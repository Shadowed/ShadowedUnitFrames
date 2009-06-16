local Units = {unitFrames = {}}
local vehicleMonitor = CreateFrame("Frame", nil, nil, "SecureHandlerBaseTemplate")
local unitEvents, loadedUnits, queuedCombat = {}, {}, {}, {}
local unitFrames = Units.unitFrames
local inCombat, needPartyFrame, frameMoving, centralFrame
local FRAME_LEVEL_MAX = 5

ShadowUF.Units = Units
ShadowUF:RegisterModule(Units, "units")

-- Frame shown, do a full update
local function FullUpdate(self)
	for i=1, #(self.fullUpdates), 2 do
		local handler = self.fullUpdates[i]
		handler[self.fullUpdates[i + 1]](handler, self)
	end
end

-- Register an event that should always call the frame
local function RegisterNormalEvent(self, event, handler, func)
	self:RegisterEvent(event)
	self.registeredEvents[event] = self.registeredEvents[event] or {}
	
	-- Each handler can only register an event once per a frame.
	if( self.registeredEvents[event][handler] ) then
		return
	end
			
	self.registeredEvents[event][handler] = func
end

-- Unregister an event
local function UnregisterEvent(self, event, handler)
	if( self and self.registeredEvents[handler] ) then
		self.registeredEvents[event][handler] = nil
	end
end

-- Register an event thats only called if it's for the actual unit
local function RegisterUnitEvent(self, event, handler, func)
	unitEvents[event] = true
	RegisterNormalEvent(self, event, handler, func)
end

-- Register a function to be called in an OnUpdate if it's an invalid unit (targettarget/etc)
local function RegisterUpdateFunc(self, handler, func)
	for i=1, #(self.fullUpdates), 2 do
		local data = self.fullUpdates[i]
		if( data == handler and self.fullUpdates[i + 1] == func ) then
			return
		end
	end
	
	table.insert(self.fullUpdates, handler)
	table.insert(self.fullUpdates, func)
end

-- Used when something is disabled, removes all callbacks etc to it
local function UnregisterAll(self, handler)
	for i=#(self.fullUpdates), 1, -1 do
		if( self.fullUpdates[i] == handler ) then
			table.remove(self.fullUpdates, i + 1)
			table.remove(self.fullUpdates, i)
		end
	end

	for event, list in pairs(self.registeredEvents) do
		list[handler] = nil
		
		local totalEvents = 0
		for _ in pairs(list) do
			totalEvents = totalEvents + 1
		end
		
		if( totalEvents == 0 ) then
			self:UnregisterEvent(event)
		end
	end
end

-- Event handling
local function OnEvent(self, event, unit, ...)
	if( not unitEvents[event] or self.unit == unit ) then
		for handler, func in pairs(self.registeredEvents[event]) do
			handler[func](handler, self, event, unit, ...)
		end
	end
end

-- Do a full update OnShow, and stop watching for events when it's not visible
local function OnShow(self)
	-- Reset the event handler
	self:SetScript("OnEvent", OnEvent)
	
	Units:CheckUnitGUID(self)
end

local function OnHide(self)
	self:SetScript("OnEvent", nil)
	
	-- If it's a non-static unit like target or focus, will reset the flag and force an update when it's shown.
	if( self.unitType ~= "party" and self.unitType ~= "partypet" and self.unitType ~= "partytarget" and self.unitType ~= "player" and self.unitType ~= "raid" ) then
		self.unitGUID = nil
	end
end

-- For targettarget/focustarget/etc units that don't give us real events
local function TargetUnitUpdate(self, elapsed)
	self.timeElapsed = self.timeElapsed + elapsed
	
	if( self.timeElapsed >= 0.50 ) then
		self.timeElapsed = 0
		self:FullUpdate()
	end
end

-- Deal with enabling modules inside a zone
local function SetVisibility(self)
	local layoutUpdate
	local zone = select(2, IsInInstance())
	-- Selectively disable modules
	for _, module in pairs(ShadowUF.moduleOrder) do
		if( module.OnEnable and module.OnDisable ) then
			local key = module.moduleKey
			local enabled = ShadowUF.db.profile.units[self.unitType][key] and ShadowUF.db.profile.units[self.unitType][key].enabled
			
			-- Make sure at least one option is enabled if it's an aura or indicator
			if( key == "auras" or key == "indicators" ) then
				enabled = false
				for _, option in pairs(ShadowUF.db.profile.units[self.unitType][key]) do
					if( option.enabled ) then
						enabled = true
						break
					end
				end
			end
					
			if( zone ~= "none" ) then
				if( ShadowUF.db.profile.visibility[zone][self.unitType .. key] == false ) then
					enabled = false
				elseif( ShadowUF.db.profile.visibility[zone][self.unitType .. key] == true ) then
					enabled = true
				end
			end
			
			-- Options changed, will need to do a layout update
			local wasEnabled = self.visibility[key]
			if( self.visibility[key] ~= enabled ) then
				layoutUpdate = true
			end
			
			self.visibility[key] = enabled
			
			-- Module isn't enabled all the time, only in this zone so we need to force it to be enabled
			if( enabled and ( not self[key] or self[key].disabled )) then
				module:OnEnable(self)
			elseif( not enabled and wasEnabled ) then
				module:OnDisable(self)
				if( self[key] ) then self[key].disabled = true end
			end
		end
	end
	
	-- We had a module update, so redo everything
	if( layoutUpdate ) then
		ShadowUF.Layout:ApplyAll(self)
		self:FullUpdate()
	end
end

-- Annoying, but a pure OnUpdate seems to be the most accurate way of ensuring we got data if it was delayed
local function checkVehicleData(self, elapsed)
	self.timeElapsed = self.timeElapsed + elapsed
	if( self.timeElapsed >= 0.20 ) then
		self.timeElapsed = 0
		self.dataAttempts = self.dataAttempts + 1
		
		-- Either we got data already, or it took over 5 seconds (25 tries) to get it
		if( UnitIsConnected(self.unit) or UnitHealthMax(self.unit) > 0 or self.dataAttempts >= 25 ) then
			self:SetScript("OnUpdate", nil)
			self:FullUpdate()
		end
	end
end

-- Check if a unit entered a vehicle
function Units:CheckVehicleStatus(frame)
	-- Not in a vehicle yet, and they entered one that has a UI 
	if( not frame.inVehicle and UnitHasVehicleUI(frame.unitOwner) ) then
		frame.inVehicle = true
		frame.unit = frame.vehicleUnit

		if( not UnitIsConnected(frame.unit) or UnitHealthMax(frame.unit) == 0 ) then
			frame.timeElapsed = 0
			frame.dataAttempts = 0
			frame:SetScript("OnUpdate", checkVehicleData)
		else
			frame:FullUpdate()
		end
	-- Was in a vehicle, no longer has a UI
	elseif( frame.inVehicle and not UnitHasVehicleUI(frame.unitOwner) ) then
		frame.inVehicle = false
		frame.unit = frame.unitOwner
		frame:FullUpdate()
	end
end

-- When a frames GUID changes,
-- Handles checking for GUID changes for doing a full update, this fixes frames sometimes showing the wrong unit when they change
function Units:CheckUnitGUID(frame)
	local guid = frame.unit and UnitGUID(frame.unit)
	if( guid ~= frame.unitGUID ) then
		frame:FullUpdate()
	end
	
	frame.unitGUID = guid
end


-- When player summons a new pet, UNIT_PET fires for player, when party1 summons a new one, party1 fires not partypet1/party1pet
function Units:CheckUnitUpdated(frame, event, unit)
	if( unit ~= frame.unitRealOwner or not UnitExists(unit) ) then return end
	frame:FullUpdate()
end

-- Sets up the unit and all that good stuff
local function SetupUnitFrame(self)
	unitFrames[self.unit] = self
			
	-- Add to Clique
	ClickCastFrames = ClickCastFrames or {}
	ClickCastFrames[self] = true
	
	-- You got to love programming without documentation, ~3 hours spent making this work with raids and such properly, turns out? It's a simple attribute
	-- and all you have to do is set it up so the unit variables are properly changed based on being in a vehicle... which is what will do now
	if( self.unit == "player" or self.unitType == "party" or self.unitType == "raid" ) then
		-- player -> pet, party -> partypet#, raid -> raidpet# (party#pet/raid#pet work too, the secure headers automatically translate it to *pet# thought.
		self.vehicleUnit = self.unitOwner == "player" and "vehicle" or self.unitType == "party" and "partypet" .. self.unitID or self.unitType == "raid" and "raidpet" .. self.unitID

		self:RegisterNormalEvent("UNIT_ENTERED_VEHICLE", Units, "CheckVehicleStatus")
		self:RegisterNormalEvent("UNIT_EXITED_VEHICLE", Units, "CheckVehicleStatus")
		self:RegisterUpdateFunc(Units, "CheckVehicleStatus")
		
		-- This unit can be a vehicle, so will want to be able to target the vehicle if they enter one
		self:SetAttribute("toggleForVehicle", true)
		
		-- Check if they are in a vehicle
		Units:CheckVehicleStatus(self)
	end	

	-- Update module status
	self:SetVisibility()
end

-- Attribute set, something changed
local function OnAttributeChanged(self, name, unit)
	if( name ~= "unit" or ( not unit and not self.unit ) ) then return end
	-- I'd love if it this all worked in combat, but I don't really want to rewrite it 100% into secure templates
	if( inCombat ) then
		-- Either the unit was reset, or the unit's actually changed
		if( not unit or self.updateGUID ~= UnitGUID(unit) ) then
			self.updateGUID = unit and UnitGUID(unit)
			queuedCombat[self] = true
		end
		return
	-- No change, or the unit was killed
	elseif( unit == self.unitOwner or not unit ) then
		return
	end
	
	-- Setup identification data
	self.unit = unit
	self.unitID = tonumber(string.match(unit, "([0-9]+)"))
	self.unitType = string.gsub(unit, "([0-9]+)", "")
	self.unitOwner = unit
	self.updateGUID = UnitGUID(unit)
	
	-- Pet changed, going from pet -> vehicle for one
	if( self.unit == "pet" or self.unitType == "partypet" ) then
		self.unitRealOwner = self.unit == "pet" and "player" or ShadowUF.partyUnits[self.unitID]
		self:RegisterNormalEvent("UNIT_PET", Units, "CheckUnitUpdated")

		-- Hide any pet that became a vehicle, we detect this by the player being untargetable but we have a pet out
		local text = string.format("[target=%s, nohelp,noharm] vehicle; [target=%s, exists] pet", self.unitRealOwner, self.unit)
		RegisterStateDriver(self, "vehicleupdated", text)
		vehicleMonitor:WrapScript(self, "OnAttributeChanged", [[
			if( name == "state-vehicleupdated" ) then
				self:SetAttribute("unitIsVehicle", value == "vehicle" and true or false)
			elseif( name == "state-unitexists" ) then
				if( not value or self:GetAttribute("unitIsVehicle") ) then
					self:Hide()
				elseif( value ) then
					self:Show()
				end
			end
		]])
		
		-- Logged out in a vehicle
		if( UnitHasVehicleUI(self.unitRealOwner) ) then
			self:SetAttribute("unitIsVehicle", true)
		end

	-- Automatically do a full update on target change
	elseif( self.unit == "target" ) then
		self:RegisterNormalEvent("PLAYER_TARGET_CHANGED", self, "FullUpdate")

	-- Automatically do a full update on focus change
	elseif( self.unit == "focus" ) then
		self:RegisterNormalEvent("PLAYER_FOCUS_CHANGED", self, "FullUpdate")
	
	-- When a player is force ressurected by releasing in naxx/tk/etc then they might freeze
	elseif( self.unit == "player" ) then
		self:RegisterNormalEvent("PLAYER_ALIVE", self, "FullUpdate")
	
	-- Check for a unit guid to do a full update
	elseif( self.unitType == "raid" ) then
		self:RegisterNormalEvent("RAID_ROSTER_UPDATE", Units, "CheckUnitGUID")
		
	-- Party members need to watch for changes
	elseif( self.unitType == "party" ) then
		self:RegisterNormalEvent("PARTY_MEMBERS_CHANGED", Units, "CheckUnitGUID")

		-- Party frame has been loaded, so initialize it's sub-frames if they are enabled
		if( loadedUnits.partypet ) then
			Units:LoadPartyChildUnit(ShadowUF.db.profile.units.partypet, SUFHeaderparty, "partypet", "partypet" .. self.unitID)
		end
		
		if( loadedUnits.partytarget ) then
			Units:LoadPartyChildUnit(ShadowUF.db.profile.units.partytarget, SUFHeaderparty, "partytarget", "party" .. self.unitID .. "target")
		end

	-- *target units are not real units, thus they do not receive events and must be polled for data
	elseif( string.match(self.unit, "%w+target") ) then
		self.timeElapsed = 0
		self:SetScript("OnUpdate", TargetUnitUpdate)
		
		-- This speeds up updating of fake units, if party1 changes target than party1target is force updated, if target changes target, then targettarget and targettarget are force updated
		-- same goes for focus changing target, focustarget is forced to update.
		self.unitRealOwner = self.unitType == "partytarget" and ShadowUF.partyUnits[self.unitID] or self.unitType == "focustarget" and "focus" or "target"
		self:RegisterNormalEvent("UNIT_TARGET", Units, "CheckUnitUpdated")
		
		-- Another speed up, if the focus changes then of course the focustarget has to be force updated
		if( self.unit == "focustarget" ) then
			self:RegisterNormalEvent("PLAYER_FOCUS_CHANGED", self, "FullUpdate")
		-- If the player changes targets, then we know the targettarget and targettargettarget definitely changed
		elseif( self.unit == "targettarget" or self.unit == "targettargettarget" ) then
			self:RegisterNormalEvent("PLAYER_TARGET_CHANGED", self, "FullUpdate")
		end
	end
	
	-- Initialize all of the frame visuals
	SetupUnitFrame(self)
end

function Units:LoadUnit(config, unit)
	-- Already be loaded, just enable
	if( unitFrames[unit] ) then
		unitFrames[unit]:SetAttribute("unit", unit)
		RegisterUnitWatch(unitFrames[unit], unit == "pet")
		return
	end
	
	local frame = CreateFrame("Button", "SUFUnit" .. unit, UIParent, "SecureUnitButtonTemplate")
	self:CreateUnit(frame)
	frame:SetAttribute("unit", unit)

	unitFrames[unit] = frame
		
	-- Annd lets get this going
	RegisterUnitWatch(frame, unit == "pet")
end

local function OnDragStart(self)
	if( ShadowUF.db.profile.locked or self.isMoving ) then return end
	self = unitFrames[self.unitType] or self
	
	self.isMoving = true
	self:StartMoving()

	frameMoving = self
	
	GameTooltip:Hide()
end

local function OnDragStop(self)
	self = unitFrames[self.unitType] or self
	
	if( not self.isMoving ) then
		return
	end
	
	self.isMoving = nil
	self:StopMovingOrSizing()
	
	local scale = self:GetEffectiveScale()
	local position = ShadowUF.db.profile.positions[self.unitType]
	local point, _, relativePoint, x, y = self:GetPoint()
		
	position.anchorPoint = ""
	position.point = point
	position.anchorTo = "UIParent"
	position.relativePoint = relativePoint
	position.x = x * scale
	position.y = y * scale
	
	frameMoving = nil
end


-- Show tooltip
local function OnEnter(...)
	if( not ShadowUF.db.profile.tooltipCombat or not inCombat ) then
		UnitFrame_OnEnter(...)
	end
end

local function ShowMenu(frame)
	local menuFrame
	if( frame.unit == "player" ) then
		menuFrame = PlayerFrameDropDown
	elseif( frame.unit == "pet" ) then
		menuFrame = PetFrameDropDown
	elseif( frame.unit == "target" ) then
		menuFrame = TargetFrameDropDown
	elseif( frame.unitType == "party" ) then
		menuFrame = getglobal("PartyMemberFrame" .. frame.unitID .. "DropDown")
	elseif( frame.unitType == "raid" ) then
		menuFrame = FriendsDropDown
		menuFrame.displayMode = "MENU"
		menuFrame.initialize = RaidFrameDropDown_Initialize
		menuFrame.userData = frame.unitID
	end
		
	if( not menuFrame ) then
		return
	end
	
	HideDropDownMenu(1)
	menuFrame.unit = frame.unit
	menuFrame.name = UnitName(frame.unit)
	menuFrame.id = frame.unitID
	ToggleDropDownMenu(1, nil, menuFrame, "cursor")
end

-- Create the generic things that we want in every secure frame regardless if it's a button or a header
function Units:CreateUnit(frame,  hookVisibility)
	frame.barFrame = CreateFrame("Frame", nil, frame)
	
	frame.fullUpdates = {}
	frame.registeredEvents = {}
	frame.visibility = {}
	frame.RegisterNormalEvent = RegisterNormalEvent
	frame.RegisterUnitEvent = RegisterUnitEvent
	frame.RegisterUpdateFunc = RegisterUpdateFunc
	frame.UnregisterAll = UnregisterAll
	frame.FullUpdate = FullUpdate
	frame.SetVisibility = SetVisibility
	frame.topFrameLevel = FRAME_LEVEL_MAX
	
	-- Ensures that text is the absolute highest thing there is
	frame.highFrame = CreateFrame("Frame", nil, frame)
	frame.highFrame:SetFrameLevel(frame.topFrameLevel + 1)
	frame.highFrame:SetAllPoints(frame)
	
	frame:SetScript("OnDragStart", OnDragStart)
	frame:SetScript("OnDragStop", OnDragStop)
	frame:SetScript("OnAttributeChanged", OnAttributeChanged)
	frame:SetScript("OnEnter", 	OnEnter)
	frame:SetScript("OnLeave", 	UnitFrame_OnLeave)
	frame:SetScript("OnEvent", OnEvent)

	frame:SetMovable(true)
	frame:RegisterForDrag("LeftButton")
	frame:RegisterForClicks("AnyUp")	
	frame:SetAttribute("*type1", "target")
	frame:SetAttribute("*type2", "menu")
	-- allowVehicleTarget
	--[16:42] <+alestane> Shadowed: It says whether a unit defined as, for instance, "party1target" should be remapped to "partypet1target" when party1 is in a vehicle.
	frame.menu = ShowMenu

	if( hookVisibility ) then
		frame:HookScript("OnShow", OnShow)
		frame:HookScript("OnHide", OnHide)
	else
		frame:SetScript("OnShow", OnShow)
		frame:SetScript("OnHide", OnHide)
	end
end

function Units:ReloadHeader(type)
	-- Update the main header
	local frame = unitFrames[type]
	if( frame ) then
		self:SetFrameAttributes(frame, type)
		ShadowUF.Layout:AnchorFrame(UIParent, frame, ShadowUF.db.profile.positions[type])
	end

	-- Now update it's children
	if( type == "partypet" or type == "partytarget" ) then
		for _, frame in pairs(unitframes) do
			if( frame.unitType == type ) then
				self:SetFrameAttributes(frame, type)
				if( UnitExists(frame.unit) ) then
					frame:Hide()
					frame:Show()
				end
			end
		end
	end
end

function Units:ProfileChanged()
	-- Force all of the module changes
	for _, frame in pairs(unitFrames) do
		if( frame:GetAttribute("unit") ) then
			-- Force all enabled modules to disable
			for key, module in pairs(ShadowUF.modules) do
				if( frame[key] and frame[key].disabled ) then
					frame[key].disabled = true
					module:OnDisable(frame)
				end
			end
			
			-- Now enable whatever we need to
			frame:SetVisibility()
			frame:FullUpdate()
		end
	end
	
	-- Force headers to update
	self:ReloadHeader("raid")
	self:ReloadHeader("party")
end

function Units:SetFrameAttributes(frame, type)
	local config = ShadowUF.db.profile.units[type]
	if( not config ) then
		return
	end
	
	if( type == "raid" or type == "party" ) then
		frame:SetAttribute("point", config.attribPoint)
		frame:SetAttribute("initial-width", config.width)
		frame:SetAttribute("initial-height", config.height)
		frame:SetAttribute("initial-scale", config.scale)
		frame:SetAttribute("showRaid", type == "raid" and true or false)
		frame:SetAttribute("showParty", type == "party" and true or false)
		frame:SetAttribute("xOffset", config.xOffset)
		frame:SetAttribute("yOffset", config.yOffset)
		
		if( type == "raid" ) then
			local filter
			for id, enabled in pairs(config.filters) do
				if( enabled ) then
					if( filter ) then
						filter = filter .. "," .. id
					else
						filter = id
					end
				end
			end
		
			frame:SetAttribute("sortMethod", "INDEX")
			frame:SetAttribute("sortDir", config.sortOrder)
			frame:SetAttribute("maxColumns", config.maxColumns)
			frame:SetAttribute("unitsPerColumn", config.unitsPerColumn)
			frame:SetAttribute("columnSpacing", config.columnSpacing)
			frame:SetAttribute("columnAnchorPoint", config.attribAnchorPoint)
			frame:SetAttribute("groupFilter", filter or "1,2,3,4,5,6,7,8")
			
			if( config.groupBy == "CLASS" ) then
				frame:SetAttribute("groupingOrder", "DEATHKNIGHT,DRUID,HUNTER,MAGE,PALADIN,PRIEST,ROGUE,SHAMAN,WARLOCK,WARRIOR")
				frame:SetAttribute("groupBy", "CLASS")
			else
				frame:SetAttribute("groupingOrder", "1,2,3,4,5,6,7,8")
				frame:SetAttribute("groupBy", "GROUP")
			end
		end
	elseif( type == "partypet" or type == "partytarget" ) then
		frame:SetAttribute("framePositioned", false)
		frame:SetAttribute("framePoint", ShadowUF.Layout:GetPoint(ShadowUF.db.profile.positions[type].anchorPoint))
		frame:SetAttribute("frameRelative", ShadowUF.Layout:GetRelative(ShadowUF.db.profile.positions[type].anchorPoint))
		frame:SetAttribute("frameX", ShadowUF.db.profile.positions[type].x)
		frame:SetAttribute("frameY", ShadowUF.db.profile.positions[type].y)
	end
end

local function initializeUnit(self)
	self.ignoreAnchor = true
	Units:CreateUnit(self)
end

function Units:LoadGroupHeader(config, type)
	if( unitFrames[type] ) then
		self:SetFrameAttributes(unitFrames[type], type)
		unitFrames[type]:Show()
		return
	end
	
	local headerFrame = CreateFrame("Frame", "SUFHeader" .. type, UIParent, "SecureGroupHeaderTemplate")
	self:SetFrameAttributes(headerFrame, type)
	
	headerFrame:SetAttribute("template", "SecureUnitButtonTemplate")
	headerFrame:SetAttribute("initial-unitWatch", true)
	headerFrame.initialConfigFunction = initializeUnit
	headerFrame.unitType = type
	headerFrame:SetMovable(true)
	headerFrame:RegisterForDrag("LeftButton")
	headerFrame:Show()

	unitFrames[type] = headerFrame
	ShadowUF.Layout:AnchorFrame(UIParent, headerFrame, ShadowUF.db.profile.positions[type])
end

function Units:LoadPartyChildUnit(config, parentHeader, type, unit)
	if( unitFrames[unit] ) then
		self:SetFrameAttributes(unitFrames[unit], unitFrames[unit].unitType)
		RegisterUnitWatch(unitFrames[unit], type == "partypet")
		return
	end
	
	local frame = CreateFrame("Button", "SUFUnit" .. unit, UIParent, "SecureUnitButtonTemplate,SecureHandlerShowHideTemplate")
	frame.ignoreAnchor = true
	frame:Hide()

	self:SetFrameAttributes(frame, type)
	
	self:CreateUnit(frame, true)
	frame:SetFrameRef("partyHeader",  parentHeader)
	frame:SetAttribute("unit", unit)
	frame:SetAttribute("unitOwner", "party" .. (string.match(unit, "(%d+)")))
	frame:SetAttribute("_onshow", [[
		if( self:GetAttribute("framePositioned") ) then return end
		
		local children = table.new(self:GetFrameRef("partyHeader"):GetChildren())
		for _, child in pairs(children) do
			if( child:GetAttribute("unit") == self:GetAttribute("unitOwner") ) then
				self:SetParent(child)
				self:ClearAllPoints()
				self:SetPoint(self:GetAttribute("framePoint"), child, self:GetAttribute("frameRelative"), self:GetAttribute("frameX"), self:GetAttribute("frameY"))
				self:SetAttribute("framePositioned", true)
			end
		end
	]])
	
	unitFrames[unit] = frame

	-- Annd lets get this going
	RegisterUnitWatch(frame, type == "partypet")
end

function Units:InitializeFrame(config, type)
	if( loadedUnits[type] ) then return end
	loadedUnits[type] = true
	
	if( type == "party" ) then
		self:LoadGroupHeader(config, type)
	elseif( type == "raid" ) then
		self:LoadGroupHeader(config, type)
	-- Since I delay the partypet/partytarget creation until the owners were loaded, we don't want to actually initialize them here
	-- unless the pets were already loaded, this mainly accounts for the fact that you might enable a unit in arenas, but not in raids, etc.
	elseif( type == "partypet" ) then
		for id, unit in pairs(ShadowUF.partyUnits) do
			if( unitFrames[unit] ) then
				Units:LoadPartyChildUnit(ShadowUF.db.profile.units.partypet, SUFHeaderparty, "partypet", "partypet" .. id)
			end
		end
	elseif( type == "partytarget" ) then
		for id, unit in pairs(ShadowUF.partyUnits) do
			if( unitFrames[unit] ) then
				Units:LoadPartyChildUnit(ShadowUF.db.profile.units.partytarget, SUFHeaderparty, "partytarget", "party" .. id .. "target")
			end
		end
	else
		self:LoadUnit(config, type)
	end
end

local function disableChildren(...)
	for i=1, select("#", ...) do
		local frame = select(i, ...)
		if( frame.unit ) then
			frame:SetAttribute("unit", nil)
		end
	end
end

function Units:UninitializeFrame(config, type)
	if( not loadedUnits[type] ) then return end
	loadedUnits[type] = nil
	
	-- We're trying to disable a header
	if( unitFrames[type] ) then
		UnregisterUnitWatch(unitFrames[type])
		unitFrames[type]:Hide()
		
		disableChildren(unitFrames[type]:GetChildren())
		return
	end
	
	-- Otherwise, we're disabling a specific unit
	for _, frame in pairs(unitFrames) do
		if( frame.unitType == type ) then
			UnregisterUnitWatch(frame)

			frame:SetAttribute("unit", nil)
			frame:Hide()
		end
	end
end

function Units:CreateBar(parent)
	local frame = CreateFrame("StatusBar", nil, parent)
	frame:SetFrameLevel(FRAME_LEVEL_MAX)
	frame.parent = parent
	frame.background = frame:CreateTexture(nil, "BORDER")
	frame.background:SetHeight(1)
	frame.background:SetWidth(1)
	frame.background:SetAllPoints(frame)
	
	return frame
end

-- Handles events related to all units and not a specific one
local headerUpdated = {}

centralFrame = CreateFrame("Frame")
centralFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
centralFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
centralFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
centralFrame:RegisterEvent("PARTY_MEMBERS_CHANGED")
centralFrame:RegisterEvent("RAID_ROSTER_UPDATE")
centralFrame:SetScript("OnEvent", function(self, event, unit)
	if( event == "RAID_ROSTER_UPDATE" or event == "PARTY_MEMBERS_CHANGED" ) then
		if( not frameMoving ) then return end
		OnDragStop(frameMoving)
	
	elseif( event == "ZONE_CHANGED_NEW_AREA" ) then
		for _, frame in pairs(unitFrames) do
			if( frame:GetAttribute("unit") ) then
				frame:SetVisibility()
			end
		end
		
	elseif( event == "PLAYER_REGEN_ENABLED" ) then
		inCombat = nil
	
		for k in pairs(headerUpdated) do headerUpdated[k] = nil end
		
		for frame in pairs(queuedCombat) do
			queuedCombat[frame] = nil
		
		if( not frame.unit ) then
				OnAttributeChanged(frame, "unit", frame:GetAttribute("unit"))
			else
				SetupUnitFrame(frame)
			end
			
			-- When parties change in combat, the overall height/width of the secure header will change, we need to force a secure group update
			-- in order for all of the sizing information to be set correctly.
			if( frame.unitType ~= frame.unit and not headerUpdated[frame.unitType] ) then
				local header = unitFrames[frame.unitType]
				if( header and header:GetHeight() <= 0 and header:GetWidth() <= 0 ) then
					SecureGroupHeader_Update(header)
				end
				
				headerUpdated[frame.unitType] = true
			end
		end
	elseif( event == "PLAYER_REGEN_DISABLED" ) then
		inCombat = true
	end
end)