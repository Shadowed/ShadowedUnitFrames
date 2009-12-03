local Range = {}
ShadowUF:RegisterModule(Range, "range", ShadowUFLocals["Range indicator"])

local friendly = {["PRIEST"] = GetSpellInfo(2050), ["DRUID"] = GetSpellInfo(48378), ["PALADIN"] = GetSpellInfo(48782), ["SHAMAN"] = GetSpellInfo(49273)}
local hostile = {["PRIEST"] = GetSpellInfo(48127), ["DRUID"] = GetSpellInfo(48461), ["PALADIN"] = GetSpellInfo(62124), ["HUNTER"] = GetSpellInfo(75), ["WARLOCK"] = GetSpellInfo(686), ["SHAMAN"] = GetSpellInfo(529), ["MAGE"] = GetSpellInfo(133), ["DEATHKNIGHT"] = GetSpellInfo(49576)}
local playerClass = select(2, UnitClass("player"))

local function checkRange(self, elapsed)
	self.timeElapsed = self.timeElapsed + elapsed
	if( self.timeElapsed <= 0.50 ) then return end
	self.timeElapsed = 0
	
	-- We set a spell for them in our flags check, use that
	if( self.spell ) then
		self.parent:SetAlpha(IsSpellInRange(self.spell, self.parent.unit) == 1 and ShadowUF.db.profile.units[self.parent.unitType].range.inAlpha or ShadowUF.db.profile.units[self.parent.unitType].range.oorAlpha)
	-- That didn't work, but they are grouped lets try the actual API for this, it's a bit flaky though and not that useful generally
	elseif( self.grouped ) then
		self.parent:SetAlpha(UnitInRange(self.parent.unit, "player") and ShadowUF.db.profile.units[self.parent.unitType].range.inAlpha or ShadowUF.db.profile.units[self.parent.unitType].range.oorAlpha)
	-- Nope, fall back to interaction :(
	elseif( self.isFriendly ) then
		self.parent:SetAlpha(CheckInteractDistance(self.parent.unit, 4) and ShadowUF.db.profile.units[self.parent.unitType].range.inAlpha or ShadowUF.db.profile.units[self.parent.unitType].range.oorAlpha)
	else
		self.parent:SetAlpha(ShadowUF.db.profile.units[self.parent.unitType].range.inAlpha)
	end
end

function Range:ForceUpdate(frame)
	checkRange(frame.range, 1)
end

function Range:OnEnable(frame)
	if( not frame.range ) then
		frame.range = CreateFrame("Frame", nil, frame)
		frame.range:SetScript("OnUpdate", checkRange)
		frame.range.timeElapsed = 0
		frame.range.parent = frame
		frame.range:Hide()
	end
	
	-- I want to say UNIT_FACTION is the function thats called when a unit is MCed, but not 100% sure
	frame:RegisterUnitEvent("UNIT_FACTION", self, "UpdateFlags")
	frame:RegisterNormalEvent("PARTY_MEMBERS_CHANGED", self, "UpdateFlags")
	frame:RegisterNormalEvent("RAID_ROSTER_UPDATE", self, "UpdateFlags")

	frame:RegisterUpdateFunc(self, "UpdateFlags")
	frame:RegisterUpdateFunc(self, "ForceUpdate")
end

function Range:OnDisable(frame)
	frame:UnregisterAll(self)
	
	if( frame.range ) then
		frame.range:Hide()
		frame:SetAlpha(1.0)
	end
end

-- I'd rather store the flags here, they rarely change and we can do that based off events, no sense in doing it eveyr 0.50s
function Range:UpdateFlags(frame)
	frame.range.canAttack = UnitCanAttack("player", frame.unit)
	frame.range.isFriendly = UnitIsFriend("player", frame.unit)
	frame.range.grouped = UnitInRaid(frame.unit) or UnitInParty(frame.unit)
	frame.range.spell = frame.range.canAttack and hostile[playerClass] or frame.range.isFriendly and friendly[playerClass] or nil

	-- No sense in updating range if we have no data
	if( not frame.range.spell and not frame.range.grouped and not frame.range.isFriendly ) then
		frame:SetAlpha(ShadowUF.db.profile.units[frame.unitType].range.inAlpha)
		frame.range:Hide()
	else
		frame.range:Show()
	end
end


