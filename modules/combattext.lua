local Combat = ShadowUF:NewModule("CombatText")
ShadowUF:RegisterModule(Combat, "combatText", ShadowUFLocals["Combat Text"])

function Combat:UnitEnabled(frame, unit)
	if( not frame.visibility.combatText ) then
		return
	end
	
	frame:RegisterUpdateFunc(self.Update)
end

function Combat:UnitDisabled(frame, unit)
	frame:UnregisterAll(self.Update)
end

function Combat.Update(self, unit)

end
