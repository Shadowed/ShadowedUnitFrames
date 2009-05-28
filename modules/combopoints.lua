local Combo = {}
local playerUnit = "player"
ShadowUF:RegisterModule(Combo, "comboPoints", ShadowUFLocals["Combo points"])

function Combo:OnEnable(frame)
	if( not frame.visibility.comboPoints or frame.unitType ~= "target" ) then return end

	if( not frame.comboPoints ) then
		frame.comboPoints = CreateFrame("Frame", nil, frame)
		frame.comboPoints.points = {}
		
		for i=1, MAX_COMBO_POINTS do
			frame.comboPoints.points[i] = frame.comboPoints:CreateTexture(nil, "OVERLAY")
			frame.comboPoints.points[i]:SetTexture("Interface\\AddOns\\ShadowedUnitFrames\\media\\textures\\combo")
		end
	end
		
	frame:RegisterNormalEvent("UNIT_ENTERED_VEHICLE", self, "CheckUnit")
	frame:RegisterNormalEvent("UNIT_EXITED_VEHICLE", self, "CheckUnit")
	frame:RegisterNormalEvent("UNIT_COMBO_POINTS", self, "Update")
	frame:RegisterUpdateFunc(self, "UpdateAll")
end

function Combo:OnPreLayoutApply(frame)
	if( not frame.comboPoints ) then return end
	local config = ShadowUF.db.profile.units[frame.unitType].comboPoints
	local point, relativePoint
	local x, y = 0, 0
	
	if( config.growth == "LEFT" ) then
		point, relativePoint = "BOTTOMRIGHT", "BOTTOMLEFT"
		x = config.spacing
	elseif( config.growth == "RIGHT" ) then
		point, relativePoint = "BOTTOMLEFT", "BOTTOMRIGHT"
		x = config.spacing
	elseif( config.growth == "UP" ) then
		point, relativePoint = "BOTTOMLEFT", "TOPLEFT"
		y = config.spacing
	elseif( config.growth == "DOWN" ) then
		point, relativePoint = "TOPLEFT", "BOTTOMLEFT"
		y = config.spacing
	end
	
	for id, pointTexture in pairs(frame.comboPoints.points) do
		pointTexture:SetHeight(config.size)
		pointTexture:SetWidth(config.size)
		pointTexture:ClearAllPoints()
		
		if( id > 1 ) then
			pointTexture:SetPoint(point, frame.comboPoints.points[id - 1], relativePoint, x, y)
		else
			pointTexture:SetPoint("CENTER", frame.comboPoints, "CENTER", 0, 0)
		end
	end
end

function Combo:OnDisable(frame)
	frame:UnregisterAll(self)
end

function Combo:CheckUnit(frame)
	playerUnit = UnitHasVehicleUI("player") and "vehicle" or "player"
end

function Combo:Update(frame)
	-- For Malygos dragons, they also self cast their CP on themselves, which is why we check CP on ourself!
	local points = GetComboPoints(playerUnit)
	if( points == 0 ) then
		points = GetComboPoints(playerUnit, playerUnit)
	end
	
	for id, pointTexture in pairs(frame.comboPoints.points) do
		if( id <= points ) then
			pointTexture:Show()
		else
			pointTexture:Hide()
		end
	end
end

function Combo:UpdateAll(frame)
	self:CheckUnit(Frame)
	self:Update(frame)
end

