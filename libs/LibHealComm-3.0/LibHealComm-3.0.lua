local MAJOR_VERSION = "LibHealComm-3.0";
local MINOR_VERSION = 90000 + tonumber(("$Revision: 56 $"):match("%d+"));

local lib = LibStub:NewLibrary(MAJOR_VERSION, MINOR_VERSION);
if not lib then return end

local playerName = UnitName('player');
local playerRealm = GetRealmName();
local playerClass = select(2, UnitClass('player'));
local isHealer = (playerClass == "PRIEST") or (playerClass == "SHAMAN") or (playerClass == "DRUID") or (playerClass == "PALADIN");


-----------------
-- Event Frame --
-----------------

lib.EventFrame = lib.EventFrame or CreateFrame("Frame");
lib.EventFrame:SetScript("OnEvent", function (this, event, ...) lib[event](lib, ...) end);
lib.EventFrame:UnregisterAllEvents();

-- Register Events
lib.EventFrame:RegisterEvent("PLAYER_ALIVE");
lib.EventFrame:RegisterEvent("LEARNED_SPELL_IN_TAB");
lib.EventFrame:RegisterEvent("CHAT_MSG_ADDON");
lib.EventFrame:RegisterEvent("UNIT_SPELLCAST_DELAYED");
lib.EventFrame:RegisterEvent("UNIT_AURA");
lib.EventFrame:RegisterEvent("UNIT_TARGET");
lib.EventFrame:RegisterEvent("PLAYER_TARGET_CHANGED");
lib.EventFrame:RegisterEvent("PLAYER_FOCUS_CHANGED");
lib.EventFrame:RegisterEvent("GLYPH_ADDED");
lib.EventFrame:RegisterEvent("GLYPH_REMOVED");
lib.EventFrame:RegisterEvent("GLYPH_UPDATED");

-- For keeping track of versions
lib.EventFrame:RegisterEvent("PARTY_MEMBERS_CHANGED");
lib.EventFrame:RegisterEvent("RAID_ROSTER_UPDATE");

-- Prune data at zone change
lib.EventFrame:RegisterEvent("PLAYER_ENTERING_WORLD");

-- Only listen to these events if player is healing class
if (isHealer) then
    lib.EventFrame:RegisterEvent("UNIT_SPELLCAST_SENT");
    lib.EventFrame:RegisterEvent("UNIT_SPELLCAST_START");
    lib.EventFrame:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED");
    lib.EventFrame:RegisterEvent("UNIT_SPELLCAST_STOP");
end


----------------------
-- Scanning Tooltip --
----------------------

if (not lib.Tooltip) then
    lib.Tooltip = CreateFrame("GameTooltip");
    lib.Tooltip:SetOwner(UIParent, "ANCHOR_NONE");
    for i = 1, 4 do
        lib["TooltipTextLeft" .. i] = lib.Tooltip:CreateFontString();
        lib["TooltipTextRight" .. i] = lib.Tooltip:CreateFontString();
        lib.Tooltip:AddFontStrings(lib["TooltipTextLeft" .. i], lib["TooltipTextRight" .. i]);
    end
end


-------------------------------
-- Embed CallbackHandler-1.0 --
-------------------------------

lib.Callbacks = LibStub("CallbackHandler-1.0"):New(lib);


-----------------
-- Static Data --
-----------------

-- Cache of spells and heal sizes
local SpellCache = {};

-- Cache of glyphs
local GlyphCache = {};

-- Info about spells being cast by other players
local HealTime = {};
local HealTarget = {};
local HealSize = {};

-- Healing Modifiers (by name)
local HealModifier = {};

-- Last target name from UNIT_SPELLCAST_SENT
local SentTargetName;

-- Last spellCastIndex from UNIT_SPELLCAST_STOP
local LastSpellCastIndex;

-- Info about the spell being cast by the player
local CastInfoIsCasting;
local CastInfoHealingTargetUnitID;
local CastInfoHealingTargetNames;
local CastInfoHealingSize;
local CastInfoEndTime;

-- Latency Measurement
local SentTime = 0;
local Latency = 0;

-- Version Information Table
local Versions = {};

-- Battleground/Arena/Group Indicators
local InBattlegroundOrArena;
local InRaid;
local InParty;

-- Subgroup of raid members
local Subgroup = {};


---------------------------------
-- Frequently Accessed Globals --
---------------------------------

local type = type;
local tonumber = tonumber;
local math = math;
local string = string;
local select = select;
local pairs = pairs;
local unpack = unpack;
local UnitName = UnitName;
local SendAddonMessage = SendAddonMessage;
local IsInInstance = IsInInstance;
local UnitBuff = UnitBuff;
local UnitDebuff = UnitDebuff;
local UnitLevel = UnitLevel;
local GetInventoryItemLink = GetInventoryItemLink;
local GetTime = GetTime;
local UnitCastingInfo = UnitCastingInfo;
local GetSpellBonusHealing = GetSpellBonusHealing;
local GetTalentInfo = GetTalentInfo;
local UnitExists = UnitExists;
local tinsert = table.insert;
local tconcat = table.concat;
local twipe = table.wipe;


---------------
-- Utilities --
---------------

local function unitFullName(unit)
    local name, realm = UnitName(unit);
    if (realm and realm ~= "") then
        return name .. "-" .. realm;
    else
        return name;
    end
end

local function extractRealm(fullName)
    return fullName:match("^[^%-]+%-(.+)$");
end

-- Convert a remotely generated fully qualified name to
-- a local fully qualified name.
local function convertRealm(fullName, remoteRealm)
    if (remoteRealm) then
        local name, realm = fullName:match("^([^%-]+)%-(.+)$");
        if (not realm) then
            -- Apply remote realm if there is no realm on the target
            return fullName .. "-" .. remoteRealm;
        elseif (realm == playerRealm) then
            -- Strip realm if it is equal to the local realm
            return name;
        end
    end
    return fullName;
end

local function commSend(contents, distribution, target)
    SendAddonMessage("HealComm", contents, distribution or (InBattlegroundOrArena and "BATTLEGROUND" or "RAID"), target);
end

-- Spellbook Scanner --
local function getBaseHealSize(name)

    -- Check if info is already cached
    if (SpellCache[name]) then
        return SpellCache[name];
    end

    SpellCache[name] = {};

    -- Gather info (only done if not in cache)
    local i = 1;

    while true do

        local spellName, spellRank = GetSpellName(i, BOOKTYPE_SPELL);

        if (not spellName) then
            break
        end

        if (spellName == name) then
            -- This is the spell we're looking for, gather info

            -- Determine rank
            spellRank = tonumber(spellRank:match("(%d+)"));
            lib.Tooltip:SetSpell(i, BOOKTYPE_SPELL);

            -- Determine healing
            local HealMin, HealMax = select(3, string.find(lib.TooltipTextLeft4:GetText() or lib.TooltipTextLeft3:GetText() or "", "(%d+) ?[\195\160tobisa到~\-]+ ?(%d+)"));
            HealMin, HealMax = tonumber(HealMin) or 0, tonumber(HealMax) or 0;
            local Heal = (HealMin + HealMax) / 2;

            SpellCache[spellName][spellRank] = Heal;
        end
        i = i + 1;
    end

    return SpellCache[name];
end

local function detectGlyph(id)

    -- Check if info is already cached
    if (GlyphCache[id] ~= nil) then
        return GlyphCache[id];
    end

    GlyphCache[id] = false;

    -- Gather info (only done if not in cache)
    for i = 1, GetNumGlyphSockets() do
        local enabled, _, glyphId = GetGlyphSocketInfo(i);
        if (enabled and glyphId) then
            GlyphCache[glyphId] = true;
        end
    end

    return GlyphCache[id];
end

-- Detects if a buff is present on the unit and returns the application number,
-- otherwise return false. Optionally, if the third argument is provided and is
-- true, then return false if the buff was not placed by the player.
local function detectBuff(unit, buffName, mineOnly)
    local name, _, _, count, _, _, _, applier = UnitBuff(unit, buffName);
    return name and (not mineOnly or applier and UnitIsUnit(applier, 'player')) and count or false;
end

--[[
    [GetSpellInfo(604)]   = -20,      -- Dampen Magic (Rank 1)
    [GetSpellInfo(8450)]  = -40,      -- Dampen Magic (Rank 2)
    [GetSpellInfo(8451)]  = -80,      -- Dampen Magic (Rank 3)
    [GetSpellInfo(10173)] = -120,     -- Dampen Magic (Rank 4)
    [GetSpellInfo(10174)] = -180,     -- Dampen Magic (Rank 5)
    [GetSpellInfo(33944)] = -240,     -- Dampen Magic (Rank 6)
    [GetSpellInfo(1008)]  = 30,       -- Amplify Magic (Rank 1)
    [GetSpellInfo(8455)]  = 60,       -- Amplify Magic (Rank 2)
    [GetSpellInfo(10169)] = 100,      -- Amplify Magic (Rank 3)
    [GetSpellInfo(10170)] = 150,      -- Amplify Magic (Rank 4)
    [GetSpellInfo(27130)] = 180,      -- Amplify Magic (Rank 5)
    [GetSpellInfo(33946)] = 240,      -- Amplify Magic (Rank 6)
    [GetSpellInfo(32858)] = -345      -- Touch of the Forgotten (Auchenai Crypts)
    [GetSpellInfo(38377)] = -690      -- Touch of the Forgotten (Auchenai Crypts)
]]--

local healingBuffs =
{
    [GetSpellInfo(706)]   = 1.20, -- Demon Armor
    [GetSpellInfo(45234)] = function (count, rank) return (1.0 + (0.04 + 0.03 * (rank - 1)) * count) end, -- Focused Will
    [GetSpellInfo(34123)] = 1.06, -- Tree of Life
    [GetSpellInfo(58549)] = function (count, rank, texture) return ((texture == "Interface\\Icons\\Ability_Warrior_StrengthOfArms") and (1.18 ^ count) or 1.0) end, -- Tenacity (Wintergrasp)
}

local healingDebuffs =
{
    [GetSpellInfo(25646)] = function (count) return (1.0 - count * 0.10) end, -- Mortal Wound (Temporus - The Black Morass)
    [GetSpellInfo(45347)] = function (count) return (1.0 - count * 0.04) end, -- Dark Touched (Grand Warlock Alythess - Sunwell Plateau)
    [GetSpellInfo(30423)] = function (count) return (1.0 - count * 0.01) end, -- Nether Portal - Dominance (Netherspite - Karazhan)
    [GetSpellInfo(13218)] = function (count) return (1.0 - count * 0.10) end, -- Wound Poison
    [GetSpellInfo(19434)] = 0.50,   -- Aimed Shot
    [GetSpellInfo(12294)] = 0.50,   -- Mortal Strike
    [GetSpellInfo(40599)] = 0.50,   -- Arcing Smash (Gurtogg Bloodboil)
    [GetSpellInfo(23169)] = 0.50,   -- Brood Affliction: Green (Chromaggus)
    [GetSpellInfo(34073)] = 0.85,   -- Curse of the Bleeding Hollow (Hellfire Peninsula)
    [GetSpellInfo(13583)] = 0.50,   -- Curse of the Deadwood (Deadwood Furbolgs - Felwood)
    [GetSpellInfo(36023)] = 0.50,   -- Deathblow
    [GetSpellInfo(34625)] = 0.25,   -- Demolish (Negatron - Netherstorm)
    [GetSpellInfo(34366)] = 0.75,   -- Ebon Poison (Black Morass)
    [GetSpellInfo(32378)] = 0.50,   -- Filet (Spectral Chef - Karazhan)
    [GetSpellInfo(19716)] = 0.25,   -- Gehennas' Curse (Gehennas - Molten Core)
    [GetSpellInfo(36917)] = 0.50,   -- Magma-Thrower's Curse (Sulfuron Magma-Thrower - The Arcatraz)
    [GetSpellInfo(22859)] = 0.50,   -- Mortal Cleave (High Priestess Thekal - Zul'Gurub)
    [GetSpellInfo(38572)] = 0.50,   -- Mortal Cleave (High Priestess Thekal - Zul'Gurub)
    [GetSpellInfo(39595)] = 0.50,   -- Mortal Cleave (High Priestess Thekal - Zul'Gurub)
    [GetSpellInfo(28776)] = 0.10,   -- Necrotic Poison (Maexxna - Naxxramas)
    [GetSpellInfo(35189)] = 0.50,   -- Solar Strike (The Mechanar)
    [GetSpellInfo(32315)] = 0.50,   -- Soul Strike (Ethereal Crypt Raiders - Mana-Tombs)
    [GetSpellInfo(7068)]  = 0.25,   -- Veil of Shadow (Nefarian - Blackwing Lair)
    [GetSpellInfo(38387)] = 1.50,   -- Bane of Infinity (CoT: Escape from Durholde)
    [GetSpellInfo(31977)] = 1.50,   -- Curse of Infinity (CoT: Escape from Durholde)
    [GetSpellInfo(41292)] = 0.00,   -- Aura of Suffering (Essence of Souls - Black Temple)
    [GetSpellInfo(41350)] = 2.00,   -- Aura of Desire (Essence of Souls - Black Temple)
    [GetSpellInfo(30843)] = 0.00,   -- Enfeeble (Prince Malchezaar - Karazhan)
}

local function calculateHealModifier(unit)
    local modifier = 1.0;

    for i = 1, 40 do
        local name, rank, texture, count = UnitDebuff(unit, i);
        if (not name) then
            break;
        end
        local mark = healingDebuffs[name];
        if (mark) then
            if (type(mark) == "function") then
                mark = mark(count);
            end
            if (mark < modifier) then
                modifier = mark;
            end
        end
    end
    for i = 1, 40 do
        local name, rank, texture, count = UnitBuff(unit, i);
        if (not name) then
            break;
        end
        local mark = healingBuffs[name];
        if (mark) then
            if (type(mark) == "function") then
                mark = mark(count, rank and tonumber(rank:match("(%d+)")), texture);
            end
            modifier = modifier * mark;
        end
    end

    return modifier;
end

local function getDownrankingFactor(spellLevel, playerLevel)
    local factor = 0.05 * ((spellLevel + 7) - playerLevel) + 1;
    if (factor > 1.0) then
        return 1;
    elseif (factor < 0.0) then
        return 0;
    else
        return factor;
    end
end

local relicSlotNumber = GetInventorySlotInfo("RangedSlot");
local function getEquippedRelicID()
    local itemLink = GetInventoryItemLink('player', relicSlotNumber);
    if (itemLink) then
        return tonumber(itemLink:match("(%d+):"));
    end
end


-----------------------------
-- Healing Data Management --
-----------------------------

local function entryDelete(healerName)
    local targetNames = HealTarget[healerName];
    HealTime[healerName] = nil;
    HealTarget[healerName] = nil;
    if (type(targetNames) == "table") then
        for i, targetName in pairs(targetNames) do
            if HealSize[targetName] then
                HealSize[targetName][healerName] = nil;
            end
        end
    elseif (targetNames and HealSize[targetNames]) then
        HealSize[targetNames][healerName] = nil;
    end
end

local function entryUpdate(healerName, targetNames, healSize, healTime)
    entryDelete(healerName);
    HealTime[healerName] = healTime;
    HealTarget[healerName] = targetNames;
    if (type(targetNames) == "table") then
        for i, targetName in pairs(targetNames) do
            if (not HealSize[targetName]) then
                HealSize[targetName] = {};
            end
            HealSize[targetName][healerName] = healSize;
        end
    elseif (targetNames) then
        if (not HealSize[targetNames]) then
            HealSize[targetNames] = {};
        end
        HealSize[targetNames][healerName] = healSize;
    end
end

local function entryRetrieve(healerName)
    local healTime = HealTime[healerName];
    if (healTime) then
        local targetNames = HealTarget[healerName];
        if (type(targetNames) == "table") then
            return targetNames, HealSize[targetNames[1]][healerName], healTime;
        elseif (targetNames) then
            return targetNames, HealSize[targetNames][healerName], healTime;
        end
    end
end


----------------------
-- Public Functions --
----------------------

--[[ UnitIncomingHealGet(unit, time)

Description: Retrieve info about the incoming heals to a specific
             target. The second argument specifies a boundary time,
             relative to the current time. Examples:

             UnitIncomingHealGet("Kaki", GetTime() + 3)
             UnitIncomingHealGet("Kaki-Emerald Dream", GetTime() + 3)
             UnitIncomingHealGet("player", GetTime() + 3)
             UnitIncomingHealGet("raid10", GetTime() + 3)
             UnitIncomingHealGet("target", GetTime() + 3)

             Retrieves info about the incoming heals on the specified
             target. incomingHealBefore will contain the sum of heals
             that will land within the next 3 seconds, and
             incomingHealAfter will contain the sum of heals that will
             land after 3 seconds.

Input:
    unit - The exact name or UnitID of the unit to retrieve information about.
    time - the desired boundary time of the inquiry.

Output:
    incomingHealBefore - The total size of the incoming heals before the boundary time.
    incomingHealAfter - The total size of the incoming heals after the boundary time.
    nextTime - the time left until the next incoming heal will land.
    nextSize - the size of the next incoming heal.
    nextName - the name of the healer casting the next incoming heal.

]]--

function lib:UnitIncomingHealGet(unit, time)
    if (type(unit) ~= "string") then return end
    if (type(time) ~= "number") then return end

    local targetName = unitFullName(unit);
    if (HealSize[targetName]) then
        local now = GetTime();
        local incomingHealBefore, incomingHealAfter = 0, 0;
        local nextTime, nextSize, nextName;
        for healerName, size in pairs(HealSize[targetName]) do
            local healTime = HealTime[healerName];
            if (size and healTime) then
                healTime = healTime + Latency;
                if (healTime > now) then
                    if (healTime < time) then
                        -- Due before boundary time
                        incomingHealBefore = incomingHealBefore + size;
                    else
                        -- Due after boundary time
                        incomingHealAfter = incomingHealAfter + size;
                    end
                    if ((not nextTime) or (healTime < nextTime)) then
                        nextTime = healTime;
                        nextSize = size;
                        nextName = healerName;
                    end
                end
            end
        end
        if ((incomingHealBefore > 0) or (incomingHealAfter > 0)) then
            return incomingHealBefore, incomingHealAfter, nextTime, nextSize, nextName;
        end
    end
end

--[[ UnitCastingHealGet(unit)

Description: Retrieve info about the direct healing spell
             currently being cast by any unit. Examples:

             UnitCastingHealGet("Kaki");
             UnitCastingHealGet("Kaki-Emerald Dream");
             UnitCastingHealGet("player")
             UnitCastingHealGet("raid10")
             UnitCastingHealGet("target")

Input:
    unit - The name or UnitID of the unit to retrieve information about.

Output:
    healSize - Size of the healing being cast.
    endTime - The time when the healing completes.
    targetName - Name of the unit(s) being targeted for heal.

]]--

function lib:UnitCastingHealGet(unit)
    if (type(unit) ~= "string") then return end
    local healerName = unitFullName(unit);

    if (healerName == playerName) then
        if (CastInfoIsCasting) then
            return CastInfoHealingSize, CastInfoEndTime, CastInfoHealingTargetNames;
        end
    else
        local targetNames, healSize, endTime = entryRetrieve(healerName);
        if (targetNames) then
            return healSize, endTime, targetNames;
        end
    end
end

--[[ UnitHealModifierGet(unit)

Description: Returns the modifier to healing (as a factor)
             caused by buffs and debuffs. Examples:

             UnitHealModifierGet("Kaki");
             UnitHealModifierGet("Kaki-Emerald Dream");
             UnitHealModifierGet("player", 3)
             UnitHealModifierGet("raid10", 3)
             UnitHealModifierGet("target", 3)

Input:
    unit - The name or UnitID of the unit to retrieve information about.

Output:
    factor - Always a fractional number - will be 1.0 if no buffs/debuffs
             affect healing.

]]--

function lib:UnitHealModifierGet(unit)
    if (type(unit) ~= "string") then return end

    local targetName = unitFullName(unit);
    return HealModifier[targetName] or calculateHealModifier(unit);
end


function lib:GetRaidOrPartyVersions()
    local tab = {};

    if (InRaid) then
        for i = 1, GetNumRaidMembers() do
            local name = unitFullName('raid' .. i);
            if (not (name == playerName)) then
                tab[name] = Versions[name] or false;
            end
        end
    elseif (InParty) then
        for i = 1, GetNumPartyMembers() do
            local name = unitFullName('party' .. i);
            tab[name] = Versions[name] or false;
        end
    end

    tab[playerName] = MINOR_VERSION;

    return tab;
end

function lib:GetGuildVersions()
    local tab = {};

    if (IsInGuild()) then
        GuildRoster();

        for i = 1, GetNumGuildMembers(false) do
            local name, rank, rankIndex, level, class, zone, note, officernote, online, status = GetGuildRosterInfo(i);
            if (online and not (name == playerName)) then
                tab[name] = Versions[name] or false;
            end
        end
    end

    tab[playerName] = MINOR_VERSION;

    return tab;
end

function lib:GetUnitVersion(unit)
    if (type(unit) ~= "string") then return end

    local targetName = unitFullName(unit);
    if (targetName == playerName) then return MINOR_VERSION end
    return Versions[targetName] or false;
end


--------------------
-- Class Specific --
--------------------

local HealingSpells;
--local HotSpells;
local GetHealSize;

-- Druid --

-- TODO:
-- Talent: Empowered Rejuvenation. Increase effect of all HOTs by 4%-20%
-- Idol: Idol of Rejuvenation

if (playerClass == "DRUID") then

    local tHealingTouch = GetSpellInfo(5185);
    local tRegrowth = GetSpellInfo(8936);
    local tNourish = GetSpellInfo(50464);
    local tRejuvenation = GetSpellInfo(774);
    local tLifebloom = GetSpellInfo(33763);
    local tWildGrowth = GetSpellInfo(48438);

--[[HotSpells =
    {
        [tRegrowth] =
        {
            Level = {17, 23, 29, 35, 41, 47, 53, 59, 65, 70, 76, 80},
            Duration = 21,
            Ticks = 7,
            Pattern = "(%d+)[^0-9]+%d+[^0-9]+$",
            Type = "HoT",
        },
        [tRejuvenation] =
        {
            Level = {9, 15, 21, 27, 33, 39, 45, 51, 57, 59, 62, 68, 74, 79, 80},
            Duration = 12,
            Ticks = 4,
            Pattern = "(%d+)",
            Type = "HoT",
        },
        [tLifebloom] =
        {
            Level = {71, 79, 80},
            Duration = 7,
            Ticks = 7,
            Pattern = "(%d+)"
            Type = "Lifebloom",
        },
    }]]--

    HealingSpells =
    {
        [tHealingTouch] =
        {
            Level = {1, 8, 14, 20, 26, 32, 38, 44, 50, 56, 60, 62, 69, 74, 79},
            Type = "Direct",
        },
        [tRegrowth] =
        {
            Level = {12, 18, 24, 30, 36, 42, 48, 54, 60, 65, 71, 77},
            Type = "Direct",
        },
        [tNourish] =
        {
            Level = {80};
            Type = "Direct",
        }
    }

    local idolsHealingTouch =
    {
        [28568] = 136, -- Idol of the Avian Heart
        [22399] = 100, -- Idol of Health
    }

    local idolsNourish =
    {
        [46138] = 187, -- Idol of the Flourishing Life
    }

    GetHealSize = function(name, rank, target)
        local i, effectiveHeal;

        -- Get static spell info
        local baseHealSize = getBaseHealSize(name)[rank];
        local nBonus = 0;
        local effectiveHealModifier = 1.0;

        if (not baseHealSize) then
            return nil;
        end

        -- Get +healing bonus
        local bonus = GetSpellBonusHealing();

        local spellTab = HealingSpells[name];

        -- Gift of Nature Talent - Increases effective healing by 2% per rank on all spells
        effectiveHealModifier = effectiveHealModifier * (2 * select(5, GetTalentInfo(3, 13)) / 100 + 1);

        -- Process individual spells
        if (name == tHealingTouch) then
            local idolBonus = idolsHealingTouch[getEquippedRelicID()] or 0;
            baseHealSize = baseHealSize + idolBonus;

            -- Glyph of Healing Touch (decreases amount healed by 50%)
            if (detectGlyph(54825)) then
                effectiveHealModifier = effectiveHealModifier * 0.5
            end

            -- Empowered Touch Talent (increases bonus healing effects by 20% per rank)
            local talentEmpoweredTouch = 20 * select(5, GetTalentInfo(3, 15)) / 100;

            if (rank < 5) then
                nBonus = bonus * (1.88 * (1.0 + rank * 0.5) / 3.5 + talentEmpoweredTouch);
            else
                nBonus = bonus * (1.88 + talentEmpoweredTouch);
            end
        elseif (name == tRegrowth) then
            -- Glyph of Regrowth (increases effective healing by 20% if player's Regrowth is on target)
            if (detectGlyph(54743) and detectBuff(target, tRegrowth, true)) then
                effectiveHealModifier = effectiveHealModifier * 1.2;
            end
            nBonus = bonus * 1.88 * (2.0 / 3.5) * 0.5;
        elseif (name == tNourish) then
            local idolBonus = idolsNourish[getEquippedRelicID()] or 0;
            -- Nourish heals for 20% more if player's HoT is on the target.
            if (detectBuff(target, tRejuvenation, true) or detectBuff(target, tRegrowth, true) or detectBuff(target, tLifebloom, true) or detectBuff(target, tWildGrowth, true)) then
                effectiveHealModifier = effectiveHealModifier * 1.2
            end
            nBonus = (bonus + idolBonus) * 1.88 * (1.5 / 3.5);
        end

        effectiveHeal = effectiveHealModifier * (baseHealSize + nBonus * getDownrankingFactor(spellTab.Level[rank], UnitLevel('player')));
        return effectiveHeal;
    end

end

-- Paladin --
if (playerClass == "PALADIN") then

    local tHolyLight = GetSpellInfo(635);
    local tFlashOfLight = GetSpellInfo(19750);
    local tDivineFavor = GetSpellInfo(20216);
    local tSealOfLight = GetSpellInfo(20167);
    local tAvengingWrath = GetSpellInfo(31884);
    local tDivinePlea = GetSpellInfo(54428);

    HealingSpells =
    {
        [tHolyLight] =
        {
            Level = {1, 6, 14, 22, 30, 38, 46, 54, 60, 62, 70, 75, 80},
            Type = "Direct",
        },
        [tFlashOfLight] =
        {
            Level = {20, 26, 34, 42, 50, 58, 66, 74, 79},
            Type = "Direct",
        },
    }

    local libramsFlashOfLight =
    {
        [42615] = 320, -- Furious Gladiator's Libram of Justice
        [42614] = 267, -- Deadly Gladiator's Libram of Justice
        [42613] = 236, -- Hateful Gladiator's Libram of Justice
        [42612] = 204, -- Savage Gladiator's Libram of Justice
        [28592] = 89,  -- Libram of Souls Redeemed (TODO: may be changed to affect Holy Light in 3.0.3)
        [25644] = 79,  -- Blessed Book of Nagrand
        [23006] = 43,  -- Libram of Light
        [23201] = 28,  -- Libram of Divinity
    }

    local libramsHolyLight =
    {
        [45436] = 160, -- Libram of the Resolute
        [40268] = 141, -- Libram of Tolerance
        [28296] = 47,  -- Libram of the Lightbringer
    }

    GetHealSize = function(name, rank, target)
        local i, effectiveHeal;

        -- Get static spell info
        local baseHealSize = getBaseHealSize(name)[rank];
        local nBonus = 0;
        local effectiveHealModifier = 1.0;

        if (not baseHealSize) then
            return nil;
        end

        -- Get +healing bonus
        local bonus = GetSpellBonusHealing();

        local spellTab = HealingSpells[name];

        -- Divine Favor (100% crit chance on heal spell)
        if (detectBuff('player', tDivineFavor)) then
            effectiveHealModifier = effectiveHealModifier * 1.5;
        end

        -- Avenging Wrath (increase all healing by 20%)
        if (detectBuff('player', tAvengingWrath)) then
            effectiveHealModifier = effectiveHealModifier * 1.2;
        end

        -- Divine Plea (decrease all healing by 50%)
        if (detectBuff('player', tDivinePlea)) then
            effectiveHealModifier = effectiveHealModifier * 0.5;
        end

        -- Glyph of Seal of Light (increases healing by 5% if Seal of Light is active)
        if (detectGlyph(54943) and detectBuff('player', tSealOfLight)) then
            effectiveHealModifier = effectiveHealModifier * 1.05;
        end

        -- Healing Light - Increases healing by 4% per rank on all spells
        effectiveHealModifier = effectiveHealModifier * (4 * select(5, GetTalentInfo(1, 3)) / 100 + 1);

        -- Process individual spells
        if (name == tFlashOfLight) then
            local libramBonus = libramsFlashOfLight[getEquippedRelicID()] or 0;
            nBonus = (bonus + libramBonus) * 1.88 * (1.5 / 3.5) * 1.25;
        elseif (name == tHolyLight) then
            local libramBonus = libramsHolyLight[getEquippedRelicID()] or 0;
            nBonus = (bonus + libramBonus) * 1.88 * (2.5 / 3.5) * 1.25;
        end

        effectiveHeal = effectiveHealModifier * (baseHealSize + nBonus * getDownrankingFactor(spellTab.Level[rank], UnitLevel('player')));
        return effectiveHeal;
    end

end

-- Priest --
-- TODO: Talent: Improved Renew: increases renew by 5%-10%-15%
-- Healing_Done = (Renew_Base + (Healbonus * Downrankfactor) ) * Improved_Renew * Spiritual_Healing
if (playerClass == "PRIEST") then

    local tLesserHeal = GetSpellInfo(2050);
    local tHeal = GetSpellInfo(2054);
    local tGreaterHeal = GetSpellInfo(2060);
    local tFlashHeal = GetSpellInfo(2061);
    local tBindingHeal = GetSpellInfo(32546);
    local tPrayerOfHealing = GetSpellInfo(596);
    local tPowerWordFortitude = GetSpellInfo(1243);
    --local tRenew = GetSpellInfo(139);
    local tGrace = GetSpellInfo(47930);

--[[HotSpells =
    {
        [tRenew] =
        {
            Level = {8, 14, 20, 26, 32, 38, 44, 50, 56, 60, 65, 74, 79, 80},
            Duration = 15,
            Ticks = 5,
            Pattern = "(%d+)",
            Type = "HoT",
        },
    }]]--

    HealingSpells =
    {
        [tLesserHeal] =
        {
            Level = {1, 4, 10},
            Type = "Direct"
        },
        [tHeal] =
        {
            Level = {16, 22, 28, 34},
            Type = "Direct"
        },
        [tGreaterHeal] =
        {
            Level = {40, 46, 52, 58, 60, 63, 68, 73, 78},
            Type = "Direct",
        },
        [tFlashHeal] =
        {
            Level = {20, 26, 32, 38, 44, 50, 56, 61, 67, 73, 79},
            Type = "Direct",
        },
        [tBindingHeal] =
        {
            Level = {64, 72, 78},
            Type = "Binding"
        },
        [tPrayerOfHealing] =
        {
            Level = {30, 40, 50, 60, 60, 68, 76},
            Type = "Party",
        },
    }

    GetHealSize = function(name, rank, target)
        local i, effectiveHeal;

        -- Get static spell info
        local baseHealSize = getBaseHealSize(name)[rank];
        local nBonus = 0;
        local effectiveHealModifier = 1.0;

        if (not baseHealSize) then
            return nil;
        end

        -- Get +healing bonus
        local bonus = GetSpellBonusHealing();

        local spellTab = HealingSpells[name];

        -- Focused Power - Increases healing by 2% per rank on all spells
        effectiveHealModifier = effectiveHealModifier * (2 * select(5, GetTalentInfo(1, 16)) / 100 + 1);

        -- Spiritual Healing - Increases healing by 2% per rank on all spells
        effectiveHealModifier = effectiveHealModifier * (2 * select(5, GetTalentInfo(2, 16)) / 100 + 1);

        -- Grace (increases healing by 2% per application on target if buff was placed by the player)
        if (target) then
            local grace = detectBuff(target, tGrace, true);
            if (grace) then
                effectiveHealModifier = effectiveHealModifier * (1.0 + 0.02 * grace);
            end
        end

        -- Process individual spells
        if (name == tLesserHeal) then
            nBonus = bonus * 1.88 * (1.0 + rank * 0.5) / 3.5;
        elseif (name == tHeal) then
            nBonus = bonus * 1.88 * (3.0 / 3.5);
        elseif (name == tGreaterHeal) then
            local empoweredHealing = 8 * select(5, GetTalentInfo(2, 20)) / 100;
            nBonus = bonus * (1.88 * (3.0 / 3.5) + empoweredHealing);
        elseif (name == tFlashHeal) then
            local empoweredHealing = 4 * select(5, GetTalentInfo(2, 20)) / 100;
            nBonus = bonus * (1.88 * (1.5 / 3.5) + empoweredHealing);
        elseif (name == tBindingHeal) then
            local empoweredHealing = 4 * select(5, GetTalentInfo(2, 20)) / 100;
            nBonus = bonus * (1.88 * (1.5 / 3.5) + empoweredHealing);
        elseif (name == tPrayerOfHealing) then
            nBonus = bonus * 1.88 * (3.0 / 3.5) * 0.5;
        end

        effectiveHeal = effectiveHealModifier * (baseHealSize + nBonus * getDownrankingFactor(spellTab.Level[rank], UnitLevel('player')));
        return effectiveHeal;
    end

end

-- Shaman --
-- TODO: Nature's Blessing (GetTalentInfo(3, 21)) is probably not accounted for automatically anymore (or is it?)
-- TODO: Riptide 51point resto spell (instant cast regrowth (direct + hot))
-- TODO: Glyph of Healing Wave (binding heal, but self-heal is percentage of actual target healed)
if (playerClass == "SHAMAN") then

    local tLesserHealingWave = GetSpellInfo(8004);
    local tHealingWave = GetSpellInfo(331);
    local tChainHeal = GetSpellInfo(1064);
    local tHealingWay = GetSpellInfo(29206);
    local tTidalWaves = GetSpellInfo(51562);
    local tRiptide = GetSpellInfo(61295);
    local tEarthShield = GetSpellInfo(974);

--[[HotSpells =
    {
        [tRiptide] =
        {
            Level = {60, 70, 75, 80},
            Duration = 15,
            Ticks = 5,
            Pattern = "(%d+)",
            Type = "HoT",
        },
    }]]--

    HealingSpells =
    {
        [tLesserHealingWave] =
        {
            Level = {20, 28, 36, 44, 52, 60, 66, 72, 77},
            Type = "Direct",
        },
        [tHealingWave] =
        {
            Level = {1, 6, 12, 18, 24, 32, 40, 48, 56, 60, 63, 70, 75, 80},
            Type = "Direct",
        },
        [tChainHeal] =
        {
            Level = {40, 46, 54, 61, 68, 74, 80},
            Type = "Direct",
        },
    }

    local totemsLesserHealingWave =
    {
        [42598] = 320, -- Furious Gladiator's Totem of the Third Wind
        [42597] = 267, -- Deadly Gladiator's Totem of the Third Wind
        [42596] = 236, -- Hateful Gladiator's Totem of the Third Wind
        [42595] = 204, -- Savage Gladiator's Totem of the Third Wind
        [25645] = 79,  -- Totem of The Plains
        [22396] = 80,  -- Totem of Life
        [23200] = 53,  -- Totem of Sustaining
    }

    local totemsHealingWave =
    {
        [27544] = 88,  -- Totem of Spontaneous Regrowth
    }

    local totemsChainHeal =
    {
        [45114] = 243, -- Steamcaller's Totem
        [38368] = 102, -- Totem of the Bay
        [28523] = 87,  -- Totem of Healing Rains
    }

    GetHealSize = function(name, rank, target)
        local i, effectiveHeal;

        -- Get static spell info
        local baseHealSize = getBaseHealSize(name)[rank];
        local nBonus = 0;
        local effectiveHealModifier = 1.0;

        if (not baseHealSize) then
            return nil;
        end

        -- Get +healing bonus
        local bonus = GetSpellBonusHealing();

        -- Purification Talent (increases healing by 2% per rank).
        -- This is factored into effectiveHealModifier in the individual spell section below due to interaction with Improved Chain Heal.
        local talentPurification = 2 * select(5, GetTalentInfo(3, 15)) / 100 + 1;

        local spellTab = HealingSpells[name];

        -- Process individual spells
        if (name == tLesserHealingWave) then
            local totemBonus = totemsLesserHealingWave[getEquippedRelicID()] or 0;
            effectiveHealModifier = effectiveHealModifier * talentPurification;

            -- Glyph of Lesser Healing Wave (increases effective healing by 20% if player's Earth Shield is on target)
            if (detectGlyph(55438) and detectBuff(target, tEarthShield, true)) then
                effectiveHealModifier = effectiveHealModifier * 1.2;
            end

            -- Tidal Waves Talent (increases bonus healing effects by 2% per rank)
            local talentTidalWaves = 2 * select(5, GetTalentInfo(3, 25)) / 100;

            nBonus = (bonus + totemBonus) * (1.88 * (1.5 / 3.5) + talentTidalWaves);
        elseif (name == tHealingWave) then
            local totemBonus = totemsHealingWave[getEquippedRelicID()] or 0;
            effectiveHealModifier = effectiveHealModifier * talentPurification;

            -- Healing Way Buff (target buff that increases effective healing by 18%)
            if (detectBuff(target, tHealingWay)) then
                effectiveHealModifier = effectiveHealModifier * 1.18;
            end;

            -- Tidal Waves Talent (increases bonus healing effects by 4% per rank)
            local talentTidalWaves = 4 * select(5, GetTalentInfo(3, 25)) / 100;

            -- Determine normalisation
            if (rank < 4) then
                nBonus = (bonus + totemBonus) * (1.88 * (1.0 + rank * 0.5) / 3.5 + talentTidalWaves);
            else
                nBonus = (bonus + totemBonus) * (1.88 * (3.0 / 3.5) + talentTidalWaves);
            end
        elseif (name == tChainHeal) then
            local totemBonus = totemsChainHeal[getEquippedRelicID()] or 0;
            baseHealSize = baseHealSize + totemBonus;

            -- Improved Chain Heal Talent (increases healing by 10% per rank)
            local talentImprovedChainHeal = 10 * select(5, GetTalentInfo(3, 20)) / 100;

            effectiveHealModifier = effectiveHealModifier * (talentPurification + talentImprovedChainHeal);

            -- Riptide Buff (target buff that increases effective healing by 25%)
            if (detectBuff(target, tRiptide, true)) then
                effectiveHealModifier = effectiveHealModifier * 1.25;
            end

            nBonus = bonus * 1.88 * (2.5 / 3.5);
        end

        effectiveHeal = effectiveHealModifier * (baseHealSize + nBonus * getDownrankingFactor(spellTab.Level[rank], UnitLevel('player')));
        return effectiveHeal;
    end

end


--------------------
-- Event Handlers --
--------------------

function lib:PLAYER_FOCUS_CHANGED()
    if (UnitExists('focus')) then
        self:UNIT_AURA('focus');
    end
    if (UnitExists('focustarget')) then
        self:UNIT_AURA('focustarget');
    end
end

function lib:PLAYER_TARGET_CHANGED()
    if (UnitExists('target')) then
        self:UNIT_AURA('target');
    end
    if (UnitExists('targettarget')) then
        self:UNIT_AURA('targettarget');
    end
end

function lib:UNIT_TARGET(unit)
    if ((unit == 'target') or (unit == 'focus')) then
        local unitTarget = unit .. "target";
        if (UnitExists(unitTarget)) then
            self:UNIT_AURA(unitTarget);
        end
    end
end

function lib:UNIT_AURA(unit)
    local targetName = unitFullName(unit);

    local oldModifier = HealModifier[targetName];
    local newModifier = calculateHealModifier(unit);
    if (oldModifier) then
        if (newModifier == oldModifier) then
            return
        end
    else
        if (newModifier == 1.0) then
            return
        end
    end
    HealModifier[targetName] = newModifier;

    self.Callbacks:Fire("HealComm_HealModifierUpdate", unit, targetName, newModifier);
end

function lib:LEARNED_SPELL_IN_TAB()
    -- Invalidate cached spell data when learning new spells
    SpellCache = {};
end

function lib:GLYPH_ADDED()
    -- Invalidate cached glyph data when updating glyphs
    GlyphCache = {};
end

function lib:GLYPH_REMOVED()
    -- Invalidate cached glyph data when updating glyphs
    GlyphCache = {};
end

function lib:GLYPH_UPDATED()
    -- Invalidate cached glyph data when updating glyphs
    GlyphCache = {};
end

function lib:UNIT_SPELLCAST_SENT(unit, spellName, spellRank, targetName)
    if (unit ~= 'player') then return end

    -- Latency measurement
    SentTime = GetTime();

    SentTargetName = targetName;
end

function lib:UNIT_SPELLCAST_START(unit, spellName, spellRank)
    if (unit ~= 'player') then return end

    -- Latency measurement
    local currentLatency = GetTime() - SentTime;
    if (currentLatency > 1) then -- Limit to 1 sec
        currentLatency = 1;
    end
    Latency = 0.5 * Latency + 0.70 * currentLatency;

    local spellInfo = HealingSpells[spellName];

    -- Only process healing spells
    if (spellInfo) then
        if (spellInfo.Type == "Direct") then
            CastInfoHealingTargetNames = SentTargetName;
            CastInfoHealingSize = GetHealSize(spellName, tonumber(spellRank:match("(%d+)")), SentTargetName) or 0;
            CastInfoIsCasting = true;
            CastInfoEndTime = (select(6, UnitCastingInfo('player')) or 0) / 1000;
            self.Callbacks:Fire("HealComm_DirectHealStart", playerName, CastInfoHealingSize, CastInfoEndTime, SentTargetName);
            commSend(string.format("000%05d%s", math.min(CastInfoHealingSize, 99999), SentTargetName));
        elseif (spellInfo.Type == "Binding") then
            CastInfoHealingTargetNames = {playerName, SentTargetName};
            CastInfoHealingSize = GetHealSize(spellName, tonumber(spellRank:match("(%d+)")), SentTargetName) or 0;
            CastInfoIsCasting = true;
            CastInfoEndTime = (select(6, UnitCastingInfo('player')) or 0) / 1000;
            self.Callbacks:Fire("HealComm_DirectHealStart", playerName, CastInfoHealingSize, CastInfoEndTime, unpack(CastInfoHealingTargetNames));
            commSend(string.format("002%05d%s", math.min(CastInfoHealingSize, 99999), SentTargetName));
        elseif (spellInfo.Type == "Party") then
            CastInfoHealingTargetNames = {SentTargetName};
            if (InRaid) then
                local targetSubgroup = Subgroup[SentTargetName];
                if (targetSubgroup) then
                    for name, subgroup in pairs(Subgroup) do
                        if ((subgroup == targetSubgroup) and (name ~= SentTargetName) and (UnitIsVisible(name))) then
                            tinsert(CastInfoHealingTargetNames, name);
                        end
                    end
                end
            elseif (InParty and UnitInParty(SentTargetName)) then
                if (playerName ~= SentTargetName) then
                    tinsert(CastInfoHealingTargetNames, playerName);
                end
                for i = 1, GetNumPartyMembers() do
                    local name = unitFullName("party" .. i);
                    if (name and (name ~= SentTargetName) and (UnitIsVisible(name))) then
                        tinsert(CastInfoHealingTargetNames, name);
                    end
                end
            end
            CastInfoHealingSize = GetHealSize(spellName, tonumber(spellRank:match("(%d+)"))) or 0;
            CastInfoIsCasting = true;
            CastInfoEndTime = (select(6, UnitCastingInfo('player')) or 0) / 1000;
            commSend(string.format("003%05d%s", math.min(CastInfoHealingSize, 99999), tconcat(CastInfoHealingTargetNames, ":")));
            self.Callbacks:Fire("HealComm_DirectHealStart", playerName, CastInfoHealingSize, CastInfoEndTime, unpack(CastInfoHealingTargetNames));
        end
    end
end

function lib:CHAT_MSG_ADDON(prefix, msg, distribution, sender)
    if (prefix ~= "HealComm") then return end
    if (sender == playerName) then return end

    -- Workaround: Sometimes in battlegrounds the sender argument is not a
    -- fully qualified name (the realm is missing), even though the sender is
    -- from a different realm.
    if (distribution == "BATTLEGROUND") then
        sender = unitFullName(sender) or sender;
    end

    -- Get message type
    local msgtype = tonumber(msg:sub(1, 3));
    if (not msgtype) then return end

    if (msgtype == 0) then -- DirectHealStart
        local healSize = tonumber(msg:sub(4, 8));
        local targetName = msg:sub(9, -1);

        if (healSize and targetName) then
            local endTime = select(6, UnitCastingInfo(sender));

            if (endTime) then
                if (distribution == "BATTLEGROUND") then
                    targetName = convertRealm(targetName, extractRealm(sender));
                end
                endTime = endTime / 1000;
                entryUpdate(sender, targetName, healSize, endTime);
                self.Callbacks:Fire("HealComm_DirectHealStart", sender, healSize, endTime, targetName);
            end
        end
    elseif (msgtype == 1) then -- HealStop
        local targetNames, healSize = entryRetrieve(sender);
        entryDelete(sender);
        if (type(targetNames) == "table") then
            self.Callbacks:Fire("HealComm_DirectHealStop", sender, healSize, msg:sub(4, 4) == "S", unpack(targetNames));
        elseif (targetNames) then
            self.Callbacks:Fire("HealComm_DirectHealStop", sender, healSize, msg:sub(4, 4) == "S", targetNames);
        end
    elseif ((msgtype == 2) or (msgtype == 3)) then -- MultiTargetHealStart
        local healSize = tonumber(msg:sub(4, 8));
        local targetNames = {strsplit(":", msg:sub(9, -1))};

        if (healSize) then
            local endTime = select(6, UnitCastingInfo(sender));

            if (endTime) then
                if (distribution == "BATTLEGROUND") then
                    local senderRealm = extractRealm(sender);
                    for k, targetName in pairs(targetNames) do
                        targetNames[k] = convertRealm(targetName, senderRealm);
                    end
                end
                endTime = endTime / 1000;
                if (msgtype == 2) then
                    tinsert(targetNames, 1, sender);
                end
                entryUpdate(sender, targetNames, healSize, endTime);
                self.Callbacks:Fire("HealComm_DirectHealStart", sender, healSize, endTime, unpack(targetNames));
            end
        end
    elseif (msgtype >= 998) then -- AnnounceVersion
        local version = tonumber(msg:sub(4, -1));
        if (version) then
            Versions[sender] = version;

            if (msgtype == 999) then -- RequestVersion
                if (distribution ~= "BATTLEGROUND") then
                    -- Reply in whisper if possible
                    commSend("998" .. tostring(MINOR_VERSION), "WHISPER", sender);
                else
                    -- Reply to inbound distribution channel
                    commSend("998" .. tostring(MINOR_VERSION), distribution);
                end
            end
        end
    end
end

function lib:UNIT_SPELLCAST_DELAYED(unit)
    if (unit == 'player') then
        if (CastInfoIsCasting) then
            local endTime = select(6, UnitCastingInfo('player'));
            if (endTime) then
                CastInfoEndTime = endTime / 1000;
                if (type(CastInfoHealingTargetNames) == "table") then
                    self.Callbacks:Fire("HealComm_DirectHealDelayed", playerName, CastInfoHealingSize, CastInfoEndTime, unpack(CastInfoHealingTargetNames));
                elseif (CastInfoHealingTargetNames) then
                    self.Callbacks:Fire("HealComm_DirectHealDelayed", playerName, CastInfoHealingSize, CastInfoEndTime, CastInfoHealingTargetNames);
                end
            end
        end
    elseif (unit ~= 'target' and unit ~= 'focus') then
        local healerName = unitFullName(unit);
        local targetNames, healSize = entryRetrieve(healerName)
        if (targetNames) then
            local endTime = select(6, UnitCastingInfo(healerName));
            if (endTime) then
                endTime = endTime / 1000;
                HealTime[healerName] = endTime;
                if (type(targetNames) == "table") then
                    self.Callbacks:Fire("HealComm_DirectHealDelayed", healerName, healSize, endTime, unpack(targetNames));
                elseif (targetNames) then
                    self.Callbacks:Fire("HealComm_DirectHealDelayed", healerName, healSize, endTime, targetNames);
                end
            end
        end
    end
end

function lib:UNIT_SPELLCAST_SUCCEEDED(unit, spellName, spellRank, spellCastIndex)
    if (unit ~= 'player') then return end

    if (CastInfoIsCasting) then
        CastInfoIsCasting = false;
        commSend("001S");

        if (type(CastInfoHealingTargetNames) == "table") then
            self.Callbacks:Fire("HealComm_DirectHealStop", playerName, CastInfoHealingSize, true, unpack(CastInfoHealingTargetNames));
        elseif (CastInfoHealingTargetNames) then
            self.Callbacks:Fire("HealComm_DirectHealStop", playerName, CastInfoHealingSize, true, CastInfoHealingTargetNames);
        end
    else
        if (LastSpellCastIndex ~= spellCastIndex) then
            -- Instant Cast Spells
        end
    end
end

function lib:UNIT_SPELLCAST_STOP(unit, spellName, spellRank, spellCastIndex)
    if (unit == 'player' and CastInfoIsCasting) then
        LastSpellCastIndex = spellCastIndex;
        CastInfoIsCasting = false;
        commSend("001F");
        if (type(CastInfoHealingTargetNames) == "table") then
            self.Callbacks:Fire("HealComm_DirectHealStop", playerName, CastInfoHealingSize, false, unpack(CastInfoHealingTargetNames));
        elseif (CastInfoHealingTargetNames) then
            self.Callbacks:Fire("HealComm_DirectHealStop", playerName, CastInfoHealingSize, false, CastInfoHealingTargetNames);
        end
    end
end

function lib:PLAYER_ALIVE()
    -- This event is only fired at initial login, not at reloadui or load-on-demand loading.
    -- The initialisation is triggered again, since none of the initialisation had any effect
    -- prior to this event firing (no messages sent and InBattlegroundOrArena, InRaid and InParty
    -- are probably not correctly initialised).
    lib:Initialise();

    -- Only receive once
    self.EventFrame:UnregisterEvent("PLAYER_ALIVE");
end

function lib:PLAYER_ENTERING_WORLD()
    HealTime = {};
    HealTarget = {};
    HealSize = {};
    HealModifier = {};
end

function lib:PARTY_MEMBERS_CHANGED()
    local wasInRaidOrParty = InRaid or InParty;
    InRaid = (GetNumRaidMembers() > 0);
    InParty = (GetNumPartyMembers() > 0);

    -- Announce and request version when joining a group
    if (not wasInRaidOrParty and (InRaid or InParty)) then
        commSend("999" .. tostring(MINOR_VERSION));
    end

    -- Update Subgroups table
    twipe(Subgroup);
    if (InRaid) then
        for i = 1, GetNumRaidMembers() do
            local name, _, subgroup = GetRaidRosterInfo(i);
            if (name and subgroup) then
                Subgroup[name] = subgroup;
            end
        end
    end
end

function lib:RAID_ROSTER_UPDATE()
    self:PARTY_MEMBERS_CHANGED();
end

function lib:Initialise()
    local it = select(2, IsInInstance());
    InBattlegroundOrArena = (it == "pvp") or (it == "arena");

    InRaid = (GetNumRaidMembers() > 0);
    InParty = (GetNumPartyMembers() > 0);

    -- Announce and request version in group and in guild
    commSend("999" .. tostring(MINOR_VERSION));
    if (IsInGuild()) then
        commSend("999" .. tostring(MINOR_VERSION), "GUILD");
    end
end

lib:Initialise();
