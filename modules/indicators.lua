local Indicator = ShadowUF:NewModule("Indicator")

function Indicator:OnInitialize()
	ShadowUF:RegisterModule(self)
end

function Indicator:UnitCreated(frame, unit)
	frame.indicators = {}
	
	frame:RegisterNormalEvent("PLAYER_REGEN_ENABLED", self.UpdateStatus)
	frame:RegisterNormalEvent("PLAYER_REGEN_DISABLED", self.UpdateStatus)
	frame:RegisterNormalEvent("PLAYER_UPDATE_RESTING", self.UpdateStatus)
	frame:RegisterNormalEvent("UPDATE_FACTION", self.UpdateStatus)
	frame:RegisterUnitEvent("PLAYER_FLAGS_CHANGED", self.UpdatePVPFlag)
	frame:RegisterUnitEvent("UNIT_FACTION", self.UpdatePVPFlag)
	frame:RegisterUpdateFunc(self.UpdateStatus)
	frame:RegisterUpdateFunc(self.UpdatePVPFlag)

	frame.indicators.status = frame:CreateTexture(nil, "OVERLAY")
	frame.indicators.status:SetTexture("Interface\\CharacterFrame\\UI-StateIcon")
	
	frame.indicators.pvp = frame:CreateTexture(nil, "OVERLAY")
end
			
function Indicator.UpdatePVPFlag(self, unit)
	if( UnitIsPVP(unit) and UnitFactionGroup(unit) ) then
		self.indicators.pvp:SetTexture(string.format("Interface\\TargetingFrame\\UI-PVP-%s", UnitFactionGroup(unit)))
		self.indicators.pvp:Show()
	elseif( UnitIsPVPFreeForAll(unit) ) then
		self.indicators.pvp:SetTexture("Interface\\TargetingFrame\\UI-PVP-FFA")
		self.indicators.pvp:Show()
	else
		self.indicators.pvp:Hide()
	end
end

function Indicator.UpdateStatus(self, unit)
	if( UnitAffectingCombat(unit) ) then
		self.indicators.status:SetTexCoord(0.50, 1.0, 0.0, 0.49)
		self.indicators.status:Show()
	elseif( self.unit == "player" and IsResting() ) then
		self.indicators.status:SetTexCoord(0.0, 0.50, 0.0, 0.421875)
		self.indicators.status:Show()
	else
		self.indicators.status:Hide()
	end
end




