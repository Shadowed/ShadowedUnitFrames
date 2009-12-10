local L = ShadowUFLocals
local Movers = {headers = {["party"] = "partyUnits", ["raid"] = "raidUnits", ["maintank"] = "raidUnits", ["mainassist"] = "raidUnits", ["arena"] = "arenaUnits"}}
local childUnits = ShadowUF.Units.childUnits
local moverList, tempPositions = {}, {}
ShadowUF:RegisterModule(Movers, "movers")

if( ShadowUF.isBuild30300 ) then Movers.headers.boss = "bossUnits" end

local function OnEnter(self)
	local tooltipText = self.tooltipText or L.units[self.unitType] or self.unitType
	if( tooltipText and self.tooltipHeader ) then
		GameTooltip:SetOwner(self, "ANCHOR_BOTTOMLEFT")
		GameTooltip:SetText(self.tooltipHeader, 1, 0.81, 0, 1, true)
		GameTooltip:AddLine(tooltipText, 0.90, 0.90, 0.90, 1)
		GameTooltip:Show()
	elseif( tooltipText ) then
		GameTooltip:SetOwner(self, "ANCHOR_BOTTOMLEFT")
		GameTooltip:SetText(tooltipText, 1, 0.81, 0, 1, true)
		GameTooltip:Show()
	end
end

local function OnLeave(self)
	GameTooltip:Hide()
end

local function OnShow(self)
	for frame in pairs(ShadowUF.Units.frameList) do
		frame:SetAlpha(0)
		frame.OrigSetAlpha = frame.SetAlpha
		frame.SetAlpha = ShadowUF.noop
		
		if( frame:IsShown() ) then
			frame.wasVisible = true
			frame:Hide()
		end
	end
end

local function OnHide(self)
	for frame in pairs(ShadowUF.Units.frameList) do
		if( frame.OrigSetAlpha ) then
			frame.OrigSetAlpha = nil
			frame.SetAlpha = frame.OrigSetAlpha
		end
		frame:SetAlpha(1)
		
		if( frame.wasVisible ) then
			frame.wasVisible = nil
			frame:Show()
		end
	end
end

function Movers:Enable()
	-- Enable it for all units that are enabled
	-- Create necessary frames
	for unit, config in pairs(ShadowUF.db.profile.units) do
		if( config.enabled and not childUnits[unit] ) then
			if( self.headers[unit] ) then
				self:CreateHeader(unit)
			else
				self:CreateSingle(unit)
			end
		end
	end
	
	-- Disable the unnecessary
	for _, frame in pairs(moverList) do
		if( ( frame.unitType and not ShadowUF.db.profile.units[frame.unitType].enabled ) or ( frame.childsOwner and not frame.childsOwner:IsVisible() ) ) then
			frame:Hide()
		elseif( not frame.headerFrame ) then
			frame:Show()
		end
	end
	
	if( self.infoFrame ) then
		self.infoFrame:Show()
		return
	end
	
	-- Show an info frame that users can lock the frames through
	local frame = CreateFrame("Frame", nil, UIParent)
	frame:SetClampedToScreen(true)
	frame:SetWidth(300)
	frame:SetHeight(115)
	frame:RegisterForDrag("LeftButton")
	frame:EnableMouse(true)
	frame:SetMovable(true)
	frame:SetScript("OnShow", OnShow)
	frame:SetScript("OnHide", OnHide)
	frame:SetScript("OnDragStart", function(self)
		self:StartMoving()
	end)
	frame:SetScript("OnDragStop", function(self)
		self:StopMovingOrSizing()
	end)
	frame:SetBackdrop({
		  bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
		  edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
		  edgeSize = 26,
		  insets = {left = 9, right = 9, top = 9, bottom = 9},
	})
	frame:SetBackdropColor(0, 0, 0, 0.85)
	frame:SetPoint("CENTER", UIParent, "CENTER", 0, 225)

	frame.titleBar = frame:CreateTexture(nil, "ARTWORK")
	frame.titleBar:SetTexture("Interface\\DialogFrame\\UI-DialogBox-Header")
	frame.titleBar:SetPoint("TOP", 0, 8)
	frame.titleBar:SetWidth(350)
	frame.titleBar:SetHeight(45)

	frame.title = frame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
	frame.title:SetPoint("TOP", 0, 0)
	frame.title:SetText("Shadowed Unit Frames")

	frame.text = frame:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
	frame.text:SetText(L["The black boxes are used for positioning all enabled unit frames.\n\nYou can hide them by locking them through /shadowuf or clicking the button below."])
	frame.text:SetPoint("TOPLEFT", 12, -22)
	frame.text:SetWidth(frame:GetWidth() - 20)
	frame.text:SetJustifyH("LEFT")

	frame.lock = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
	frame.lock:SetText(L["Lock frames"])
	frame.lock:SetHeight(20)
	frame.lock:SetWidth(100)
	frame.lock:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 6, 8)
	frame.lock:SetScript("OnEnter", OnEnter)
	frame.lock:SetScript("OnLeave", OnLeave)
	frame.lock.tooltipText = L["Locks the unit frame positionings hiding the mover boxes."]
	frame.lock:SetScript("OnClick", function()
		ShadowUF.db.profile.locked = true
		Movers:Update()
	end)

	frame.unlink = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
	frame.unlink:SetText(L["Unlink frames"])
	frame.unlink:SetHeight(20)
	frame.unlink:SetWidth(100)
	frame.unlink:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -6, 8)
	frame.unlink:SetScript("OnEnter", OnEnter)
	frame.unlink:SetScript("OnLeave", OnLeave)
	frame.unlink.tooltipText = L["WARNING: This will unlink all frames from each other so you can move them without another frame moving with it."]
	frame.unlink:SetScript("OnClick", function()
		for _, frame in pairs(moverList) do
			if( not frame.isHeaderFrame and not frame.childsOwner ) then
				frame:GetScript("OnDragStart")(frame)
				frame:GetScript("OnDragStop")(frame)
			end
		end
		
		Movers:Update()
	end)

	self.infoFrame = frame
end

local function OnDragStart(self)
	if( not self:IsMovable() ) then return end
	
	local frame = self.headerFrame or self
	frame.isMoving = true
	frame:StartMoving()
	self.parentMover = frame
	
	if( frame.unitType == "raid" and ShadowUF.Units.headerFrames.raidParent and ShadowUF.Units.headerFrames.raidParent:IsVisible() ) then
		frame.parent = ShadowUF.Units.headerFrames.raidParent
		frame.isSplitFrame = true
	else
		frame.parent = ShadowUF.Units.headerFrames[frame.unitType] or ShadowUF.Units.unitFrames[frame.unitType]
		frame.isSplitframe = nil
	end
end

local function OnDragStop(self)
	if( not self:IsMovable() ) then return end

	local frame = self.parentMover or self
	frame.isMoving = nil
	frame:StopMovingOrSizing()
	
	-- When dragging the frame around, Blizzard changes the anchoring based on the closet portion of the screen
	-- When a widget is near the top left it uses top left, near the left it uses left and so on, which messes up positioning for header frames
	local scale = GetCVarBool("useUiScale") and frame:GetEffectiveScale() or 1
	local position = ShadowUF.db.profile.positions[frame.unitType]
	local point, _, relativePoint, x, y = frame:GetPoint()
	
	-- Figure out the horizontal anchor
	if( frame.isHeaderFrame ) then
		if( ShadowUF.db.profile.units[frame.unitType].attribAnchorPoint == "RIGHT" ) then
			x = frame:GetRight()
			point = "RIGHT"
		else
			x = frame:GetLeft()
			point = "LEFT"
		end
		
		if( ShadowUF.db.profile.units[frame.unitType].attribPoint == "BOTTOM" ) then
			y = frame:GetBottom()
			point = "BOTTOM" .. point
		else
			y = frame:GetTop()
			point = "TOP" .. point
		end
		
		relativePoint = "BOTTOMLEFT"
		position.bottom = frame:GetBottom() * scale
		position.top = frame:GetTop() * scale
	end
	
	position.anchorTo = "UIParent"
	position.movedAnchor = nil
	position.anchorPoint = ""
	position.point = point
	position.relativePoint = relativePoint
	position.x = x * scale
	position.y = y * scale
		
	ShadowUF.Layout:AnchorFrame(UIParent, frame, ShadowUF.db.profile.positions[frame.unitType])

	-- Unlock the parent frame from the mover now too
	if( frame.parent ) then
		ShadowUF.Layout:AnchorFrame(UIParent, frame.parent, ShadowUF.db.profile.positions[frame.parent.unitType])
	end
	
	-- Notify the configuration it can update itself now
	LibStub("AceConfigRegistry-3.0"):NotifyChange("ShadowedUF")
end

-- Handles the header creation to mimick all the frames they have
local function positionFrame(frame)
	tempPositions[frame.unitType] = tempPositions[frame.unitType] or {}
	table.wipe(tempPositions[frame.unitType])
	for k, v in pairs(ShadowUF.db.profile.positions[frame.unitType]) do tempPositions[frame.unitType][k] = v end
	tempPositions[frame.unitType].anchorTo = string.gsub(tempPositions[frame.unitType].anchorTo, "#SUFUnit", "#SUFMover")
	tempPositions[frame.unitType].anchorTo = string.gsub(tempPositions[frame.unitType].anchorTo, "#SUFHeader", "#SUFMover")
	
	ShadowUF.Layout:AnchorFrame(frame.childsOwner or UIParent, frame, tempPositions[frame.unitType])
end

-- Need to make sure we keep the mover frames updated to what their owners would look like
local function setupFrame(frame)
	ShadowUF.Layout:SetupFrame(frame, ShadowUF.db.profile.units[frame.unitType])
	frame.text:SetWidth(frame:GetWidth() - 10)
	frame.text:SetHeight(frame:GetHeight() - 10)
	
	-- Setup test mode
	local config = ShadowUF.db.profile.units[frame.unitType]
	for _, module in pairs(ShadowUF.modules) do
		if( module.TestMode ) then
			module:TestMode(frame, config)
		end
	end
	
	-- Handle anchoring an aura group to another
	frame.auras.anchorAurasOn = nil
	if( config.auras.buffs.enabled and config.auras.debuffs.enabled ) then
		if( config.auras.buffs.anchorOn ) then
			frame.auras.anchorAurasOn = frame.auras.debuffs
			frame.auras.anchorAurasChild = frame.auras.buffs
		elseif( config.auras.debuffs.anchorOn ) then
			frame.auras.anchorAurasOn = frame.auras.buffs
			frame.auras.anchorAurasChild = frame.auras.debuffs
		end
	end

	if( frame.auras.anchorAurasOn ) then
		ShadowUF.modules.auras.anchorGroupToGroup(frame, config[frame.auras.anchorAurasOn.type], frame.auras.anchorAurasOn, config[frame.auras.anchorAurasChild.type], frame.auras.anchorAurasChild)
	end

	-- Handle prioritizing an anchor group over another when merging them
	if( config.auras.buffs.anchorPoint == config.auras.debuffs.anchorPoint and config.auras.buffs.enabled and config.auras.debuffs.enabled and not config.auras.buffs.anchorOn and not config.auras.debuffs.anchorOn ) then
		if( config.auras.buffs.prioritize ) then
			for _, button in pairs(frame.auras.debuffs.buttons) do
				button:Hide()
			end
		else
			for _, button in pairs(frame.auras.buffs.buttons) do
				button:Hide()
			end
		end
	end

	if( not frame.headerFrame and not frame.dontPosition ) then
		positionFrame(frame)
	end
end

function Movers:OnLayoutReload(type)
	if( ShadowUF.db.profile.locked ) then return end
	
	for _, frame in pairs(moverList) do
		if( frame.unitType == type and not frame.isHeaderFrame ) then
			setupFrame(frame)
		end
	end
	
	if( moverList[type] ) then
		self:CreateHeader(type)
	end
end
		
function Movers:CreateHeader(type)
	local headerFrame = moverList[type] or CreateFrame("Frame", "SUFMover" .. type, UIParent)
	headerFrame:SetMovable(true)
	headerFrame.unitType = type
	headerFrame.unit = type
	headerFrame.isHeaderFrame = true
	
	moverList[type] = headerFrame
	
	-- Ceate all of the child frames for this header
	headerFrame.children = headerFrame.children or {}
	for id, unit in pairs(ShadowUF[self.headers[type]]) do
		headerFrame.children[id] = self:CreateFrame(unit, type, true)
		headerFrame.children[id].tooltipHeader = string.format(L["%s frames"], L.units[type])
		headerFrame.children[id].tooltipText = L.units[type] .. " #" .. id
		headerFrame.children[id].text:SetText(headerFrame.children[id].tooltipText)
		headerFrame.children[id].headerFrame = headerFrame
		
		-- And create the children of the children (Boy do they reproduce fast!)
		for unitChild, unitParent in pairs(childUnits) do
			if( unitParent == type ) then
				local frame = self:CreateFrame(unitChild .. id, unitChild, true, headerFrame.children[id])
				frame.childsOwner = headerFrame.children[id]
				frame.tooltipHeader = L.units[unitChild] .. " (#" .. id .. ")"
				frame.tooltipText = L["To reposition this frame, open /shadowuf and manually position it there."]
				frame.text:SetText(frame.tooltipHeader)
				frame:SetMovable(false)
				
				positionFrame(frame)
			end
		end
	end
				
	-- Position all of the children headers so they mimick the real ones
	local config = ShadowUF.db.profile.units[type]
	local unitsPerColumn = config.frameSplit and 5 or config.unitsPerColumn or #(headerFrame.children)
	local maxUnits = 0
	if( config.filters ) then
		for _, enabled in pairs(config.filters) do
			if( enabled ) then maxUnits = maxUnits + 5 end
		end
		
		unitsPerColumn = math.min(unitsPerColumn, maxUnits)
	else
		maxUnits = #(headerFrame.children)
	end
	
	local point = config.attribPoint or "TOP"
    local relativePoint, xOffsetMulti, yOffsetMulti = ShadowUF.Layout:GetRelativeAnchor(point)
    local xMultiplier, yMultiplier = math.abs(xOffsetMulti), math.abs(yOffsetMulti)
	local columnRelativePoint, colxMulti, colyMulti = ShadowUF.Layout:GetRelativeAnchor(config.attribAnchorPoint)
    local maxColumns = config.frameSplit and 8 or config.maxColumns or 1
	local totalDisplayed = math.min(maxUnits, (maxColumns * unitsPerColumn))
	local numColumns = math.ceil(totalDisplayed / unitsPerColumn)
    local x = (config.offset or 0) * xOffsetMulti
    local y = (config.offset or 0) * yOffsetMulti
    		
	-- Position all of the children
	local columnTotal = 0
	for id, child in pairs(headerFrame.children) do
		columnTotal = columnTotal + 1
		if( numColumns > 0 and columnTotal > unitsPerColumn ) then
			columnTotal = 1
		end
				
		if( id == 1 ) then
			child:ClearAllPoints()
			child:SetPoint(point, headerFrame, point, 0, 0)
			
			if( config.attribAnchorPoint and numColumns > 1 ) then
				child:SetPoint(config.attribAnchorPoint, headerFrame, config.attribAnchorPoint, 0, 0)
			end
		elseif( columnTotal == 1 ) then
			child:ClearAllPoints()
			child:SetPoint(config.attribAnchorPoint, headerFrame.children[id - unitsPerColumn], columnRelativePoint, colxMulti * config.columnSpacing, colyMulti * config.columnSpacing)
		else
			child:ClearAllPoints()
			child:SetPoint(point, headerFrame.children[id - 1], relativePoint, xMultiplier * x, yMultiplier * y)
		end
	end

	-- Figure out the size of the total header
	local width = xMultiplier * ( unitsPerColumn - 1 ) * config.width + ( ( unitsPerColumn - 1 ) * ( x * xOffsetMulti ) ) + config.width
	local height = yMultiplier * ( unitsPerColumn - 1 ) * config.height + ( ( unitsPerColumn - 1 ) * ( y * yOffsetMulti ) ) + config.height

	if( numColumns > 1 ) then
		width = width + ( ( numColumns - 1 ) * math.abs(colxMulti) * ( width + config.columnSpacing ) )
		height = height + ( ( numColumns - 1 ) * math.abs(colyMulti) * ( height + config.columnSpacing ) )
	end
	
	
	headerFrame:SetHeight(math.max(height, 0.1))
	headerFrame:SetWidth(math.max(width, 0.1))
		
	-- Now set which of the frames is shown vs hidden
	for id, frame in pairs(headerFrame.children) do
		if( id <= totalDisplayed ) then
			frame:Show()
		else
			frame:Hide()
		end
	end
		
	-- Position the header
	tempPositions[type] = tempPositions[type] or {}
	table.wipe(tempPositions[type])
	for k, v in pairs(ShadowUF.db.profile.positions[type]) do tempPositions[type][k] = v end
	tempPositions[type].anchorTo = string.gsub(tempPositions[type].anchorTo, "#SUFUnit", "#SUFMover")
	tempPositions[type].anchorTo = string.gsub(tempPositions[type].anchorTo, "#SUFHeader", "#SUFMover")
		
	ShadowUF.Layout:AnchorFrame(UIParent, headerFrame, tempPositions[type])
end

function Movers:CreateSingle(unit)
	local frame = self:CreateFrame(unit, unit)
	frame.text:SetText(L.units[unit])
end

function Movers:CreateFrame(unit, unitType, dontPosition, parent)
	for _, frame in pairs(moverList) do
		if( frame.unit == unit and frame.unitType == unitType ) then
			setupFrame(frame)
			return frame
		end
	end
		
	local moverFrame = CreateFrame("Frame", "SUFMover" .. unit, UIParent)
	moverFrame:SetScript("OnDragStart", OnDragStart)
	moverFrame:SetScript("OnDragStop", OnDragStop)
	moverFrame:SetScript("OnEnter", OnEnter)
	moverFrame:SetScript("OnLeave", OnLeave)
	moverFrame:SetFrameStrata("DIALOG")
	moverFrame:SetClampedToScreen(true)
	moverFrame:EnableMouse(true)
	moverFrame:RegisterForDrag("LeftButton")
	moverFrame:SetMovable(true)
	moverFrame.text = moverFrame:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
	moverFrame.text:SetPoint("CENTER", moverFrame, "CENTER")

	moverFrame.unitType = unitType or unit
	moverFrame.unit = unit
	moverFrame.ignoreAnchor = true
	moverFrame.dontPosition = dontPosition
	moverFrame.parent = parent
	moverFrame.auras = {}
	
	table.insert(moverList, moverFrame)
	setupFrame(moverFrame)
	OnShow(moverFrame)
	
	return moverFrame
end

function Movers:Update()
	if( not ShadowUF.db.profile.locked ) then
		self:Enable()
	elseif( ShadowUF.db.profile.locked ) then
		self:Disable()
	end
end

function Movers:Disable()
	for _, frame in pairs(moverList) do
		if( frame.isMoving ) then OnDragStop(frame) end
		frame:Hide()
	end
	
	if( self.infoFrame ) then
		self.infoFrame:Hide()
	end
end