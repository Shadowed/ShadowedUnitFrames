local Fader = {}
ShadowUF:RegisterModule(Fader, "fader", ShadowUFLocals["Combat fader"])

local function faderUpdate(self, elapsed)
	self.timeElapsed = self.timeElapsed + elapsed
	if( self.timeElapsed >= self.fadeTime ) then
		self.parent:SetAlpha(self.alphaEnd)
		self:Hide()
		return
	end
	
	if( self.fadeType == "in" ) then
		self.parent:SetAlpha((self.timeElapsed / self.fadeTime) * (self.alphaEnd - self.alphaStart) + self.alphaStart)
	else
		self.parent:SetAlpha(((self.fadeTime - self.timeElapsed) / self.fadeTime) * (self.alphaStart - self.alphaEnd) + self.alphaEnd)
	end
end

local function startFading(self, type, alpha)
	self.fader.fadeTime = type == "in" and 0.25 or type == "out" and 0.50
	self.fader.timeElapsed = 0
	self.fader.alphaEnd = alpha
	self.fader.alphaStart = self:GetAlpha()
	self.fader:Show()
end

function Fader:OnEnable(frame)
	if( not frame.visibility.fader or ( frame.unitType ~= "player" and frame.unitType ~= "focus" and frame.unitType ~= "party" and frame.unitType ~= "raid" ) ) then return end
	
	if( not frame.fader ) then
		frame.fader = CreateFrame("Frame", nil, frame)
		frame.fader.timeElapsed = 0
		frame.fader.parent = frame
		frame.fader:SetScript("OnUpdate", faderUpdate)
		frame.fader:Hide()
	end
		
	frame:RegisterNormalEvent("PLAYER_REGEN_ENABLED", self, "Update")
	frame:RegisterNormalEvent("PLAYER_REGEN_DISABLED", self, "Update")
	frame:RegisterNormalEvent("PLAYER_TARGET_CHANGED", self, "Update")
	frame:RegisterUnitEvent("UNIT_HEALTH", self, "Update")
	frame:RegisterUnitEvent("UNIT_MANA", self, "Update")
	frame:RegisterUnitEvent("UNIT_MAXHEALTH", self, "Update")
	frame:RegisterUnitEvent("UNIT_MAXMANA", self, "Update")
	frame:RegisterUpdateFunc(self, "Update")
end

function Fader:OnDisable(frame)
	frame:UnregisterAll(self)
	frame:SetAlpha(1.0)

	if( frame.fader ) then
		frame.fader:Hide()
	end
end

function Fader:Update(frame)
	if( InCombatLockdown() ) then
		startFading(frame, "in", ShadowUF.db.profile.units[frame.unitType].fader.combatAlpha)
	elseif( UnitPowerType(frame.unit) == 0 and UnitPower(frame.unit) ~= UnitPowerMax(frame.unit) ) then
		startFading(frame, "in", ShadowUF.db.profile.units[frame.unitType].fader.combatAlpha)
	elseif( UnitHealth(frame.unit) ~= UnitHealthMax(frame.unit) ) then
		startFading(frame, "in", ShadowUF.db.profile.units[frame.unitType].fader.combatAlpha)
	elseif( frame.unitType == "player" and UnitExists("target") ) then
		startFading(frame, "in", ShadowUF.db.profile.units[frame.unitType].fader.combatAlpha)
	else
		startFading(frame, "out", ShadowUF.db.profile.units[frame.unitType].fader.inactiveAlpha)
	end
end
