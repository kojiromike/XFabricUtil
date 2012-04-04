#!/usr/bin/env ruby -W0

require 'rubygems'
require 'stringio'
require 'json'
require 'rubygems'
require 'avro'
require 'pp'
require 'yajl'
require 'set'

HASH = {}

def write_type_msg(buf, schema, delim, written, namespace = nil)
  buf.print delim if delim
  
  if schema.class == Avro::Schema::UnionSchema
 
    delim = ''
    nullable = false
    #pick the last
    subschema = schema.schemas.last
    #buf.print("\\")
    write_type_msg(buf, subschema, delim, written)
    #buf.print("\\")
  elsif schema.class == Avro::Schema::RecordSchema
    if !written.include?(schema.name)
      written.add(schema.name)
      namespace = schema.namespace if schema.namespace
      buf.print "{"
    
      delim = ''
      #puts "Schema - #{schema.name}\n--------"
      temp_hash = {}
      schema.fields.each do |f|
       
      if f.type.class == Avro::Schema::UnionSchema
          
            test_buf = StringIO.new
            test_written = Set.new
            write_type_msg(test_buf, f.type.schemas.last, '', test_written, namespace)
            test_buf.rewind
            temp_hash[f.name] = test_buf.read
            #puts "schema name is #{schema.name}, #{temp_hash[f.name]}"
      elsif f.type.class == Avro::Schema::EnumSchema
           test_buf = StringIO.new
           test_written = Set.new
           write_type_msg(test_buf, f.type, '', test_written, namespace)
           test_buf.rewind   
           temp_hash[f.name] = test_buf.read
           #puts "schema name is #{schema.name}, #{test_buf.read}"
           #if temp_hash.has_key?(f.name)
          # puts "f is #{f}, name is #{f.name} test_buf is #{test_buf.read}"
      else
        #puts "f.name is #{f.name} and type is #{f.type}"
        temp_hash[f.name] = f.type
      end
        
      end
     # puts "#{temp_hash}"
     # temp_hash.each  {|k,v|
     #        puts "#{k}\t #{v}"
     #        }
      # if HASH.has_key?(schema.name)
      #         puts "key exists for #{schema.name} #{HASH[schema.name]}, new value is #{temp_hash}"
      #       end
      HASH[schema.name] = temp_hash
      schema.fields.each do |field|
        
        buf.print delim
        buf.print "\"#{field.name}\":"
        #puts "field is #{field}, type is #{field.type}"
        write_type_msg(buf, field.type, '', written)
        delim = ','
        
      end
      buf.print "}"
      
    else
      #puts "schema is #{schema.name}"
      if schema.namespace
        #puts "\"#{schema.namespace}.#{schema.name}\""
        buf.print "\"#{schema.namespace}.#{schema.name}\""
      else
        #puts "\"#{schema.name}\""
        buf.print "\"#{schema.name}\""
      end
    end
  elsif schema.class == Avro::Schema::ArraySchema
    #puts "schema #{schema}"
    buf.print "["
    
    write_type_msg(buf, schema.items, '', written)
    buf.print "]"
  elsif schema.class == Avro::Schema::EnumSchema
    #puts "schema is #{schema}"
    #json = schema.to_json()[1..-2].gsub('"\\"', '"').gsub('\\"', '"')
    #puts "schema is #{schema}, name is #{schema.name}, enum is #{schema.symbols.first}"
    buf.print "\"#{schema.symbols.first}\""
  else
    
    json = schema.to_json()[1..-2].gsub('"\\"', '"').gsub('\\"', '"')
    buf.print json
  end
end

#########################################################

def write_type(buf, schema, delim, written, namespace = nil)
  buf.print delim if delim
  
  if schema.class == Avro::Schema::UnionSchema
    buf.print '['
    delim = ''
    nullable = false
    schema.schemas.each do |subschema|
      nullable = nullable || (subschema.to_s == '"null"')
      write_type(buf, subschema, delim, written)
      delim = ','
    end
    buf.print ']'
    if nullable
      buf.print ',"default":null'
    end
  elsif schema.class == Avro::Schema::RecordSchema
    if !written.include?(schema.name)
      written.add(schema.name)

      namespace = schema.namespace if schema.namespace
      
      buf.print "{\"type\":\"record\",\"name\":\"#{schema.name}\""

      ['version', 'topic'].each do |prop|
        if schema.props.has_key? prop
          buf.print ", \"#{prop}\":\"#{schema.props[prop]}\""
        end
      end

      if namespace
        buf.print ",\"namespace\":\"#{namespace}\""
      end
      buf.print ",\"fields\":["
      
      delim = ''
      
      schema.fields.each do |field|
        buf.print delim
        buf.print "{\"name\":\"#{field.name}\",\"type\":"
        write_type(buf, field.type, '', written)
        begin
          field.props.each do |k,v|
            buf.print ", \"#{k}\": \"#{v}\""
          end
        rescue
          nil
        end
        buf.print '}'
        delim = ','
      end

      buf.print "]}"
    else
      if schema.namespace
        buf.print "\"#{schema.namespace}.#{schema.name}\""
      else
        buf.print "\"#{schema.name}\""
      end
    end
  elsif schema.class == Avro::Schema::ArraySchema
    buf.print "{\"type\":\"array\",\"items\":"

    write_type(buf, schema.items, '', written)

    buf.print "}"
  else
    json = schema.to_json()[1..-2].gsub('"\\"', '"').gsub('\\"', '"')
    buf.print json
  end
end



if ARGV.size != 1
  #puts "Error. Expecting the AVDL file as an input (<excutable> <filename.avdl> <X.commerce contracts_path>)"
  puts "Error. Expecting the AVDL file as an input (<excutable> <filename.avdl> )"
  exit
end

#copy all the contracts to sample folder
#copy_contracts_sample_folder()

if !File.exist?("lib/avro-tools-1.6.1.jar")
  puts "Cannot find the avro-tools-1.6.1.jar file in the application root directory."
  exit
end

if !File.directory?('out')
  `mkdir out`
end

idl_file = File.open(ARGV[0])
jar_path = File.join(Dir.pwd, 'lib', 'avro-tools-1.6.1.jar')
puts "Compiling #{ARGV[0]}"

last_index = ARGV[0].gsub("\\",'/').rindex('/')
f = ARGV[0][last_index+1..ARGV[0].length-1].split('.')[0]
out = `java -jar #{jar_path} idl #{idl_file.path} 2>&1`

`java -jar #{jar_path} idl #{idl_file.path} > ./out/#{f}.avpr`
if !File.exist?("./out/#{f}.avpr")
  puts "Could not generate avpr files. Dying with the following error\n#{out}\n"
  raise "quitting! Try putting all the necessary avdl files in the root folder and rerun the script."
end

puts "Processing #{f}.avpr"


protocol_file = File.open("out/#{f}.avpr")
protocol_text = protocol_file.read
protocol = Avro::Protocol.parse(protocol_text)
protocol.types.each do |type|
  #puts type.class  
  if type.class == Avro::Schema::RecordSchema && type.props['version']  
    buf = StringIO.new
    msg_buf = StringIO.new
    written = Set.new
    msg_written = Set.new
    namespace = type.namespace ? type.namespace : protocol.namespace
    puts "attempting to generate message for #{type.name}\n\n"
    write_type_msg(msg_buf, type, '', msg_written, namespace)
    write_type(buf, type, '', written, namespace)
    buf.rewind
    #puts buf.read
    msg_buf.rewind
    json_message = msg_buf.read
    schema = buf.read
    # pp HASH
    #    puts "unprocessed0\n"
    #            puts json_message
    #            puts "\n\n"
    #pp HASH
     # HASH.each { |k,v|
     #       #if a value has a com attribute replace it with its true value
     #       #json_message.gsub!(/\"com\.x\.ocl\.\w+\"/,'{}') 
     #       msg_buf = StringIO.new
     #       msg_written = Set.new
     #       write_type_msg(msg_buf, v, '', msg_written, namespace)
     #       msg_buf.rewind
     #       HASH[k] = msg_buf.read
     #      }
    
    HASH.each { |k,v|
      #puts "#{k}, #{v}"
      if v.is_a?(Hash)
        #puts "key is #{k}\nvalue is #{v}"
        if !v.to_s.include?("com.x.ocl") 
          vdash = v.to_s.gsub("\\\"","\"")
          json_message.gsub!(/\"#{k}\"/,"\"#{vdash}\"")
          json_message.gsub!(/\.#{k}\"/,".#{vdash}\"")
        else
          json_message.gsub!(/\"#{k}\"/,"{}")
          json_message.gsub!(/\.#{k}\"/,".{}")
        end
        
      else
        if !v.include?('com.x.ocl')
          json_message.gsub!(/\"#{k}\"/,"\"#{v}\"")
          json_message.gsub!(/\.#{k}\"/,".#{v}")
        else
          #json_message.gsub!(/\"#{k}\"/,"{}")
          json_message.gsub!(/#{k}\"/,"{}")
        end
        #json_message.gsub!(/\.#{k}\"/,".#{v}\"")
      end
    }
   
     # 
    
    #pp HASH
    # puts "unprocessed\n"
    #     puts json_message
    #     puts "\n\n"
    #puts "\n\n"
    generated_message = json_message.gsub("\"com.x.ocl.","").gsub('"{"','{"').gsub('}"','}').gsub("=>",":").\
                        gsub('""','"').gsub('"null"','null').gsub("\\[","").gsub("]\\","").gsub("\\","").\
                        gsub('"int"',"0").gsub('"float"',"0.0").gsub('"boolean"',"false").gsub('"double"',"0.0").\
                        gsub('"long"',"0").gsub('{"type":"map"}','null').gsub('{"type":"map","values":{}}','{}')
                        #.gsub('"bytes"','"00101010"')
    
    
    out = File.open(namespace + '.' + type.name + '.avsc', 'w')
    out.print schema
    out.close
    out = File.open(namespace + '.' + type.name + '.avsc', 'rb')
    msg_file = File.open(namespace + '.' + type.name + '.json', 'w')
    
    puts generated_message
    puts "\n\n"
    msg = generated_message
     
    if !msg.nil?
      puts "Generated a test message for #{type.name}\n"
      puts "attempting to verify the message against the message schema"
      stringwriter = StringIO.new
      begin
        schema_parsed = Avro::Schema.parse(schema)
        datumwriter = Avro::IO::DatumWriter.new(schema_parsed)
        encoder = Avro::IO::BinaryEncoder.new(stringwriter)
      
         datumwriter.write(JSON.parse(msg),encoder)
         puts "Successfully validated the message against the schema. This is a valid test message."     
         msg_file.print(msg)
       rescue Avro::IO::AvroTypeError => e
         puts "Error, could not generate a valid message for #{type.name}!!\n"
       rescue
         puts "Error, could not generate a valid message for #{type.name}!!\n"
       end
    else
      puts "Could not generate a test message for #{type.name}\n"
    end
    
    msg_file.close
    out.close
    puts "\n\n------------\n\n"
  end
  
end

`mv *.avsc *.json out`


