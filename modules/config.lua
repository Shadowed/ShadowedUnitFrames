local Config = ShadowUF:NewModule("Config")
local options, dialog, registered
local L = ShadowUFLocals

local function loadOptions()
	options = {
		type = "group",
		name = "Shadowed UF",
		args = {}
	}
	
	options.args.units = {
		type = "group",
		name = L["Units"],
		args = {},
	}
	
	options.args.tags = {
		type = "group",
		name = L["Tags"],
		args = {},
	}
	
	options.args.layout = {
		type = "group",
		name = L["Layout"],
		args = {},
	}
end

SLASH_SSUF1 = "/suf"
SLASH_SSUF2 = "/shadowuf"
SLASH_SSUS3 = "/shadoweduf"
SLASH_SSUS4 = "/shadowedunitframes"
SlashCmdList["SSUF"] = function(msg)
	dialog = dialog or LibStub("AceConfigDialog-3.0")

	if( not registered ) then
		if( not options ) then
			loadOptions()
		end
		
		LibStub("AceConfig-3.0"):RegisterOptionsTable("ShadowedUF", options)
		dialog:SetDefaultSize("ShadowedUF", 725, 525)
		registered = true
	end

	dialog:Open("ShadowedUF")
end
