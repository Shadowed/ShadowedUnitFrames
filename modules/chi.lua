local Chi = setmetatable({}, {__index = ShadowUF.ComboPoints})
ShadowUF:RegisterModule(Chi, "chi", ShadowUF.L["Chi"], nil, "MONK")
local chiConfig = {max = 6, key = "chi", colorKey = "CHI", powerType = SPELL_POWER_CHI, eventType = "CHI", icon = "Interface\\AddOns\\ShadowedUnitFrames\\media\\textures\\combo"}

function Chi:OnEnable(frame)
	frame.chi = frame.chi or CreateFrame("Frame", nil, frame)
	frame.chi.cpConfig = chiConfig
	frame.comboPointType = chiConfig.key

	frame:RegisterUnitEvent("UNIT_POWER_FREQUENT", self, "Update")
	frame:RegisterUnitEvent("UNIT_MAXPOWER", self, "UpdateBarBlocks")
	frame:RegisterUnitEvent("UNIT_DISPLAYPOWER", self, "Update")
	frame:RegisterUpdateFunc(self, "Update")
end

function Chi:OnDisable(frame)
	frame:UnregisterAll(self)
end

function Chi:OnLayoutApplied(frame, config)
	ShadowUF.ComboPoints:OnLayoutApplied(frame, config)
	self:UpdateBarBlocks(frame)
end

function Chi:GetPoints(unit)
	return UnitPower("player", chiConfig.powerType)
end