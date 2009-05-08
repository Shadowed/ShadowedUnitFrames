local Layout = ShadowUF:NewModule("Layout", "AceEvent-3.0")
local SML, config
local ordering = {}
	
local function orderSort(a, b)
	return (config[a].order < config[b].order)
end

function Layout:LoadSML()
	SML = SML or LibStub:GetLibrary("LibSharedMedia-3.0")
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
	frame:Show()
	
	if( config[unit] ) then
		frame:SetPoint(config[unit].point, config[unit].anchorTo, config[unit].relativeTo, config[unit].x, config[unit].y)
	end
	
	-- We want it to be a pixel inside the frame, so inset + 1 * 2 gets us that
	local clip = config.backdrop.inset + (config.general.clip or 1)

	-- Position portrait, this is the "important" one
	if( frame.portrait ) then
		frame.portrait:SetHeight(config[unit].height - (clip * 2))
		frame.portrait:SetWidth(config[unit].width * config.portrait.width)

		frame.barFrame:SetHeight(frame:GetHeight() - (clip * 2))

		-- Flip the alignment for targets to keep the same look as default
		local position = config.portrait.alignment
		if( string.match(unit, "%w+target") ) then
			position = config.portrait.alignment == "LEFT" and "RIGHT" or "LEFT"
		end

		if( position == "LEFT" ) then
			frame.portrait:SetPoint("TOPLEFT", frame, "TOPLEFT", clip, -clip)
			frame.barFrame:SetPoint("RIGHT", frame.portrait)
			frame.barFrame:SetPoint("RIGHT", frame, -clip, 0)
			frame.barFrame:SetWidth(frame:GetWidth() - (clip * 2) - frame.portrait:GetWidth() - 3)
		else
			frame.portrait:SetPoint("TOPRIGHT", frame, "TOPLEFT", -clip, -clip)
			frame.barFrame:SetPoint("LEFT", frame.portrait)
			frame.barFrame:SetPoint("LEFT", frame, config.backdrop.inset, 0)
			frame.barFrame:SetWidth(frame:GetWidth() - (clip * 2) - frame.portrait:GetWidth() - 3)
		end
	else
		frame.barFrame:SetPoint("TOPLEFT", frame, "TOPLEFT", clip, -clip)
		frame.barFrame:SetHeight(frame:GetHeight() - (clip *2))
		frame.barFrame:SetWidth(frame:GetWidth() - (clip * 2))
	end
	
	if( frame.healthBar ) then
		frame.healthBar:SetStatusBarTexture(SML:Fetch(SML.MediaType.STATUSBAR, config.general.barTexture))
	end
	
	if( frame.manaBar ) then
		frame.manaBar:SetStatusBarTexture(SML:Fetch(SML.MediaType.STATUSBAR, config.general.barTexture))
	end
	
	-- Create text
	if( ShadowUF.db.profile.units[unit].text ) then
		for _, row in pairs(ShadowUF.db.profile.units[unit].text) do
			local bar = frame[row.anchorTo]
			if( bar ) then
				local fontString = bar:CreateFontString(nil, "ARTWORK")
				fontString:SetFont(SML:Fetch(SML.MediaType.FONT, config.font.name), config.font.size)
				fontString:SetText(row.text)
				fontString:SetPoint(row.point, bar, row.relativePoint, row.x, row.y)
				
				if( config.font.shadowColor and config.font.shadowX and config.font.shadowY ) then
					fontString:SetShadowColor(config.font.shadowColor.r, config.font.shadowColor.g, config.font.shadowColor.b, config.font.shadowColor.a)
					fontString:SetShadowOffset(config.font.shadowX, config.font.shadowY)
				else
					fontString:SetShadowColor(0, 0, 0, 0)
				end
				
				ShadowUF.modules.Tags:Register(frame, fontString, row.text)
				fontString:UpdateTags()
			end
		end
	end
	
	
	-- Figure out the height of a few widgets, and set the size/positioning correctly
	local totalWeight = 0
	local totalBars = -1
	for _, data in pairs(config) do
			if( data.heightWeight ) then
				totalWeight = totalWeight + data.heightWeight
				totalBars = totalBars + 1
			end
	end

	for i=#(ordering), 1, -1 do table.remove(ordering, i) end

	for key, data in pairs(config) do
		if( data.order ) then
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
	
	-- Layouts been fully setup
	self:SendMessage("SUF_LAYOUT_SET", frame)
end











 