local Stagger = {}
ShadowUF:RegisterModule(Stagger, "staggerBar", ShadowUF.L["Stagger bar"], true, "MONK", SPEC_MONK_BREWMASTER)

function Stagger:OnEnable(frame)
	frame.staggerBar = frame.staggerBar or ShadowUF.Units:CreateBar(frame)
	frame.staggerBar.timeElapsed = 0
	frame.staggerBar:SetScript("OnUpdate", function(self, elapsed)
		self.timeElapsed = self.timeElapsed + elapsed
		if( self.timeElapsed < 0.50 ) then return end
		self.timeElapsed = self.timeElapsed - 0.50

		Stagger:Update(self)
	end)

	frame:RegisterUnitEvent("UNIT_MAXHEALTH", self, "UpdateMinMax")
	frame:RegisterUpdateFunc(self, "UpdateMinMax")
end

function Stagger:OnDisable(frame)
	frame:UnregisterAll(self)
end

function Stagger:OnLayoutApplied(frame)
	frame.staggerBar.colorState = nil
end

function Stagger:UpdateMinMax(frame)
	frame.staggerBar.maxHealth = UnitHealthMax(frame.unit)
	frame.staggerBar:SetMinMaxValues(0, frame.staggerBar.maxHealth)

	self:Update(frame)
end

function Stagger:Update(frame)
	local stagger = UnitStagger(frame.unit)
	if( not stagger ) then return end

	-- Figure out how screwed they are
	local percent = stagger / frame.staggerBar.maxHealth
	local state
	if( percent < STAGGER_YELLOW_TRANSITION ) then
		state = "STAGGER_GREEN"
	elseif( percent < STAGGER_RED_TRANSITION ) then
		state = "STAGGER_YELLOW"
	else
		state = "STAGGER_RED"
	end

	if( state ~= frame.staggerBar.colorState ) then
		frame:SetBarColor("staggerBar", ShadowUF.db.profile.powerColors[state])
	end

	frame.staggerBar:SetValue(stagger)
end