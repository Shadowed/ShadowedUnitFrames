local Combo = {}
ShadowUF:RegisterModule(Combo, "comboPoints", ShadowUF.L["Combo points"])
local cpConfig = {max = MAX_COMBO_POINTS, key = "comboPoints", icon = "Interface\\AddOns\\ShadowedUnitFrames\\media\\textures\\combo"}

function Combo:OnEnable(frame)
	frame.comboPoints = frame.comboPoints or CreateFrame("Frame", nil, frame)
	frame.comboPoints.config = cpConfig
	frame.comboPointType = cpvisualConfig.key
	frame:RegisterNormalEvent("UNIT_COMBO_POINTS", self, "Update")
	frame:RegisterUpdateFunc(self, "Update")
end

function Combo:OnLayoutApplied(frame, config)
	local key = frame.comboPointType
	local pointsFrame = frame[key]
	local pointsConfig = pointsFrame.config
	config = config[key]
	-- Not a bar so set the containers frame configuration
	if( config and not visualConfig.isBar ) then
		ShadowUF.Layout:ToggleVisibility(pointsFrame, frame.visibility[key])
	end
	
	if( not frame.visibility[key] ) then return end
	
	-- Hide the active combo points
	if( pointsFrame.points ) then
		for _, texture in pairs(pointsFrame.points) do
			texture:Hide()
		end
	end
	
	-- Setup for bar display!
	if( visualConfig.isBar ) then
		pointsFrame.blocks = pointsFrame.blocks or {}
		pointsFrame.points = pointsFrame.blocks
	
		-- Position bars, the 5 accounts for borders
		local blockWidth = (pointsFrame:GetWidth() - 4 ) / pointsConfig.max
		for id=1, pointsConfig.max do
			pointsFrame.blocks[id] = pointsFrame.blocks[id] or pointsFrame:CreateTexture(nil, "OVERLAY")
			local texture = pointsFrame.blocks[id]
			texture:SetVertexColor(1, 0.80, 0)
			texture:SetHorizTile(false)
			texture:SetTexture(ShadowUF.Layout.mediaPath.statusbar)
			texture:SetHeight(pointsFrame:GetHeight())
			texture:SetWidth(blockWidth)
			texture:ClearAllPoints()
			
			if( visualConfig.growth == "LEFT" ) then
				if( id > 1 ) then
					texture:SetPoint("TOPRIGHT", pointsFrame.blocks[id - 1], "TOPLEFT", -1, 0)
				else
					texture:SetPoint("TOPRIGHT", pointsFrame, "TOPRIGHT", 0, 0)
				end
			else
				if( id > 1 ) then
					texture:SetPoint("TOPLEFT", pointsFrame.blocks[id - 1], "TOPRIGHT", 1, 0)
				else
					texture:SetPoint("TOPLEFT", pointsFrame, "TOPLEFT", 0, 0)
				end
			end
		end

	-- guess not, will have to do icons :(
	else
		local point, relativePoint
		local x, y = 0, 0
		
		if( visualConfig.growth == "LEFT" ) then
			point, relativePoint = "BOTTOMRIGHT", "BOTTOMLEFT"
			x = visualConfig.spacing
		elseif( visualConfig.growth == "RIGHT" ) then
			point, relativePoint = "BOTTOMLEFT", "BOTTOMRIGHT"
			x = visualConfig.spacing
		elseif( visualConfig.growth == "UP" ) then
			point, relativePoint = "BOTTOMLEFT", "TOPLEFT"
			y = visualConfig.spacing
		elseif( visualConfig.growth == "DOWN" ) then
			point, relativePoint = "TOPLEFT", "BOTTOMLEFT"
			y = visualConfig.spacing
		end
		

		pointsFrame.icons = pointsFrame.icons or {}
		pointsFrame.points = pointsFrame.icons
		
		for id=1, pointsConfig.max do
			pointsFrame.icons[id] = pointsFrame.icons[id] or pointsFrame:CreateTexture(nil, "OVERLAY")
			local texture = frame.comboPoints.icons[id]
			texture:SetTexture(pointsConfig.icon)
			texture:SetSize(visualConfig.size, visualConfig.size)
			
			if( id > 1 ) then
				texture:ClearAllPoints()
				texture:SetPoint(point, pointsFrame.icons[id - 1], relativePoint, x, y)
			else
				texture:ClearAllPoints()
				texture:SetPoint("CENTER", pointsFrame, "CENTER", 0, 0)
			end
		end
		
		-- Position the main frame
		pointsFrame:Setsize(0.1, 0.1)
		
		ShadowUF.Layout:AnchorFrame(frame, pointsFrame, visualConfig)
	end
end

function Combo:OnDisable(frame)
	frame:UnregisterAll(self)
end

function Combo:Update(frame)
	-- For Malygos dragons, they also self cast their CP on themselves, which is why we check CP on ourself!
	local playerUnit = UnitHasVehicleUI("player") and "vehicle" or "player"
	local points = GetComboPoints(playerUnit)
	if( points == 0 ) then
		points = GetComboPoints(playerUnit, playerUnit)
	end
	
	-- Bar display, hide it if we don't have any combo points
	if( ShadowUF.db.profile.units[frame.unitType].comboPoints.isBar ) then
		ShadowUF.Layout:SetBarVisibility(frame, "comboPoints", points > 0)
	end
	
	for id, pointTexture in pairs(frame.comboPoints.points) do
		if( id <= points ) then
			pointTexture:Show()
		else
			pointTexture:Hide()
		end
	end
end
