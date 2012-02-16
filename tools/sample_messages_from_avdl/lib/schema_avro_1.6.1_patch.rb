# Licensed to the Apache Software Foundation (ASF) under one
# or more contributor license agreements.  See the NOTICE file
# distributed with this work for additional information
# regarding copyright ownership.  The ASF licenses this file
# to you under the Apache License, Version 2.0 (the
# "License"); you may not use this file except in compliance
# with the License.  You may obtain a copy of the License at
# 
# http://www.apache.org/licenses/LICENSE-2.0
# 
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

module Avro
  class Schema
    # FIXME turn these into symbols to prevent some gc pressure
    PRIMITIVE_TYPES = Set.new(%w[null boolean string bytes int long float double])
    NAMED_TYPES =     Set.new(%w[fixed enum record error])

    VALID_TYPES = PRIMITIVE_TYPES + NAMED_TYPES + Set.new(%w[array map union request])

    INT_MIN_VALUE = -(1 << 31)
    INT_MAX_VALUE = (1 << 31) - 1
    LONG_MIN_VALUE = -(1 << 63)
    LONG_MAX_VALUE = (1 << 63) - 1

    MSG_ARRAY = []
    MSG_HASH = {"string" => "string", "int" => 0, "double" => 0.0, "float" => 0.0, "boolean" => true}
    MSG_ERROR_FLAG = []

    def self.parse(json_string)
      real_parse(Yajl.load(json_string), {})
    end
    def self.clear_message_structures(value)
      const_set("MSG_ARRAY", [])
      const_set("MSG_ERROR_FLAG", [])
      const_set("MSG_HASH", {"string" => "string", "int" => 0, "double" => 0.0, "float" => 0.0, "boolean" => true})
    end
    # Build Avro Schema from data parsed out of JSON string.
    def self.real_parse(json_obj, names=nil, namespace=nil)
      if json_obj.is_a? Hash
        type = json_obj['type']

        if PRIMITIVE_TYPES.include?(type)
          return PrimitiveSchema.new(type)
        elsif NAMED_TYPES.include? type
          name = json_obj['name']
          namespace = json_obj['namespace']
          case type
          when 'fixed'
            size = json_obj['size']
            return FixedSchema.new(name, namespace, size, names)
          when 'enum'
            symbols = json_obj['symbols']
            return EnumSchema.new(name, namespace, symbols, names)
          when 'record', 'error'
            fields = json_obj['fields']

            props = {}
            json_obj.each {|k,v| props[k] = v if not ['type', 'name', 'fields', 'items'].include? k}

            return RecordSchema.new(name, namespace, fields, names, type, props)
            elsex
            raise SchemaParseError.new("Unknown named type: #{type}")
          end
        elsif VALID_TYPES.include?(type)
          case type
          when 'array'
            return ArraySchema.new(json_obj['items'], namespace, names)
          when 'map'
            return MapSchema.new(json_obj['values'], namespace, names)
          else
            raise SchemaParseError.new("Unknown Valid Type: #{type}")
          end
        elsif type.nil?
          raise SchemaParseError.new("No \"type\" property: #{json_obj}")
        else
          raise SchemaParseError.new("Undefined type: #{type}")
        end
      elsif json_obj.is_a? Array
        # JSON array (union)
        return UnionSchema.new(json_obj, namespace, names)
      elsif PRIMITIVE_TYPES.include? json_obj
        return PrimitiveSchema.new(json_obj)
      else
        msg = "#{json_obj.inspect} is not a schema we know about."
        raise SchemaParseError.new(msg)
      end
    end

    # Determine if a ruby datum is an instance of a schema
    def self.validate(expected_schema, datum)
      case expected_schema.type
      when 'null'
        datum.nil?
      when 'boolean'
        datum == true || datum == false
      when 'string', 'bytes'
        datum.is_a? String
      when 'int'
        (datum.is_a?(Fixnum) || datum.is_a?(Bignum)) &&
        (INT_MIN_VALUE <= datum) && (datum <= INT_MAX_VALUE)
      when 'long'
        (datum.is_a?(Fixnum) || datum.is_a?(Bignum)) &&
        (LONG_MIN_VALUE <= datum) && (datum <= LONG_MAX_VALUE)
      when 'float', 'double'
        datum.is_a?(Float) || datum.is_a?(Fixnum) || datum.is_a?(Bignum)
      when 'fixed'
        datum.is_a?(String) && datum.size == expected_schema.size
      when 'enum'
        expected_schema.symbols.include? datum
      when 'array'
        datum.is_a?(Array) &&
        datum.all?{|d| validate(expected_schema.items, d) }
      when 'map'
        datum.keys.all?{|k| k.is_a? String } &&
        datum.values.all?{|v| validate(expected_schema.values, v) }
      when 'union'
        expected_schema.schemas.any?{|s| validate(s, datum) }
      when 'record', 'error', 'request'
        datum.is_a?(Hash) &&
        expected_schema.fields.all?{|f| validate(f.type, datum[f.name]) }
      else
        raise "you suck #{expected_schema.inspect} is not allowed."
      end
    end

    def initialize(type)
      @type = type
    end

    def type; @type; end

    def ==(other, seen=nil)
      other.is_a?(Schema) && @type == other.type
    end

    def hash(seen=nil)
      @type.hash
    end

    def subparse(json_obj, namespace=nil, names=nil)
      begin
        Schema.real_parse(json_obj, names, namespace)
      rescue => e
        raise e if e.is_a? SchemaParseError
        raise SchemaParseError, "Sub-schema for #{self.class.name} not a valid Avro schema. Bad schema: #{json_obj}"
      end
    end

    def to_avro
      {'type' => @type}
    end

    def to_s
      Yajl.dump to_avro
    end

    class NamedSchema < Schema
      attr_reader :name, :namespace
      def initialize(type, name, namespace=nil, names=nil)
        super(type)
        @name, @namespace = Name.extract_namespace(name, namespace)
        names = Name.add_name(names, self)
      end

      def to_avro
        props = {'name' => @name}
        props.merge!('namespace' => @namespace) if @namespace
        super.merge props
      end

      def fullname
        Name.make_fullname(@name, @namespace)
      end
    end

    class RecordSchema < NamedSchema
      attr_reader :fields
      attr_reader :props

      def self.make_field_objects(field_data, namespace, names)
        field_objects, field_names = [], Set.new
        field_data.each_with_index do |field, i|
          if field.respond_to?(:[]) # TODO(jmhodges) wtffffff
            type = field['type']
            name = field['name']
            default = field['default']
            order = field['order']
            new_field = Field.new(type, name, default, order, namespace, names)
            # make sure field name has not been used yet
            if field_names.include?(new_field.name)
              raise SchemaParseError, "Field name #{new_field.name.inspect} is already in use"
            end
            field_names << new_field.name
          else
            raise SchemaParseError, "Not a valid field: #{field}"
          end
          field_objects << new_field
          update_message_structures(new_field) #sv

        end
        field_objects
      end

      def self.array_schema_process(new_field, new_field_type = nil)

        if !new_field_type.nil?
          nftype = new_field_type
          nfname = new_field
        else
          nftype = new_field.type
          nfname = new_field.name
        end

        MSG_ARRAY << "\"#{nfname}\" : #{nftype.class}"
        #puts "\"#{nfname}\" : #{nftype.class}"
        #puts "\"#{new_field.name}\" : #{new_field.type}"
        begin
          parser = Yajl::Parser.new
          jp = parser.parse(nftype.to_s)

          if jp["type"] == "record"
            MSG_HASH["#{nfname}"] = jp["name"]
            self.parse(jp.to_s)
          elsif jp["type"] == "array"
            #p jp
            if jp["items"]["name"].nil?
              MSG_HASH["#{nfname}"] = jp["items"]

            else
              MSG_HASH["#{nfname}"] = jp["items"]["name"]
              self.parse(jp["items"].to_s)
            end
          end
        rescue
          if jp.instance_of? Array
            #this might be because of null fields
            
            jp.each do |j|
            
              if j.instance_of? Hash
                if j["type"] == "record"
                  MSG_HASH["#{nfname}"] = j["name"]
                elsif j["type"] == "array"
                  if j["items"]["name"].nil?
                    MSG_HASH["#{nfname}"] = j["items"]
                  else
                    MSG_HASH["#{nfname}"] = j["items"]["name"]
                  end
                end
              end
            end
          end
          MSG_ERROR_FLAG << true
        end
      end
      def self.update_message_structures(new_field, new_field_type = nil)
       
        if !new_field_type.nil?
          nftype = new_field_type
          nfname = new_field
        else
          nftype = new_field.type
          nfname = new_field.name
        end

        
        if nftype.instance_of? Avro::Schema::EnumSchema
          MSG_ARRAY << "\"#{nfname}\" : #{nftype.get_random_sym}, "
          #puts "\"#{nfname}\" : #{nftype.get_random_sym}"
        elsif nftype.instance_of? Avro::Schema::PrimitiveSchema
          MSG_ARRAY << "\"#{nfname}\" : #{nftype}, "
          #puts "\"#{nfname}\" : #{nftype}"
        elsif nftype.instance_of? Avro::Schema::UnionSchema
          temp_sch = nftype.schemas[1]          
          if temp_sch.type == "record"            
            MSG_HASH["#{nfname}"] = temp_sch
            update_message_structures(nfname,temp_sch)
          elsif temp_sch.type == "array"
            MSG_ARRAY << "\"#{nfname}\" : Avro::Schema::ArraySchema"
          else
            begin
              if temp_sch.items.has_key?("type")
                if temp_sch.items.type == "array"
                  MSG_HASH["#{nfname}"] = temp_sch.items
                else
                  if temp_sch.type == "array"
                    MSG_ARRAY << "\"#{nfname}\" : Avro::Schema::ArraySchema"
                  else
                    #MSG_ARRAY << "\"#{nfname}\" : Avro::Schema::ArraySchema"
                    MSG_HASH["#{nfname}"] = temp_sch.items
                    update_message_structures(nfname,temp_sch.items)
                  end
                end
              end
            rescue
              if !temp_sch.instance_of? Avro::Schema::PrimitiveSchema
                if temp_sch.type == "record" || temp_sch.type == "map" 
                  MSG_ARRAY << "\"#{nfname}\" : {}, "
                elsif temp_sch.type == "array"     
                  MSG_ARRAY << "\"#{nfname}\" : Avro::Schema::ArraySchema"
                end
              else
                MSG_ARRAY << "\"#{nfname}\" : #{temp_sch}, "
              end
              #MSG_HASH["#{nfname}"] = temp_sch.items
              #update_message_structures(nfname,temp_sch.items)
              #MSG_ERROR_FLAG << true
            end
          end

        elsif nftype.instance_of? Avro::Schema::ArraySchema
          #p "2 #{nfname}"
          array_schema_process(new_field)   
        else

          MSG_ARRAY << "\"#{nfname}\" : #{nftype.class}"
           begin
            parser = Yajl::Parser.new
            jp = parser.parse(nftype.to_s)

            if jp["type"] == "record"
              MSG_HASH["#{nfname}"] = jp["name"]
            elsif jp["type"] == "array"
             
              if jp["items"]["name"].nil?
                MSG_HASH["#{nfname}"] = jp["items"]
              else
                MSG_HASH["#{nfname}"] = jp["items"]["name"]
              end
            end
          rescue
            
            MSG_ERROR_FLAG << true
          end
        end

      end

      def initialize(name, namespace, fields, names=nil, schema_type='record', props=nil)
        @props = props
        if schema_type == 'request'
          @type = schema_type
        else
          super(schema_type, name, namespace, names)
        end
        #puts "new field #{name}\n\n"
        MSG_ARRAY << "FIELD.#{name}"
        @fields = RecordSchema.make_field_objects(fields, namespace, names)
        MSG_ARRAY << "DONE.#{name}"
        #puts "done new field #{name}\n\n"

      end

      def fields_hash
        fields.inject({}){|hsh, field| hsh[field.name] = field; hsh }
      end

      def to_avro
        hsh = super.merge('fields' => @fields.map {|f| f.to_avro } )
        if type == 'request'
          hsh['fields']
        else
          hsh
        end
      end
    end

    class ArraySchema < Schema
      attr_reader :items, :items_schema_from_names
      def initialize(items, namespace=nil, names=nil)
        @items_schema_from_names = false

        super('array')

        if items.is_a?(String) && names.has_key?(items)
          @items = names[items]
          @items_schema_from_names = true
        elsif items.is_a?(String) && namespace && !namespace.match(/^org\.apache\.avro/) && names.has_key?("#{namespace}.#{items}")  # SJC
          @items = names["#{namespace}.#{items}"]
          @items_schema_from_names = true
        else
          @items = subparse(items, namespace, names)
        end
      end

      def to_avro
        name_or_json = if items_schema_from_names
          items.fullname
        else
          items.to_avro
        end
        super.merge('items' => name_or_json)
      end
    end

    class MapSchema < Schema
      attr_reader :values, :values_schema_from_names

      def initialize(values, namespace=nil, names=nil)
        @values_schema_from_names = false
        super('map')

        if values.is_a?(String) && names && names.has_key?(values)
          values_schema = names[values]
          @values_schema_from_names = true
        elsif values.is_a?(String) && namespace.is_a?(String) && !namespace.match(/^org\.apache\.avro/) && names && names.has_key?("#{namespace}.#{values}")  # SJC
          values_schema = names["#{namespace}.#{values}"]
          @values_schema_from_names = true
        else
          values_schema = subparse(values, namespace, names)
        end
        @values = values_schema
      end

      def to_avro
        #        to_dump = super
        #        if values_schema_from_names
        #          to_dump['values'] = values
        #        else
        #          to_dump['values'] = values.to_avro
        #        end
        #        to_dump
        name_or_json = if values_schema_from_names
          values.fullname
        else
          values.to_avro
        end
        super.merge('values' => name_or_json)

      end
    end

    class UnionSchema < Schema
      attr_reader :schemas, :schema_from_names_indices
      def initialize(schemas, namespace=nil, names=nil)
        super('union')

        schema_objects = []
        @schema_from_names_indices = []
        schemas.each_with_index do |schema, i|
          from_names = false
          if schema.is_a?(String) && names && names.has_key?(schema)
            new_schema = names[schema]
            from_names = true
          elsif schema.is_a?(String) && namespace && !namespace.match(/^org\.apache\.avro/) && names && names.has_key?("#{namespace}.#{schema}") # SJC
            new_schema = names["#{namespace}.#{schema}"]
            from_names = true
          else
            new_schema = subparse(schema, namespace, names)
          end

          ns_type = new_schema.type
          if VALID_TYPES.include?(ns_type) &&
            !NAMED_TYPES.include?(ns_type) &&
            schema_objects.map{|o| o.type }.include?(ns_type)
            raise SchemaParseError, "#{ns_type} is already in Union"
          elsif ns_type == 'union'
            raise SchemaParseError, "Unions cannot contain other unions"
          else
            schema_objects << new_schema
            @schema_from_names_indices << i if from_names
          end
          @schemas = schema_objects

        end
      end

      def to_avro
        # FIXME(jmhodges) this from_name pattern is really weird and
        # seems code-smelly.
        to_dump = []
        schemas.each_with_index do |schema, i|
          if schema_from_names_indices.include?(i)
            to_dump << schema.fullname
          else
            to_dump << schema.to_avro
          end
        end
        to_dump
      end
    end

    class EnumSchema < NamedSchema
      attr_reader :symbols
      def initialize(name, space, symbols, names=nil)
        if symbols.uniq.length < symbols.length
          fail_msg = 'Duplicate symbol: %s' % symbols
          raise Avro::SchemaParseError, fail_msg
        end
        super('enum', name, space, names)
        @symbols = symbols
      end
      def get_random_sym
        "\"#{@symbols[rand(@symbols.size)]}\""
      end
      def to_avro
        super.merge('symbols' => symbols)
      end
    end

    # Valid primitive types are in PRIMITIVE_TYPES.
    class PrimitiveSchema < Schema
      def initialize(type)
        unless PRIMITIVE_TYPES.include? type
          raise AvroError.new("#{type} is not a valid primitive type.")
        end

        super(type)
      end

      def to_avro
        hsh = super
        hsh.size == 1 ? type : hsh
      end
    end

    class FixedSchema < NamedSchema
      attr_reader :size
      def initialize(name, space, size, names=nil)
        # Ensure valid cto args
        unless size.is_a?(Fixnum) || size.is_a?(Bignum)
          raise AvroError, 'Fixed Schema requires a valid integer for size property.'
        end
        super('fixed', name, space, names)
        @size = size
      end

      def to_avro
        super.merge('size' => @size)
      end
    end

    class Field < Schema
      attr_reader :type, :name, :default, :order, :type_from_names
      def initialize(type, name, default=nil, order=nil, namespace=nil, names=nil)
        @type_from_names = false

        if type.is_a?(String) && names && namespace && !namespace.match(/^org\.apache\.avro/) && names.has_key?("#{namespace}.#{type}") # SJC
          type = "#{namespace}.#{type}"
        end

        if type.is_a?(String) && names && names.has_key?(type)
          type_schema = names[type]
          @type_from_names = true
        else
          type_schema = subparse(type, namespace, names)
        end
        @type = type_schema
        @name = name
        @default = default
        @order = order
      end

      def to_avro
        sigh_type = type_from_names ? type.fullname : type.to_avro
        hsh = {
          'name' => name,
          'type' => sigh_type
        }
        hsh['default'] = default if default
        hsh['order'] = order if order
        hsh
      end
    end
  end

  class SchemaParseError < AvroError; end

  module Name
    def self.extract_namespace(name, namespace)
      parts = name.split('.')
      if parts.size > 1
        namespace, name = parts[0..-2].join('.'), parts.last
      end
      return name, namespace
    end

    # Add a new schema object to the names dictionary (in place).
    def self.add_name(names, new_schema)
      new_fullname = new_schema.fullname
      if Avro::Schema::VALID_TYPES.include?(new_fullname)
        raise SchemaParseError, "#{new_fullname} is a reserved type name."
      elsif names.nil?
        names = {}
      elsif names.has_key?(new_fullname)
        raise SchemaParseError, "The name \"#{new_fullname}\" is already in use."
      end

      names[new_fullname] = new_schema
      names
    end

    def self.make_fullname(name, namespace)
      if !name.include?('.') && !namespace.nil?
        namespace + '.' + name
      else
        name
      end
    end
  end
end
