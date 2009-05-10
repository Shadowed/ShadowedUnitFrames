local Unit = ShadowUF:NewModule("Unit", "AceEvent-3.0")
local unitFrames = {}
local unitEvents = {}

function Unit:OnInitialize()
	ShadowUF:RegisterModule(self)
end

-- Register an event that should always call the frame
local function RegisterNormalEvent(self, event, funct)
	self:RegisterEvent(event)
	self[event] = funct
end

-- Register an event thats only called if it's for the actual unit
local function RegisterUnitEvent(self, event, funct)
	unitEvents[event] = true

	RegisterNormalEvent(self, event, funct)
end

-- Register a function to be called in an OnUpdate if it's an invalid unit (targettarget/etc)
local function RegisterUpdateFunc(self, handler, funct)
	self.fullUpdates[handler] = funct or true
end

local function UnregisterUpdateFunc(self, funct)
	self.fullUpdates[funct] = nil
end

-- Event handling
local function OnEvent(self, event, unit, ...)
	if( not self:IsShown() ) then return end
	if( not unitEvents[event] or self.unit == unit ) then
		self[event](self, self.unit, ...)
	end
end

-- Frame shown, do a full update
local function FullUpdate(self)
	for handler, funct in pairs(self.fullUpdates) do
		if( funct == true ) then
			handler(self, self.unit)
		else
			handler[funct](handler, self.unit)
		end
	end
end

-- For targettarget/focustarget/etc units that don't give us real events
local function TargetUnitUpdate(self, elapsed)
	self.timeElapsed = self.timeElapsed + elapsed
	
	if( self.unit and self.unitGuid ~= UnitGUID(self.unit) and self.timeElapsed >= 0.25 ) then
		self.timeElapsed = 0
		self:FullUpdate()

		self.unitGuid = UnitGUID(self.unit)
	end
end

-- Frame is now initialized with a unit
local function OnAttributeChanged(self, name, value)
	if( name ~= "unit" or not value ) then
		return
	end
	
	self.unit = value
	self.unitID = tonumber(string.match(value, "([0-9]+)"))
	self.configUnit = string.gsub(value, "([0-9]+)", "")
	
	unitFrames[value] = self
		
	if( not self.unitCreated ) then
		self.unitCreated = true
		
		ShadowUF:FireModuleEvent("UnitCreated", self, value)
	end
	
	-- Apply our layout quickly
	ShadowUF.modules.Layout:Apply(self, self.configUnit)
	
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
	--ClickCastFrames = ClickCastFrames or {}
	--ClickCastFrames[self] = true
end

function Unit:LoadUnit(config, unit)
	local mainFrame = CreateFrame("Button", "SSUFUnit" .. unit, UIParent, "SecureUnitButtonTemplate")
	self:CreateUnit(mainFrame)
	
	mainFrame:SetAttribute("unit", unit)

	-- Annd lets get this going
	RegisterUnitWatch(mainFrame)
end

function Unit:CreateUnit(frame, hookShow)
	frame.barFrame = CreateFrame("Frame", frame:GetName() .. "BarFrame", frame)
	
	if( hookShow ) then
		frame:HookScript("OnShow", FullUpdate)
	else
		frame:SetScript("OnShow", FullUpdate)
	end
	
	frame:RegisterForClicks("AnyUp")
	frame:SetScript("OnAttributeChanged", OnAttributeChanged)
	frame:SetScript("OnEvent", FullUpdate)
	frame:SetAttribute("*type1", "target")
	frame:SetAttribute("*type2", "menu")
	frame.menu = Unit.ShowMenu
	frame:Hide()
	
	frame.fullUpdates = {}
	frame.RegisterNormalEvent = RegisterNormalEvent
	frame.RegisterUnitEvent = RegisterUnitEvent
	frame.RegisterUpdateFunc = RegisterUpdateFunc
	frame.UnregisterUpdateFunc = UnregisterUpdateFunc
	frame.FullUpdate = FullUpdate
end

local function initUnit(frame)
	frame.ignoreAnchor = true
	Unit:CreateUnit(frame)
end

function Unit:LoadPartyHeader(config, unit)
	local headerFrame = CreateFrame("Frame", "SSUFHeader" .. unit, UIParent, "SecureGroupHeaderTemplate")
	headerFrame:SetAttribute("template", "SecureUnitButtonTemplate")
	headerFrame:SetAttribute("point", "TOP")
	headerFrame:SetAttribute("columnAnchorPoint", "TOP")
	headerFrame:SetAttribute("initial-width", config.width)
	headerFrame:SetAttribute("initial-height", config.height)
	headerFrame:SetAttribute("initial-scale", config.scale)
	headerFrame:SetAttribute("initial-unitWatch", true)
	headerFrame:SetAttribute("showParty", true)
	headerFrame.initialConfigFunction = initUnit
	headerFrame:Show()

	headerFrame:ClearAllPoints()
	headerFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
end

local petPoint = { "TOPRIGHT", "RIGHT", "BOTTOMRIGHT", "TOPLEFT", "LEFT", "BOTTOMLEFT", "BOTTOMLEFT", "BOTTOM", "BOTTOMRIGHT", "TOPLEFT", "TOP", "TOPRIGHT"}
local petRelative = { "TOPLEFT", "LEFT", "BOTTOMLEFT", "TOPRIGHT", "RIGHT", "BOTTOMRIGHT", "TOPLEFT", "TOP", "TOPRIGHT", "BOTTOMLEFT", "BOTTOM", "BOTTOMRIGHT"}
function Unit:LoadPetUnit(config, parentHeader, unit)
	local frame = CreateFrame("Button", "SSUFUnit" .. unit, UIParent, "SecureUnitButtonTemplate,SecureHandlerShowHideTemplate")
	self:CreateUnit(frame, true)
	
	frame.ignoreAnchor = true
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
	frame:SetAttribute("unit", unit)
	frame:SetAttribute("petOwner", (string.gsub(unit, "(%w+)pet(%d+)", "%1%2")))
	frame:SetAttribute("framePoint", petPoint[config.position])
	frame:SetAttribute("frameRelative", petRelative[config.position])
	frame:SetPoint("CENTER", UIParent, "CENTER", 150, -150)

	frame:SetFrameRef("partyHeader",  parentHeader)
	
	-- Annd lets get this going
	RegisterUnitWatch(frame)
end

function Unit:InitializeFrame(config, unit)
	if( unit == "party" ) then
		self:LoadPartyHeader(config, unit)
	elseif( unit == "raid" ) then
	
	elseif( unit == "partypet" ) then
		for i=1, MAX_PARTY_MEMBERS do
			self:LoadPetUnit(config, SSUFHeaderparty, unit .. i)
		end
	else
		self:LoadUnit(config, unit)
	end
end

function Unit:UninitializeFrame(unit)
	
end

function Unit:LayoutApplied(frame, unit)
	frame:FullUpdate()
end

function Unit.ShowMenu(frame)
	local menuFrame
	if( frame.unit == "player" ) then
		menuFrame = PlayerFrameDropDown
	elseif( frame.unit == "pet" ) then
		menuFrame = PetFrameDropDown
	elseif( frame.unit == "target" ) then
		menuFrame = TargetFrameDropDown
	elseif( frame.configUnit == "party" ) then
		menuFrame = getglobal("PartyMemberFrame" .. frame.unitID .. "DropDown")
	elseif( frame.configUnit == "raid" ) then
		menuFrame = FriendsDropDown
		menuFrame.displayMode = "MENU"
		menuFrame.initialize = RaidFrameDropDown_Initialize
	end
	
	if( not menuFrame ) then
		return
	end
	
	HideDropDownMenu(1)
	ToggleDropDownMenu(1, nil, menuFrame, "cursor")
	
	menuFrame.unit = frame.unit
	menuFrame.name = UnitName(frame.unit)
	menuFrame.id = frame.unitID
end

function Unit:CreateBar(parent, name)
	local frame = CreateFrame("StatusBar", parent:GetName() .. "HealthBar", parent)
	frame.parent = parent
	frame.background = frame:CreateTexture(nil, "BORDER")
	frame.background:SetHeight(1)
	frame.background:SetWidth(1)
	frame.background:SetAllPoints(frame)
	
	return frame
end


