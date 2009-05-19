local XP = ShadowUF:NewModule("XP")
ShadowUF:RegisterModule(XP, "xpBar", ShadowUFLocals["XP/Rep bar"], "bar")

function XP:UnitEnabled(frame, unit)
	if( not frame.visibility.xpBar or ( unit ~= "player" and unit ~= "pet" ) ) then
		return
	end
	
	if( not frame.xpBar ) then
		frame.xpBar = ShadowUF.Units:CreateBar(frame)
		frame.xpBar.rested = CreateFrame("StatusBar", nil, frame.xpBar)
		frame.xpBar.rested:SetFrameLevel(frame.xpBar:GetFrameLevel() - 1)
		frame.xpBar.rested:SetAllPoints(frame.xpBar)
	end
	
	if( unit == "player" ) then
		frame:RegisterNormalEvent("PLAYER_XP_UPDATE", self.Update)
		frame:RegisterNormalEvent("UPDATE_EXHAUSTION", self.Update)
		frame:RegisterNormalEvent("PLAYER_LEVEL_UP", self.Update)
		frame:RegisterUnitEvent("UPDATE_FACTION", self.UpdateRep)
	else
		frame:RegisterNormalEvent("UNIT_PET_EXPERIENCE", self.Update)
	end

	frame:RegisterUpdateFunc(self.Update)
end

function XP:UnitDisabled(frame, unit)
	frame:UnregisterAll(self.Update, self.UpdateRep)
end

function XP:PreLayoutApplied(frame, unit)
	if( frame.xpBar ) then
		frame.xpBar.rested:SetStatusBarTexture(ShadowUF.Layout.mediaPath.statusbar)
	end
end

function XP.SetColor(self, unit)
	if( not self.xpBar ) then
		return
	end
	
	if( self.xpBar.type == "rep" ) then
		self.xpBar:SetStatusBarColor(FACTION_BAR_COLORS[self.xpBar.reaction].r, FACTION_BAR_COLORS[self.xpBar.reaction].g, FACTION_BAR_COLORS[self.xpBar.reaction].b, ShadowUF.db.profile.bars.alpha)
		self.xpBar.background:SetVertexColor(FACTION_BAR_COLORS[self.xpBar.reaction].r, FACTION_BAR_COLORS[self.xpBar.reaction].g, FACTION_BAR_COLORS[self.xpBar.reaction].b, ShadowUF.db.profile.bars.backgroundAlpha)
	else
		self.xpBar:SetStatusBarColor(ShadowUF.db.profile.xpColor.normal.r, ShadowUF.db.profile.xpColor.normal.g, ShadowUF.db.profile.xpColor.normal.b, ShadowUF.db.profile.bars.alpha)
		self.xpBar.background:SetVertexColor(ShadowUF.db.profile.xpColor.normal.r, ShadowUF.db.profile.xpColor.normal.g, ShadowUF.db.profile.xpColor.normal.b, ShadowUF.db.profile.bars.backgroundAlpha)
		self.xpBar.rested:SetStatusBarColor(ShadowUF.db.profile.xpColor.rested.r, ShadowUF.db.profile.xpColor.rested.g, ShadowUF.db.profile.xpColor.rested.b, ShadowUF.db.profile.bars.alpha)
	end
end

-- Handles updating the bar ordering if needed
function XP.SetBarVisibility(self, shown)
	local wasShown = self.xpBar:IsShown()
	ShadowUF.Layout:ToggleVisibility(self.xpBar, shown)
	if( wasShown and not shown or not wasShown and shown ) then
		ShadowUF.Layout:ApplyBars(self, ShadowUF.db.profile.units[self.unitType])
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

