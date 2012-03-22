#!/Users/svigraham/.rvm/rubies/ruby-1.9.2-p290/bin/ruby

require 'rubygems'
require 'yajl'
require 'pp'

def arrecursive(val,str)
  arr =[]
  val.each do |vd|
    if vd.is_a?(Hash)
      vd.each do |hdd,vdd|
        if vdd.is_a?(Hash)
          arr.push({"data" => hdd, "children" => recursive(vdd)})
        elsif vdd.is_a?(Array)
           arr.push({"data" => hdd, "children" => arrecursive(vdd,hdd)})
        else
          arr.push({"data" => hdd, "children" => [vdd]})
        end
      end
    else
      
      arr.push( {"data" => str, "children" => [vd]})
    end
  end
  return arr
end

def recursive(hash)
  #val can be array
  #val can be hash
  #val can be other
  arr = []

  if hash.is_a?(Array)
    hash.each do |hsh|
      if hsh.is_a?(Hash)
        hsh.each do |h,v|
           arr.push({"data" => h, "children" => recursive(v)})
        end
      else
        nil
      end
    end
  end
  if hash.is_a?(Hash)
    hash.each do |h,v|
      if v.is_a?(Array)
        if v[0].is_a?(Hash)
          arr.push({"data" => h, "children" => arrecursive(v,h)})
        else
          arr.push({"data" => h, "children" => [v]})
        end
      elsif v.is_a?(Hash)
        
        arr.push({"data" => h, "children" => recursive(v)})
      else     
        
        arr.push({"data" => h, "children" => [v]})
      end
    end
  end
  return arr
end



hash_structure = {"data" => "node name", "children" => [{"data" => "children1"},{"data" => "children2"}]}
json = File.read('pt.json').gsub(/\{\"array\"\:/,'').gsub(/\]\}/,']')
parser = Yajl::Parser.new
hash = parser.parse(json)
new_hash = {}
arr = []
# hash.each do |h,v|
#   arr.push({"data" => h, "children" => recursive(v)})
# end
#pp hash
hash.each do |h,v|
  if v.is_a?(Hash)
   
      arr.push({"data" => h, "children" => recursive(v)})
    
  elsif v.is_a?(Array)
    
    # new_arr = []
    #     v.each do |vd|
    #       new_arr.push({"data" => h, "children" => [recursive(vd)]})
    #     end
    #     arr.push({"data" => h, "children" => new_arr})
    arr.push({"data" => h, "children" => arrecursive(v,h)})
  
  end
 
end
puts arr.to_s.gsub("=>",":").gsub("nil",'"nil"')
#.gsub('"}, {"data"',']"}, {"data"').gsub('"children":"','"children":["')

# hash["com.x.app.taxonomy.dto.TaxonomyDTO"].each do |h|
#   p h.key
#   if h.is_a?(Hash)
#     p h
#   end
# end
#pp hash["com.x.app.taxonomy.dto.TaxonomyDTO"]
# hash["com.x.app.taxonomy.dto.TaxonomyDTO"].each do |key,val|
#   if val.is_a?(Hash)
#     temp_hash = {"data" => key}
#     c
#   end
# end

#p hash.size
