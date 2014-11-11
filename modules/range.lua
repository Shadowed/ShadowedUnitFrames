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

local function checkRange(self, elapsed)
	local frame = self.parent
	local oorAlpha = ShadowUF.db.profile.units[frame.unitType].range.oorAlpha
	local inAlpha = ShadowUF.db.profile.units[frame.unitType].range.inAlpha

	-- Offline
	if( not UnitIsConnected(frame.unit) ) then
		frame:SetRangeAlpha(oorAlpha)
		return
	-- Hostile spell
	elseif( rangeSpells.hostile and UnitCanAttack("player", frame.unit) and IsSpellInRange(rangeSpells.hostile) == 1 ) then
		frame:SetRangeAlpha(inAlpha)
		return
	-- Friendly spell
	elseif( rangeSpells.friendly and UnitCanAssist("player", frame.unit) and IsSpellInRange(rangeSpells.friendly, frame.unit) == 1 ) then
		frame:SetRangeAlpha(inAlpha)
		return
	-- Use the built in UnitInRange
	elseif( UnitInRaid(frame.unit) or UnitInParty(frame.unit) ) then
		frame:SetRangeAlpha(UnitInRange(frame.unit, "player") and inAlpha or oorAlpha)
		return
	end

	-- Interact
	if( CheckInteractDistance(frame.unit, 1) ) then
		frame:SetRangeAlpha(inAlpha)
		return
	end

	frame:SetRangeAlpha(oorAlpha)
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

	frame:RegisterNormalEvent("PLAYER_SPECIALIZATION_CHANGED", self, "SpellChecks")
	frame:RegisterUpdateFunc(self, "ForceUpdate")

	frame.range:Show()
end

function Range:OnLayoutApplied(frame)
	self:SpellChecks()
end

function Range:OnDisable(frame)
	frame:UnregisterAll(self)
	
	if( frame.range ) then
		frame.range:Hide()
		frame:SetRangeAlpha(1.0)
	end
end


function Range:SpellChecks(frame)
	updateSpellCache("friendly")
	updateSpellCache("hostile")
end