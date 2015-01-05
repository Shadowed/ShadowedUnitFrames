-- Moon on left, Sun on right
local Eclipse = {types = {"sun", "moon"}}
ShadowUF:RegisterModule(Eclipse, "eclipseBar", ShadowUF.L["Eclipse bar"], true, "DRUID", 1)

function Eclipse:OnEnable(frame)
	if( not frame.eclipseBar ) then
		frame.eclipseBar = CreateFrame("Frame", nil, frame)
		-- the arrow marker
		frame.eclipseBar.marker = CreateFrame("Frame", nil, frame.eclipseBar)
		frame.eclipseBar.marker:SetPoint("CENTER", frame.eclipseBar)
		frame.eclipseBar.marker:SetFrameLevel(frame.topFrameLevel + 5)
		frame.eclipseBar.marker.texture = frame.eclipseBar.marker:CreateTexture(nil, "OVERLAY")
		frame.eclipseBar.marker.texture:SetAtlas("DruidEclipse-Arrow")
		frame.eclipseBar.marker.texture:SetTexCoord(1.0, 0.914, 0.82, 1.0)
		frame.eclipseBar.marker.texture:SetVertexColor(1, 1, 1, 1)
		frame.eclipseBar.marker.texture:SetBlendMode("ADD")
		frame.eclipseBar.marker.texture:SetAllPoints(frame.eclipseBar.marker)
		
		-- the actual bar textures
		frame.eclipseBar.moon = frame.eclipseBar:CreateTexture(nil, "ARTWORK")
		frame.eclipseBar.moon:SetPoint("TOPLEFT", frame.eclipseBar, "TOPLEFT")
		frame.eclipseBar.moon:SetPoint("BOTTOMRIGHT", frame.eclipseBar, "BOTTOM")
		
		frame.eclipseBar.sun = frame.eclipseBar:CreateTexture(nil, "ARTWORK")
		frame.eclipseBar.sun:SetPoint("TOPRIGHT", frame.eclipseBar, "TOPRIGHT")
		frame.eclipseBar.sun:SetPoint("BOTTOMLEFT", frame.eclipseBar, "BOTTOM")

		for _, type in pairs(self.types) do
			local typeFrame = frame.eclipseBar[type]
			typeFrame.highlight = CreateFrame("Frame", nil, frame.eclipseBar)
			typeFrame.highlight:SetFrameLevel(frame.topFrameLevel)
			typeFrame.highlight:SetAllPoints(typeFrame)
			typeFrame.highlight:SetSize(1, 1)

			typeFrame.highlight.top = typeFrame.highlight:CreateTexture(nil, "OVERLAY")
			typeFrame.highlight.top:SetBlendMode("ADD")
			typeFrame.highlight.top:SetTexture("Interface\\AddOns\\ShadowedUnitFrames\\media\\textures\\highlight")
			typeFrame.highlight.top:SetPoint("TOPLEFT", typeFrame, 0, 0)
			typeFrame.highlight.top:SetPoint("TOPRIGHT", typeFrame, 0, 0)
			typeFrame.highlight.top:SetHeight(30)
			typeFrame.highlight.top:SetTexCoord(0.3125, 0.625, 0, 0.3125)
			typeFrame.highlight.top:SetHorizTile(false)
			
			typeFrame.highlight.left = typeFrame.highlight:CreateTexture(nil, "OVERLAY")
			typeFrame.highlight.left:SetBlendMode("ADD")
			typeFrame.highlight.left:SetTexture("Interface\\AddOns\\ShadowedUnitFrames\\media\\textures\\highlight")
			typeFrame.highlight.left:SetPoint("TOPLEFT", typeFrame, 0, 0)
			typeFrame.highlight.left:SetPoint("BOTTOMLEFT", typeFrame, 0, 0)
			typeFrame.highlight.left:SetWidth(30)
			typeFrame.highlight.left:SetTexCoord(0, 0.3125, 0.3125, 0.625)
			typeFrame.highlight.left:SetHorizTile(false)

			typeFrame.highlight.right = typeFrame.highlight:CreateTexture(nil, "OVERLAY")
			typeFrame.highlight.right:SetBlendMode("ADD")
			typeFrame.highlight.right:SetTexture("Interface\\AddOns\\ShadowedUnitFrames\\media\\textures\\highlight")
			typeFrame.highlight.right:SetPoint("TOPRIGHT", typeFrame, 0, 0)
			typeFrame.highlight.right:SetPoint("BOTTOMRIGHT", typeFrame, 0, 0)
			typeFrame.highlight.right:SetWidth(30)
			typeFrame.highlight.right:SetTexCoord(0.625, 0.93, 0.3125, 0.625)
			typeFrame.highlight.right:SetHorizTile(false)

			typeFrame.highlight.bottom = typeFrame.highlight:CreateTexture(nil, "OVERLAY")
			typeFrame.highlight.bottom:SetBlendMode("ADD")
			typeFrame.highlight.bottom:SetTexture("Interface\\AddOns\\ShadowedUnitFrames\\media\\textures\\highlight")
			typeFrame.highlight.bottom:SetPoint("BOTTOMLEFT", typeFrame, 0, 0)
			typeFrame.highlight.bottom:SetPoint("BOTTOMRIGHT", typeFrame, 0, 0)
			typeFrame.highlight.bottom:SetHeight(30)
			typeFrame.highlight.bottom:SetTexCoord(0.3125, 0.625, 0.625, 0.93)
			typeFrame.highlight.bottom:SetHorizTile(false)
			typeFrame.highlight:Hide()
		end
	end

	frame:RegisterUnitEvent("UNIT_POWER_FREQUENT", self, "Update")
	frame:RegisterUnitEvent("UNIT_MAXPOWER", self, "Update")
	frame:RegisterNormalEvent("ECLIPSE_DIRECTION_CHANGE", self, "UpdateDirection")
	frame:RegisterNormalEvent("UPDATE_SHAPESHIFT_FORM", self, "UpdateVisibility")
	
	frame:RegisterUpdateFunc(self, "UpdateVisibility")
end

function Eclipse:OnDisable(frame)
	frame:UnregisterAll(self)
end

function Eclipse:OnLayoutApplied(frame)
	if( not frame.visibility.eclipseBar ) then return end
	
	local highlightSize = math.ceil(frame.eclipseBar:GetHeight())
	for _, type in pairs(self.types) do
		local color = ShadowUF.db.profile.powerColors["ECLIPSE_" .. string.upper(type)]
		frame.eclipseBar[type]:SetTexture(ShadowUF.Layout.mediaPath.statusbar)
		frame.eclipseBar[type]:SetVertexColor(color.r, color.g, color.b)
		frame.eclipseBar[type]:SetHorizTile(false)

		for _, type in pairs(self.types) do
			local typeFrame = frame.eclipseBar[type]
			typeFrame.highlight.top:SetVertexColor(color.r, color.g, color.b, 0.9)
			typeFrame.highlight.top:SetHeight(highlightSize)

			typeFrame.highlight.bottom:SetVertexColor(color.r, color.g, color.b, 0.9)
			typeFrame.highlight.bottom:SetHeight(highlightSize)

			typeFrame.highlight.left:SetVertexColor(color.r, color.g, color.b, 0.9)
			typeFrame.highlight.left:SetWidth(highlightSize)

			typeFrame.highlight.right:SetVertexColor(color.r, color.g, color.b, 0.9)
			typeFrame.highlight.right:SetWidth(highlightSize)
		end
	end

	frame.eclipseBar.marker:SetSize(frame.eclipseBar:GetHeight() * 2, frame.eclipseBar:GetHeight() * 2)

	
	self:UpdateVisibility(frame)
end

function Eclipse:UpdateVisibility(frame)
	local form = GetShapeshiftFormID()
	ShadowUF.Layout:SetBarVisibility(frame, "eclipseBar", form == MOONKIN_FORM or not form and not frame.inVehicle)
	self:UpdateDirection(frame)
	self:Update(frame, nil, nil, "ECLIPSE")
end

function Eclipse:UpdateDirection(frame)
	local direction = GetEclipseDirection()
	if( direction ) then
		frame.eclipseBar.marker.texture:SetTexCoord(unpack(ECLIPSE_MARKER_COORDS[direction]))
	end
end

function Eclipse:Update(frame, event, unit, powerType)
	if( event and powerType ~= "ECLIPSE" ) then return end

	local power = UnitPower("player", SPELL_POWER_ECLIPSE)
	local halfWidth = (frame.eclipseBar:GetWidth() - frame.eclipseBar.marker:GetWidth()) / 2
	local x = halfWidth * (power / 100)
	frame.eclipseBar.marker:SetPoint("CENTER", frame.eclipseBar, "CENTER", x, 0)

	-- Sun power
	if( power > 0 ) then
		frame.eclipseBar.sun.highlight:Show()
		frame.eclipseBar.moon.highlight:Hide()
	-- Moon power
	elseif( power < 0 ) then
		frame.eclipseBar.sun.highlight:Hide()
		frame.eclipseBar.moon.highlight:Show()
	-- No power
	else
		frame.eclipseBar.sun.highlight:Hide()
		frame.eclipseBar.moon.highlight:Hide()
	end
end
