local Portrait = ShadowUF:NewModule("Portrait")
ShadowUF:RegisterModule(Portrait, "portrait", ShadowUFLocals["Portrait"])

-- If the camera isn't reset OnShow, it'll show the entire character instead of just the head, odd I know
local function resetCamera(self)
	self:SetCamera(0)
end

local function resetGUID(self)
	self.guid = nil
end

function Portrait:UnitEnabled(frame, unit)
	if( not frame.visibility.portrait ) then
		return
	end
	
	frame.portraitModel = frame.portraitModel or CreateFrame("PlayerModel", frame:GetName() .. "PlayerModel", frame)
	frame.portraitModel:SetScript("OnShow", resetCamera)
	frame.portraitModel:SetScript("OnHide", resetGUID)

	frame.portraitTexture = frame.portraitTexture or frame:CreateTexture(nil, "ARTWORK")
	
	self:PreLayoutApplied(frame)
	
	frame:RegisterUnitEvent("UNIT_PORTRAIT_UPDATE", self.Update)
	frame:RegisterUpdateFunc(self.UpdateFunc)
end

function Portrait:UnitDisabled(frame, unit)
	frame:UnregisterAll(self.Update)
end

function Portrait:PreLayoutApplied(frame)
	if( not frame.portraitTexture or not frame.portraitModel ) then
		return
	end
	
	if( ShadowUF.db.profile.units[frame.unitType].portraitType == "2D" ) then
		frame.portrait = frame.portraitTexture
		frame.portraitModel:Hide()
		frame.portrait:Show()
	elseif( ShadowUF.db.profile.units[frame.unitType].portraitType == "3D" ) then
		frame.portrait = frame.portraitModel
		frame.portraitTexture:Hide()
		frame.portrait:Show()
	end
end

function Portrait.UpdateFunc(self, unit)
	local guid = UnitGUID(unit)
	if( self.portrait.guid ~= guid ) then
		Portrait.Update(self, unit)
	end
	
	self.portrait.guid = guid
end

function Portrait.Update(self, unit)
	if( ShadowUF.db.profile.units[self.unitType].portraitType == "2D" ) then
		self.portraitTexture:SetTexCoord(0.10, 0.90, 0.10, 0.90)
		SetPortraitTexture(self.portraitTexture, unit)
	elseif( UnitIsVisible(unit) and UnitIsConnected(unit) ) then
		self.portrait:SetUnit(unit)
		self.portrait:SetCamera(0)
	else
		self.portrait:SetModelScale(4.25)
		self.portrait:SetPosition(0, 0, -1.5)
		self.portrait:SetModel("Interface\\Buttons\\talktomequestionmark.mdx")	
	end
end


