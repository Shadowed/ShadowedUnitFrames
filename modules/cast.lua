local Cast = {}
local castFuncs = {["UNIT_SPELLCAST_START"] = UnitCastingInfo, ["UNIT_SPELLCAST_DELAYED"] = UnitCastingInfo, ["UNIT_SPELLCAST_CHANNEL_START"] = UnitChannelInfo, ["UNIT_SPELLCAST_CHANNEL_UPDATE"] = UnitChannelInfo}
local FADE_TIME = 0.20

ShadowUF:RegisterModule(Cast, "castBar", ShadowUFLocals["Cast bar"], true)

function Cast:UnitEnabled(frame, unit)
	-- We won't get valid information from *target, while I could do an OnUpdate, but I don't want to
	if( not frame.visibility.castBar or string.match(unit, "(%w+)target") ) then
		return
	end

	if( not frame.castBar ) then
		frame.castBar = ShadowUF.Units:CreateBar(frame)
		frame.castBar.name = frame.castBar:CreateFontString(nil, "ARTWORK")
		frame.castBar.time = frame.castBar:CreateFontString(nil, "ARTWORK")
	end
		
	frame:RegisterUnitEvent("UNIT_SPELLCAST_START", self, "EventUpdateCast")
	frame:RegisterUnitEvent("UNIT_SPELLCAST_STOP", self, "EventStopCast")
	frame:RegisterUnitEvent("UNIT_SPELLCAST_FAILED", self, "EventStopCast")
	frame:RegisterUnitEvent("UNIT_SPELLCAST_INTERRUPTED", self, "EventInterruptCast")
	frame:RegisterUnitEvent("UNIT_SPELLCAST_DELAYED", self, "EventUpdateCast")

	frame:RegisterUnitEvent("UNIT_SPELLCAST_CHANNEL_START", self, "EventUpdateCast")
	frame:RegisterUnitEvent("UNIT_SPELLCAST_CHANNEL_STOP", self, "EventStopCast")
	frame:RegisterUnitEvent("UNIT_SPELLCAST_CHANNEL_INTERRUPTED", self, "EventInterruptCast")
	frame:RegisterUnitEvent("UNIT_SPELLCAST_CHANNEL_UPDATE", self, "EventUpdateCast")
	
	frame:RegisterUpdateFunc(self, "UpdateCurrentCast")
end

function Cast:UnitDisabled(frame, unit)
	frame:UnregisterAll(self)
end

-- Easy coloring
local function setBarColor(self, r, g, b)
	self:SetStatusBarColor(r, g, b, ShadowUF.db.profile.bars.alpha)
	self.background:SetVertexColor(r, g, b, ShadowUF.db.profile.bars.backgroundAlpha)
end


-- GOOD JOB DUMBASS, YOU FORGOT TO LOCAL _
function Cast:UpdateCurrentCast(frame)
	local spell, rank, startTime, endTime, event, _
	if( UnitCastingInfo(frame.unit) ) then
		spell, rank, _, _, startTime, endTime = UnitCastingInfo(frame.unit)
		event = "UNIT_SPELLCAST_START"
	elseif( UnitChannelInfo(frame.unit) ) then
		spell, rank, _, _, startTime, endTime = UnitChannelInfo(frame.unit)
		event = "UNIT_SPELLCAST_CHANNEL_START"
	end

	if( endTime ) then
		self:UpdateCast(frame, event, unit, spell, rank, startTime, endTime)
	else
		setBarColor(frame.castBar, 0, 0, 0)
		
		frame.castBar.spellName = nil
		frame.castBar:SetScript("OnUpdate", nil)
		frame.castBar.name:Hide()
		frame.castBar.time:Hide()
		frame.castBar:SetMinMaxValues(0, 1)
		frame.castBar:SetValue(0)
	end
end

-- Cast OnUpdates
local function fadeOnUpdate(self, elapsed)
	self.fadeElapsed = self.fadeElapsed - elapsed
	self:SetAlpha(self.fadeElapsed / FADE_TIME)
	
	if( self.fadeElapsed <= 0 ) then
		self.name:Hide()
		self.time:Hide()
		self.fadeElapsed = nil
		self:SetScript("OnUpdate", nil)
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
	
	local timeLeft = self.endSeconds - self.elapsed
	if( timeLeft <= 0 ) then
		self.time:SetText("0.0")
	elseif( self.pushback == 0 ) then
		self.time:SetFormattedText("%.1f", timeLeft)
	else
		self.time:SetFormattedText("|cffff0000%.1f|r %.1f", self.pushback, timeLeft)
	end

	-- Cast finished, do a quick fade
	if( self.elapsed >= self.endSeconds ) then
		self.fadeElapsed = FADE_TIME
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

	if( self.elapsed <= 0 ) then
		self.time:SetText("0.0")
	elseif( self.pushback == 0 ) then
		self.time:SetFormattedText("%.1f", self.elapsed)
	else
		self.time:SetFormattedText("|cffff0000%.1f|r %.1f", self.pushback, self.elapsed)
	end

	-- Channel finished, do a quick fade
	if( self.elapsed <= 0 ) then
		self.fadeElapsed = FADE_TIME
		self:SetScript("OnUpdate", fadeOnUpdate)
	end
end

-- Cast started, or it was delayed
function Cast:EventUpdateCast(frame, event)
	local spell, rank, _, _, startTime, endTime = castFuncs[event](frame.unit)
	if( endTime ) then
		self:UpdateCast(frame, event, frame.unit, spell, rank, startTime, endTime)
	end
end

-- Cast finished
function Cast:EventStopCast(frame, event)
	if( not frame.castBar.spellName ) then
		return
	end
	
	setBarColor(frame.castBar, 1.0, 0.0, 0.0)

	frame.castBar.spellName = nil
	frame.castBar.fadeElapsed = FADE_TIME
	frame.castBar.time:SetText("0.0")
	frame.castBar:SetScript("OnUpdate", fadeOnUpdate)
	frame.castBar:SetMinMaxValues(0, 1)
	frame.castBar:SetValue(1)
end

-- Cast interrupted
function Cast:EventInterruptCast(frame, event)
	if( not frame.castBar.spellName ) then
		return
	end

	setBarColor(frame.castBar, 1.0, 0.0, 0.0)

	frame.castBar.spellName = nil
	frame.castBar.fadeElapsed = FADE_TIME + 0.10
	frame.castBar:SetScript("OnUpdate", fadeOnUpdate)
	frame.castBar:SetMinMaxValues(0, 1)
	frame.castBar:SetValue(1)
end

-- Update the actual bar
function Cast:UpdateCast(frame, event, unit, spell, rank, startTime, endTime)
	startTime = startTime / 1000
	endTime = endTime / 1000
	
	local cast = frame.castBar
	if( event == "UNIT_SPELLCAST_DELAYED" or event == "UNIT_SPELLCAST_CHANNEL_UPDATE" ) then
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
		return
	end
	
	-- Set casted spell
	if( rank ~= "" ) then
		cast.name:SetFormattedText("%s (%s)", spell, rank)
	else
		cast.name:SetText(spell)
	end
		
	local secondsLeft = endTime - startTime
	
	-- Setup cast info
	cast.isChannelled = (self.event == "UNIT_SPELLCAST_CHANNEL_START")
	cast.startTime = startTime
	cast.elapsed = cast.isChannelled and secondsLeft or 0
	cast.endSeconds = secondsLeft
	cast.spellName = spell
	cast.spellRank = rank
	cast.pushback = 0
	cast.lastUpdate = startTime
	cast:SetMinMaxValues(0, cast.endSeconds)
	cast:SetValue(cast.elapsed)
	cast:SetAlpha(ShadowUF.db.profile.bars.alpha)
	cast.hasCast = true
	cast.name:Show()
	cast.time:Show()
	
	if( cast.isChannelled ) then
		setBarColor(cast, 0.25, 0.25, 1.0)
		cast:SetScript("OnUpdate", channelOnUpdate)
	else
		setBarColor(cast, 1.0, 0.70, 0.30)
		cast:SetScript("OnUpdate", castOnUpdate)
	end
end
