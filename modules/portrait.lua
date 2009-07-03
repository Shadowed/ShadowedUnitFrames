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
	if( not frame.portraitModel ) then
		frame.portraitModel = CreateFrame("PlayerModel", nil, frame)
		frame.portraitModel:SetScript("OnShow", resetCamera)
		frame.portraitModel:SetScript("OnHide", resetGUID)

		frame.portraitTexture = frame:CreateTexture(nil, "ARTWORK")
		
		self:OnPreLayoutApply(frame)
	end
		
	frame:RegisterUnitEvent("UNIT_PORTRAIT_UPDATE", self, "Update")
	frame:RegisterUpdateFunc(self, "UpdateFunc")
end

function Portrait:OnDisable(frame)
	frame:UnregisterAll(self)
end

function Portrait:OnPreLayoutApply(frame)
	if( frame.visibility.portrait ) then
		frame.portraitModel.guid = nil
		
		if( ShadowUF.db.profile.units[frame.unitType].portrait.type == "2D" or ShadowUF.db.profile.units[frame.unitType].portrait.type == "class" ) then
			frame.portrait = frame.portraitTexture
			frame.portraitModel:Hide()
			frame.portrait:Show()
		elseif( ShadowUF.db.profile.units[frame.unitType].portrait.type == "3D" ) then
			frame.portrait = frame.portraitModel
			frame.portraitTexture:Hide()
			frame.portrait:Show()
		end
	end
end

-- Makes sure we only do a portrait update if the GUID changed
function Portrait:UpdateFunc(frame)
	local guid = UnitGUID(frame.unit)
	if( frame.portraitModel.guid ~= guid ) then
		self:Update(frame)
	end
	
	frame.portraitModel.guid = guid
end

function Portrait:Update(frame)
	if( ShadowUF.db.profile.units[frame.unitType].portrait.type == "class" ) then
		local classToken = select(2, UnitClass(frame.unitOwner))
		if( classToken ) then
			frame.portrait:SetTexture("Interface\\Glues\\CharacterCreate\\UI-CharacterCreate-Classes")
			frame.portrait:SetTexCoord(CLASS_ICON_TCOORDS[classToken][1], CLASS_ICON_TCOORDS[classToken][2], CLASS_ICON_TCOORDS[classToken][3], CLASS_ICON_TCOORDS[classToken][4])
		else
			frame.portrait:SetTexture("")
		end
	elseif( ShadowUF.db.profile.units[frame.unitType].portrait.type == "2D" ) then
		frame.portrait:SetTexCoord(0.10, 0.90, 0.10, 0.90)
		SetPortraitTexture(frame.portrait, frame.unitOwner)
	elseif( UnitIsVisible(frame.unitOwner) and UnitIsConnected(frame.unitOwner) ) then
		frame.portrait:SetUnit(frame.unitOwner)
		frame.portrait:SetCamera(0)
	else
		frame.portrait:SetModelScale(4.25)
		frame.portrait:SetPosition(0, 0, -1.5)
		frame.portrait:SetModel("Interface\\Buttons\\talktomequestionmark.mdx")	
	end
end




