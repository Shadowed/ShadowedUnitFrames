local IncHeal = {}
ShadowUF:RegisterModule(IncHeal, "incHeal", ShadowUF.L["Incoming heals"])

function IncHeal:OnEnable(frame)
	frame.incHeal = frame.incHeal or ShadowUF.Units:CreateBar(frame)

	if( ShadowUF.db.profile.units[frame.unitType].incHeal.heals ) then
		frame:RegisterUnitEvent("UNIT_MAXHEALTH", self, "UpdateFrame")
		frame:RegisterUnitEvent("UNIT_HEALTH_FREQUENT", self, "UpdateFrame")
		frame:RegisterUnitEvent("UNIT_HEAL_PREDICTION", self, "UpdateFrame")
	end
	
	frame:RegisterUpdateFunc(self, "UpdateFrame")
end

function IncHeal:OnDisable(frame)
	frame:UnregisterAll(self)
	frame.incHeal:Hide()
end

function IncHeal:OnLayoutApplied(frame)
	if( not frame.visibility.incHeal or not frame.visibility.healthBar ) then return end


	frame.incHeal:SetSize(frame.healthBar:GetSize())
	frame.incHeal:SetStatusBarTexture(ShadowUF.Layout.mediaPath.statusbar)
	frame.incHeal:SetStatusBarColor(ShadowUF.db.profile.healthColors.inc.r, ShadowUF.db.profile.healthColors.inc.g, ShadowUF.db.profile.healthColors.inc.b, ShadowUF.db.profile.bars.alpha)
	frame.incHeal:GetStatusBarTexture():SetHorizTile(false)
	frame.incHeal:SetOrientation(frame.healthBar:GetOrientation())
	frame.incHeal:SetReverseFill(frame.healthBar:GetReverseFill())
	frame.incHeal:Hide()
	
	-- When we can cheat and put the incoming bar right behind the health bar, we can efficiently show the incoming heal bar
	-- if the main bar has a transparency set, then we need a more complicated method to stop the health bar from being darker with incoming heals up
	if( ( ShadowUF.db.profile.units[frame.unitType].healthBar.invert and ShadowUF.db.profile.bars.backgroundAlpha == 0 ) or ( not ShadowUF.db.profile.units[frame.unitType].healthBar.invert and ShadowUF.db.profile.bars.alpha == 1 ) ) then
		frame.incHeal.simple = true
		frame.incHeal:SetFrameLevel(frame.topFrameLevel - 1)

		if( frame.incHeal:GetOrientation() == "HORIZONTAL" ) then
			frame.incHeal:SetWidth(frame.healthBar:GetWidth() * ShadowUF.db.profile.units[frame.unitType].incHeal.cap)
		else
			frame.incHeal:SetHeight(frame.healthBar:GetHeight() * ShadowUF.db.profile.units[frame.unitType].incHeal.cap)
		end

		frame.incHeal:ClearAllPoints()
		
		local point = frame.incHeal:GetReverseFill() and "RIGHT" or "LEFT"
		frame.incHeal:SetPoint("TOP" .. point, frame.healthBar)
		frame.incHeal:SetPoint("BOTTOM" .. point, frame.healthBar)
	else
		frame.incHeal.simple = nil
		frame.incHeal:SetFrameLevel(frame.topFrameLevel )
		frame.incHeal:SetWidth(1)
		frame.incHeal:SetMinMaxValues(0, 1)
		frame.incHeal:SetValue(1)
		frame.incHeal:ClearAllPoints()

		frame.incHeal.orientation = frame.incHeal:GetOrientation()
		frame.incHeal.reverseFill = frame.incHeal:GetReverseFill()

		if( frame.incHeal.orientation == "HORIZONTAL" ) then
			frame.incHeal.healthSize = frame.healthBar:GetWidth()
			frame.incHeal.positionPoint = frame.incHeal.reverseFill and "TOPRIGHT" or "TOPLEFT"
			frame.incHeal.positionRelative = frame.incHeal.reverseFill and "BOTTOMRIGHT" or "BOTTOMLEFT"
		else
			frame.incHeal.healthSize = frame.healthBar:GetHeight()
			frame.incHeal.positionPoint = frame.incHeal.reverseFill and "TOPLEFT" or "BOTTOMLEFT"
			frame.incHeal.positionRelative = frame.incHeal.reverseFill and "TOPRIGHT" or "BOTTOMRIGHT"
		end

		frame.incHeal.positionMod = frame.incHeal.reverseFill and -1 or 1
		frame.incHeal.cappedSize = frame.incHeal.healthSize * (ShadowUF.db.profile.units[frame.unitType].incHeal.cap - 1)
		frame.incHeal.maxSize = frame.incHeal.healthSize * ShadowUF.db.profile.units[frame.unitType].incHeal.cap
	end
end

function IncHeal:UpdateFrame(frame)
	if( not frame.visibility.incHeal or not frame.visibility.healthBar ) then return end

	local healed = UnitGetIncomingHeals(frame.unit) or 0
	if( healed <= 0 ) then
		frame.incHeal.total = nil
		frame.incHeal.healed = nil
		frame.incHeal:Hide()
		return
	end

	frame.incHeal.healed = healed
	frame.incHeal:Show()
	
	-- When the primary bar has an alpha of 100%, we can cheat and do incoming heals easily. Otherwise we need to do it a more complex way to keep it looking good
	if( frame.incHeal.simple ) then
		frame.incHeal.total = UnitHealth(frame.unit) + healed
		frame.incHeal:SetMinMaxValues(0, UnitHealthMax(frame.unit) * ShadowUF.db.profile.units[frame.unitType].incHeal.cap)
		frame.incHeal:SetValue(frame.incHeal.total)
	else
		local health, maxHealth = UnitHealth(frame.unit), UnitHealthMax(frame.unit)
		local healthSize = frame.incHeal.healthSize * (maxHealth > 0 and health / maxHealth or 0)
		local incSize = frame.incHeal.healthSize * (health > 0 and healed / health or 0)

		if( (healthSize + incSize) > frame.incHeal.maxSize ) then
			incSize = frame.incHeal.cappedSize
		end

		if( frame.incHeal.orientation == "HORIZONTAL" ) then
			frame.incHeal:SetWidth(incSize)
			frame.incHeal:SetPoint(frame.incHeal.positionPoint, frame.healthBar, frame.incHeal.positionMod * healthSize, 0)
			frame.incHeal:SetPoint(frame.incHeal.positionRelative, frame.healthBar, frame.incHeal.positionMod * healthSize, 0)
		else
			frame.incHeal:SetHeight(incSize)
			frame.incHeal:SetPoint(frame.incHeal.positionPoint, frame.healthBar, 0, frame.incHeal.positionMod * healthSize)
			frame.incHeal:SetPoint(frame.incHeal.positionRelative, frame.healthBar, 0, frame.incHeal.positionMod * healthSize)
		end
	end
end
