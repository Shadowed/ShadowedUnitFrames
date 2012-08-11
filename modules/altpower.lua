local AltPower = {}
ShadowUF:RegisterModule(AltPower, "altPowerBar", ShadowUF.L["Alt. Power bar"], true)

function AltPower:OnEnable(frame)
	frame.altPowerBar = frame.altPowerBar or ShadowUF.Units:CreateBar(frame)

	frame:RegisterUnitEvent("UNIT_POWER", self, "Update")
	frame:RegisterUnitEvent("UNIT_MAXPOWER", self, "Update")
	frame:RegisterUnitEvent("UNIT_POWER_BAR_SHOW", self, "UpdateVisibility")
	frame:RegisterUnitEvent("UNIT_POWER_BAR_HIDE", self, "UpdateVisibility")

	frame:RegisterUpdateFunc(self, "UpdateVisibility")
end

function AltPower:OnLayoutApplied(frame)
	if( frame.visibility.altPowerBar ) then
		local color = ShadowUF.db.profile.powerColors.ALTERNATE
		frame.altPowerBar:SetStatusBarColor(color.r, color.g, color.b, ShadowUF.db.profile.bars.alpha)
	end
end

function AltPower:OnDisable(frame)
	frame:UnregisterAll(self)
end

function AltPower:UpdateVisibility(frame)
	local barType, minPower, _, _, _, hideFromOthers = UnitAlternatePowerInfo(frame.unit)
	local visible = barType and ( frame.unitType == "player" or not hideFromOthers )
	ShadowUF.Layout:SetBarVisibility(frame, "altPowerBar", visible)
	AltPower:Update(frame, nil, nil, "ALTERNATE")
end

function AltPower:Update(frame, event, unit, type)
	if( type ~= "ALTERNATE" ) then return end

	frame.altPowerBar:SetMinMaxValues(select(2, UnitAlternatePowerInfo(frame.unit)) or 0, UnitPowerMax(frame.unit, ALTERNATE_POWER_INDEX) or 0)
	frame.altPowerBar:SetValue(UnitPower(frame.unit, ALTERNATE_POWER_INDEX) or 0)
end
