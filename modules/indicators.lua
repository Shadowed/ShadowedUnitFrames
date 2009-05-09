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
	frame.indicators = {}
	
	frame:RegisterNormalEvent("PLAYER_REGEN_ENABLED", self.UpdateStatus)
	frame:RegisterNormalEvent("PLAYER_REGEN_DISABLED", self.UpdateStatus)
	frame:RegisterNormalEvent("PLAYER_UPDATE_RESTING", self.UpdateStatus)
	frame:RegisterNormalEvent("UPDATE_FACTION", self.UpdateStatus)
	frame:RegisterNormalEvent("PARTY_LEADER_CHANGED", self.UpdateLeader)
	frame:RegisterNormalEvent("PARTY_MEMBERS_CHANGED", self.UpdateLeader)
	frame:RegisterNormalEvent("PARTY_LOOT_METHOD_CHANGED", self.UpdateMasterLoot)
	frame:RegisterUnitEvent("PLAYER_FLAGS_CHANGED", self.UpdatePVPFlag)
	frame:RegisterUnitEvent("UNIT_FACTION", self.UpdatePVPFlag)
	frame:RegisterUpdateFunc(self.UpdateStatus)
	frame:RegisterUpdateFunc(self.UpdatePVPFlag)
	frame:RegisterUpdateFunc(self.UpdateLeader)
	frame:RegisterUpdateFunc(self.UpdateMasterLoot)
	
	frame.indicators.status = frame:CreateTexture(nil, "OVERLAY")
	frame.indicators.status:SetTexture("Interface\\CharacterFrame\\UI-StateIcon")
	
	frame.indicators.pvp = frame:CreateTexture(nil, "OVERLAY")
	
	frame.indicators.leader = frame:CreateTexture(nil, "OVERLAY")
	frame.indicators.leader:SetTexture("Interface\\GroupFrame\\UI-Group-LeaderIcon")
	
	frame.indicators.masterLoot = frame:CreateTexture(nil, "OVERLAY")
	frame.indicators.masterLoot:SetTexture("Interface\\GroupFrame\\UI-Group-MasterLooter")
end

function Indicator.UpdateMasterLoot(self, unit)
	local lootType, partyID, raidID = GetLootMethod()
	if( lootType ~= "master" or not partyID or not raidID ) then
		self.indicators.masterLoot:Hide()
	elseif( ( partyID > 0 and UnitIsUnit(unit, partyUnits[partyID]) ) or ( raidID > 0 and UnitIsUnit(unit, raidUnits[raidID]) ) ) then
		self.indicators.masterLoot:Show()
	else
		self.indicators.masterLoot:Hide()
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




