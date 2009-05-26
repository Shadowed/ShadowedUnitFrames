local Indicators = {}
local raidUnits, partyUnits = ShadowUF.raidUnits, ShadowUF.partyUnits
local indicatorList = {"status", "pvp", "leader", "masterLoot", "raidTarget", "happiness"}

ShadowUF:RegisterModule(Indicators, "indicators", ShadowUFLocals["Indicators"])

function Indicators:UpdateHappiness(frame)
	if( not frame.indicators.happiness.enabled ) then return end
	
	local happyHappy = GetPetHappiness()
	if( not happyHappy ) then
		frame.indicators.happiness:Hide()
	elseif( happyHappy == 3 ) then
		frame.indicators.happiness:SetTexCoord(0, 0.1875, 0, 0.359375)
		frame.indicators.happiness:Show()
	elseif( happyHappy == 2 ) then
		frame.indicators.happiness:SetTexCoord(0.1875, 0.375, 0, 0.359375)
		frame.indicators.happiness:Show()
	elseif( happyHappy == 1 ) then
		frame.indicators.happiness:SetTexCoord(0.375, 0.5625, 0, 0.359375)
		frame.indicators.happiness:Show()
	end
end

function Indicators:UpdateMasterLoot(frame)
	if( not frame.indicators.masterLoot.enabled ) then return end
	
	local lootType, partyID, raidID = GetLootMethod()
	if( lootType ~= "master" ) then
		frame.indicators.masterLoot:Hide()
	elseif( ( partyID and partyID == 0 and UnitIsUnit(frame.unit, "player") ) or ( partyID and partyID > 0 and UnitIsUnit(frame.unit, partyUnits[partyID]) ) or ( raidID and raidID > 0 and UnitIsUnit(frame.unit, raidUnits[raidID]) ) ) then
		frame.indicators.masterLoot:Show()
	else
		frame.indicators.masterLoot:Hide()
	end
end
			
function Indicators:UpdateRaidTarget(frame)
	if( not frame.indicators.raidTarget.enabled ) then return end
	
	if( UnitExists(frame.unit) and GetRaidTargetIndex(frame.unit) ) then
		SetRaidTargetIconTexture(frame.indicators.raidTarget, GetRaidTargetIndex(frame.unit))
		frame.indicators.raidTarget:Show()
	else
		frame.indicators.raidTarget:Hide()
	end
end
			
function Indicators:UpdateLeader(frame)
	Indicators:UpdateMasterLoot(frame)
	if( not frame.indicators.leader.enabled ) then return end
	
	if( UnitIsPartyLeader(frame.unit) ) then
		frame.indicators.leader:Show()
	else
		frame.indicators.leader:Hide()
	end
end

function Indicators:UpdatePVPFlag(frame)
	if( not frame.indicators.pvp.enabled ) then return end
	
	if( UnitIsPVP(frame.unit) and UnitFactionGroup(frame.unit) ) then
		frame.indicators.pvp:SetTexture(string.format("Interface\\TargetingFrame\\UI-PVP-%s", UnitFactionGroup(frame.unit)))
		frame.indicators.pvp:Show()
	elseif( UnitIsPVPFreeForAll(frame.unit) ) then
		frame.indicators.pvp:SetTexture("Interface\\TargetingFrame\\UI-PVP-FFA")
		frame.indicators.pvp:Show()
	else
		frame.indicators.pvp:Hide()
	end
end

function Indicators:UpdateStatus(frame)
	if( not frame.indicators.status.enabled ) then return end
	
	if( UnitAffectingCombat(frame.unit) ) then
		frame.indicators.status:SetTexCoord(0.50, 1.0, 0.0, 0.49)
		frame.indicators.status:Show()
	elseif( frame.unit == "player" and IsResting() ) then
		frame.indicators.status:SetTexCoord(0.0, 0.50, 0.0, 0.421875)
		frame.indicators.status:Show()
	else
		frame.indicators.status:Hide()
	end
end

function Indicators:UpdateAll(frame)
	self:UpdateStatus(frame)
	self:UpdatePVPFlag(frame)
	self:UpdateLeader(frame)
	self:UpdateMasterLoot(frame)
	self:UpdateRaidTarget(frame)
	self:UpdateHappiness(frame)
end

function Indicators:UnitEnabled(frame, unit)
	if( not frame.visibility.indicators ) then
		return
	end
	
	frame:RegisterNormalEvent("PLAYER_REGEN_ENABLED", self, "UpdateStatus")
	frame:RegisterNormalEvent("PLAYER_REGEN_DISABLED", self, "UpdateStatus")
	frame:RegisterNormalEvent("PLAYER_UPDATE_RESTING", self, "UpdateStatus")
	frame:RegisterNormalEvent("UPDATE_FACTION", self, "UpdateStatus")
	frame:RegisterNormalEvent("PARTY_LEADER_CHANGED", self, "UpdateLeader")
	frame:RegisterNormalEvent("PARTY_MEMBERS_CHANGED", self, "UpdateLeader")
	frame:RegisterNormalEvent("PARTY_LOOT_METHOD_CHANGED", self, "UpdateMasterLoot")
	frame:RegisterNormalEvent("RAID_TARGET_UPDATE", self, "UpdateRaidTarget")
	frame:RegisterUnitEvent("PLAYER_FLAGS_CHANGED", self, "UpdatePVPFlag")
	frame:RegisterUnitEvent("UNIT_FACTION", self, "UpdatePVPFlag")
	frame:RegisterUnitEvent("UNIT_HAPPINESS", self, "UpdateHappiness")
	frame:RegisterUpdateFunc(self, "UpdateAll")

	if( frame.indicators ) then
		return
	end
	
	-- Forces the indicators to be above the bars/portraits/etc
	frame.indicators = CreateFrame("Frame", nil, frame)
	frame.indicators:SetFrameLevel(frame.topFrameLevel)
	frame.indicators.list = indicatorList

	frame.indicators.status = frame.indicators.status or frame.indicators:CreateTexture(nil, "OVERLAY")
	frame.indicators.status:SetTexture("Interface\\CharacterFrame\\UI-StateIcon")
	frame.indicators.status:Hide()

	frame.indicators.pvp = frame.indicators.pvp or frame.indicators:CreateTexture(nil, "OVERLAY")
	frame.indicators.pvp:Hide()

	frame.indicators.leader = frame.indicators:CreateTexture(nil, "OVERLAY")
	frame.indicators.leader:SetTexture("Interface\\GroupFrame\\UI-Group-LeaderIcon")
	frame.indicators.leader:Hide()

	frame.indicators.masterLoot = frame.indicators.masterLoot or frame.indicators:CreateTexture(nil, "OVERLAY")
	frame.indicators.masterLoot:SetTexture("Interface\\GroupFrame\\UI-Group-MasterLooter")
	frame.indicators.masterLoot:Hide()

	frame.indicators.raidTarget = frame.indicators.raidTarget or frame.indicators:CreateTexture(nil, "OVERLAY")
	frame.indicators.raidTarget:SetTexture("Interface\\TargetingFrame\\UI-RaidTargetingIcons")
	frame.indicators.raidTarget:Hide()
	
	frame.indicators.happiness = frame.indicators.happiness or frame.indicators:CreateTexture(nil, "OVERLAY")
	frame.indicators.happiness:SetTexture("Interface\\PetPaperDollFrame\\UI-PetHappiness")
	frame.indicators.happiness:Hide()
end

function Indicators:UnitDisabled(frame, unit)
	frame:UnregisterAll(self)

	if( frame.indicators ) then
		for _, key in pairs(frame.indicators.list) do
			local indicator = frame.indicators[key]
			if( indicator ) then
				indicator:Hide()
			end
		end
	end
end

function Indicators:LayoutApplied(frame)
	if( frame.indicators ) then
		for _, key in pairs(frame.indicators.list) do
			local indicator = frame.indicators[key]
			if( indicator and not indicator.enabled ) then
				indicator:Hide()
			end
		end
	end
end
