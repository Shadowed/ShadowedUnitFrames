local Range = {
	friendly = {
		["PRIEST"] = GetSpellInfo(2061), -- Flash Heal
		["DRUID"] = GetSpellInfo(774), -- Rejuvenation
		["PALADIN"] = GetSpellInfo(85673), -- Word of Glory
		["SHAMAN"] = GetSpellInfo(8004), -- Healing Surge
		["WARLOCK"] = GetSpellInfo(5697), -- Unending Breath
		["DEATHKNIGHT"] = GetSpellInfo(47541), -- Death Coil
		["MAGE"] = GetSpellInfo(475), -- Remove Curse
		["MONK"] = GetSpellInfo(115450) -- Detox
	},
	hostile = {
		["WARRIOR"] = GetSpellInfo(355), -- Taunt
		["PRIEST"] = GetSpellInfo(589), -- Shadow Word: Pain
		["DRUID"] = GetSpellInfo(5176),  -- Wrath
		["PALADIN"] = GetSpellInfo(20271), -- Judgement
		["SHAMAN"] = GetSpellInfo(403), -- Lightning Bolt
		["HUNTER"] = GetSpellInfo(75), -- Auto Shot
		["WARLOCK"] = GetSpellInfo(686), -- Shadow Bolt
		["DEATHKNIGHT"] = GetSpellInfo(49576), -- Death Grip
		["MAGE"] = GetSpellInfo(44614), -- Frostfire Bolt
		["ROGUE"] = GetSpellInfo(1725), -- Distract
		["MONK"] = GetSpellInfo(115546) -- Provoke
	},
	friendlyAlt = {},
	hostileAlt = {
		["MAGE"] = GetSpellInfo(30451) -- Arcane Blast
	}
}

ShadowUF:RegisterModule(Range, "range", ShadowUF.L["Range indicator"])

local playerClass = select(2, UnitClass("player"))
local rangeSpells = {}

local function checkRange(self)
	local frame = self.parent

	-- Check which spell to use
	local spell
	if( UnitCanAssist("player", frame.unit) ) then
		spell = rangeSpells.friendly
	elseif( UnitCanAttack("player", frame.unit) ) then
		spell = rangeSpells.hostile
	end

	if( not UnitIsConnected(frame.unit) ) then
		frame:SetRangeAlpha(ShadowUF.db.profile.units[frame.unitType].range.oorAlpha)
	elseif( spell ) then
		frame:SetRangeAlpha(IsSpellInRange(spell, frame.unit) == 1 and ShadowUF.db.profile.units[frame.unitType].range.inAlpha or ShadowUF.db.profile.units[frame.unitType].range.oorAlpha)
	-- That didn't work, but they are grouped lets try the actual API for this, it's a bit flaky though and not that useful generally
	elseif( UnitInRaid(frame.unit) or UnitInParty(frame.unit) ) then
		frame:SetRangeAlpha(UnitInRange(frame.unit, "player") and ShadowUF.db.profile.units[frame.unitType].range.inAlpha or ShadowUF.db.profile.units[frame.unitType].range.oorAlpha)
	-- Nope, fall back to interaction :(
	else
		frame:SetRangeAlpha(CheckInteractDistance(frame.unit, 1) and ShadowUF.db.profile.units[frame.unitType].range.inAlpha or ShadowUF.db.profile.units[frame.unitType].range.oorAlpha)
	end
end

local function updateSpellCache(type)
	rangeSpells[type] = nil
	if( IsUsableSpell(ShadowUF.db.profile.range[type .. playerClass]) ) then
		rangeSpells[type] = ShadowUF.db.profile.range[type .. playerClass]

	elseif( IsUsableSpell(ShadowUF.db.profile.range[type .. "Alt" .. playerClass]) ) then
		rangeSpells[type] = ShadowUF.db.profile.range[type .. "Alt" .. playerClass]

	elseif( IsUsableSpell(Range[type][playerClass]) ) then
		rangeSpells[type] = Range[type][playerClass]

	elseif( IsUsableSpell(Range[type .. "Alt"][playerClass]) ) then
		rangeSpells[type] = Range[type .. "Alt"][playerClass]
	end
end

function Range:ForceUpdate(frame)
	if( UnitIsUnit(frame.unit, "player") ) then
		frame:SetRangeAlpha(ShadowUF.db.profile.units[frame.unitType].range.inAlpha)
		frame.range.timer:Stop()
	else
		frame.range.timer:Play()
		checkRange(frame.range.timer)
	end
end

function Range:OnEnable(frame)
	if( not frame.range ) then
		frame.range = CreateFrame("Frame", nil, frame)

		frame.range.timer = frame:CreateOnUpdate(0.50, checkRange)
		frame.range.timer.parent = frame
	end

	frame:RegisterNormalEvent("PLAYER_SPECIALIZATION_CHANGED", self, "SpellChecks")
	frame:RegisterUpdateFunc(self, "ForceUpdate")

	frame.range.timer:Play()
end

function Range:OnLayoutApplied(frame)
	self:SpellChecks(frame)
end

function Range:OnDisable(frame)
	frame:UnregisterAll(self)
	
	if( frame.range ) then
		frame.range.timer:Stop()
		frame:SetRangeAlpha(1.0)
	end
end


function Range:SpellChecks(frame)
	updateSpellCache("friendly")
	updateSpellCache("hostile")
	if( frame.range ) then
		checkRange(frame.range.timer)
	end
end