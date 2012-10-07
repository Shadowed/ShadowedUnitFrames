local IncHeal = {}
ShadowUF:RegisterModule(IncHeal, "incHeal", ShadowUF.L["Incoming heals"])

function IncHeal:OnEnable(frame)
	frame.incHeal = frame.incHeal or ShadowUF.Units:CreateBar(frame)

	if( ShadowUF.db.profile.units[frame.unitType].incHeal.heals ) then
		frame:RegisterUnitEvent("UNIT_MAXHEALTH", self, "UpdateFrame")
		frame:RegisterUnitEvent("UNIT_HEALTH", self, "UpdateFrame")
		frame:RegisterUnitEvent("UNIT_HEAL_PREDICTION", self, "UpdateFrame")
	end
	
	frame:RegisterUpdateFunc(self, "UpdateFrame")
end

function IncHeal:OnDisable(frame)
	frame:UnregisterAll(self)
	frame.incHeal:Hide()
end

function IncHeal:OnLayoutApplied(frame)
	if( frame.visibility.incHeal and frame.visibility.healthBar ) then
		frame.incHeal:SetHeight(frame.healthBar:GetHeight())
		frame.incHeal:SetStatusBarTexture(ShadowUF.Layout.mediaPath.statusbar)
		frame.incHeal:SetStatusBarColor(ShadowUF.db.profile.healthColors.inc.r, ShadowUF.db.profile.healthColors.inc.g, ShadowUF.db.profile.healthColors.inc.b, ShadowUF.db.profile.bars.alpha)
		frame.incHeal:GetStatusBarTexture():SetHorizTile(false)
		frame.incHeal:Hide()
		
		-- When we can cheat and put the incoming bar right behind the health bar, we can efficiently show the incoming heal bar
		-- if the main bar has a transparency set, then we need a more complicated method to stop the health bar from being darker with incoming heals up
		if( ( ShadowUF.db.profile.units[frame.unitType].healthBar.invert and ShadowUF.db.profile.bars.backgroundAlpha == 0 ) or ( not ShadowUF.db.profile.units[frame.unitType].healthBar.invert and ShadowUF.db.profile.bars.alpha == 1 ) ) then
			frame.incHeal.simple = true
			frame.incHeal:SetWidth(frame.healthBar:GetWidth() * ShadowUF.db.profile.units[frame.unitType].incHeal.cap)
			frame.incHeal:SetFrameLevel(frame.topFrameLevel - 1)

			frame.incHeal:ClearAllPoints()
			frame.incHeal:SetPoint("TOPLEFT", frame.healthBar)
			frame.incHeal:SetPoint("BOTTOMLEFT", frame.healthBar)
		else
			frame.incHeal.simple = nil
			frame.incHeal:SetFrameLevel(frame.topFrameLevel)
			frame.incHeal:SetWidth(1)
			frame.incHeal:SetMinMaxValues(0, 1)
			frame.incHeal:SetValue(1)

			local x, y = select(4, frame.healthBar:GetPoint())
			frame.incHeal:ClearAllPoints()
			frame.incHeal.healthX = x
			frame.incHeal.healthY = y
			frame.incHeal.healthWidth = frame.healthBar:GetWidth()
			frame.incHeal.maxWidth = frame.incHeal.healthWidth * ShadowUF.db.profile.units[frame.unitType].incHeal.cap
			frame.incHeal.cappedWidth = frame.incHeal.healthWidth * (ShadowUF.db.profile.units[frame.unitType].incHeal.cap - 1)
		end
	end
end

function IncHeal:UpdateFrame(frame)
	if( not frame.visibility.incHeal or not frame.visibility.healthBar ) then return end

	local healed = UnitGetIncomingHeals(frame.unit) or 0
	if( healed < 0 ) then
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
		local healthWidth = frame.incHeal.healthWidth * (maxHealth > 0 and health / maxHealth or 0)
		local incWidth = frame.healthBar:GetWidth() * (health > 0 and healed / health or 0)
		if( (healthWidth + incWidth) > frame.incHeal.maxWidth ) then
			incWidth = frame.incHeal.cappedWidth
		end
		
		frame.incHeal:SetWidth(incWidth)
		frame.incHeal:SetPoint("TOPLEFT", SUFUnitplayer, "TOPLEFT", frame.incHeal.healthX + healthWidth, frame.incHeal.healthY)
	end
end
