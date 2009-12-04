local Units = {unitFrames = {}, frameList = {}, loadedUnits = {}, unitEvents = {}}
Units.childUnits = {["partytarget"] = "party", ["partypet"] = "party", ["maintanktarget"] = "maintank", ["mainassisttarget"] = "mainassist", ["bosstarget"] = "boss", ["arenatarget"] = "arena", ["arenapet"] = "arena"}
Units.zoneUnits = {["arena"] = "arena", ["boss"] = "raid"}

local stateMonitor = CreateFrame("Frame", nil, nil, "SecureHandlerBaseTemplate")
local playerClass = select(2, UnitClass("player"))
local unitFrames, frameList, unitEvents, childUnits, queuedCombat = Units.unitFrames, Units.frameList, Units.unitEvents, Units.childUnits, {}
local combatDebug = ""
local _G = getfenv(0)

ShadowUF.Units = Units
ShadowUF:RegisterModule(Units, "units")

-- DEBUG CODE
local function dumpDebugData()
	local self = ShadowUF
	local text = "---- Child dump\n\n"
	local parents = {}
	
	for frame in pairs(frameList) do
		if( frame.parent ) then
			local point, anchorTo = frame:GetPoint()
			local pointParent = anchorTo and (anchorTo:GetName() or "anonymous") or "no anchor set"
			
			local parent = frame:GetParent() and (frame:GetParent():GetName() or "anonymous") or "no parent"
			text = text .. string.format("Frame %s, unit parent %s, unit %s, unit owner %s, guid %s, actual guid %s, shown %s, visible %s, format %s, parentUnit %s, point %s, pointParent %s, parent %s, attrib exists %s, attrib disableSwap %s, attrib isVehicle %s, status %s.\n\n", tostring(frame:GetName()), tostring(frame:GetAttribute("parentUnit")), tostring(frame.unit), tostring(frame.unitOwner), tostring(frame.unitGUID), tostring(UnitGUID(frame.unit)), tostring(frame:IsShown()), tostring(frame:IsVisible()), tostring(frame:GetAttribute("unitFormat")), tostring(frame:GetAttribute("parentUnit")), tostring(point), tostring(pointParent), tostring(parent), tostring(frame:GetAttribute("state-unitexists")), tostring(frame:GetAttribute("disableVehicleSwap")), tostring(frame:GetAttribute("unitIsVehicle")), tostring(frame:GetAttribute("visibilityStatus")))
			
			parents[frame.parent] = true
		end
	end
	
	text = text .. "\n---- Parent dump\n\n"
	for frame in pairs(parents) do
		local list
		for i=1, frame.totalChildren do
			local child = frame:GetAttribute("frameRef-childframe" .. i)
			if( list ) then
				list = list .. ", " .. (child and child:GetName() or "bad id" .. i)
			else
				list = (child and child:GetName() or "bad id" .. i)
			end
		end
		
		text = text .. string.format("Frame %s, wrapped? %s, last unit %s, unit %s, unit owner %s, guid %s, actual guid %s (%s), shown %s, visible %s, total children %s, children %s\n\n", tostring(frame:GetName()), tostring(frame.isWrapped), tostring(frame:GetAttribute("lastUnit")), tostring(frame.unit), tostring(frame.unitOwner), tostring(frame.unitGUID), tostring(UnitGUID(frame.unit)), tostring(UnitName(frame.unit)), tostring(frame:IsShown()), tostring(frame:IsVisible()), tostring(frame.totalChildren), list or "none")
	end
	
	text = text .. "\n---- Direct party dump\n\n"
	for i=1, 4 do
		local frame = _G["SUFHeaderpartyUnitButton" .. i]
		if( frame and frame.unit ) then
			local list
			if( frame.totalChildren ) then
				for i=1, frame.totalChildren do
					local child = frame:GetAttribute("frameRef-childframe" .. i)
					if( list ) then
						list = list .. ", " .. (child and child:GetName() or "bad id" .. i)
					else
						list = (child and child:GetName() or "bad id" .. i)
					end
				end
			end
			
			text = text .. string.format("Frame %s, wrapped? %s (%s), last unit %s, unit %s, unit owner %s, guid %s, actual guid %s (%s), shown %s, visible %s, total children %s, children %s\n\n", tostring(frame:GetName()), tostring(frame.isWrapped), tostring(frame.loadStatus), tostring(frame:GetAttribute("lastUnit")), tostring(frame.unit), tostring(frame.unitOwner), tostring(frame.unitGUID), tostring(UnitGUID(frame.unit)), tostring(UnitName(frame.unit)), tostring(frame:IsShown()), tostring(frame:IsVisible()), tostring(frame.totalChildren), list or "none")
		end
	end
	
	text = text .. "\n---- Combat queue dump\n\n"
	text = text .. tostring(combatDebug) .. "\n"
	for type, data in pairs(queuedCombat) do
		text = text .. string.format("Parent %s, type %s, id %s\n", parent and parent:GetName() or parent or "nil", type or "nil", id or "nil")
	end
	
	
	text = text .. "\n---- Party setting dump\n\n"
	for key, value in pairs(self.db.profile.units.party) do
		if( type(value) ~= "table" ) then
			text = text .. string.format("%s = [%s]\n", key, tostring(value))
		end
	end

	text = text .. "\n---- Main tank setting dump\n\n"
	for key, value in pairs(self.db.profile.units.maintank) do
		if( type(value) ~= "table" ) then
			text = text .. string.format("%s = [%s]\n", key, tostring(value))
		end
	end

	text = text .. "\n---- Main assist setting dump\n\n"
	for key, value in pairs(self.db.profile.units.mainassist) do
		if( type(value) ~= "table" ) then
			text = text .. string.format("%s = [%s]\n", key, tostring(value))
		end
	end
	
	
	self.guiFrame.editBox:SetText(text)
end

function ShadowUF:Debug()
	local self = ShadowUF
	if( self.guiFrame ) then
		self.guiFrame:Show()
		return
	end
	
	local backdrop = {
		bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
		edgeFile = "Interface\\ChatFrame\\ChatFrameBackground",
		tile = true,
		edgeSize = 1,
		tileSize = 5,
		insets = {left = 1, right = 1, top = 1, bottom = 1}
	}

	self.guiFrame = CreateFrame("Frame", nil, UIParent)
	self.guiFrame:SetWidth(550)
	self.guiFrame:SetHeight(275)
	self.guiFrame:SetBackdrop(backdrop)
	self.guiFrame:SetBackdropColor(0.0, 0.0, 0.0, 1.0)
	self.guiFrame:SetBackdropBorderColor(0.65, 0.65, 0.65, 1.0)
	self.guiFrame:SetMovable(true)
	self.guiFrame:EnableMouse(true)
	self.guiFrame:SetFrameStrata("HIGH")
	self.guiFrame:Hide()

	-- Fix edit box size
	self.guiFrame:SetScript("OnShow", function(self)
		self.child:SetHeight(self.scroll:GetHeight())
		self.child:SetWidth(self.scroll:GetWidth())
		self.editBox:SetWidth(self.scroll:GetWidth())
		
		dumpDebugData()
	end)
	
	-- Select all text
	self.guiFrame.copy = CreateFrame("Button", nil, self.guiFrame, "UIPanelButtonGrayTemplate")
	self.guiFrame.copy:SetWidth(70)
	self.guiFrame.copy:SetHeight(18)
	self.guiFrame.copy:SetText("Select all")
	self.guiFrame.copy:SetPoint("TOPLEFT", self.guiFrame, "TOPLEFT", 1, -1)
	self.guiFrame.copy:SetScript("OnClick", function(self)
		self.editBox:SetFocus()
		self.editBox:SetCursorPosition(0)
		self.editBox:HighlightText(0)
	end)
	
	-- Title info
	self.guiFrame.title = self.guiFrame:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
	self.guiFrame.title:SetPoint("TOPLEFT", self.guiFrame, "TOPLEFT", 75, -4)
	
	-- Close button (Shocking!)
	local button = CreateFrame("Button", nil, self.guiFrame, "UIPanelCloseButton")
	button:SetPoint("TOPRIGHT", self.guiFrame, "TOPRIGHT", 6, 6)
	button:SetScript("OnClick", function()
		HideUIPanel(self.guiFrame)
	end)
	
	self.guiFrame.closeButton = button
	
	-- Create the container frame for the scroll box
	local container = CreateFrame("Frame", nil, self.guiFrame)
	container:SetHeight(265)
	container:SetWidth(1)
	container:ClearAllPoints()
	container:SetPoint("BOTTOMLEFT", self.guiFrame, 0, -9)
	container:SetPoint("BOTTOMRIGHT", self.guiFrame, 4, 0)
	
	self.guiFrame.container = container
	
	-- Scroll frame
	local scroll = CreateFrame("ScrollFrame", "SUFFrameScroll", container, "UIPanelScrollFrameTemplate")
	scroll:SetPoint("TOPLEFT", 5, 0)
	scroll:SetPoint("BOTTOMRIGHT", -28, 10)
	
	self.guiFrame.scroll = scroll
	
	local child = CreateFrame("Frame", nil, scroll)
	scroll:SetScrollChild(child)
	child:SetHeight(2)
	child:SetWidth(2)
	
	self.guiFrame.child = child

	-- Create the actual edit box
	local editBox = CreateFrame("EditBox", nil, child)
	editBox:SetPoint("TOPLEFT")
	editBox:SetHeight(50)
	editBox:SetWidth(50)

	editBox:SetMultiLine(true)
	editBox:SetAutoFocus(false)
	editBox:EnableMouse(true)
	editBox:SetFontObject(GameFontHighlightSmall)
	editBox:SetTextInsets(0, 0, 0, 0)
	editBox:SetScript("OnEscapePressed", editBox.ClearFocus)
	scroll:SetScript("OnMouseUp", function() editBox:SetFocus() end)	

	self.guiFrame.editBox = editBox
	self.guiFrame.copy.editBox = editBox

	self.guiFrame:SetPoint("CENTER", UIParent, "CENTER")
	self.guiFrame:Show()
end

-- DEBUG CODE
	
-- Frame shown, do a full update
local function FullUpdate(self)
	for i=1, #(self.fullUpdates), 2 do
		local handler = self.fullUpdates[i]
		handler[self.fullUpdates[i + 1]](handler, self)
	end
end

-- Register an event that should always call the frame
local function RegisterNormalEvent(self, event, handler, func)
	-- Make sure the handler/func exists
	if( not handler[func] ) then
		error(string.format("Invalid handler/function passed for %s on event %s, the function %s does not exist.", self:GetName() or tostring(self), tostring(event), tostring(func)), 3)
		return
	end

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
	if( self.registeredEvents[event] ) then
		self.registeredEvents[event][handler] = nil
		
		local hasHandler
		for handler in pairs(self.registeredEvents[event]) do
			hasHandler = true
			break
		end
		
		if( not hasHandler ) then
			self:UnregisterEvent(event)
		end
	end
end

-- Register an event thats only called if it's for the actual unit
local function RegisterUnitEvent(self, event, handler, func)
	unitEvents[event] = true
	RegisterNormalEvent(self, event, handler, func)
end

-- Register a function to be called in an OnUpdate if it's an invalid unit (targettarget/etc)
local function RegisterUpdateFunc(self, handler, func)
	if( not handler[func] ) then
		error(string.format("Invalid handler/function passed to RegisterUpdateFunc for %s, the function %s does not exist.", self:GetName() or tostring(self), event, func), 3)
		return
	end

	for i=1, #(self.fullUpdates), 2 do
		local data = self.fullUpdates[i]
		if( data == handler and self.fullUpdates[i + 1] == func ) then
			return
		end
	end
	
	table.insert(self.fullUpdates, handler)
	table.insert(self.fullUpdates, func)
end

local function UnregisterUpdateFunc(self, handler, func)
	for i=#(self.fullUpdates), 1, -1 do
		if( self.fullUpdates[i] == handler and self.fullUpdates[i + 1] == func ) then
			table.remove(self.fullUpdates, i + 1)
			table.remove(self.fullUpdates, i)
		end
	end
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
		
		local hasRegister
		for handler in pairs(list) do
			hasRegister = true
			break
		end
		
		if( not hasRegister ) then
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
	Units:CheckUnitStatus(self)
end

local function OnHide(self)
	self:SetScript("OnEvent", nil)
	
	-- If it's a volatile such as target or focus, next time it's shown it has to do an update
	if( self.isUnitVolatile ) then
		self.unitGUID = nil
	end
end

-- *target units do not give events, polling is necessary here
local function TargetUnitUpdate(self, elapsed)
	self.timeElapsed = self.timeElapsed + elapsed
	
	if( self.timeElapsed >= 0.50 ) then
		self.timeElapsed = self.timeElapsed - 0.50
		
		-- Have to make sure the unit exists or else the frame will flash offline for a second until it hides
		if( UnitExists(self.unit) ) then
			self:FullUpdate()
		end
	end
end

-- Deal with enabling modules inside a zone
local function SetVisibility(self)
	local layoutUpdate
	local instanceType = select(2, IsInInstance())

	-- Selectively disable modules
	for _, module in pairs(ShadowUF.moduleOrder) do
		if( module.OnEnable and module.OnDisable and ShadowUF.db.profile.units[self.unitType][module.moduleKey] ) then
			local key = module.moduleKey
			local enabled = ShadowUF.db.profile.units[self.unitType][key].enabled
			
			-- These modules have mini-modules, the entire module should be enabled if at least one is enabled, and disabled if all are disabled
			if( key == "auras" or key == "indicators" or key == "highlight" ) then
				enabled = nil
				for _, option in pairs(ShadowUF.db.profile.units[self.unitType][key]) do
					if( type(option) == "table" and option.enabled or option == true ) then
						enabled = true
						break
					end
				end
			end
			
			-- In an actual zone, check to see if we have an override for the zone
			if( instanceType ~= "none" ) then
				if( ShadowUF.db.profile.visibility[instanceType][self.unitType .. key] == false ) then
					enabled = nil
				elseif( ShadowUF.db.profile.visibility[instanceType][self.unitType .. key] == true ) then
					enabled = true
				end
			end
			
			-- Force disable modules for people who aren't the class for it
			if( module.moduleClass and module.moduleClass ~= playerClass ) then
				enabled = nil
			end
						
			-- Module isn't enabled all the time, only in this zone so we need to force it to be enabled
			if( not self.visibility[key] and enabled ) then
				module:OnEnable(self)
				layoutUpdate = true
			elseif( self.visibility[key] and not enabled ) then
				module:OnDisable(self)
				layoutUpdate = true
			end
			
			self.visibility[key] = enabled or nil
		end
	end
	
	-- We had a module update, force a full layout update of this frame
	if( layoutUpdate ) then
		ShadowUF.Layout:Load(self)
	end
end

-- Vehicles do not always return their data right away, a pure OnUpdate check seems to be the most accurate unfortunately
local function checkVehicleData(self, elapsed)
	self.timeElapsed = self.timeElapsed + elapsed
	if( self.timeElapsed >= 0.50 ) then
		self.timeElapsed = 0
		self.dataAttempts = self.dataAttempts + 1
		
		-- Took too long to get vehicle data, or they are no longer in a vehicle
		if( self.dataAttempts >= 6 or not UnitHasVehicleUI(self.unitOwner) ) then
			self.timeElapsed = nil
			self.dataAttempts = nil
			self:SetScript("OnUpdate", nil)

			self.inVehicle = false
			self.unit = self.unitOwner
			self:FullUpdate()
			
		-- Got data, stop checking and do a full frame update
		elseif( UnitIsConnected(self.unit) or UnitHealthMax(self.unit) > 0 ) then
			self.timeElapsed = nil
			self.dataAttempts = nil
			self:SetScript("OnUpdate", nil)
			
			self.unitGUID = UnitGUID(self.unit)
			self:FullUpdate()
		end
	end
end 

-- Check if a unit entered a vehicle
function Units:CheckVehicleStatus(frame, event, unit)
	if( event and frame.unitOwner ~= unit ) then return end
		
	-- Not in a vehicle yet, and they entered one that has a UI or they were in a vehicle but the GUID changed (vehicle -> vehicle)
	if( ( not frame.inVehicle or frame.unitGUID ~= UnitGUID(frame.vehicleUnit) ) and UnitHasVehicleUI(frame.unitOwner) and not ShadowUF.db.profile.units[frame.unitType].disableVehicle ) then
		frame.inVehicle = true
		frame.unit = frame.vehicleUnit

		if( not UnitIsConnected(frame.unit) or UnitHealthMax(frame.unit) == 0 ) then
			frame.timeElapsed = 0
			frame.dataAttempts = 0
			frame:SetScript("OnUpdate", checkVehicleData)
		else
			frame.unitGUID = UnitGUID(frame.unit)
			frame:FullUpdate()
		end
		
		-- Keep track of what the players current unit is supposed to be, so things like auras can figure it out
		if( frame.unitOwner == "player" ) then
			ShadowUF.playerUnit = frame.unit
		end
				
	-- Was in a vehicle, no longer has a UI
	elseif( frame.inVehicle and ( not UnitHasVehicleUI(frame.unitOwner) or ShadowUF.db.profile.units[frame.unitType].disableVehicle ) ) then
		frame.inVehicle = false
		frame.unit = frame.unitOwner
		frame.unitGUID = UnitGUID(frame.unit)
		frame:FullUpdate()

		if( frame.unitOwner == "player" ) then
			ShadowUF.playerUnit = frame.unitOwner
		end
	end
end

-- Handles checking for GUID changes for doing a full update, this fixes frames sometimes showing the wrong unit when they change
function Units:CheckUnitStatus(frame)
	local guid = frame.unit and UnitGUID(frame.unit)
	if( guid ~= frame.unitGUID ) then
		frame.unitGUID = guid
		
		if( guid ) then
			frame:FullUpdate()
		end
	end
end


-- The argument from UNIT_PET is the pets owner, so the player summoning a new pet gets "player", party1 summoning a new pet gets "party1" and so on
function Units:CheckPetUnitUpdated(frame, event, unit)
	if( unit == frame.unitRealOwner and UnitExists(frame.unit) ) then
		frame.unitGUID = UnitGUID(frame.unit)
		frame:FullUpdate()
	end
end

function Units:CheckGroupedUnitStatus(frame)
	-- When raid1, raid2, raid3 are in a group with each other and raid1 or raid2 are in a vehicle and get kicked
	-- OnAttributeChanged won't do anything because the frame is already setup, however, the active unit is non-existant
	-- while the primary unit is. So if we see they're in a vehicle with this case, we force the full update to get the vehicle change
	if( frame.inVehicle and not UnitExists(frame.unit) and UnitExists(frame.unitOwner) ) then
		frame.inVehicle = false
		frame.unit = frame.unitOwner
		frame.unitGUID = guid
		frame:FullUpdate()
	else
		frame.unitGUID = UnitGUID(frame.unit)
		frame:FullUpdate()
	end
end

local function ShowMenu(self)
	local menuFrame
	if( self.unit == "player" ) then
		menuFrame = PlayerFrameDropDown
	elseif( self.unitRealType == "party" ) then
		menuFrame = getglobal("PartyMemberFrame" .. self.unitID .. "DropDown")
	elseif( self.unitRealType == "raid" ) then
		menuFrame = FriendsDropDown
		menuFrame.displayMode = "MENU"
		menuFrame.initialize = RaidFrameDropDown_Initialize
		menuFrame.userData = self.unitID
	else
		return
	end	
	
	self.dropdownMenu = menuFrame
	
	HideDropDownMenu(1)
	menuFrame.unit = self.unitOwner
	menuFrame.name = UnitName(self.unitOwner)
	menuFrame.id = self.unitID
	ToggleDropDownMenu(1, nil, menuFrame, "cursor")
end

-- More fun with sorting, due to sorting magic we have to check if we want to create stuff when the frame changes of partys too
local function createChildUnits(self)
	self.loadStatus = "createChildUnits"
	for child, parentUnit in pairs(childUnits) do
		if( parentUnit == self.unitType and ShadowUF.db.profile.units[child].enabled ) then
			self.loadStatus = "createChildUnits - looped"
			Units:LoadChildUnit(self, child, self.unitID)
		end
	end
end


-- Attribute set, something changed
-- unit = Active unitid
-- unitID = Just the number from the unitid
-- unitType = Unitid minus numbers in it, used for configuration
-- unitRealType = The actual unit type, if party is shown in raid this will be "party" while unitType is still "raid"
-- unitOwner = Always the units owner even when unit changes due to vehicles
-- vehicleUnit = Unit to use when the unitOwner is in a vehicle
local function OnAttributeChanged(self, name, unit)
	if( name ~= "unit" or not unit or unit == self.unitOwner ) then return end
	-- Nullify the previous entry if it had one
	if( self.unit and unitFrames[self.unit] == self ) then unitFrames[self.unit] = nil end
	
	-- Setup identification data
	self.unit = unit
	self.unitID = tonumber(string.match(unit, "([0-9]+)"))
	self.unitRealType = string.gsub(unit, "([0-9]+)", "")
	self.unitType = self.unitType or self.unitRealType
	self.unitOwner = unit
	self.vehicleUnit = self.unitOwner == "player" and "vehicle" or self.unitRealType == "party" and "partypet" .. self.unitID or self.unitRealType == "raid" and "raidpet" .. self.unitID or nil
	self.inVehicle = nil
	
	-- Split everything into two maps, this is the simple parentUnit -> frame map
	-- This is for things like finding a party parent for party target/pet, the main map for doing full updates is
	-- an indexed frame that is updated once and won't have unit conflicts.
	if( self.unitRealType == self.unitType ) then
		unitFrames[unit] = self
	end
	
	frameList[self] = true

	-- Create child frames
	createChildUnits(self)

	-- Unit already exists but unitid changed, update the info we got on them
	-- Don't need to recheck the unitType and force a full update, because a raid frame can never become
	-- a party frame, or a player frame and so on
	if( self.unitInitialized ) then
		self:FullUpdate()
		return
	end
	
	self.unitInitialized = true

	-- Add to Clique
	ClickCastFrames = ClickCastFrames or {}
	ClickCastFrames[self] = true
	
	-- Handles switching the internal unit variable to that of their vehicle
	if( self.unit == "player" or self.unitRealType == "party" or self.unitRealType == "raid" ) then
		self:RegisterNormalEvent("UNIT_ENTERED_VEHICLE", Units, "CheckVehicleStatus")
		self:RegisterNormalEvent("UNIT_EXITED_VEHICLE", Units, "CheckVehicleStatus")
		self:RegisterUpdateFunc(Units, "CheckVehicleStatus")
	end	
	
	-- Pet changed, going from pet -> vehicle for one
	if( self.unit == "pet" or self.unitType == "partypet" ) then
		self.unitRealOwner = self.unit == "pet" and "player" or ShadowUF.partyUnits[self.unitID]
		self:RegisterNormalEvent("UNIT_PET", Units, "CheckPetUnitUpdated")
		
		if( self.unit == "pet" ) then
			self.dropdownMenu = PetFrameDropDown
			self:SetAttribute("_menu", PetFrame.menu)
			self:SetAttribute("disableVehicleSwap", ShadowUF.db.profile.units.player.disableVehicle)
		else
			self:SetAttribute("disableVehicleSwap", ShadowUF.db.profile.units.party.disableVehicle)
		end
	
		-- Logged out in a vehicle
		if( UnitHasVehicleUI(self.unitRealOwner) ) then
			self:SetAttribute("unitIsVehicle", true)
		end
		
		-- Hide any pet that became a vehicle, we detect this by the owner being untargetable but they have a pet out
		stateMonitor:WrapScript(self, "OnAttributeChanged", [[
			if( name == "state-vehicleupdated" ) then
				self:SetAttribute("unitIsVehicle", value == "vehicle" and true or false)
			elseif( name == "disablevehicleswap" or name == "state-unitexists" or name == "unitisvehicle" ) then
				-- Unit does not exist, OR unit is a vehicle and vehicle swap is not disabled, hide frame
				if( not self:GetAttribute("state-unitexists") or ( self:GetAttribute("unitIsVehicle") and not self:GetAttribute("disableVehicleSwap") ) ) then
					self:Hide()
				-- Unit exists, show it
				else
					self:Show()
				end
			end
		]])
		RegisterStateDriver(self, "vehicleupdated", string.format("[target=%s, nohelp, noharm] vehicle; pet", self.unitRealOwner, self.unit))

	-- Automatically do a full update on target change
	elseif( self.unit == "target" ) then
		self.isUnitVolatile = true
		self.dropdownMenu = TargetFrameDropDown
		self:SetAttribute("_menu", TargetFrame.menu)
		self:RegisterNormalEvent("PLAYER_TARGET_CHANGED", Units, "CheckUnitStatus")

	-- Automatically do a full update on focus change
	elseif( self.unit == "focus" ) then
		self.isUnitVolatile = true
		self.dropdownMenu = FocusFrameDropDown
		self:SetAttribute("_menu", FocusFrame.menu)
		self:RegisterNormalEvent("PLAYER_FOCUS_CHANGED", Units, "CheckUnitStatus")
				
	elseif( self.unit == "player" ) then
		self:SetAttribute("toggleForVehicle", true)
		
		-- Force a full update when the player is alive to prevent freezes when releasing in a zone that forces a ressurect (naxx/tk/etc)
		self:RegisterNormalEvent("PLAYER_ALIVE", self, "FullUpdate")
	
	-- Check for a unit guid to do a full update
	elseif( self.unitRealType == "raid" ) then
		self:RegisterNormalEvent("RAID_ROSTER_UPDATE", Units, "CheckGroupedUnitStatus")
		self:RegisterUnitEvent("UNIT_NAME_UPDATE", Units, "CheckUnitStatus")
		
	-- Party members need to watch for changes
	elseif( self.unitRealType == "party" ) then
		self:RegisterNormalEvent("PARTY_MEMBERS_CHANGED", Units, "CheckGroupedUnitStatus")
		self:RegisterUnitEvent("UNIT_NAME_UPDATE", Units, "CheckUnitStatus")
	
	-- *target units are not real units, thus they do not receive events and must be polled for data
	elseif( string.match(self.unit, "%w+target") ) then
		self.timeElapsed = 0
		self:SetScript("OnUpdate", TargetUnitUpdate)
		
		-- Speeds up updating units when their owner changes target, if party1 changes target then party1target is force updated, if target changes target
		-- then targettarget and targettargettarget are also force updated
		if( self.unitRealType == "partytarget" ) then
			self.unitRealOwner = ShadowUF.partyUnits[self.unitID]
		elseif( self.unitRealType == "raid" ) then
			self.unitRealOwner = ShadowUF.raidUnits[self.unitID]
		elseif( self.unitRealType == "arenatarget" ) then
			self.unitRealOwner = ShadowUF.arenaUnits[self.unitID]
		elseif( self.unit == "focustarget" ) then
			self.unitRealOwner = "focus"
			self:RegisterNormalEvent("PLAYER_FOCUS_CHANGED", Units, "CheckUnitStatus")
		elseif( self.unit == "targettarget" or self.unit == "targettargettarget" ) then
			self.unitRealOwner = "target"
			self:RegisterNormalEvent("PLAYER_TARGET_CHANGED", Units, "CheckUnitStatus")
		end

		self:RegisterNormalEvent("UNIT_TARGET", Units, "CheckPetUnitUpdated")
	end
	
	-- No secure menu set, default to tainted
	if( not self:GetAttribute("_menu") ) then
		self.menu = ShowMenu
	end
			
	-- Update module status
	self:SetVisibility()
	
	-- Check for any unit changes
	Units:CheckUnitStatus(self)
end

-- Header unit initialized
local function initializeUnit(self)
	local unitType = self:GetParent().unitType
	local config = ShadowUF.db.profile.units[unitType]

	self.ignoreAnchor = true
	self.unitType = unitType
	self:SetAttribute("initial-height", config.height)
	self:SetAttribute("initial-width", config.width)
	self:SetAttribute("initial-scale", config.scale)
	self:SetAttribute("toggleForVehicle", true)
	
	Units:CreateUnit(self)
end

-- Show tooltip
local function OnEnter(self)
	if( not ShadowUF.db.profile.tooltipCombat or not InCombatLockdown() ) then
		UnitFrame_OnEnter(self)
	end
end

-- Reset the fact that we clamped the dropdown to the screen to be safe
DropDownList1:HookScript("OnHide", function(self)
	self:SetClampedToScreen(false)
end)

-- Reposition the dropdown
local function PostClick(self)
	if( UIDROPDOWNMENU_OPEN_MENU == self.dropdownMenu and DropDownList1:IsShown() )	 then
		DropDownList1:ClearAllPoints()
		DropDownList1:SetPoint("TOPLEFT", self, "BOTTOMLEFT", 0, 0)
		DropDownList1:SetClampedToScreen(true)
	end
end

-- Create the generic things that we want in every secure frame regardless if it's a button or a header
function Units:CreateUnit(...)
	local frame = select("#", ...) > 1 and CreateFrame(...) or select(1, ...)
	frame.fullUpdates = {}
	frame.registeredEvents = {}
	frame.visibility = {}
	frame.RegisterNormalEvent = RegisterNormalEvent
	frame.RegisterUnitEvent = RegisterUnitEvent
	frame.RegisterUpdateFunc = RegisterUpdateFunc
	frame.UnregisterAll = UnregisterAll
	frame.UnregisterSingleEvent = UnregisterEvent
	frame.UnregisterUpdateFunc = UnregisterUpdateFunc
	frame.FullUpdate = FullUpdate
	frame.SetVisibility = SetVisibility
	frame.topFrameLevel = 5
	
	-- Ensures that text is the absolute highest thing there is
	frame.highFrame = CreateFrame("Frame", nil, frame)
	frame.highFrame:SetFrameLevel(frame.topFrameLevel + 1)
	frame.highFrame:SetAllPoints(frame)
	
	frame:SetScript("OnAttributeChanged", OnAttributeChanged)
	frame:SetScript("OnEvent", OnEvent)
	frame:SetScript("OnEnter", OnEnter)
	frame:SetScript("OnLeave", UnitFrame_OnLeave)
	frame:SetScript("OnShow", OnShow)
	frame:SetScript("OnHide", OnHide)
	frame:SetScript("PostClick", PostClick)

	frame:RegisterForClicks("AnyUp")	
	frame:SetAttribute("*type1", "target")
	frame:SetAttribute("*type2", "menu")
	
	return frame
end

-- Update the main header
function Units:ReloadHeader(type)
	local frame = unitFrames[type]
	if( frame ) then
		self:SetHeaderAttributes(frame, type)

		ShadowUF.Layout:AnchorFrame(UIParent, frame, ShadowUF.db.profile.positions[type])
		ShadowUF:FireModuleEvent("OnLayoutReload", type)
	end
end

function Units:PositionHeaderChildren(frame)
    local point = frame:GetAttribute("point") or "TOP"
    local relativePoint = ShadowUF.Layout:GetRelativeAnchor(point)
	
	if( #(frame.children) == 0 ) then return end

    local xMod, yMod = math.abs(frame:GetAttribute("xMod")), math.abs(frame:GetAttribute("yMod"))
    local x = frame:GetAttribute("xOffset") or 0
    local y = frame:GetAttribute("yOffset") or 0
	
	for id, child in pairs(frame.children) do
		if( id > 1 ) then
			frame.children[id]:ClearAllPoints()
			frame.children[id]:SetPoint(point, frame.children[id - 1], relativePoint, xMod * x, yMod * y)
		else
			frame.children[id]:ClearAllPoints()
			frame.children[id]:SetPoint(point, frame, point, 0, 0)
		end
	end
end

function Units:SetHeaderAttributes(frame, type)
	local config = ShadowUF.db.profile.units[type]
	if( not config ) then return end
	
	local xMod = config.attribPoint == "LEFT" and 1 or config.attribPoint == "RIGHT" and -1 or 0
	local yMod = config.attribPoint == "TOP" and -1 or config.attribPoint == "BOTTOM" and 1 or 0
	
	frame:SetAttribute("point", config.attribPoint)
	frame:SetAttribute("sortMethod", config.sortMethod)
	frame:SetAttribute("sortDir", config.sortOrder)
	
	frame:SetAttribute("xOffset", config.offset * xMod)
	frame:SetAttribute("yOffset", config.offset * yMod)
	frame:SetAttribute("xMod", xMod)
	frame:SetAttribute("yMod", yMod)
				
	if( type == "raid" or type == "mainassist" or type == "maintank" ) then
		local filter
		if( config.filters ) then
			for id, enabled in pairs(config.filters) do
				if( enabled ) then
					if( filter ) then
						filter = filter .. "," .. id
					else
						filter = id
					end
				end
			end
		else
			filter = config.groupFilter
		end
		
		frame:SetAttribute("showRaid", true)
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
	
	-- Need to position the fake units
	elseif( type == "boss" or type == "arena" ) then
		frame:SetWidth(config.width)
		self:PositionHeaderChildren(frame)
	
	-- Update party frames to not show anyone if they should be in raids
	elseif( type == "party" ) then
		frame:SetAttribute("showParty", ( not ShadowUF.db.profile.units.raid.showParty or not ShadowUF.db.profile.units.raid.enabled ) and true or false)
		frame:SetAttribute("showPlayer", config.showPlayer)
	end

	-- Update the raid frames to if they should be showing raid or party
	if( type == "party" or type == "raid" ) then
		if( unitFrames.raid and unitFrames.party ) then
			unitFrames.raid:SetAttribute("showParty", not unitFrames.party:GetAttribute("showParty"))
			unitFrames.raid:SetAttribute("showPlayer", unitFrames.party:GetAttribute("showPlayer"))
		end
		
		-- Need to update our flags on the state monitor so it knows what to do
		stateMonitor:SetAttribute("hideSemiRaid", ShadowUF.db.profile.units.party.hideSemiRaid)
		stateMonitor:SetAttribute("hideAnyRaid", ShadowUF.db.profile.units.party.hideAnyRaid)
	end
end

-- Load a single unit such as player, target, pet, etc
function Units:LoadUnit(config, unit)
	-- Already be loaded, just enable
	if( unitFrames[unit] ) then
		RegisterUnitWatch(unitFrames[unit], unit == "pet")
		return
	end
	
	local frame = self:CreateUnit("Button", "SUFUnit" .. unit, UIParent, "SecureUnitButtonTemplate")
	frame:SetAttribute("unit", unit)
		
	-- Annd lets get this going
	RegisterUnitWatch(frame, unit == "pet")
end

-- Load a header unit, party or raid
function Units:LoadGroupHeader(config, type)
	if( unitFrames[type] ) then
		unitFrames[type]:Show()
		
		if( type == "party" ) then
			stateMonitor:SetAttribute("partyDisabled", nil)
		end
		return
	end
	
	local headerFrame = CreateFrame("Frame", "SUFHeader" .. type, UIParent, "SecureGroupHeaderTemplate")
	unitFrames[type] = headerFrame

	self:SetHeaderAttributes(headerFrame, type)
	
	if( type == "party" or type == "maintank" or type == "mainassist" ) then
		headerFrame:SetAttribute("template", "SecureUnitButtonTemplate,SecureHandlerBaseTemplate")
	else
		headerFrame:SetAttribute("template", "SecureUnitButtonTemplate")
	end
	
	headerFrame:SetAttribute("initial-unitWatch", true)
	headerFrame.initialConfigFunction = initializeUnit
	headerFrame.isHeaderFrame = true
	headerFrame.unitType = type
	headerFrame:UnregisterEvent("UNIT_NAME_UPDATE")
	
	ShadowUF.Layout:AnchorFrame(UIParent, headerFrame, ShadowUF.db.profile.positions[type])
	
	-- We have to do party hiding based off raid as a state driver so that we can smoothly hide the party frames based off of combat and such
	-- technically this isn't the cleanest solution because party frames will still have unit watches active
	-- but this isn't as big of a deal, because SUF automatically will unregister the OnEvent for party frames while hidden
	if( type == "party" ) then
		headerFrame.childContainer = CreateFrame("Frame", nil, headerFrame, "SecureHandlerBaseTemplate")
		stateMonitor:SetFrameRef("partyHeader", headerFrame)
		stateMonitor:WrapScript(stateMonitor, "OnAttributeChanged", [[
			if( name ~= "state-raidmonitor" and name ~= "partydisabled" and name ~= "hideanyraid" and name ~= "hidesemiraid" ) then return end
			if( self:GetAttribute("partyDisabled") ) then return end
			
			if( self:GetAttribute("hideAnyRaid") and ( self:GetAttribute("state-raidmonitor") == "raid1" or self:GetAttribute("state-raidmonitor") == "raid6" ) ) then
				self:GetFrameRef("partyHeader"):Hide()
			elseif( self:GetAttribute("hideSemiRaid") and self:GetAttribute("state-raidmonitor") == "raid6" ) then
				self:GetFrameRef("partyHeader"):Hide()
			else
				self:GetFrameRef("partyHeader"):Show()
			end
		]])
		RegisterStateDriver(stateMonitor, "raidmonitor", "[target=raid6, exists] raid6; [target=raid1, exists] raid1; none")
	else
		headerFrame:Show()
	end
end

-- Fake headers that are supposed to act like headers to the users, but are really not
function Units:LoadZoneHeader(config, type)
	if( unitFrames[type] ) then
		unitFrames[type]:Show()
		return
	end
	
	local headerFrame = CreateFrame("Frame", "SUFHeader" .. type, UIParent)
	headerFrame.isHeaderFrame = true
	headerFrame.unitType = type
	headerFrame:SetClampedToScreen(true)
	headerFrame:SetMovable(true)
	headerFrame:SetHeight(0.1)
	headerFrame.children = {}
	unitFrames[type] = headerFrame
	
	if( type == "arena" ) then
		headerFrame:SetScript("OnAttributeChanged", function(self, key, value)
			if( key == "childChanged" and value and self.children[value] and self:IsVisible() ) then
				self.children[value]:FullUpdate()
			end
		end)
	end
	
	for id, unit in pairs(ShadowUF[type .. "Units"]) do
		local frame = self:CreateUnit("Button", "SUFHeader" .. type .. "UnitButton" .. id, headerFrame, "SecureUnitButtonTemplate")
		frame.ignoreAnchor = true
		frame:SetAttribute("unit", unit)
		frame:Hide()
		
		headerFrame.children[id] = frame
		
		-- Arena frames are only allowed to be shown not hidden from the unit existing, or else when a Rogue
		-- stealths the frame will hide which looks bad. Instead force it to stay open and it has to be manually hidden when the player leaves an arena.
		if( type == "arena" ) then
			frame:SetAttribute("unitID", id)
			stateMonitor:WrapScript(frame, "OnAttributeChanged", [[
				if( name == "state-unitexists" ) then
					local parent = self:GetParent()
					if( value and self:GetAttribute("unitDisappeared") ) then
						parent:SetAttribute("childChanged", self:GetAttribute("unitID"))
						self:SetAttribute("unitDisappeared", nil)
					elseif( not value and not self:GetAttribute("unitDisappeared") ) then
						self:SetAttribute("unitDisappeared", true)
					end
					
					
					if( value ) then
						self:Show()
					end
				end
			]])
		
			RegisterUnitWatch(frame, true)
		else
			RegisterUnitWatch(frame)
 		end
 	end
	

	self:SetHeaderAttributes(headerFrame, type)
	
	ShadowUF.Layout:AnchorFrame(UIParent, headerFrame, ShadowUF.db.profile.positions[type])	
end

-- Load a unit that is a child of another unit (party pet/party target)
function Units:LoadChildUnit(parent, type, id)
	parent.loadStatus = "function called"
	
	local unitFormat = string.match(type, "pet$") and (parent.unitRealType .. "pet%d") or (parent.unitRealType .. "%dtarget")
	local unit = string.format(unitFormat, id)
	if( InCombatLockdown() ) then
		parent.loadStatus = "combat lockdown"
		if( not queuedCombat[unit .. type] ) then
			queuedCombat[unit .. type] = {parent = parent, type = type, id = id}
		end
		return
	else
		-- This is a bit confusing to write down, but just in case I forget:
		-- It's possible theres a bug where you have a frame skip creating it's child because it thinks one was already created, but the one that was created is actually associated to another parent. What would need to be changed is it checks if the frame has the parent set to it and it's the same unit type before returning, not that the units match.
		for frame in pairs(frameList) do
			if( frame.unit == unit and frame.unitType == type ) then
				parent.loadStatus = "found existing"
				RegisterUnitWatch(frame, type == "partypet")
				return
			end
		end
	end
	
	-- Now we can create the actual frame
	local frame = self:CreateUnit("Button", "SUFChild" .. type .. string.match(parent:GetName(), "(%d+)"), parent, "SecureUnitButtonTemplate")
	frame.unitType = type
	frame.parent = parent
	frame:SetFrameStrata("LOW")
	frame:SetAttribute("unit", unit)
	frame:SetAttribute("unitFormat", unitFormat)
	frame:SetAttribute("parentUnit", parent:GetAttribute("unit"))
	
	RegisterUnitWatch(frame, type == "partypet")
		
	-- While we're at it, let us also position it for the first time
	ShadowUF.Layout:AnchorFrame(parent, frame, ShadowUF.db.profile.positions[type])
	
	-- Only raid and party types should use the special reattributing code
	if( parent.unitType ~= "party" and parent.unitType ~= "raid" ) then return end
	
	-- Need to make it so the secure monitor can access the frames
	parent.totalChildren = (parent.totalChildren or 0) + 1
	parent:SetFrameRef("childFrame" .. parent.totalChildren, frame)

	-- Parent needs to be wrapped to know when to change the childs unit
	if( not parent.isWrapped ) then
		parent.isWrapped = true
		stateMonitor:WrapScript(parent, "OnAttributeChanged", [[
			if( name ~= "unit" or not value or self:GetAttribute("lastUnit") == value ) then return end
			self:SetAttribute("lastUnit", value)

			local id = 1
			while( true ) do
				local child = self:GetFrameRef("childFrame" .. id)
				if( not child ) then break end
				
				-- Currently the player? Then don't show any child units for it
				if( value == "player" ) then
					child:SetAttribute("unit", nil)
					child:SetAttribute("parentUnit", nil)
				elseif( child:GetAttribute("parentUnit") ~= value ) then
					child:SetAttribute("unit", string.format(child:GetAttribute("unitFormat"), string.match(value, "(%d+)")))
					child:SetAttribute("parentUnit", value)
				end

				id = id + 1
			end
		]])
	end
end

-- Initialize units
function Units:InitializeFrame(config, type)
	if( type == "party" or type == "raid" or type == "maintank" or type == "mainassist" ) then
		self:LoadGroupHeader(config, type)
	elseif( self.zoneUnits[type] ) then
		self:LoadZoneHeader(config, type)
	elseif( self.childUnits[type] ) then
		for frame in pairs(frameList) do
			if( frame.unitType == self.childUnits[type] and ShadowUF.db.profile.units[frame.unitType] ) then
				self:LoadChildUnit(frame, type, frame.unitID)
			end
		end
	else
		self:LoadUnit(config, type)
	end
end

-- Uninitialize units
function Units:UninitializeFrame(config, type)
	-- Disables showing party in raid automatically if raid frames are disabled
	if( type == "party" ) then
		stateMonitor:SetAttribute("partyDisabled", true)
	elseif( type == "raid" and unitFrames.party ) then
		unitFrames.party:SetAttribute("showParty", true)
	end

	-- Disable the parent and the children will follow
	if( unitFrames[type] and unitFrames[type].isHeaderFrame ) then
		unitFrames[type]:Hide()
		
		if( unitFrames[type].children ) then
			for _, frame in pairs(unitFrames[type].children) do
				frame:Hide()
			end
		end
	else
		-- Disable all frames of this type
		for frame in pairs(frameList) do
			if( frame.unitType == type ) then
				UnregisterUnitWatch(frame)
				frame:Hide()
			end
		end
	end
end

-- Profile changed, reload units
function Units:ProfileChanged()
	-- Reset the anchors for all frames to prevent X is dependant on Y
	for frame in pairs(frameList) do
		if( frame.unit ) then
			frame:ClearAllPoints()
		end
	end
	
	for frame in pairs(frameList) do
		if( frame.unit and ShadowUF.db.profile.units[frame.unitType].enabled ) then
			-- Force all enabled modules to disable
			for key, module in pairs(ShadowUF.modules) do
				if( frame[key] and frame.visibility[key] ) then
					frame.visibility[key] = nil
					module:OnDisable(frame)
				end
			end
			
			-- Now enable whatever we need to
			frame:SetVisibility()
			ShadowUF.Layout:Load(frame)
			frame:FullUpdate()
		end
	end
	
	for _, frame in pairs(unitFrames) do
		if( frame.isHeaderFrame and ShadowUF.db.profile.units[frame.unitType].enabled ) then
			self:ReloadHeader(frame.unitType)
		end
	end
end

-- Small helper function for creating bars with
function Units:CreateBar(parent)
	local bar = CreateFrame("StatusBar", nil, parent)
	bar:SetFrameLevel(parent.topFrameLevel or 5)
	bar.parent = parent
	
	bar.background = bar:CreateTexture(nil, "BORDER")
	bar.background:SetHeight(1)
	bar.background:SetWidth(1)
	bar.background:SetAllPoints(bar)

	return bar
end

-- Deal with zone changes for enabling modules
local instanceType
function Units:CheckPlayerZone(force)
	local instance = select(2, IsInInstance())
	if( instance == instanceType and not force ) then return end
	instanceType = instance
	
	ShadowUF:LoadUnits()
	for frame in pairs(frameList) do
		if( frame.unit and ShadowUF.db.profile.units[frame.unitType].enabled ) then
			frame:SetVisibility()
			
			-- Auras are enabled so will need to check if the filter has to change
			if( frame.visibility.auras ) then
				ShadowUF.modules.auras:UpdateFilter(frame)
			end
			
			if( UnitExists(frame.unit) ) then
				frame:FullUpdate()
			end
		end
	end
end

local centralFrame = CreateFrame("Frame")
centralFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
centralFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
centralFrame:SetScript("OnEvent", function(self, event, unit)
	-- Check if the player changed zone types and we need to change module status, while they are dead
	-- we won't change their zone type as releasing from an instance will change the zone type without them
	-- really having left the zone
	if( event == "ZONE_CHANGED_NEW_AREA" ) then
		if( UnitIsDeadOrGhost("player") ) then
			self:RegisterEvent("PLAYER_UNGHOST")
		else
			self:UnregisterEvent("PLAYER_UNGHOST")
			Units:CheckPlayerZone()
		end				
		
	-- They're alive again so they "officially" changed zone types now
	elseif( event == "PLAYER_UNGHOST" ) then
		Units:CheckPlayerZone()
		
	-- This is slightly hackish, but it suits the purpose just fine for somthing thats rarely called.
	elseif( event == "PLAYER_REGEN_ENABLED" ) then
		-- Now do all of the creation for child wrapping
		for _, queue in pairs(queuedCombat) do
			Units:LoadChildUnit(queue.parent, queue.type, queue.id)
		end
		
		table.wipe(queuedCombat)
	end
end)