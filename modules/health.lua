local Health = ShadowUF:NewModule("Health", "AceEvent-3.0")

function Health:OnInitialize()
	self:RegisterMessage("SUF_CREATED_UNIT")
	self:RegisterMessage("SUF_LAYOUT_SET")
end

function Health:SUF_CREATED_UNIT(event, frame)
	frame.healthBar = CreateFrame("StatusBar", frame:GetName() .. "HealthBar", frame.barFrame)
	
	ShadowUF:RegisterUnitEvent("UNIT_HEALTH", frame, self.Update)
	ShadowUF:RegisterUnitEvent("UNIT_MAXHEALTH", frame, self.Update)
end

function Health:SUF_LAYOUT_SET(event, frame)
	self.Update(frame, frame.unit)
	self.UpdateColor(frame, frame.unit)
end

function Health.setGradient(healthBar, unit)
		local current, max = UnitHealth(unit), UnitHealthMax(unit)
		local percent = current / max
		local r, g, b = 0.0, 0.0, 0.0
		
		if( percent == 1.0 ) then
			r, g, b = ShadowUF.db.profile.layout.healthColor.green.r, ShadowUF.db.profile.layout.healthColor.green.g, ShadowUF.db.profile.layout.healthColor.green.b
		elseif( percent > 0.50 ) then
			r = (ShadowUF.db.profile.layout.healthColor.red.r - percent) * 2
			g = ShadowUF.db.profile.layout.healthColor.green.g
		else
			r = ShadowUF.db.profile.layout.healthColor.red.r
			g = percent * 2
		end
		
		healthBar:SetStatusBarColor(r, g, b)
end

function Health.UpdateColor(self, unit)
	local color
	-- Tapped by a non-party member
	if( not UnitIsTappedByPlayer(unit) and UnitIsTapped(unit) ) then
		color = ShadowUF.db.profile.layout.healthColor.tapped
	elseif( unit == "pet" and GetPetHappiness() ) then
		local happiness = GetPetHappiness()
		if( happiness == 3 ) then
			color = ShadowUF.db.profile.layout.healthColor.green
		elseif( happiness == 2 ) then
			color = ShadowUF.db.profile.layout.healthColor.yellow
		else
			color = ShadowUF.db.profile.layout.healthColor.red
		end
	elseif( not UnitIsPlayer(unit) and ShadowUF.db.profile.units[unit].healthBar.colorBy == "reaction" ) then
		local reaction = UnitReaction(unit, "player")
		if( reaction > 4 ) then
			color = ShadowUF.db.profile.layout.healthColor.green
		elseif( reaction == 4 ) then
			color = ShadowUF.db.profile.layout.healthColor.yellow
		elseif( reaction < 4 ) then
			color = ShadowUF.db.profile.layout.healthColor.red
		end
	elseif( ShadowUF.db.profile.units[unit].healthBar.colorBy == "class" and UnitIsPlayer(unit) ) then
		local class = select(2, UnitClass(unit))
		if( class and RAID_CLASS_COLORS[class] ) then
			color = RAID_CLASS_COLORS[class]
		end
	end
	
	if( not color ) then
		Health.setGradient(self.healthBar, unit)
	else
		self.healthBar:SetStatusBarColor(color.r, color.g, color.b)
	end
end

function Health.Update(self, unit)
	local max = UnitHealthMax(unit)
	local current = UnitHealth(unit)
	
	self.healthBar:SetMinMaxValues(0, max)
	self.healthBar:SetValue(current)
	
	if( ShadowUF.db.profile.units[unit].healthBar.colorBy == "percent" ) then
		Health.setGradient(self.healthBar, unit)
	end
end
