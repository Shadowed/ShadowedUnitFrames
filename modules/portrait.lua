local Portrait = ShadowUF:NewModule("Portrait")
ShadowUF:RegisterModule(Portrait, "portrait", ShadowUFLocals["Portrait"])

-- If the camera isn't reset OnShow, it'll show the entire character instead of just the head, odd I know
local function resetCamera(self)
	self:SetCamera(0)
end

local function resetGUID(self)
	self.guid = nil
end

function Portrait:UnitEnabled(frame)
	if( not frame.visibility.portrait ) then
		return
	end
	
	if( not frame.portraitModel ) then
		frame.portraitModel = CreateFrame("PlayerModel", nil, frame)
		frame.portraitModel:SetScript("OnShow", resetCamera)
		frame.portraitModel:SetScript("OnHide", resetGUID)

		frame.portraitTexture = frame:CreateTexture(nil, "ARTWORK")
		
		self:PreLayoutApplied(frame)
	end
		
	frame:RegisterUnitEvent("UNIT_PORTRAIT_UPDATE", self, "Update")
	frame:RegisterUpdateFunc(self, "UpdateFunc")
end

function Portrait:UnitDisabled(frame)
	frame:UnregisterAll(self)
end

function Portrait:PreLayoutApplied(frame)
	if( not frame.portraitTexture or not frame.portraitModel ) then
		return
	end
	
	if( ShadowUF.db.profile.units[frame.unitType].portrait.type == "2D" ) then
		frame.portrait = frame.portraitTexture
		frame.portraitModel:Hide()
		frame.portrait:Show()
	elseif( ShadowUF.db.profile.units[frame.unitType].portrait.type == "3D" ) then
		frame.portrait = frame.portraitModel
		frame.portraitTexture:Hide()
		frame.portrait:Show()
	end
end

function Portrait:UpdateFunc(frame)
	local guid = UnitGUID(frame.unit)
	if( frame.portraitModel.guid ~= guid ) then
		self:Update(frame)
	end
	
	frame.portraitModel.guid = guid
end

function Portrait:Update(frame)
	if( ShadowUF.db.profile.units[frame.unitType].portrait.type == "2D" ) then
		frame.portrait:SetTexCoord(0.10, 0.90, 0.10, 0.90)
		SetPortraitTexture(frame.portrait, frame.unit)
	elseif( UnitIsVisible(frame.unit) and UnitIsConnected(frame.unit) ) then
		frame.portrait:SetUnit(frame.unit)
		frame.portrait:SetCamera(0)
	else
		frame.portrait:SetModelScale(4.25)
		frame.portrait:SetPosition(0, 0, -1.5)
		frame.portrait:SetModel("Interface\\Buttons\\talktomequestionmark.mdx")	
	end
end


