local Souls = setmetatable({}, {__index = ShadowUF.ComboPoints})
ShadowUF:RegisterModule(Souls, "soulShards", ShadowUF.L["Soul Shards"], nil, "WARLOCK")
local soulsConfig = {max = SHARD_BAR_NUM_SHARDS, key = "soulShards", colorKey = "SOULSHARDS", icon = "Interface\\AddOns\\ShadowedUnitFrames\\media\\textures\\shard"}

function Souls:OnEnable(frame)
	frame.soulShards = frame.soulShards or CreateFrame("Frame", nil, frame)
	frame.soulShards.config = soulsConfig
	frame.comboPointType = soulsConfig.key

	frame:RegisterUnitEvent("UNIT_POWER", self, "Update")
	frame:RegisterUnitEvent("UNIT_DISPLAYPOWER", self, "Update")
	frame:RegisterUpdateFunc(self, "Update")
end

function Souls:OnDisable(frame)
	frame:UnregisterAll(self)
end

function Souls:Update(frame, event, unit, powerType)
	if( event == "UNIT_POWER" and powerType ~= "SOUL_SHARDS" ) then return end
	
	local points = UnitPower("player", SPELL_POWER_SOUL_SHARDS)
	-- Bar display, hide it if we don't have any soul shards
	if( ShadowUF.db.profile.units[frame.unitType].soulShards.isBar ) then
		ShadowUF.Layout:SetBarVisibility(frame, "soulShards", ShadowUF.db.profile.units[frame.unitType].soulShards.showAlways or (points and points > 0))
	end
	
	for id, pointTexture in pairs(frame.soulShards.points) do
		if( id <= points ) then
			pointTexture:Show()
		else
			pointTexture:Hide()
		end
	end
end
