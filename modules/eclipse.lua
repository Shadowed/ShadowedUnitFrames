-- Moon on left, Sun on right
-- Cast Arcane -> Move to Sun (Buff Nature)
-- Cast Nature -> Move to Moon (Buff Arcane)
local Eclipse = {types = {"sun", "moon"}}
ShadowUF:RegisterModule(Eclipse, "eclipseBar", ShadowUF.L["Eclipse bar"], true, "DRUID")

local function updatePower(self)
	local power = UnitPower(self.parent.unit, ECLIPSE_BAR_POWER_INDEX)
	local maxPower = UnitPowerMax(self.parent.unit, ECLIPSE_BAR_POWER_INDEX)
	if( power == self.currentPower and maxPower == self.currentPower ) then return end
	self.currentPower = power
	self.currentMax = maxPower
	
	self:SetMinMaxValues(0, maxPower)
	self:SetValue(power)
	
	-- Only update the eclipse coloring if we're doing a state change
	if( self.maxPower and power < maxPower ) then
		self.maxPower = nil
		self.parent:SetBarColor("eclipseBar", ShadowUF.db.profile.units[self.parent.unit].eclipseBar.invert, ShadowUF.db.profile.powerColors.ECLIPSE.r, ShadowUF.db.profile.powerColors.ECLIPSE.g, ShadowUF.db.profile.powerColors.ECLIPSE.b)
	elseif( not self.maxPower and power == maxPower ) then
		self.maxPower = true
		self.parent:SetBarColor("eclipseBar", ShadowUF.db.profile.units[self.parent.unit].eclipseBar.invert, ShadowUF.db.profile.powerColors.ECLIPSE_FULL.r, ShadowUF.db.profile.powerColors.ECLIPSE_FULL.g, ShadowUF.db.profile.powerColors.ECLIPSE_FULL.b)
	end
end

function Eclipse:OnEnable(frame)
	if( not frame.eclipseBar ) then
		frame.eclipseBar = CreateFrame("Frame", nil, frame)
		for _, type in pairs(self.types) do
			frame.eclipseBar[type] = frame.eclipseBar:CreateTexture(nil, "ARTWORK")
			frame.eclipseBar[type].icon = frame.eclipseBar:CreateTexture(nil, "ARTWORK")
			frame.eclipseBar[type].icon:SetTexture("Interface\\PlayerFrame\\UI-DruidEclipse")
		end
	
		frame.eclipseBar.moon:SetTexture("Interface\\Icons\\Spell_Arcane_StarFire")
		frame.eclipseBar.sun:SetTexture("Interface\\Icons\\Spell_Nature_AbolishMagic")

		--frame.eclipseBar.sun:SetTexture(0.26562500, 0.50781250, 0.00781250, 0.24218750)
		--frame.eclipseBar.moon:SetTexCoord(0.00781250, 0.25000000, 0.00781250, 0.24218750)
	end
	
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
		frame.eclipseBar[type].icon:SetSize(frame.eclipseBar:GetHeight(), frame.eclipseBar:GetHeight())
	end
	
	frame.eclipseBar.moon.icon:SetPoint("TOPLEFT", frame.eclipseBar, "TOPLEFT", 0, 0)
	frame.eclipseBar.moon:SetPoint("TOPLEFT", frame.eclipseBar.moon.icon, "TOPRIGHT")
	frame.eclipseBar.moon:SetPoint("BOTTOMLEFT", frame.eclipseBar.moon.icon, "BOTTOMRIGHT")
	
	frame.eclipseBar.sun.icon:SetPoint("TOPRIGHT", frame.eclipseBar.bar, "TOPLEFT", 0, 0)
	frame.eclipseBar.sun:SetPoint("TOPRIGHT", frame.eclipseBar.bar, "TOPLEFT", 0, 0)
	frame.eclipseBar.sun:SetPoint("BOTTOMRIGHT", frame.eclipseBar.bar, "BOTTOMLEFT", 0, 0)
end

function Eclipse:UpdateVisibility(frame)
	ShadowUF.Layout:SetBarVisibility(frame, "eclipseBar", GetShapeshiftFormID() == MOONKIN_FORM and GetMasteryIndex(GetActiveTalentGroup()) == 1)
end