local Layout = {}
local SML, config
local ordering, backdropCache, anchoringQueued, mediaPath, frameList = {}, {}, {}, {}, {}
local mediaRequired

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
		self:ReloadAll()
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
		
		self:ReloadAll()
	end
end

-- Help function
function Layout:ToggleVisibility(frame, visible)
	if( frame ) then
		if( visible ) then
			frame:Show()
		else
			frame:Hide()
		end
	end
end	

function Layout:ReloadAll(unit)
	for frame in pairs(frameList) do
		if( not unit or frame.unitType == unit ) then
			frame:SetVisibility()
			self:ApplyAll(frame)
			frame:FullUpdate()
		end
	end
end

-- Do a full update
function Layout:ApplyAll(frame)
	local unitConfig = ShadowUF.db.profile.units[frame.unitType]
	if( not unitConfig ) then
		return
	end
	
	-- About to set layout
	ShadowUF:FireModuleEvent("OnPreLayoutApply", frame)
			
	self:ApplyUnitFrame(frame, unitConfig)
	self:ApplyPortrait(frame, unitConfig)
	self:ApplyBarVisuals(frame, unitConfig)
	self:ApplyBars(frame, unitConfig)
	self:ApplyIndicators(frame, unitConfig)
	self:ApplyAuras(frame, unitConfig)
	self:ApplyText(frame, unitConfig)
	
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

function Layout:AnchorFrame(parent, frame, config, isRecurse)
	if( not config or not config.anchorTo ) then
		return
	end
		
	local anchorTo
	local prefix = string.sub(config.anchorTo, 0, 1)
	if( config.anchorTo == "$parent" ) then
		anchorTo = parent
	-- $ is used as an indicator of a sub-frame inside a parent, $healthBar -> parent.healthBar and so on
	elseif( prefix == "$" ) then
		anchorTo = parent[string.sub(config.anchorTo, 2)]
	-- # is used as an indicator of an actual frame created by SUF, SUFUnittarget, etc. It also means, that the frame might not have been created yet
	elseif( prefix == "#" ) then
		anchorTo = string.sub(config.anchorTo, 2)
		if( not getglobal(anchorTo) ) then
			frame.queuedParent = parent
			frame.queuedConfig = config
			frame.queuedName = anchorTo
			anchoringQueued[frame] = true
			
			if( not isRecurse ) then
				local unit = string.match(anchorTo, "SUFUnit(%a+)") or string.match(anchorTo, "SUFHeader(%a+)")
				if( unit and ShadowUF.db.profile.positions[unit] ) then
					self:AnchorFrame(parent, frame, ShadowUF.db.profile.positions[unit], isRecurse)
				end
			else
				frame:ClearAllPoints()
				frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
			end
			return
		end
	else
		anchorTo = config.anchorTo
	end

	-- Effective scaling should only be used if it's enabled + they are anchored to the UIParent
	-- raaaaaaaaaaaaaggggggggggggggggeeeeeeeeeeeeeeeeeeeeeee
	local scale = 1
	if( config.anchorTo == "UIParent" and frame.unitType ) then
		scale = frame:GetEffectiveScale()
	end
		
	if( config.anchorPoint and config.anchorPoint ~= "" ) then
		frame:ClearAllPoints()
		frame:SetPoint(preDefPoint[config.anchorPoint], anchorTo, preDefRelative[config.anchorPoint], config.x / scale, config.y / scale)
	elseif( config.point ~= "" and config.relativePoint ~= "" and config.x and config.y ) then
		frame:ClearAllPoints()
		frame:SetPoint(config.point, anchorTo, config.relativePoint, config.x / scale, config.y / scale)
	end
end

-- Setup the main frame
function Layout:ApplyUnitFrame(frame, config)
	local backdrop = ShadowUF.db.profile.backdrop
	local id = backdrop.backgroundTexture .. backdrop.borderTexture .. backdrop.tileSize .. backdrop.edgeSize .. backdrop.tileSize .. backdrop.inset
	local backdropTbl = backdropCache[id] or {
			bgFile = mediaPath.background,
			edgeFile = mediaPath.border,
			tile = backdrop.tileSize > 0 and true or false,
			edgeSize = backdrop.edgeSize,
			tileSize = backdrop.tileSize,
			insets = {left = backdrop.inset, right = backdrop.inset, top = backdrop.inset, bottom = backdrop.inset}
	}
	backdropCache[id] = backdropTbl
		
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
	
	frameList[frame] = true
		
	-- Anything parented to us?
	for queuedFrame in pairs(anchoringQueued) do
		if( queuedFrame.queuedName == frame:GetName() ) then
			self:AnchorFrame(queuedFrame.queuedParent, queuedFrame, queuedFrame.queuedConfig)

			queuedFrame.queuedParent = nil
			queuedFrame.queuedConfig = nil
			anchoringQueued[queuedFrame] = nil
		end
	end
end

-- Setup portraits
function Layout:ApplyPortrait(frame, config)
	-- We want it to be a pixel inside the frame, so inset + clip gets us that
	local clip = ShadowUF.db.profile.backdrop.inset + ShadowUF.db.profile.backdrop.clip
	
	self:ToggleVisibility(frame.portrait, frame.visibility.portrait)
	if( frame.portrait and frame.portrait:IsShown() ) then
		frame.portrait:ClearAllPoints()
		frame.portrait:SetHeight(config.height - (clip * 2))
		frame.portrait:SetWidth(config.width * config.portrait.width)

		frame.barFrame:ClearAllPoints()
		frame.barFrame:SetHeight(frame:GetHeight() - (clip * 2))

		-- Flip the alignment for targets to keep the same look as default
		local position = config.portrait.alignment
		if( frame:GetAttribute("unit") and not config.portrait.noAutoAlign and ( frame.unit == "target" or string.match(frame.unit, "%w+target") ) ) then
			position = config.portrait.alignment == "LEFT" and "RIGHT" or "LEFT"
		end

		if( position == "LEFT" ) then
			frame.portrait:SetPoint("TOPLEFT", frame, "TOPLEFT", clip, -clip)
			frame.barFrame:SetPoint("RIGHT", frame.portrait)
			frame.barFrame:SetPoint("RIGHT", frame, -clip, 0)
			frame.barFrame:SetWidth(frame:GetWidth() - (clip * 2) - frame.portrait:GetWidth() - ShadowUF.db.profile.backdrop.clip)
		else
			frame.portrait:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -clip, -clip)
			frame.barFrame:SetPoint("LEFT", frame.portrait)
			frame.barFrame:SetPoint("LEFT", frame, clip, 0)
			frame.barFrame:SetWidth(frame:GetWidth() - (clip * 2) - frame.portrait:GetWidth() - ShadowUF.db.profile.backdrop.clip)
		end
	else
		frame.barFrame:ClearAllPoints()
		frame.barFrame:SetPoint("TOPLEFT", frame, "TOPLEFT", clip, -clip)
		frame.barFrame:SetHeight(frame:GetHeight() - (clip * 2))
		frame.barFrame:SetWidth(frame:GetWidth() - (clip * 2))
	end
end

-- Setup bars
function Layout:ApplyBarVisuals(frame, config)
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
function Layout:ApplyText(frame, config)
	-- Update cast bar text
	if( frame.castBar and frame.castBar:IsShown() ) then
		-- Set the font at the very least, so it doesn't error when we set text on it even if it isn't being shown
		frame.castBar.name:SetFont(mediaPath.font, ShadowUF.db.profile.font.size)
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
		
		frame.castBar.time:SetFont(mediaPath.font, ShadowUF.db.profile.font.size)
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
		fontString:Hide()
	end
	
	for k in pairs(totalWeight) do totalWeight[k] = nil end
	
	-- Update the actual text, and figure out the weighting information now
	for id, row in pairs(config.text) do
		local parent = row.anchorTo == "$parent" and frame or frame[string.sub(row.anchorTo, 2)]
		if( parent and parent:IsShown() and row.enabled and row.text ~= "" ) then
			local fontString = frame.fontStrings[id] or frame:CreateFontString(nil, "ARTWORK")
			fontString:SetFont(mediaPath.font, ShadowUF.db.profile.font.size + row.size)
			fontString:SetText(row.text)
			fontString:SetParent(frame.highFrame)
			fontString:SetJustifyH(self:GetJustify(row))
			self:AnchorFrame(frame, fontString, row)
			
			local anchorPoint = (row.anchorPoint == "ITR" or row.anchorPoint == "ITL") and "IT" or (row.anchorPoint == "ICL" or row.anchorPoint == "ICR" ) and "IC" or row.anchorPoint
			
			fontString.availableWidth = parent:GetWidth()
			fontString.widthID = row.anchorTo .. anchorPoint .. row.y
			totalWeight[fontString.widthID] = (totalWeight[fontString.widthID] or 0) + row.width
			
			updateShadows(fontString)
			
			ShadowUF.Tags:Register(frame, fontString, row.text)
			fontString:UpdateTags()
			fontString:Show()
			
			frame.fontStrings[id] = fontString
			frame:RegisterUpdateFunc(fontString, "UpdateTags")
		
		-- Tag was enabled, but it no longer is
		elseif( frame.fontStrings[id] ) then
			frame.fontStrings[id].fastPower = nil
			frame.fontStrings[id].fastHealth = nil
			frame.fontStrings[id]:Hide()
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
function Layout:ApplyIndicators(frame, config)
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
			if( indicator.enabled ) then
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
function Layout:ApplyAuras(frame, config)
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

-- Setup the bar ordering/info
local currentConfig
local function sortOrder(a, b)
	return ((currentConfig[a].order or 100) < (currentConfig[b].order or 100))
end

function Layout:ApplyBars(frame, config)
	-- Figure out the height of a few widgets, and set the size/positioning correctly
	local totalWeight = 0
	local totalBars = -1

	for i=#(ordering), 1, -1 do table.remove(ordering, i) end
	for _, module in pairs(ShadowUF.modules) do
		if( module.moduleHasBar and frame[module.moduleKey] and config[module.moduleKey].height and frame[module.moduleKey]:IsShown() ) then
			totalWeight = totalWeight + config[module.moduleKey].height
			totalBars = totalBars + 1
			
			table.insert(ordering, module.moduleKey)
		end
	end
	
	currentConfig = config
	table.sort(ordering, sortOrder)
		
	local lastFrame
	local availableHeight = frame.barFrame:GetHeight() - (math.abs(ShadowUF.db.profile.bars.spacing) * totalBars)
	for id, key in pairs(ordering) do
		local bar = frame[key]
		bar:ClearAllPoints()
		bar:SetWidth(frame.barFrame:GetWidth())
		bar:SetHeight(availableHeight * (config[key].height / totalWeight))
		
		if( id > 1 ) then
			bar:SetPoint("TOPLEFT", lastFrame, "BOTTOMLEFT", 0, ShadowUF.db.profile.bars.spacing)
		else
			bar:SetPoint("TOPLEFT", frame.barFrame, "TOPLEFT", 0, 0)
		end
		
		lastFrame = bar
	end
end



 