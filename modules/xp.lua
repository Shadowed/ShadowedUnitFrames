local XP = {}
local L = ShadowUFLocals
ShadowUF:RegisterModule(XP, "xpBar", ShadowUFLocals["XP/Rep bar"], true)

local IsXPUserDisabled = IsXPUserDisabled
if( not ShadowUF.is30200 ) then
	IsXPUserDisabled = function() return false end
end

local function OnEnter(self)
	if( self.tooltip ) then
		GameTooltip:SetOwner(self, "ANCHOR_BOTTOMLEFT")
		GameTooltip:SetText(self.tooltip)
	end
end

local function OnLeave(self)
	GameTooltip:Hide()
end

function XP:OnEnable(frame)
	if( not frame.xpBar ) then
		frame.xpBar = ShadowUF.Units:CreateBar(frame)
		frame.xpBar:EnableMouse(true)
		frame.xpBar:SetScript("OnEnter", OnEnter)
		frame.xpBar:SetScript("OnLeave", OnLeave)

		frame.xpBar.rested = CreateFrame("StatusBar", nil, frame.xpBar)
		frame.xpBar.rested:SetFrameLevel(frame.xpBar:GetFrameLevel() - 1)
		frame.xpBar.rested:SetAllPoints(frame.xpBar)
	end
	
	if( frame.unitType == "player" ) then
		frame:RegisterNormalEvent("PLAYER_XP_UPDATE", self, "Update")
		frame:RegisterNormalEvent("UPDATE_EXHAUSTION", self, "Update")
		frame:RegisterNormalEvent("PLAYER_LEVEL_UP", self, "Update")
		frame:RegisterNormalEvent("ENABLE_XP_GAIN", self, "Update")
		frame:RegisterNormalEvent("DISABLE_XP_GAIN", self, "Update")
		frame:RegisterUnitEvent("UPDATE_FACTION", self, "UpdateRep")
	else
		frame:RegisterNormalEvent("UNIT_PET_EXPERIENCE", self, "Update")
	end

	frame:RegisterUpdateFunc(self, "Update")
end

function XP:OnDisable(frame)
	frame:UnregisterAll(self)
end

function XP:OnLayoutApplied(frame)
	if( frame.visibility.xpBar ) then
		frame.xpBar.rested:SetStatusBarTexture(ShadowUF.Layout.mediaPath.statusbar)
	end
end

function XP:SetColor(frame)
	if( frame.xpBar.type == "rep" ) then
		frame.xpBar:SetStatusBarColor(FACTION_BAR_COLORS[frame.xpBar.reaction].r, FACTION_BAR_COLORS[frame.xpBar.reaction].g, FACTION_BAR_COLORS[frame.xpBar.reaction].b, ShadowUF.db.profile.bars.alpha)
		frame.xpBar.background:SetVertexColor(FACTION_BAR_COLORS[frame.xpBar.reaction].r, FACTION_BAR_COLORS[frame.xpBar.reaction].g, FACTION_BAR_COLORS[frame.xpBar.reaction].b, ShadowUF.db.profile.bars.backgroundAlpha)
	else
		frame.xpBar:SetStatusBarColor(ShadowUF.db.profile.xpColors.normal.r, ShadowUF.db.profile.xpColors.normal.g, ShadowUF.db.profile.xpColors.normal.b, ShadowUF.db.profile.bars.alpha)
		frame.xpBar.background:SetVertexColor(ShadowUF.db.profile.xpColors.normal.r, ShadowUF.db.profile.xpColors.normal.g, ShadowUF.db.profile.xpColors.normal.b, ShadowUF.db.profile.bars.backgroundAlpha)
		frame.xpBar.rested:SetStatusBarColor(ShadowUF.db.profile.xpColors.rested.r, ShadowUF.db.profile.xpColors.rested.g, ShadowUF.db.profile.xpColors.rested.b, ShadowUF.db.profile.bars.alpha)
	end
end

-- Handles updating the bar visibility if needed
function XP:SetBarVisibility(frame, shown)
	local wasShown = frame.xpBar:IsShown()
	ShadowUF.Layout:ToggleVisibility(frame.xpBar, shown)
	if( wasShown and not shown or not wasShown and shown ) then
		ShadowUF.Layout:PositionWidgets(frame, ShadowUF.db.profile.units[frame.unitType])
	end
end

-- Format 5000 into 5,000
local function formatNumber(number)
	local found
	while( true ) do
		number, found = string.gsub(number, "^(-?%d+)(%d%d%d)", "%1,%2")
		if( found == 0 ) then break end
	end
	
	return number
end

function XP:UpdateRep(frame)
	local name, reaction, min, max, current = GetWatchedFactionInfo()
	if( not name ) then
		self:SetBarVisibility(frame, false)
		return
	end
	
	-- Blizzard stores faction info related to Exalted, not your current level so do a little bit of mathier to get the current
	-- reputations level information out
	current = math.abs(min - current)
	max = math.abs(min - max)
		
	frame.xpBar:SetMinMaxValues(0, max)
	frame.xpBar:SetValue(current)
	frame.xpBar.type = "rep"
	frame.xpBar.tooltip = string.format(L["%s (%s): %s/%s (%.2f%% done)"], name, GetText("FACTION_STANDING_LABEL" .. reaction, UnitSex("player")), formatNumber(current), formatNumber(max), (current / max) * 100)
	frame.xpBar.reaction = reaction
	frame.xpBar.rested:SetMinMaxValues(0, 1)
	frame.xpBar.rested:SetValue(0)

	XP:SetColor(frame)
	XP:SetBarVisibility(frame, true)
end

function XP:Update(frame)
	-- At the level cap
	if( UnitLevel(frame.unit) == MAX_PLAYER_LEVEL or IsXPUserDisabled() ) then
		if( frame.unit == "player" ) then
			self:UpdateRep(frame)
		else
			self:SetBarVisibility(frame, false)
		end
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
		frame.xpBar.tooltip = string.format(L["%s/%s (%.2f%% done), %s rested."], formatNumber(current), formatNumber(max), (current / max) * 100, formatNumber(GetXPExhaustion()))
	else
		frame.xpBar.rested:SetMinMaxValues(0, 1)
		frame.xpBar.rested:SetValue(0)
		frame.xpBar.tooltip = string.format(L["%s/%s (%.2f%% done)"], formatNumber(current), formatNumber(max), (current / max) * 100)
	end
	
	-- Update coloring
	self:SetColor(frame, frame.unit)
	self:SetBarVisibility(frame, true)
end

