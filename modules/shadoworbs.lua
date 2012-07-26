local ShadowOrbs = setmetatable({}, {__index = ShadowUF.ComboPoints})
ShadowUF:RegisterModule(ShadowOrbs, "shadowOrbs", ShadowUF.L["Shadow Orbs"], nil, "PRIEST", SPEC_PRIEST_SHADOW)
local shadowConfig = {max = PRIEST_BAR_NUM_ORBS, key = "shadowOrbs", colorKey = "SHADOWORBS", powerType = SPELL_POWER_SHADOW_ORBS, eventType = "SHADOW_ORBS", icon = "Interface\\AddOns\\ShadowedUnitFrames\\media\\textures\\combo"}

function ShadowOrbs:OnEnable(frame)
	frame.shadowOrbs = frame.shadowOrbs or CreateFrame("Frame", nil, frame)
	frame.shadowOrbs.config = shadowConfig
	frame.comboPointType = shadowConfig.key
	
	frame:RegisterUnitEvent("UNIT_POWER_FREQUENT", self, "Update")
	frame:RegisterUnitEvent("UNIT_MAXPOWER", self, "UpdateBarBlocks")
	frame:RegisterUnitEvent("UNIT_DISPLAYPOWER", self, "Update")
	frame:RegisterUpdateFunc(self, "Update")
	frame:RegisterUpdateFunc(self, "UpdateBarBlocks")
end

function ShadowOrbs:OnDisable(frame)
	frame:UnregisterAll(self)
end

function ShadowOrbs:OnLayoutApplied(frame, config)
	ShadowUF.ComboPoints:OnLayoutApplied(frame, config)
	self:UpdateBarBlocks(frame)
end

function ShadowOrbs:Update(frame, event, unit, powerType)
	if( event == "UNIT_POWER" and powerType ~= shadowConfig.eventType ) then return end
	
	local points = UnitPower("player", shadowConfig.powerType)
	-- Bar display, hide it if we don't have any combo points
	if( ShadowUF.db.profile.units[frame.unitType].shadowOrbs.isBar ) then
		ShadowUF.Layout:SetBarVisibility(frame, "shadowOrbs", ShadowUF.db.profile.units[frame.unitType].shadowOrbs.showAlways or (points and points > 0))
	end
	
	for id, pointTexture in pairs(frame.shadowOrbs.points) do
		if( id <= points ) then
			pointTexture:Show()
		else
			pointTexture:Hide()
		end
	end
end
