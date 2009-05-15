local Runes = ShadowUF:NewModule("Runes")
ShadowUF:RegisterModule(Runes, "runeBar", ShadowUFLocals["Rune Bar"], "bar")

function Runes:UnitEnabled(frame, unit)
	if( not frame.visibility.runeBar ) then
		return
	end
	
	frame:RegisterUpdateFunc(self.Update)
end

function Runes:UnitDisabled(frame, unit)
	frame:UnregisterAll(self.Update)
end

function Runes.Update(self, unit)

end
