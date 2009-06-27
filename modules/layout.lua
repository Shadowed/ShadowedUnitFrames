local Layout = {}
local SML, config, mediaRequired
local barOrder, anchoringQueued, mediaPath, frameList = {}, {}, {}, {}
local _G = getfenv(0)

ShadowUF.Layout = Layout

local function loadMedia(type, name, default)
	if( name == "" ) then return "" end
	
	local media = SML:Fetch(type, name, true)
	if( not media ) then
		mediaRequired = mediaRequired or {}
		mediaRequired[type] = name
		return default
	end
	
	return media
end

function Layout:MediaForced(mediaType)
	local oldPath = mediaPath[mediaType]
	self:CheckMedia()
	
	if( mediaPath[mediaType] ~= oldPath ) then
		self:Reload()
	end
end

function Layout:CheckMedia()
	mediaPath[SML.MediaType.STATUSBAR] = loadMedia(SML.MediaType.STATUSBAR, ShadowUF.db.profile.bars.texture, "Interface\\AddOns\\ShadowedUnitFrames\\media\\textures\\Aluminium")
	mediaPath[SML.MediaType.FONT] = loadMedia(SML.MediaType.FONT, ShadowUF.db.profile.font.name, "Interface\\AddOns\\ShadowedUnitFrames\\media\\fonts\\Myriad Condensed Web.ttf")
	mediaPath[SML.MediaType.BACKGROUND] = loadMedia(SML.MediaType.BACKGROUND, ShadowUF.db.profile.backdrop.backgroundTexture, "Interface\\ChatFrame\\ChatFrameBackground")
	mediaPath[SML.MediaType.BORDER] = loadMedia(SML.MediaType.BORDER, ShadowUF.db.profile.backdrop.borderTexture, "")

	self.mediaPath = mediaPath

end

-- We might not have had a media we required at initial load, wait for it to load and then update everything when it does
function Layout:MediaRegistered(event, mediaType, key)
	if( mediaRequired and mediaRequired[mediaType] and mediaRequired[mediaType] == key ) then
		mediaPath[mediaType] = SML:Fetch(mediaType, key)
		mediaRequired[mediaType] = nil
		
		self:Reload()
	end
end

-- Helper function
function Layout:ToggleVisibility(frame, visible)
	if( frame ) then
		if( visible ) then
			frame:Show()
		else
			frame:Hide()
		end
	end
end	

-- Frame changed somehow between when we first set it all up and now
function Layout:Reload(unit)
	-- Now update them
	for frame in pairs(frameList) do
		if( not unit or frame.unitType == unit ) then
			frame:SetVisibility()
			self:Load(frame)
			frame:FullUpdate()
		end
	end
end

-- Do a full update
function Layout:Load(frame)
	-- About to set layout
	ShadowUF:FireModuleEvent("OnPreLayoutApply", frame)

	local unitConfig = ShadowUF.db.profile.units[frame.unitType]
	
	-- Load all of the layout things
	self:SetupFrame(frame, unitConfig)
	self:SetupBars(frame, unitConfig)
	self:PositionWidgets(frame, unitConfig)
	self:PositionIndicators(frame, unitConfig)
	self:PositionAuras(frame, unitConfig)
	self:SetupText(frame, unitConfig)

	-- Set this frame as managed by the layout system
	frameList[frame] = true

	-- Check if we had anything parented to us
	for queued in pairs(anchoringQueued) do
		if( queued.queuedName == frame:GetName() ) then
			self:AnchorFrame(queued.queuedParent, queued, queued.queuedConfig)

			queued.queuedParent = nil
			queued.queuedConfig = nil
			queued.queuedName = nil
			anchoringQueued[queued] = nil
		end
	end

	-- Layouts been fully set
	ShadowUF:FireModuleEvent("OnLayoutApplied", frame)
end

function Layout:LoadSML()
	SML = SML or LibStub:GetLibrary("LibSharedMedia-3.0")
	SML.RegisterCallback(self, "LibSharedMedia_Registered", "MediaRegistered")
	SML.RegisterCallback(self, "LibSharedMedia_SetGlobal", "MediaForced")

	SML:Register(SML.MediaType.FONT, "Myriad Condensed Web", "Interface\\AddOns\\ShadowedUnitFrames\\media\\fonts\\Myriad Condensed Web.ttf")
	SML:Register(SML.MediaType.BORDER, "Square Clean", "Interface\\AddOns\\ShadowedUnitFrames\\media\\textures\\ABFBorder")
	SML:Register(SML.MediaType.BACKGROUND, "Chat Frame", "Interface\\ChatFrame\\ChatFrameBackground")
	SML:Register(SML.MediaType.STATUSBAR, "BantoBar", "Interface\\AddOns\\ShadowedUnitFrames\\media\\textures\\banto")
	SML:Register(SML.MediaType.STATUSBAR, "Smooth",   "Interface\\AddOns\\ShadowedUnitFrames\\media\\textures\\smooth")
	SML:Register(SML.MediaType.STATUSBAR, "Perl",     "Interface\\AddOns\\ShadowedUnitFrames\\media\\textures\\perl")
	SML:Register(SML.MediaType.STATUSBAR, "Glaze",    "Interface\\AddOns\\ShadowedUnitFrames\\media\\textures\\glaze")
	SML:Register(SML.MediaType.STATUSBAR, "Charcoal", "Interface\\AddOns\\ShadowedUnitFrames\\media\\textures\\Charcoal")
	SML:Register(SML.MediaType.STATUSBAR, "Otravi",   "Interface\\AddOns\\ShadowedUnitFrames\\media\\textures\\otravi")
	SML:Register(SML.MediaType.STATUSBAR, "Striped",  "Interface\\AddOns\\ShadowedUnitFrames\\media\\textures\\striped")
	SML:Register(SML.MediaType.STATUSBAR, "LiteStep", "Interface\\AddOns\\ShadowedUnitFrames\\media\\textures\\LiteStep")
	SML:Register(SML.MediaType.STATUSBAR, "Aluminium", "Interface\\AddOns\\ShadowedUnitFrames\\media\\textures\\Aluminium")
	SML:Register(SML.MediaType.STATUSBAR, "Minimalist", "Interface\\AddOns\\ShadowedUnitFrames\\media\\textures\\Minimalist")

	self:CheckMedia()
end

--[[
	Keep in mind this is relative to where you're parenting it, RT will put the object outside of the frame, on the right side, at the top of it
	while ITR will put it inside the frame, at the top to the right
	
	RT = Right Top, RC = Right Center, RB = Right Bottom
	LT = Left Top, LC = Left Center, LB = Left Bottom,
	BL = Bottom Left, BC = Bottom Center, BR = Bottom Right
	ICL = Inside Center Left, IC = Inside Center Center, ICR = Inside Center Right
	TR = Top Right, TC = Top Center, TL = Top Left
	ITR = Inside Top Right, ITL = Inside Top Left
]]

local preDefPoint = {C = "CENTER", ICL = "LEFT", RT = "TOPLEFT", BC = "TOP", ICR = "RIGHT", LT = "TOPRIGHT", TR = "TOPRIGHT", BL = "TOPLEFT", LB = "BOTTOMRIGHT", LC = "RIGHT", RB = "BOTTOMLEFT", RC = "LEFT", TC = "BOTTOM", BR = "TOPRIGHT", TL = "TOPLEFT", IBR = "BOTTOMRIGHT", IBL = "BOTTOM", ITR = "BOTTOMRIGHT", ITL = "BOTTOM", IC = "CENTER"}
local preDefRelative = {C = "CENTER", ICL = "LEFT", RT = "TOPRIGHT", BC = "BOTTOM", ICR = "RIGHT", LT = "TOPLEFT", TR = "TOPRIGHT", BL = "BOTTOMLEFT", LB = "BOTTOMLEFT", LC = "LEFT", RB = "BOTTOMRIGHT", RC = "RIGHT", TC = "TOP", BR = "BOTTOMRIGHT", TL = "TOPLEFT", IBR = "BOTTOMRIGHT", IBL = "BOTTOMLEFT", ITR = "RIGHT", ITL = "LEFT", IC = "CENTER"}

-- Figures out how text should be justified based on where it's anchoring
function Layout:GetJustify(config)
	local point = config.anchorPoint and config.anchorPoint ~= "" and preDefPoint[config.anchorPoint] or config.point
	if( point and point ~= "" ) then
		if( string.match(point, "LEFT$") ) then
			return "LEFT"
		elseif( string.match(point, "RIGHT$") ) then
			return "RIGHT"
		end
	end
	
	return "CENTER"
end

function Layout:GetPoint(key)
	return preDefPoint[key]
end

function Layout:GetRelative(key)
	return preDefRelative[key]
end

function Layout:AnchorFrame(parent, frame, config)
	if( not config or not config.anchorTo ) then
		return
	end
	
	local anchorTo = config.anchorTo
	local prefix = string.sub(config.anchorTo, 0, 1)
	if( config.anchorTo == "$parent" ) then
		anchorTo = parent
	-- $ is used as an indicator of a sub-frame inside a parent, $healthBar -> parent.healthBar and so on
	elseif( prefix == "$" ) then
		anchorTo = parent[string.sub(config.anchorTo, 2)]
	-- # is used as an indicator of an actual frame created by SUF, SUFUnittarget, etc. It also means, that the frame might not have been created yet
	elseif( prefix == "#" ) then
		anchorTo = string.sub(config.anchorTo, 2)
		-- The frame we wanted to anchor to doesn't exist yet, so will queue and wait for it to exist
		if( not _G[anchorTo] ) then
			frame.queuedParent = parent
			frame.queuedConfig = config
			frame.queuedName = anchorTo
			anchoringQueued[frame] = true
			
			-- For the time being, will take over the frame we wanted to anchor to's position.
			local unit = string.match(anchorTo, "SUFUnit(%w+)") or string.match(anchorTo, "SUFHeader(%w+)")
			if( unit and ShadowUF.db.profile.positions[unit] ) then
				self:AnchorFrame(parent, frame, ShadowUF.db.profile.positions[unit])
			end
			return
		end
	end

	-- Effective scaling should only be used if it's enabled + they are anchored to the UIParent
	local scale = 1
	if( config.anchorTo == "UIParent" and frame.unitType ) then
		scale = frame:GetEffectiveScale()
	end
	
	if( config.anchorPoint and config.anchorPoint ~= "" ) then
		frame:ClearAllPoints()
		frame:SetPoint(preDefPoint[config.anchorPoint], anchorTo, preDefRelative[config.anchorPoint], config.x / scale, config.y / scale)
	elseif( config.point and config.point ~= "" and config.relativePoint and config.relativePoint ~= "" and config.x and config.y ) then
		frame:ClearAllPoints()
		frame:SetPoint(config.point, anchorTo, config.relativePoint, config.x / scale, config.y / scale)
	end
end

-- Setup the main frame
local backdropTbl = {insets = {}}
function Layout:SetupFrame(frame, config)
	local backdrop = ShadowUF.db.profile.backdrop
	backdropTbl.bgFile = mediaPath.background
	backdropTbl.edgeFile = mediaPath.border
	backdropTbl.tile = backdrop.tileSize > 0 and true or false
	backdropTbl.edgeSize = backdrop.edgeSize
	backdropTbl.tileSize = backdrop.tileSize
	backdropTbl.insets.left = backdrop.inset
	backdropTbl.insets.right = backdrop.inset
	backdropTbl.insets.top = backdrop.inset
	backdropTbl.insets.bottom = backdrop.inset
		
	frame:SetHeight(config.height)
	frame:SetWidth(config.width)
	frame:SetScale(config.scale)
	frame:SetBackdrop(backdropTbl)
	frame:SetBackdropColor(backdrop.backgroundColor.r, backdrop.backgroundColor.g, backdrop.backgroundColor.b, backdrop.backgroundColor.a)
	frame:SetBackdropBorderColor(backdrop.borderColor.r, backdrop.borderColor.g, backdrop.borderColor.b, backdrop.borderColor.a)
	frame:SetClampedToScreen(true)
	
	-- Let the frame clip closer to the edge
	local clip = backdrop.inset + backdrop.clip
	frame:SetClampRectInsets(-clip, -clip, -clip, -clip)
	
	if( not frame.ignoreAnchor ) then
		self:AnchorFrame(UIParent, frame, ShadowUF.db.profile.positions[frame.unitType])
	end
end

-- Setup bars
function Layout:SetupBars(frame, config)
	for _, module in pairs(ShadowUF.modules) do
		local key = module.moduleKey
		local widget = frame[key]
		if( widget and module.moduleHasBar ) then
			self:ToggleVisibility(widget, frame.visibility[key])
			if( widget:IsShown() ) then
				widget:SetStatusBarTexture(mediaPath.statusbar)
								
				if( widget.background ) then
					if( config[key].background ) then
						widget.background:SetTexture(mediaPath.statusbar)
						widget.background:Show()
					else
						widget.background:Hide()
					end
				end
			end
		end
	end
end

-- Setup text
local function updateShadows(fontString)
	if( ShadowUF.db.profile.font.shadowColor and ShadowUF.db.profile.font.shadowX and ShadowUF.db.profile.font.shadowY ) then
		fontString:SetShadowColor(ShadowUF.db.profile.font.shadowColor.r, ShadowUF.db.profile.font.shadowColor.g, ShadowUF.db.profile.font.shadowColor.b, ShadowUF.db.profile.font.a)
		fontString:SetShadowOffset(ShadowUF.db.profile.font.shadowX, ShadowUF.db.profile.font.shadowY)
	else
		fontString:SetShadowColor(0, 0, 0, 0)
		fontString:SetShadowOffset(0, 0)
	end
end

local totalWeight = {}
function Layout:SetupText(frame, config)
	-- Update cast bar text
	if( frame.castBar and frame.castBar:IsShown() ) then
		-- Set the font at the very least, so it doesn't error when we set text on it even if it isn't being shown
		frame.castBar.name:SetFont(mediaPath.font, ShadowUF.db.profile.font.size, ShadowUF.db.profile.font.extra)
		if( config.castBar.castName.enabled ) then
			frame.castBar.name:SetParent(frame.highFrame)
			frame.castBar.name:SetWidth(frame.castBar:GetWidth() * 0.75)
			frame.castBar.name:SetHeight(ShadowUF.db.profile.font.size + 1)
			frame.castBar.name:SetJustifyH(self:GetJustify(config.castBar.castName))
			frame.castBar.name:Show()
			self:AnchorFrame(frame.castBar, frame.castBar.name, config.castBar.castName)

			updateShadows(frame.castBar.name)
		else
			frame.castBar.name:Hide()
		end
		
		frame.castBar.time:SetFont(mediaPath.font, ShadowUF.db.profile.font.size, ShadowUF.db.profile.font.extra)
		if( config.castBar.castTime.enabled ) then
			frame.castBar.time:SetParent(frame.highFrame)
			frame.castBar.time:SetWidth(frame.castBar:GetWidth() * 0.25)
			frame.castBar.time:SetHeight(ShadowUF.db.profile.font.size + 1)
			frame.castBar.time:SetJustifyH(self:GetJustify(config.castBar.castTime))
			frame.castBar.time:Show()
			self:AnchorFrame(frame.castBar, frame.castBar.time, config.castBar.castTime)

			updateShadows(frame.castBar.time)
		else
			frame.castBar.time:Hide()
		end
	elseif( frame.castBar ) then
		frame.castBar.time:Hide()
		frame.castBar.name:Hide()
	end
	
	-- Update feedback text
	self:ToggleVisibility(frame.combatText, config.combatText and config.combatText.enabled)
	if( frame.combatText and frame.combatText:IsShown() ) then
		frame.combatText.feedbackText:SetFont(mediaPath.font, ShadowUF.db.profile.font.size + 1)
		frame.combatText.feedbackFontHeight = ShadowUF.db.profile.font.size + 1
		frame.combatText.fontPath = mediaPath.font
		
		updateShadows(frame.combatText.feedbackText)
		
		self:AnchorFrame(frame, frame.combatText, config.combatText)
	end

	-- Update tag text
	frame.fontStrings = frame.fontStrings or {}
	for _, fontString in pairs(frame.fontStrings) do
		ShadowUF.Tags:Unregister(fontString)
		fontString:Hide()
	end
	
	for k in pairs(totalWeight) do totalWeight[k] = nil end
	
	-- Update the actual text, and figure out the weighting information now
	for id, row in pairs(config.text) do
		local parent = row.anchorTo == "$parent" and frame or frame[string.sub(row.anchorTo, 2)]
		if( parent and parent:IsShown() and row.enabled and row.text ~= "" ) then
			local fontString = frame.fontStrings[id] or frame:CreateFontString(nil, "ARTWORK")
			fontString:SetFont(mediaPath.font, ShadowUF.db.profile.font.size + row.size, ShadowUF.db.profile.font.extra)
			fontString:SetText(row.text)
			fontString:SetParent(frame.highFrame)
			fontString:SetJustifyH(self:GetJustify(row))
			self:AnchorFrame(frame, fontString, row)
			
			local anchorPoint = (row.anchorPoint == "ITR" or row.anchorPoint == "ITL") and "IT" or (row.anchorPoint == "ICL" or row.anchorPoint == "ICR" ) and "IC" or row.anchorPoint
			
			fontString.availableWidth = parent:GetWidth() - row.x
			fontString.widthID = row.anchorTo .. anchorPoint .. row.y
			totalWeight[fontString.widthID] = (totalWeight[fontString.widthID] or 0) + row.width
			
			updateShadows(fontString)
			
			ShadowUF.Tags:Register(frame, fontString, row.text)
			fontString:UpdateTags()
			fontString:Show()
			
			frame.fontStrings[id] = fontString
			frame:RegisterUpdateFunc(fontString, "UpdateTags")
		end
	end

	-- Now set all of the width using our weightings
	for id, fontString in pairs(frame.fontStrings) do
		if( fontString:IsShown() ) then
			fontString:SetWidth(fontString.availableWidth * (config.text[id].width / totalWeight[fontString.widthID]))
			fontString:SetHeight(ShadowUF.db.profile.font.size + 1)
		end
	end
end

-- Setup indicators
function Layout:PositionIndicators(frame, config)
	if( frame.comboPoints ) then
		self:ToggleVisibility(frame.comboPoints, config.comboPoints.enabled)
		if( frame.comboPoints:IsShown() ) then
			frame.comboPoints:SetHeight(0.1)
			frame.comboPoints:SetWidth(0.1)
			
			self:AnchorFrame(frame, frame.comboPoints, config.comboPoints)
		end
	end

	if( not frame.indicators or not frame.visibility.indicators ) then
		if( frame.indicators ) then
			for _, indicator in pairs(frame.indicators.list) do
				self:ToggleVisibility(frame.indicators[indicator], false)
			end
		end
		return
	end
	
	for _, key in pairs(frame.indicators.list) do
		local indicator = frame.indicators[key]
		if( indicator ) then
			indicator.enabled = config.indicators[key] and config.indicators[key].enabled
			if( indicator.enabled and config.indicators[key].size ) then
				indicator:SetHeight(config.indicators[key].size)
				indicator:SetWidth(config.indicators[key].size)
				
				self:AnchorFrame(frame, indicator, config.indicators[key])
			end
		end
	end
end

local function positionAuras(self, config)
	for id=1, self.maxAuras do
		local button = self.buttons[id]
		button:SetHeight(config.size)
		button:SetWidth(config.size)
		button.border:SetHeight(config.size + 1)
		button.border:SetWidth(config.size + 1)
		button:ClearAllPoints()

		-- If's ahoy
		if( id > 1 ) then
			if( config.anchorPoint == "BOTTOM" or config.anchorPoint == "TOP" or config.anchorPoint == "INSIDE" ) then
				if( id % config.perRow == 1 ) then
					if( config.anchorPoint == "TOP" ) then
						button:SetPoint("BOTTOM", self.buttons[id - config.perRow], "TOP", 0, 2)
					else
						button:SetPoint("TOP", self.buttons[id - config.perRow], "BOTTOM", 0, -2)
					end
				elseif( config.anchorPoint == "INSIDE" ) then
						button:SetPoint("RIGHT", self.buttons[id - 1], "LEFT", -1, 0)
				else
					button:SetPoint("LEFT", self.buttons[id - 1], "RIGHT", 1, 0)
				end
			elseif( id % config.maxRows == 1 or config.maxRows == 1 ) then
				if( config.anchorPoint == "RIGHT" ) then
					button:SetPoint("LEFT", self.buttons[id - config.maxRows], "RIGHT", 1, 0)
				else
					button:SetPoint("RIGHT", self.buttons[id - config.maxRows], "LEFT", -1, 0)
				end
			else
				button:SetPoint("TOP", self.buttons[id - 1], "BOTTOM", 0, -2)
			end
		elseif( config.anchorPoint == "INSIDE" ) then
			button:SetPoint("TOPRIGHT", self.parent.healthBar, "TOPRIGHT", config.x + -ShadowUF.db.profile.backdrop.clip, config.y + -ShadowUF.db.profile.backdrop.clip)
		elseif( config.anchorPoint == "BOTTOM" ) then
			button:SetPoint("BOTTOMLEFT", self.parent, "BOTTOMLEFT", config.x + ShadowUF.db.profile.backdrop.inset, config.y + -(config.size + 2))
		elseif( config.anchorPoint == "TOP" ) then
			button:SetPoint("TOPLEFT", self.parent, "TOPLEFT", config.x + ShadowUF.db.profile.backdrop.inset, config.y + (config.size + 2))
		elseif( config.anchorPoint == "LEFT" ) then
			button:SetPoint("TOPLEFT", self.parent, "TOPLEFT", config.x + -config.size, config.y + ShadowUF.db.profile.backdrop.inset + ShadowUF.db.profile.backdrop.clip)
		elseif( config.anchorPoint == "RIGHT" ) then
			button:SetPoint("TOPRIGHT", self.parent, "TOPRIGHT", config.x + config.size, config.y + ShadowUF.db.profile.backdrop.inset + ShadowUF.db.profile.backdrop.clip)
		end
	end
end			
			
-- Setup auras
function Layout:PositionAuras(frame, config)
	if( not frame.auras or not frame.visibility.auras ) then
		if( frame.auras ) then
			frame.auras.buffs.buttons[1]:Hide()
			frame.auras.debuffs.buttons[1]:Hide()
		end
		return
	end
		
	-- Update aura position
	if( config.auras.buffs.enabled ) then positionAuras(frame.auras.buffs, config.auras.buffs) end
	if( config.auras.debuffs.enabled ) then positionAuras(frame.auras.debuffs, config.auras.debuffs) end
end

-- Setup the bar barOrder/info
local currentConfig
local function sortOrder(a, b)
	return currentConfig[a].order < currentConfig[b].order
end

-- This system is a bit odd for dealing with full sized bars, but it's functional although slightly more complicated than the old one
-- as using the old system would require 3 bar frames per each frame which is kind of a waste when we can just use offsets and a bit of magic
function Layout:PositionWidgets(frame, config)
	-- Deal with setting all of the bar heights
	local totalWeight, totalBars, hasFullSize = 0, -1
	
	-- Figure out total weighting as well as what bars are full sized
	for i=#(barOrder), 1, -1 do table.remove(barOrder, i) end
	for key, module in pairs(ShadowUF.modules) do
		if( module.moduleHasBar and frame[key] and frame[key]:IsShown() ) then
			totalWeight = totalWeight + config[key].height
			totalBars = totalBars + 1
			
			table.insert(barOrder, key)
			
			-- Decide whats full sized
			if( not frame.visibility.portrait or config[key].order < config.portrait.fullBefore or config[key].order > config.portrait.fullAfter ) then
				hasFullSize = true
				frame[key].fullSize = true
			else
				frame[key].fullSize = nil
			end
		end
	end

	-- Sort the barOrder so it's all nice and orderly (:>)
	currentConfig = config
	table.sort(barOrder, sortOrder)

	-- Now deal with setting the heights and figure out how large the portrait should be.
	local clip = ShadowUF.db.profile.backdrop.inset + ShadowUF.db.profile.backdrop.clip
	local clipDoubled = clip * 2
	
	-- Figure out portrait alignment
	local portraitAlignment = config.portrait.alignment
	if( not config.portrait.noAutoAlign and ( frame.unit == "target" or string.match(frame.unit, "%w+target") ) ) then
		portraitAlignment = config.portrait.alignment == "LEFT" and "RIGHT" or "LEFT"
	end

	-- Set the portrait width so we can figure out the offset to use on bars, will do height and position later
	self:ToggleVisibility(frame.portrait, frame.visibility.portrait)
	if( frame.portrait and frame.portrait:IsShown() ) then
		frame.portrait:SetWidth(math.floor(config.width * config.portrait.width) - ShadowUF.db.profile.backdrop.inset)
	end

	-- As well as how much to offset bars by (if it's using a left alignment) to keep them all fancy looking
	local portraitOffset = clip
	if( frame.visibility.portrait and portraitAlignment == "LEFT" ) then
		portraitOffset = frame.portrait:GetWidth() + clip
	end
	
	-- Position and size everything
	local portraitHeight, xOffset = 0, -clip
	local availableHeight = frame:GetHeight() - clipDoubled - (math.abs(ShadowUF.db.profile.bars.spacing) * totalBars)
	local portraitAnchor
	for id, key in pairs(barOrder) do
		local bar = frame[key]
		bar.type = key
		
		-- Position the actual bar based on it's type
		if( bar.fullSize ) then
			bar:SetWidth(math.ceil(frame:GetWidth() - clipDoubled))
			bar:SetHeight(availableHeight * (config[key].height / totalWeight))
			bar:SetPoint("TOPLEFT", frame, "TOPLEFT", clip, xOffset)
		else
			bar:SetWidth(math.ceil(frame:GetWidth() - frame.portrait:GetWidth() - clipDoubled))
			bar:SetHeight(availableHeight * (config[key].height / totalWeight))
			bar:SetPoint("TOPLEFT", frame, "TOPLEFT", portraitOffset, xOffset)
			
			portraitHeight = portraitHeight + bar:GetHeight()
		end
		
		-- Figure out where the portrait is going to be anchored to
		if( not portraitAnchor and config[key].order >= config.portrait.fullBefore ) then
			portraitAnchor = bar
		end

		xOffset = xOffset - bar:GetHeight() + ShadowUF.db.profile.bars.spacing
	end
	
	-- Now position the portrait and set the height
	if( frame.portrait and frame.portrait:IsShown() and portraitAnchor ) then
		if( portraitAlignment == "LEFT" ) then
			frame.portrait:ClearAllPoints()
			frame.portrait:SetPoint("TOPRIGHT", portraitAnchor, "TOPLEFT", -1, 0)
		else
			frame.portrait:ClearAllPoints()
			frame.portrait:SetPoint("TOPLEFT", portraitAnchor, "TOPRIGHT", 1, 0)
		end
			
		if( hasFullSize ) then
			frame.portrait:SetHeight(math.floor(portraitHeight))
		else
			frame.portrait:SetHeight(config.height - clipDoubled)
		end
	end
end



 