local IncHeal = {}
local frames = {}
ShadowUF:RegisterModule(IncHeal, "incHeal", ShadowUF.L["Incoming heals"])
-- ShadowUF.Tags.customEvents["CRTABS"] = IncHeal

function IncHeal:OnEnable(frame)
	frame.incHeal = frame.incHeal or ShadowUF.Units:CreateBar(frame)
	
	if( ShadowUF.db.profile.units[frame.unitType].incHeal.heals ) then
		frame:RegisterUnitEvent("UNIT_MAXHEALTH", self, "UpdateFrame")
		frame:RegisterUnitEvent("UNIT_HEALTH", self, "UpdateFrame")
		frame:RegisterUnitEvent("UNIT_HEAL_PREDICTION", self, "UpdateFrame")
	end
	
	-- if( ShadowUF.db.profile.units[frame.unitType].incHeal.absorbs ) then
	-- 	frame:RegisterUnitEvent("UNIT_AURA", self, "CalculateAbsorb")
	-- 	frame:RegisterUpdateFunc(self, "CalculateAbsorb")
	-- -- Since CalculateAbsorb already calls UpdateFrame, we don't need to explicitly do it
	-- else
		frame:RegisterUpdateFunc(self, "UpdateFrame")
	-- end
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
			frame.incHeal:SetFrameLevel(frame.topFrameLevel - 3)

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

-- function IncHeal:EnableTag(frame, fontString)
-- 	if( not frames[frame] ) then frames[frame] = {} end
-- 	
-- 	frames[frame][fontString] = true
-- 	
-- 	-- Need to register the events since we're not watching them by default
-- 	if( not frame.tagEnabled and not ShadowUF.db.profile.units[frame.unitType].incHeal.absorbs ) then
-- 		frame:RegisterUnitEvent("UNIT_AURA", self, "CalculateAbsorb")
-- 		frame:RegisterUpdateFunc(self, "CalculateAbsorb")
-- 		
-- 		-- And unregister the default updater since it's used by default
-- 		if( ShadowUF.db.profileunits[frame.unitType].incHeal.heals ) then
-- 			frame:UnregisterUpdateFunc(self, "UpdateFrame")
-- 		end
-- 	end
-- 	
-- 	frame.tagEnabled = true
-- end
-- 
-- function IncHeal:DisableTag(frame, fontString)
-- 	if( not frames[frame] or not frames[frame][fontString] ) then return end
-- 	
-- 	frames[frame][fontString] = nil
-- 	frame.tagEnabled = nil
-- 	for _, _ in pairs(frames[frame]) do
-- 		frame.tagEnabled = true
-- 		break
-- 	end
-- 	
-- 	if( frame.tagEnabled ) then return end
-- 
-- 	-- Need to unrregister the events since we're not watching them by default
-- 	if( not ShadowUF.db.profile.units[frame.unitType].incHeal.absorbs ) then
-- 		frame:UnregisterUnitEvent("UNIT_AURA", self, "CalculateAbsorb")
-- 		frame:UnregisterUpdateFunc(self, "CalculateAbsorb")
-- 		
-- 		-- Also register the default updater since we used it by default
-- 		if( ShadowUF.db.profileunits[frame.unitType].incHeal.heals ) then
-- 			frame:RegisterUpdateFunc(self, "UpdateFrame")
-- 		end
-- 	end
-- end	
-- 
-- function IncHeal:CalculateAbsorb(frame)
-- 	frame.absorb = 0
-- 	
-- 	local index = 0
-- 	while( true ) do
-- 		index = index + 1
-- 		local name, _, _, _, _, _, _, _, _, _, _, _, _, absorbAmount = UnitAura(frame.unit, index, "HELPFUL"))
-- 		if( not name ) then break end
-- 		
-- 		
-- 	end
-- 	
-- 	if( frame.tagEnabled ) then
-- 		for fontString, _ in pairs(frames[frame]) do
-- 			fontString:UpdateTags()
-- 		end
-- 	end
-- 	
-- 	self:UpdateFrame(frame)
-- end

function IncHeal:UpdateFrame(frame)
	-- This makes sure that when a heal like Tranquility is cast, it won't show the entire cast but cap it at 4 seconds into the future
	local healed = UnitGetIncomingHeals(frame.unit) or 0
		
	-- Bar is also supposed to be enabled, lets update that too
	if( frame.visibility.incHeal and frame.visibility.healthBar ) then
		if( healed > 0 ) then
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
		else
			frame.incHeal.total = nil
			frame.incHeal.healed = nil
			frame.incHeal:Hide()
		end
	end
end
