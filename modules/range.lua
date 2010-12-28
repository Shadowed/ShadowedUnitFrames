local Range = {
	friendly = {["PRIEST"] = GetSpellInfo(2061), ["DRUID"] = GetSpellInfo(5185), ["PALADIN"] = GetSpellInfo(635), ["SHAMAN"] = GetSpellInfo(331)},
	hostile = {["PRIEST"] = GetSpellInfo(585), ["DRUID"] = GetSpellInfo(5176), ["PALADIN"] = GetSpellInfo(62124), ["HUNTER"] = GetSpellInfo(75), ["WARLOCK"] = GetSpellInfo(686), ["SHAMAN"] = GetSpellInfo(403), ["MAGE"] = GetSpellInfo(133), ["DEATHKNIGHT"] = GetSpellInfo(49576)},
}
ShadowUF:RegisterModule(Range, "range", ShadowUF.L["Range indicator"])

local playerClass = select(2, UnitClass("player"))
local friendlySpell = Range.friendly[playerClass]
local hostileSpell = Range.hostile[playerClass]

local function checkRange(self, elapsed)
	self.timeElapsed = self.timeElapsed + elapsed
	if( self.timeElapsed <= 0.50 ) then return end
	self.timeElapsed = 0
	
	local frame = self.parent
	local spell
	-- check which spell to use
	if UnitIsFriend("player", frame.unit) then
		spell = friendlySpell
	elseif UnitCanAttack("player", frame.unit) then
		spell = hostileSpell
	end

	if( spell ) then
		self.parent:SetRangeAlpha(IsSpellInRange(spell, frame.unit) == 1 and ShadowUF.db.profile.units[frame.unitType].range.inAlpha or ShadowUF.db.profile.units[frame.unitType].range.oorAlpha)
	-- That didn't work, but they are grouped lets try the actual API for this, it's a bit flaky though and not that useful generally
	elseif( UnitInRaid(frame.unit) or UnitInParty(frame.unit) ) then
		self.parent:SetRangeAlpha(UnitInRange(frame.unit, "player") and ShadowUF.db.profile.units[frame.unitType].range.inAlpha or ShadowUF.db.profile.units[frame.unitType].range.oorAlpha)
	-- Nope, fall back to interaction :(
	else
		self.parent:SetRangeAlpha(CheckInteractDistance(frame.unit, 4) and ShadowUF.db.profile.units[frame.unitType].range.inAlpha or ShadowUF.db.profile.units[frame.unitType].range.oorAlpha)
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
		frame.range:Show()
	end
	frame:RegisterUpdateFunc(self, "ForceUpdate")
end

function Range:OnLayoutApplied(frame)
	hostileSpell = ShadowUF.db.profile.range["hostile" .. playerClass] or self.hostile[playerClass]
	friendlySpell = ShadowUF.db.profile.range["friendly" .. playerClass] or self.friendly[playerClass]
end

function Range:OnDisable(frame)
	frame:UnregisterAll(self)
	
	if( frame.range ) then
		frame.range:Hide()
		frame:SetRangeAlpha(1.0)
	end
end
