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
		frame:RegisterUnitEvent("UPDATE_FACTION", self.UpdateRep)
	else
		frame:RegisterEvent("UNIT_PET_EXPERIENCE", self.Update)
	end

	self.Update(frame, unit)
end

function XP.SetColor(self, unit)
	if( not self.xpBar ) then
		return
	end
	
	if( self.xpBar.type == "rep" ) then
		self.xpBar:SetStatusBarColor(FACTION_BAR_COLORS[self.xpBar.reaction].r, FACTION_BAR_COLORS[self.xpBar.reaction].g, FACTION_BAR_COLORS[self.xpBar.reaction].b, ShadowUF.db.profile.layout.general.barAlpha)
		self.xpBar.background:SetVertexColor(FACTION_BAR_COLORS[self.xpBar.reaction].r, FACTION_BAR_COLORS[self.xpBar.reaction].g, FACTION_BAR_COLORS[self.xpBar.reaction].b, ShadowUF.db.profile.layout.general.backgroundAlpha)
	else
		self.xpBar:SetStatusBarColor(ShadowUF.db.profile.layout.xpColor.normal.r, ShadowUF.db.profile.layout.xpColor.normal.g, ShadowUF.db.profile.layout.xpColor.normal.b, ShadowUF.db.profile.layout.general.barAlpha)
		self.xpBar.background:SetVertexColor(ShadowUF.db.profile.layout.xpColor.normal.r, ShadowUF.db.profile.layout.xpColor.normal.g, ShadowUF.db.profile.layout.xpColor.normal.b, ShadowUF.db.profile.layout.general.backgroundAlpha)
		self.xpBar.rested:SetStatusBarColor(ShadowUF.db.profile.layout.xpColor.rested.r, ShadowUF.db.profile.layout.xpColor.rested.g, ShadowUF.db.profile.layout.xpColor.rested.b, ShadowUF.db.profile.layout.general.barAlpha)
	end
end

function XP:LayoutApplied(frame, unit)
	self.SetColor(frame, unit)
end

-- Handles updating the bar ordering if needed
function XP.SetBarVisibility(self, shown)
	local wasShown = self.xpBar:IsShown()
	if( shown ) then
		self.xpBar.rested:Show()
		self.xpBar:Show()
	else
		self.xpBar.rested:Hide()
		self.xpBar:Hide()
	end
	
	if( wasShown and not shown or not wasShown and shown ) then
		ShadowUF.modules.Layout:SetupBars(self, ShadowUF.db.profile.layout)
	end
end

function XP.UpdateRep(self, unit)
	local name, reaction, min, max, current = GetWatchedFactionInfo()
	if( not name ) then
		XP.SetBarVisibility(self, false)
		return
	end
	
	self.xpBar:SetMinMaxValues(min, max)
	self.xpBar:SetValue(current)
	self.xpBar.type = "rep"
	self.xpBar.reaction = reaction
	self.xpBar.rested:SetMinMaxValues(0, 1)
	self.xpBar.rested:SetValue(0)

	XP.SetColor(self, unit)
	XP.SetBarVisibility(self, true)
end

function XP.Update(self, unit)
	if( unit == "pet" and UnitXPMax(unit) == 0 ) then
		XP.SetBarVisibility(self, false)
		return
	elseif( UnitLevel(unit) == MAX_PLAYER_LEVEL ) then
		XP.UpdateRep(self, unit)
		return
	end
	
	local current = UnitXP(unit)
	local min, max = math.min(0, current), UnitXPMax(unit)
	
	self.xpBar:SetMinMaxValues(min, max)
	self.xpBar:SetValue(current)
	self.xpBar.type = "xp"
	
	if( unit == "player" and GetXPExhaustion() ) then
		self.xpBar.rested:SetMinMaxValues(min, max)
		self.xpBar.rested:SetValue(math.min(current + GetXPExhaustion(), max))
	else
		self.xpBar.rested:SetMinMaxValues(0, 1)
		self.xpBar.rested:SetValue(0)
	end
	
	-- Update coloring
	XP.SetColor(self, unit)
	XP.SetBarVisibility(self, true)
end

