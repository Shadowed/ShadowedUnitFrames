local Power = ShadowUF:NewModule("Power")
ShadowUF:RegisterModule(Power, "powerBar", ShadowUFLocals["Power bar"], "bar")

local function updateTimer(self, elapsed)
	Power.Update(self.parent, self.unit)
end


function Power:UnitEnabled(frame, unit)
	if( not frame.visibility.powerBar ) then
		return
	end
	
	if( not frame.powerBar ) then
		frame.powerBar = ShadowUF.Units:CreateBar(frame, "PowerBar")
	end
		
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
		frame.powerBar:SetScript("OnUpdate", updateTimer)
		frame.powerBar.parent = frame
		frame.powerBar.unit = unit
	end
end

function Power:UnitDisabled(frame, unit)
	frame:UnregisterAll(self.Update, self.UpdateColor)
end

function Power.UpdateColor(self, unit)
	local powerType = UnitPowerType(unit)
	self.powerBar:SetStatusBarColor(ShadowUF.db.profile.powerColor[powerType].r, ShadowUF.db.profile.powerColor[powerType].g, ShadowUF.db.profile.powerColor[powerType].b, ShadowUF.db.profile.bars.alpha)
	self.powerBar.background:SetVertexColor(ShadowUF.db.profile.powerColor[powerType].r, ShadowUF.db.profile.powerColor[powerType].g, ShadowUF.db.profile.powerColor[powerType].b, ShadowUF.db.profile.bars.backgroundAlpha)
end

function Power.Update(self, unit)
	self.powerBar:SetMinMaxValues(0, UnitPowerMax(unit))
	self.powerBar:SetValue(UnitPower(unit))
end
