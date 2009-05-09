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

function Unit:InitializeFrame(config, unit)
	local mainFrame = CreateFrame("Button", "SUFUnit" .. unit, UIParent, "SecureUnitButtonTemplate")
	mainFrame.barFrame = CreateFrame("Frame", "SUFUnit" .. unit .. "BarFrame", mainFrame)

	mainFrame:RegisterForClicks("AnyUp")
	mainFrame:SetScript("OnEvent", FullUpdate)
	mainFrame:SetScript("OnShow", FullUpdate)
	mainFrame:SetAttribute("unit", unit)
	mainFrame:SetAttribute("*type1", "target")
	mainFrame:SetAttribute("*type2", "menu")
	mainFrame.unit = unit
	mainFrame.menu = Unit.ShowMenu
	mainFrame:Hide()

	mainFrame.fullUpdates = {}
	mainFrame.RegisterNormalEvent = RegisterNormalEvent
	mainFrame.RegisterUnitEvent = RegisterUnitEvent
	mainFrame.RegisterUpdateFunc = RegisterUpdateFunc
	mainFrame.UnregisterUpdateFunc = UnregisterUpdateFunc
	mainFrame.FullUpdate = FullUpdate
	
	unitFrames[unit] = mainFrame
		
	ShadowUF:FireModuleEvent("UnitCreated", mainFrame, unit)
	
	-- Apply our layout quickly
	ShadowUF.modules.Layout:Apply(mainFrame, unit)
	
	-- Annd lets get this going
	RegisterUnitWatch(mainFrame)

	-- Is it an invalid unit?
	if( string.match(unit, "%w+target") ) then
		mainFrame.timeElapsed = 0
		mainFrame:SetScript("OnUpdate", TargetUnitUpdate)
		
	-- Automatically do a full update on target change
	elseif( unit == "target" ) then
		mainFrame:RegisterNormalEvent("PLAYER_TARGET_CHANGED", FullUpdate)
	-- Automatically do a full update on focus change
	elseif( unit == "focus" ) then
		mainFrame:RegisterNormalEvent("PLAYER_FOCUS_CHANGED", FullUpdate)
	end
	
	-- Add to Clique
	--ClickCastFrames = ClickCastFrames or {}
	--ClickCastFrames[mainFrame] = true
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
	elseif( frame.type == "party" ) then
		menuFrame = getglobal("PartyMemberFrame" .. fra,me.unitID .. "DropDown")
	elseif( frame.type == "raid" ) then
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
	local frame = CreateFrame("StatusBar", nil, parent)
	frame:SetFrameLevel(1)
	frame.parent = parent
	frame.background = frame:CreateTexture(nil, "BORDER")
	frame.background:SetHeight(1)
	frame.background:SetWidth(1)
	frame.background:SetAllPoints(frame)
	
	return frame
end


