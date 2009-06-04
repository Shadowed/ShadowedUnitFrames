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
	
	-- Party and raid frames love to show/hide themselves, so we're going to block it from doing a full update if the GUID never changed
	if( self.unitType == "raid" or self.unitType == "party" ) then
		local guid = UnitGUID(self.unit)
		if( guid == self.guid ) then return end
		
		self.guid = guid
	end
	
	-- Force a full update
	self:FullUpdate()
end

local function OnHide(self)
	self:SetScript("OnEvent", nil)
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

function Units:GotVehicleData(frame)
	if( UnitIsConnected(frame.unit) or UnitHealthMax(frame.unit) > 0 ) then
		UnregisterEvent(frame, "UNIT_PET", Units)
		frame:FullUpdate()
	end
end

-- Vehicle status changed for the unit, we need to put it all together again, kind of like the humpty dumpty of the 21st sentry
function Units:VehicleEntered(frame, event, unit, skipUpdate)
	if( frame.unitOwner ~= unit ) then return end

	frame.inVehicle = true
	frame.unit = frame.vehicleUnit
	
	if( not skipUpdate ) then
		frame:FullUpdate()
	end
		
	if( not UnitIsConnected(frame.unit) or UnitHealthMax(frame.unit) == 0 ) then
		frame:RegisterUnitEvent("UNIT_PET", Units, "GotVehicleData")
	end
end

function Units:VehicleLeft(frame, event, unit)
	if( frame.unitOwner ~= unit ) then return end
	frame.inVehicle = false
	frame.unit = frame.unitOwner
	frame:FullUpdate()
end

function Units:CheckVehicleStatus(frame)
	-- Update vehicle status
	if( not frame.inVehicle and UnitHasVehicleUI(frame.unitOwner) ) then
		self:VehicleEntered(frame, nil, frame.unitOwner, true)
	elseif( frame.inVehicle and not UnitHasVehicleUI(frame.unitOwner) ) then
		frame.inVehicle = false
		frame.unit = frame.unitOwner
	end
end

-- Frame is now initialized with a unit
local function OnAttributeChanged(self, name, unit)
	if( name ~= "unit" or not unit or unit == self.unitOwner ) then return end
	-- I'd love if it this all worked in combat, but I don't really want to rewrite it 100% into secure templates
	if( inCombat ) then
		queuedCombat[self] = true
		return
	end
	
	self.unit = unit
	self.unitID = tonumber(string.match(unit, "([0-9]+)"))
	self.unitType = string.gsub(unit, "([0-9]+)", "")
	self.unitOwner = unit
	
	unitFrames[unit] = self
			
	-- Add to Clique
	ClickCastFrames = ClickCastFrames or {}
	ClickCastFrames[self] = true
	
	-- Pet changed, going from pet -> vehicle for one
	if( unit == "pet" or self.unitType == "partypet" ) then
		self:RegisterUnitEvent("UNIT_PET", self, "FullUpdate")
	-- Automatically do a full update on target change
	elseif( unit == "target" ) then
		self:RegisterNormalEvent("PLAYER_TARGET_CHANGED", self, "FullUpdate")
	-- Automatically do a full update on focus change
	elseif( unit == "focus" ) then
		self:RegisterNormalEvent("PLAYER_FOCUS_CHANGED", self, "FullUpdate")
	-- *target units are not real units, thus they do not receive events and must be polled for data
	elseif( string.match(unit, "%w+target") ) then
		self.timeElapsed = 0
		self:SetScript("OnUpdate", TargetUnitUpdate)
	-- When a player is force ressurected by releasing in naxx/tk/etc then they might freeze
	elseif( unit == "player" ) then
		self:RegisterNormalEvent("PLAYER_ALIVE", self, "FullUpdate")
	end

	-- You got to love programming without documentation, ~3 hours spent making this work with raids and such properly, turns out? It's a simple attribute
	-- and all you have to do is set it up so the unit variables are properly changed based on being in a vehicle... which is what will do now
	if( unit == "player" or self.unitType == "party" or self.unitType == "raid" ) then
		-- player -> pet, party -> partypet#, raid -> raidpet# (party#pet/raid#pet work too, the secure headers automatically translate it to *pet# thought.
		self.vehicleUnit = self.unitOwner == "player" and "pet" or self.unitType == "party" and "partypet" .. self.unitID or self.unitType == "raid" and "raidpet" .. self.unitID

		self:RegisterNormalEvent("UNIT_ENTERED_VEHICLE", Units, "VehicleEntered")
		self:RegisterNormalEvent("UNIT_EXITED_VEHICLE", Units, "VehicleLeft")
		self:RegisterUpdateFunc(Units, "CheckVehicleStatus")

		-- Check if they are in a vehicle
		Units:CheckVehicleStatus(self)
	end	

	-- Update module status
	self:SetVisibility()

	--[[
	-- Hide any pet that became a vehicle, we detect this by the player being untargetable but we have a pet out
	else
		local vehicleUnit = unit == "pet" and "player" or self.unitType == "partypet" and ShadowUF.partyUnits[self.unitID]
		RegisterStateDriver(self, "vehicleupdated", string.format("[target=%s, help][target=%s, exists] %s; none", vehicleUnit, unit, unit))
		vehicleMonitor:WrapScript(self, "OnAttributeChanged", [ [
			if( name ~= "state-vehicleupdated" ) then return end
			self:SetAttribute("unit", value ~= "none" and value or nil)
			print(value, self:GetAttribute("unit"))
		] ])

		-- Logged out in a vehicle
		if( not UnitCanAssist(vehicleUnit, "player") and UnitExists(unit) ) then
			self:SetAttribute("unit", nil)
		end
	end
	]]
end

function Units:LoadUnit(config, unit)
	-- Already be loaded, just enable
	if( unitFrames[unit] ) then
		unitFrames[unit]:SetAttribute("unit", unit)
		RegisterUnitWatch(unitFrames[unit])
		return
	end
	
	local frame = CreateFrame("Button", "SUFUnit" .. unit, UIParent, "SecureUnitButtonTemplate")
	self:CreateUnit(frame)
	frame:SetAttribute("unit", unit)

	unitFrames[unit] = frame
		
	-- Annd lets get this going
	RegisterUnitWatch(frame)
end

local function OnDragStart(self)
	if( ShadowUF.db.profile.locked or self.isMoving ) then return end
	self = unitFrames[self.unitType] or self
	
	self.isMoving = true
	self:StartMoving()

	frameMoving = self
	
	if( self.unitType == "raid" ) then
		centralFrame:RegisterEvent("RAID_ROSTER_UPDATE")
	elseif( self.unitType == "party" ) then
		centralFrame:RegisterEvent("PARTY_MEMBERS_CHANGED)
	end


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
	frame:SetAttribute("toggleForVehicle", true)
	-- allowVehicleTarget
	--[16:42] <+alestane> Shadowed: It says whether a unit defined as, for instance, "party1target" should be remapped to "partypet1target" when party1 is in a vehicle.
	frame.menu = Units.ShowMenu

	if( hookVisibility ) then
		frame:HookScript("OnShow", OnShow)
		frame:HookScript("OnHide", OnHide)
	else
		frame:SetScript("OnShow", OnShow)
		frame:SetScript("OnHide", OnHide)
	end
end

local function initUnit(self)
	self.ignoreAnchor = true
	Units:CreateUnit(self)
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
		for i=1, MAX_PARTY_MEMBERS do
			local frame = unitFrames[type .. i]
			if( frame ) then
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
	for _, frame in pairs(unitFrames) do
		if( frame:GetAttribute("unit") ) then
			frame:SetVisibility()
			frame:FullUpdate()
		end
	end
	
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
		frame:SetAttribute("framePoint", ShadowUF.Layout:GetPoint(ShadowUF.db.profile.positions[type].anchorPoint))
		frame:SetAttribute("frameRelative", ShadowUF.Layout:GetRelative(ShadowUF.db.profile.positions[type].anchorPoint))
		frame:SetAttribute("frameX", ShadowUF.db.profile.positions[type].x)
		frame:SetAttribute("frameY", ShadowUF.db.profile.positions[type].y)
	end
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
	headerFrame.initialConfigFunction = initUnit
	headerFrame.unitType = type
	headerFrame:SetMovable(true)
	headerFrame:RegisterForDrag("LeftButton")
	headerFrame:Show()

	unitFrames[type] = headerFrame
	ShadowUF.Layout:AnchorFrame(UIParent, headerFrame, ShadowUF.db.profile.positions[type])
	
	if( type == "party" and needPartyFrame ) then
		needPartyFrame = nil
		
		Units:LoadPartyChildUnit(ShadowUF.db.profile.units.partypet, headerFrame, "partypet")
		Units:LoadPartyChildUnit(ShadowUF.db.profile.units.partypet, headerFrame, "partytarget")
	end
end

function Units:LoadPartyChildUnit(config, parentHeader, type, unit)
	if( not parentHeader ) then
		needPartyFrame = true
		return
	elseif( unitFrames[unit] ) then
		self:SetFrameAttributes(unitFrames[unit], unitFrames[unit].unitType)
		RegisterUnitWatch(unitFrames[unit])
		return
	end
	
	local frame = CreateFrame("Button", "SUFUnit" .. unit, UIParent, "SecureUnitButtonTemplate,SecureHandlerShowHideTemplate")
	frame.ignoreAnchor = true

	self:SetFrameAttributes(frame, type)
	
	self:CreateUnit(frame, true)
	frame:SetFrameRef("partyHeader",  parentHeader)
	frame:SetAttribute("unit", unit)
	frame:SetAttribute("unitOwner", "party" .. (string.match(unit, "(%d+)")))
	frame:SetAttribute("_onshow", [[
		local children = table.new(self:GetFrameRef("partyHeader"):GetChildren())
		for _, child in pairs(children) do
			if( child:GetAttribute("unit") == self:GetAttribute("unitOwner") ) then
				self:SetParent(child)
				self:ClearAllPoints()
				self:SetPoint(self:GetAttribute("framePoint"), child, self:GetAttribute("frameRelative"), self:GetAttribute("frameX"), self:GetAttribute("frameY"))
			end
		end
	]])
	
	unitFrames[unit] = frame

	-- Annd lets get this going
	RegisterUnitWatch(frame)
end

function Units:InitializeFrame(config, type)
	if( loadedUnits[type] ) then return end
	loadedUnits[type] = true
	
	if( type == "party" ) then
		self:LoadGroupHeader(config, type)
	elseif( type == "raid" ) then
		self:LoadGroupHeader(config, type)
	elseif( type == "partypet" ) then
		for _, unit in pairs(ShadowUF.partyUnits) do
			self:LoadPartyChildUnit(config, SUFHeaderparty, type, unit .. "pet")
		end
	elseif( type == "partytarget" ) then
		for _, unit in pairs(ShadowUF.partyUnits) do
			self:LoadPartyChildUnit(config, SUFHeaderparty, type, unit .. "target")
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

--function Units:OnLayoutApplied(frame)
--	frame:FullUpdate()
--end

function Units.ShowMenu(frame)
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
centralFrame:SetScript("OnEvent", function(self, event, unit)
	if( event == "RAID_ROSTER_UPDATE" or event == "PARTY_MEMBERS_CHANGED" ) then
		if( not frameMoving ) then return end
		self:UnregisterEvent(event)

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
			OnAttributeChanged(frame, "unit", frame:GetAttribute("unit"))
			queuedCombat[frame] = nil
			
			-- When parties change in combat, the overall height/width of the secure header will change, we need to force a secure group update
			-- in order for all of the sizing information to be set correctly.
			if( frame.unitType ~= frame.unit and not headerUpdated[frame.unitType] ) then
				local header = unitFrames[frame.unitType]
				if( header and header:GetHeight() == 0 and header:GetWidth() == 0 ) then
					SecureGroupHeader_Update(header)
				end
				
				headerUpdated[frame.unitType] = true
			end
		end
	elseif( event == "PLAYER_REGEN_DISABLED" ) then
		inCombat = true
	end
end)