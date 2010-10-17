local IncHeal = {}
local frames = {}
ShadowUF:RegisterModule(IncHeal, "incHeal", ShadowUF.L["Incoming heals"])
ShadowUF.Tags.customEvents["HEALCOMM"] = IncHeal

function IncHeal:OnEnable(frame)
	frames[frame] = true
	frame.incHeal = frame.incHeal or ShadowUF.Units:CreateBar(frame)
	
	frame:RegisterUnitEvent("UNIT_MAXHEALTH", self, "UpdateFrame")
	frame:RegisterUnitEvent("UNIT_HEALTH", self, "UpdateFrame")
	frame:RegisterUnitEvent("UNIT_HEAL_PREDICTION", self, "UpdateFrame")
	frame:RegisterUpdateFunc(self, "UpdateFrame")
end

function IncHeal:OnDisable(frame)
	frame:UnregisterAll(self)
	frame.incHeal:Hide()
	
	if( not frame.hasHCTag ) then
		frames[frame] = nil
	end
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

-- Since I don't want a more complicated system where both incheal.lua and tags.lua are watching the same events
-- I'll update the HC tags through here instead
function IncHeal:EnableTag(frame)
	frames[frame] = true
	frame.hasHCTag = true
end

function IncHeal:DisableTag(frame)
	frame.hasHCTag = nil
	
	if( not frame.visibility.incHeal ) then
		frames[frame] = nil
	end
end

-- Update any tags using HC
function IncHeal:UpdateTags(frame, amount)
	if( not frame.fontStrings or not frame.hasHCTag ) then return end
	
	for _, fontString in pairs(frame.fontStrings) do
		if( fontString.HEALCOMM ) then
			fontString.incoming = amount > 0 and amount or nil
			fontString:UpdateTags()
		end
	end
end

function IncHeal:UpdateFrame(frame)
	-- This makes sure that when a heal like Tranquility is cast, it won't show the entire cast but cap it at 4 seconds into the future
	local healed = UnitGetIncomingHeals(frame.unit) or 0
	
	-- Update any tags that are using HC data
	IncHeal:UpdateTags(frame, healed)
	
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
				local healthWidth = frame.incHeal.healthWidth * (health / maxHealth)
				local incWidth = frame.healthBar:GetWidth() * (healed / health)
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
