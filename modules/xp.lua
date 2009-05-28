local XP = {}
ShadowUF:RegisterModule(XP, "xpBar", ShadowUFLocals["XP/Rep bar"], true)

function XP:OnEnable(frame)
	if( not frame.visibility.xpBar or ( frame.unitType ~= "player" and frame.unitType ~= "pet" ) ) then
		return
	end
	
	if( not frame.xpBar ) then
		frame.xpBar = ShadowUF.Units:CreateBar(frame)
		frame.xpBar.rested = CreateFrame("StatusBar", nil, frame.xpBar)
		frame.xpBar.rested:SetFrameLevel(frame.xpBar:GetFrameLevel() - 1)
		frame.xpBar.rested:SetAllPoints(frame.xpBar)
	end
	
	if( frame.unitType == "player" ) then
		frame:RegisterNormalEvent("PLAYER_XP_UPDATE", self, "Update")
		frame:RegisterNormalEvent("UPDATE_EXHAUSTION", self, "Update")
		frame:RegisterNormalEvent("PLAYER_LEVEL_UP", self, "Update")
		frame:RegisterUnitEvent("UPDATE_FACTION", self, "UpdateRep")
	else
		frame:RegisterNormalEvent("UNIT_PET_EXPERIENCE", self, "Update")
	end

	frame:RegisterUpdateFunc(self, "Update")
end

function XP:OnDisable(frame)
	frame:UnregisterAll(self)
end

function XP:OnPreLayoutApply(frame)
	if( frame.xpBar ) then
		frame.xpBar.rested:SetStatusBarTexture(ShadowUF.Layout.mediaPath.statusbar)
	end
end

function XP:SetColor(frame)
	if( not frame.xpBar ) then
		return
	end
	
	if( frame.xpBar.type == "rep" ) then
		frame.xpBar:SetStatusBarColor(FACTION_BAR_COLORS[frame.xpBar.reaction].r, FACTION_BAR_COLORS[frame.xpBar.reaction].g, FACTION_BAR_COLORS[frame.xpBar.reaction].b, ShadowUF.db.profile.bars.alpha)
		frame.xpBar.background:SetVertexColor(FACTION_BAR_COLORS[frame.xpBar.reaction].r, FACTION_BAR_COLORS[frame.xpBar.reaction].g, FACTION_BAR_COLORS[frame.xpBar.reaction].b, ShadowUF.db.profile.bars.backgroundAlpha)
	else
		frame.xpBar:SetStatusBarColor(ShadowUF.db.profile.xpColors.normal.r, ShadowUF.db.profile.xpColors.normal.g, ShadowUF.db.profile.xpColors.normal.b, ShadowUF.db.profile.bars.alpha)
		frame.xpBar.background:SetVertexColor(ShadowUF.db.profile.xpColors.normal.r, ShadowUF.db.profile.xpColors.normal.g, ShadowUF.db.profile.xpColors.normal.b, ShadowUF.db.profile.bars.backgroundAlpha)
		frame.xpBar.rested:SetStatusBarColor(ShadowUF.db.profile.xpColors.rested.r, ShadowUF.db.profile.xpColors.rested.g, ShadowUF.db.profile.xpColors.rested.b, ShadowUF.db.profile.bars.alpha)
	end
end

-- Handles updating the bar ordering if needed
function XP:SetBarVisibility(frame, shown)
	local wasShown = frame.xpBar:IsShown()
	ShadowUF.Layout:ToggleVisibility(frame.xpBar, shown)
	if( wasShown and not shown or not wasShown and shown ) then
		ShadowUF.Layout:ApplyBars(frame, ShadowUF.db.profile.units[frame.unitType])
	end
end

function XP:UpdateRep(frame)
	local name, reaction, min, max, current = GetWatchedFactionInfo()
	if( not name ) then
		XP:SetBarVisibility(frame, false)
		return
	end
	
	frame.xpBar:SetMinMaxValues(min, max)
	frame.xpBar:SetValue(current)
	frame.xpBar.type = "rep"
	frame.xpBar.reaction = reaction
	frame.xpBar.rested:SetMinMaxValues(0, 1)
	frame.xpBar.rested:SetValue(0)

	XP:SetColor(frame)
	XP:SetBarVisibility(frame, true)
end

function XP:Update(frame)
	if( frame.unit == "pet" and UnitXPMax(frame.unit) == 0 ) then
		self:SetBarVisibility(frame, false)
		return
	elseif( UnitLevel(frame.unit) == MAX_PLAYER_LEVEL ) then
		self:UpdateRep(frame)
		return
	end
	
	local current = UnitXP(frame.unit)
	local min, max = math.min(0, current), UnitXPMax(frame.unit)
	
	frame.xpBar:SetMinMaxValues(min, max)
	frame.xpBar:SetValue(current)
	frame.xpBar.type = "xp"
	
	if( frame.unit == "player" and GetXPExhaustion() ) then
		frame.xpBar.rested:SetMinMaxValues(min, max)
		frame.xpBar.rested:SetValue(math.min(current + GetXPExhaustion(), max))
	else
		frame.xpBar.rested:SetMinMaxValues(0, 1)
		frame.xpBar.rested:SetValue(0)
	end
	
	-- Update coloring
	self:SetColor(frame, frame.unit)
	self:SetBarVisibility(frame, true)
end

