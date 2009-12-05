local Auras = {}
local stealableColor = {r = 0.80, g = 0.50, b = 0}
local tempEnchantScan
ShadowUF:RegisterModule(Auras, "auras", ShadowUFLocals["Auras"])

function Auras:OnEnable(frame)
	frame.auras = frame.auras or {}
	
	frame:RegisterNormalEvent("PLAYER_ENTERING_WORLD", self, "Update")
	frame:RegisterUnitEvent("UNIT_AURA", self, "Update")
	frame:RegisterUpdateFunc(self, "Update")

	self:UpdateFilter(frame)
end

function Auras:OnLayoutApplied(frame)
	self:UpdateFilter(frame)
end

function Auras:OnDisable(frame)
	frame:UnregisterAll(self)
end

-- Aura positioning code
-- Definitely some of the more unusual code I've done, not sure I really like this method
-- but it does allow more flexibility with how things are anchored without me having to hardcode the 10 different growth methods
local function load(text)
	local result, err = loadstring(text)
	if( err ) then
		error(err, 3)
		return nil
	end
		
	return result()
end

local positionData = setmetatable({}, {
	__index = function(tbl, index)
		local data = {}
		local columnGrowth = ShadowUF.Layout:GetColumnGrowth(index)
		local auraGrowth = ShadowUF.Layout:GetAuraGrowth(index)
		data.xMod = (columnGrowth == "RIGHT" or auraGrowth == "RIGHT") and 1 or -1
		data.yMod = (columnGrowth ~= "TOP" and auraGrowth ~= "TOP") and -1 or 1
		
		local auraX, colX, auraY, colY, xOffset, yOffset = 0, 0, 0, 0, "", ""
		if( columnGrowth == "LEFT" or columnGrowth == "RIGHT" ) then
			colX = 1
			xOffset = " + offset"
			auraY = 3
			data.isSideGrowth = true
		elseif( columnGrowth == "TOP" or columnGrowth == "BOTTOM" ) then
			colY = 2
			yOffset = " + offset"
			auraX = 2
		end
		
		data.column = load(string.format([[return function(button, positionTo, offset)
			button:ClearAllPoints()
			button:SetPoint("%s", positionTo, "%s", %d * (%d%s), %d * (%d%s)) end
		]], ShadowUF.Layout:ReverseDirection(columnGrowth), columnGrowth, data.xMod, colX, xOffset, data.yMod, colY, yOffset))
		data.aura = load(string.format([[return function(button, positionTo) 
			button:ClearAllPoints()
			button:SetPoint("%s", positionTo, "%s", %d, %d) end
		]], ShadowUF.Layout:ReverseDirection(auraGrowth), auraGrowth, data.xMod * auraX, data.yMod * auraY))
		
		tbl[index] = data
		return tbl[index]
	end,
})

local function positionButton(id,  group, config)
	local position = positionData[group.forcedAnchorPoint or config.anchorPoint] 
	local button = group.buttons[id]
	button.isAuraAnchor = nil
	
	-- Alright, in order to find out where an aura group is going to be anchored to certain buttons need
	-- to be flagged as suitable anchors visually, this speeds it up bcause this data is cached and doesn't
	-- have to be recalculated unless auras are specifically changed
	if( id > 1 ) then
		if( position.isSideGrowth and id <= config.perRow ) then
			button.isAuraAnchor = true
		end
		
		if( id % config.perRow == 1 or config.perRow == 1 ) then
			position.column(button, group.buttons[id - config.perRow], 0)

			if( not position.isSideGrowth ) then
				button.isAuraAnchor = true
			end
		else
			position.aura(button, group.buttons[id - 1])
		end
	else
		button.isAuraAnchor = true
		button:SetPoint(ShadowUF.Layout:GetPoint(config.anchorPoint), group.anchorTo, ShadowUF.Layout:GetRelative(config.anchorPoint), config.x + (position.xMod * ShadowUF.db.profile.backdrop.inset), config.y + (position.yMod * ShadowUF.db.profile.backdrop.inset))
	end
end

-- Aura button functions
-- Updates the X seconds left on aura tooltip while it's shown
local function updateTooltip(self)
	if( GameTooltip:IsOwned(self) ) then
		GameTooltip:SetUnitAura(self.unit, self.auraID, self.filter)
	end
end

local function showTooltip(self)
	GameTooltip:SetOwner(self, "ANCHOR_BOTTOMLEFT")

	if( self.filter == "TEMP" ) then
		GameTooltip:SetInventoryItem("player", self.auraID)
		self:SetScript("OnUpdate", nil)
	else
		GameTooltip:SetUnitAura(self.unit, self.auraID, self.filter)
		self:SetScript("OnUpdate", updateTooltip)
	end

end

local function hideTooltip(self)
	self:SetScript("OnUpdate", nil)
	GameTooltip:Hide()
end

local function cancelBuff(self)
	if( self.filter == "TEMP" ) then
		CancelItemTempEnchantment(self.auraID - 15)
	else
		CancelUnitBuff(self.unit, self.auraID, self.filter)
	end
end

local function updateButton(id, group, config)
	local button = group.buttons[id]
	if( not button ) then
		group.buttons[id] = CreateFrame("Button", nil, group)
		
		button = group.buttons[id]
		button:SetScript("OnEnter", showTooltip)
		button:SetScript("OnLeave", hideTooltip)
		button:SetScript("OnClick", cancelBuff)
		button:RegisterForClicks("RightButtonUp")
		
		button.cooldown = CreateFrame("Cooldown", nil, button)
		button.cooldown:SetAllPoints(button)
		button.cooldown:SetReverse(true)
		button.cooldown:SetFrameLevel(7)
		button.cooldown:Hide()			
		
		button.stack = button:CreateFontString(nil, "OVERLAY")
		button.stack:SetFont("Interface\\AddOns\\ShadowedUnitFrames\\media\\fonts\\Myriad Condensed Web.ttf", 10, "OUTLINE")
		button.stack:SetShadowColor(0, 0, 0, 1.0)
		button.stack:SetShadowOffset(0.50, -0.50)
		button.stack:SetHeight(1)
		button.stack:SetWidth(1)
		button.stack:SetAllPoints(button)
		button.stack:SetJustifyH("RIGHT")
		button.stack:SetJustifyV("BOTTOM")
		button.stack:SetJustifyH("RIGHT")

		button.border = button:CreateTexture(nil, "OVERLAY")
		button.border:SetPoint("CENTER", button)		
		
		button.icon = button:CreateTexture(nil, "BACKGROUND")
		button.icon:SetAllPoints(button)
		button.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
	end
		
	if( ShadowUF.db.profile.auras.borderType == "blizzard" ) then
		button.border:SetTexture("Interface\\Buttons\\UI-Debuff-Overlays")
		button.border:SetTexCoord(0.296875, 0.5703125, 0, 0.515625)
		button.border:Show()
	elseif( ShadowUF.db.profile.auras.borderType == "" ) then
		button.border:Hide()
	else
		button.border:SetTexture("Interface\\AddOns\\ShadowedUnitFrames\\media\\textures\\border-" .. ShadowUF.db.profile.auras.borderType)
		button.border:SetTexCoord(0, 1, 0, 1)
		button.border:Show()
	end
	
	-- Set the button sizing
	button:SetHeight(config.size)
	button:SetWidth(config.size)
	button.border:SetHeight(config.size + 1)
	button.border:SetWidth(config.size + 1)
	button:ClearAllPoints()
	button:Hide()
	
	-- Position the button quickly
	positionButton(id, group, config)
end

-- Let the mover access this for creating aura things
Auras.updateButton = updateButton

-- Create an aura anchor as well as the buttons to contain it
local function updateGroup(self, type, config, reverseConfig)
	self.auras[type] = self.auras[type] or CreateFrame("Frame", nil, self.highFrame)
	
	local group = self.auras[type]
	group.buttons = group.buttons or {}
	
	group.maxAuras = config.perRow * config.maxRows
	group.totalAuras = 0
	group.temporaryEnchants = 0
	group.type = type
	group.parent = self
	group.anchorTo = self
	group:SetFrameLevel(5)
	group:Show()

	-- If debuffs are anchored to buffs, debuffs need to grow however buffs do
	if( config.anchorOn and reverseConfig.enabled ) then
		group.forcedAnchorPoint = reverseConfig.anchorPoint
	end
	
	if( self.unit == "player" and config.temporary ) then
		group:SetScript("OnUpdate", tempEnchantScan)
	else
		group:SetScript("OnUpdate", nil)
	end
	
	-- Update filters used for the anchor
	group.filter = group.type == "buffs" and "HELPFUL" or group.type == "debuffs" and "HARMFUL" or ""

	-- This is a bit of an odd filter, when used with a HELPFUL filter, it will only return buffs you can cast on group members
	-- When used with HARMFUL it will only return debuffs you can cure
	if( config.raid ) then
		group.filter = group.filter .. "|RAID"
	end
	
	for id, button in pairs(group.buttons) do
		updateButton(id, group, config)
	end
end

-- Update aura positions based off of configuration
function Auras:OnLayoutApplied(frame, config)
	if( frame.auras ) then
		if( frame.auras.buffs ) then
			for _, button in pairs(frame.auras.buffs.buttons) do
				button:Hide() 
			end 
		end
		if( frame.auras.debuffs ) then
			for _, button in pairs(frame.auras.debuffs.buttons) do
				button:Hide()
			end
		end
	end
	
	if( not frame.visibility.auras ) then return end

	if( config.auras.buffs.enabled ) then
		updateGroup(frame, "buffs", config.auras.buffs, config.auras.debuffs)
	end
	
	if( config.auras.debuffs.enabled ) then
		updateGroup(frame, "debuffs", config.auras.debuffs, config.auras.buffs)
	end
			
	-- Anchor an aura group to another aura group
	frame.auras.anchorAurasOn = nil
	if( config.auras.buffs.enabled and config.auras.debuffs.enabled ) then
		if( config.auras.buffs.anchorOn ) then
			frame.auras.anchorAurasOn = frame.auras.debuffs
			frame.auras.anchorAurasChild = frame.auras.buffs
		elseif( config.auras.debuffs.anchorOn ) then
			frame.auras.anchorAurasOn = frame.auras.buffs
			frame.auras.anchorAurasChild = frame.auras.debuffs
		end
	end
		
	-- Check if either auras are anchored to each other
	if( config.auras.buffs.anchorPoint == config.auras.debuffs.anchorPoint and config.auras.buffs.enabled and config.auras.debuffs.enabled and not config.auras.buffs.anchorOn and not config.auras.debuffs.anchorOn ) then
		frame.auras.anchor = frame.auras[config.auras.buffs.enabled and "buffs" or "debuffs"]
		frame.auras.primary = config.auras.buffs.prioritize and "buffs" or "debuffs"
		frame.auras.secondary = frame.auras.primary == "buffs" and "debuffs" or "buffs"
	else
		frame.auras.anchor = nil
	end
end

-- Temporary enchant support
local timeElapsed = 0
local mainHand, offHand = {time = 0}, {time = 0}
local function updateTemporaryEnchant(frame, slot, tempData, hasEnchant, timeLeft, charges)
	if( tempData.has and timeLeft < tempData.time and charges == tempData.charges ) then return end
	
	-- Some trickys magic, we can't get the start time of temporary enchants easily.
	-- So will save the first time we find when a new enchant is added
	if( timeLeft > tempData.time or not tempData.has ) then
		tempData.startTime = GetTime()
	end

	tempData.has = hasEnchant
	tempData.time = timeLeft
	tempData.charges = charges
		
	local config = ShadowUF.db.profile.units[frame.parent.unitType].auras[frame.type]
	
	-- Create any buttons we need
	if( #(frame.buttons) < frame.temporaryEnchants ) then
		updateButton(frame.temporaryEnchants, frame, config)
	end
				
	local button = frame.buttons[frame.temporaryEnchants]
	
	-- Purple border
	button.border:SetVertexColor(0.50, 0, 0.50)
	
	-- Show the cooldown ring
	if( not ShadowUF.db.profile.auras.disableCooldown ) then
		button.cooldown:SetCooldown(tempData.startTime, timeLeft / 1000)
		button.cooldown:Show()
	end

	-- Enlarge our own auras
	if( config.enlargeSelf and caster == ShadowUF.playerUnit ) then
		button.isSelfScaled = true
		button:SetScale(config.selfScale)
	else
		button.isSelfScaled = nil
		button:SetScale(1)
	end

	-- Size it
	button:SetHeight(config.size)
	button:SetWidth(config.size)
	button.border:SetHeight(config.size + 1)
	button.border:SetWidth(config.size + 1)
	
	-- Stack + icon + show! Never understood why, auras sometimes return 1 for stack even if they don't stack
	button.auraID = slot
	button.filter = "TEMP"
	button.unit = nil
	button.columnHasScaled = nil
	button.previousHasScale = nil
	button.icon:SetTexture(GetInventoryItemTexture("player", slot))
	button.stack:SetText(charges > 1 and charges or "")
	button:Show()
end

-- Unfortunately, temporary enchants have basically no support beyond hacks. So we will hack!
tempEnchantScan = function(self, elapsed)
	timeElapsed = timeElapsed + elapsed
	if( timeElapsed < 1 ) then return end
	timeElapsed = 0

	local hasMain, mainTimeLeft, mainCharges, hasOff, offTimeLeft, offCharges = GetWeaponEnchantInfo()
	self.temporaryEnchants = 0
	
	if( hasMain ) then
		self.temporaryEnchants = self.temporaryEnchants + 1
		updateTemporaryEnchant(self, 16, mainHand, hasMain, mainTimeLeft or 0, mainCharges)
		mainHand.time = mainTimeLeft or 0
	end

	mainHand.has = hasMain
	
	if( hasOff and self.temporaryEnchants < self.maxAuras ) then
		self.temporaryEnchants = self.temporaryEnchants + 1
		updateTemporaryEnchant(self, 17, offHand, hasOff, offTimeLeft or 0, offCharges)
		offHand.time = offTimeLeft or 0
	end
	
	offHand.has = hasOff
	
	-- Update if totals changed
	if( self.lastTemporary ~= self.temporaryEnchants ) then
		self.lastTemporary = self.temporaryEnchants
		Auras:Update(self.parent)
	end
end

-- Nice and simple, don't need to do a full update because either this is called in an OnEnable or
-- the zone monitor will handle it all cleanly. The fun part of this code is aura filtering itself takes 10 seconds
-- but making the configuration clean takes two weeks and another 2-3 days of implementing
-- This isn't actually filled with data, it's just to stop any errors from triggering if no filter is added
local filterDefault = {}
function Auras:UpdateFilter(frame)
	local zone = select(2, IsInInstance())
	local id = zone .. frame.unitType
	
	local filter = ShadowUF.db.profile.filters.zones[zone .. frame.unitType]
	frame.auras.whitelist = filter and ShadowUF.db.profile.filters.whitelists[filter] or filterDefault
	frame.auras.blacklist = filter and ShadowUF.db.profile.filters.blacklists[filter] or filterDefault
end

-- Scan for auras
local function scan(parent, frame, type, config, filter)
	if( frame.totalAuras >= frame.maxAuras ) then return end
	
	local isFriendly = UnitIsFriend(frame.parent.unit, "player")
	
	
	local index = 0
	while( true ) do
		index = index + 1
		local name, rank, texture, count, auraType, duration, endTime, caster, isStealable = UnitAura(frame.parent.unit, index, filter)
		if( not name ) then break end
		
		if( ( not config.player or caster == ShadowUF.playerUnit ) and ( not parent.whitelist[type] and not parent.blacklist[type] or parent.whitelist[type] and parent.whitelist[name] or parent.blacklist[type] and not parent.blacklist[name] ) ) then
			-- Create any buttons we need
			frame.totalAuras = frame.totalAuras + 1
			if( #(frame.buttons) < frame.totalAuras ) then
				updateButton(frame.totalAuras, frame, ShadowUF.db.profile.units[frame.parent.unitType].auras[frame.type])
			end
				
			-- Show debuff border, or a special colored border if it's stealable
			local button = frame.buttons[frame.totalAuras]
			if( isStealable and not isFriendly ) then
				button.border:SetVertexColor(stealableColor.r, stealableColor.g, stealableColor.b)
			elseif( not isFriendly or type == "debuffs" ) then
				local color = auraType and DebuffTypeColor[auraType] or DebuffTypeColor.none
				button.border:SetVertexColor(color.r, color.g, color.b)
			else
				button.border:SetVertexColor(0.60, 0.60, 0.60)
			end
			
			-- Show the cooldown ring
			if( not ShadowUF.db.profile.auras.disableCooldown and duration > 0 and endTime > 0 and ( not config.selfTimers or ( config.selfTimers and caster == ShadowUF.playerUnit ) ) ) then
				button.cooldown:SetCooldown(endTime - duration, duration)
				button.cooldown:Show()
			else
				button.cooldown:Hide()
			end
			
			-- Enlarge our own auras
			if( config.enlargeSelf and caster == ShadowUF.playerUnit ) then
				button.isSelfScaled = true
				button:SetScale(config.selfScale)
			else
				button.isSelfScaled = nil
				button:SetScale(1)
			end

			-- Size it
			button:SetHeight(config.size)
			button:SetWidth(config.size)
			button.border:SetHeight(config.size + 1)
			button.border:SetWidth(config.size + 1)
			
			-- Stack + icon + show! Never understood why, auras sometimes return 1 for stack even if they don't stack
			button.auraID = index
			button.filter = filter
			button.unit = frame.parent.unit
			button.columnHasScaled = nil
			button.previousHasScale = nil
			button.icon:SetTexture(texture)
			button.stack:SetText(count > 1 and count or "")
			button:Show()
			
			-- Too many auras shown break out
			-- Get down
			if( frame.totalAuras >= frame.maxAuras ) then break end
		end
	end

	for i=frame.totalAuras + 1, #(frame.buttons) do frame.buttons[i]:Hide() end
end

local function anchorGroupToGroup(frame, config, group, childConfig, childGroup)
	-- Child group has nothing in it yet, so don't care
	if( not childGroup.buttons[1] ) then return end

	-- Group we want to anchor to has nothing in it, takeover the postion
	if( group.totalAuras == 0 ) then
		local position = positionData[config.anchorPoint]
		childGroup.buttons[1]:SetPoint(ShadowUF.Layout:GetPoint(config.anchorPoint), group.anchorTo, ShadowUF.Layout:GetRelative(config.anchorPoint), config.x + (position.xMod * ShadowUF.db.profile.backdrop.inset), config.y + (position.yMod * ShadowUF.db.profile.backdrop.inset))
		return
	end
	
	local anchorTo
	for i=#(group.buttons), 1, -1 do
		local button = group.buttons[i]
		if( button.isAuraAnchor and button:IsVisible() ) then
			anchorTo = button
			break
		end
	end

	local position = positionData[childGroup.forcedAnchorPoint or childConfig.anchorPoint] 
	if( position.isSideGrowth ) then
		position.aura(childGroup.buttons[1], anchorTo)
	else
		position.column(childGroup.buttons[1], anchorTo, 2)
	end
end

Auras.anchorGroupToGroup = anchorGroupToGroup

--[[
-- Debug
local textureList = {
	[0] = "Interface\\Icons\\Spell_Nature_Rejuvenation",
	[1] = "Interface\\Icons\\INV_Misc_Herb_Felblossom",
	[2] = "Interface\\Icons\\Spell_Nature_ResistNature",
	[3] = "Interface\\Icons\\Ability_Druid_Flourish",
}
 
local debuffType = {
	[0] = "Magic",
	[1] = "Curse",
	[2] = "Poison",
	[3] = "Disease",
	[4] = "none",
}
 
UnitAura = function(unit, id, filter)
	if( id >= 20 ) then return end
	return "Test aura", "Rank 1", textureList[id % 4], id, debuffType[id % 5], 0, 0, "none", false
end
]]

-- Do an update and figure out what we need to scan
function Auras:Update(frame)
	local config = ShadowUF.db.profile.units[frame.unitType].auras
	if( frame.auras.anchor ) then
		frame.auras.anchor.totalAuras = frame.auras.anchor.temporaryEnchants
		
		scan(frame.auras, frame.auras.anchor, frame.auras.primary, config[frame.auras.primary], frame.auras[frame.auras.primary].filter)
		scan(frame.auras, frame.auras.anchor, frame.auras.secondary, config[frame.auras.secondary], frame.auras[frame.auras.secondary].filter)
	else
		if( config.buffs.enabled ) then
			frame.auras.buffs.totalAuras = frame.auras.buffs.temporaryEnchants
			scan(frame.auras, frame.auras.buffs, "buffs", config.buffs, frame.auras.buffs.filter)
		end

		if( config.debuffs.enabled ) then
			frame.auras.debuffs.totalAuras = 0
			scan(frame.auras, frame.auras.debuffs, "debuffs", config.debuffs, frame.auras.debuffs.filter)
		end
		
		if( frame.auras.anchorAurasOn ) then
			anchorGroupToGroup(frame, config[frame.auras.anchorAurasOn.type], frame.auras.anchorAurasOn, config[frame.auras.anchorAurasChild.type], frame.auras.anchorAurasChild)
		end
	end
end

local function setupAuras(frame, config, type)
	if( frame.auras[type] ) then
		for _, button in pairs(frame.auras[type].buttons) do
			button:Hide()
		end
	end
	
	if( not config.enabled ) then return end
	frame.auras[type] = frame.auras[type] or CreateFrame("Frame", nil, frame)
	frame.auras[type].buttons = frame.auras[type].buttons or {}
	frame.auras[type].anchorTo = frame
	frame.auras[type].totalAuras = config.maxRows * config.perRow
		
	-- If debuffs are anchored to buffs, debuffs need to grow however buffs do
	local reverseConfig = type == "buffs" and ShadowUF.db.profile.units[frame.unitType].auras.debuffs or ShadowUF.db.profile.units[frame.unitType].auras.buffs
	if( config.anchorOn and reverseConfig.enabled ) then
		frame.auras[type].forcedAnchorPoint = reverseConfig.anchorPoint
	end

	for id=1, frame.auras[type].totalAuras do
		updateButton(id, frame.auras[type], config)
		local button = frame.auras[type].buttons[id]
		
		if( type == "buffs" ) then
			button.border:SetVertexColor(0.60, 0.60, 0.60)
		else
			button.border:SetVertexColor(0.80, 0, 0)
		end
		
		button.icon:SetTexture(id % 2 == 0 and "Interface\\Icons\\Spell_Nature_Rejuvenation" or "Interface\\Icons\\Spell_Nature_Riptide")
		button.stack:SetText(id)
		button:SetScript("OnEnter", nil)
		button:SetScript("OnLeave", nil)
		button:SetScript("OnClick", nil)
		button:Show()
	end
end

function Auras:TestMode(frame, config)
	setupAuras(frame, config.auras.buffs, "buffs")
	setupAuras(frame, config.auras.debuffs, "debuffs")
end
