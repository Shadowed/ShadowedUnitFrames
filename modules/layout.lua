local Layout = ShadowUF:NewModule("Layout", "AceEvent-3.0")
local SML, config
local ordering = {}
	
local function orderSort(a, b)
	return (config[a].order < config[b].order)
end

function Layout:LoadSML()
	SML = SML or LibStub:GetLibrary("LibSharedMedia-3.0")
	SML:Register(SML.MediaType.FONT, "Myriad Condensed Web", "Interface\\AddOns\\ShadowedUnitFrames\\media\\fonts\\Myriad Condensed Web.ttf")
	SML:Register(SML.MediaType.STATUSBAR, "BantoBar", "Interface\\Addons\\ShadowedUnitFrames\\media\\textures\\banto")
	SML:Register(SML.MediaType.STATUSBAR, "Smooth",   "Interface\\Addons\\ShadowedUnitFrames\\media\\textures\\smooth")
	SML:Register(SML.MediaType.STATUSBAR, "Perl",     "Interface\\Addons\\ShadowedUnitFrames\\media\\textures\\perl")
	SML:Register(SML.MediaType.STATUSBAR, "Glaze",    "Interface\\Addons\\ShadowedUnitFrames\\media\\textures\\glaze")
	SML:Register(SML.MediaType.STATUSBAR, "Charcoal", "Interface\\Addons\\ShadowedUnitFrames\\media\\textures\\Charcoal")
	SML:Register(SML.MediaType.STATUSBAR, "Otravi",   "Interface\\Addons\\ShadowedUnitFrames\\media\\textures\\otravi")
	SML:Register(SML.MediaType.STATUSBAR, "Striped",  "Interface\\Addons\\ShadowedUnitFrames\\media\\textures\\striped")
	SML:Register(SML.MediaType.STATUSBAR, "LiteStep", "Interface\\Addons\\ShadowedUnitFrames\\media\\textures\\LiteStep")
	SML:Register(SML.MediaType.STATUSBAR, "Aluminium", "Interface\\Addons\\ShadowedUnitFrames\\media\\textures\\Aluminium")
end

-- NTS: Eventually, this needs to be changed to do some sort of magic when it comes to positioning everything
-- eg, player frame anchored to target frame, target frame not created yet
function Layout:AnchorFrame(parent, frame, config)
	if( not config ) then
		return
	end
	
	local anchorTo
	if( config.anchorTo == "$parent" ) then
		anchorTo = parent
	elseif( string.sub(config.anchorTo, 0, 1) == "$" ) then
		anchorTo = parent[string.sub(config.anchorTo, 2)]
	else
		anchorTo = config.anchorTo
	end
	
	local scale = 1
	if( config.applyEffective ) then
		scale = parent:GetEffectiveScale()
	end

	frame:ClearAllPoints()
	frame:SetPoint(config.point, anchorTo, config.relativePoint, config.x / scale, config.y / scale)
end

function Layout:Apply(frame, unit)
	config = ShadowUF.db.profile.layout
	if( not config[unit] ) then
		return
	end
	
	SML = SML or LibStub:GetLibrary("LibSharedMedia-3.0")
	
	local backdrop = {
			bgFile = config.backdrop.backgroundTexture,
			edgeFile = config.backdrop.borderTexture,
			tile = config.backdrop.tileSize > 0 and true or false,
			edgeSize = config.backdrop.edgeSize,
			tileSize = config.backdrop.tileSize,
			insets = {left = config.backdrop.inset, right = config.backdrop.inset, top = config.backdrop.inset, bottom = config.backdrop.inset}
	}
		
	frame:SetHeight(config[unit].height)
	frame:SetWidth(config[unit].width)
	frame:SetScale(config[unit].scale)
	frame:SetBackdrop(backdrop)
	frame:SetBackdropColor(config.backdrop.backgroundColor.r, config.backdrop.backgroundColor.g, config.backdrop.backgroundColor.b, config.backdrop.backgroundColor.a)
	frame:SetBackdropBorderColor(config.backdrop.borderColor.r, config.backdrop.borderColor.g, config.backdrop.borderColor.b, config.backdrop.borderColor.a)
	frame:SetClampedToScreen(true)
	frame.barTexture = SML:Fetch(SML.MediaType.STATUSBAR, config.general.barTexture)
	
	-- Prevents raid and party frames from being anchored
	if( not frame.isGroupHeaderUnit ) then
		self:AnchorFrame(UIParent, frame, config[unit])
	end
	
	-- We want it to be a pixel inside the frame, so inset + 1 * 2 gets us that
	local clip = config.backdrop.inset + config.general.clip

	-- Position portrait, this is the "important" one
	if( frame.portrait and frame.portrait:IsShown() ) then
		frame.portrait:SetHeight(config[unit].height - (clip * 2))
		frame.portrait:SetWidth(config[unit].width * config.portrait.width)

		frame.barFrame:SetHeight(frame:GetHeight() - (clip * 2))

		-- Flip the alignment for targets to keep the same look as default
		local position = config.portrait.alignment
		if( unit == "target" or string.match(unit, "%w+target") ) then
			position = config.portrait.alignment == "LEFT" and "RIGHT" or "LEFT"
		end

		if( position == "LEFT" ) then
			frame.portrait:SetPoint("TOPLEFT", frame, "TOPLEFT", clip, -clip)
			frame.barFrame:SetPoint("RIGHT", frame.portrait)
			frame.barFrame:SetPoint("RIGHT", frame, -clip, 0)
			frame.barFrame:SetWidth(frame:GetWidth() - (clip * 2) - frame.portrait:GetWidth() - config.general.clip)
		else
			frame.portrait:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -clip, -clip)
			frame.barFrame:SetPoint("LEFT", frame.portrait)
			frame.barFrame:SetPoint("LEFT", frame, clip, 0)
			frame.barFrame:SetWidth(frame:GetWidth() - (clip * 2) - frame.portrait:GetWidth() - config.general.clip)
		end
	else
		frame.barFrame:SetPoint("TOPLEFT", frame, "TOPLEFT", clip, -clip)
		frame.barFrame:SetHeight(frame:GetHeight() - (clip * 2))
		frame.barFrame:SetWidth(frame:GetWidth() - (clip * 2))
	end
	
	-- Update health bars
	if( frame.healthBar and frame.healthBar:IsShown() ) then
		frame.healthBar:SetStatusBarTexture(frame.barTexture)
		
		if( config.healthBar.background ) then
			frame.healthBar.background:SetTexture(frame.barTexture)
			frame.healthBar.background:Show()
		else
			frame.healthBar.background:Hide()
		end
	end
	
	-- Update mana bars
	if( frame.manaBar and frame.manaBar:IsShown() ) then
		frame.manaBar:SetStatusBarTexture(frame.barTexture)

		if( config.manaBar.background ) then
			frame.manaBar.background:SetTexture(frame.barTexture)
			frame.manaBar.background:Show()
		else
			frame.manaBar.background:Hide()
		end
	end
	
	-- Update XP bar
	if( frame.xpBar and frame.xpBar:IsShown() ) then
		frame.xpBar:SetStatusBarTexture(frame.barTexture)
		frame.xpBar.rested:SetStatusBarTexture(frame.barTexture)
		
		if( config.xpBar.background ) then
			frame.xpBar.background:SetTexture(frame.barTexture)
			frame.xpBar.background:Show()
		else
			frame.xpBar.background:Hide()
		end
	end
	
	-- Create text
	if( ShadowUF.db.profile.units[unit].text ) then
		frame.fontStrings = frame.fontStrings or {}
		for _, fontString in pairs(frame.fontStrings) do
			fontString:Hide()
		end
		
		for id, row in pairs(ShadowUF.db.profile.units[unit].text) do
			local bar = row.anchorTo == "$parent" and frame or frame[string.sub(row.anchorTo, 2)]
			if( bar ) then
				local fontString = frame.fontStrings[id] or frame:CreateFontString(nil, "ARTWORK")
				fontString:SetFont(SML:Fetch(SML.MediaType.FONT, config.font.name), config.font.size)
				fontString:SetText(row.text)
				fontString:SetParent(bar)
				fontString:SetJustifyH(row.point)
				self:AnchorFrame(frame, fontString, row)
											
				if( row.widthPercent ) then
					fontString:SetWidth(bar:GetWidth() * row.widthPercent)
					fontString:SetHeight(config.font.size + 1)
				elseif( row.height or row.width ) then
					fontString:SetWidth(row.height or 0)
					fontString:SetHeight(row.width or 0)
				end
				
				if( config.font.shadowColor and config.font.shadowX and config.font.shadowY ) then
					fontString:SetShadowColor(config.font.shadowColor.r, config.font.shadowColor.g, config.font.shadowColor.b, config.font.shadowColor.a)
					fontString:SetShadowOffset(config.font.shadowX, config.font.shadowY)
				else
					fontString:SetShadowColor(0, 0, 0, 0)
				end
				
				ShadowUF.modules.Tags:Register(frame, fontString, row.text)
				fontString:UpdateTags()
				fontString:Show()
				
				frame.fontStrings[id] = fontString
				frame:RegisterUpdateFunc(fontString, "UpdateTags")
			end
		end
	end
	
	-- Position indicators
	if( frame.indicators and config[unit].indicators ) then
		for key, indicator in pairs(frame.indicators) do
			if( config[unit].indicators[key] ) then
				indicator:SetHeight(config[unit].indicators[key].height)
				indicator:SetWidth(config[unit].indicators[key].width)
				
				self:AnchorFrame(frame, indicator, config[unit].indicators[key])
			end
		end
	end
	
	self:SetupBars(frame, config)
	
	-- Layouts been fully set
	ShadowUF:FireModuleEvent("LayoutApplied", frame, unit)
end

function Layout:SetupBars(frame, config)
	-- Figure out the height of a few widgets, and set the size/positioning correctly
	local totalWeight = 0
	local totalBars = -1
	for key, data in pairs(config) do
			if( data.heightWeight and frame[key] and frame[key]:IsShown() ) then
				totalWeight = totalWeight + data.heightWeight
				totalBars = totalBars + 1
			end
	end

	for i=#(ordering), 1, -1 do table.remove(ordering, i) end
	for key, data in pairs(config) do
		if( data.order and frame[key] and frame[key]:IsShown() ) then
			table.insert(ordering, key)
		end
	end
	
	table.sort(ordering, sortOrder)
	
	local availableHeight = frame.barFrame:GetHeight() - (math.abs(config.general.barSpacing) * totalBars)
	local lastFrame
	for id, key in pairs(ordering) do
		local barConfig = config[key]
		local bar = frame[key]
		bar:ClearAllPoints()
		bar:SetWidth(frame.barFrame:GetWidth())
		bar:SetHeight(availableHeight * (barConfig.heightWeight / totalWeight))
		
		if( id > 1 ) then
				bar:SetPoint("TOPLEFT", lastFrame, "BOTTOMLEFT", 0, config.general.barSpacing)
		else
				bar:SetPoint("TOPLEFT", frame.barFrame, "TOPLEFT", 0, 0)
		end
		
		lastFrame = bar
	end
end










 