local Monk = {}
ShadowUF:RegisterModule(Monk, "monkBar", ShadowUF.L["Monk mana bar"], true, "MONK", SPEC_MONK_MISTWEAVER)

function Monk:OnEnable(frame)
	frame.monkBar = frame.monkBar or ShadowUF.Units:CreateBar(frame)

	frame:RegisterUnitEvent("UNIT_POWER_FREQUENT", self, "Update")
	frame:RegisterUnitEvent("UNIT_MAXPOWER", self, "Update")

	frame:RegisterUpdateFunc(self, "Update")
end

function Monk:OnDisable(frame)
	frame:UnregisterAll(self)
end

function Monk:OnLayoutApplied(frame)
	if( frame.visibility.monkBar ) then
		local color = ShadowUF.db.profile.powerColors.MANA
		
		if( not ShadowUF.db.profile.units[frame.unitType].monkBar.invert ) then
			frame.monkBar:SetStatusBarColor(color.r, color.g, color.b, ShadowUF.db.profile.bars.alpha)
			if( not frame.monkBar.background.overrideColor ) then
				frame.monkBar.background:SetVertexColor(color.r, color.g, color.b, ShadowUF.db.profile.bars.backgroundAlpha)
			end
		else
			frame.monkBar.background:SetVertexColor(color.r, color.g, color.b, ShadowUF.db.profile.bars.alpha)

			color = frame.monkBar.background.overrideColor or color
			frame.monkBar:SetStatusBarColor(color.r, color.g, color.b, ShadowUF.db.profile.bars.backgroundAlpha)
		end
	end
end

function Monk:Update(frame, event, unit, powerType)
	if( powerType ~= "MANA" ) then return end
	frame.monkBar:SetMinMaxValues(0, UnitPowerMax(frame.unit, SPELL_POWER_MANA))
	frame.monkBar:SetValue(UnitIsDeadOrGhost(frame.unit) and 0 or not UnitIsConnected(frame.unit) and 0 or UnitPower(frame.unit, SPELL_POWER_MANA))
end
