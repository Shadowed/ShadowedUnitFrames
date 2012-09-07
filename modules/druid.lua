local Druid = {}
ShadowUF:RegisterModule(Druid, "druidBar", ShadowUF.L["Druid mana bar"], true, "DRUID")

function Druid:OnEnable(frame)
	frame.druidBar = frame.druidBar or ShadowUF.Units:CreateBar(frame)

	frame:RegisterUnitEvent("UNIT_DISPLAYPOWER", self, "PowerChanged")
	
	frame:RegisterUpdateFunc(self, "PowerChanged")
	frame:RegisterUpdateFunc(self, "Update")
end

function Druid:OnDisable(frame)
	frame:UnregisterAll(self)
end

function Druid:OnLayoutApplied(frame)
	if( not frame.visibility.druidBar ) then return end

	local color = ShadowUF.db.profile.powerColors.MANA
	
	if( not ShadowUF.db.profile.units[frame.unitType].druidBar.invert ) then
		frame.druidBar:SetStatusBarColor(color.r, color.g, color.b, ShadowUF.db.profile.bars.alpha)
		if( not frame.druidBar.background.overrideColor ) then
			frame.druidBar.background:SetVertexColor(color.r, color.g, color.b, ShadowUF.db.profile.bars.backgroundAlpha)
		end
	else
		frame.druidBar.background:SetVertexColor(color.r, color.g, color.b, ShadowUF.db.profile.bars.alpha)

		color = frame.druidBar.background.overrideColor or color
		frame.druidBar:SetStatusBarColor(color.r, color.g, color.b, ShadowUF.db.profile.bars.backgroundAlpha)
	end
end

function Druid:PowerChanged(frame)
	local visible = UnitPowerType(frame.unit) ~= ADDITIONAL_POWER_BAR_INDEX
	local type = visible and "RegisterUnitEvent" or "UnregisterSingleEvent"

	frame[type](frame, "UNIT_POWER_FREQUENT", self, "Update")
	frame[type](frame, "UNIT_POWERMAX", self, "Update")
	ShadowUF.Layout:SetBarVisibility(frame, "druidBar", visible)

	if( visible ) then self:Update(frame) end
end

function Druid:Update(frame, event, unit, powerType)
	if( powerType and powerType ~= "MANA" ) then return end
	frame.druidBar:SetMinMaxValues(0, UnitPowerMax(frame.unit, SPELL_POWER_MANA))
	frame.druidBar:SetValue(UnitIsDeadOrGhost(frame.unit) and 0 or not UnitIsConnected(frame.unit) and 0 or UnitPower(frame.unit, SPELL_POWER_MANA))
end
