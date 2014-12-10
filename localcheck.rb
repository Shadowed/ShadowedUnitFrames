require "uri"
require "net/http"

skip = nil
i18n = {}

toc_file = File.read("./ShadowedUnitFrames.toc")
toc_file.split("\n").each do |line|
	# Scan TOC for relevant files that are active
	line.strip!
	next if line == ""

	if line == '#@no-lib-strip@'
		skip = true
	elsif line == '#@end-no-lib-strip@'
		skip = nil
		next
	elsif line =~ /^\#/
		next
	end

	next if skip || line =~ /^localization/

	keys = 0

	# Extract i18n
	file = File.read("./#{line.tr("\\", "/")}")
	file.scan(/L\["(.+?)"\]/).each do |match|
		text = match.first

		i18n[text] = true
		keys += 1
	end

	puts "#{line} (#{keys} keys)"
end

puts "Total #{i18n.length}"
puts

# Turn it into a lua additive table for uploading
compiled = ""
i18n.each_key do |text|
	compiled << "L[\"#{text}\"] = true\n"
end

# Onward!
URL = URI.parse("http://www.wowace.com/addons/shadowed-unit-frames/localization/import/")

http = Net::HTTP.new(URL.host, URL.port)

request = Net::HTTP::Post.new(URL.request_uri)
request.add_field("Referer", "http://www.wowace.com/addons/shadowed-unit-frames/localization/import/")
request.set_form_data(
	"api-key" => File.read(File.expand_path("~/.curse-key")).strip,
	format: :lua_additive_table,
	language: 1,
	delete_unimported: "y",
	text: compiled
)

res = http.request(request)
puts res.header.inspect
puts res.code
puts res.body