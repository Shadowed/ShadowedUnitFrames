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
	if( not frame.unitConfig.portrait ) then
		return
	end
	
	frame.portrait = frame.portrait or CreateFrame("PlayerModel", frame:GetName() .. "PlayerModel", frame)
	frame.portrait:SetScript("OnShow", resetCamera)
	frame.portrait:SetScript("OnHide", resetGUID)

	frame:RegisterUnitEvent("UNIT_PORTRAIT_UPDATE", self.Update)
	frame:RegisterUpdateFunc(self.UpdateFunc)
end

function Portrait:UnitDisabled(frame, unit)
	frame:UnregisterAll(self.Update)
end

function Portrait.UpdateFunc(self, unit)
	local guid = UnitGUID(unit)
	if( self.guid ~= guid ) then
		Portrait.Update(self, unit)
	end
	
	self.guid = guid
end

function Portrait.Update(self, unit)
	if( UnitIsVisible(unit) and UnitIsConnected(unit) ) then
		self.portrait:SetUnit(unit)
		self.portrait:SetCamera(0)
	else
		self.portrait:SetModelScale(4.25)
		self.portrait:SetPosition(0, 0, -1.5)
		self.portrait:SetModel("Interface\\Buttons\\talktomequestionmark.mdx")	
	end
end
