local AuraPoints = {
	isComboPoints = true,
	spells = {
		["MAGE"] = {max = 6, name = GetSpellInfo(36032)},
		["ROGUE"] = {max = 5, name = GetSpellInfo(115189)}
	}
}

AuraPoints.trackSpell = AuraPoints.spells[select(2, UnitClass("player"))]

if( not AuraPoints.trackSpell ) then return end
ShadowUF:RegisterModule(AuraPoints, "auraPoints", ShadowUF.L["Aura Combo Points"])

function AuraPoints:OnEnable(frame)
	frame.auraPoints = frame.auraPoints or CreateFrame("Frame", nil, frame)
	frame:RegisterUnitEvent("UNIT_AURA", self, "Update")
	frame:RegisterUpdateFunc(self, "Update")
end

function AuraPoints:OnLayoutApplied(frame, config)
	local pointsFrame = frame.auraPoints
	if( not pointsFrame ) then return end
	
	pointsFrame:SetFrameLevel(frame.topFrameLevel + 1)
	
	-- Not a bar so set the containers frame configuration
	if( not config.auraPoints.isBar ) then
		ShadowUF.Layout:ToggleVisibility(pointsFrame, frame.visibility[key])
	end
	
	if( not frame.visibility.auraPoints ) then return end
	
	-- Hide the active combo points
	if( pointsFrame.points ) then
		for _, texture in pairs(pointsFrame.points) do
			texture:Hide()
		end
	end
	
	-- Setup for bar display!
	if( config.auraPoints.isBar ) then
		pointsFrame.blocks = pointsFrame.blocks or {}
		pointsFrame.points = pointsFrame.blocks

		pointsFrame.visibleBlocks = AuraPoints.trackSpell.max
	
		-- Position bars, the 5 accounts for borders
		local blockWidth = (pointsFrame:GetWidth() - (AuraPoints.trackSpell.max - 1)) / AuraPoints.trackSpell.max
		for id=1, AuraPoints.trackSpell.max do
			pointsFrame.blocks[id] = pointsFrame.blocks[id] or pointsFrame:CreateTexture(nil, "OVERLAY")

			local texture = pointsFrame.blocks[id]
			local color = ShadowUF.db.profile.powerColors.AURAPOINTS
			texture:SetVertexColor(color.r, color.g, color.b, color.a)
			texture:SetHorizTile(false)
			texture:SetTexture(ShadowUF.Layout.mediaPath.statusbar)
			texture:SetHeight(pointsFrame:GetHeight())
			texture:SetWidth(blockWidth)
			texture:ClearAllPoints()
			
			if( config.growth == "LEFT" ) then
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
		
		if( config.auraPoints.growth == "LEFT" ) then
			point, relativePoint = "BOTTOMRIGHT", "BOTTOMLEFT"
			x = config.auraPoints.spacing
		elseif( config.auraPoints.growth == "RIGHT" ) then
			point, relativePoint = "BOTTOMLEFT", "BOTTOMRIGHT"
			x = config.auraPoints.spacing
		elseif( config.auraPoints.growth == "UP" ) then
			point, relativePoint = "BOTTOMLEFT", "TOPLEFT"
			y = config.auraPoints.spacing
		elseif( config.auraPoints.growth == "DOWN" ) then
			point, relativePoint = "TOPLEFT", "BOTTOMLEFT"
			y = config.auraPoints.spacing
		end
		

		pointsFrame.icons = pointsFrame.icons or {}
		pointsFrame.points = pointsFrame.icons
	
		for id=1, AuraPoints.trackSpell.max do
			pointsFrame.icons[id] = pointsFrame.icons[id] or pointsFrame:CreateTexture(nil, "OVERLAY")
			local texture = pointsFrame.icons[id]
			texture:SetTexture("Interface\\AddOns\\ShadowedUnitFrames\\media\\textures\\combo")
			texture:SetSize(config.auraPoints.size, config.auraPoints.size)
			
			if( id > 1 ) then
				texture:ClearAllPoints()
				texture:SetPoint(point, pointsFrame.icons[id - 1], relativePoint, x, y)
			else
				texture:ClearAllPoints()
				texture:SetPoint("CENTER", pointsFrame, "CENTER", 0, 0)
			end
		end
		
		-- Position the main frame
		pointsFrame:SetSize(0.1, 0.1)
		pointsFrame:Show()

		ShadowUF.Layout:AnchorFrame(frame, pointsFrame, config.auraPoints)
	end
end

function AuraPoints:OnDisable(frame)
	frame:UnregisterAll(self)
end


function AuraPoints:Update(frame, event, unit)
	local points = select(4, UnitAura("player", AuraPoints.trackSpell.name)) or 0
	
	-- Bar display, hide it if we don't have any combo points
	if( ShadowUF.db.profile.units[frame.unitType].auraPoints.isBar ) then
		ShadowUF.Layout:SetBarVisibility(frame, "auraPoints", ShadowUF.db.profile.units[frame.unitType].auraPoints.showAlways or (points and points > 0))
	end
	
	for id, pointTexture in pairs(frame.auraPoints.points) do
		if( id <= points ) then
			pointTexture:Show()
		else
			pointTexture:Hide()
		end
	end
end