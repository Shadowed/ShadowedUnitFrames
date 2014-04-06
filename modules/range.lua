local Range = {
	friendly = {["WARRIOR"] = GetSpellInfo(3411), ["PRIEST"] = GetSpellInfo(2061), ["DRUID"] = GetSpellInfo(774), ["PALADIN"] = GetSpellInfo(635), ["SHAMAN"] = GetSpellInfo(331), ["WARLOCK"] = GetSpellInfo(5697), ["DEATHKNIGHT"] = GetSpellInfo(49016), ["MAGE"] = GetSpellInfo(475), ["ROGUE"] = GetSpellInfo(57934), ["MONK"] = GetSpellInfo(115450)},
	hostile = {["WARRIOR"] = GetSpellInfo(355), ["PRIEST"] = GetSpellInfo(585), ["DRUID"] = GetSpellInfo(5176), ["PALADIN"] = GetSpellInfo(62124), ["SHAMAN"] = GetSpellInfo(403), ["HUNTER"] = GetSpellInfo(75), ["WARLOCK"] = GetSpellInfo(686), ["DEATHKNIGHT"] = GetSpellInfo(49576), ["MAGE"] = GetSpellInfo(133), ["ROGUE"] = GetSpellInfo(2094), ["MONK"] = GetSpellInfo(115546)},
}
ShadowUF:RegisterModule(Range, "range", ShadowUF.L["Range indicator"])

local playerClass = select(2, UnitClass("player"))
local friendlySpell = Range.friendly[playerClass]
local hostileSpell = Range.hostile[playerClass]

local function checkRange(self, elapsed)
	local frame = self.parent
	local spell

	-- Check which spell to use
	if( UnitCanAssist("player", frame.unit) ) then
		spell = friendlySpell
	elseif( UnitCanAttack("player", frame.unit) ) then
		spell = hostileSpell
	end

	if( spell ) then
		frame:SetRangeAlpha(IsSpellInRange(spell, frame.unit) == 1 and ShadowUF.db.profile.units[frame.unitType].range.inAlpha or ShadowUF.db.profile.units[frame.unitType].range.oorAlpha)
	-- That didn't work, but they are grouped lets try the actual API for this, it's a bit flaky though and not that useful generally
	elseif( UnitInRaid(frame.unit) or UnitInParty(frame.unit) ) then
		frame:SetRangeAlpha(UnitInRange(frame.unit, "player") and ShadowUF.db.profile.units[frame.unitType].range.inAlpha or ShadowUF.db.profile.units[frame.unitType].range.oorAlpha)
	-- Nope, fall back to interaction :(
	else
		frame:SetRangeAlpha(CheckInteractDistance(frame.unit, 4) and ShadowUF.db.profile.units[frame.unitType].range.inAlpha or ShadowUF.db.profile.units[frame.unitType].range.oorAlpha)
	end
end

function Range:ForceUpdate(frame)
	if( UnitIsUnit(frame.unit, "player") ) then
		frame:SetRangeAlpha(ShadowUF.db.profile.units[frame.unitType].range.inAlpha)
		frame.range:Hide()
	else
		frame.range:Show()
		checkRange(frame.range.timer)
	end
end

function Range:OnEnable(frame)
	if( not frame.range ) then
		frame.range = CreateFrame("Frame", nil, frame)

		frame.range.timer = frame:CreateOnUpdate(0.50, checkRange)
		frame.range.timer.parent = frame
	end

	frame.range:Show()

	frame:RegisterUpdateFunc(self, "ForceUpdate")
end

function Range:OnLayoutApplied(frame)
	hostileSpell = ShadowUF.db.profile.range["hostile" .. playerClass] or self.hostile[playerClass]
	if( not GetSpellInfo(hostileSpell) ) then hostileSpell = nil end

	friendlySpell = ShadowUF.db.profile.range["friendly" .. playerClass] or self.friendly[playerClass]
	if( not GetSpellInfo(friendlySpell) ) then friendlySpell = nil end
end

function Range:OnDisable(frame)
	frame:UnregisterAll(self)
	
	if( frame.range ) then
		frame.range:Hide()
		frame:SetRangeAlpha(1.0)
	end
end
