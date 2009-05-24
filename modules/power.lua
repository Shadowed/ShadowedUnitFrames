local Power = ShadowUF:NewModule("Power")
ShadowUF:RegisterModule(Power, "powerBar", ShadowUFLocals["Power bar"], "bar")

local function updateTimer(self, elapsed)
	Power:Update(self.parent)
end

function Power:UnitEnabled(frame)
	if( not frame.visibility.powerBar ) then
		return
	end
	
	if( not frame.powerBar ) then
		frame.powerBar = ShadowUF.Units:CreateBar(frame)
	end
		
	frame:RegisterUnitEvent("UNIT_MANA", self, "Update")
	frame:RegisterUnitEvent("UNIT_RAGE", self, "Update")
	frame:RegisterUnitEvent("UNIT_ENERGY", self, "Update")
	frame:RegisterUnitEvent("UNIT_FOCUS", self, "Update")
	frame:RegisterUnitEvent("UNIT_RUNIC_POWER", self, "Update")
	frame:RegisterUnitEvent("UNIT_MAXMANA", self, "Update")
	frame:RegisterUnitEvent("UNIT_MAXRAGE", self, "Update")
	frame:RegisterUnitEvent("UNIT_MAXENERGY", self, "Update")
	frame:RegisterUnitEvent("UNIT_MAXFOCUS", self, "Update")
	frame:RegisterUnitEvent("UNIT_MAXRUNIC_POWER", self, "Update")
	frame:RegisterUnitEvent("UNIT_DISPLAYPOWER", self, "UpdateColor")
	frame:RegisterUpdateFunc(self, "UpdateAll")
	
	-- If it's the player, we'll update it on OnUpdate to make the mana increase smoothly
	if( frame.unit == "player" ) then
		frame.powerBar:SetScript("OnUpdate", updateTimer)
		frame.powerBar.parent = frame
	end
end

function Power:UnitDisabled(frame)
	frame:UnregisterAll(self)
end

function Power:UpdateColor(frame)
	local powerType = select(2, UnitPowerType(frame.unit))
	powerType = powerType == "" and "MANA" or powerType
	frame.powerBar:SetStatusBarColor(ShadowUF.db.profile.powerColors[powerType].r, ShadowUF.db.profile.powerColors[powerType].g, ShadowUF.db.profile.powerColors[powerType].b, ShadowUF.db.profile.bars.alpha)
	frame.powerBar.background:SetVertexColor(ShadowUF.db.profile.powerColors[powerType].r, ShadowUF.db.profile.powerColors[powerType].g, ShadowUF.db.profile.powerColors[powerType].b, ShadowUF.db.profile.bars.backgroundAlpha)
end

function Power:Update(frame)
	frame.powerBar:SetMinMaxValues(0, UnitPowerMax(frame.unit))
	frame.powerBar:SetValue(UnitPower(frame.unit))
end

function Power:UpdateAll(frame)
	self:Update(frame)
	self:UpdateColor(frame)
end
