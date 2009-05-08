local Mana = ShadowUF:NewModule("Mana", "AceEvent-3.0")

function Mana:OnInitialize()
	self:RegisterMessage("SUF_CREATED_UNIT")
	self:RegisterMessage("SUF_LAYOUT_SET")
end

function Mana:SUF_CREATED_UNIT(event, frame)
	frame.manaBar = CreateFrame("StatusBar", nil, frame.barFrame)
	
	ShadowUF:RegisterUnitEvent("UNIT_HEALTH", frame, self.Update)
	ShadowUF:RegisterUnitEvent("UNIT_MAXHEALTH", frame, self.Update)
	ShadowUF:RegisterUnitEvent("UNIT_MANA", frame, self.Update)
	ShadowUF:RegisterUnitEvent("UNIT_RAGE", frame, self.Update)
	ShadowUF:RegisterUnitEvent("UNIT_ENERGY", frame, self.Update)
	ShadowUF:RegisterUnitEvent("UNIT_FOCUS", frame, self.Update)
	ShadowUF:RegisterUnitEvent("UNIT_RUNIC_POWER", frame, self.Update)

	ShadowUF:RegisterUnitEvent("UNIT_MAXMANA", frame, self.Update)
	ShadowUF:RegisterUnitEvent("UNIT_MAXRAGE", frame, self.Update)
	ShadowUF:RegisterUnitEvent("UNIT_MAXENERGY", frame, self.Update)
	ShadowUF:RegisterUnitEvent("UNIT_MAXFOCUS", frame, self.Update)
	ShadowUF:RegisterUnitEvent("UNIT_MAXRUNIC_POWER", frame, self.Update)

	ShadowUF:RegisterUnitEvent("UNIT_DISPLAYPOWER", frame, self.UpdateColor)
end

function Mana:SUF_LAYOUT_SET(event, frame)
	self.Update(frame, frame.unit)
	self.UpdateColor(frame, frame.unit)
end

function Mana.UpdateColor(self, unit)
	self.powerType = UnitPowerType(unit)
	self.manaBar:SetStatusBarColor(ShadowUF.db.profile.layout.powerColor[self.powerType].r, ShadowUF.db.profile.layout.powerColor[self.powerType].g, ShadowUF.db.profile.layout.powerColor[self.powerType].b)
end

function Mana.Update(self, unit)
	self.manaBar:SetMinMaxValues(0, UnitPowerMax(unit, self.powerType))
	self.manaBar:SetValue(UnitPower(unit, self.powerType))
end
