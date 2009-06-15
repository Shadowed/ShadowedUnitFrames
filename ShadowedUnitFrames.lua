--[[ 
	Shadow Unit Frames, Mayen of Mal'Ganis (US) PvP
]]

ShadowUF = {raidUnits = {}, partyUnits = {}, modules = {}, moduleOrder = {}, units = {"player", "pet", "target", "targettarget", "targettargettarget", "focus", "focustarget", "party", "partypet", "partytarget", "raid"}}

local L = ShadowUFLocals
local units = ShadowUF.units

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
	}
	
	self:LoadUnitDefaults()
	
	-- Initialize DB
	self.db = LibStub:GetLibrary("AceDB-3.0"):New("ShadowedUFDB", self.defaults, true)
	self.db.RegisterCallback(self, "OnProfileChanged", "ProfilesChanged")
	self.db.RegisterCallback(self, "OnProfileCopied", "ProfilesChanged")
	self.db.RegisterCallback(self, "OnProfileReset", "ProfilesChanged")
		
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
	
	-- UPGRADING CODE
	-- I will remove these once a month has passed since I added them.
	do
		-- May 28th
		if( self.db.profile.activeLayout ) then
			self.db.profile.activeLayout = nil
			DEFAULT_CHAT_FRAME:AddMessage("|cff33ff99ShadowUF|r: Warning, a layout reset has been forced due to changes in the database format to improve performance and clean up the code. Sorry!")
		end

		if( not self.db.profile.units.player.indicators.ready.anchorTo ) then
			for unit, data in pairs(self.db.profile.units) do
				if( data.indicators and self.defaults.profile.units[unit].indicators.ready and not data.indicators.ready.anchorTo ) then
					data.indicators.ready.anchorTo = "$parent"
					data.indicators.ready.anchorPoint = "LC"
					data.indicators.ready.size = 24
					data.indicators.ready.x = 0
					data.indicators.ready.y = 0
				end
			end
		end
		
		-- May 30th
		if( not self.db.profile.powerColors.AMMOSLOT ) then
			self.db.profile.powerColors.AMMOSLOT = {r = 0.85, g = 0.60, b = 0.55}
			self.db.profile.powerColors.FUEL = {r = 0.85, g = 0.47, b = 0.36}
			self.db.profile.classColors.VEHICLE = {r = 0.40, g = 0.85, b = 0.48}
			
			-- Disable fader on units that it shouldn't have been enabled for
			self.db.profile.units.focus.fader = nil
			self.db.profile.units.focustarget.fader = nil
			self.db.profile.units.target.fader = nil
			self.db.profile.units.targettarget.fader = nil
			self.db.profile.units.targettargettarget.fader = nil
		end
		
		-- May 31th
		if( self.db.profile.units.targettarget.indicators.pvp ) then
			self.db.profile.units.focustarget.indicators.pvp = nil
			self.db.profile.units.targettarget.indicators.pvp = nil
			self.db.profile.units.targettargettarget.indicators.pvp = nil
		end
		
		if( self.db.profile.units.party.hideInRaid ) then
			self.db.profile.units.party.hideSemiRaid = self.db.profile.units.party.hideInRaid
			self.db.profile.units.party.hideInRaid = nil
		end
		
		if( self.db.profile.units.player.range ) then
			self.db.profile.units.player.range = nil
		end
		
		-- Jun 11th
		if( not self.db.profile.healthColors.friendly ) then
			self.db.profile.healthColors.friendly = CopyTable(self.db.profile.healthColors.green)
			self.db.profile.healthColors.neutral = CopyTable(self.db.profile.healthColors.yellow)
			self.db.profile.healthColors.hostile = CopyTable(self.db.profile.healthColors.red)
		end
		
		-- June 15th
		if( type(self.db.profile.loadedLayout) == "string" ) then
			--self.db.profile.loadedLayout = true
					
			ShadowUF.db.profile.units.pet.indicators.happiness.size = ShadowUF.db.profile.units.pet.indicators.happiness.size or 0
			for _, config in pairs(ShadowUF.db.profile.units) do
				config.text[1].name = L["Left text"]
				config.text[1].text = config.text[1].text or "[afk( )][name]"
				config.text[1].size = config.text[1].size or 0
				config.text[1].anchorTo = "$healthBar"
				config.text[1].anchorPoint = "ICL"

				config.text[2].name = L["Right text"]
				config.text[2].text = config.text[2].text or "[curmaxhp]"
				config.text[2].size = config.text[2].size or 0
				config.text[2].anchorTo = "$healthBar"
				config.text[2].anchorPoint = "ICR"

				config.text[3].name = L["Left text"]
				config.text[3].text = config.text[3].text or "[level] [race]"
				config.text[3].size = config.text[3].size or 0
				config.text[3].anchorTo = "$powerBar"
				config.text[3].anchorPoint = "ICL"

				config.text[4].name = L["Right text"]
				config.text[4].text = config.text[4].text or "[curmaxpp]"
				config.text[4].size = config.text[4].size or 0
				config.text[4].anchorTo = "$powerBar"
				config.text[4].anchorPoint = "ICR"
			end
		end
	end
	
	-- Hide any Blizzard frames
	self:HideBlizzardFrames()
	
	-- Load SML info
	self.Layout:LoadSML()
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
		local config = self.db.profile.units[type]
		if( config ) then
			local enabled = config.enabled
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
			powerBar = {enabled = true}, portrait = {enabled = false, type = "3D"},
			range = {enabled = false, oorAlpha = 0.80, inAlpha = 1.0},
			text = {{enabled = true, name = L["Left text"]}, {enabled = true, name = L["Right text"]}, {enabled = true, name = L["Left text"]}, {enabled = true, name = L["Right text"]}},
			indicators = {raidTarget = {enabled = true}}, 
			auras = {
				buffs = {enabled = false, perRow = 11, maxRows = 4, prioritize = true, enlargeSelf = false},
				debuffs = {enabled = false, perRow = 11, maxRows = 4, enlargeSelf = true},
			},
		}
				
		-- These modules are not enabled for "fake" units so don't bother with adding defaults
		if( not string.match(unit, "%w+target") ) then
			self.defaults.profile.units[unit].incHeal = {enabled = false}
			self.defaults.profile.units[unit].castBar = {enabled = false, castName = {enabled = true, anchorTo = "$parent", anchorPoint = "ICL", x = 1, y = 0}, castTime = {enabled = true, anchorTo = "$parent", anchorPoint = "ICR", x = -1, y = 0}}
			self.defaults.profile.units[unit].combatText = {enabled = true}
		end
			
		-- Want pvp/leader/ML enabled for these units
		if( unit == "player" or unit == "party" or unit == "target" or unit == "raid" or unit == "focus" ) then
			self.defaults.profile.units[unit].indicators.leader = {enabled = true}
			self.defaults.profile.units[unit].indicators.masterLoot = {enabled = true}
			self.defaults.profile.units[unit].indicators.pvp = {enabled = true}
			
			if( unit ~= "focus" and unit ~= "target" ) then
				self.defaults.profile.units[unit].indicators.ready = {enabled = true}
			end
		end
	end
		
	-- PLAYER
	self.defaults.profile.units.player.enabled = true
	self.defaults.profile.units.player.powerBar.predicted = true
	self.defaults.profile.units.player.runeBar = {enabled = false}
	self.defaults.profile.units.player.totemBar = {enabled = false}
	self.defaults.profile.units.player.xpBar = {enabled = false}
	self.defaults.profile.units.player.fader = {enabled = false, combatAlpha = 1.0, inactiveAlpha = 0.60}
	self.defaults.profile.units.player.indicators.status = {enabled = true}
	self.defaults.profile.units.player.range = false
	-- PET
	self.defaults.profile.units.pet.enabled = true
	self.defaults.profile.units.pet.indicators.happiness = {enabled = true}
	self.defaults.profile.units.pet.fader = {enabled = false, combatAlpha = 1.0, inactiveAlpha = 0.60}
	self.defaults.profile.units.pet.xpBar = {enabled = false}
	-- FOCUS
	self.defaults.profile.units.focus.enabled = true
	-- FOCUSTARGET
	self.defaults.profile.units.focustarget.enabled = true
	-- TARGET
	self.defaults.profile.units.target.enabled = true
	self.defaults.profile.units.target.comboPoints = {enabled = false}
	-- TARGETTARGET/TARGETTARGETTARGET
	self.defaults.profile.units.targettarget.enabled = true
	self.defaults.profile.units.targettargettarget.enabled = true
	-- PARTY
	self.defaults.profile.units.party.enabled = true
	self.defaults.profile.units.party.auras.debuffs.maxRows = 1
	self.defaults.profile.units.party.auras.buffs.maxRows = 1
	self.defaults.profile.units.party.fader = {enabled = false, combatAlpha = 1.0, inactiveAlpha = 0.60}
	self.defaults.profile.units.party.combatText.enabled = false
	-- RAID
	self.defaults.profile.units.raid.groupBy = "GROUP"
	self.defaults.profile.units.raid.sortOrder = "ASC"
	self.defaults.profile.units.raid.filters = {[1] = true, [2] = true, [3] = true, [4] = true, [5] = true, [6] = true, [7] = true, [8] = true}
	self.defaults.profile.units.raid.fader = {enabled = false, combatAlpha = 1.0, inactiveAlpha = 0.60}
	self.defaults.profile.units.raid.combatText.enabled = false
	-- PARTYPET
	self.defaults.profile.units.partypet.fader = {enabled = false, combatAlpha = 1.0, inactiveAlpha = 0.60}
	-- PARTYTARGET
	self.defaults.profile.units.partytarget.fader = {enabled = false, combatAlpha = 1.0, inactiveAlpha = 0.60}
	
	-- Indicate that defaults were loaded
	self:FireModuleEvent("OnDefaultsSet")
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
			local frame = getglobal(party)

			frame:UnregisterAllEvents()
			frame.Show = dummy
			frame:Hide()

			getglobal(party .. "HealthBar"):UnregisterAllEvents()
			getglobal(party .. "ManaBar"):UnregisterAllEvents()
		end
	end
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

-- Profiles changed
function ShadowUF:ProfilesChanged()
	-- Reset any loaded caches
	for k in pairs(self.tagFunc) do self.tagFunc[k] = nil end
	
	-- No active layout, register the default one
	if( not self.db.profile.loadedLayout ) then
		self:LoadDefaultLayout()
	end
	
	ShadowUF.Layout:CheckMedia()
	ShadowUF.Units:ProfileChanged()
	ShadowUF:LoadUnits()
	ShadowUF.Layout:ReloadAll()
end

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

		self:UnregisterEvent("PLAYER_ENTERING_WORLD")
	else
		ShadowUF[event](ShadowUF, event, ...)
	end
end)
