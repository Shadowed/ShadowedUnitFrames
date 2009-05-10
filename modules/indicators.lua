local Indicator = ShadowUF:NewModule("Indicator")
local raidUnits, partyUnits = {}, {}

function Indicator:OnInitialize()
	ShadowUF:RegisterModule(self)
	
	for i=1, MAX_PARTY_MEMBERS do
		partyUnits[i] = "party" .. i
	end
	
	for i=1, MAX_RAID_MEMBERS do
		raidUnits[i] = "raid" .. i
	end
end

function Indicator:UnitCreated(frame, unit)
	frame:RegisterNormalEvent("PLAYER_REGEN_ENABLED", self.UpdateStatus)
	frame:RegisterNormalEvent("PLAYER_REGEN_DISABLED", self.UpdateStatus)
	frame:RegisterNormalEvent("PLAYER_UPDATE_RESTING", self.UpdateStatus)
	frame:RegisterNormalEvent("UPDATE_FACTION", self.UpdateStatus)
	frame:RegisterNormalEvent("PARTY_LEADER_CHANGED", self.UpdateLeader)
	frame:RegisterNormalEvent("PARTY_MEMBERS_CHANGED", self.UpdateLeader)
	frame:RegisterNormalEvent("PARTY_LOOT_METHOD_CHANGED", self.UpdateMasterLoot)
	frame:RegisterNormalEvent("RAID_TARGET_UPDATE", self.UpdateRaidTarget)
	frame:RegisterUnitEvent("PLAYER_FLAGS_CHANGED", self.UpdatePVPFlag)
	frame:RegisterUnitEvent("UNIT_FACTION", self.UpdatePVPFlag)
	frame:RegisterUnitEvent("UNIT_HAPPINESS", self.UpdateHappiness)
	frame:RegisterUpdateFunc(self.UpdateRaidTarget)
	frame:RegisterUpdateFunc(self.UpdateStatus)
	frame:RegisterUpdateFunc(self.UpdatePVPFlag)
	frame:RegisterUpdateFunc(self.UpdateLeader)
	frame:RegisterUpdateFunc(self.UpdateMasterLoot)
	frame:RegisterUpdateFunc(self.UpdateHappiness)
	
	-- Forces the indicators to be above the bars/portraits/etc
	frame.indicators = CreateFrame("Frame", frame:GetName() .. "IndicatorFrame", frame)

	frame.indicators.status = frame.indicators:CreateTexture(nil, "OVERLAY")
	frame.indicators.status:SetTexture("Interface\\CharacterFrame\\UI-StateIcon")
	
	frame.indicators.pvp = frame.indicators:CreateTexture(nil, "OVERLAY")
	
	frame.indicators.leader = frame.indicators:CreateTexture(nil, "OVERLAY")
	frame.indicators.leader:SetTexture("Interface\\GroupFrame\\UI-Group-LeaderIcon")
	
	frame.indicators.masterLoot = frame.indicators:CreateTexture(nil, "OVERLAY")
	frame.indicators.masterLoot:SetTexture("Interface\\GroupFrame\\UI-Group-MasterLooter")
	
	frame.indicators.raidTarget = frame.indicators:CreateTexture(nil, "OVERLAY")
	frame.indicators.raidTarget:SetTexture("Interface\\TargetingFrame\\UI-RaidTargetingIcons")
	
	frame.indicators.happiness = frame.indicators:CreateTexture(nil, "OVERLAY")
	frame.indicators.happiness:SetTexture("Interface\\PetPaperDollFrame\\UI-PetHappiness")
end

function Indicator.UpdateHappiness(self, unit)
	local happyHappy = GetPetHappiness()
	if( not happyHappy ) then
		self.indicators.happiness:Hide()
	elseif( happyHappy == 3 ) then
		self.indicators.happiness:SetTexCoord(0, 0.1875, 0, 0.359375)
		self.indicators.happiness:Show()
	elseif( happyHappy == 2 ) then
		self.indicators.happiness:SetTexCoord(0.1875, 0.375, 0, 0.359375)
		self.indicators.happiness:Show()
	elseif( happyHappy == 1 ) then
		self.indicators.happiness:SetTexCoord(0.375, 0.5625, 0, 0.359375)
		self.indicators.happiness:Show()
	end
end

function Indicator.UpdateMasterLoot(self, unit)
	local unit = self:GetAttribute("unit")	local lootType, partyID, raidID = GetLootMethod()
	if( lootType ~= "master" or not partyID or not raidID ) then
		self.indicators.masterLoot:Hide()
	elseif( ( partyID > 0 and UnitIsUnit(unit, partyUnits[partyID]) ) or ( raidID > 0 and UnitIsUnit(unit, raidUnits[raidID]) ) ) then
		self.indicators.masterLoot:Show()
	else
		self.indicators.masterLoot:Hide()
	end
end
			
function Indicator.UpdateRaidTarget(self, unit)
	if( UnitExists(unit) and GetRaidTargetIndex(unit) ) then
		SetRaidTargetIconTexture(self.indicators.raidTarget, GetRaidTargetIndex(unit))
		self.indicators.raidTarget:Show()
	else
		self.indicators.raidTarget:Hide()
	end
end
			
function Indicator.UpdateLeader(self, unit)
	if( UnitIsPartyLeader(unit) ) then
		self.indicators.leader:Show()
	else
		self.indicators.leader:Hide()
	end
end

function Indicator.UpdatePVPFlag(self, unit)
	if( UnitIsPVP(unit) and UnitFactionGroup(unit) ) then
		self.indicators.pvp:SetTexture(string.format("Interface\\TargetingFrame\\UI-PVP-%s", UnitFactionGroup(unit)))
		self.indicators.pvp:Show()
	elseif( UnitIsPVPFreeForAll(unit) ) then
		self.indicators.pvp:SetTexture("Interface\\TargetingFrame\\UI-PVP-FFA")
		self.indicators.pvp:Show()
	else
		self.indicators.pvp:Hide()
	end
end

function Indicator.UpdateStatus(self, unit)
	if( UnitAffectingCombat(unit) ) then
		self.indicators.status:SetTexCoord(0.50, 1.0, 0.0, 0.49)
		self.indicators.status:Show()
	elseif( self.unit == "player" and IsResting() ) then
		self.indicators.status:SetTexCoord(0.0, 0.50, 0.0, 0.421875)
		self.indicators.status:Show()
	else
		self.indicators.status:Hide()
	end
end




