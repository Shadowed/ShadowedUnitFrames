local XP = ShadowUF:NewModule("XP")

function XP:OnInitialize()
	ShadowUF:RegisterModule(self)
end

function XP:UnitCreated(frame, unit)
	if( unit ~= "player" and unit ~= "pet" ) then
		return
	end
	
	frame.xpBar = ShadowUF.modules.Unit:CreateBar(frame, "XPBar")
	frame.xpBar.rested = CreateFrame("StatusBar", nil, frame)
	frame.xpBar.rested:SetAllPoints(frame.xpBar)
	frame.xpBar:SetParent(frame.xpBar.rested)
	frame.xpBar.background:SetParent(frame.xpBar.rested)
	frame:RegisterUpdateFunc(self.Update)
	
	if( unit == "player" ) then
		frame:RegisterEvent("PLAYER_XP_UPDATE", self.Update)
		frame:RegisterEvent("UPDATE_EXHAUSTION", self.Update)
		frame:RegisterEvent("PLAYER_LEVEL_UP", self.Update)
	else
		frame:RegisterEvent("UNIT_PET_EXPERIENCE", self.Update)
	end

	self.Update(frame, unit)
end

function XP:LayoutApplied(frame, unit)
	if( frame.xpBar ) then
		frame.xpBar:SetStatusBarColor(ShadowUF.db.profile.layout.xpColor.normal.r, ShadowUF.db.profile.layout.xpColor.normal.g, ShadowUF.db.profile.layout.xpColor.normal.b, ShadowUF.db.profile.layout.xpColor.normal.a)
		frame.xpBar.background:SetVertexColor(ShadowUF.db.profile.layout.xpColor.normal.r, ShadowUF.db.profile.layout.xpColor.normal.g, ShadowUF.db.profile.layout.xpColor.normal.b, ShadowUF.db.profile.layout.general.backgroundFade)
		frame.xpBar.rested:SetStatusBarColor(ShadowUF.db.profile.layout.xpColor.rested.r, ShadowUF.db.profile.layout.xpColor.rested.g, ShadowUF.db.profile.layout.xpColor.rested.b, ShadowUF.db.profile.layout.xpColor.rested.a)
	end
end

function XP.Update(self, unit)
	if( ( unit == "pet" and UnitXPMax(unit) == 0 ) or UnitLevel(unit) == MAX_PLAYER_LEVEL ) then
		self.xpBar.rested:Hide()
		self.xpBar:Hide()
		return
	end
	
	local current = UnitXP(unit)
	local min, max = math.min(0, current), UnitXPMax(unit)
	
	self.xpBar:SetMinMaxValues(min, max)
	self.xpBar:SetValue(current)
	self.xpBar:Show()
	
	if( unit == "player" and GetXPExhaustion() ) then
		self.xpBar.rested:SetMinMaxValues(min, max)
		self.xpBar.rested:SetValue(math.min(current + GetXPExhaustion(), max))
	else
		self.xpBar.rested:SetMinMaxValues(0, 1)
		self.xpBar.rested:SetValue(0)
	end
end

