--[[ 
	Shadowed Unit Frames, Shadowed of Mal'Ganis (US) PvP
]]

ShadowUF = select(2, ...)

local L = ShadowUF.L
ShadowUF.dbRevision = 55
ShadowUF.playerUnit = "player"
ShadowUF.enabledUnits = {}
ShadowUF.modules = {}
ShadowUF.moduleOrder = {}
ShadowUF.unitList = {"player", "pet", "pettarget", "target", "targettarget", "targettargettarget", "focus", "focustarget", "party", "partypet", "partytarget", "partytargettarget", "raid", "raidpet", "boss", "bosstarget", "maintank", "maintanktarget", "mainassist", "mainassisttarget", "arena", "arenatarget", "arenapet", "battleground", "battlegroundtarget", "battlegroundpet", "arenatargettarget", "battlegroundtargettarget", "maintanktargettarget", "mainassisttargettarget", "bosstargettarget"}
ShadowUF.fakeUnits = {["targettarget"] = true, ["targettargettarget"] = true, ["pettarget"] = true, ["arenatarget"] = true, ["arenatargettarget"] = true, ["focustarget"] = true, ["focustargettarget"] = true, ["partytarget"] = true, ["raidtarget"] = true, ["bosstarget"] = true, ["maintanktarget"] = true, ["mainassisttarget"] = true, ["battlegroundtarget"] = true, ["partytargettarget"] = true, ["battlegroundtargettarget"] = true, ["maintanktargettarget"] = true, ["mainassisttargettarget"] = true, ["bosstargettarget"] = true}
L.units = {["raidpet"] = L["Raid pet"], ["PET"] = L["Pet"], ["VEHICLE"] = L["Vehicle"], ["arena"] = L["Arena"], ["arenapet"] = L["Arena Pet"], ["arenatarget"] = L["Arena Target"], ["arenatargettarget"] = L["Arena Target of Target"], ["boss"] = L["Boss"], ["bosstarget"] = L["Boss Target"], ["focus"] = L["Focus"], ["focustarget"] = L["Focus Target"], ["mainassist"] = L["Main Assist"], ["mainassisttarget"] = L["Main Assist Target"], ["maintank"] = L["Main Tank"], ["maintanktarget"] = L["Main Tank Target"], ["party"] = L["Party"], ["partypet"] = L["Party Pet"], ["partytarget"] = L["Party Target"], ["pet"] = L["Pet"], ["pettarget"] = L["Pet Target"], ["player"] = L["Player"],["raid"] = L["Raid"], ["target"] = L["Target"], ["targettarget"] = L["Target of Target"], ["targettargettarget"] = L["Target of Target of Target"], ["battleground"] = L["Battleground"], ["battlegroundpet"] = L["Battleground Pet"], ["battlegroundtarget"] = L["Battleground Target"], ["partytargettarget"] = L["Party Target of Target"], ["battlegroundtargettarget"] = L["Battleground Target of Target"], ["maintanktargettarget"] = L["Main Tank Target of Target"], ["mainassisttargettarget"] = L["Main Assist Target of Target"], ["bosstargettarget"] = L["Boss Target of Target"]}
L.shortUnits = {["battleground"] = L["BG"], ["battlegroundtarget"] = L["BG Target"], ["battlegroundpet"] = L["BG Pet"], ["battlegroundtargettarget"] = L["BG ToT"], ["arenatargettarget"] = L["Arena ToT"], ["partytargettarget"] = L["Party ToT"], ["bosstargettarget"] = L["Boss ToT"], ["maintanktargettarget"] = L["MT ToT"], ["mainassisttargettarget"] = L["MA ToT"]}

-- Cache the units so we don't have to concat every time it updates
ShadowUF.unitTarget = setmetatable({}, {__index = function(tbl, unit) rawset(tbl, unit, unit .. "target"); return unit .. "target" end})
ShadowUF.partyUnits, ShadowUF.raidUnits, ShadowUF.raidPetUnits, ShadowUF.bossUnits, ShadowUF.arenaUnits, ShadowUF.battlegroundUnits = {}, {}, {}, {}, {}, {}
ShadowUF.maintankUnits, ShadowUF.mainassistUnits, ShadowUF.raidpetUnits = ShadowUF.raidUnits, ShadowUF.raidUnits, ShadowUF.raidPetUnits
for i=1, MAX_PARTY_MEMBERS do ShadowUF.partyUnits[i] = "party" .. i end
for i=1, MAX_RAID_MEMBERS do ShadowUF.raidUnits[i] = "raid" .. i end
for i=1, MAX_RAID_MEMBERS do ShadowUF.raidPetUnits[i] = "raidpet" .. i end
for i=1, MAX_BOSS_FRAMES do ShadowUF.bossUnits[i] = "boss" .. i end
for i=1, 5 do ShadowUF.arenaUnits[i] = "arena" .. i end
for i=1, 4 do ShadowUF.battlegroundUnits[i] = "arena" .. i end

function ShadowUF:OnInitialize()
	self.defaults = {
		profile = {
			locked = false,
			advanced = false,
			tooltipCombat = false,
			omnicc = false,
			tags = {},
			units = {},
			positions = {},
			range = {},
			filters = {zonewhite = {}, zoneblack = {}, whitelists = {}, blacklists = {}},
			visibility = {arena = {}, pvp = {}, party = {}, raid = {}},
			hidden = {cast = false, playerPower = true, buffs = false, party = true, raid = false, player = true, pet = true, target = true, focus = true, boss = true, arena = true, playerAltPower = false},
		},
	}
	
	self:LoadUnitDefaults()
		
	-- Initialize DB
	self.db = LibStub:GetLibrary("AceDB-3.0"):New("ShadowedUFDB", self.defaults, true)
	self.db.RegisterCallback(self, "OnProfileChanged", "ProfilesChanged")
	self.db.RegisterCallback(self, "OnProfileCopied", "ProfilesChanged")
	self.db.RegisterCallback(self, "OnProfileReset", "ProfileReset")

	local LibDualSpec = LibStub("LibDualSpec-1.0")
	LibDualSpec:EnhanceDatabase(self.db, "ShadowedUnitFrames")

	-- Setup tag cache
	self.tagFunc = setmetatable({}, {
		__index = function(tbl, index)
			if( not ShadowUF.Tags.defaultTags[index] and not ShadowUF.db.profile.tags[index] ) then
				tbl[index] = false
				return false
			end
			
			local func, msg = loadstring("return " .. (ShadowUF.Tags.defaultTags[index] or ShadowUF.db.profile.tags[index].func or ""))
			if( func ) then
				func = func()
			elseif( msg ) then
				error(msg, 3)
			end
			
			tbl[index] = func
			return tbl[index]
	end})
	
	if( not self.db.profile.loadedLayout ) then
		self:LoadDefaultLayout()
	else
		self:CheckUpgrade()
		self:CheckBuild()
		self:ShowInfoPanel()
	end

	self.db.profile.revision = self.dbRevision
	self:FireModuleEvent("OnInitialize")
	self:HideBlizzardFrames()
	self.Layout:LoadSML()
	self:LoadUnits()
	self.modules.movers:Update()
end

function ShadowUF:CheckBuild()
	local build = select(4, GetBuildInfo())
	if( self.db.profile.wowBuild == build ) then return end

	-- Nothing to add here right now
	self.db.profile.wowBuild = build
end

function ShadowUF:CheckUpgrade()
	local revision = self.db.profile.revision or self.dbRevision
	if( revision <= 53 ) then
		for i=1, #(self.db.profile.units.player.text) do
			if( self.db.profile.units.player.text[i].anchorTo == "$eclipseBar" ) then
				table.remove(self.db.profile.units.player.text, i)
				break
			end
		end
	end

	if( revision <= 49 ) then
		ShadowUF:LoadDefaultLayout(true)
	end

	if( revision <= 49 ) then
		if( ShadowUF.db.profile.font.extra == "MONOCHROME" ) then
			ShadowUF.db.profile.font.extra = ""
		end
	end

	if( revision <= 47 ) then
		local config = self.db.profile.units
		config.player.comboPoints = config.target.comboPoints
	end

	if( revision <= 46 ) then
		local config = self.db.profile.units.arena
		config.indicators.arenaSpec = {enabled = true, anchorPoint = "LC", size = 28, x = 0, y = 0, anchorTo = "$parent"}
		config.indicators.lfdRole = {enabled = true, anchorPoint = "BR", size = 14, x = 3, y = 14, anchorTo = "$parent"}
	end

	if( revision <= 45 ) then
		for unit, config in pairs(self.db.profile.units) do
			if( config.auras ) then
				for _, key in pairs({"buffs", "debuffs"}) do
					local aura = config.auras[key]
					aura.show = aura.show or {}
					aura.show.player = true
					aura.show.boss = true
					aura.show.raid = true
					aura.show.consolidated = true
					aura.show.misc = true
				end
			end
		end
	end
end

local function zoneEnabled(zone, zoneList)
	if( type(zoneList) == "string" ) then
		return zone == zoneList
	end

	for id, row in pairs(zoneList) do
		if( zone == row ) then return true end
	end

	return false
end

function ShadowUF:LoadUnits()
	-- CanHearthAndResurrectFromArea() returns true for world pvp areas, according to BattlefieldFrame.lua
	local instanceType = CanHearthAndResurrectFromArea() and "pvp" or select(2, IsInInstance())
	if( instanceType == "scenario" ) then instanceType = "party" end

  	if( not instanceType ) then instanceType = "none" end
	
	for _, type in pairs(self.unitList) do
		local enabled = self.db.profile.units[type].enabled
		if( ShadowUF.Units.zoneUnits[type] ) then
			enabled = enabled and zoneEnabled(instanceType, ShadowUF.Units.zoneUnits[type])
		elseif( instanceType ~= "none" ) then
			if( self.db.profile.visibility[instanceType][type] == false ) then
				enabled = false
			elseif( self.db.profile.visibility[instanceType][type] == true ) then
				enabled = true
			end
		end
		
		self.enabledUnits[type] = enabled
		
		if( enabled ) then
			self.Units:InitializeFrame(type)
		else
			self.Units:UninitializeFrame(type)
		end
	end
end

function ShadowUF:LoadUnitDefaults()
	for _, unit in pairs(self.unitList) do
		self.defaults.profile.positions[unit] = {point = "", relativePoint = "", anchorPoint = "", anchorTo = "UIParent", x = 0, y = 0}
		
		-- The reason why the defaults are so sparse, is because the layout needs to specify most of this. The reason I set tables here is basically
		-- as an indication that hey, the unit wants this, if it doesn't that it won't want it.
		self.defaults.profile.units[unit] = {
			enabled = false, height = 0, width = 0, scale = 1.0,
			healthBar = {enabled = true},
			powerBar = {enabled = true},
			emptyBar = {enabled = false},
			portrait = {enabled = false},
			castBar = {enabled = false, name = {}, time = {}},
			text = {
				{enabled = true, name = L["Left text"], text = "[name]", anchorPoint = "C", anchorTo = "$healthBar", size = 0},
				{enabled = true, name = L["Right text"], text = "[curmaxhp]", anchorPoint = "C", anchorTo = "$healthBar", size = 0},
				{enabled = true, name = L["Left text"], text = "[level] [race]", anchorPoint = "C", anchorTo = "$powerBar", size = 0},
				{enabled = true, name = L["Right text"], text = "[curmaxpp]", anchorPoint = "C", anchorTo = "$powerBar", size = 0},
				{enabled = true, name = L["Text"], text = "", anchorTo = "$emptyBar", anchorPoint = "C", size = 0, x = 0, y = 0}
			},
			indicators = {raidTarget = {enabled = true, size = 0}}, 
			highlight = {},
			auraIndicators = {enabled = false},
			auras = {
				buffs = {enabled = false, perRow = 10, maxRows = 4, selfScale = 1.30, prioritize = true, show = {player = true, boss = true, raid = true, consolidated = true, misc = true}, enlarge = {}, timers = {ALL = true}},
				debuffs = {enabled = false, perRow = 10, maxRows = 4, selfScale = 1.30, show = {player = true, boss = true, raid = true, consolidated = true, misc = true}, enlarge = {SELF = true}, timers = {ALL = true}},
			},
		}
		
		if( not self.fakeUnits[unit] ) then
			self.defaults.profile.units[unit].combatText = {enabled = true, anchorTo = "$parent", anchorPoint = "C", x = 0, y = 0}

			if( unit ~= "battleground" and unit ~= "battlegroundpet" and unit ~= "arena" and unit ~= "arenapet" and unit ~= "boss" ) then
				self.defaults.profile.units[unit].incHeal = {enabled = true, cap = 1.20}
				self.defaults.profile.units[unit].incAbsorb = {enabled = true, cap = 1.30}
				self.defaults.profile.units[unit].healAbsorb = {enabled = true, cap = 1.30}
			end
		end
		
		if( unit ~= "player" ) then
			self.defaults.profile.units[unit].range = {enabled = false, oorAlpha = 0.80, inAlpha = 1.0}

			if( not string.match(unit, "pet") ) then
				self.defaults.profile.units[unit].indicators.class = {enabled = false, size = 19}
			end
		end

		if( unit == "player" or unit == "party" or unit == "target" or unit == "raid" or unit == "focus" or unit == "mainassist" or unit == "maintank" ) then
			self.defaults.profile.units[unit].indicators.leader = {enabled = true, size = 0}
			self.defaults.profile.units[unit].indicators.masterLoot = {enabled = true, size = 0}
			self.defaults.profile.units[unit].indicators.pvp = {enabled = true, size = 0}
			self.defaults.profile.units[unit].indicators.role = {enabled = true, size = 0}
			self.defaults.profile.units[unit].indicators.status = {enabled = false, size = 19}
			self.defaults.profile.units[unit].indicators.resurrect = {enabled = true}

			if( unit ~= "focus" and unit ~= "target" ) then
				self.defaults.profile.units[unit].indicators.ready = {enabled = true, size = 0}
			end
		end

		if( unit == "battleground" ) then
			self.defaults.profile.units[unit].indicators.pvp = {enabled = true, size = 0}
		end

		self.defaults.profile.units[unit].altPowerBar = {enabled = not ShadowUF.fakeUnits[unit]}
	end

	-- PLAYER
	self.defaults.profile.units.player.enabled = true
	self.defaults.profile.units.player.healthBar.predicted = true
	self.defaults.profile.units.player.powerBar.predicted = true
	self.defaults.profile.units.player.indicators.status.enabled = true
	self.defaults.profile.units.player.runeBar = {enabled = false}
	self.defaults.profile.units.player.totemBar = {enabled = false}
	self.defaults.profile.units.player.druidBar = {enabled = false}
	self.defaults.profile.units.player.monkBar = {enabled = false}
	self.defaults.profile.units.player.xpBar = {enabled = false}
	self.defaults.profile.units.player.fader = {enabled = false}
	self.defaults.profile.units.player.soulShards = {enabled = true, isBar = true}
	self.defaults.profile.units.player.staggerBar = {enabled = true}
	self.defaults.profile.units.player.demonicFuryBar = {enabled = true}
	self.defaults.profile.units.player.comboPoints = {enabled = true, isBar = true}
	self.defaults.profile.units.player.burningEmbersBar = {enabled = true}
	self.defaults.profile.units.player.eclipseBar = {enabled = true}
	self.defaults.profile.units.player.holyPower = {enabled = true, isBar = true}
	self.defaults.profile.units.player.shadowOrbs = {enabled = true, isBar = true}
	self.defaults.profile.units.player.chi = {enabled = true, isBar = true}
	self.defaults.profile.units.player.indicators.lfdRole = {enabled = true, size = 0, x = 0, y = 0}
	self.defaults.profile.units.player.auraPoints = {enabled = false, isBar = true}
	table.insert(self.defaults.profile.units.player.text, {enabled = true, text = "", anchorTo = "", anchorPoint = "C", size = 0, x = 0, y = 0, default = true})
	table.insert(self.defaults.profile.units.player.text, {enabled = true, text = "", anchorTo = "", anchorPoint = "C", size = 0, x = 0, y = 0, default = true})
	table.insert(self.defaults.profile.units.player.text, {enabled = true, text = "", anchorTo = "", anchorPoint = "C", size = 0, x = 0, y = 0, default = true})
	table.insert(self.defaults.profile.units.player.text, {enabled = true, text = "", anchorTo = "", anchorPoint = "C", size = 0, x = 0, y = 0, default = true})
	table.insert(self.defaults.profile.units.player.text, {enabled = true, text = "", anchorTo = "", anchorPoint = "C", size = 0, x = 0, y = 0, default = true})

    -- PET
	self.defaults.profile.units.pet.enabled = true
	self.defaults.profile.units.pet.fader = {enabled = false, combatAlpha = 1.0, inactiveAlpha = 0.60}
	self.defaults.profile.units.pet.xpBar = {enabled = false}
    -- FOCUS
	self.defaults.profile.units.focus.enabled = true
	self.defaults.profile.units.focus.fader = {enabled = false, combatAlpha = 1.0, inactiveAlpha = 0.60}
	self.defaults.profile.units.focus.indicators.lfdRole = {enabled = false, size = 0, x = 0, y = 0}
	self.defaults.profile.units.focus.indicators.questBoss = {enabled = true, size = 0, x = 0, y = 0}
	-- FOCUSTARGET
	self.defaults.profile.units.focustarget.enabled = true
	self.defaults.profile.units.focustarget.fader = {enabled = false, combatAlpha = 1.0, inactiveAlpha = 0.60}
	-- TARGET
	self.defaults.profile.units.target.enabled = true
	self.defaults.profile.units.target.indicators.lfdRole = {enabled = false, size = 0, x = 0, y = 0}
	self.defaults.profile.units.target.indicators.questBoss = {enabled = true, size = 0, x = 0, y = 0}
	self.defaults.profile.units.target.comboPoints = {enabled = false, isBar = true}
	-- TARGETTARGET/TARGETTARGETTARGET
	self.defaults.profile.units.targettarget.enabled = true
	self.defaults.profile.units.targettargettarget.enabled = true
	-- PARTY
	self.defaults.profile.units.party.enabled = true
	self.defaults.profile.units.party.auras.debuffs.maxRows = 1
	self.defaults.profile.units.party.auras.buffs.maxRows = 1
	self.defaults.profile.units.party.fader = {enabled = false, combatAlpha = 1.0, inactiveAlpha = 0.60}
	self.defaults.profile.units.party.combatText.enabled = false
	self.defaults.profile.units.party.indicators.lfdRole = {enabled = true, size = 0, x = 0, y = 0}
	self.defaults.profile.units.party.indicators.phase = {enabled = true, size = 0, x = 0, y = 0}
	-- ARENA
	self.defaults.profile.units.arena.enabled = false
	self.defaults.profile.units.arena.attribPoint = "TOP"
	self.defaults.profile.units.arena.attribAnchorPoint = "LEFT"
	self.defaults.profile.units.arena.auras.debuffs.maxRows = 1
	self.defaults.profile.units.arena.auras.buffs.maxRows = 1
	self.defaults.profile.units.arena.offset = 0
	self.defaults.profile.units.arena.indicators.arenaSpec = {enabled = true, size = 0, x = 0, y = 0}
	self.defaults.profile.units.arena.indicators.lfdRole = {enabled = true, size = 0, x = 0, y = 0}
	-- BATTLEGROUND
	self.defaults.profile.units.battleground.enabled = false
	self.defaults.profile.units.battleground.attribPoint = "TOP"
	self.defaults.profile.units.battleground.attribAnchorPoint = "LEFT"
	self.defaults.profile.units.battleground.auras.debuffs.maxRows = 1
	self.defaults.profile.units.battleground.auras.buffs.maxRows = 1
	self.defaults.profile.units.battleground.offset = 0
	-- BOSS
	self.defaults.profile.units.boss.enabled = false
	self.defaults.profile.units.boss.attribPoint = "TOP"
	self.defaults.profile.units.boss.attribAnchorPoint = "LEFT"
	self.defaults.profile.units.boss.auras.debuffs.maxRows = 1
	self.defaults.profile.units.boss.auras.buffs.maxRows = 1
	self.defaults.profile.units.boss.offset = 0
	self.defaults.profile.units.boss.altPowerBar.enabled = true
	-- RAID
	self.defaults.profile.units.raid.groupBy = "GROUP"
	self.defaults.profile.units.raid.sortOrder = "ASC"
	self.defaults.profile.units.raid.sortMethod = "INDEX"
	self.defaults.profile.units.raid.attribPoint = "TOP"
	self.defaults.profile.units.raid.attribAnchorPoint = "RIGHT"
	self.defaults.profile.units.raid.offset = 0
	self.defaults.profile.units.raid.filters = {[1] = true, [2] = true, [3] = true, [4] = true, [5] = true, [6] = true, [7] = true, [8] = true}
	self.defaults.profile.units.raid.fader = {enabled = false, combatAlpha = 1.0, inactiveAlpha = 0.60}
	self.defaults.profile.units.raid.combatText.enabled = false
	self.defaults.profile.units.raid.indicators.lfdRole = {enabled = true, size = 0, x = 0, y = 0}
	-- RAID PET
	self.defaults.profile.units.raidpet.groupBy = "GROUP"
	self.defaults.profile.units.raidpet.sortOrder = "ASC"
	self.defaults.profile.units.raidpet.sortMethod = "INDEX"
	self.defaults.profile.units.raidpet.attribPoint = "TOP"
	self.defaults.profile.units.raidpet.attribAnchorPoint = "RIGHT"
	self.defaults.profile.units.raidpet.offset = 0
	self.defaults.profile.units.raidpet.filters = {[1] = true, [2] = true, [3] = true, [4] = true, [5] = true, [6] = true, [7] = true, [8] = true}
	self.defaults.profile.units.raidpet.fader = {enabled = false, combatAlpha = 1.0, inactiveAlpha = 0.60}
	self.defaults.profile.units.raidpet.combatText.enabled = false
	-- MAINTANK
	self.defaults.profile.units.maintank.roleFilter = "TANK"
	self.defaults.profile.units.maintank.groupFilter = "MAINTANK"
	self.defaults.profile.units.maintank.groupBy = "GROUP"
	self.defaults.profile.units.maintank.sortOrder = "ASC"
	self.defaults.profile.units.maintank.sortMethod = "INDEX"
	self.defaults.profile.units.maintank.attribPoint = "TOP"
	self.defaults.profile.units.maintank.attribAnchorPoint = "RIGHT"
	self.defaults.profile.units.maintank.offset = 0
	self.defaults.profile.units.maintank.fader = {enabled = false, combatAlpha = 1.0, inactiveAlpha = 0.60}
	-- MAINASSIST
	self.defaults.profile.units.mainassist.groupFilter = "MAINASSIST"
	self.defaults.profile.units.mainassist.groupBy = "GROUP"
	self.defaults.profile.units.mainassist.sortOrder = "ASC"
	self.defaults.profile.units.mainassist.sortMethod = "INDEX"
	self.defaults.profile.units.mainassist.attribPoint = "TOP"
	self.defaults.profile.units.mainassist.attribAnchorPoint = "RIGHT"
	self.defaults.profile.units.mainassist.offset = 0
	self.defaults.profile.units.mainassist.fader = {enabled = false, combatAlpha = 1.0, inactiveAlpha = 0.60}
	-- PARTYPET
	self.defaults.profile.positions.partypet.anchorTo = "$parent"
	self.defaults.profile.positions.partypet.anchorPoint = "RB"
	self.defaults.profile.units.partypet.fader = {enabled = false, combatAlpha = 1.0, inactiveAlpha = 0.60}
	-- PARTYTARGET
	self.defaults.profile.positions.partytarget.anchorTo = "$parent"
	self.defaults.profile.positions.partytarget.anchorPoint = "RT"
	self.defaults.profile.units.partytarget.fader = {enabled = false, combatAlpha = 1.0, inactiveAlpha = 0.60}
	-- PARTYTARGETTARGET
	self.defaults.profile.positions.partytarget.anchorTo = "$parent"
	self.defaults.profile.positions.partytarget.anchorPoint = "RT"
	self.defaults.profile.units.partytarget.fader = {enabled = false, combatAlpha = 1.0, inactiveAlpha = 0.60}

	-- Aura indicators
	self.defaults.profile.auraIndicators = {
		disabled = {},
		missing = {},
		linked = {
			[GetSpellInfo(61316)] = GetSpellInfo(1459), -- Dalarn Brilliance -> AB
			[GetSpellInfo(109773)] = GetSpellInfo(1459), -- Dark Intent -> AB
			[GetSpellInfo(126309)] = GetSpellInfo(1459) -- Waterstrider -> AB
		},
		indicators = {
			["tl"] = {name = L["Top Left"], anchorPoint = "TLI", anchorTo = "$parent", height = 8, width = 8, alpha = 1.0, x = 4, y = -4, friendly = true, hostile = true},
			["tr"] = {name = L["Top Right"], anchorPoint = "TRI", anchorTo = "$parent", height = 8, width = 8, alpha = 1.0, x = -3, y = -3, friendly = true, hostile = true},
			["bl"] = {name = L["Bottom Left"], anchorPoint = "BLI", anchorTo = "$parent", height = 8, width = 8, alpha = 1.0, x = 4, y = 4, friendly = true, hostile = true},
			["br"] = {name = L["Bottom Right"], anchorPoint = "BRI", anchorTo = "$parent", height = 8, width = 8, alpha = 1.0, x = -4, y = -4, friendly = true, hostile = true},
			["c"] = {name = L["Center"], anchorPoint = "C", anchorTo = "$parent", height = 20, width = 20, alpha = 1.0, x = 0, y = 0, friendly = true, hostile = true},
		},
		filters = {
			["tl"] = {boss = {priority = 100}, curable = {priority = 100}},
			["tr"] = {boss = {priority = 100}, curable = {priority = 100}},
			["bl"] = {boss = {priority = 100}, curable = {priority = 100}},
			["br"] = {boss = {priority = 100}, curable = {priority = 100}},
			["c"] = {boss = {priority = 100}, curable = {priority = 100}},
		},
		auras = {
			["17"] = "{r=1;group=\"Priest\";indicator=\"tl\";g=0.41960784313725;player=true;alpha=1;duration=true;b=0.5843137254902;priority=0;icon=false;iconTexture=\"Interface\\\\Icons\\\\Spell_Holy_PowerWordShield\";}",
			["139"] = "{r=0.23921568627451;group=\"Priest\";indicator=\"tr\";g=1;player=true;alpha=1;duration=true;b=0.39607843137255;priority=10;icon=false;iconTexture=\"Interface\\\\Icons\\\\Spell_Holy_Renew\";}",
			["498"] = "{r=0;group=\"Paladin\";indicator=\"c\";g=0;duration=true;b=0;priority=0;icon=true;iconTexture=\"Interface\\\\Icons\\\\spell_holy_divineprotection\";}",
			["586"] = "{r=0;group=\"Priest\";indicator=\"\";g=0.85882352941176;selfColor={alpha=1;b=1;g=0.93725490196078;r=0;};alpha=1;priority=0;b=1;iconTexture=\"Interface\\\\Icons\\\\Spell_Magic_LesserInvisibilty\";}",
			["774"] = "{r=0.57647058823529;group=\"Druid\";indicator=\"tr\";g=0.28235294117647;player=true;duration=true;b=0.6156862745098;priority=100;alpha=1;iconTexture=\"Interface\\\\Icons\\\\Spell_Nature_Rejuvenation\";}",
			["871"] = "{r=0;group=\"Warrior\";indicator=\"c\";g=0;duration=true;b=0;priority=10;icon=true;iconTexture=\"Interface\\\\Icons\\\\Ability_Warrior_ShieldWall\";}",
			["974"] = "{r=1;group=\"Shaman\";indicator=\"tr\";g=0.65882352941176;player=true;alpha=1;priority=10;b=0.27843137254902;iconTexture=\"Interface\\\\Icons\\\\Spell_Nature_SkinofEarth\";}",
			["1022"] = "{r=0;group=\"Paladin\";indicator=\"c\";g=0;player=false;duration=true;b=0;priority=0;icon=true;iconTexture=\"Interface\\\\Icons\\\\Spell_Holy_SealOfProtection\";}",
			["1126"] = "{r=0.47450980392157;group=\"Druid\";indicator=\"\";g=0.2156862745098;player=true;duration=true;missing=true;b=0.81960784313725;priority=0;alpha=1;iconTexture=\"Interface\\\\Icons\\\\Spell_Nature_Regeneration\";}",
			["1459"] = "{indicator=\"\";group=\"Mage\";priority=10;r=0.10;g=0.68;b=0.88}",
			["5277"] = "{b=0;group=\"Rogue\";indicator=\"c\";g=0;duration=true;r=0;priority=1;icon=true;iconTexture=\"Interface\\\\Icons\\\\Spell_Shadow_ShadowWard\";}",
			["6788"] = "{b=0.29019607843137;group=\"Priest\";indicator=\"tl\";alpha=1;player=false;g=0.56862745098039;duration=true;r=0.83921568627451;priority=20;icon=false;iconTexture=\"Interface\\\\Icons\\\\Spell_Holy_AshesToAshes\";}",
			["8936"] = "{r=0.12156862745098;group=\"Druid\";indicator=\"br\";g=0.45882352941176;player=true;duration=true;b=0.12156862745098;priority=100;alpha=1;iconTexture=\"Interface\\\\Icons\\\\Spell_Nature_ResistNature\";}",
			["12975"] = "{r=0;group=\"Warrior\";indicator=\"c\";g=0;duration=true;b=0;priority=10;icon=true;iconTexture=\"Interface\\\\Icons\\\\Spell_Holy_AshesToAshes\";}",
			["15286"] = "{r=0;group=\"Priest\";indicator=\"c\";g=0;player=false;duration=true;alpha=1;b=0;priority=1;icon=true;iconTexture=\"Interface\\\\Icons\\\\Spell_Shadow_UnsummonBuilding\";}",
			["19705"] = "{r=0.80392156862745;group=\"Food\";indicator=\"\";g=0.76470588235294;missing=true;duration=true;priority=0;alpha=1;b=0.24313725490196}",
			["19740"] = "{r=0.93333333333333;group=\"Paladin\";indicator=\"\";g=0.84705882352941;selfColor={alpha=1;b=0.18823529411765;g=0.89411764705882;r=0.9843137254902;};player=false;missing=true;duration=true;alpha=1;priority=0;b=0.15294117647059;iconTexture=\"Interface\\\\Icons\\\\Spell_Holy_GreaterBlessingofKings\";}",
			["20217"] = "{r=1;group=\"Paladin\";indicator=\"\";g=0.30196078431373;selfColor={alpha=1;b=0.91764705882353;g=0.058823529411765;r=1;};player=false;duration=true;missing=true;alpha=1;priority=90;b=0.94117647058824;iconTexture=\"Interface\\\\Icons\\\\Spell_Magic_GreaterBlessingofKings\";}",
			["20707"] = "{indicator=\"\";group=\"Warlock\";priority=10;r=0.42;g=0.21;b=0.65}",
			["20925"] = "{r=1;group=\"Paladin\";indicator=\"tl\";g=0.98823529411765;selfColor={b=0.56078431372549;alpha=1;g=0.93725490196078;r=1;};player=true;duration=true;alpha=1;priority=100;b=0.47450980392157;iconTexture=\"Interface\\\\Icons\\\\Ability_Paladin_BlessedMending\";}",
			["21562"] = "{r=1;group=\"Priest\";indicator=\"\";g=1;alpha=1;missing=true;priority=0;b=1;iconTexture=\"Interface\\\\Icons\\\\Spell_Holy_WordFortitude\";}",
			["23333"] = "{icon=true;b=0;priority=0;r=0;group=\"PvP Flags\";indicator=\"bl\";g=0;iconTexture=\"Interface\\\\Icons\\\\INV_BannerPVP_01\";}",
			["23335"] = "{r=0;group=\"PvP Flags\";indicator=\"bl\";g=0;duration=false;b=0;priority=0;icon=true;iconTexture=\"Interface\\\\Icons\\\\INV_BannerPVP_02\";}",
			["27827"] = "{r=0;group=\"Priest\";indicator=\"c\";g=0;duration=true;b=0;priority=0;icon=true;iconTexture=\"Interface\\\\Icons\\\\INV_Enchant_EssenceEternalLarge\";}",			
			["31224"] = "{b=0;group=\"Rogue\";indicator=\"c\";g=0;duration=true;r=0;priority=1;icon=true;iconTexture=\"Interface\\\\Icons\\\\Spell_Shadow_NetherCloak\";}",
			["31821"] = "{r=0;group=\"Paladin\";duration=true;g=0;b=0;indicator=\"\";priority=0;icon=true;iconTexture=\"Interface\\\\Icons\\\\Spell_Holy_AuraMastery\";}",			
			["31850"] = "{b=0;group=\"Paladin\";indicator=\"c\";g=0;player=false;duration=true;r=0;priority=10;icon=true;iconTexture=\"Interface\\\\Icons\\\\Spell_Holy_ArdentDefender\";}",
			["33206"] = "{r=0;group=\"Priest\";indicator=\"c\";g=0;b=0;duration=true;priority=0;icon=true;iconTexture=\"Interface\\\\Icons\\\\Spell_Holy_PainSupression\";}",
			["33763"] = "{r=0.23137254901961;group=\"Druid\";indicator=\"tl\";g=1;player=true;duration=true;alpha=1;priority=0;b=0.2;iconTexture=\"Interface\\\\Icons\\\\INV_Misc_Herb_Felblossom\";}",			
			["34976"] = "{r=0;group=\"PvP Flags\";indicator=\"bl\";g=0;player=false;b=0;priority=0;icon=true;iconTexture=\"Interface\\\\Icons\\\\INV_BannerPVP_03\";}",
			["41635"] = "{r=1;group=\"Priest\";indicator=\"br\";g=0.90196078431373;missing=false;player=true;duration=false;alpha=1;b=0;priority=50;icon=false;iconTexture=\"Interface\\\\Icons\\\\Spell_Holy_PrayerOfMendingtga\";}",
			["47585"] = "{r=0;group=\"Priest\";indicator=\"c\";g=0;duration=true;b=0;priority=1;icon=true;iconTexture=\"Interface\\\\Icons\\\\Spell_Shadow_Dispersion\";}",
			["47753"] = "{b=0;group=\"Priest\";indicator=\"br\";alpha=1;player=true;duration=true;r=0.8078431372549;priority=0;g=0.76862745098039;iconTexture=\"Interface\\\\Icons\\\\Spell_Holy_DevineAegis\";}",						
			["47788"] = "{r=0;group=\"Priest\";indicator=\"c\";g=0;b=0;duration=true;priority=1;icon=true;iconTexture=\"Interface\\\\Icons\\\\Spell_Holy_GuardianSpirit\";}",
			["48438"] = "{r=0.55294117647059;group=\"Druid\";indicator=\"31685\";g=1;player=true;duration=true;b=0.3921568627451;priority=100;alpha=1;iconTexture=\"Interface\\\\Icons\\\\Ability_Druid_Flourish\";}",
			["48707"] = "{r=0;group=\"Death Knight\";indicator=\"c\";g=0;duration=true;b=0;priority=0;icon=true;iconTexture=\"Interface\\\\Icons\\\\Spell_Shadow_AntiMagicShell\";}",
			["48792"] = "{b=0;group=\"Death Knight\";indicator=\"c\";g=0;duration=true;r=0;priority=10;icon=true;iconTexture=\"Interface\\\\Icons\\\\Spell_DeathKnight_IceBoundFortitude\";}",
			["50461"] = "{r=0;group=\"Death Knight\";indicator=\"c\";g=0;duration=true;b=0;priority=0;icon=true;iconTexture=\"Interface\\\\Icons\\\\Spell_DeathKnight_AntiMagicZone\";}",
			["53563"] = "{r=0.64313725490196;group=\"Paladin\";indicator=\"tr\";g=0.24705882352941;player=true;alpha=1;b=0.73333333333333;priority=100, duration=false;iconTexture=\"Interface\\\\Icons\\\\Ability_Paladin_BeaconofLight\";}",
			["55233"] = "{r=0;group=\"Death Knight\";indicator=\"c\";g=0;duration=true;b=0;priority=10;icon=true;iconTexture=\"Interface\\\\Icons\\\\Spell_Shadow_LifeDrain\";}",
			["55646"] = "{icon=true;b=0;priority=0;r=0;group=\"Wrath of the Lich King\";indicator=\"c\";g=0;iconTexture=\"Interface\\\\Icons\\\\Spell_Shadow_LifeDrain02\";}",
			["61295"] = "{r=0.17647058823529;group=\"Shaman\";indicator=\"tl\";g=0.4;player=true;alpha=1;duration=true;b=1;priority=0;icon=false;iconTexture=\"Interface\\\\Icons\\\\spell_nature_riptide\";}",
			["61316"] = "{alpha=1;b=1;priority=0;r=0;group=\"Mage\";indicator=\"\";g=0.96078431372549;iconTexture=\"Interface\\\\Icons\\\\Achievement_Dungeon_TheVioletHold_Heroic\";}",
			["61888"] = "{icon=true;b=0;priority=0;r=0;group=\"Wrath of the Lich King\";indicator=\"c\";g=0;iconTexture=\"Interface\\\\Icons\\\\Spell_Shaman_AncestralAwakening\";}",
			["61990"] = "{r=0;group=\"Wrath of the Lich King\";indicator=\"c\";g=0;duration=false;b=0;priority=0;icon=true;iconTexture=\"Interface\\\\Icons\\\\Ability_Mage_DeepFreeze\";}",
			["62055"] = "{icon=true;b=0;priority=0;r=0;group=\"Wrath of the Lich King\";indicator=\"c\";g=0;iconTexture=\"Interface\\\\Icons\\\\Spell_Shaman_ImprovedEarthShield\";}",
			["62376"] = "{r=0;group=\"Wrath of the Lich King\";indicator=\"c\";g=0;player=false;b=0;priority=0;icon=true;iconTexture=\"Interface\\\\Icons\\\\INV_Ammo_Bullet_08\";}",
			["62930"] = "{icon=true;b=0;priority=0;r=0;group=\"Wrath of the Lich King\";indicator=\"c\";g=0;iconTexture=\"Interface\\\\Icons\\\\Spell_Nature_StrangleVines\";}",
			["63018"] = "{icon=true;b=0;priority=0;r=0;group=\"Wrath of the Lich King\";indicator=\"\";g=0;iconTexture=\"Interface\\\\Icons\\\\Ability_Paladin_InfusionofLight\";}",
			["63038"] = "{icon=true;b=0;priority=0;r=0;group=\"Wrath of the Lich King\";indicator=\"c\";g=0;iconTexture=\"Interface\\\\Icons\\\\Spell_Shadow_Shadowfury\";}",
			["63042"] = "{r=0;group=\"Wrath of the Lich King\";indicator=\"c\";g=0;duration=true;b=0;priority=100;icon=true;iconTexture=\"Interface\\\\Icons\\\\Spell_Shadow_ShadowWordDominate\";}",
			["63120"] = "{r=0;group=\"Wrath of the Lich King\";indicator=\"c\";g=0;duration=true;b=0;priority=100;icon=true;iconTexture=\"Interface\\\\Icons\\\\INV_Helmet_01\";}",
			["63134"] = "{icon=true;b=0;priority=25;r=0;group=\"Wrath of the Lich King\";indicator=\"c\";g=0;iconTexture=\"Interface\\\\Icons\\\\Spell_Shadow_DemonicEmpathy\";}",
			["63147"] = "{icon=true;b=0;priority=50;r=0;group=\"Wrath of the Lich King\";indicator=\"c\";g=0;iconTexture=\"Interface\\\\Icons\\\\Spell_Shadow_DemonForm\";}",		
			["63277"] = "{icon=true;b=0;priority=0;r=0;group=\"Wrath of the Lich King\";indicator=\"c\";g=0;iconTexture=\"Interface\\\\Icons\\\\Spell_Shadow_PainSpike\";}",
			["63322"] = "{icon=true;b=0;priority=0;r=0;group=\"Wrath of the Lich King\";indicator=\"c\";g=0;iconTexture=\"Interface\\\\Icons\\\\inv_ore_saronite_01\";}",
			["63477"] = "{icon=true;b=0;priority=0;r=0;group=\"Wrath of the Lich King\";indicator=\"\";g=0;iconTexture=\"Interface\\\\Icons\\\\INV_GAUNTLETS_66\";}",
			["63493"] = "{icon=true;b=0;priority=0;r=0;group=\"Wrath of the Lich King\";indicator=\"c\";g=0;iconTexture=\"Interface\\\\Icons\\\\Ability_GolemThunderClap\";}",
			["63571"] = "{icon=true;b=0;priority=100;r=0;group=\"Wrath of the Lich King\";indicator=\"c\";g=0;iconTexture=\"Interface\\\\Icons\\\\Spell_Shaman_StaticShock\";}",
			["63830"] = "{r=0;group=\"Wrath of the Lich King\";indicator=\"c\";g=0;duration=true;b=0;priority=50;icon=true;iconTexture=\"Interface\\\\Icons\\\\Spell_Shadow_DeathCoil\";}",
			["64126"] = "{icon=true;b=0;priority=100;r=0;group=\"Wrath of the Lich King\";indicator=\"c\";g=0;iconTexture=\"Interface\\\\Icons\\\\Ability_Creature_Poison_04\";}",
			["64152"] = "{icon=true;b=0;priority=0;r=0;group=\"Wrath of the Lich King\";indicator=\"c\";g=0;iconTexture=\"Interface\\\\Icons\\\\Spell_Nature_NullifyPoison\";}",
			["64157"] = "{r=0;group=\"Wrath of the Lich King\";indicator=\"c\";g=0;duration=true;b=0;priority=0;icon=true;iconTexture=\"Interface\\\\Icons\\\\Spell_Shadow_AuraOfDarkness\";}",
			["64159"] = "{icon=true;b=0;priority=0;r=0;group=\"Wrath of the Lich King\";indicator=\"c\";g=0;iconTexture=\"Interface\\\\Icons\\\\Spell_Shadow_LifeDrain02\";}",
			["64234"] = "{icon=true;b=0;priority=0;r=0;group=\"Wrath of the Lich King\";indicator=\"c\";g=0;iconTexture=\"Interface\\\\Icons\\\\inv_ingot_titansteel_dark\";}",
			["64292"] = "{icon=true;b=0;priority=0;r=0;group=\"Wrath of the Lich King\";indicator=\"c\";g=0;iconTexture=\"Interface\\\\Icons\\\\Ability_Warrior_SecondWind\";}",
			["64392"] = "{icon=true;b=0;priority=0;r=0;group=\"Wrath of the Lich King\";indicator=\"c\";g=0;iconTexture=\"Interface\\\\Icons\\\\Spell_Shadow_FocusedPower\";}",
			["64478"] = "{icon=true;b=0;priority=0;r=0;group=\"Wrath of the Lich King\";indicator=\"c\";g=0;iconTexture=\"Interface\\\\Icons\\\\Ability_Druid_PrimalTenacity\";}",
			["64667"] = "{icon=true;b=0;priority=0;r=0;group=\"Wrath of the Lich King\";indicator=\"c\";g=0;iconTexture=\"Interface\\\\Icons\\\\Ability_Druid_Rake\";}",
			["64704"] = "{r=0;group=\"Wrath of the Lich King\";indicator=\"c\";g=0;duration=false;b=0;priority=0;icon=true;iconTexture=\"Interface\\\\Icons\\\\Spell_Fire_BlueFlameStrike\";}",
			["64844"] = "{r=0.67843137254902;group=\"Priest\";indicator=\"31685\";g=0.30588235294118;player=true;alpha=1;priority=0;b=0.14117647058824;iconTexture=\"Interface\\\\Icons\\\\Spell_Holy_DivineProvidence\";}",
			["65775"] = "{r=0;group=\"Wrath of the Lich King\";indicator=\"c\";g=0;duration=true;b=0;priority=70;icon=true;iconTexture=\"Interface\\\\Icons\\\\Ability_Creature_Poison_01\";}",
			["65950"] = "{icon=true;b=0;priority=70;r=0;group=\"Wrath of the Lich King\";indicator=\"c\";g=0;iconTexture=\"Interface\\\\Icons\\\\Ability_Paladin_InfusionofLight\";}",
			["66001"] = "{icon=true;b=0;priority=42;r=0;group=\"Wrath of the Lich King\";indicator=\"c\";g=0;iconTexture=\"Interface\\\\Icons\\\\Spell_Shadow_ChillTouch\";}",
			["66013"] = "{r=0;group=\"Wrath of the Lich King\";indicator=\"c\";g=0;duration=true;b=0;priority=70;icon=true;iconTexture=\"Interface\\\\Icons\\\\Spell_Frost_ColdHearted\";}",
			["66197"] = "{icon=true;b=0;priority=75;r=0;group=\"Wrath of the Lich King\";indicator=\"c\";g=0;iconTexture=\"Interface\\\\Icons\\\\Spell_Fire_FelImmolation\";}",
			["66237"] = "{icon=true;b=0;priority=100;r=0;group=\"Wrath of the Lich King\";indicator=\"c\";g=0;iconTexture=\"Interface\\\\Icons\\\\Ability_Warlock_FireandBrimstone\";}",
			["66406"] = "{icon=true;b=0;priority=0;r=0;group=\"Wrath of the Lich King\";indicator=\"c\";g=0;iconTexture=\"Interface\\\\Icons\\\\Ability_Mage_TormentOfTheWeak\";}",
			["66823"] = "{icon=true;b=0;priority=0;r=0;group=\"Wrath of the Lich King\";indicator=\"c\";g=0;iconTexture=\"Interface\\\\Icons\\\\Ability_Creature_Poison_03\";}",
			["66869"] = "{icon=true;b=0;priority=0;r=0;group=\"Wrath of the Lich King\";indicator=\"c\";g=0;iconTexture=\"Interface\\\\Icons\\\\Ability_Mage_Burnout\";}",
			["69062"] = "{icon=true;b=0;priority=0;r=0;group=\"Wrath of the Lich King\";indicator=\"c\";g=0;iconTexture=\"Interface\\\\Icons\\\\INV_Misc_Bone_03\";}",
			["70109"] = "{r=0;group=\"Wrath of the Lich King\";indicator=\"c\";g=0;duration=false;b=0;priority=70;icon=true;iconTexture=\"Interface\\\\Icons\\\\Spell_Frost_ColdHearted\";}",
			["76577"] = "{b=0;group=\"Rogue\";indicator=\"c\";g=0;duration=true;r=0;priority=0;icon=true;iconTexture=\"Interface\\\\ICONS\\\\ability_rogue_smoke\";}",
			["77699"] = "{indicator=\"\";group=\"Blackwing Descent\";priority=10;icon=true}",
			["77760"] = "{indicator=\"\";group=\"Blackwing Descent\";priority=10;icon=true}",
			["77786"] = "{indicator=\"\";group=\"Blackwing Descent\";priority=10;icon=true}",
			["78092"] = "{indicator=\"\";group=\"Blackwing Descent\";priority=10;icon=true}",
			["78941"] = "{indicator=\"\";group=\"Blackwing Descent\";priority=10;icon=true}",
			["79318"] = "{indicator=\"\";group=\"Blackwing Descent\";priority=10;icon=true}",
			["79339"] = "{indicator=\"\";group=\"Blackwing Descent\";priority=10;icon=true}",
			["79501"] = "{indicator=\"\";group=\"Blackwing Descent\";priority=10;icon=true}",
			["79888"] = "{indicator=\"\";group=\"Blackwing Descent\";priority=10;icon=true}",
			["80094"] = "{indicator=\"\";group=\"Blackwing Descent\";priority=10;icon=true}",
			["81256"] = "{r=0;group=\"Death Knight\";indicator=\"c\";g=0;duration=true;b=0;priority=0;icon=true;iconTexture=\"Interface\\\\Icons\\\\INV_Sword_07\";}",
			["81782"] = "{r=0;group=\"Priest\";indicator=\"c\";g=0;duration=true;b=0;priority=0;icon=true;iconTexture=\"Interface\\\\Icons\\\\spell_holy_powerwordbarrier\";}",
			["82660"] = "{indicator=\"\";group=\"Bastion of Twilight\";priority=10;icon=true}",
			["82665"] = "{indicator=\"\";group=\"Bastion of Twilight\";priority=10;icon=true}",
			["82762"] = "{r=0;group=\"Bastion of Twilight\";indicator=\"c\";g=0;duration=true;b=0;priority=0;icon=true;iconTexture=\"Interface\\\\Icons\\\\INV_Elemental_Primal_Water\";}",
			["82772"] = "{indicator=\"\";group=\"Bastion of Twilight\";priority=10;icon=true}",
			["82935"] = "{indicator=\"\";group=\"Blackwing Descent\";priority=10;icon=true}",
			["83099"] = "{indicator=\"\";group=\"Bastion of Twilight\";priority=10;icon=true}",
			["84645"] = "{indicator=\"\";group=\"Mists of Pandaria\";priority=10;icon=true}",
			["84948"] = "{indicator=\"\";group=\"Bastion of Twilight\";priority=10;icon=true}",
			["86273"] = "{b=0;group=\"Paladin\";indicator=\"br\";g=0.45882352941176;player=true;duration=true;r=1;priority=100;alpha=1;iconTexture=\"Interface\\\\Icons\\\\Spell_Holy_Absolution\";}",
			["86622"] = "{indicator=\"\";group=\"Bastion of Twilight\";priority=10;icon=true}",
			["86788"] = "{indicator=\"\";group=\"Bastion of Twilight\";priority=10;icon=true}",
			["88518"] = "{indicator=\"\";group=\"Bastion of Twilight\";priority=10;icon=true}",
			["88954"] = "{indicator=\"\";group=\"Baradin Hold\";priority=10;icon=true}",
			["89084"] = "{indicator=\"\";group=\"Blackwing Descent\";priority=10;icon=true}",
			["89421"] = "{indicator=\"\";group=\"Bastion of Twilight\";priority=10;icon=true}",
			["89668"] = "{indicator=\"\";group=\"Mists of Pandaria\";priority=10;icon=true}",
			["89773"] = "{indicator=\"\";group=\"Blackwing Descent\";priority=10;icon=true}",
			["91317"] = "{indicator=\"\";group=\"Bastion of Twilight\";priority=10;icon=true}",
			["92053"] = "{indicator=\"\";group=\"Blackwing Descent\";priority=10;icon=true}",
			["92067"] = "{indicator=\"\";group=\"Bastion of Twilight\";priority=10;icon=true}",
			["92075"] = "{indicator=\"\";group=\"Bastion of Twilight\";priority=10;icon=true}",
			["92307"] = "{indicator=\"\";group=\"Bastion of Twilight\";priority=10;icon=true}",
			["92685"] = "{indicator=\"\";group=\"Blackwing Descent\";priority=10;icon=true}",
			["97235"] = "{r=0;group=\"Firelands\";indicator=\"c\";g=0;duration=false;b=0;priority=0;icon=true;iconTexture=\"Interface\\\\Icons\\\\Ability_Warrior_IntensifyRage\";}",
			["97238"] = "{icon=true;b=0;priority=0;r=0;group=\"Firelands\";indicator=\"c\";g=0;iconTexture=\"Interface\\\\ICONS\\\\ability_rogue_vigor\";}",
			["97463"] = "{b=0;group=\"Warrior\";indicator=\"c\";g=0;player=false;duration=true;r=0;priority=0;icon=true;iconTexture=\"Interface\\\\ICONS\\\\ability_toughness\";}",
			["98007"] = "{b=0;group=\"Shaman\";indicator=\"c\";g=0;duration=true;r=0;priority=0;icon=true;iconTexture=\"Interface\\\\Icons\\\\Spell_Shaman_SpiritLink\";}",
			["98450"] = "{duration=true;group=\"Firelands\";priority=10;icon=true;indicator=\"bl\";}",
			["98584"] = "{indicator=\"\";group=\"Firelands\";priority=10;icon=true}",
			["98928"] = "{indicator=\"\";group=\"Firelands\";priority=10;icon=true}",
			["99256"] = "{r=0;group=\"Firelands\";indicator=\"c\";g=0;duration=true;b=0;priority=88;icon=true;iconTexture=\"Interface\\\\Icons\\\\Spell_Shadow_TwistedFaith\";}",
			["99461"] = "{r=0;group=\"Firelands\";indicator=\"c\";g=0;duration=true;b=0;priority=90;icon=true;iconTexture=\"Interface\\\\Icons\\\\Spell_Fire_Incinerate\";}",
			["99476"] = "{indicator=\"\";group=\"Firelands\";priority=10;icon=true}",
			["99516"] = "{indicator=\"\";group=\"Firelands\";priority=10;icon=true}",
			["99526"] = "{indicator=\"\";group=\"Firelands\";priority=10;icon=true}",
			["99532"] = "{icon=true;b=0;priority=90;r=0;group=\"Firelands\";indicator=\"c\";g=0;iconTexture=\"Interface\\\\Icons\\\\Spell_Fire_Immolation\";}",
			["99837"] = "{group=\"Firelands\";indicator=\"c\";icon=true;priority=10;}",
			["99838"] = "{indicator=\"\";group=\"Firelands\";priority=15;icon=true}",
			["99849"] = "{indicator=\"\";group=\"Firelands\";priority=10;icon=true}",
			["99936"] = "{r=0;group=\"Firelands\";indicator=\"c\";g=0;duration=true;b=0;priority=0;icon=true;iconTexture=\"Interface\\\\Icons\\\\Ability_Gouge\";}",			
			["100460"] = "{indicator=\"\";group=\"Firelands\";priority=15;icon=true}",
			["101223"] = "{indicator=\"\";group=\"Firelands\";priority=10;icon=true}",
			["102342"] = "{r=0;group=\"Druid\";indicator=\"c\";g=0;duration=true;b=0;priority=0;icon=true;iconTexture=\"Interface\\\\Icons\\\\spell_druid_ironbark\";}",
			["103434"] = "{indicator=\"\";group=\"Dragonsoul\";priority=10;icon=true}",
			["105171"] = "{indicator=\"\";group=\"Dragonsoul\";priority=10;icon=true}",
			["105479"] = "{indicator=\"\";group=\"Dragonsoul\";priority=10;icon=true}",
			["105490"] = "{indicator=\"\";group=\"Dragonsoul\";priority=10;icon=true}",
			["106199"] = "{indicator=\"\";group=\"Dragonsoul\";priority=10;icon=true}",
			["106466"] = "{r=0;group=\"Dragonsoul\";indicator=\"c\";g=0;duration=true;b=0;priority=0;icon=true;iconTexture=\"Interface\\\\Icons\\\\Spell_Nature_WispSplodeGreen\";}",
			["106730"] = "{indicator=\"\";group=\"Dragonsoul\";priority=10;icon=true}",
			["106794"] = "{indicator=\"\";group=\"Dragonsoul\";priority=10;icon=true}",
			["107439"] = "{indicator=\"\";group=\"Dragonsoul\";priority=10;icon=true}",
			["108649"] = "{indicator=\"\";group=\"Dragonsoul\";priority=10;icon=true}",
			["109075"] = "{indicator=\"\";group=\"Dragonsoul\";priority=10;icon=true}",
			["109325"] = "{indicator=\"\";group=\"Dragonsoul\";priority=10;icon=true}",
			["109773"] = "{r=0.52941176470588;group=\"Warlock\";indicator=\"\";g=0.12941176470588;alpha=1;b=0.71372549019608;priority=0;missing=true;iconTexture=\"Interface\\\\Icons\\\\spell_warlock_focusshadow\";}",
			["110214"] = "{indicator=\"\";group=\"Dragonsoul\";priority=10;icon=true}",
			["114030"] = "{b=0;group=\"Warrior\";indicator=\"c\";g=0;duration=true;r=0;priority=10;icon=true;iconTexture=\"Interface\\\\Icons\\\\Ability_Warrior_Vigilance\";}",
			["115921"] = "{r=0.30980392156863;group=\"Monk\";indicator=\"\";g=0.69411764705882;selfColor={alpha=1;b=0.36078431372549;g=0.71764705882353;r=0.29803921568627;};missing=true;alpha=1;duration=true;priority=0;b=0.019607843137255;iconTexture=\"Interface\\\\Icons\\\\ability_monk_legacyoftheemperor\";}",
			["116417"] = "{r=0;group=\"Mists of Pandaria\";indicator=\"c\";g=0;duration=true;b=0;priority=0;icon=true;iconTexture=\"Interface\\\\Icons\\\\Spell_Shadow_TwistedFaith\";}",
			["116781"] = "{r=0.45098039215686;group=\"Monk\";indicator=\"\";g=0.49411764705882;selfColor={alpha=1;b=0.4078431372549;g=0.43137254901961;r=0.4078431372549;};missing=true;duration=false;b=0.48627450980392;alpha=1;priority=0;icon=false;iconTexture=\"Interface\\\\Icons\\\\ability_monk_prideofthetiger\";}",
			["116784"] = "{icon=true;b=0;priority=0;r=0;group=\"Mists of Pandaria\";indicator=\"c\";g=0;iconTexture=\"Interface\\\\Icons\\\\Spell_Fire_Burnout\";}",
			["116849"] = "{r=0.19607843137255;group=\"Monk\";indicator=\"c\";g=1;player=false;duration=true;b=0.3843137254902;alpha=1;priority=0;icon=true;iconTexture=\"Interface\\\\Icons\\\\ability_monk_chicocoon\";}",
			["116888"] = "{r=0;group=\"Death Knight\";indicator=\"c\";g=0;duration=true;b=0;alpha=1;priority=0;icon=true;iconTexture=\"Interface\\\\Icons\\\\INV_Misc_ShadowEgg\";}",
			["117878"] = "{r=0.1921568627451;group=\"Mists of Pandaria\";indicator=\"bl\";g=0.77254901960784;alpha=1;b=1;duration=true;priority=0;icon=true;iconTexture=\"Interface\\\\Icons\\\\Spell_Shaman_StaticShock\";}",
			["118038"] = "{b=0;group=\"Warrior\";indicator=\"c\";g=0;duration=true;r=0;priority=10;icon=true;iconTexture=\"Interface\\\\Icons\\\\Ability_Warrior_Challange\";}",
			["118135"] = "{r=0;group=\"Mists of Pandaria\";indicator=\"c\";g=0;duration=false;b=0;priority=0;icon=true;iconTexture=\"Interface\\\\Icons\\\\INV_Ammo_Arrow_01\";}",
			["118191"] = "{alpha=1;b=0.14901960784314;priority=0;r=0.56862745098039;group=\"Mists of Pandaria\";indicator=\"bl\";g=0.20392156862745;iconTexture=\"Interface\\\\Icons\\\\sha_ability_rogue_envelopingshadows\";}",
			["119032"] = "{r=0;group=\"Priest\";indicator=\"c\";g=0;duration=true;b=0;priority=0;icon=true;iconTexture=\"Interface\\\\Icons\\\\spell_priest_spectralguise\";}",
			["119611"] = "{r=0.26274509803922;group=\"Monk\";indicator=\"tl\";g=0.76078431372549;player=true;duration=true;alpha=1;b=0.53725490196078;priority=0;icon=false;iconTexture=\"Interface\\\\Icons\\\\ability_monk_renewingmists\";}",
			["121164"] = "{alpha=1;b=1;priority=0;r=0;group=\"PvP Flags\";indicator=\"bl\";g=0.003921568627451;iconTexture=\"Interface\\\\Icons\\\\INV_BannerPVP_03\";}",
			["121175"] = "{r=1;group=\"PvP Flags\";indicator=\"bl\";g=0.24705882352941;b=0.90196078431373;alpha=1;priority=0;icon=false;iconTexture=\"Interface\\\\Icons\\\\INV_BannerPVP_03\";}",
			["121176"] = "{alpha=1;b=0;priority=0;r=0.062745098039216;group=\"PvP Flags\";indicator=\"bl\";g=1;iconTexture=\"Interface\\\\Icons\\\\INV_BannerPVP_03\";}",
			["121177"] = "{r=0.78039215686275;group=\"PvP Flags\";indicator=\"bl\";g=0.42352941176471;alpha=1;b=0;priority=0;icon=false;iconTexture=\"Interface\\\\Icons\\\\INV_BannerPVP_03\";}",
			["121881"] = "{r=0;group=\"Mists of Pandaria\";indicator=\"c\";g=0;duration=true;b=0;alpha=1;priority=0;icon=true;iconTexture=\"Interface\\\\Icons\\\\inv_misc_uncutgemnormal\";}",
			["121885"] = "{icon=true;b=0;priority=0;r=0;group=\"Mists of Pandaria\";indicator=\"c\";g=0;iconTexture=\"Interface\\\\Icons\\\\inv_misc_uncutgemnormal\";}",
			["121949"] = "{r=1;group=\"Mists of Pandaria\";indicator=\"bl\";g=0.80392156862745;duration=true;alpha=1;b=0.2156862745098;priority=0;icon=false;iconTexture=\"Interface\\\\Icons\\\\spell_yorsahj_bloodboil_yellow\";}",
			["122055"] = "{r=0.2078431372549;group=\"Mists of Pandaria\";indicator=\"bl\";g=0.33725490196078;alpha=1;missing=false;duration=true;priority=100;b=1;iconTexture=\"Interface\\\\Icons\\\\Spell_Arcane_ArcanePotency\";}",
			["122151"] = "{icon=true;b=0;priority=0;r=0;group=\"Mists of Pandaria\";indicator=\"c\";g=0;iconTexture=\"Interface\\\\ICONS\\\\trade_archaeology_troll_voodoodoll\";}",
			["122752"] = "{r=0;group=\"Tank Debuffs Mists of Pandaria\";indicator=\"bl\";g=0;player=false;b=0;missing=false;duration=true;priority=100;icon=true;iconTexture=\"Interface\\\\Icons\\\\Ability_Warlock_ShadowFlame\";}",
			["123017"] = "{r=0;group=\"Mists of Pandaria\";indicator=\"c\";g=0;b=0;duration=true;priority=0;icon=true;iconTexture=\"Interface\\\\Icons\\\\Ability_Hunter_MarkedForDeath\";}",
			["123081"] = "{r=0;group=\"Mists of Pandaria\";indicator=\"c\";g=0;duration=false;b=0;priority=0;icon=true;iconTexture=\"Interface\\\\Icons\\\\spell_nature_sicklypolymorph\";}",
			["123121"] = "{r=0;group=\"Tank Debuffs Mists of Pandaria\";indicator=\"bl\";g=0;duration=true;b=0;priority=100;icon=true;iconTexture=\"Interface\\\\Icons\\\\Spell_Frost_SummonWaterElemental\";}",
			["123180"] = "{r=0.8078431372549;group=\"Mists of Pandaria\";indicator=\"bl\";g=0.24705882352941;selfColor={alpha=1;b=0.80392156862745;g=0.2;r=0.83529411764706;};alpha=1;duration=true;priority=0;b=0.83529411764706;iconTexture=\"Interface\\\\Icons\\\\Spell_Frost_WindWalkOn\";}",
			["123184"] = "{icon=true;b=0;priority=0;r=0;group=\"Mists of Pandaria\";indicator=\"c\";g=0;iconTexture=\"Interface\\\\Icons\\\\Spell_Holy_Persecution\";}",
			["123474"] = "{r=0;group=\"Tank Debuffs Mists of Pandaria\";indicator=\"bl\";g=0;duration=true;b=0;priority=100;icon=true;iconTexture=\"Interface\\\\Icons\\\\Ability_Warrior_UnrelentingAssault\";}",
			["123707"] = "{r=0.003921568627451;group=\"Tank Debuffs Mists of Pandaria\";indicator=\"bl\";g=0.003921568627451;alpha=1;duration=true;b=0.003921568627451;priority=100;icon=true;iconTexture=\"Interface\\\\Icons\\\\inv_gizmo_hardenedadamantitetube\";}",
			["123788"] = "{r=0.15686274509804;group=\"Mists of Pandaria\";indicator=\"bl\";g=0.41960784313725;alpha=1;duration=true;priority=0;b=0.79607843137255;iconTexture=\"Interface\\\\Icons\\\\Spell_Shadow_ConeOfSilence\";}",
			["124081"] = "{r=0.51372549019608;group=\"Monk\";indicator=\"br\";g=1;player=true;duration=true;b=0.90588235294118;alpha=1;priority=100;icon=false;iconTexture=\"Interface\\\\Icons\\\\ability_monk_forcesphere\";}",
			["130395"] = "{r=0.87843137254902;group=\"Mists of Pandaria\";indicator=\"bl\";g=0.65490196078431;alpha=1;duration=true;b=0.23529411764706;priority=0;icon=false;iconTexture=\"Interface\\\\Icons\\\\inv_belt_44b\";}",
			["132120"] = "{b=0.25098039215686;group=\"Monk\";indicator=\"tr\";g=1;player=true;duration=true;r=0.83137254901961;priority=100;alpha=1;iconTexture=\"Interface\\\\Icons\\\\spell_monk_envelopingmist\";}",
			["132422"] = "{b=0;group=\"Mists of Pandaria\";indicator=\"c\";g=0;duration=true;r=0;priority=100;icon=true;iconTexture=\"Interface\\\\Icons\\\\Ability_Warrior_Revenge\";}",
			["133767"] = "{r=0;group=\"Tank Debuffs Mists of Pandaria\";indicator=\"bl\";g=0;duration=true;b=0;priority=100;icon=true;iconTexture=\"Interface\\\\Icons\\\\Ability_Druid_InfectedWound\";}",
			["133798"] = "{r=0;group=\"Mists of Pandaria\";indicator=\"c\";g=0;duration=true;b=0;priority=0;icon=true;iconTexture=\"Interface\\\\Icons\\\\Spell_Shadow_LifeDrain02\";}",
			["134366"] = "{r=0;group=\"Tank Debuffs Mists of Pandaria\";indicator=\"bl\";g=0;duration=true;b=0;priority=100;icon=true;iconTexture=\"Interface\\\\Icons\\\\Ability_Rogue_Dismantle\";}",
			["134647"] = "{r=0.66274509803922;group=\"Mists of Pandaria\";indicator=\"bl\";g=0.29411764705882;duration=true;alpha=1;priority=0;b=0.15686274509804;iconTexture=\"Interface\\\\Icons\\\\Spell_Fire_Volcano\";}",
			["134668"] = "{r=0;group=\"Mists of Pandaria\";indicator=\"bl\";g=0;duration=true;b=0;priority=0;icon=true;iconTexture=\"Interface\\\\Icons\\\\Ability_Creature_Disease_02\";}",
			["134691"] = "{r=0;group=\"Tank Debuffs Mists of Pandaria\";indicator=\"bl\";g=0;duration=true;b=0;priority=100;icon=true;iconTexture=\"Interface\\\\Icons\\\\Ability_Warrior_FocusedRage\";}",
			["134916"] = "{r=0;group=\"Tank Debuffs Mists of Pandaria\";indicator=\"bl\";g=0;duration=true;b=0;priority=0;icon=true;iconTexture=\"Interface\\\\Icons\\\\ability_thunderking_decapitate\";}",
			["135695"] = "{r=0;group=\"Mists of Pandaria\";indicator=\"c\";g=0;duration=true;b=0;priority=0;icon=true;iconTexture=\"Interface\\\\Icons\\\\Spell_Shaman_StaticShock\";}",
			["136050"] = "{r=0;group=\"Tank Debuffs Mists of Pandaria\";indicator=\"bl\";g=0;player=false;duration=true;b=0;priority=100;icon=true;iconTexture=\"Interface\\\\Icons\\\\ability_deathwing_bloodcorruption_earth\";}",
			["136192"] = "{r=0;group=\"Mists of Pandaria\";indicator=\"c\";g=0;b=0;duration=true;priority=0;icon=true;iconTexture=\"Interface\\\\Icons\\\\INV_Rod_EnchantedAdamantite\";}",
			["136478"] = "{r=0;group=\"Tank Debuffs Mists of Pandaria\";indicator=\"bl\";g=0;duration=true;b=0;priority=100;icon=true;iconTexture=\"Interface\\\\Icons\\\\Spell_Nature_ThunderClap\";}",
			["136767"] = "{r=0;group=\"Tank Debuffs Mists of Pandaria\";indicator=\"bl\";g=0;player=false;duration=true;b=0;priority=100;icon=true;iconTexture=\"Interface\\\\Icons\\\\Ability_Warrior_ShieldBreak\";}",
			["136903"] = "{r=0;group=\"Tank Debuffs Mists of Pandaria\";indicator=\"bl\";g=0;player=false;b=0;duration=true;priority=100;icon=true;iconTexture=\"Interface\\\\Icons\\\\inv_axe_1h_pvpcataclysms3_c_01\";}",
			["136910"] = "{r=0;group=\"Tank Debuffs Mists of Pandaria\";indicator=\"c\";g=0;b=0;duration=true;priority=0;icon=true;iconTexture=\"Interface\\\\Icons\\\\Ability_Mage_DeepFreeze\";}",
			["136922"] = "{r=0;group=\"Mists of Pandaria\";indicator=\"c\";g=0;duration=false;b=0;priority=100;icon=true;iconTexture=\"Interface\\\\Icons\\\\spell_mage_frostbomb\";}",
			["136992"] = "{r=0;group=\"Mists of Pandaria\";indicator=\"c\";g=0;duration=true;b=0;priority=0;icon=true;iconTexture=\"Interface\\\\Icons\\\\ability_deathknight_remorselesswinters2\";}",
			["137360"] = "{r=0;group=\"Tank Debuffs Mists of Pandaria\";indicator=\"bl\";g=0;duration=true;b=0;priority=0;icon=true;iconTexture=\"Interface\\\\Icons\\\\Spell_DeathKnight_BloodPlague\";}",
			["137408"] = "{r=0;group=\"Tank Debuffs Mists of Pandaria\";indicator=\"bl\";g=0;duration=true;b=0;priority=100;icon=true;iconTexture=\"Interface\\\\Icons\\\\inv_offhand_1h_panstart_a_02\";}",
			["137422"] = "{r=0;group=\"Mists of Pandaria\";indicator=\"c\";g=0;duration=false;b=0;priority=0;icon=true;iconTexture=\"Interface\\\\Icons\\\\ability_vehicle_electrocharge\";}",
			["137633"] = "{icon=true;b=0;priority=0;r=0;group=\"Mists of Pandaria\";indicator=\"bl\";g=0;iconTexture=\"Interface\\\\Icons\\\\INV_DataCrystal01\";}",
			["138002"] = "{r=0.14117647058824;group=\"Mists of Pandaria\";indicator=\"bl\";g=0.47843137254902;selfColor={alpha=1;b=0;g=0;r=0;};duration=false;alpha=1;b=0.67843137254902;priority=0;icon=false;iconTexture=\"Interface\\\\ICONS\\\\inv_misc_volatilewater\";}",
			["138349"] = "{r=0;group=\"Tank Debuffs Mists of Pandaria\";indicator=\"bl\";g=0;duration=true;b=0;priority=100;icon=true;iconTexture=\"Interface\\\\Icons\\\\Spell_Nature_Purge\";}",
			["138569"] = "{r=0;group=\"Tank Debuffs Mists of Pandaria\";indicator=\"bl\";g=0;duration=true;b=0;priority=100;icon=true;iconTexture=\"Interface\\\\Icons\\\\Ability_Warrior_BloodNova\";}",
			["140208"] = "{r=0;group=\"Tank Debuffs Mists of Pandaria\";indicator=\"bl\";g=0;duration=true;b=0;priority=100;icon=true;iconTexture=\"Interface\\\\Icons\\\\Spell_Nature_Cyclone\";}",
			["140546"] = "{r=0.24705882352941;group=\"Mists of Pandaria\";indicator=\"bl\";g=0.57254901960784;alpha=1;duration=true;b=0.78823529411765;missing=false;priority=0;icon=false;iconTexture=\"Interface\\\\Icons\\\\achievement_boss_primordius\";}",
			["140701"] = "{r=0;group=\"Mists of Pandaria\";indicator=\"bl\";g=0;duration=true;b=0;priority=100;icon=true;iconTexture=\"Interface\\\\Icons\\\\inv_datacrystal08\";}",
			["140946"] = "{r=1;group=\"Mists of Pandaria\";indicator=\"bl\";g=0.29803921568627;b=0.45098039215686;alpha=1;priority=0;icon=false;iconTexture=\"Interface\\\\ICONS\\\\inv_misc_eye_04\";}",
			["142532"] = "{r=0;group=\"Siege of Orgrimmar\";indicator=\"bl\";g=0.3843137254902;b=1;duration=true;alpha=1;priority=100;icon=true;iconTexture=\"Interface\\\\Icons\\\\ability_xaril_masterpoisoner_blue\";}",
			["142533"] = "{r=1;group=\"Siege of Orgrimmar\";indicator=\"bl\";g=0;duration=true;b=0.058823529411765;alpha=1;priority=90;icon=true;iconTexture=\"Interface\\\\Icons\\\\ability_xaril_masterpoisoner_red\";}",
			["142534"] = "{r=1;group=\"Siege of Orgrimmar\";indicator=\"bl\";g=0.9921568627451;b=0;duration=true;alpha=1;priority=79;icon=true;iconTexture=\"Interface\\\\Icons\\\\ability_xaril_masterpoisoner_yellow\";}",
			["142671"] = "{r=0;group=\"Siege of Orgrimmar\";indicator=\"c\";g=0;duration=true;b=0;priority=0;icon=true;iconTexture=\"Interface\\\\Icons\\\\ability_kaztik_dominatemind\";}",
			["142863"] = "{icon=true;b=0;priority=0;r=0;group=\"Siege of Orgrimmar\";indicator=\"bl\";g=0;iconTexture=\"Interface\\\\Icons\\\\ability_malkorok_blightofyshaarj_red\";}",
			["142864"] = "{icon=true;b=0;priority=0;r=0;group=\"Siege of Orgrimmar\";indicator=\"bl\";g=0;iconTexture=\"Interface\\\\Icons\\\\ability_malkorok_blightofyshaarj_yellow\";}",
			["142865"] = "{icon=true;b=0;priority=0;r=0;group=\"Siege of Orgrimmar\";indicator=\"bl\";g=0;iconTexture=\"Interface\\\\Icons\\\\ability_malkorok_blightofyshaarj_green\";}",
			["142990"] = "{r=0;group=\"Tank Debuff Siege of Orgrimmar\";indicator=\"br\";g=0;duration=true;b=0;priority=100;icon=true;iconTexture=\"Interface\\\\Icons\\\\warrior_wild_strike\";}",
			["143385"] = "{r=0;group=\"Tank Debuff Siege of Orgrimmar\";indicator=\"bl\";g=0;duration=true;b=0;priority=100;icon=true;iconTexture=\"Interface\\\\Icons\\\\spell_shaman_staticshock\";}",
			["143436"] = "{r=0;group=\"Tank Debuff Siege of Orgrimmar\";indicator=\"bl\";g=0;duration=true;b=0;priority=100;icon=true;iconTexture=\"Interface\\\\Icons\\\\Ability_Warlock_ShadowFlame\";}",
			["143480"] = "{r=0;group=\"Siege of Orgrimmar\";indicator=\"c\";g=0;duration=true;b=0;priority=80;icon=true;iconTexture=\"Interface\\\\Icons\\\\ability_fixated_state_purple\";}",
			["143494"] = "{r=0;group=\"Tank Debuff Siege of Orgrimmar\";indicator=\"bl\";g=0;duration=true;b=0;priority=100;icon=true;iconTexture=\"Interface\\\\Icons\\\\Ability_Warrior_Sunder\";}",
			["143572"] = "{r=0;group=\"Siege of Orgrimmar\";indicator=\"bl\";g=0;duration=true;b=0;priority=0;icon=true;iconTexture=\"Interface\\\\Icons\\\\Spell_Fire_BurningSpeed\";}",
			["143766"] = "{r=0;group=\"Tank Debuff Siege of Orgrimmar\";indicator=\"bl\";g=0;duration=true;b=0;priority=100;icon=true;iconTexture=\"Interface\\\\Icons\\\\Spell_Shadow_PainAndSuffering\";}",
			["143773"] = "{r=0;group=\"Tank Debuff Siege of Orgrimmar\";indicator=\"bl\";g=0;duration=true;b=0;priority=100;icon=true;iconTexture=\"Interface\\\\Icons\\\\Spell_Frost_FrostBlast\";}",
			["143777"] = "{r=0;group=\"Siege of Orgrimmar\";indicator=\"c\";g=0;duration=true;b=0;priority=0;icon=true;iconTexture=\"Interface\\\\Icons\\\\Ability_Mage_ColdAsIce\";}",
			["143780"] = "{r=0;group=\"Tank Debuff Siege of Orgrimmar\";indicator=\"bl\";g=0;duration=true;b=0;priority=100;icon=true;iconTexture=\"Interface\\\\Icons\\\\Ability_Creature_Poison_05\";}",
			["143840"] = "{r=0;group=\"Siege of Orgrimmar\";indicator=\"br\";g=0;duration=true;b=0;priority=0;icon=true;iconTexture=\"Interface\\\\Icons\\\\ability_fixated_state_red\";}",
			["143882"] = "{icon=true;b=0;priority=0;r=0;group=\"Siege of Orgrimmar\";indicator=\"c\";g=0;iconTexture=\"Interface\\\\Icons\\\\ability_fixated_state_red\";}",
			["143979"] = "{r=0;group=\"Tank Debuff Siege of Orgrimmar\";indicator=\"bl\";g=0;duration=true;b=0;priority=100;icon=true;iconTexture=\"Interface\\\\Icons\\\\Spell_Shadow_BloodBoil\";}",
			["143990"] = "{r=0;group=\"Tank Debuff Siege of Orgrimmar\";indicator=\"c\";g=0;duration=true;b=0;priority=0;icon=true;iconTexture=\"Interface\\\\Icons\\\\ability_creature_poison_02\";}",
			["144089"] = "{r=0.49411764705882;group=\"Siege of Orgrimmar\";indicator=\"br\";g=0.10980392156863;duration=true;alpha=1;b=0.87450980392157;priority=0;icon=false;iconTexture=\"Interface\\\\Icons\\\\spell_warlock_demonicportal_purple\";}",
			["144176"] = "{r=0;group=\"Tank Debuff Siege of Orgrimmar\";indicator=\"bl\";g=0;duration=true;b=0;priority=100;icon=true;iconTexture=\"Interface\\\\Icons\\\\sha_inv_misc_slime_01\";}",
			["144215"] = "{r=0;group=\"Tank Debuff Siege of Orgrimmar\";indicator=\"bl\";g=0;duration=true;b=0;priority=100;icon=true;iconTexture=\"Interface\\\\ICONS\\\\spell_shaman_unleashweapon_frost\";}",
			["144330"] = "{r=0.5843137254902;group=\"Siege of Orgrimmar\";indicator=\"bl\";g=0.67843137254902;alpha=1;duration=true;b=0.70980392156863;priority=0;icon=false;iconTexture=\"Interface\\\\Icons\\\\inv_misc_lockboxghostiron\";}",
			["144364"] = "{r=0.7843137254902;group=\"Siege of Orgrimmar\";indicator=\"br\";g=0.75294117647059;duration=true;alpha=1;priority=100;b=0.2078431372549;iconTexture=\"Interface\\\\Icons\\\\Spell_Holy_PowerInfusion\";}",
			["144467"] = "{r=0;group=\"Tank Debuff Siege of Orgrimmar\";indicator=\"bl\";g=0;duration=true;b=0;priority=100;icon=true;iconTexture=\"Interface\\\\Icons\\\\inv_shield_deathwingraid_d_02\";}",
			["144759"] = "{r=0;group=\"Siege of Orgrimmar\";indicator=\"c\";g=0;duration=true;b=0;alpha=1;priority=0;icon=true;iconTexture=\"Interface\\\\Icons\\\\ability_hisek_aim\";}",
			["144849"] = "{r=0;group=\"Siege of Orgrimmar\";indicator=\"c\";g=0;duration=true;b=0;priority=0;icon=true;iconTexture=\"Interface\\\\Icons\\\\ability_titankeeper_testofserenity\";}",
			["144851"] = "{r=0;group=\"Tank Debuff Siege of Orgrimmar\";indicator=\"c\";g=0;duration=true;b=0;priority=0;icon=true;iconTexture=\"Interface\\\\Icons\\\\ability_titankeeper_testofconfidence\";}",
			["145065"] = "{r=0;group=\"Siege of Orgrimmar\";indicator=\"c\";g=0;duration=true;b=0;priority=0;icon=true;iconTexture=\"Interface\\\\Icons\\\\ability_garrosh_touch_of_yshaarj\";}",
			["145175"] = "{r=0;group=\"Siege of Orgrimmar\";indicator=\"c\";g=0;duration=true;b=0;priority=0;icon=true;iconTexture=\"Interface\\\\Icons\\\\ability_garrosh_touch_of_yshaarj\";}",
			["145183"] = "{r=0;group=\"Tank Debuff Siege of Orgrimmar\";indicator=\"bl\";g=0;duration=true;b=0;priority=100;icon=true;iconTexture=\"Interface\\\\Icons\\\\Spell_DeathKnight_Strangulate\";}",
			["145195"] = "{r=0;group=\"Tank Debuff Siege of Orgrimmar\";indicator=\"bl\";g=0;duration=true;b=0;priority=100;icon=true;iconTexture=\"Interface\\\\Icons\\\\ability_deathknight_aoedeathgrip\";}",
			["145215"] = "{r=0;group=\"Siege of Orgrimmar\";indicator=\"c\";g=0;duration=true;b=0;priority=0;icon=true;iconTexture=\"Interface\\\\Icons\\\\sha_spell_shadow_shadesofdarkness\";}",
			["145987"] = "{r=0;group=\"Siege of Orgrimmar\";indicator=\"bl\";g=0;duration=true;b=0;priority=0;icon=true;iconTexture=\"Interface\\\\Icons\\\\INV_Misc_Bomb_07\";}",
			["146124"] = "{r=0;group=\"Tank Debuff Siege of Orgrimmar\";indicator=\"bl\";g=0;duration=true;b=0;priority=100;icon=true;iconTexture=\"Interface\\\\Icons\\\\sha_ability_rogue_bloodyeye\";}",
			["146594"] = "{r=0.21960784313725;group=\"Siege of Orgrimmar\";indicator=\"br\";g=0.50980392156863;duration=true;alpha=1;b=0.67843137254902;priority=50;icon=false;iconTexture=\"Interface\\\\Icons\\\\Achievement_Dungeon_UlduarRaid_Titan_01\";}",
			["146817"] = "{icon=true;b=0;priority=0;r=0;group=\"Siege of Orgrimmar\";indicator=\"c\";g=0;iconTexture=\"Interface\\\\Icons\\\\sha_ability_rogue_envelopingshadows\";}",
			["147029"] = "{r=0;group=\"Tank Debuffs Mists of Pandaria\";indicator=\"bl\";g=0;b=0;duration=true;priority=0;icon=true;iconTexture=\"Interface\\\\Icons\\\\spell_fire_moltenblood\";}",
			["147207"] = "{r=1;group=\"Siege of Orgrimmar\";indicator=\"bl\";g=0.098039215686275;alpha=1;duration=true;b=0;priority=0;icon=false;iconTexture=\"Interface\\\\Icons\\\\ability_titankeeper_phasing\";}",
			["147209"] = "{b=0;priority=0;r=0;group=\"Mists of Pandaria\";indicator=\"\";g=0;iconTexture=\"Interface\\\\Icons\\\\Ability_Warlock_Eradication\";}",
			["148983"] = "{r=0;group=\"Siege of Orgrimmar\";indicator=\"bl\";g=0;duration=true;b=0;priority=0;icon=true;iconTexture=\"Interface\\\\Icons\\\\Spell_Holy_PowerInfusion\";}",
			["148994"] = "{r=0;group=\"Siege of Orgrimmar\";indicator=\"bl\";g=0;duration=true;b=0;priority=0;icon=true;iconTexture=\"Interface\\\\Icons\\\\Spell_Holy_PowerInfusion\";}",
			["149004"] = "{r=0;group=\"Siege of Orgrimmar\";indicator=\"bl\";g=0;duration=true;b=0;alpha=1;priority=0;icon=true;iconTexture=\"Interface\\\\Icons\\\\Spell_Holy_PowerInfusion\";}",
			["152118"] = "{r=1;group=\"Priest\";indicator=\"tl\";g=0.41960784313725;player=true;alpha=1;duration=true;b=0.5843137254902;priority=0;icon=false;iconTexture=\"Interface\\\\Icons\\\\Ability_Priest_ClarityOfWill\";}",
			["155074"] = "{r=0;group=\"Tank Debuff Blackrock Foundry\";indicator=\"bl\";g=0;duration=true;b=0;priority=0;icon=true;iconTexture=\"Interface\\\\Icons\\\\ability_monk_breathoffire\";}",
			["155080"] = "{r=1;group=\"Blackrock Foundry\";indicator=\"bl\";g=0.22745098039216;alpha=1;duration=true;missing=false;b=0;priority=0;icon=false;iconTexture=\"Interface\\\\Icons\\\\Spell_Fire_FlameBlades\";}",
			["155196"] = "{b=0;group=\"Blackrock Foundry\";indicator=\"bl\";g=0;duration=true;r=0;priority=0;icon=true;iconTexture=\"Interface\\\\Icons\\\\ability_fixated_state_red\";}",
			["155236"] = "{b=0;group=\"Tank Debuff Blackrock Foundry\";indicator=\"bl\";g=0;duration=true;r=0;priority=0;icon=true;iconTexture=\"Interface\\\\Icons\\\\Ability_Warrior_ShieldBreak\";}",
			["155330"] = "{b=0;group=\"Blackrock Foundry\";indicator=\"c\";g=0;duration=true;r=0;priority=0;icon=true;iconTexture=\"Interface\\\\Icons\\\\INV_Elemental_Mote_Earth01\";}",
			["155569"] = "{r=0;group=\"Highmaul\";indicator=\"c\";g=0;duration=true;b=0;priority=2;icon=true;iconTexture=\"Interface\\\\Icons\\\\ability_warrior_bloodfrenzy\";}",
			["155777"] = "{r=0.57647058823529;group=\"Druid\";indicator=\"tr\";g=0.28235294117647;player=true;duration=true;b=0.6156862745098;priority=100;alpha=1;iconTexture=\"Interface\\\\Icons\\\\Spell_Nature_Rejuvenation\";}",
			["155835"] = "{b=0;group=\"Druid\";indicator=\"c\";g=0;duration=true;alpha=1;r=0;priority=61;icon=true;iconTexture=\"Interface\\\\Icons\\\\spell_druid_bristlingfur\";}",
			["155921"] = "{b=0;group=\"Tank Debuff Blackrock Foundry\";indicator=\"bl\";g=0;duration=true;r=0;priority=0;icon=true;iconTexture=\"Interface\\\\Icons\\\\INV_SummerFest_FireSpirit\";}",
			["156151"] = "{r=0;group=\"Tank Debuff Highmaul\";indicator=\"bl\";g=0;duration=true;b=0;priority=0;icon=true;iconTexture=\"Interface\\\\Icons\\\\INV_Mace_52\";}",
			["156152"] = "{b=0;group=\"Highmaul\";indicator=\"bl\";g=0;duration=true;r=0;priority=0;icon=true;iconTexture=\"Interface\\\\Icons\\\\ability_butcher_gushingwounds\";}",
			["156203"] = "{r=0;group=\"Blackrock Foundry\";indicator=\"c\";g=0;duration=true;b=0;priority=0;icon=true;iconTexture=\"Interface\\\\Icons\\\\ability_vehicle_oiljets\";}",
			["156310"] = "{r=0;group=\"Blackrock Foundry\";indicator=\"c\";g=0;duration=true;b=0;priority=0;icon=true;iconTexture=\"Interface\\\\Icons\\\\spell_shaman_spewlava\";}",
			["156743"] = "{b=0;group=\"Blackrock Foundry\";indicator=\"c\";g=0;duration=true;r=0;priority=0;icon=true;iconTexture=\"Interface\\\\Icons\\\\Ability_Warrior_BloodBath\";}",
			["156910"] = "{r=0.73333333333333;group=\"Paladin\";indicator=\"tr\";g=0;player=true;alpha=1;priority=50;b=1;iconTexture=\"Interface\\\\Icons\\\\ability_paladin_beaconsoflight\";}",
			["158010"] = "{r=0;group=\"Blackrock Foundry\";indicator=\"c\";g=0;duration=true;b=0;priority=100;icon=true;iconTexture=\"Interface\\\\Icons\\\\ability_ironmaidens_boomerangrush\";}",
			["158241"] = "{b=0;group=\"Highmaul\";indicator=\"c\";g=0;duration=true;r=0;priority=0;icon=true;iconTexture=\"Interface\\\\Icons\\\\Spell_Fire_Fire\";}",
			["158605"] = "{r=0;group=\"Tank Debuff Highmaul\";duration=true;g=0;b=0;indicator=\"bl\";priority=0;icon=true;iconTexture=\"Interface\\\\Icons\\\\Spell_Arcane_MassDispel\";}",
			["159113"] = "{r=0;group=\"Tank Debuff Highmaul\";indicator=\"bl\";g=0;duration=true;b=0;priority=0;icon=true;iconTexture=\"Interface\\\\Icons\\\\Ability_Rogue_HungerforBlood\";}",
			["159220"] = "{r=0;group=\"Tank Debuff Highmaul\";indicator=\"bl\";g=0;duration=true;b=0;priority=0;icon=true;iconTexture=\"Interface\\\\Icons\\\\ability_mage_worldinflamesgreen\";}",
			["159709"] = "{b=0;group=\"Tank Debuff Highmaul\";indicator=\"bl\";g=0;duration=true;r=0;priority=0;icon=true;iconTexture=\"Interface\\\\Icons\\\\ability_whirlwind\";}",
			["162184"] = "{b=0;group=\"Highmaul\";indicator=\"bl\";g=0;duration=true;r=0;priority=0;icon=true;iconTexture=\"Interface\\\\Icons\\\\INV_Elemental_Primal_Shadow\";}",
			["162370"] = "{b=0;group=\"Highmaul\";indicator=\"bl\";g=0;duration=true;r=0;priority=0;icon=true;iconTexture=\"Interface\\\\Icons\\\\Spell_Holiday_ToW_SpiceCloud\";}",
			["163134"] = "{b=0;group=\"Highmaul\";indicator=\"c\";g=0;duration=true;r=0;priority=0;icon=true;iconTexture=\"Interface\\\\Icons\\\\Spell_Fire_FelFireward\";}",
			["163241"] = "{b=0;group=\"Tank Debuff Highmaul\";indicator=\"bl\";g=0;duration=true;r=0;priority=0;icon=true;iconTexture=\"Interface\\\\Icons\\\\Ability_Creature_Disease_02\";}",
			["163322"] = "{r=1;group=\"Highmaul\";indicator=\"bl\";g=0.32156862745098;alpha=1;duration=true;b=0;priority=1;icon=true;iconTexture=\"Interface\\\\Icons\\\\inv_firearm_2h_rifle_pvppandarias1_c_01\";}",
			["163372"] = "{b=0;group=\"Highmaul\";indicator=\"c\";g=0;duration=true;r=0;priority=0;icon=true;iconTexture=\"Interface\\\\Icons\\\\Spell_Arcane_Arcane04\";}",
			["163663"] = "{b=0;group=\"Highmaul\";indicator=\"bl\";g=0;duration=true;r=0;priority=0;icon=true;iconTexture=\"Interface\\\\Icons\\\\inv_firearm_2h_rifle_pvppandarias1_c_01\";}",
			["164176"] = "{r=0;group=\"Tank Debuff Highmaul\";indicator=\"bl\";g=0;duration=true;b=0;priority=0;icon=true;iconTexture=\"Interface\\\\Icons\\\\Spell_Arcane_MassDispel\";}",
			["164178"] = "{r=0;group=\"Tank Debuff Highmaul\";indicator=\"bl\";g=0;duration=true;b=0;priority=0;icon=true;iconTexture=\"Interface\\\\Icons\\\\Spell_Arcane_MassDispel\";}",
			["164191"] = "{r=0;group=\"Tank Debuff Highmaul\";indicator=\"bl\";g=0;duration=true;b=0;priority=0;icon=true;iconTexture=\"Interface\\\\Icons\\\\Spell_Arcane_MassDispel\";}",
			["164380"] = "{r=0;group=\"Blackrock Foundry\";indicator=\"c\";g=0;duration=true;b=0;priority=1;icon=true;iconTexture=\"Interface\\\\Icons\\\\Spell_Fire_Incinerate\";}",
			["165195"] = "{b=0;group=\"Blackrock Foundry\";indicator=\"c\";g=0;duration=true;r=0;priority=0;icon=true;iconTexture=\"Interface\\\\Icons\\\\Ability_Vehicle_ElectroCharge\";}",
			["165298"] = "{b=0;group=\"Blackrock Foundry\";indicator=\"bl\";alpha=1;g=0.96078431372549;r=1;priority=40;icon=false;iconTexture=\"Interface\\\\Icons\\\\INV_Elemental_Primal_Fire\";}",
			["170405"] = "{r=0;group=\"Blackrock Foundry\";indicator=\"bl\";g=0;duration=true;b=0;priority=0;icon=true;iconTexture=\"Interface\\\\Icons\\\\ability_ironmaidens_maraksbloodcalling\";}",
			["171049"] = "{b=0;group=\"Death Knight\";indicator=\"c\";g=0;duration=true;r=0;priority=0;icon=true;iconTexture=\"Interface\\\\Icons\\\\Spell_DeathKnight_RuneTap\";}",
			["174716"] = "{b=0;group=\"Blackrock Foundry\";indicator=\"c\";g=0;duration=true;r=0;priority=0;icon=true;iconTexture=\"Interface\\\\Icons\\\\inv_misc_enggizmos_35\";}",
			["176121"] = "{b=0;group=\"Blackrock Foundry\";indicator=\"c\";g=0;duration=true;r=0;priority=0;icon=true;iconTexture=\"Interface\\\\Icons\\\\Spell_Fire_LavaSpawn\";}",
			["179219"] = "{b=0;g=0;priority=0;r=0;group=\"Hellfire Citadel\";indicator=\"c\";icon=true;iconTexture=\"Interface\\\\Icons\\\\ability_felarakkoa_feldetonation_red\";}",
			["179219"] = "{r=0;group=\"Hellfire Citadel\";indicator=\"c\";g=0;duration=true;b=0;priority=100;icon=true;iconTexture=\"Interface\\\\Icons\\\\ability_felarakkoa_feldetonation_red\";}",
			["179428"] = "{b=0;group=\"Hellfire Citadel\";indicator=\"c\";g=0;duration=true;r=0;priority=0;icon=true;iconTexture=\"Interface\\\\Icons\\\\ability_bossfellord_felfissure\";}",
			["179864"] = "{b=0;g=0;priority=0;r=0;group=\"Hellfire Citadel\";indicator=\"c\";icon=true;iconTexture=\"Interface\\\\Icons\\\\Spell_Arcane_PrismaticCloak\";}",
			["179864"] = "{b=0;group=\"Hellfire Citadel\";indicator=\"c\";g=0;duration=true;r=0;priority=0;icon=true;iconTexture=\"Interface\\\\Icons\\\\Spell_Arcane_PrismaticCloak\";}",
			["179867"] = "{b=0;group=\"Hellfire Citadel\";indicator=\"bl\";g=0;duration=true;r=0;priority=0;icon=true;iconTexture=\"Interface\\\\Icons\\\\ability_bossgorefiend_gorefiendscorruption\";}",
			["179909"] = "{b=0;group=\"Hellfire Citadel\";indicator=\"c\";g=0;duration=true;r=0;priority=0;icon=true;iconTexture=\"Interface\\\\Icons\\\\ability_warlock_soullink\";}",
			["179978"] = "{b=0;g=0;priority=0;r=0;group=\"Hellfire Citadel\";indicator=\"c\";icon=true;iconTexture=\"Interface\\\\Icons\\\\ability_bossgorefiend_touchofdoom\";}",
			["179995"] = "{b=0;group=\"Hellfire Citadel\";indicator=\"c\";g=0;duration=true;r=0;priority=0;icon=true;iconTexture=\"Interface\\\\ICONS\\\\ability_warlock_soulsiphon\";}",
			["180000"] = "{b=0;group=\"Tank Debuff Hellfire Citadel\";indicator=\"bl\";g=0;duration=true;r=0;priority=0;icon=true;iconTexture=\"Interface\\\\Icons\\\\Spell_Holy_SealOfRighteousness\";}",
			["180079"] = "{b=0;g=0;priority=0;r=0;group=\"Hellfire Citadel\";indicator=\"c\";icon=true;iconTexture=\"Interface\\\\Icons\\\\inv_blacksmithdye_black\";}",
			["180166"] = "{b=0;g=0;priority=0;r=0;group=\"Hellfire Citadel\";indicator=\"tr\";icon=true;iconTexture=\"Interface\\\\Icons\\\\Spell_Shadow_ChillTouch\";}",
			["180199"] = "{r=0;group=\"Tank Debuff Hellfire Citadel\";indicator=\"bl\";g=0;duration=true;b=0;priority=0;icon=true;iconTexture=\"Interface\\\\Icons\\\\Ability_Warrior_Riposte\";}",
			["180270"] = "{b=0;group=\"Hellfire Citadel\";duration=true;g=0;indicator=\"c\";r=0;priority=0;icon=true;iconTexture=\"Interface\\\\Icons\\\\spell_yorsahj_bloodboil_purpleoil\";}",
			["180415"] = "{b=0;group=\"Hellfire Citadel\";indicator=\"c\";g=0;duration=true;r=0;priority=0;icon=true;iconTexture=\"Interface\\\\Icons\\\\inv_gizmo_felstabilizer\";}",
			["181099"] = "{b=0;g=0;priority=0;r=0;group=\"Hellfire Citadel\";indicator=\"c\";icon=true;iconTexture=\"Interface\\\\Icons\\\\Spell_Shadow_AuraOfDarkness\";}",
			["181275"] = "{icon=true;b=0;priority=0;r=0;group=\"Hellfire Citadel\";indicator=\"c\";g=0;iconTexture=\"Interface\\\\Icons\\\\spell_warlock_summonterrorguard\";}",
			["181295"] = "{b=0;group=\"Hellfire Citadel\";indicator=\"c\";g=0;duration=true;r=0;priority=0;icon=true;iconTexture=\"Interface\\\\Icons\\\\Spell_Shadow_DeathCoil\";}",
			["181305"] = "{r=0;group=\"Hellfire Citadel\";indicator=\"c\";g=0;duration=true;b=0;priority=0;icon=true;iconTexture=\"Interface\\\\ICONS\\\\inv_offhand_stratholme_a_02\";}",
			["181306"] = "{b=0;group=\"Hellfire Citadel\";indicator=\"c\";g=0;duration=true;r=0;priority=0;icon=true;iconTexture=\"Interface\\\\Icons\\\\Ability_Mage_LivingBomb\";}",
			["181307"] = "{b=0;group=\"Hellfire Citadel\";indicator=\"c\";g=0;duration=true;r=0;priority=0;icon=true;iconTexture=\"Interface\\\\Icons\\\\Spell_Shadow_Requiem\";}",
			["181321"] = "{r=0;group=\"Hellfire Citadel\";indicator=\"c\";g=0;duration=true;b=0;priority=0;icon=true;iconTexture=\"Interface\\\\Icons\\\\Spell_Shadow_ChillTouch\";}",
			["181508"] = "{b=0;group=\"Hellfire Citadel\";indicator=\"c\";g=0;duration=true;r=0;priority=0;icon=true;iconTexture=\"Interface\\\\Icons\\\\Spell_Shadow_SeedOfDestruction\";}",
			["181515"] = "{b=0;g=0;priority=1;r=0;group=\"Hellfire Citadel\";indicator=\"c\";icon=true;iconTexture=\"Interface\\\\Icons\\\\Spell_Shadow_SeedOfDestruction\";}",
			["181528"] = "{b=0;group=\"Hellfire Citadel\";indicator=\"bl\";g=0;duration=true;r=0;priority=0;icon=true;iconTexture=\"Interface\\\\Icons\\\\Ability_Rogue_FeignDeath\";}",
			["181597"] = "{b=0;g=0;priority=0;r=0;group=\"Hellfire Citadel\";indicator=\"c\";icon=true;iconTexture=\"Interface\\\\Icons\\\\ability_bossmannoroth_mannorothsgaze\";}",
			["181753"] = "{b=0;group=\"Hellfire Citadel\";indicator=\"c\";g=0;duration=true;r=0;priority=0;icon=true;iconTexture=\"Interface\\\\Icons\\\\ability_felarakkoa_feldetonation_green\";}",
			["181957"] = "{b=0;g=0;priority=2;r=0;group=\"Hellfire Citadel\";indicator=\"c\";icon=true;iconTexture=\"Interface\\\\Icons\\\\Spell_Frost_ArcticWinds\";}",
			["182001"] = "{r=0;group=\"Hellfire Citadel\";indicator=\"bl\";g=0;duration=true;b=0;priority=0;icon=true;iconTexture=\"Interface\\\\Icons\\\\Spell_Fire_FelFlameRing\";}",
			["182038"] = "{r=0;group=\"Tank Debuff Hellfire Citadel\";indicator=\"bl\";g=0;duration=true;b=0;priority=0;icon=true;iconTexture=\"Interface\\\\Icons\\\\archaeology_5_0_crackedmogurunestone\";}",
			["182074"] = "{b=0;group=\"Hellfire Citadel\";indicator=\"bl\";g=0;duration=true;r=0;priority=0;icon=true;iconTexture=\"Interface\\\\Icons\\\\Spell_Fire_FelImmolation\";}",
			["182108"] = "{b=0;g=0;priority=0;r=0;group=\"Tank Debuff Hellfire Citadel\";indicator=\"bl\";icon=true;iconTexture=\"Interface\\\\Icons\\\\spell_fire_ragnaros_lavaboltgreen\";}",
			["182178"] = "{r=0;group=\"Hellfire Citadel\";indicator=\"c\";g=0;duration=true;b=0;priority=100;icon=true;iconTexture=\"Interface\\\\Icons\\\\ability_arakkoa_spinning_blade\";}",
			["182200"] = "{b=0;g=0;priority=0;r=0;group=\"Hellfire Citadel\";indicator=\"c\";icon=true;iconTexture=\"Interface\\\\Icons\\\\ability_arakkoa_spinning_blade\";}",
			["182280"] = "{b=0;group=\"Hellfire Citadel\";indicator=\"c\";g=0;duration=true;r=0;priority=0;icon=true;iconTexture=\"Interface\\\\Icons\\\\Ability_Hunter_MarkedForDeath\";}",
			["182325"] = "{b=0;group=\"Hellfire Citadel\";indicator=\"c\";g=0;duration=true;r=0;priority=0;icon=true;iconTexture=\"Interface\\\\Icons\\\\Spell_Shadow_DevouringPlague\";}",
			["182600"] = "{r=0;group=\"Hellfire Citadel\";indicator=\"c\";g=0;duration=true;b=0;priority=100;icon=true;iconTexture=\"Interface\\\\Icons\\\\Spell_Fire_FelFire\";}",
			["182769"] = "{b=0;group=\"Hellfire Citadel\";indicator=\"c\";g=0;duration=true;r=0;priority=0;icon=true;iconTexture=\"Interface\\\\Icons\\\\ability_fixated_state_purple\";}",
			["182826"] = "{b=0;g=0;priority=0;r=0;group=\"Hellfire Citadel\";indicator=\"c\";icon=true;iconTexture=\"Interface\\\\Icons\\\\Spell_Fire_FelFlameRing\";}",
			["183586"] = "{b=0;group=\"Hellfire Citadel\";indicator=\"bl\";g=0;duration=true;r=0;priority=0;icon=true;iconTexture=\"Interface\\\\Icons\\\\Spell_Fire_FelFlameRing\";}",
			["183817"] = "{b=0;group=\"Hellfire Citadel\";indicator=\"c\";g=0;duration=true;r=0;priority=0;icon=true;iconTexture=\"Interface\\\\Icons\\\\Ability_Warlock_EverlastingAffliction\";}",
			["183828"] = "{b=0;group=\"Hellfire Citadel\";indicator=\"bl\";g=0;duration=true;r=0;priority=0;icon=true;iconTexture=\"Interface\\\\Icons\\\\warlock_summon_doomguard\";}",
			["183865"] = "{b=0;group=\"Hellfire Citadel\";indicator=\"c\";g=0;duration=true;r=0;priority=0;icon=true;iconTexture=\"Interface\\\\Icons\\\\ability_warlock_shadowfurytga\";}",
			["183963"] = "{r=0;group=\"Hellfire Citadel\";indicator=\"bl\";g=0;duration=true;b=0;priority=0;icon=true;iconTexture=\"Interface\\\\Icons\\\\Spell_Holy_SurgeOfLight\";}",
			["184124"] = "{b=0;group=\"Hellfire Citadel\";indicator=\"c\";g=0;duration=true;r=0;priority=0;icon=true;iconTexture=\"Interface\\\\Icons\\\\Spell_Shadow_AntiMagicShell\";}",
			["184243"] = "{b=0;group=\"Tank Debuff Hellfire Citadel\";indicator=\"bl\";g=0;duration=true;r=0;priority=0;icon=true;iconTexture=\"Interface\\\\Icons\\\\inv_misc_volatileearth\";}",
			["184449"] = "{b=0;g=0;priority=0;r=0;group=\"Hellfire Citadel\";indicator=\"c\";icon=true;iconTexture=\"Interface\\\\Icons\\\\ability_bossfelorcs_necromancer_purple\";}",
			["184450"] = "{b=0;g=0;priority=0;r=0;group=\"Hellfire Citadel\";indicator=\"c\";icon=true;iconTexture=\"Interface\\\\Icons\\\\ability_bossfelorcs_necromancer_purple\";}",
			["184678"] = "{r=0;group=\"Tank Debuff Hellfire Citadel\";indicator=\"bl\";g=0;duration=true;b=0;priority=0;icon=true;iconTexture=\"Interface\\\\Icons\\\\Spell_Shadow_SummonVoidWalker\";}",
			["184847"] = "{icon=true;b=0;priority=0;r=0;group=\"Tank Debuff Hellfire Citadel\";indicator=\"bl\";g=0;iconTexture=\"Interface\\\\Icons\\\\Ability_Gouge\";}",
			["185065"] = "{b=0;g=0;priority=0;r=0;group=\"Hellfire Citadel\";indicator=\"c\";icon=true;iconTexture=\"Interface\\\\Icons\\\\ability_bossfelorcs_necromancer_orange\";}",
			["185066"] = "{b=0;g=0;priority=0;r=0;group=\"Hellfire Citadel\";indicator=\"c\";icon=true;iconTexture=\"Interface\\\\Icons\\\\ability_bossfelorcs_necromancer_red\";}",
			["185189"] = "{r=0;group=\"Tank Debuff Hellfire Citadel\";indicator=\"bl\";g=0;duration=true;b=0;priority=0;icon=true;iconTexture=\"Interface\\\\Icons\\\\Spell_Fire_FelImmolation\";}",
			["185239"] = "{b=0;group=\"Hellfire Citadel\";indicator=\"c\";g=0;duration=true;r=0;priority=100;icon=true;iconTexture=\"Interface\\\\Icons\\\\spell_burningbladeshaman_blazing_radiance\";}",
			["185510"] = "{icon=true;b=0;priority=0;r=0;group=\"Hellfire Citadel\";indicator=\"c\";g=0;iconTexture=\"Interface\\\\ICONS\\\\inv_misc_steelweaponchain\";}",
			["185519"] = "{b=0;group=\"Hellfire Citadel\";indicator=\"c\";g=0;duration=true;alpha=1;r=0;priority=0;icon=true;iconTexture=\"Interface\\\\Icons\\\\spell_yorsahj_bloodboil_orangeoil\";}",
			["185563"] = "{b=0;group=\"Hellfire Citadel\";indicator=\"c\";g=0;duration=true;r=0;priority=0;icon=true;iconTexture=\"Interface\\\\Icons\\\\warrior_talent_icon_gladiatorsresolve\";}",
			["185656"] = "{r=0;group=\"Hellfire Citadel\";indicator=\"bl\";g=0;duration=true;b=0;priority=0;icon=true;iconTexture=\"Interface\\\\Icons\\\\sha_spell_shadow_shadesofdarkness\";}",
			["185747"] = "{r=0;group=\"Hellfire Citadel\";indicator=\"c\";g=0;duration=true;b=0;priority=100;icon=true;iconTexture=\"Interface\\\\Icons\\\\ability_siege_engineer_superheated\";}",
			["185821"] = "{b=0;group=\"Tank Debuff Hellfire Citadel\";indicator=\"bl\";g=0;duration=true;r=0;priority=0;icon=true;iconTexture=\"Interface\\\\Icons\\\\ability_bossmannoroth_massiveblast\";}",
			["186063"] = "{r=0;group=\"Hellfire Citadel\";indicator=\"c\";g=0;duration=true;b=0;priority=0;icon=true;iconTexture=\"Interface\\\\Icons\\\\Ability_Creature_Disease_05\";}",
			["186073"] = "{b=0;group=\"Hellfire Citadel\";indicator=\"c\";g=0;duration=true;r=0;priority=0;icon=true;iconTexture=\"Interface\\\\Icons\\\\Spell_Fire_FelImmolation\";}",
			["186134"] = "{b=0;group=\"Hellfire Citadel\";indicator=\"bl\";g=0;duration=true;r=0;priority=0;icon=true;iconTexture=\"Interface\\\\Icons\\\\spell_fel_elementaldevastation\";}",
			["186135"] = "{b=0;group=\"Hellfire Citadel\";indicator=\"bl\";g=0;duration=true;r=0;priority=0;icon=true;iconTexture=\"Interface\\\\Icons\\\\Spell_Shadow_AntiShadow\";}",
			["186333"] = "{icon=true;b=0;priority=0;r=0;group=\"Hellfire Citadel\";indicator=\"c\";g=0;iconTexture=\"Interface\\\\Icons\\\\Spell_Shadow_DevouringPlague\";}",
			["186407"] = "{r=0;indicator=\"c\";b=0;group=\"Hellfire Citadel\";priority=2;g=0;iconTexture=\"Interface\\\\Icons\\\\spell_fel_incinerate\";}",
			["186500"] = "{b=0;group=\"Hellfire Citadel\";indicator=\"c\";g=0;duration=true;r=0;priority=1;icon=true;iconTexture=\"Interface\\\\ICONS\\\\inv_misc_steelweaponchain\";}",
			["186684"] = "{b=0;group=\"Tank Debuff Hellfire Citadel\";indicator=\"bl\";g=0;duration=true;r=0;priority=0;icon=true;iconTexture=\"Interface\\\\Icons\\\\ability_deathwing_sealarmorbreachgreen\";}",
			["186952"] = "{b=0;group=\"Hellfire Citadel\";indicator=\"c\";g=0;duration=true;r=0;priority=0;icon=true;iconTexture=\"Interface\\\\Icons\\\\spell_warlock_demonicportal_purple\";}",
			["186961"] = "{b=0;group=\"Hellfire Citadel\";indicator=\"c\";g=0;duration=true;r=0;priority=0;icon=true;iconTexture=\"Interface\\\\Icons\\\\ability_warlock_moltencoregreen\";}",
			["187122"] = "{r=0;group=\"Hellfire Citadel\";indicator=\"c\";g=0;duration=true;b=0;priority=0;icon=true;iconTexture=\"Interface\\\\Icons\\\\INV_Elemental_Primal_Life\";}",
			["188208"] = "{r=0;group=\"Hellfire Citadel\";indicator=\"c\";g=0;duration=true;b=0;priority=0;icon=true;iconTexture=\"Interface\\\\Icons\\\\inv_ember_fel\";}",
			["188448"] = "{b=0;g=0;priority=0;r=0;group=\"Hellfire Citadel\";indicator=\"c\";icon=true;iconTexture=\"Interface\\\\Icons\\\\Spell_Fire_FelImmolation\";}",
			["188666"] = "{b=0;group=\"Hellfire Citadel\";indicator=\"c\";g=0;duration=true;r=0;priority=0;icon=true;iconTexture=\"Interface\\\\ICONS\\\\ability_warlock_soulsiphon\";}",
			["188852"] = "{b=0;group=\"Hellfire Citadel\";indicator=\"c\";g=0;duration=true;r=0;priority=0;icon=true;iconTexture=\"Interface\\\\Icons\\\\ability_ironmaidens_corruptedblood\";}",
			["188929"] = "{b=0;group=\"Hellfire Citadel\";indicator=\"c\";g=0;duration=true;r=0;priority=0;icon=true;iconTexture=\"Interface\\\\Icons\\\\Ability_Hunter_MarkedForDeath\";}",
			["189030"] = "{b=0;g=0;priority=0;r=0;group=\"Hellfire Citadel\";indicator=\"c\";icon=true;iconTexture=\"Interface\\\\Icons\\\\ability_malkorok_blightofyshaarj_red\";}",
			["189031"] = "{b=0;g=0;priority=0;r=0;group=\"Hellfire Citadel\";indicator=\"c\";icon=true;iconTexture=\"Interface\\\\Icons\\\\ability_malkorok_blightofyshaarj_yellow\";}",
			["189032"] = "{b=0;g=0;priority=0;r=0;group=\"Hellfire Citadel\";indicator=\"c\";icon=true;iconTexture=\"Interface\\\\Icons\\\\ability_malkorok_blightofyshaarj_green\";}",
			["189260"] = "{b=0;g=0;priority=0;r=0;group=\"Tank Debuff Hellfire Citadel\";indicator=\"bl\";icon=true;iconTexture=\"Interface\\\\Icons\\\\Spell_Shadow_PainAndSuffering\";}",
			["189538"] = "{b=0;group=\"Hellfire Citadel\";duration=true;g=0;indicator=\"c\";r=0;priority=0;icon=true;iconTexture=\"Interface\\\\Icons\\\\Ability_Creature_Cursed_02\";}",
			["189540"] = "{r=0;group=\"Hellfire Citadel\";indicator=\"c\";alpha=1;duration=true;g=0;b=0;priority=100;icon=true;iconTexture=\"Interface\\\\Icons\\\\ability_priest_clarityofpower\";}",
			["189627"] = "{b=0;group=\"Hellfire Citadel\";indicator=\"tl\";g=0;duration=true;r=0;priority=0;icon=true;iconTexture=\"Interface\\\\Icons\\\\achievement_zone_cataclysmgreen\";}",
			["189777"] = "{b=0;g=0;priority=0;r=0;group=\"Hellfire Citadel\";indicator=\"c\";icon=true;iconTexture=\"Interface\\\\ICONS\\\\inv_misc_steelweaponchain\";}",
			["189895"] = "{b=0;group=\"Hellfire Citadel\";indicator=\"c\";g=0;duration=true;r=0;priority=0;icon=true;iconTexture=\"Interface\\\\Icons\\\\INV_Enchant_VoidSphere\";}",
			["190341"] = "{b=0;group=\"Hellfire Citadel\";indicator=\"bl\";g=0;duration=true;r=0;priority=0;icon=true;iconTexture=\"Interface\\\\Icons\\\\spell_deathknight_necroticplague\";}",
			["190679"] = "{b=0;group=\"Tank Debuff Hellfire Citadel\";indicator=\"bl\";g=0;duration=true;r=0;priority=0;icon=true;iconTexture=\"Interface\\\\Icons\\\\Spell_Fire_FelImmolation\";}",
			["190684"] = "{icon=true;b=0;priority=0;r=0;group=\"Hellfire Citadel\";indicator=\"c\";g=0;iconTexture=\"Interface\\\\Icons\\\\Ability_Warrior_Bloodsurge\";}",
		}
	}

	for classToken in pairs(RAID_CLASS_COLORS) do
		self.defaults.profile.auraIndicators.disabled[classToken] = {}
	end
end

-- Module APIs
function ShadowUF:RegisterModule(module, key, name, isBar, class, spec, level)
	-- Prevent duplicate registration for deprecated plugin
	if( key == "auraIndicators" and IsAddOnLoaded("ShadowedUF_Indicators") and self.modules.auraIndicators ) then
		self:Print(L["WARNING! ShadowedUF_Indicators has been deprecated as v4 and is now built in. Please delete ShadowedUF_Indicators, your configuration will be saved."])
		return
	end

	self.modules[key] = module

	module.moduleKey = key
	module.moduleHasBar = isBar
	module.moduleName = name
	module.moduleClass = class
	module.moduleLevel = level

	if( type(spec) == "number" ) then
		module.moduleSpec = {}
		module.moduleSpec[spec] = true
	elseif( type(spec) == "table" ) then
		module.moduleSpec = {}
		for _, id in pairs(spec) do
			module.moduleSpec[id] = true
		end
	end
	
	table.insert(self.moduleOrder, module)
end

function ShadowUF:FireModuleEvent(event, frame, unit)
	for _, module in pairs(self.moduleOrder) do
		if( module[event] ) then
			module[event](module, frame, unit)
		end
	end
end

-- Profiles changed
-- I really dislike this solution, but if we don't do it then there is setting issues
-- because when copying a profile, AceDB-3.0 fires OnProfileReset -> OnProfileCopied
-- SUF then sees that on the new reset profile has no profile, tries to load one in
-- ... followed by the profile copying happen and it doesn't copy everything correctly
-- due to variables being reset already.
local resetTimer
function ShadowUF:ProfileReset()
	if( not resetTimer ) then
		resetTimer = CreateFrame("Frame")
		resetTimer:SetScript("OnUpdate", function(self)
			ShadowUF:ProfilesChanged()
			self:Hide()
		end)
	end
	
	resetTimer:Show()
end

function ShadowUF:ProfilesChanged()
	if( self.layoutImporting ) then return end
	if( resetTimer ) then resetTimer:Hide() end
	
	self.db:RegisterDefaults(self.defaults)
	
	-- No active layout, register the default one
	if( not self.db.profile.loadedLayout ) then
		self:LoadDefaultLayout()
	else
		self:CheckUpgrade()
	end
	
	self:FireModuleEvent("OnProfileChange")
	self:LoadUnits()
	self:HideBlizzardFrames()
	self.Layout:CheckMedia()
	self.Units:ProfileChanged()
	self.modules.movers:Update()
end

ShadowUF.noop = function() end
ShadowUF.hiddenFrame = CreateFrame("Frame")
ShadowUF.hiddenFrame:Hide()

local rehideFrame = function(self)
	if( not InCombatLockdown() ) then
		self:Hide()
	end
end

local function basicHideBlizzardFrames(...)
	for i=1, select("#", ...) do
		local frame = select(i, ...)
		frame:UnregisterAllEvents()
		frame:HookScript("OnShow", rehideFrame)
		frame:Hide()
	end
end

local function hideBlizzardFrames(taint, ...)
	for i=1, select("#", ...) do
		local frame = select(i, ...)
		frame:UnregisterAllEvents()
		frame:Hide()

		if( frame.manabar ) then frame.manabar:UnregisterAllEvents() end
		if( frame.healthbar ) then frame.healthbar:UnregisterAllEvents() end
		if( frame.spellbar ) then frame.spellbar:UnregisterAllEvents() end
		if( frame.powerBarAlt ) then frame.powerBarAlt:UnregisterAllEvents() end

		if( taint ) then
			frame.Show = ShadowUF.noop
		else
			frame:SetParent(ShadowUF.hiddenFrame)
			frame:HookScript("OnShow", rehideFrame)
		end
	end
end

local active_hiddens = {}
function ShadowUF:HideBlizzardFrames()
	if( self.db.profile.hidden.cast and not active_hiddens.cast ) then
		hideBlizzardFrames(true, CastingBarFrame, PetCastingBarFrame)
	end

	if( self.db.profile.hidden.party and not active_hiddens.party ) then
		for i=1, MAX_PARTY_MEMBERS do
			local name = "PartyMemberFrame" .. i
			hideBlizzardFrames(true, _G[name], _G[name .. "HealthBar"], _G[name .. "ManaBar"])
		end
		
		-- This stops the compact party frame from being shown		
		UIParent:UnregisterEvent("GROUP_ROSTER_UPDATE")

		-- This just makes sure
		if( CompactPartyFrame ) then
			hideBlizzardFrames(false, CompactPartyFrame)
		end
	end

	if( CompactRaidFrameManager ) then
		if( self.db.profile.hidden.raid and not active_hiddens.raidTriggered ) then
			active_hiddens.raidTriggered = true

			local function hideRaid()
				CompactRaidFrameManager:UnregisterAllEvents()
				CompactRaidFrameContainer:UnregisterAllEvents()
				if( InCombatLockdown() ) then return end
	
				CompactRaidFrameManager:Hide()
				local shown = CompactRaidFrameManager_GetSetting("IsShown")
				if( shown and shown ~= "0" ) then
					CompactRaidFrameManager_SetSetting("IsShown", "0")
				end
			end
			
			hooksecurefunc("CompactRaidFrameManager_UpdateShown", function()
				if( self.db.profile.hidden.raid ) then
					hideRaid()
				end
			end)
			
			hideRaid()
			CompactRaidFrameContainer:HookScript("OnShow", hideRaid)
			CompactRaidFrameManager:HookScript("OnShow", hideRaid)
		end
	end

	if( self.db.profile.hidden.buffs and not active_hiddens.buffs ) then
		hideBlizzardFrames(false, BuffFrame, TemporaryEnchantFrame, ConsolidatedBuffs)
	end
	
	if( self.db.profile.hidden.player and not active_hiddens.player ) then
		hideBlizzardFrames(false, PlayerFrame, PlayerFrameAlternateManaBar)
			
		-- We keep these in case someone is still using the default auras, otherwise it messes up vehicle stuff
		PlayerFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
		PlayerFrame:RegisterEvent("UNIT_ENTERING_VEHICLE")
		PlayerFrame:RegisterEvent("UNIT_ENTERED_VEHICLE")
		PlayerFrame:RegisterEvent("UNIT_EXITING_VEHICLE")
		PlayerFrame:RegisterEvent("UNIT_EXITED_VEHICLE")
		PlayerFrame:SetMovable(true)
		PlayerFrame:SetUserPlaced(true)
		PlayerFrame:SetDontSavePosition(true)
	end

	if( self.db.profile.hidden.playerPower and not active_hiddens.playerPower ) then
		basicHideBlizzardFrames(PriestBarFrame, PaladinPowerBar, EclipseBarFrame, ShardBarFrame, RuneFrame, MonkHarmonyBar, WarlockPowerFrame)
	end

	if( self.db.profile.hidden.pet and not active_hiddens.pet ) then
		hideBlizzardFrames(false, PetFrame)
	end
	
	if( self.db.profile.hidden.target and not active_hiddens.target ) then
		hideBlizzardFrames(false, TargetFrame, ComboFrame, TargetFrameToT)
	end
	
	if( self.db.profile.hidden.focus and not active_hiddens.focus ) then
		hideBlizzardFrames(false, FocusFrame, FocusFrameToT)
	end
		
	if( self.db.profile.hidden.boss and not active_hiddens.boss ) then
		for i=1, MAX_BOSS_FRAMES do
			local name = "Boss" .. i .. "TargetFrame"
			hideBlizzardFrames(false, _G[name], _G[name .. "HealthBar"], _G[name .. "ManaBar"])
		end
	end

	if( self.db.profile.hidden.arena and not active_hiddens.arenaTriggered and IsAddOnLoaded("Blizzard_ArenaUI") and not InCombatLockdown() ) then
		active_hiddens.arenaTriggered = true

		ArenaEnemyFrames:UnregisterAllEvents()
		ArenaEnemyFrames:SetParent(self.hiddenFrame)
		ArenaPrepFrames:UnregisterAllEvents()
		ArenaPrepFrames:SetParent(self.hiddenFrame)

		SetCVar("showArenaEnemyFrames", 0, "SHOW_ARENA_ENEMY_FRAMES_TEXT")

	end

	if( self.db.profile.hidden.playerAltPower and not active_hiddens.playerAltPower ) then
		hideBlizzardFrames(false, PlayerPowerBarAlt)
	end

	-- As a reload is required to reset the hidden hooks, we can just set this to true if anything is true
	for type, flag in pairs(self.db.profile.hidden) do
		if( flag ) then
			active_hiddens[type] = true
		end
	end
end

-- Upgrade info
local infoMessages = {
	-- Old messages we don't need anymore
	{}, {},
	{
		L["You must restart Shadowed Unit Frames."],
		L["If you don't, you will be unable to use any combo point features (Chi, Holy Power, Combo Points, Aura Points, etc) until you do so."]
	}
}

function ShadowUF:ShowInfoPanel()
	local infoID = ShadowUF.db.global.infoID or 0
	if( ShadowUF.ComboPoints and infoID < 3 ) then infoID = 3 end

	ShadowUF.db.global.infoID = #(infoMessages)
	if( infoID < 0 or infoID >= #(infoMessages) ) then return end
	
	local frame = CreateFrame("Frame", nil, UIParent)
	frame:SetClampedToScreen(true)
	frame:SetFrameStrata("HIGH")
	frame:SetToplevel(true)
	frame:SetWidth(500)
	frame:SetHeight(285)
	frame:SetBackdrop({
		  bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
		  edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
		  edgeSize = 26,
		  insets = {left = 9, right = 9, top = 9, bottom = 9},
	})
	frame:SetBackdropColor(0, 0, 0, 0.85)
	frame:SetPoint("CENTER", UIParent, "CENTER", 0, 100)

	frame.titleBar = frame:CreateTexture(nil, "ARTWORK")
	frame.titleBar:SetTexture("Interface\\DialogFrame\\UI-DialogBox-Header")
	frame.titleBar:SetPoint("TOP", 0, 8)
	frame.titleBar:SetWidth(350)
	frame.titleBar:SetHeight(45)

	frame.title = frame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
	frame.title:SetPoint("TOP", 0, 0)
	frame.title:SetText("Shadowed Unit Frames")

	frame.text = frame:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
	frame.text:SetText(table.concat(infoMessages[ShadowUF.db.global.infoID], "\n"))
	frame.text:SetPoint("TOPLEFT", 12, -22)
	frame.text:SetWidth(frame:GetWidth() - 20)
	frame.text:SetJustifyH("LEFT")
	frame:SetHeight(frame.text:GetHeight() + 70)

	frame.hide = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
	frame.hide:SetText(L["Ok"])
	frame.hide:SetHeight(20)
	frame.hide:SetWidth(100)
	frame.hide:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 8, 8)
	frame.hide:SetScript("OnClick", function(self)
		self:GetParent():Hide()
	end)
end

function ShadowUF:Print(msg)
	DEFAULT_CHAT_FRAME:AddMessage("|cff33ff99Shadow UF|r: " .. msg)
end

CONFIGMODE_CALLBACKS = CONFIGMODE_CALLBACKS or {}
CONFIGMODE_CALLBACKS["Shadowed Unit Frames"] = function(mode)
	if( mode == "ON" ) then
		ShadowUF.db.profile.locked = false
		ShadowUF.modules.movers.isConfigModeSpec = true
	elseif( mode == "OFF" ) then
		ShadowUF.db.profile.locked = true
	end
	
	ShadowUF.modules.movers:Update()
end

SLASH_SHADOWEDUF1 = "/suf"
SLASH_SHADOWEDUF2 = "/shadowuf"
SLASH_SHADOWEDUF3 = "/shadoweduf"
SLASH_SHADOWEDUF4 = "/shadowedunitframes"
SlashCmdList["SHADOWEDUF"] = function(msg)
	msg = msg and string.lower(msg)
	if( msg and string.match(msg, "^profile (.+)") ) then
		local profile = string.match(msg, "^profile (.+)")
		
		for id, name in pairs(ShadowUF.db:GetProfiles()) do
			if( string.lower(name) == profile ) then
				ShadowUF.db:SetProfile(name)
				ShadowUF:Print(string.format(L["Changed profile to %s."], name))
				return
			end
		end
		
		ShadowUF:Print(string.format(L["Cannot find any profiles named \"%s\"."], profile))
		return
	end
	
	local loaded, reason = LoadAddOn("ShadowedUF_Options")
	if( not ShadowUF.Config ) then
		DEFAULT_CHAT_FRAME:AddMessage(string.format(L["Failed to load ShadowedUF_Options, cannot open configuration. Error returned: %s"], reason and _G["ADDON_" .. reason] or ""))
		return
	end
	
	ShadowUF.Config:Open()
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("ADDON_LOADED")
frame:SetScript("OnEvent", function(self, event, addon)
	if( event == "PLAYER_LOGIN" ) then
		ShadowUF:OnInitialize()
		self:UnregisterEvent("PLAYER_LOGIN")
	elseif( event == "ADDON_LOADED" and ( addon == "Blizzard_ArenaUI" or addon == "Blizzard_CompactRaidFrames" ) ) then
		ShadowUF:HideBlizzardFrames()
	end
end)
