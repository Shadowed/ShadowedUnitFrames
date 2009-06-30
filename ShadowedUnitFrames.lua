--[[ 
	Shadow Unit Frames, Mayen of Mal'Ganis (US) PvP
]]

ShadowUF = {playerUnit = "player", raidUnits = {}, partyUnits = {}, modules = {}, moduleOrder = {}, units = {"player", "pet", "pettarget", "target", "targettarget", "targettargettarget", "focus", "focustarget", "party", "partypet", "partytarget", "raid"}}
ShadowUF.is30200 = select(4, GetBuildInfo()) >= 30200

local L = ShadowUFLocals
local units = ShadowUF.units
local _G = getfenv(0)

-- Cache the units so we don't have to concat every time it updates
for i=1, MAX_PARTY_MEMBERS do ShadowUF.partyUnits[i] = "party" .. i end
for i=1, MAX_RAID_MEMBERS do ShadowUF.raidUnits[i] = "raid" .. i end

function ShadowUF:OnInitialize()
	self.defaults = {
		profile = {
			locked = false,
			advanced = false,
			tooltipCombat = false,
			tags = {},
			units = {},
			positions = {},
			visibility = {arena = {}, pvp = {}, party = {}, raid = {}},
			hidden = {player = true, pet = true, target = true, party = true, focus = true, targettarget = true, cast = nil, runes = true, buffs = true},
		},
		--char = { primary = "", secondary = ""},
	}
	
	self:LoadUnitDefaults()
	
	-- Initialize DB
	self.db = LibStub:GetLibrary("AceDB-3.0"):New("ShadowedUFDB", self.defaults, true)
	self.db.RegisterCallback(self, "OnProfileChanged", "ProfilesChanged")
	self.db.RegisterCallback(self, "OnProfileCopied", "ProfilesChanged")
	self.db.RegisterCallback(self, "OnProfileReset", "ProfileReset")
	
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
	
	-- No active layout, register the default one
	if( not self.db.profile.loadedLayout ) then
		self:LoadDefaultLayout()
	end
	
	-- UPGRADING CODE, I will remove these once a month has passed since I added them.
	self:CheckUpgrade()

	-- Hide any Blizzard frames
	self:HideBlizzardFrames()
	
	-- Load SML info
	self.Layout:LoadSML()
		
	-- Show example frames?
	self.modules.movers:Update()
end

function ShadowUF:CheckUpgrade()
	-- June 11th
	if( not self.db.profile.healthColors.friendly ) then
		self.db.profile.healthColors.friendly = CopyTable(self.db.profile.healthColors.green)
		self.db.profile.healthColors.neutral = CopyTable(self.db.profile.healthColors.yellow)
		self.db.profile.healthColors.hostile = CopyTable(self.db.profile.healthColors.red)
	end
	
	-- June 17th
	self.db.profile.layoutInfo = nil

	-- June 20th
	if( self.db.profile.units.pettarget.enabled == false and self.db.profile.units.pettarget.height == 0 and self.db.profile.units.pettarget.width == 0 ) then
		self.db.profile.positions.pettarget.anchorPoint = "C"
		self.db.profile.units.pettarget = CopyTable(self.db.profile.units.pet)
		self.db.profile.units.pettarget.enabled = false
		self.db.profile.units.pettarget.castBar = nil
		self.db.profile.units.pettarget.incHeal = nil
		self.db.profile.units.pettarget.xpBar = nil
		self.db.profile.units.pettarget.indicators.happiness = nil
	end
	
	for unit, data in pairs(self.db.profile.units) do
		-- June 25th
		if( data.auras.debuffs.raid == nil ) then
			data.auras.debuffs.raid = data.auras.buffs.curable
			data.auras.buffs.curable = nil
		end

		-- June 26th
		data.healthBar.fullSize = nil
		
		-- June 28th
		if( string.match(unit, "%w+target") and data.castBar ) then
			data.castBar = nil
		end
	end
	
	-- June 28th
	self.db.profile.positions.partypet.anchorTo = "$parent"
	self.db.profile.positions.partytarget.anchorTo = "$parent"
end
	
local partyDisabled
function ShadowUF:RAID_ROSTER_UPDATE()
	if( not self.db.profile.units.party.enabled ) then return end
	
	if( ( self.db.profile.units.party.hideSemiRaid and GetNumRaidMembers() > 5 ) or ( self.db.profile.units.party.hideAnyRaid and GetNumRaidMembers() > 0 ) ) then
		if( not partyDisabled ) then
			partyDisabled = true
			self.Units:UninitializeFrame(self.db.profile.units.party, "party")
		end
	elseif( partyDisabled ) then
		partyDisabled = nil
		self:LoadUnits()
	end
end

function ShadowUF:LoadUnits()
	local zone = select(2, IsInInstance())
	for _, type in pairs(units) do
		local enabled = self.db.profile.units[type].enabled
		if( type == "party" and partyDisabled ) then
			enabled = nil
		elseif( zone ~= "none" ) then
			if( self.db.profile.visibility[zone][type] == false ) then
				enabled = false
			elseif( self.db.profile.visibility[zone][type] == true ) then
				enabled = true
			end
		end
		
		if( enabled ) then
			self.Units:InitializeFrame(config, type)
		else
			self.Units:UninitializeFrame(config, type)
		end
	end
end

-- Why set values to nil instead of false you ask? Mostly so I can still see the fields, as when I set them to false AceDB-3.0
-- swaps settings incorrectly
function ShadowUF:LoadUnitDefaults()
	for _, unit in pairs(units) do
		self.defaults.profile.positions[unit] = {point = "", relativePoint = "", anchorPoint = "", anchorTo = "UIParent", x = 0, y = 0}
		
		-- The reason why the defaults are so sparse, is because the layout needs to specify most of this. The reason I set tables here is basically
		-- as an indication that hey, the unit wants this, if it doesn't that it won't want it.
		self.defaults.profile.units[unit] = {
			enabled = false, height = 0, width = 0, scale = 1.0,
			healthBar = {enabled = true, colorType = "percent", reaction = true},
			powerBar = {enabled = true}, portrait = {enabled = false, type = "3D", fullBefore = 0, fullAfter = 100},
			range = {enabled = false, oorAlpha = 0.80, inAlpha = 1.0},
			text = {{enabled = true, name = L["Left text"], text = "[name]", anchorTo = "$healthBar", size = 0}, {enabled = true, name = L["Right text"], text = "[curmaxhp]", anchorTo = "$healthBar", size = 0}, {enabled = true, name = L["Left text"], text = "[level] [race]", anchorTo = "$powerBar", size = 0}, {enabled = true, name = L["Right text"], text = "[curmaxpp]", anchorTo = "$powerBar", size = 0}},
			indicators = {raidTarget = {enabled = true, size = 0}}, 
			auras = {
				buffs = {enabled = false, perRow = 11, maxRows = 4, prioritize = true, enlargeSelf = false},
				debuffs = {enabled = false, perRow = 11, maxRows = 4, enlargeSelf = true},
			},
		}
				
		-- These modules are not enabled for "fake" units so don't bother with adding defaults
		if( not string.match(unit, "%w+target") ) then
			self.defaults.profile.units[unit].incHeal = {enabled = false, cap = 1.30}
			self.defaults.profile.units[unit].castBar = {enabled = false, castName = {enabled = true, anchorTo = "$parent", anchorPoint = "ICL", x = 1, y = 0}, castTime = {enabled = true, anchorTo = "$parent", anchorPoint = "ICR", x = -1, y = 0}}
			self.defaults.profile.units[unit].combatText = {enabled = true, anchorTo = "$parent", anchorPoint = "C", x = 0, y = 0}
		end
			
		-- Want pvp/leader/ML enabled for these units
		if( unit == "player" or unit == "party" or unit == "target" or unit == "raid" or unit == "focus" ) then
			self.defaults.profile.units[unit].indicators.leader = {enabled = true, size = 0}
			self.defaults.profile.units[unit].indicators.masterLoot = {enabled = true, size = 0}
			self.defaults.profile.units[unit].indicators.pvp = {enabled = true, size = 0}
			self.defaults.profile.units[unit].highlight = {enabled = false, attention = false, mouseover = false, debuff = false, aggro = false}
			
			if( unit ~= "focus" and unit ~= "target" ) then
				self.defaults.profile.units[unit].indicators.ready = {enabled = true, size = 0}
			end
		end
	end
		
	-- PLAYER
	self.defaults.profile.units.player.enabled = true
	self.defaults.profile.units.player.powerBar.predicted = true
	self.defaults.profile.units.player.indicators.status = {enabled = true, size = 19, anchorPoint = "LB", anchorTo = "$parent", x = 0, y = 0}
	self.defaults.profile.units.player.runeBar = {enabled = false}
	self.defaults.profile.units.player.totemBar = {enabled = false}
	self.defaults.profile.units.player.xpBar = {enabled = false}
	self.defaults.profile.units.player.fader = {enabled = false, combatAlpha = 1.0, inactiveAlpha = 0.60}
	self.defaults.profile.units.player.range = nil
	-- PET
	self.defaults.profile.units.pet.enabled = true
	self.defaults.profile.units.pet.indicators.happiness = {enabled = true, size = 16, anchorPoint = "BR", anchorTo = "$parent", x = 2, y = -2}
	self.defaults.profile.units.pet.fader = {enabled = false, combatAlpha = 1.0, inactiveAlpha = 0.60}
	self.defaults.profile.units.pet.xpBar = {enabled = false}
	-- FOCUS
	self.defaults.profile.units.focus.enabled = true
	-- FOCUSTARGET
	self.defaults.profile.units.focustarget.enabled = true
	-- TARGET
	self.defaults.profile.units.target.enabled = true
	self.defaults.profile.units.target.comboPoints = {enabled = true, anchorTo = "$parent", anchorPoint = "BR", x = 0, y = 0}
	-- TARGETTARGET/TARGETTARGETTARGET
	self.defaults.profile.units.targettarget.enabled = true
	self.defaults.profile.units.targettargettarget.enabled = true
	-- PARTY
	self.defaults.profile.units.party.enabled = true
	self.defaults.profile.units.party.attribPoint = "TOP"
	self.defaults.profile.units.party.attribAnchorPoint = "LEFT"
	self.defaults.profile.units.party.auras.debuffs.maxRows = 1
	self.defaults.profile.units.party.auras.buffs.maxRows = 1
	self.defaults.profile.units.party.fader = {enabled = false, combatAlpha = 1.0, inactiveAlpha = 0.60}
	self.defaults.profile.units.party.combatText.enabled = false
	-- RAID
	self.defaults.profile.units.raid.groupBy = "GROUP"
	self.defaults.profile.units.raid.sortOrder = "ASC"
	self.defaults.profile.units.raid.attribPoint = "TOP"
	self.defaults.profile.units.raid.attribAnchorPoint = "RIGHT"
	self.defaults.profile.units.raid.filters = {[1] = true, [2] = true, [3] = true, [4] = true, [5] = true, [6] = true, [7] = true, [8] = true}
	self.defaults.profile.units.raid.fader = {enabled = false, combatAlpha = 1.0, inactiveAlpha = 0.60}
	self.defaults.profile.units.raid.combatText.enabled = false
	-- PARTYPET
	self.defaults.profile.positions.partypet.anchorTo = "$parent"
	self.defaults.profile.positions.partypet.anchorPoint = "RB"
	self.defaults.profile.units.partypet.fader = {enabled = false, combatAlpha = 1.0, inactiveAlpha = 0.60}
	-- PARTYTARGET
	self.defaults.profile.positions.partytarget.anchorTo = "$parent"
	self.defaults.profile.positions.partytarget.anchorPoint = "RT"
	self.defaults.profile.units.partytarget.fader = {enabled = false, combatAlpha = 1.0, inactiveAlpha = 0.60}
	
	-- Indicate that defaults were loaded
	self:FireModuleEvent("OnDefaultsSet")
end

-- Module APIs
function ShadowUF:RegisterModule(module, key, name, isBar)
	self.modules[key] = module

	module.moduleKey = key
	module.moduleHasBar = isBar
	module.moduleName = name
	
	table.insert(self.moduleOrder, module)
end

function ShadowUF:FireModuleEvent(event, frame, unit)
	for _, module in pairs(self.moduleOrder) do
		if( module[event] ) then
			module[event](module, frame, unit)
		end
	end
end

-- Check if we need to swap profiles
--[[
function ShadowUF:ACTIVE_TALENT_GROUP_CHANGED()
	local activeGroup = GetActiveTalentGroup()
	local dbKey = activeGroup == 1 and "primary" or activeGroup == 2 and "secondary"
	if( activeGroup and self.db.char[dbKey] ~= "" and self.db.char[dbKey] ~= self.db:GetCurrentProfile() ) then
		self.db:SetProfile(self.db.char[dbKey])
		self:Print(string.format(L["Changed profile to %s as you are currently using your %s talent specialization."], self.db.char[dbKey], L[dbKey]))
	end
end
]]

function ShadowUF:Print(msg)
	DEFAULT_CHAT_FRAME:AddMessage("|cff33ff99Shadowed Unit Frames|r: " .. msg)
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
			ShadowUF:ProfilesChanged("OnProfileReset")
			self:Hide()
		end)
	end
	
	resetTimer:Show()
end

function ShadowUF:ProfilesChanged()
	-- Reset the timer manually if another event fired
	if( resetTimer ) then resetTimer:Hide() end
	
	-- Reset any loaded caches
	for k in pairs(self.tagFunc) do self.tagFunc[k] = nil end
	
	-- No active layout, register the default one
	if( not self.db.profile.loadedLayout ) then
		self:LoadDefaultLayout()
	else
		self:CheckUpgrade()
	end
	
	self:LoadUnits()
	self.Layout:CheckMedia()
	self.Units:ProfileChanged()
	self.modules.movers:Update()
end

-- Hiding Blizzard stuff (Stolen from haste)
function ShadowUF:HideBlizzardFrames()
	-- Hide Blizzard frames
	for type, hidden in pairs(self.db.profile.hidden) do
		if( hidden ) then
			self:HideBlizzard(type)
		end
	end
end

local function dummy() end
function ShadowUF:HideBlizzard(type)
	if( type == "runes" ) then
		RuneFrame.Show = dummy
		RuneFrame:Hide()
	elseif( type == "buffs" ) then
		BuffFrame:UnregisterEvent("UNIT_AURA")
		TemporaryEnchantFrame:Hide()
		BuffFrame:Hide()
	elseif( type == "player" ) then
		PlayerFrame:UnregisterAllEvents()
		PlayerFrame.Show = dummy
		PlayerFrame:Hide()

		PlayerFrameHealthBar:UnregisterAllEvents()
		PlayerFrameManaBar:UnregisterAllEvents()
	elseif( type == "pet" ) then
		PetFrame:UnregisterAllEvents()
		PetFrame.Show = dummy
		PetFrame:Hide()

		PetFrameHealthBar:UnregisterAllEvents()
		PetFrameManaBar:UnregisterAllEvents()
	elseif( type == "target" ) then
		TargetFrame:UnregisterAllEvents()
		TargetFrame.Show = dummy
		TargetFrame:Hide()

		TargetFrameHealthBar:UnregisterAllEvents()
		TargetFrameManaBar:UnregisterAllEvents()
		TargetFrameSpellBar:UnregisterAllEvents()

		ComboFrame:UnregisterAllEvents()
		ComboFrame.Show = dummy
		ComboFrame:Hide()
	elseif( type == "focus" ) then
		FocusFrame:UnregisterAllEvents()
		FocusFrame.Show = dummy
		FocusFrame:Hide()

		FocusFrameHealthBar:UnregisterAllEvents()
		FocusFrameManaBar:UnregisterAllEvents()
		FocusFrameSpellBar:UnregisterAllEvents()
	elseif( type == "targettarget" ) then
		TargetofTargetFrame:UnregisterAllEvents()
		TargetofTargetFrame.Show = dummy
		TargetofTargetFrame:Hide()

		TargetofTargetHealthBar:UnregisterAllEvents()
		TargetofTargetManaBar:UnregisterAllEvents()
	elseif( type == "cast" ) then
		CastingBarFrame:UnregisterAllEvents()
		PetCastingBarFrame:UnregisterAllEvents()
	elseif( type == "party" ) then
		for i=1, MAX_PARTY_MEMBERS do
			local party = "PartyMemberFrame" .. i
			local frame = _G[party]

			frame:UnregisterAllEvents()
			frame.Show = dummy
			frame:Hide()

			_G[party .. "HealthBar"]:UnregisterAllEvents()
			_G[party .. "ManaBar"]:UnregisterAllEvents()
		end
	end
end

-- Event handling, makes sure SUF loads fine
local frame = CreateFrame("Frame")
frame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:RegisterEvent("RAID_ROSTER_UPDATE")
frame:SetScript("OnEvent", function(self, event, ...)
	if( event == "ZONE_CHANGED_NEW_AREA" ) then
		ShadowUF:LoadUnits()
	elseif( event == "PLAYER_ENTERING_WORLD" ) then
		ShadowUF:OnInitialize()
		ShadowUF:LoadUnits()
		ShadowUF:RAID_ROSTER_UPDATE()
		--ShadowUF:ACTIVE_TALENT_GROUP_CHANGED()

		self:UnregisterEvent("PLAYER_ENTERING_WORLD")
		--self:RegisterEvent("ACTIVE_TALENT_GROUP_CHANGED")
	else
		ShadowUF[event](ShadowUF, event, ...)
	end
end)
