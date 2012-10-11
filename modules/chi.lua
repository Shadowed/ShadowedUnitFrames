local Chi = setmetatable({}, {__index = ShadowUF.ComboPoints})
ShadowUF:RegisterModule(Chi, "chi", ShadowUF.L["Chi"], nil, "MONK")
local chiConfig = {max = 5, key = "chi", colorKey = "CHI", powerType = ShadowUF.is501 and SPELL_POWER_CHI or SPELL_POWER_LIGHT_FORCE, eventType = ShadowUF.is501 and "CHI" or "LIGHT_FORCE", icon = "Interface\\AddOns\\ShadowedUnitFrames\\media\\textures\\combo"}

function Chi:OnEnable(frame)
	frame.chi = frame.chi or CreateFrame("Frame", nil, frame)
	frame.chi.config = chiConfig
	frame.comboPointType = chiConfig.key

	frame:RegisterUnitEvent("UNIT_POWER_FREQUENT", self, "Update")
	frame:RegisterUnitEvent("UNIT_MAXPOWER", self, "UpdateBarBlocks")
	frame:RegisterUnitEvent("UNIT_DISPLAYPOWER", self, "Update")
	frame:RegisterUpdateFunc(self, "Update")
end

function Chi:OnDisable(frame)
	frame:UnregisterAll(self)
end

function Chi:OnLayoutApplied(frame, config)
	ShadowUF.ComboPoints:OnLayoutApplied(frame, config)
	self:UpdateBarBlocks(frame)
end

function Chi:Update(frame, event, unit, powerType)
	if( powerType and powerType ~= chiConfig.eventType ) then return end
	
	local points = UnitPower("player", chiConfig.powerType)
	-- Bar display, hide it if we don't have any combo points
	if( ShadowUF.db.profile.units[frame.unitType].chi.isBar ) then
		ShadowUF.Layout:SetBarVisibility(frame, "chi", ShadowUF.db.profile.units[frame.unitType].chi.showAlways or (points and points > 0))
	end
	
	for id, pointTexture in pairs(frame.chi.points) do
		if( id <= points ) then
			pointTexture:Show()
		else
			pointTexture:Hide()
		end
	end
end
