-- Moon on left, Sun on right
-- Cast Arcane -> Move to Sun (Buff Nature)
-- Cast Nature -> Move to Moon (Buff Arcane)
local Eclipse = {types = {"sun", "moon"}}
ShadowUF:RegisterModule(Eclipse, "eclipseBar", ShadowUF.L["Eclipse bar"], true, "DRUID")

function Eclipse:OnEnable(frame)
	if( not frame.eclipseBar ) then
		frame.eclipseBar = CreateFrame("Frame", nil, frame)
		-- the arrow marker
		frame.eclipseBar.marker = CreateFrame("Frame", nil, frame.eclipseBar)
		frame.eclipseBar.marker:SetPoint("CENTER", frame.eclipseBar)
		frame.eclipseBar.marker.texture = frame.eclipseBar.marker:CreateTexture(nil, "OVERLAY")
		frame.eclipseBar.marker.texture:SetTexture([[Interface\PlayerFrame\UI-DruidEclipse]])
		frame.eclipseBar.marker.texture:SetTexCoord(1.0, 0.914, 0.82, 1.0)
		frame.eclipseBar.marker.texture:SetBlendMode("ADD")
		frame.eclipseBar.marker.texture:SetAllPoints(frame.eclipseBar.marker)
		
		-- the actual bar textures
		frame.eclipseBar.moon = frame.eclipseBar:CreateTexture(nil, "ARTWORK")
		frame.eclipseBar.moon:SetPoint("TOPLEFT", frame.eclipseBar, "TOPLEFT")
		frame.eclipseBar.moon:SetPoint("BOTTOMRIGHT", frame.eclipseBar, "BOTTOM")
		
		frame.eclipseBar.sun = frame.eclipseBar:CreateTexture(nil, "ARTWORK")
		frame.eclipseBar.sun:SetPoint("TOPRIGHT", frame.eclipseBar, "TOPRIGHT")
		frame.eclipseBar.sun:SetPoint("BOTTOMLEFT", frame.eclipseBar, "BOTTOM")
	end
	
	frame:RegisterNormalEvent("UNIT_POWER", self, "Update")
	frame:RegisterNormalEvent("UNIT_MAXPOWER", self, "Update")
	frame:RegisterNormalEvent("ECLIPSE_DIRECTION_CHANGE", self, "UpdateDirection")
	frame:RegisterNormalEvent("UPDATE_SHAPESHIFT_FORM", self, "UpdateVisibility")
	frame:RegisterNormalEvent("PLAYER_TALENT_UPDATE", self, "UpdateVisibility")
	frame:RegisterNormalEvent("MASTERY_UPDATE", self, "UpdateVisibility")
	
	frame:RegisterUpdateFunc(self, "UpdateVisibility")
end

function Eclipse:OnDisable(frame)
	frame:UnregisterAll(self)
end

function Eclipse:OnLayoutApplied(frame)
	if( not frame.visibility.eclipseBar ) then return end
	
	for _, type in pairs(self.types) do
		local color = ShadowUF.db.profile.powerColors["ECLIPSE_" .. string.upper(type)]
		frame.eclipseBar[type]:SetTexture(ShadowUF.Layout.mediaPath.statusbar)
		frame.eclipseBar[type]:SetVertexColor(color.r, color.g, color.b)
		frame.eclipseBar[type]:SetHorizTile(false)
	end
	frame.eclipseBar.marker:SetSize(frame.eclipseBar:GetHeight() * 2, frame.eclipseBar:GetHeight() * 2)
	Eclipse:UpdateVisibility(frame)
end

function Eclipse:UpdateVisibility(frame)
	local form = GetShapeshiftFormID()
	ShadowUF.Layout:SetBarVisibility(frame, "eclipseBar", (form == MOONKIN_FORM or not form) and GetPrimaryTalentTree() == 1)
	Eclipse:UpdateDirection(frame)
	Eclipse:Update(frame, nil, nil, "ECLIPSE")
end

function Eclipse:UpdateDirection(frame)
	local direction = GetEclipseDirection()
	if direction then
		frame.eclipseBar.marker.texture:SetTexCoord(unpack(ECLIPSE_MARKER_COORDS[direction]))
	end
end

function Eclipse:Update(frame, event, unit, id)
	if (id == "ECLIPSE") then
		local power = UnitPower("player", SPELL_POWER_ECLIPSE)
		local xpos = (frame.eclipseBar:GetWidth()/2) * (power/100)
		frame.eclipseBar.marker:SetPoint("CENTER", frame.eclipseBar, "CENTER", xpos, 0)
	end
end
