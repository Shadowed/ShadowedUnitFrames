local Cast = ShadowUF:NewModule("Cast")
local castFuncs = {["UNIT_SPELLCAST_START"] = UnitCastingInfo, ["UNIT_SPELLCAST_DELAYED"] = UnitCastingInfo, ["UNIT_SPELLCAST_CHANNEL_START"] = UnitChannelInfo, ["UNIT_SPELLCAST_CHANNEL_UPDATE"] = UnitChannelInfo}
local FADE_TIME = 0.20

ShadowUF:RegisterModule(Cast, "castBar", ShadowUFLocals["Cast bar"], "bar")

local function setBarColor(self, r, g, b)
	self:SetStatusBarColor(r, g, b, ShadowUF.db.profile.bars.alpha)
	self.background:SetVertexColor(r, g, b, ShadowUF.db.profile.bars.backgroundAlpha)
end

function Cast:UnitEnabled(frame, unit)
	-- We won't get valid information from *target, while I could do an OnUpdate, but I don't want to
	if( not frame.visibility.castBar or string.match(unit, "(%w+)target") ) then
		return
	end

	frame.castBar = frame.castBar or ShadowUF.Units:CreateBar(frame, "CastBar")
	frame.castBar.name = frame.castBar.name or frame.castBar:CreateFontString(nil, "OVERLAY")
	frame.castBar.time = frame.castBar.time or frame.castBar:CreateFontString(nil, "OVERLAY")

	frame:RegisterUnitEvent("UNIT_SPELLCAST_START", self.EventUpdateCast)
	frame:RegisterUnitEvent("UNIT_SPELLCAST_STOP", self.EventStopCast)
	frame:RegisterUnitEvent("UNIT_SPELLCAST_FAILED", self.EventStopCast)
	frame:RegisterUnitEvent("UNIT_SPELLCAST_INTERRUPTED", self.EventInterruptCast)
	frame:RegisterUnitEvent("UNIT_SPELLCAST_DELAYED", self.EventUpdateCast)

	frame:RegisterUnitEvent("UNIT_SPELLCAST_CHANNEL_START", self.EventUpdateCast)
	frame:RegisterUnitEvent("UNIT_SPELLCAST_CHANNEL_STOP", self.EventStopCast)
	frame:RegisterUnitEvent("UNIT_SPELLCAST_CHANNEL_INTERRUPTED", self.EventInterruptCast)
	frame:RegisterUnitEvent("UNIT_SPELLCAST_CHANNEL_UPDATE", self.EventUpdateCast)
	
	frame:RegisterUpdateFunc(self.UpdateCurrentCast)
end

function Cast:UnitDisabled(frame, unit)
	frame:UnregisterAll(self.EventUpdateCast, self.EventStopCast, self.EventInterruptCast, self.EventUpdateCast, self.UpdateCurrentCast)
end

function Cast.UpdateCurrentCast(self, unit)
	local spell, rank, startTime, endTime
	if( UnitCastingInfo(unit) ) then
		spell, rank, _, _, startTime, endTime = UnitCastingInfo(unit)
		self.event = "UNIT_SPELLCAST_START"
	elseif( UnitChannelInfo(unit) ) then
		spell, rank, _, _, startTime, endTime = UnitChannelInfo(unit)
		self.event = "UNIT_SPELLCAST_CHANNEL_START"
	end

	if( endTime ) then
		Cast:UpdateCast(self, unit, spell, rank, startTime, endTime)
	else
		setBarColor(self.castBar, 0, 0, 0)
		
		self.castBar.name:Hide()
		self.castBar.time:Hide()
		self.castBar:SetValue(0)
		self.castBar:SetScript("OnUpdate", nil)
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
	
	if( self.pushback == 0 ) then
		self.time:SetFormattedText("%.1f", self.endSeconds - self.elapsed)
	else
		self.time:SetFormattedText("|cffff0000%.1f|r %.1f", self.pushback, self.endSeconds - self.elapsed)
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

	if( self.pushback == 0 ) then
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
function Cast.EventUpdateCast(self, unit)
	local spell, rank, _, _, startTime, endTime = castFuncs[self.event](unit)
	if( endTime ) then
		Cast:UpdateCast(self, unit, spell, rank, startTime, endTime)
	end
end

-- Cast finished
function Cast.EventStopCast(self, unit)
	if( self.castBar.fadeElapsed or not self.castBar.hasCat ) then
		return
	end
	
	self.castBar.hasCast = nil
	self.castBar.fadeElapsed = FADE_TIME
	setBarColor(self.castBar, 1.0, 0.0, 0.0)
	self.castBar:SetScript("OnUpdate", fadeOnUpdate)
	self.castBar:SetMinMaxValues(0, 1)
	self.castBar:SetValue(1)
end

-- Cast interrupted
function Cast.EventInterruptCast(self, unit)
	if( self.castBar.fadeElapsed or not self.castBar.hasCast ) then
		return
	end

	self.castBar.hasCast = nil
	self.castBar.fadeElapsed = FADE_TIME + 0.10
	setBarColor(self.castBar, 1.0, 0.0, 0.0)
	self.castBar:SetScript("OnUpdate", fadeOnUpdate)
	self.castBar:SetMinMaxValues(0, 1)
	self.castBar:SetValue(1)
end

-- Update the actual bar
function Cast:UpdateCast(frame, unit, spell, rank, startTime, endTime)
	local cast = frame.castBar
	if( frame.event == "UNIT_SPELLCAST_DELAYED" or frame.event == "UNIT_SPELLCAST_CHANNEL_UPDATE" ) then
		if( cast.hasCast ) then
			-- For a channel, delay is a negative value so using plus is fine here
			local delay = ( startTime - cast.startTime ) / 1000
			if( not cast.isChannelled ) then
				cast.endSeconds = cast.endSeconds + delay
				cast:SetMinMaxValues(0, cast.endSeconds)
			else
				cast.elapsed = cast.elapsed + delay
			end

			cast.pushback = cast.pushback + delay
			cast.lastUpdate = GetTime()
		end
		return
	end
	
	-- Set casted spell
	if( rank ~= "" ) then
		cast.name:SetFormattedText("%s (%s)", spell, rank)
	else
		cast.name:SetText(spell)
	end
	
	local secondsLeft = (endTime / 1000) - GetTime()
		
	-- Setup cast info
	cast.isChannelled = (self.event == "UNIT_SPELLCAST_CHANNEL_START")
	cast.startTime = startTime
	cast.elapsed = cast.isChannelled and secondsLeft or 0
	cast.endSeconds = secondsLeft
	cast.spellName = spell
	cast.spellRank = rank
	cast.pushback = 0
	cast.lastUpdate = GetTime()
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
