local Totems = ShadowUF:NewModule("Totems")
ShadowUF:RegisterModule(Totems, "totems", ShadowUFLocals["Totem Indicators"])

function Totems:UnitEnabled(frame, unit)
	if( not frame.visibility.totems ) then
		return
	end
	
	frame:RegisterUpdateFunc(self.Update)
end

function Totems:UnitDisabled(frame, unit)
	frame:UnregisterAll(self.Update)
end

function Totems.Update(self, unit)

end
