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
            
      else
        temp_hash[f.name] = f.type
      end
        
      end
     # puts "#{temp_hash}"
      HASH[schema.name] = temp_hash
      schema.fields.each do |field|
        
        buf.print delim
        buf.print "\"#{field.name}\":"
        write_type_msg(buf, field.type, '', written)
        delim = ','
        
      end
      buf.print "}"
      
    else
      if schema.namespace
        buf.print "\"#{schema.namespace}.#{schema.name}\""
      else
        buf.print "\"#{schema.name}\""
      end
    end
  elsif schema.class == Avro::Schema::ArraySchema
    #puts "schema #{schema}"
    buf.print "["
    write_type_msg(buf, schema.items, '', written)
    buf.print "]"
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
    HASH.each { |k,v|
      #puts "#{k}, #{v}"
      if v.is_a?(Hash)
        vdash = v.to_s.gsub("\\\"","\"")
        json_message.gsub!(k,vdash)
      else
        json_message.gsub!(k,v)
      end
    }
     # 
    
    #pp HASH
    #puts "\n\n"
    generated_message = json_message.gsub("com.x.ocl.","").gsub('"{"','{"').gsub('}"','}').gsub("=>",":").\
                        gsub('""','"').gsub('"null"','null').gsub("\\[","").gsub("]\\","").gsub("\\","").\
                        gsub('"int"',"0")
    
    
    out = File.open(namespace + '.' + type.name + '.avsc', 'w')
    out.print schema
    out.close
    out = File.open(namespace + '.' + type.name + '.avsc', 'rb')
    msg_file = File.open(namespace + '.' + type.name + '.json', 'w')
    
    puts generated_message
    puts "\n\n"
    msg = generated_message
    
    
    msg_file.print(msg)
    
    if !msg.nil?
      puts "successfully generated a test message for #{type.name}\n"
      puts "attempting to verify the schema against the contract"
      stringwriter = StringIO.new
      schema_parsed = Avro::Schema.parse(schema)
      datumwriter = Avro::IO::DatumWriter.new(schema_parsed)
      encoder = Avro::IO::BinaryEncoder.new(stringwriter)
      begin
         datumwriter.write(JSON.parse(msg),encoder)
         puts "Successfully validated the message against the schema"     
       rescue Avro::IO::AvroTypeError => e
         puts "Error, could not validate message!!"
       end
    else
      puts "Could not generate a test message for #{type.name}\n"
    end
    break
    msg_file.close
    out.close
  end
  
end

`mv *.avsc *.json out`


