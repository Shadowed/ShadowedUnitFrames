local Portrait = ShadowUF:NewModule("Portrait", "AceEvent-3.0")

function Portrait:OnInitialize()
	self:RegisterMessage("SUF_CREATED_UNIT")
end

function Portrait:SUF_CREATED_UNIT(event, frame)
	frame.portrait = CreateFrame("PlayerModel", frame:GetName() .. "PlayerModel", frame)
	frame.portrait:SetUnit(frame.unit)
	frame.portrait:SetCamera(0)
	--frame.portrait:SetModelScale(4.25)
	--frame.portrait:SetPosition(0,0,-1.5)
	--frame.portrait:SetModel("Interface\\Buttons\\talktomequestionmark.mdx")	
end
