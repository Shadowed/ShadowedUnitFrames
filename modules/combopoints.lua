local Combo = ShadowUF:NewModule("Combo")
ShadowUF:RegisterModule(Combo, "comboPoints", ShadowUFLocals["Combo points"])

function Combo:UnitEnabled(frame, unit)
	if( not frame.visibility.comboPointsPoints or unit ~= "target" ) then return end

	frame.comboPoints = frame.comboPoints or CreateFrame("Frame", nil, frame)
	frame.comboPoints.points = frame.comboPoints.points or {}
	
	for i=1, MAX_COMBO_POINTS do
		frame.comboPoints.points[i] = frame.comboPoints.points[i] or frame.comboPoints:CreateTexture(nil, "BACKGROUND")
		local point = frame.comboPoints.points[i]
		
		point:SetHeight(12)
		point:SetWidth(12)
		
		if( i > 1 ) then
			point:SetPoint("BOTTOMRIGHT", frame.comboPoints.points[i - 1], "BOTTOMLEFT")
		else
			point:SetPoint("CENTER", frame.comboPoints, "CENTER", 0, 0)
		end
		
		point:Show()
	end
	
	frame:RegisterUpdateFunc(self.Update)
end

function Combo:UnitDisabled(frame, unit)
	frame:UnregisterAll(self.Update)
end

function Combo.Update(self, unit)

end

--[[
				object[frame]:SetPoint("BOTTOMRIGHT",object["Combo"..i-1],"BOTTOMLEFT")
			else
				object[frame]:SetPoint("BOTTOMRIGHT",object.frame,"BOTTOMRIGHT",-2,-1)

				<Layer level="BACKGROUND">
				<Texture file="Interface\ComboFrame\ComboPoint">
					<Size>
						<AbsDimension x="12" y="16"/>
					</Size>
					<Anchors>
						<Anchor point="TOPLEFT"/>
					</Anchors>
					<TexCoords left="0" right="0.375" top="0" bottom="1"/>
				</Texture>
			</Layer>
]]