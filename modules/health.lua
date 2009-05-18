local Health = ShadowUF:NewModule("Health")
ShadowUF:RegisterModule(Health, "healthBar", ShadowUFLocals["Health bar"], "bar")

function Health:UnitEnabled(frame, unit)
	if( not frame.visibility.healthBar ) then
		return
	end
	
	if( not frame.healthBar ) then
		frame.healthBar = ShadowUF.Units:CreateBar(frame, "HealthBar")
	end
	
	frame:RegisterUnitEvent("UNIT_HEALTH", self.Update)
	frame:RegisterUnitEvent("UNIT_MAXHEALTH", self.Update)
	frame:RegisterUnitEvent("UNIT_FACTION", self.Update)
	frame:RegisterUnitEvent("UNIT_THREAT_SITUATION_UPDATE", self.UpdateThreat)
	frame:RegisterUpdateFunc(self.Update)
	frame:RegisterUpdateFunc(self.UpdateColor)
	frame:RegisterUpdateFunc(self.UpdateThreat)
end

function Health:UnitDisabled(frame, unit)
	frame:UnregisterAll(self.Update, self.UpdateColor, self.UpdateThreat)
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
		r, g, b = ShadowUF.db.profile.healthColor.green.r, ShadowUF.db.profile.healthColor.green.g, ShadowUF.db.profile.healthColor.green.b
	elseif( percent > 0.50 ) then
		r = (ShadowUF.db.profile.healthColor.red.r - percent) * 2
		g = ShadowUF.db.profile.healthColor.green.g
	else
		r = ShadowUF.db.profile.healthColor.red.r
		g = percent * 2
	end
	
	setBarColor(healthBar, r, g, b)
end

--[[
	WoWWIki docs on this are terrible, stole these from Omen
	
	nil = the unit is not on the mob's threat list
	0 = 0-99% raw threat percentage (no indicator shown)
	1 = 100% or more raw threat percentage (yellow warning indicator shown)
	2 = tanking, other has 100% or more raw threat percentage (orange indicator shown)
	3 = tanking, all others have less than 100% raw percentage threat (red indicator shown)
]]

local invalidUnit = {["focustarget"] = true, ["targettarget"] = true, ["targettargettarget"] = true}
function Health.UpdateThreat(self, unit)
	-- This unit may contain adult siutations
	if( not invalidUnit[unit] and ShadowUF.db.profile.units[self.unitType].healthBar.colorAggro and UnitThreatSituation(unit) == 3 ) then
		setBarColor(self.healthBar, ShadowUF.db.profile.healthColor.red.r, ShadowUF.db.profile.healthColor.red.g, ShadowUF.db.profile.healthColor.red.b)
		self.healthBar.hasAggro = true
	elseif( self.healthBar.hasAggro ) then
		self.healthBar.hasAggro = nil
	end
end

function Health.UpdateColor(self, unit)
	-- Check aggro first, since it's going to override any other setting
	if( ShadowUF.db.profile.units[self.unitType].healthBar.colorAggro ) then
		Health.UpdateThreat(self, unit)
			
		if( self.healthBar.hasAggro ) then return end
	end
	
	-- Tapped by a non-party member
	self.healthBar.hasReaction = false
	
	local color
	if( not UnitIsTappedByPlayer(unit) and UnitIsTapped(unit) ) then
		color = ShadowUF.db.profile.healthColor.tapped
	elseif( ShadowUF.db.profile.units[self.unitType].healthBar.reaction and not UnitIsFriend(unit, "player") ) then
		self.healthBar.hasReaction = true
		if( UnitPlayerControlled(unit) ) then
			if( UnitCanAttack("player", unit) ) then
				color = ShadowUF.db.profile.healthColor.red
			else
				color = ShadowUF.db.profile.healthColor.enemyUnattack
			end
		elseif( UnitReaction(unit, "player") ) then
			local reaction = UnitReaction(unit, "player")
			if( reaction > 4 ) then
				color = ShadowUF.db.profile.healthColor.green
			elseif( reaction == 4 ) then
				color = ShadowUF.db.profile.healthColor.yellow
			elseif( reaction < 4 ) then
				color = ShadowUF.db.profile.healthColor.red
			end
		end
	elseif( ShadowUF.db.profile.units[self.unitType].healthBar.colorType == "class" and UnitIsPlayer(unit) ) then
		local class = select(2, UnitClass(unit))
		if( class and ShadowUF.db.profile.classColors[class] ) then
			color = ShadowUF.db.profile.classColors[class]
		end
	elseif( ShadowUF.db.profile.units[self.unitType].healthBar.colorType == "static" ) then
		color = ShadowUF.db.profile.healthColor.green
	end
	
	if( color ) then
		setBarColor(self.healthBar, color.r, color.g, color.b)
	else
		setGradient(self.healthBar, unit)
	end
end

function Health.Update(self, unit)
	local max = UnitHealthMax(unit)
	local current = UnitHealth(unit)
	local isOffline = not UnitIsConnected(unit)
	if( isOffline ) then
		current = max
	elseif( current == 1 or UnitIsDeadOrGhost(unit) ) then
		current = 0
	end
	
	self.healthBar:SetMinMaxValues(0, max)
	self.healthBar:SetValue(current)
	
	if( self.incHeal and self.incHeal.nextUpdate ) then
		self.incHeal:Hide()
	end
		
	if( isOffline ) then
		setBarColor(self.healthBar, 0.50, 0.50, 0.50)
	elseif( not self.healthBar.hasReaction and not self.healthBar.hasAggro and ShadowUF.db.profile.units[self.unitType].healthBar.colorType == "percent" ) then
		setGradient(self.healthBar, unit)
	end
end
