local DemonicFury = {}
ShadowUF:RegisterModule(DemonicFury, "demonicFuryBar", ShadowUF.L["Demonic Fury"], true, "WARLOCK", SPEC_WARLOCK_DEMONOLOGY)

function DemonicFury:OnEnable(frame)
	frame.demonicFuryBar = frame.demonicFuryBar or ShadowUF.Units:CreateBar(frame)

	frame:RegisterUnitEvent("UNIT_POWER_FREQUENT", self, "Update")
	frame:RegisterUnitEvent("UNIT_MAXPOWER", self, "UpdateMax")

	frame:RegisterUpdateFunc(self, "Update")
	frame:RegisterUpdateFunc(self, "UpdateMax")
end

function DemonicFury:OnLayoutApplied(frame)
	if( frame.visibility.demonicFuryBar ) then
		local color = ShadowUF.db.profile.powerColors.DEMONICFURY
		frame.demonicFuryBar:SetStatusBarColor(color.r, color.g, color.b, ShadowUF.db.profile.bars.alpha)
	end
end

function DemonicFury:OnDisable(frame)
	frame:UnregisterAll(self)
end

function DemonicFury:UpdateMax(frame, event, unit, powerType)
	if( event and powerType ~= "DEMONIC_FURY" ) then return end
	
	frame.demonicFuryBar:SetMinMaxValues(0, UnitPowerMax("player", SPELL_POWER_DEMONIC_FURY) or 0)
	frame.demonicFuryBar:SetValue(UnitPower("player", SPELL_POWER_DEMONIC_FURY) or 0)
end

function DemonicFury:Update(frame, event, unit, powerType)
	if( event and powerType ~= "DEMONIC_FURY" ) then return end

	frame.demonicFuryBar:SetValue(UnitPower("player", SPELL_POWER_DEMONIC_FURY) or 0)
end