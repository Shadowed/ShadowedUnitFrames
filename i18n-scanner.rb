require 'set'
strings = Set.new

Dir["**/*.lua"].each do |file|
    next if file =~ /localization/
    next if file =~ /libs\//
    contents = File.read(file)
    
    contents.scan(/L\["(.+?)"\]/).each do |match|
        strings << match[0]
    end
end

strings.sort.each do |string|
    puts "L[\"#{string}\"] = true"
end