local IncAbsorb = setmetatable({["frameKey"] = "incAbsorb", ["colorKey"] = "incAbsorb", ["frameLevelMod"] = 2}, {__index = ShadowUF.IncHeal})
ShadowUF:RegisterModule(IncAbsorb, "incAbsorb", ShadowUF.L["Incoming absorbs"])

function IncAbsorb:OnEnable(frame)
	frame.incAbsorb = frame.incAbsorb or ShadowUF.Units:CreateBar(frame)

	frame:RegisterUnitEvent("UNIT_MAXHEALTH", self, "UpdateFrame")
	frame:RegisterUnitEvent("UNIT_HEALTH", self, "UpdateFrame")
	frame:RegisterUnitEvent("UNIT_HEALTH_FREQUENT", self, "UpdateFrame")
	frame:RegisterUnitEvent("UNIT_ABSORB_AMOUNT_CHANGED", self, "UpdateFrame")

	frame:RegisterUpdateFunc(self, "UpdateFrame")
end

function IncAbsorb:OnLayoutApplied(frame)
	if( not frame.visibility[self.frameKey] or not frame.visibility.healthBar ) then return end

	if( frame.visibility.incHeal ) then
		frame:RegisterUnitEvent("UNIT_HEAL_PREDICTION", self, "UpdateFrame")
	else
		frame:UnregisterSingleEvent("UNIT_HEAL_PREDICTION", self, "UpdateFrame")
	end

	ShadowUF.IncHeal.OnLayoutApplied(self, frame)
end

function IncAbsorb:UpdateFrame(frame)
	if( not frame.visibility[self.frameKey] or not frame.visibility.healthBar ) then return end

	local amount = UnitGetTotalAbsorbs(frame.unit) or 0
	-- Obviously we only want to add incoming heals if we have something being absorbed
	if( amount > 0 and frame.visibility.incHeal ) then
		amount = amount + (UnitGetIncomingHeals(frame.unit) or 0)
	end

	self:PositionBar(frame, amount)
end