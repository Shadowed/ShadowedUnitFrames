local Combat = {}
ShadowUF:RegisterModule(Combat, "combatText", ShadowUFLocals["Combat text"])

function Combat:OnEnable(frame)
	if( not frame.combatText ) then
		frame.combatText = CreateFrame("Frame", nil, frame.barFrame)
		frame.combatText.feedbackText = frame.combatText:CreateFontString(nil, "ARTWORK")
		frame.combatText.feedbackText:SetPoint("CENTER", frame.combatText, "CENTER", 0, 0)
		frame.combatText:SetFrameLevel(frame.topFrameLevel)
		
		frame.combatText.feedbackStartTime = 0
		frame.combatText:SetScript("OnUpdate", CombatFeedback_OnUpdate)
		frame.combatText:SetHeight(1)
		frame.combatText:SetWidth(1)
	end
		
	frame:RegisterUnitEvent("UNIT_COMBAT", self, "Update")
end

function Combat:OnDisable(frame)
	frame:UnregisterAll(self)
end

function Combat:Update(frame, event, unit, ...)
	CombatFeedback_OnCombatEvent(frame.combatText, ...)
	
	-- Increasing the font size leads to it becoming pixeled, however getting the percentage it was increased by
	-- and then scaling the entire container frame, does not!
	local increased = frame.combatText.feedbackText:GetStringHeight() / ShadowUF.db.profile.font.size
	frame.combatText.feedbackText:SetFont(frame.combatText.fontPath, ShadowUF.db.profile.font.size, "OUTLINE")
	frame.combatText:SetScale(increased)
end
