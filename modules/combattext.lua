local Combat = ShadowUF:NewModule("CombatText")
ShadowUF:RegisterModule(Combat, "combatText", ShadowUFLocals["Combat text"])

function Combat:UnitEnabled(frame, unit)
	if( not frame.visibility.combatText ) then
		return
	end
	
	frame.combatText = frame.combatText or CreateFrame("Frame", nil, frame.barFrame)
	frame.combatText.feedbackText = frame.combatText:CreateFontString(nil, "ARTWORK")
	frame.combatText.feedbackText:SetPoint("CENTER", frame.combatText, "CENTER", 0, 0)

	frame.combatText.feedbackStartTime = 0
	frame.combatText:SetScript("OnUpdate", CombatFeedback_OnUpdate)
	frame.combatText:SetHeight(1)
	frame.combatText:SetWidth(1)
	
	frame:RegisterUnitEvent("UNIT_COMBAT", self.Update)
end

function Combat:UnitDisabled(frame, unit)
	frame:UnregisterAll(self.Update)
end

function Combat.Update(self, unit, junk, ...)
	CombatFeedback_OnCombatEvent(self.combatText, ...)
	
	self.combatText.feedbackText:SetFont(self.combatText.fontPath, self.combatText.feedbackText:GetStringHeight(), "OUTLINE")
end
