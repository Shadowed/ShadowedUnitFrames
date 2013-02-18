local HolyPower = setmetatable({}, {__index = ShadowUF.ComboPoints})
ShadowUF:RegisterModule(HolyPower, "holyPower", ShadowUF.L["Holy Power"], nil, "PALADIN", nil, PALADINPOWERBAR_SHOW_LEVEL)
local holyConfig = {max = HOLY_POWER_FULL, key = "holyPower", colorKey = "HOLYPOWER", powerType = SPELL_POWER_HOLY_POWER, eventType = "HOLY_POWER", icon = "Interface\\AddOns\\ShadowedUnitFrames\\media\\textures\\combo"}

function HolyPower:OnEnable(frame)
	frame.holyPower = frame.holyPower or CreateFrame("Frame", nil, frame)
	frame.holyPower.config = holyConfig
	frame.comboPointType = holyConfig.key

	frame:RegisterUnitEvent("UNIT_POWER_FREQUENT", self, "Update")
	frame:RegisterUnitEvent("UNIT_MAXPOWER", self, "UpdateBarBlocks")
	frame:RegisterUnitEvent("UNIT_DISPLAYPOWER", self, "Update")
	frame:RegisterUpdateFunc(self, "Update")
	frame:RegisterUpdateFunc(self, "UpdateBarBlocks")

	holyConfig.max = UnitPowerMax("player", holyConfig.powerType)
end

function HolyPower:OnLayoutApplied(frame, config)
	ShadowUF.ComboPoints:OnLayoutApplied(frame, config)
	self:UpdateBarBlocks(frame)
end

function HolyPower:UpdateBarBlocks(frame, event, unit, powerType)
	local pointsFrame = frame[frame.comboPointType]
	if( not pointsFrame or frame.comboPointType ~= holyConfig.key ) then return end
	if( event and powerType ~= holyConfig.eventType ) then return end

	ShadowUF.ComboPoints:UpdateBarBlocks(frame)

	local config = ShadowUF.db.profile.units[frame.unitType].holyPower
	local color = ShadowUF.db.profile.powerColors["BANKEDHOLYPOWER"]

	local max = UnitPowerMax("player", holyConfig.powerType)
	if( max > 0 and max > HOLY_POWER_FULL ) then
		for id=HOLY_POWER_FULL+1, max do
			if( config.isBar ) then
				pointsFrame.blocks[id]:SetVertexColor(color.r, color.g, color.b)
			else
				pointsFrame.icons[id]:SetVertexColor(color.r, color.g, color.b)
			end
		end
	end
end

function HolyPower:GetPoints(unit)
	return UnitPower("player", holyConfig.powerType)
end