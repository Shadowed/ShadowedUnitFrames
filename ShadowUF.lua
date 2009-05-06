--[[ 
	Shadow Unit Frames, Mayen/Selari from Illidan (US) PvP
]]

ShadowUF = LibStub("AceAddon-3.0"):NewAddon("ShadowUF", "AceEvent-3.0")

local L = ShadowUFLocals

function ShadowUF:OnInitialize()
	self.defaults = {
		profile = {
			tags = {},
			tagEvents = {},
			layouts = {},
		},
	}
	
	-- Initialize DB
	self.db = LibStub:GetLibrary("AceDB-3.0"):New("ShadowUFDB", self.defaults)
	self.db.RegisterCallback(self, "OnDatabaseShutdown", "OnDatabaseShutdown")

	self.revision = tonumber(string.match("$Revision: 1310 $", "(%d+)") or 1)
	
	-- Load SML
	self.SML = LibStub:GetLibrary("LibSharedMedia-3.0")
	
	-- Setup tag cache
	self.tags = setmetatable({}, {
		__index = function(tbl, index)
			if( ShadowUF.modules.Tags.defaultTags[index] ) then
				tbl[index] = loadstring("return " .. ShadowUF.modules.Tags.defaultTags[index])
			elseif( ShadowUF.db.profile.tags[index] ) then
				tbl[index] = loadstring("return " .. ShadowUF.db.profile.tags[index])
			else
				tbl[index] = false
			end

			return tbl[index]
		end
	})
	
	-- For consistency mostly
	self.tagEvents = self.db.profile.tagEvents
	
	-- Setup layout cache
	self.layouts = setmetatable({}, {
		__index = function(tbl, index)
			if( ShadowUF.db.profile.layouts[index] ) then
				tbl[index] = loadstring("return " .. ShadowUF.db.profile.layouts[index])
			else
				tbl[index] = false
			end
			
			return tbl[index]
		end,
	})
end

-- Database is getting ready to be written, we need to convert any changed data back into text
function ShadowUF:OnDatabaseShutdown()
end

function ShadowUF:Print(msg)
	DEFAULT_CHAT_FRAME:AddMessage("|cff33ff99ShadowUF|r: " .. msg)
end
