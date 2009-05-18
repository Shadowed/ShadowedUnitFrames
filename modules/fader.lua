local Fader = ShadowUF:NewModule("Fader")
ShadowUF:RegisterModule(Fader, "fader", ShadowUFLocals["Combat fader"])

function Fader:UnitEnabled(frame, unit)
	if( not frame.visibility.fader or ( unit ~= "player" and unit ~= "focus" and frame.unitType ~= "party" and frame.unitType ~= "raid" ) ) then return end
	
	frame:RegisterNormalEvent("PLAYER_REGEN_ENABLED", self.Update)
	frame:RegisterNormalEvent("PLAYER_REGEN_DISABLED", self.Update)
	frame:RegisterNormalEvent("PLAYER_TARGET_CHANGED", self.Update)
	frame:RegisterUnitEvent("UNIT_HEALTH", self.Update)
	frame:RegisterUnitEvent("UNIT_MANA", self.Update)
	frame:RegisterUnitEvent("UNIT_MAXHEALTH", self.Update)
	frame:RegisterUnitEvent("UNIT_MAXMANA", self.Update)
	frame:RegisterUpdateFunc(self.Update)
end

function Fader:UnitDisabled(frame, unit)
	frame:UnregisterAll(self.Update)
	frame:SetAlpha(1.0)
end

function Fader.Update(self, unit)
	if( InCombatLockdown() ) then
		self:SetAlpha(ShadowUF.db.profile.units[self.unitType].fader.combatAlpha)
		return
	end

	local inactive = true
	if( UnitPowerType(unit) == 0 and UnitPower(unit) ~= UnitPowerMax(unit) ) then
		inactive = false
	elseif( UnitHealth(unit) ~= UnitHealthMax(unit) ) then
		inactive = false
	elseif( unit == "player" and UnitExists("target") ) then
		inactive = false
	end
	
	self:SetAlpha(inactive and ShadowUF.db.profile.units[self.unitType].fader.inactiveAlpha or ShadowUF.db.profile.units[self.unitType].fader.combatAlpha)
end

