#!/usr/bin/env ruby -W0

require 'stringio'
require 'rubygems'
require 'json'
require 'rubygems'
require 'httparty'
require 'avro'

#require './sch_val.rb'
require 'yajl'
require 'set'
require 'digest/md5'
require 'net/http'
require 'stringio'
require 'json'
module Avro
  VERSION = "FIXME"

  class AvroError < StandardError; end

  class AvroTypeError < Avro::AvroError
    def initialize(schm=nil, datum=nil, msg=nil)
      msg ||= "Not a #{schm.to_s}: #{datum}"
      super(msg)
    end
  end
end

require './lib/schema_avro_1.6.1_patch.rb'
require './lib/io_avro.rb'

def generate_json_test_message(schema_str)
 
    #file = File.open(schema_file, "rb")
    #contents = file.read
    #puts "contents\n\n"
    #p contents
    contents = schema_str
   
  begin
    Avro::Schema.clear_message_structures(nil)
    schema = Avro::Schema.parse(contents)
    
    test_arr = Avro::Schema::MSG_ARRAY.dup
    msg_arr = Avro::Schema::MSG_ARRAY.dup
    created_msg_arr = []
    msg_hash = {}

  #puts msg_arr 

    test_arr.each_with_index do |t,i|
      if t.include?("FIELD")
        done_tag = "DONE.#{t.split('.')[1]}"
        index = msg_arr.index(done_tag)
        #check index + 1 to see if it is a schema
        (index == msg_arr.size - 1) ? nxt = "" : nxt = test_arr[index+1]
        #update the hash with the copy of a symbol message


        if nxt.include?("Avro::Schema")

          #arrayschema or recordschema
          if nxt.include?("ArraySchema")
            msg_arr[index] = "}], "
            msg_arr[i] = "#{nxt.gsub("Avro::Schema::ArraySchema","[{")}"
          elsif nxt.include?("RecordSchema")
            msg_arr[index] = "}, "
            msg_arr[i] = "#{nxt.gsub("Avro::Schema::RecordSchema","{")}"
          end
          #push the field name
          created_msg_arr << nxt.split(':')[0].strip
          val = t.split('.')[1]
          msg_hash["#{val}"] = (msg_arr[i..index].find_all{|item| !item.include?("Schema") && !item.include?("FIELD") && !item.include?("DONE")}).join('').gsub(', }','}').gsub(', ]',']').gsub('"boolean"',"false").gsub('"double"',"0.0").gsub('"int"',"0").gsub(']"','],"').gsub('}"','},"')
        else
          #prev does not have any value, treat it as simple close
          msg_arr[index] = "}"
          msg_arr[i] = "{"
        end

      end
    end
    #one more pass on test_arr to collect missing fields due to sym type declaration
    total_msg_arr = []
    msg_arr.each_with_index do |t,i|
      if t.include?("Avro::Schema")
        #push the field name
        total_msg_arr << t.split(':')[0].strip
      end
    end


    left_vals = (total_msg_arr - (total_msg_arr & created_msg_arr))

    #puts msg_arr
    left_vals.each do |l|
      #get the name of the field
      key = l[1..l.length-2]

      #get the replacement code
      hash_val = msg_hash[Avro::Schema::MSG_HASH[key]]
      if !hash_val.nil?
        code = msg_hash[Avro::Schema::MSG_HASH[key]].split(':') 
        code = code[1..code.length-1].join(':')
        msg_arr.each do |msg|
          if msg.include?(key)

            msg.gsub!('Avro::Schema::ArraySchema',code)
            msg.gsub!('Avro::Schema::RecordSchema',code)
          end
        end
      else
        #it is nil. there is no code
        #if it is an array schema, just replace it by [Avro::Schema::MSG_HASH[key]]
        msg_arr.each do |msg|
          if msg.include?(key)
            if msg.include?("ArraySchema")
              msg.gsub!('Avro::Schema::ArraySchema',"[\"#{Avro::Schema::MSG_HASH[key]}\"]")
            else
              msg.gsub!('Avro::Schema::RecordSchema',"{\"#{Avro::Schema::MSG_HASH[key]}\"}")
            end
          end
        end
      end

    end
    #cleanup
    message = (msg_arr.find_all{|item| !item.include?("Schema")}).join('').gsub(', }','}').gsub(', ]',']').gsub('"boolean"',"false").gsub('"double"',"0.0").gsub('"int"',"0").gsub(']"','],"').gsub('}"','},"')
  rescue
    puts "Error parsing schema #{schema_str}.\n\n"
    message = nil
  end
  if Avro::Schema::MSG_ERROR_FLAG.size > 0

    #double check to make sure the message does not have an error
    stringwriter = StringIO.new
    datumwriter = Avro::IO::DatumWriter.new(schema)
    encoder = Avro::IO::BinaryEncoder.new(stringwriter)
    begin
       datumwriter.write(JSON.parse(message),encoder)     
     rescue Avro::IO::AvroTypeError
       puts "Error, cannot generate message for #{schema_file}"
       message = nil
     end
  end

  return message
end

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

      buf.print "{\"type\":\"record\",\"name\":\"#{schema.name}\", \"version\":\"#{schema.props['version']}\""
      if namespace
        buf.print ",\"namespace\":\"#{namespace}\""
      end
      buf.print ",\"fields\":["
      
      delim = ''
      
      schema.fields.each do |field|
        buf.print delim
        buf.print "{\"name\":\"#{field.name}\",\"type\":"
        write_type(buf, field.type, '', written)
        buf.print '}'
        delim = ','
      end

      buf.print "]}"
    else
      buf.print "\"#{schema.namespace}.#{schema.name}\""
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
  puts "Error. Expecting the AVDL file as an input (<excutable> <filename.avdl>)"
  exit
end

if !File.exist?("lib/avro-tools-1.6.1.jar")
  puts "Cannot find the avro-tools-1.6.1.jar file in the application root directory."
  exit
end

idl_file = File.open(ARGV[0])
jar_path = File.join(Dir.pwd, 'lib', 'avro-tools-1.6.1.jar')
puts "Compiling #{ARGV[0]}"
f = ARGV[0].split('.')[0]
`java -jar #{jar_path} idl #{f}.avdl > out/#{f}.avpr`
puts "Processing #{f}.avpr"


protocol_file = File.open("out/#{f}.avpr")
protocol_text = protocol_file.read
protocol = Avro::Protocol.parse(protocol_text)
protocol.types.each do |type|
  #puts type.class  
  if type.class == Avro::Schema::RecordSchema && type.props['version']  
    buf = StringIO.new
    written = Set.new
    
    namespace = type.namespace ? type.namespace : protocol.namespace
    write_type(buf, type, '', written, namespace)
    buf.rewind
    out = File.open(namespace + '.' + type.name + '.avsc', 'w')
    out.print buf.read
    out.close
    out = File.open(namespace + '.' + type.name + '.avsc', 'rb')
    msg_file = File.open(namespace + '.' + type.name + '.json', 'w')
    msg = generate_json_test_message(out.read)
    msg_file.print(msg)
    if !msg.nil?
      puts "successfully generated a test message for #{type.name}\n"
    else
      puts "Could not generate a test message for #{type.name}\n"
    end
    msg_file.close
    out.close
  end
  
end
jar_path = File.join(Dir.pwd, 'lib', 'avro-tools-1.6.1.jar')
if !File.directory?('out')
  `mkdir out`
end
`mv *.avsc *.json out`


