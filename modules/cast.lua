local Cast = {}
local FADE_TIME = 0.20

ShadowUF:RegisterModule(Cast, "castBar", ShadowUFLocals["Cast bar"], true)

-- Slightly odd, I need to clean up the entire cast bar code again but for the time being this is pretty good
-- and decent proces in cleaning it up
function Cast:OnEnable(frame, unit)
	if( not frame.castBar ) then
		frame.castBar = CreateFrame("Frame", nil, frame)
		frame.castBar.bar = CreateFrame("StatusBar", nil, frame.castBar)
		frame.castBar.bar.background = frame.castBar.bar:CreateTexture(nil, "ARTWORK")
		frame.castBar.bar.background:SetHeight(0)
		frame.castBar.bar.background:SetHeight(0)
		frame.castBar.bar.background:SetAllPoints(frame.castBar.bar)
		
		frame.castBar.icon = frame.castBar.bar:CreateTexture(nil, "ARTWORK")
		frame.castBar.bar.name = frame.castBar.bar:CreateFontString(nil, "ARTWORK")
		frame.castBar.bar.time = frame.castBar.bar:CreateFontString(nil, "ARTWORK")
	end
		
	frame:RegisterUnitEvent("UNIT_SPELLCAST_START", self, "EventUpdateCast")
	frame:RegisterUnitEvent("UNIT_SPELLCAST_STOP", self, "EventStopCast")
	frame:RegisterUnitEvent("UNIT_SPELLCAST_FAILED", self, "EventStopCast")
	frame:RegisterUnitEvent("UNIT_SPELLCAST_INTERRUPTED", self, "EventInterruptCast")
	frame:RegisterUnitEvent("UNIT_SPELLCAST_DELAYED", self, "EventDelayCast")

	frame:RegisterUnitEvent("UNIT_SPELLCAST_CHANNEL_START", self, "EventUpdateChannel")
	frame:RegisterUnitEvent("UNIT_SPELLCAST_CHANNEL_STOP", self, "EventStopCast")
	frame:RegisterUnitEvent("UNIT_SPELLCAST_CHANNEL_INTERRUPTED", self, "EventInterruptCast")
	frame:RegisterUnitEvent("UNIT_SPELLCAST_CHANNEL_UPDATE", self, "EventDelayChannel")
	
	frame:RegisterUpdateFunc(self, "UpdateCurrentCast")
end

function Cast:OnLayoutApplied(frame, config)
	if( not frame.visibility.castBar ) then
		if( frame.castBar ) then
			frame.castBar.bar.name:Hide()
			frame.castBar.bar.time:Hide()
		end
		return
	end
	
	-- Set textures
	frame.castBar.bar:SetStatusBarTexture(ShadowUF.Layout.mediaPath.statusbar)
	
	ShadowUF.Layout:ToggleVisibility(frame.castBar.bar.background, config.background)
	frame.castBar.bar.background:SetVertexColor(ShadowUF.Layout.mediaPath.statusbar)
	
	-- Setup the main bar + icon
	frame.castBar.bar:ClearAllPoints()
	frame.castBar.bar:SetHeight(frame.castBar:GetHeight())
	
	-- Use the entire bars width and show the icon
	if( config.castBar.icon == "HIDE" ) then
		frame.castBar.bar:SetWidth(frame.castBar:GetWidth())
		frame.castBar.bar:SetAllPoints(frame.castBar)
		frame.castBar.icon:Hide()
	-- Shift the bar to the side and show an icon
	else
		frame.castBar.bar:SetWidth(frame.castBar:GetWidth() - frame.castBar:GetHeight())
		frame.castBar.icon:ClearAllPoints()
		frame.castBar.icon:SetWidth(frame.castBar:GetHeight())
		frame.castBar.icon:SetHeight(frame.castBar:GetHeight())
		frame.castBar.icon:Show()

		if( config.castBar.icon == "LEFT" ) then
			frame.castBar.bar:SetPoint("TOPLEFT", frame.castBar, "TOPLEFT", frame.castBar:GetHeight() + 1, 0)
			frame.castBar.icon:SetPoint("TOPRIGHT", frame.castBar.bar, "TOPLEFT", -1, 0)
		else
			frame.castBar.bar:SetPoint("TOPLEFT", frame.castBar, "TOPLEFT", 1, 0)
			frame.castBar.icon:SetPoint("TOPLEFT", frame.castBar.bar, "TOPRIGHT", 0, 0)
		end
	end
	
	-- Set the font at the very least, so it doesn't error when we set text on it even if it isn't being shown
	ShadowUF.Layout:ToggleVisibility(frame.castBar.bar.name, config.castBar.name.enabled)
	if( config.castBar.name.enabled ) then
		frame.castBar.bar.name:SetParent(frame.highFrame)
		frame.castBar.bar.name:SetWidth(frame.castBar.bar:GetWidth() * 0.75)
		frame.castBar.bar.name:SetHeight(ShadowUF.db.profile.font.size + 1)
		frame.castBar.bar.name:SetJustifyH(ShadowUF.Layout:GetJustify(config.castBar.name))

		ShadowUF.Layout:AnchorFrame(frame.castBar.bar, frame.castBar.bar.name, config.castBar.name)
		ShadowUF.Layout:SetupFontString(frame.castBar.bar.name, config.castBar.name.size)
	end
	
	ShadowUF.Layout:ToggleVisibility(frame.castBar.bar.time, config.castBar.time.enabled)
	if( config.castBar.time.enabled ) then
		frame.castBar.bar.time:SetParent(frame.highFrame)
		frame.castBar.bar.time:SetWidth(frame.castBar.bar:GetWidth() * 0.25)
		frame.castBar.bar.time:SetHeight(ShadowUF.db.profile.font.size + 1)
		frame.castBar.bar.time:SetJustifyH(ShadowUF.Layout:GetJustify(config.castBar.time))

		ShadowUF.Layout:AnchorFrame(frame.castBar.bar, frame.castBar.bar.time, config.castBar.time)
		ShadowUF.Layout:SetupFontString(frame.castBar.bar.time, config.castBar.time.size)
	end
	
	-- So we don't have to check the entire thing in an OnUpdate
	frame.castBar.bar.time.enabled = config.castBar.time.enabled
end

function Cast:OnDisable(frame, unit)
	frame:UnregisterAll(self)
end

-- Easy coloring
local function setBarColor(self, r, g, b)
	self:SetStatusBarColor(r, g, b, ShadowUF.db.profile.bars.alpha)
	self.background:SetVertexColor(r, g, b, ShadowUF.db.profile.bars.backgroundAlpha)
end

-- Cast OnUpdates
local function fadeOnUpdate(self, elapsed)
	self.fadeElapsed = self.fadeElapsed - elapsed
	
	if( self.fadeElapsed <= 0 ) then
		self.fadeElapsed = nil
		self.name:Hide()
		self.time:Hide()
		self:Hide()
	else
		local alpha = self.fadeElapsed / self.fadeStart
		self:SetAlpha(alpha)
		self.time:SetAlpha(alpha)
		self.name:SetAlpha(alpha)
	end
end

local function castOnUpdate(self, elapsed)
	local time = GetTime()
	self.elapsed = self.elapsed + (time - self.lastUpdate)
	self.lastUpdate = time
	self:SetValue(self.elapsed)
	
	if( self.elapsed <= 0 ) then
		self.elapsed = 0
	end
	
	if( self.time.enabled ) then
		local timeLeft = self.endSeconds - self.elapsed
		if( timeLeft <= 0 ) then
			self.time:SetText("0.0")
		elseif( self.pushback == 0 ) then
			self.time:SetFormattedText("%.1f", timeLeft)
		else
			self.time:SetFormattedText("|cffff0000%.1f|r %.1f", self.pushback, timeLeft)
		end
	end

	-- Cast finished, do a quick fade
	if( self.elapsed >= self.endSeconds ) then
		self.fadeElapsed = FADE_TIME
		self.fadeStart = FADE_TIME
		self:SetScript("OnUpdate", fadeOnUpdate)
	end
end

local function channelOnUpdate(self, elapsed)
	local time = GetTime()
	self.elapsed = self.elapsed - (time - self.lastUpdate)
	self.lastUpdate = time
	self:SetValue(self.elapsed)

	if( self.elapsed <= 0 ) then
		self.elapsed = 0
	end

	if( self.time.enabled ) then
		if( self.elapsed <= 0 ) then
			self.time:SetText("0.0")
		elseif( self.pushback == 0 ) then
			self.time:SetFormattedText("%.1f", self.elapsed)
		else
			self.time:SetFormattedText("|cffff0000%.1f|r %.1f", self.pushback, self.elapsed)
		end
	end

	-- Channel finished, do a quick fade
	if( self.elapsed <= 0 ) then
		self.fadeElapsed = FADE_TIME
		self:SetScript("OnUpdate", fadeOnUpdate)
	end
end

function Cast:UpdateCurrentCast(frame)
	if( UnitCastingInfo(frame.unit) ) then
		self:UpdateCast(frame, frame.unit, false, UnitCastingInfo(frame.unit))
	elseif( UnitChannelInfo(frame.unit) ) then
		self:UpdateCast(frame, frame.unit, true, UnitChannelInfo(frame.unit))
	else
		setBarColor(frame.castBar.bar, 0, 0, 0)
		
		frame.castBar.bar.spellName = nil
		frame.castBar.bar.name:Hide()
		frame.castBar.bar.time:Hide()
		frame.castBar.bar:Hide()
	end
end

-- Cast updated/changed
function Cast:EventUpdateCast(frame)
	self:UpdateCast(frame, frame.unit, false, UnitCastingInfo(frame.unit))
end

function Cast:EventDelayCast(frame)
	self:UpdateDelay(frame, UnitCastingInfo(frame.unit))
end

-- Channel updated/changed
function Cast:EventUpdateChannel(frame)
	self:UpdateCast(frame, frame.unit, true, UnitChannelInfo(frame.unit))
end

function Cast:EventDelayChannel(frame)
	self:UpdateDelay(frame, UnitChannelInfo(frame.unit))
end

-- Cast finished
function Cast:EventStopCast(frame, event, unit, spell)
	if( frame.castBar.bar.spellName ~= spell ) then return end
	if( frame.castBar.bar.time.enabled ) then
		frame.castBar.bar.time:SetText("0.0")
	end

	setBarColor(frame.castBar.bar, 1.0, 0.0, 0.0)

	frame.castBar.bar.spellName = nil
	frame.castBar.bar.fadeElapsed = FADE_TIME
	frame.castBar.bar.fadeStart = frame.castBar.bar.fadeElapsed
	frame.castBar.bar:SetScript("OnUpdate", fadeOnUpdate)
	frame.castBar.bar:SetMinMaxValues(0, 1)
	frame.castBar.bar:SetValue(1)
	frame.castBar.bar:Show()
end

-- Cast interrupted
function Cast:EventInterruptCast(frame, event, unit, spell)
	if( frame.castBar.bar.spellName ~= spell ) then return end
	
	setBarColor(frame.castBar.bar, 1.0, 0.0, 0.0)

	frame.castBar.bar.spellName = nil
	frame.castBar.bar.fadeElapsed = FADE_TIME + 0.20
	frame.castBar.bar.fadeStart = frame.castBar.bar.fadeElapsed
	frame.castBar.bar:SetScript("OnUpdate", fadeOnUpdate)
	frame.castBar.bar:SetMinMaxValues(0, 1)
	frame.castBar.bar:SetValue(1)
	frame.castBar.bar:Show()
end

function Cast:UpdateDelay(frame, spell, rank, displayName, icon, startTime, endTime)
	local cast = frame.castBar.bar
	startTime = startTime / 1000
	endTime = endTime / 1000
	
	-- For a channel, delay is a negative value so using plus is fine here
	local delay = startTime - cast.startTime
	if( not cast.isChannelled ) then
		cast.endSeconds = cast.endSeconds + delay
		cast:SetMinMaxValues(0, cast.endSeconds)
	else
		cast.elapsed = cast.elapsed + delay
	end

	cast.pushback = cast.pushback + delay
	cast.lastUpdate = GetTime()
	cast.startTime = startTime
	cast.endTime = endTime
end

-- Update the actual bar
function Cast:UpdateCast(frame, unit, channelled, spell, rank, displayName, icon, startTime, endTime)
	if( not spell ) then return end
	
	local cast = frame.castBar.bar

	-- Set casted spell
	if( ShadowUF.db.profile.units[frame.unitType].castBar.name.enabled ) then
		if( rank and rank ~= "" ) then
			cast.name:SetFormattedText("%s (%s)", spell, rank)
			cast.name:SetAlpha(1)
			cast.name:Show()
		else
			cast.name:SetText(spell)
			cast.name:SetAlpha(1)
			cast.name:Show()
		end
	end
	
	-- Show cast time
	if( cast.time.enabled ) then
		cast.time:SetAlpha(1)
		cast.time:Show()
	end
	
	-- Set spell icon
	if( ShadowUF.db.profile.units[frame.unitType].castBar.icon ~= "HIDE" ) then
		frame.castBar.icon:SetTexture(icon)
		frame.castBar.icon:Show()
	end
		
	-- Setup cast info
	cast.isChannelled = channelled
	cast.startTime = startTime / 1000
	cast.endTime = endTime / 1000
	cast.endSeconds = cast.endTime - cast.startTime
	cast.elapsed = cast.isChannelled and cast.endSeconds or 0
	cast.spellName = spell
	cast.spellRank = rank
	cast.pushback = 0
	cast.lastUpdate = cast.startTime
	cast:SetMinMaxValues(0, cast.endSeconds)
	cast:SetValue(cast.elapsed)
	cast:SetAlpha(ShadowUF.db.profile.bars.alpha)
	cast:Show()
	
	if( cast.isChannelled ) then
		setBarColor(cast, 0.25, 0.25, 1.0)
		cast:SetScript("OnUpdate", channelOnUpdate)
	else
		setBarColor(cast, 1.0, 0.70, 0.30)
		cast:SetScript("OnUpdate", castOnUpdate)
	end
end
