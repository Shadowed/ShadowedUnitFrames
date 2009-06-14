local Health = {}
ShadowUF:RegisterModule(Health, "healthBar", ShadowUFLocals["Health bar"], true)

function Health:OnEnable(frame)
	if( not frame.healthBar ) then
		frame.healthBar = ShadowUF.Units:CreateBar(frame)
	end
	
	frame:RegisterUnitEvent("UNIT_HEALTH", self, "Update")
	frame:RegisterUnitEvent("UNIT_MAXHEALTH", self, "Update")
	frame:RegisterUnitEvent("UNIT_FACTION", self, "UpdateColor")
	frame:RegisterUnitEvent("UNIT_THREAT_SITUATION_UPDATE", self, "UpdateThreat")
	
	frame:RegisterUpdateFunc(self, "UpdateColor")
	frame:RegisterUpdateFunc(self, "Update")

	if( ShadowUF.db.profile.units[frame.unitType].healthBar.predicted ) then
		frame.healthBar:SetScript("OnUpdate", updateTimer)
		frame.healthBar.parent = frame
	else
		frame.healthBar:SetScript("OnUpdate", nil)
	end
end

function Health:OnDisable(frame)
	frame:UnregisterAll(self)
end

local function setBarColor(bar, r, g, b)
	bar:SetStatusBarColor(r, g, b, ShadowUF.db.profile.bars.alpha)
	bar.background:SetVertexColor(r, g, b, ShadowUF.db.profile.bars.backgroundAlpha)
end

local function setGradient(healthBar, unit)
	local current, max = UnitHealth(unit), UnitHealthMax(unit)
	local percent = current / max
	local r, g, b = 0, 0, 0
	
	if( percent == 1.0 ) then
		r, g, b = ShadowUF.db.profile.healthColors.green.r, ShadowUF.db.profile.healthColors.green.g, ShadowUF.db.profile.healthColors.green.b
	elseif( percent > 0.50 ) then
		r = (ShadowUF.db.profile.healthColors.red.r - percent) * 2
		g = ShadowUF.db.profile.healthColors.green.g
	else
		r = ShadowUF.db.profile.healthColors.red.r
		g = percent * 2
	end
	
	setBarColor(healthBar, r, g, b)
end

-- The other checks don't need to be as accurate as the bar/gradient are
local function updateTimer(self)
	local frame = self.parent
	frame.healthBar:SetMinMaxValues(0, UnitHealthMax(frame.unit))
	frame.healthBar:SetValue(UnitHealth(frame.unit))

	if( not frame.healthBar.wasOffline and frame.healthBar.hasPercent ) then
		setGradient(frame.healthBar, frame.unit)
	end
end

--[[
	WoWWIki docs on this are terrible, stole these from Omen
	
	nil = the unit is not on the mob's threat list
	0 = 0-99% raw threat percentage (no indicator shown)
	1 = 100% or more raw threat percentage (yellow warning indicator shown)
	2 = tanking, other has 100% or more raw threat percentage (orange indicator shown)
	3 = tanking, all others have less than 100% raw percentage threat (red indicator shown)
]]

local invalidUnit = {["partytarget"] = true, ["focustarget"] = true, ["targettarget"] = true, ["targettargettarget"] = true}
function Health:UpdateThreat(frame)
	if( not invalidUnit[frame.unitType] and ShadowUF.db.profile.units[frame.unitType].healthBar.colorAggro and UnitThreatSituation(frame.unit) == 3 ) then
		setBarColor(frame.healthBar, ShadowUF.db.profile.healthColors.red.r, ShadowUF.db.profile.healthColors.red.g, ShadowUF.db.profile.healthColors.red.b)
		frame.healthBar.hasAggro = true
	elseif( frame.healthBar.hasAggro ) then
		frame.healthBar.hasAggro = nil
		self:UpdateColor(frame)
	end
end

   
function Health:UpdateColor(frame)
	-- Check aggro first, since it's going to override any other setting
	if( ShadowUF.db.profile.units[frame.unitType].healthBar.colorAggro ) then
		self:UpdateThreat(frame)
		if( frame.healthBar.hasAggro ) then return end
	end
	
	-- Tapped by a non-party member
	frame.healthBar.hasReaction = false
	frame.healthBar.wasOffline = false
	
	local color
	local unit = frame.unit
	if( not UnitIsConnected(unit) ) then
		frame.healthBar.wasOffline = true
		setBarColor(frame.healthBar, 0.50, 0.50, 0.50)
		return
	elseif( frame.inVehicle ) then
		color = ShadowUF.db.profile.classColors.VEHICLE
	elseif( not UnitIsTappedByPlayer(unit) and UnitIsTapped(unit) and UnitCanAttack("player", unit) ) then
		color = ShadowUF.db.profile.healthColors.tapped
	elseif( ShadowUF.db.profile.units[frame.unitType].healthBar.reaction and ( not UnitIsPlayer(unit) or not UnitIsFriend(unit, "player") ) ) then
		frame.healthBar.hasReaction = true
		if( not UnitIsFriend(unit, "player") and UnitPlayerControlled(unit) ) then
			if( UnitCanAttack("player", unit) ) then
				color = ShadowUF.db.profile.healthColors.hostile
			else
				color = ShadowUF.db.profile.healthColors.enemyUnattack
			end
		elseif( UnitReaction(unit, "player") ) then
			local reaction = UnitReaction(unit, "player")
			if( reaction > 4 ) then
				color = ShadowUF.db.profile.healthColors.friendly
			elseif( reaction == 4 ) then
				color = ShadowUF.db.profile.healthColors.neutral
			elseif( reaction < 4 ) then
				color = ShadowUF.db.profile.healthColors.hostile
			end
		end
	elseif( ShadowUF.db.profile.units[frame.unitType].healthBar.colorType == "class" and ( UnitIsPlayer(unit) or UnitCreatureFamily(unit) ) ) then
		if( UnitCreatureFamily(unit) ) then
			color = ShadowUF.db.profile.classColors.PET
		else
			local class = select(2, UnitClass(unit))
			if( class and ShadowUF.db.profile.classColors[class] ) then
				color = ShadowUF.db.profile.classColors[class]
			end
		end
	elseif( ShadowUF.db.profile.units[frame.unitType].healthBar.colorType == "static" ) then
		color = ShadowUF.db.profile.healthColors.green
	end
	
	if( color ) then
		frame.healthBar.hasPercent = false
		setBarColor(frame.healthBar, color.r, color.g, color.b)
	else
		frame.healthBar.hasPercent = true
		setGradient(frame.healthBar, unit)
	end
end

function Health:Update(frame)
	local unit = frame.unit
	local max = UnitHealthMax(unit)
	local current = UnitHealth(unit)
	local isOffline = not UnitIsConnected(unit)
	if( isOffline ) then
		current = max
	elseif( UnitIsDeadOrGhost(unit) ) then
		current = 0
	end
	
	frame.healthBar:SetMinMaxValues(0, max)
	frame.healthBar:SetValue(current)
	
	if( frame.incHeal and frame.incHeal.nextUpdate ) then
		frame.incHeal:Hide()
	end
		
	-- Unit is offline, fill bar up + grey it
	if( isOffline ) then
		frame.healthBar.wasOffline = true
		setBarColor(frame.healthBar, 0.50, 0.50, 0.50)
	-- The unit was offline, but they no longer are so we need to do a forced color update
	elseif( frame.healthBar.wasOffline ) then
		frame.healthBar.wasOffline = false
		self:UpdateColor(frame)
	-- Color health by percentage
	elseif( frame.healthBar.hasPercent ) then
		setGradient(frame.healthBar, unit)
	end
end
