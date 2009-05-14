local Units = ShadowUF:NewModule("Units")
local unitFrames = {}
local unitEvents = {}
local loadedUnits = {}

ShadowUF:RegisterModule(Units)

-- Frame shown, do a full update
local function FullUpdate(self)
	for handler, func in pairs(self.fullUpdates) do
		if( func == true ) then
			handler(self, self.unit)
		else
			handler[func](handler, self.unit)
		end
	end
end

-- Register an event that should always call the frame
local function RegisterNormalEvent(self, event, func)
	self:RegisterEvent(event)
	self.registeredEvents[event] = func
	self[event] = func
end

-- Register an event thats only called if it's for the actual unit
local function RegisterUnitEvent(self, event, func)
	unitEvents[event] = true

	RegisterNormalEvent(self, event, func)
end

-- Register a function to be called in an OnUpdate if it's an invalid unit (targettarget/etc)
local function RegisterUpdateFunc(self, handler, func)
	self.fullUpdates[handler] = func or true
end

-- Used when something is disabled, removes all callbacks etc to it
local function UnregisterAll(self, ...)
	for i=1, select("#", ...) do
		local func = select(i, ...)
		
		self.fullUpdates[func] = nil
		
		for event, callback in pairs(self.registeredEvents) do
			if( func == callback ) then
				self[event] = nil
				self.registeredEvents[event] = nil

				self:UnregisterEvent(event)
			end
		end
	end
end

-- Event handling
local function OnEvent(self, event, unit, ...)
	if( not unitEvents[event] or self.unit == unit ) then
		self.event = event
		self[event](self, self.unit, ...)
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
local function SetVisibility(self, unit)
	local zone = select(2, IsInInstance())

	-- Selectively disable modules
	for key in pairs(ShadowUF.moduleNames) do
		if( key == "auras" ) then
			local buffs = self.unitConfig[key].buffs
			local debuffs = self.unitConfig[key].debuffs
			
			if( zone ~= "none" ) then
				if( ShadowUF.db.profile.visibility[zone][unit .. key] == false ) then
					buffs = true
					debuffs = true
				elseif( ShadowUF.db.profile.visibility[zone][unit .. key] == true ) then
					buffs = true
					debuffs = true
				end
			end
			
			if( self.auras.buffs ) then self.auras.buffs.isEnabled = buffs end
			if( self.auras.debuffs ) then self.auras.debuffs.isEnabled = debuffs end	
		elseif( self[key] ) then
			local enabled = self.unitConfig[key]
		
			-- nil == Use the regular value inside the layout / false == Disable it here / true == Enable it here
			if( zone ~= "none" ) then
				if( ShadowUF.db.profile.visibility[zone][unit .. key] == false ) then
					enabled = false
				elseif( ShadowUF.db.profile.visibility[zone][unit .. key] == true ) then
					enabled = true
				end
			end

			self[key].isEnabled = enabled
		end
	end
end

-- Frame is now initialized with a unit
local function OnAttributeChanged(self, name, value)
	if( name ~= "unit" or not value ) then
		return
	end
	
	self.unit = value
	self.unitID = tonumber(string.match(value, "([0-9]+)"))
	self.unitType = string.gsub(value, "([0-9]+)", "")
	self.unitConfig = ShadowUF.db.profile.units[self.unitType]
	
	-- Give all of the modules a chance to create what they need
	ShadowUF:FireModuleEvent("UnitEnabled", self, value)
	
	-- Now set what is enabled
	SetVisibility(self, self.unitConfig)
	
	-- Apply our layout quickly
	ShadowUF.Layout:ApplyAll(self, self.unitType)
	
	-- For handling visibility
	self:RegisterNormalEvent("ZONE_CHANGED_NEW_AREA", SetVisibility)
	
	-- Is it an invalid unit?
	if( string.match(value, "%w+target") ) then
		self.timeElapsed = 0
		self:SetScript("OnUpdate", TargetUnitUpdate)
		
	-- Automatically do a full update on target change
	elseif( value == "target" ) then
		self:RegisterNormalEvent("PLAYER_TARGET_CHANGED", FullUpdate)
	-- Automatically do a full update on focus change
	elseif( value == "focus" ) then
		self:RegisterNormalEvent("PLAYER_FOCUS_CHANGED", FullUpdate)
	end
		
	-- Add to Clique
	ClickCastFrames = ClickCastFrames or {}
	ClickCastFrames[self] = true
end

function Units:LoadUnit(config, unit)
	-- Already be loaded, just enable
	if( unitFrames[unit] ) then
		unitFrames[unit]:SetAttribute(unit)
		unitFrames[unit]:Show()
		
		--RegisterUnitWatch(unitFrames[unit])
		return
	end
	
	local frame = CreateFrame("Button", "SUFUnit" .. unit, UIParent, "SecureUnitButtonTemplate")
	self:CreateUnit(frame)
	frame:SetAttribute("unit", unit)

	unitFrames[unit] = frame
		
	-- Annd lets get this going
	RegisterUnitWatch(frame)
end

-- Create the generic things that we want in every secure frame regardless if it's a button or a header
function Units:CreateUnit(frame,  hookVisibility)
	frame.barFrame = CreateFrame("Frame", frame:GetName() .. "BarFrame", frame)
	
	if( hookVisibility ) then
		frame:HookScript("OnShow", OnShow)
		frame:HookScript("OnHide", OnHide)
	else
		frame:SetScript("OnShow", OnShow)
		frame:SetScript("OnHide", OnHide)
	end
	
	frame:RegisterForClicks("AnyUp")
	frame:SetScript("OnAttributeChanged", OnAttributeChanged)
	frame:SetAttribute("*type1", "target")
	frame:SetAttribute("*type2", "menu")
	frame.menu = Units.ShowMenu
	frame:Hide()
	
	frame.fullUpdates = {}
	frame.registeredEvents = {}
	frame.RegisterNormalEvent = RegisterNormalEvent
	frame.RegisterUnitEvent = RegisterUnitEvent
	frame.RegisterUpdateFunc = RegisterUpdateFunc
	frame.UnregisterUpdateFunc = UnregisterUpdateFunc
	frame.UnregisterAll = UnregisterAll
	frame.FullUpdate = FullUpdate
end

local function initUnit(frame)
	frame.ignoreAnchor = true
	Units:CreateUnit(frame)
end

function Units:SetFrameAttributes(config, frame, type)
	if( type == "raid" ) then
		frame:SetAttribute("point", config.attribPoint)
		frame:SetAttribute("columnAnchorPoint", config.attribAnchorPoint)
		frame:SetAttribute("initial-width", config.width)
		frame:SetAttribute("initial-height", config.height)
		frame:SetAttribute("initial-scale", config.scale)
		frame:SetAttribute("showPlayer", config.showPlayer)
		frame:SetAttribute("showRaid", config.showRaid)
		frame:SetAttribute("showSolo", config.showSolo)
		frame:SetAttribute("groupBy", config.groupBy)
		frame:SetAttribute("groupingOrder", config.groupingOrder)
		frame:SetAttribute("sortMethod", config.sortMethod)
		frame:SetAttribute("sortDir", config.sortDir)
		frame:SetAttribute("maxColumns", config.maxColumns)
		frame:SetAttribute("unitsPerColumn", config.unitsPerColumn)
		frame:SetAttribute("columnSpacing", config.columnSpacing)
	elseif( type == "party" ) then
		frame:SetAttribute("point", config.attribPoint)
		frame:SetAttribute("columnAnchorPoint", config.attribAnchorPoint)
		frame:SetAttribute("initial-width", config.width)
		frame:SetAttribute("initial-height", config.height)
		frame:SetAttribute("initial-scale", config.scale)
		frame:SetAttribute("showParty", config.showParty)
		frame:SetAttribute("showPlayer", config.showPlayer)
		frame:SetAttribute("showSolo", config.showSolo)
	elseif( type == "partyPet" ) then
		frame:SetAttribute("framePoint", ShadowUF.Layout:GetPoint(config.position))
		frame:SetAttribute("frameRelative", ShadowUF.Layout:GetRelative(config.position))
	end
end

function Units:LoadGroupHeader(config, type)
	if( unitFrames[type] ) then
			self:SetFrameAttributes(config, unitFrames[type], type)
			unitFrames[type]:Show()
			return
	end
	
	local headerFrame = CreateFrame("Frame", "SUFHeader" .. type, UIParent, "SecureGroupHeaderTemplate")
	self:SetFrameAttributes(config, headerFrame, type)
	
	headerFrame:SetAttribute("template", "SecureUnitButtonTemplate")
	headerFrame:SetAttribute("initial-unitWatch", true)
	headerFrame.initialConfigFunction = initUnit
	headerFrame:Show()

	unitFrames[type] = frame
	ShadowUF.Layout:AnchorFrame(UIParent, headerFrame, ShadowUF.db.profile.positions[type])
end

function Units:LoadPetUnit(config, parentHeader, unit)
	if( unitFrames[unit] ) then
		self:SetFrameAttributes(config, unitFrames[unit], unitFrames[unit].unitType)
		RegisterUnitWatch(unitFrames[unit])
		return
	end
	
	local frame = CreateFrame("Button", "SUFUnit" .. unit, UIParent, "SecureUnitButtonTemplate,SecureHandlerShowHideTemplate")
	self:SetFrameAttributes(config, frame, "partypet")

	self:CreateUnit(frame, true)
	frame:SetFrameRef("partyHeader",  parentHeader)
	frame:SetAttribute("unit", unit)
	frame:SetAttribute("petOwner", (string.gsub(unit, "(%w+)pet(%d+)", "%1%2")))
	frame:SetAttribute("_onshow", [[
		local children = table.new(self:GetFrameRef("partyHeader"):GetChildren())
		for _, child in pairs(children) do
			if( child:GetAttribute("unit") == self:GetAttribute("petOwner") ) then
				self:SetParent(child)
				self:ClearAllPoints()
				self:SetPoint(self:GetAttribute("framePoint"), child, self:GetAttribute("frameRelative"), 0, 0)
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
			self:LoadPetUnit(config, SUFHeaderparty, type .. i)
		end
	else
		self:LoadUnit(config, type)
	end
end

function Units:UninitializeFrame(config, type)
	if( not loadedUnits[type] ) then return end
	loadedUnits[type] = nil
	
	for _, frame in pairs(unitFrames) do
		if( frame.unitType == type ) then
			--UnregisterUnitWatch(frame)
			
			ShadowUF:FireModuleEvent("UnitDisabled", frame, frame.unitType)
			
			frame:SetAttribute("unit", nil)
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

function Units:CreateBar(parent, name)
	local frame = CreateFrame("StatusBar", parent:GetName() .. "HealthBar", parent)
	frame.parent = parent
	frame.background = frame:CreateTexture(nil, "BORDER")
	frame.background:SetHeight(1)
	frame.background:SetWidth(1)
	frame.background:SetAllPoints(frame)
	
	return frame
end


