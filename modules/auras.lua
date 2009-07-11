local Auras = {}
local stealableColor = {r = 1, g = 1, b = 1}
ShadowUF:RegisterModule(Auras, "auras", ShadowUFLocals["Auras"])

function Auras:OnEnable(frame)
	frame.auras = frame.auras or {}

	frame:RegisterNormalEvent("PLAYER_ENTERING_WORLD", self, "Update")
	frame:RegisterUnitEvent("UNIT_AURA", self, "Update")
	frame:RegisterUpdateFunc(self, "Update")
end

function Auras:OnDisable(frame)
	frame:UnregisterAll(self)
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
	GameTooltip:SetUnitAura(self.unit, self.auraID, self.filter)

	self:SetScript("OnUpdate", updateTooltip)
end

local function hideTooltip(self)
	self:SetScript("OnUpdate", nil)
	GameTooltip:Hide()
end

local function cancelBuff(self)
	CancelUnitBuff(self.unit, self.auraID, self.filter)
end

local function updateButton(id, anchor, config)
	local button = anchor.buttons[id]
	if( not button ) then
		anchor.buttons[id] = CreateFrame("Button", nil, anchor)
		anchor.createdButtons = anchor.createdButtons + 1
		
		button = anchor.buttons[id]
		button:SetScript("OnEnter", showTooltip)
		button:SetScript("OnLeave", hideTooltip)
		button:SetScript("OnClick", cancelBuff)
		button:RegisterForClicks("RightButtonUp")
		
		button.cooldown = CreateFrame("Cooldown", nil, button)
		button.cooldown:SetAllPoints(button)
		button.cooldown:SetReverse(true)
		button.cooldown:Hide()			
		
		button.stack = button:CreateFontString(nil, "OVERLAY")
		button.stack:SetFont("Interface\\AddOns\\ShadowedUnitFrames\\media\\fonts\\Myriad Condensed Web.ttf", 10, "OUTLINE")
		button.stack:SetShadowColor(0, 0, 0, 1.0)
		button.stack:SetShadowOffset(0.8, -0.8)
		button.stack:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", 1, 0)
		button.stack:SetWidth(18)
		button.stack:SetHeight(10)
		button.stack:SetJustifyH("RIGHT")

		button.border = button:CreateTexture(nil, "ARTWORK")
		button.border:SetTexture("Interface\\Buttons\\UI-Debuff-Overlays")
		button.border:SetTexCoord(0.296875, 0.5703125, 0, 0.515625)
		button.border:SetPoint("CENTER", button)
		
		button.icon = button:CreateTexture(nil, "BACKGROUND")
		button.icon:SetAllPoints(button)
		button.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
	end
	
	-- Set the button sizing
	button:SetHeight(config.size)
	button:SetWidth(config.size)
	button.border:SetHeight(config.size + 1)
	button.border:SetWidth(config.size + 1)
	button:ClearAllPoints()
	button:Hide()
	
	-- Position, oh god is this long :<
	if( id > 1 ) then
		if( config.anchorPoint == "BL" or config.anchorPoint == "TL" ) then
			if( id % config.perRow == 1 or config.perRow == 1 ) then
				if( config.anchorPoint == "TL" ) then
					button:SetPoint("BOTTOM", anchor.buttons[id - config.perRow], "TOP", 0, 2)
				else
					button:SetPoint("TOP", anchor.buttons[id - config.perRow], "BOTTOM", 0, -2)
				end
			else
				button:SetPoint("LEFT", anchor.buttons[id - 1], "RIGHT", 1, 0)
			end
		elseif( id % config.perRow == 1 or config.perRow == 1 ) then
			if( config.anchorPoint == "RT77" ) then
				button:SetPoint("LEFT", anchor.buttons[id - config.perRow], "RIGHT", 1, 0)
			else
				button:SetPoint("RIGHT", anchor.buttons[id - config.perRow], "LEFT", -1, 0)
			end
		else
			button:SetPoint("TOP", anchor.buttons[id - 1], "BOTTOM", 0, -2)
		end
	elseif( config.anchorPoint == "BL" ) then
		button:SetPoint("BOTTOMLEFT", anchor.parent, "BOTTOMLEFT", config.x + ShadowUF.db.profile.backdrop.inset, config.y + -(config.size + 2))
	elseif( config.anchorPoint == "TL" ) then
		button:SetPoint("TOPLEFT", anchor.parent, "TOPLEFT", config.x + ShadowUF.db.profile.backdrop.inset, config.y + (config.size + 2))
	elseif( config.anchorPoint == "LT" ) then
		button:SetPoint("TOPLEFT", anchor.parent, "TOPLEFT", config.x + -config.size, config.y + ShadowUF.db.profile.backdrop.inset + ShadowUF.db.profile.backdrop.clip)
	elseif( config.anchorPoint == "RT" ) then
		button:SetPoint("TOPRIGHT", anchor.parent, "TOPRIGHT", config.x + config.size, config.y + ShadowUF.db.profile.backdrop.inset + ShadowUF.db.profile.backdrop.clip)
	end
end

-- Create an aura anchor as well as the buttons to contain it
local function updateAnchor(self, type, config)
	self.auras[type] = self.auras[type] or CreateFrame("Frame", nil, self.highFrame)
	
	local group = self.auras[type]
	group.buttons = group.buttons or {}
	
	group.maxAuras = config.perRow * config.maxRows
	group.createdButtons = 0
	group.totalAuras = 0
	group.type = type
	group.parent = self
	group:SetFrameLevel(5)
	group:Show()
	
	-- Update filters used for the anchor
	group.filter = group.type == "buffs" and "HELPFUL" or group.type == "debuffs" and "HARMFUL" or ""

	-- This is a bit of an odd filter, when used with a HELPFUL filter, it will only return buffs you can cast on group members
	-- When used with HARMFUL it will only return debuffs you can cure
	if( config.raid ) then
		group.filter = group.filter .. "|RAID"
	end
end

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
		updateAnchor(frame, "buffs", config.auras.buffs)
	end
	
	if( config.auras.debuffs.enabled ) then
		updateAnchor(frame, "debuffs", config.auras.debuffs)
	end
		
	-- Anchor an aura group to another aura group
	if( config.auras.buffs.enabled and config.auras.debuffs.enabled ) then
		if( config.auras.buffs.anchorOn ) then
			frame.auras.buffs.anchorTo = frame.auras.debuffs
		elseif( config.auras.debuffs.anchorOn ) then
			frame.auras.debuffs.anchorTo = frame.auras.buffs
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

-- Scan for auras
local function scan(frame, type, config, filter)
	local index = 0
	while( true ) do
		index = index + 1
		local name, rank, texture, count, debuffType, duration, endTime, caster, isStealable = UnitAura(frame.parent.unit, index, filter)
		if( not name ) then break end
		
		if( not config.player or caster == ShadowUF.playerUnit ) then
			-- Create any buttons we need
			frame.totalAuras = frame.totalAuras + 1
			if( frame.createdButtons < frame.totalAuras ) then
				updateButton(frame.totalAuras, frame, ShadowUF.db.profile.units[frame.parent.unitType].auras[frame.type])
			end
				
			-- Show debuff border, or a special colored border if it's stealable
			local button = frame.buttons[frame.totalAuras]
			if( button.type == "debuffs" ) then
				local color = isStealable and stealableColor or debuffType and DebuffTypeColor[debuffType] or DebuffTypeColor.none
				button.border:SetVertexColor(color.r, color.g, color.b)
			else
				button.border:SetVertexColor(0.60, 0.60, 0.60)
			end
			
			-- Show the cooldown ring
			if( ( not config.selfTimers or ( config.selfTimers and caster == ShadowUF.playerUnit ) ) and duration > 0 and endTime > 0 ) then
				button.cooldown:SetCooldown(endTime - duration, duration)
				button.cooldown:Show()
			else
				button.cooldown:Hide()
			end
			
			-- Size it
			button:SetHeight(config.size)
			button:SetWidth(config.size)
			button.border:SetHeight(config.size + 1)
			button.border:SetWidth(config.size + 1)

			-- Enlarge our own auras
			if( config.enlargeSelf and caster == ShadowUF.playerUnit ) then
				button:SetScale(config.selfScale)
			else
				button:SetScale(1)
			end
			
			-- Stack + icon + show! Never understood why, auras sometimes return 1 for stack even if they don't stack
			button.auraID = index
			button.filter = filter
			button.unit = frame.parent.unit
			button.icon:SetTexture(texture)
			button.stack:SetText(count > 1 and count or "")
			button:Show()
			
			-- Too many auras shown break out
			if( frame.totalAuras >= frame.maxAuras ) then break end
		end
	end

	for i=frame.totalAuras + 1, frame.createdButtons do frame.buttons[i]:Hide() end
end

-- Do an update and figure out what we need to scan
function Auras:Update(frame)
	local config = ShadowUF.db.profile.units[frame.unitType].auras
	if( frame.auras.anchor ) then
		frame.auras.anchor.totalAuras = 0
		
		scan(frame.auras.anchor, frame.auras.primary, config[frame.auras.primary], frame.auras[frame.auras.primary].filter)
		scan(frame.auras.anchor, frame.auras.secondary, config[frame.auras.secondary], frame.auras[frame.auras.secondary].filter)
	else
		if( config.buffs.enabled ) then
			frame.auras.buffs.totalAuras = 0
			scan(frame.auras.buffs, "buffs", config.buffs, frame.auras.buffs.filter)
		end

		if( config.debuffs.enabled ) then
			frame.auras.debuffs.totalAuras = 0
			scan(frame.auras.debuffs, "debuffs", config.debuffs, frame.auras.debuffs.filter)
		end
	end
end
