if( not ShadowUF.ComboPoints ) then return end

local HolyPower = setmetatable({}, {__index = ShadowUF.ComboPoints})
ShadowUF:RegisterModule(HolyPower, "holyPower", ShadowUF.L["Holy Power"], nil, "PALADIN", SPEC_PALADIN_RETRIBUTION, PALADINPOWERBAR_SHOW_LEVEL)
local holyConfig = {max = 5, key = "holyPower", colorKey = "HOLYPOWER", powerType = SPELL_POWER_HOLY_POWER, eventType = "HOLY_POWER", icon = "Interface\\AddOns\\ShadowedUnitFrames\\media\\textures\\combo"}

function HolyPower:OnEnable(frame)
	frame.holyPower = frame.holyPower or CreateFrame("Frame", nil, frame)
	frame.holyPower.cpConfig = holyConfig

	frame:RegisterUnitEvent("UNIT_POWER_FREQUENT", self, "Update")
	frame:RegisterUnitEvent("UNIT_MAXPOWER", self, "UpdateBarBlocks")
	frame:RegisterUnitEvent("UNIT_DISPLAYPOWER", self, "Update")
	frame:RegisterUpdateFunc(self, "Update")
	frame:RegisterUpdateFunc(self, "UpdateBarBlocks")

	holyConfig.max = UnitPowerMax("player", holyConfig.powerType)
end

function HolyPower:OnLayoutApplied(frame, config)
	ShadowUF.ComboPoints.OnLayoutApplied(self, frame, config)
	self:UpdateBarBlocks(frame)
end

function HolyPower:UpdateBarBlocks(frame, event, unit, powerType)
	local pointsFrame = frame[self:GetComboPointType()]
	if( not pointsFrame or ( event and powerType ~= holyConfig.eventType ) ) then return end

	ShadowUF.ComboPoints.UpdateBarBlocks(self, frame)

	local config = ShadowUF.db.profile.units[frame.unitType].holyPower
	local color = ShadowUF.db.profile.powerColors["BANKEDHOLYPOWER"]

	local max = UnitPowerMax("player", holyConfig.powerType)
	if( max == 5 ) then
		for id=4, 5 do
			if( config.isBar ) then
				pointsFrame.blocks[id]:SetVertexColor(color.r, color.g, color.b)
			else
				pointsFrame.icons[id]:SetVertexColor(color.r, color.g, color.b)
			end
		end
	end
end

function HolyPower:GetComboPointType()
	return "holyPower"
end

function HolyPower:GetPoints(unit)
	return UnitPower("player", holyConfig.powerType)
end