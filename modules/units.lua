local Units = ShadowUF:NewModule("Units")
local unitList, unitFrames, unitEvents, loadedUnits, queuedCombat = {}, {}, {}, {}, {}
local inCombat, needPartyFrame
local FRAME_LEVEL_MAX = 5

Units.unitFrames = unitFrames
ShadowUF:RegisterModule(Units)

-- Frame shown, do a full update
local function FullUpdate(self)
	for handler, func in pairs(self.fullUpdates) do
		if( func == true ) then
			handler(self)
		else
			handler[func](handler, self)
		end
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

-- Register an event thats only called if it's for the actual unit
local function RegisterUnitEvent(self, event, handler, func)
	unitEvents[event] = true

	RegisterNormalEvent(self, event, handler, func)
end

-- Register a function to be called in an OnUpdate if it's an invalid unit (targettarget/etc)
local function RegisterUpdateFunc(self, handler, func)
	self.fullUpdates[handler] = func or true
end

-- Used when something is disabled, removes all callbacks etc to it
local function UnregisterAll(self, handler)
	self.fullUpdates[handler] = nil
	
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
	FullUpdate(self)
	self:SetScript("OnEvent", OnEvent)
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
	for key in pairs(ShadowUF.moduleNames) do
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
			for module in pairs(ShadowUF.regModules) do
				if( module.moduleKey == key ) then
					module:UnitEnabled(self, self.unit)
				end
			end
		elseif( not enabled and wasEnabled ) then
			for module in pairs(ShadowUF.regModules) do
				if( module.moduleKey == key ) then
					module:UnitDisabled(self, self.unit)
					if( self[key] ) then
						self[key].disabled = true
					end
				end
			end
		end
	end
	
	if( layoutUpdate ) then
		ShadowUF.Layout:ApplyAll(self)
	end
end

-- Frame is now initialized with a unit
local function OnAttributeChanged(self, name, value)
	if( name ~= "unit" or not value or self.unit == value ) then return end
	if( inCombat ) then
		queuedCombat[self] = true
		return
	end
	
	self.unit = value
	self.unitID = tonumber(string.match(value, "([0-9]+)"))
	self.unitType = string.gsub(value, "([0-9]+)", "")
	
	unitList[value] = self

	-- Now set what is enabled
	self:SetVisibility()
	
	-- Is it an invalid unit?
	if( string.match(value, "%w+target") ) then
		self.timeElapsed = 0
		self:SetScript("OnUpdate", TargetUnitUpdate)
		
	-- Pet changed, going from pet -> vehicle for one
	elseif( value == "pet" ) then
		self:RegisterUnitEvent("UNIT_PET", self, "FullUpdate")
		
	-- Automatically do a full update on target change
	elseif( value == "target" ) then
		self:RegisterNormalEvent("PLAYER_TARGET_CHANGED", self, "FullUpdate")
	-- Automatically do a full update on focus change
	elseif( value == "focus" ) then
		self:RegisterNormalEvent("PLAYER_FOCUS_CHANGED", self, "FullUpdate")
	end
		
	-- Add to Clique
	ClickCastFrames = ClickCastFrames or {}
	ClickCastFrames[self] = true
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
	if( self.unitType == "party" or self.unitType == "raid" ) then
		self = unitFrames[self.unitType]
	end
	
	self.isMoving = true
	self:StartMoving()

	GameTooltip:Hide()
end

local function OnDragStop(self)
	if( self.unitType == "party" or self.unitType == "raid" ) then
		self = unitFrames[self.unitType]
	end
	
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
	frame.UnregisterUpdateFunc = UnregisterUpdateFunc
	frame.UnregisterAll = UnregisterAll
	frame.FullUpdate = FullUpdate
	frame.SetVisibility = SetVisibility
	frame.topFrameLevel = FRAME_LEVEL_MAX
	
	frame:SetScript("OnDragStart", OnDragStart)
	frame:SetScript("OnDragStop", OnDragStop)
	frame:SetScript("OnAttributeChanged", OnAttributeChanged)
	frame:SetScript("OnEnter", 	UnitFrame_OnEnter)
	frame:SetScript("OnLeave", 	UnitFrame_OnLeave)
	frame:SetScript("OnEvent", OnEvent)

	frame:SetMovable(true)
	frame:RegisterForDrag("LeftButton")
	frame:RegisterForClicks("AnyUp")	
	frame:SetAttribute("*type1", "target")
	frame:SetAttribute("*type2", "menu")
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

function Units:ReloadUnit(type)
	-- Force any attribute changes to take affect.
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
	
	local frame = unitFrames[type]
	if( frame ) then
		self:SetFrameAttributes(frame, type)
		ShadowUF.Layout:AnchorFrame(UIParent, frame, ShadowUF.db.profile.positions[type])
	end
end

function Units:ProfileChanged()
	for _, frame in pairs(unitList) do
		if( frame:GetAttribute("unit") ) then
			frame:SetVisibility()
			frame:FullUpdate()
		end
	end
	
	self:ReloadUnit("raid")
	self:ReloadUnit("party")
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
			frame:SetAttribute("sortMethod", "INDEX")
			frame:SetAttribute("sortDir", "ASC")
			frame:SetAttribute("maxColumns", config.maxColumns)
			frame:SetAttribute("unitsPerColumn", config.unitsPerColumn)
			frame:SetAttribute("columnSpacing", config.columnSpacing)
			frame:SetAttribute("columnAnchorPoint", config.attribAnchorPoint)

			if( config.groupBy == "CLASS" ) then
				frame:SetAttribute("groupingOrder", "DEATHKNIGHT,DRUID,HUNTER,MAGE,PALADIN,PRIEST,ROGUE,SHAMAN,WARLOCK,WARRIOR")
				frame:SetAttribute("groupBy", config.groupBy)
			elseif( config.groupBy == "CLASS" ) then
				frame:SetAttribute("groupingOrder", "1,2,3,4,5,6,7,8")
				frame:SetAttribute("groupBy", config.groupBy)
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
		for i=1, MAX_PARTY_MEMBERS do
			self:LoadPartyChildUnit(config, SUFHeaderparty, type, type .. i)
		end
	elseif( type == "partytarget" ) then
		for i=1, MAX_PARTY_MEMBERS do
			self:LoadPartyChildUnit(config, SUFHeaderparty, type, "party" .. i .. "target")
		end
	else
		self:LoadUnit(config, type)
	end
end

local function disableChildren(...)
	for i=1, select("#", ...) do
		local frame = select(i, ...)
		if( frame.unit ) then
			ShadowUF:FireModuleEvent("UnitDisabled", frame)
			frame:SetAttribute("unit", nil)
		end
	end
end

function Units:UninitializeFrame(config, type)
	if( not loadedUnits[type] ) then return end
	loadedUnits[type] = nil
	
	for _, frame in pairs(unitFrames) do
		if( frame.unitType == type ) then
			UnregisterUnitWatch(frame)
			
			if( frame.unit ~= type ) then
				disableChildren(frame:GetChildren())
			else
				ShadowUF:FireModuleEvent("UnitDisabled", frame)
				frame:SetAttribute("unit", nil)
			end

			frame:Hide()
		end
	end
end

function Units:LayoutApplied(frame)
	frame:FullUpdate()
end

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

-- Combat queuer
local centralFrame = CreateFrame("Frame")
centralFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
centralFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
centralFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
centralFrame:SetScript("OnEvent", function(self, event)
	if( event == "ZONE_CHANGED_NEW_AREA" ) then
		for _, frame in pairs(unitList) do
			if( frame:GetAttribute("unit") ) then
				frame:SetVisibility()
			end
		end
		
	elseif( event == "PLAYER_REGEN_ENABLED" ) then
		inCombat = nil
		
		for frame in pairs(queuedCombat) do
			OnAttributeChanged(frame, "unit", frame:GetAttribute("unit"))
			queuedCombat[frame] = nil
			
			-- If the party was started while in combat (Nobody else in the group) the header might not have height/width set
			if( frame.unitType ~= frame.unit ) then
				unitFrames[frame.unitType]:SetHeight(0.1)
				unitFrames[frame.unitType]:SetWidth(0.1)
			end
		end
	elseif( event == "PLAYER_REGEN_DISABLED" ) then
		inCombat = true
	end
end)
