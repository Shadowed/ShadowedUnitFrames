local ADDON_SLUG = string.match(io.open(".git/config"):read("*all"), "git%.wowace%.com:wow/(.-)/mainline%.git")
--local CURSE_API_KEY = ""
-- And you though I would let you steal my API key!
dofile("../TestCode/api-key.lua")

local TOC_FILE

-- Check windows first
local noLines = true
for file in io.popen(string.format("dir /B \"./\"")):lines() do
	noLines = false

	if( string.match(file, "(.+)%.toc") ) then
		TOC_FILE = file
		break
	end
end

-- Now check OSX
if( noLines ) then
	for file in io.popen(string.format("ls -1 \"./\"")):lines() do
		if( string.match(file, "(.+)%.toc") ) then
			TOC_FILE = file
			break
		end
	end
end

if( not TOC_FILE ) then
	print("Failed to find toc file.")
	return
end

-- Parse through the TOC file so we know what to scan
local ignore
local localizedKeys = {}
for text in io.lines(TOC_FILE) do
	if( string.match(text, "#@no%-lib%-strip@") ) then
		ignore = true
	elseif( string.match(text, "#@end%-no%-lib%-strip@") ) then
		ignore = nil
	end
	
	if( not ignore and not string.match(text, "^localization") and string.match(text, "%.lua$") ) then
		local contents = io.open(text):read("*all")
		
		for match in string.gmatch(contents, "L%[\"(.-)%\"]") do
			localizedKeys[match] = true
		end
	end
end

-- Compile it into string form
local totalLocalizedKeys = 0
local localization = "{"
for key in pairs(localizedKeys) do
	localization = string.format("%s\n[\"%s\"] = \"%s\",", localization, key, key)
	totalLocalizedKeys = totalLocalizedKeys + 1
end

localization = localization .. "\n}"

-- Send it all off to the localizer script
local http = require("socket.http")
local ltn = require("ltn12")

local addonData = {
	["format"] = "lua_table",
	["language"] = "1",
	["delete_unimported"] = "y",
	["text"] = localization,
}

-- Send it off
local boundary = "-------" .. os.time()
local source = {}
local body = ""

for key, data in pairs(addonData) do
	body = body .. "--" .. boundary .. "\r\n"
	body = body .. "Content-Disposition: form-data; name=\"" .. key .. "\"\r\n\r\n"
	body = body .. data .. "\r\n"
end

body = body .. "--" .. boundary .. "\r\n"

http.request({
	method = "POST",
	url = string.format("http://www.wowace.com/addons/%s/localization/import/?api-key=%s", ADDON_SLUG, CURSE_API_KEY),
	sink = ltn12.sink.table(source),
	source = ltn12.source.string(body),
	headers = {
		["Content-Type"] = string.format("multipart/form-data; boundary=\"%s\"", boundary),
		["Content-Length"] = string.len(body),
	},
})

local VALID_LOCALIZATION = string.format("<a href=\"/addons/%s/localization/phrases/", ADDON_SLUG)
--local file = io.open("test.txt", "w")
for _, text in pairs(source) do
	if( string.match(text, "Redirecting%.%.%.") ) then
		print(string.format("Localization uploaded for %s, %s keys!", ADDON_SLUG, totalLocalizedKeys))
		return
	end
	--file:write(text .. "\n")
end

print(string.format("Failed to localize for %s :(", ADDON_SLUG))
