local Mana = ShadowUF:NewModule("Mana")

function Mana:OnInitialize()
	ShadowUF:RegisterModule(self)
end

local function updateTimer(self, elapsed)
	Mana.Update(self.parent, self.parent.unit)
end


function Mana:UnitCreated(frame, unit)
	frame.manaBar = ShadowUF.modules.Unit:CreateBar(frame, "ManaBar")
		
	frame:RegisterUnitEvent("UNIT_HEALTH", self.Update)
	frame:RegisterUnitEvent("UNIT_MAXHEALTH", self.Update)
	frame:RegisterUnitEvent("UNIT_MANA", self.Update)
	frame:RegisterUnitEvent("UNIT_RAGE", self.Update)
	frame:RegisterUnitEvent("UNIT_ENERGY", self.Update)
	frame:RegisterUnitEvent("UNIT_FOCUS", self.Update)
	frame:RegisterUnitEvent("UNIT_RUNIC_POWER", self.Update)
	frame:RegisterUnitEvent("UNIT_MAXMANA", self.Update)
	frame:RegisterUnitEvent("UNIT_MAXRAGE", self.Update)
	frame:RegisterUnitEvent("UNIT_MAXENERGY", self.Update)
	frame:RegisterUnitEvent("UNIT_MAXFOCUS", self.Update)
	frame:RegisterUnitEvent("UNIT_MAXRUNIC_POWER", self.Update)
	frame:RegisterUnitEvent("UNIT_DISPLAYPOWER", self.UpdateColor)
	frame:RegisterUpdateFunc(self.Update)
	frame:RegisterUpdateFunc(self.UpdateColor)

	-- If it's the player, we'll update it on OnUpdate to make the mana increase smoothly
	if( unit == "player" ) then
		frame.manaBar:SetScript("OnUpdate", updateTimer)
	end
end

function Mana.UpdateColor(self, unit)
	local powerType = UnitPowerType(unit)
	self.manaBar:SetStatusBarColor(ShadowUF.db.profile.layout.powerColor[powerType].r, ShadowUF.db.profile.layout.powerColor[powerType].g, ShadowUF.db.profile.layout.powerColor[powerType].b, 1.0)
	self.manaBar.background:SetVertexColor(ShadowUF.db.profile.layout.powerColor[powerType].r, ShadowUF.db.profile.layout.powerColor[powerType].g, ShadowUF.db.profile.layout.powerColor[powerType].b, ShadowUF.db.profile.layout.general.backgroundFade)
end

function Mana.Update(self, unit)
	self.manaBar:SetMinMaxValues(0, UnitPowerMax(unit))
	self.manaBar:SetValue(UnitPower(unit))
end
