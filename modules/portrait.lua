local Portrait = {}
ShadowUF:RegisterModule(Portrait, "portrait", ShadowUFLocals["Portrait"])

-- If the camera isn't reset OnShow, it'll show the entire character instead of just the head, odd I know
local function resetCamera(self)
	self:SetCamera(0)
end

local function resetGUID(self)
	self.guid = nil
end

function Portrait:OnEnable(frame)
	frame:RegisterUnitEvent("UNIT_PORTRAIT_UPDATE", self, "Update")
	if( frame.unitRealType == "party" ) then
		frame:RegisterNormalEvent("PARTY_MEMBER_ENABLE", self, "Update")
		frame:RegisterNormalEvent("PARTY_MEMBER_DISABLE", self, "Update")
	end
	
	frame:RegisterUpdateFunc(self, "UpdateFunc")
end

function Portrait:OnDisable(frame)
	frame:UnregisterAll(self)
end

function Portrait:OnPreLayoutApply(frame, config)
	if( not frame.visibility.portrait ) then return end

	if( config.portrait.type == "3D" ) then
		if( not frame.portraitModel ) then
			frame.portraitModel = CreateFrame("PlayerModel", nil, frame)
			frame.portraitModel:SetScript("OnShow", resetCamera)
			frame.portraitModel:SetScript("OnHide", resetGUID)
			frame.portraitModel.parent = frame
		end
		
		frame.portraitTexture = frame.portraitTexture or frame:CreateTexture(nil, "ARTWORK")
		
		frame.portrait = frame.portraitModel
		frame.portrait.guid = nil
		frame.portrait:Show()

		ShadowUF.Layout:ToggleVisibility(frame.portraitTexture, false)
	else
		frame.portraitTexture = frame.portraitTexture or frame:CreateTexture(nil, "ARTWORK")
		frame.portrait = frame.portraitTexture
		frame.portrait:Show()

		ShadowUF.Layout:ToggleVisibility(frame.portraitModel, false)
	end
end

function Portrait:OnLayoutWidgets(frame, config)
	if( frame.visibility.portrait and config.portrait.type == "3D" ) then
		frame.portraitTexture:ClearAllPoints()
		frame.portraitTexture:SetPoint(frame.portrait:GetPoint())
		frame.portraitTexture:SetHeight(frame.portrait:GetHeight())
		frame.portraitTexture:SetWidth(frame.portrait:GetWidth())
	end
end

function Portrait:UpdateFunc(frame)
	-- Portrait models can't be updated unless the GUID changed or else you have the animation jumping around
	if( ShadowUF.db.profile.units[frame.unitType].portrait.type == "3D" ) then
		local guid = UnitGUID(frame.unitOwner)
		if( frame.portraitTexture:IsVisible() or frame.portrait.guid ~= guid ) then
			self:Update(frame)
		end
		
		frame.portrait.guid = guid
	else
		self:Update(frame)
	end
end

function Portrait:Update(frame)
	local type = ShadowUF.db.profile.units[frame.unitType].portrait.type
	
	-- Use class thingy
	if( type == "class" ) then
		local classToken = select(2, UnitClass(frame.unitOwner))
		if( classToken ) then
			frame.portrait:SetTexture("Interface\\Glues\\CharacterCreate\\UI-CharacterCreate-Classes")
			frame.portrait:SetTexCoord(CLASS_ICON_TCOORDS[classToken][1], CLASS_ICON_TCOORDS[classToken][2], CLASS_ICON_TCOORDS[classToken][3], CLASS_ICON_TCOORDS[classToken][4])
		else
			frame.portrait:SetTexture("")
		end
	-- Use 2D character image
	elseif( type == "2D" ) then
		frame.portrait:SetTexCoord(0.10, 0.90, 0.10, 0.90)
		SetPortraitTexture(frame.portrait, frame.unitOwner)
	-- Use animated 3D portrait
	elseif( UnitIsVisible(frame.unitOwner) and UnitIsConnected(frame.unitOwner) ) then
		frame.portrait:SetUnit(frame.unitOwner)
		frame.portrait:SetCamera(0)
		frame.portrait:Show()
		frame.portraitTexture:Hide()
	-- Using 3D portrait, but the players not in range so swap to 2D
	elseif( type == "3D" ) then
		frame.portraitTexture:SetTexCoord(0.10, 0.90, 0.10, 0.90)
		frame.portraitTexture:Show()
		frame.portrait:Hide()
		
		SetPortraitTexture(frame.portraitTexture, frame.unitOwner)
	end
end




