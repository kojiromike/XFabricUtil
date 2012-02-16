require 'rubygems'
require 'httparty'


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

#url = "http://localhost/fabric_post/contracts/cse_0.avpr"
#url = "https://ocl.cloud.x.com/inventory/stockItem/delete/1.0.0"
#url = "https://ocl.xcommercecloud.com/marketplace/profile/delete/1.0.0"
#url = "https://ocl.cloud.x.com/inventory/stockItem/searchSucceeded/1.0.0"
#url = "https://ocl.cloud.x.com/inventory/stockItem/get/1.0.0"
#url = "https://ocl.xcommercecloud.com/inventory/stockItem/get/1.0.0"
#url = "https://ocl.cloud.x.com/marketplace/country/searchSucceeded/1.0.0"
#url = "https://ocl.cloud.x.com/inventory/stockItem/set/1.0.0"
#url = "https://ocl.xcommercecloud.com/inventory/stockItem/set/1.0.0"
#url = "https://ocl.cloud.x.com/inventory/stockItem/search/1.0.0"
#url = "https://ocl.xcommercecloud.com/inventory/stockItem/search/1.0.0"
#url = "https://ocl.xcommercecloud.com/inventory/location/create/1.0.0"
#url = "https://ocl.xcommercecloud.com/inventory/location/searchFailed/1.0.0"

if ARGV.size == 0 || ARGV.size > 1
  puts "Please enter the schema URL as an argument <ruby filename schemaurl>\n\n"
  exit
end

url = ARGV[0]
begin
  file = HTTParty.get("#{url}")
rescue 
  puts "Unable to find file at the specified location\n\n"
  exit
end
begin
  parser = Yajl::Parser.new
  schema = Avro::Schema.parse(file.response.body)

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
  puts "Error parsing schema.\n\n"
  exit
end
if Avro::Schema::MSG_ERROR_FLAG.size > 0
  
  #double check to make sure the message does not have an error
  stringwriter = StringIO.new
  datumwriter = Avro::IO::DatumWriter.new(schema)
  encoder = Avro::IO::BinaryEncoder.new(stringwriter)
  begin
     datumwriter.write(JSON.parse(message),encoder)     
   rescue Avro::IO::AvroTypeError
     puts "I encountered weirdness, but I went ahead and generated a message. But please double check the message.\n\n"
   end
end

puts message

