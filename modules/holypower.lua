local HolyPower = setmetatable({}, {__index = ShadowUF.ComboPoints})
ShadowUF:RegisterModule(HolyPower, "holyPower", ShadowUF.L["Holy Power"], nil, "PALADIN")
local holyConfig = {max = MAX_HOLY_POWER, key = "holyPower", colorKey = "HOLYPOWER", icon = "Interface\\AddOns\\ShadowedUnitFrames\\media\\textures\\combo"}

function HolyPower:OnEnable(frame)
	frame.holyPower = frame.holyPower or CreateFrame("Frame", nil, frame)
	frame.holyPower.config = holyConfig
	frame.comboPointType = holyConfig.key

	frame:RegisterUnitEvent("UNIT_POWER", self, "Update")
	frame:RegisterUnitEvent("UNIT_DISPLAYPOWER", self, "Update")
	frame:RegisterUpdateFunc(self, "Update")
end

function HolyPower:OnDisable(frame)
	frame:UnregisterAll(self)
end

function HolyPower:Update(frame, event, unit, powerType)
	if( event == "UNIT_POWER" and powerType ~= "HOLY_POWER" ) then return end
	
	local points = UnitPower("player", SPELL_POWER_HOLY_POWER)
	-- Bar display, hide it if we don't have any combo points
	if( ShadowUF.db.profile.units[frame.unitType].holyPower.isBar ) then
		ShadowUF.Layout:SetBarVisibility(frame, "holyPower", ShadowUF.db.profile.units[frame.unitType].holyPower.showAlways or (points and points > 0))
	end
	
	for id, pointTexture in pairs(frame.holyPower.points) do
		if( id <= points ) then
			pointTexture:Show()
		else
			pointTexture:Hide()
		end
	end
end
