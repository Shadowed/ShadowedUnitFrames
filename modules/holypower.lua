local HolyPower = setmetatable({}, {__index = ShadowUF.ComboPoints})
ShadowUF:RegisterModule(HolyPower, "holyPower", ShadowUF.L["Holy Power"], nil, "PALADIN")
local holyConfig = {max = HOLY_POWER_FULL, key = "holyPower", colorKey = "HOLYPOWER", powerType = SPELL_POWER_HOLY_POWER, eventType = "HOLY_POWER", icon = "Interface\\AddOns\\ShadowedUnitFrames\\media\\textures\\combo"}

function HolyPower:OnEnable(frame)
	frame.holyPower = frame.holyPower or CreateFrame("Frame", nil, frame)
	frame.holyPower.config = holyConfig
	frame.comboPointType = holyConfig.key

	frame:RegisterUnitEvent("UNIT_POWER", self, "Update")
	frame:RegisterUnitEvent("UNIT_MAXPOWER", self, "UpdateBarBlocks")
	frame:RegisterUnitEvent("UNIT_DISPLAYPOWER", self, "Update")
	frame:RegisterUpdateFunc(self, "Update")
end

function HolyPower:OnDisable(frame)
	frame:UnregisterAll(self)
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
	if( max > HOLY_POWER_FULL ) then
		for id=HOLY_POWER_FULL+1, max do
			if( config.isBar ) then
				pointsFrame.blocks[id]:SetVertexColor(color.r, color.g, color.b, color.a)
			else
				pointsFrame.icons[id]:SetVertexColor(color.r, color.g, color.b, color.a)
			end
		end
	end
end

function HolyPower:Update(frame, event, unit, powerType)
	if( event == "UNIT_POWER" and powerType ~= holyConfig.eventType ) then return end
	
	local points = UnitPower("player", holyConfig.powerType)
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
