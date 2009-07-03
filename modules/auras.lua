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
		if( config.anchorPoint == "BOTTOM" or config.anchorPoint == "TOP" or config.anchorPoint == "INSIDE" ) then
			if( id % config.perRow == 1 ) then
				if( config.anchorPoint == "TOP" ) then
					button:SetPoint("BOTTOM", anchor.buttons[id - config.perRow], "TOP", 0, 2)
				else
					button:SetPoint("TOP", anchor.buttons[id - config.perRow], "BOTTOM", 0, -2)
				end
			elseif( config.anchorPoint == "INSIDE" ) then
				button:SetPoint("RIGHT", anchor.buttons[id - 1], "LEFT", -1, 0)
			else
				button:SetPoint("LEFT", anchor.buttons[id - 1], "RIGHT", 1, 0)
			end
		elseif( id % config.maxRows == 1 or config.maxRows == 1 ) then
			if( config.anchorPoint == "RIGHT" ) then
				button:SetPoint("LEFT", anchor.buttons[id - config.maxRows], "RIGHT", 1, 0)
			else
				button:SetPoint("RIGHT", anchor.buttons[id - config.maxRows], "LEFT", -1, 0)
			end
		else
			button:SetPoint("TOP", anchor.buttons[id - 1], "BOTTOM", 0, -2)
		end
	elseif( config.anchorPoint == "INSIDE" ) then
		button:SetPoint("TOPRIGHT", anchor.parent.healthBar, "TOPRIGHT", config.x + -ShadowUF.db.profile.backdrop.clip, config.y + -ShadowUF.db.profile.backdrop.clip)
	elseif( config.anchorPoint == "BOTTOM" ) then
		button:SetPoint("BOTTOMLEFT", anchor.parent, "BOTTOMLEFT", config.x + ShadowUF.db.profile.backdrop.inset, config.y + -(config.size + 2))
	elseif( config.anchorPoint == "TOP" ) then
		button:SetPoint("TOPLEFT", anchor.parent, "TOPLEFT", config.x + ShadowUF.db.profile.backdrop.inset, config.y + (config.size + 2))
	elseif( config.anchorPoint == "LEFT" ) then
		button:SetPoint("TOPLEFT", anchor.parent, "TOPLEFT", config.x + -config.size, config.y + ShadowUF.db.profile.backdrop.inset + ShadowUF.db.profile.backdrop.clip)
	elseif( config.anchorPoint == "RIGHT" ) then
		button:SetPoint("TOPRIGHT", anchor.parent, "TOPRIGHT", config.x + config.size, config.y + ShadowUF.db.profile.backdrop.inset + ShadowUF.db.profile.backdrop.clip)
	end
end

-- Create an aura anchor as well as the buttons to contain it
local function updateAnchor(self, type, config)
	-- Anchor type is disabled so hide it
	if( not config.enabled ) then
		ShadowUF.Layout:ToggleVisibility(self.auras[type], false)
		return
	end
	
	self.auras[type] = self.auras[type] or CreateFrame("Frame", nil, self.highFrame)
	
	local anchor = self.auras[type]
	anchor.buttons = anchor.buttons or {}
	anchor.maxAuras = config.perRow * config.maxRows
	anchor.createdButtons = 0
	anchor.totalAuras = 0
	anchor.type = type
	anchor.parent = self
	anchor:SetFrameLevel(config.anchorPoint == "INSIDE" and 5 or 1)
	anchor:Show()
	
	-- Update filters used for the anchor
	anchor.filter = anchor.type == "buffs" and "HELPFUL" or anchor.type == "debuffs" and "HARMFUL" or ""

	-- This is a bit of an odd filter, when used with a HELPFUL filter, it will only return buffs you can cast on group members
	-- When used with HARMFUL it will only return debuffs you can cure
	if( config.raid ) then
		anchor.filter = anchor.filter .. "|RAID"
	end

	-- Create and position all of the sub anchors
	for id=1, anchor.createdButtons do
		updateButton(id, anchor, config)
	end
end

function Auras:OnLayoutApplied(frame, config)
	if( not frame.visibility.auras ) then
		if( frame.auras ) then
			if( frame.auras.buffs ) then for _, button in pairs(frame.auras.buffs.buttons) do button:Hide() end end
			if( frame.auras.debuffs ) then for _, button in pairs(frame.auras.debuffs.buttons) do button:Hide() end end
		end
		return
	end
	
	updateAnchor(frame, "buffs", config.auras.buffs)
	updateAnchor(frame, "debuffs", config.auras.debuffs)

	frame.auras.anchor = config.auras.buffs.enabled and "buffs" or "debuffs"
end

function Auras:UpdateDisplay(frame, unitType)
	for _, button in pairs(frame.buttons) do button:Hide() end
	
	-- Position aura
	for i=1, frame.totalAuras do
		local button = frame.buttons[i]
		local config = ShadowUF.db.profile.units[unitType].auras[button.type]
		
		-- Show debuff border, or a special colored border if it's stealable
		if( button.type == "debuffs" ) then
			local color =  button.auraStealable and stealableColor or button.auraType and DebuffTypeColor[button.auraType] or DebuffTypeColor.none
			button.border:SetVertexColor(color.r, color.g, color.b)
		else
			button.border:SetVertexColor(0.60, 0.60, 0.60, 1.0)
		end
		
		-- Show the cooldown ring
		if( ( not config.selfTimers or ( config.selfTimers and button.auraPlayers ) ) and button.auraDuration > 0 and button.auraEnd > 0 ) then
			button.cooldown:SetCooldown(button.auraEnd - button.auraDuration, button.auraDuration)
			button.cooldown:Show()
		else
			button.cooldown:Hide()
		end
		
		-- Enlarge our own auras
		if( config.enlargeSelf and button.auraPlayers ) then
			button:SetScale(1.30)
		else
			button:SetScale(1)
		end
		
		-- Stack + icon + show!
		button.icon:SetTexture(button.auraTexture)
		button.stack:SetText(button.auraCount > 1 and button.auraCount or "")
		button:Show()
	end
end

function Auras:Scan(frame, type, config, filter)
	local index = 0
	while( true ) do
		index = index + 1
		local name, _, texture, count, debuffType, duration, endTime, caster, isStealable = UnitAura(frame.parent.unit, index, filter)
		if( not name ) then break end
		
		if( not config.player or caster == ShadowUF.playerUnit ) then
			frame.totalAuras = frame.totalAuras + 1
			
			-- Hit our limit, too many shown
			if( frame.totalAuras >= frame.maxAuras ) then
				frame.totalAuras = frame.maxAuras
				return
			-- Create any buttons we need
			elseif( frame.createdButtons < frame.totalAuras ) then
				updateButton(frame.totalAuras, frame, ShadowUF.db.profile.units[frame.parent.unitType].auras[frame.type])
			end
			
			local button = frame.buttons[frame.totalAuras]
			button.auraName = name
			button.auraTexture = texture
			button.auraCount = count
			button.auraType = debuffType
			button.auraDuration = duration
			button.auraEnd = endTime
			button.auraStealable = isStealable
			button.auraPlayers = caster == ShadowUF.playerUnit
			button.auraID = index
			button.type = type
			button.filter = filter
			button.unit = frame.parent.unit
		end
	end
end

-- This needs a bit of optimization later
function Auras:Update(frame)
	local config = ShadowUF.db.profile.units[frame.unitType].auras
	if( config.buffs.anchorPoint == config.debuffs.anchorPoint ) then
		frame.auras[frame.auras.anchor].totalAuras = 0
				
		if( config.buffs.prioritize ) then
			if( config.buffs.enabled ) then
				self:Scan(frame.auras[frame.auras.anchor], "buffs", config.buffs, frame.auras.buffs.filter)
			end
			if( config.debuffs.enabled ) then
				self:Scan(frame.auras[frame.auras.anchor], "debuffs", config.debuffs, frame.auras.debuffs.filter)
			end
		else
			if( config.debuffs.enabled ) then
				self:Scan(frame.auras[frame.auras.anchor], "debuffs", config.debuffs, frame.auras.debuffs.filter)
			end
			if( config.buffs.enabled ) then
				self:Scan(frame.auras[frame.auras.anchor], "buffs", config.buffs, frame.auras.buffs.filter)
			end
		end
		
		self:UpdateDisplay(frame.auras[frame.auras.anchor], frame.unitType)
	else
		if( config.buffs.enabled ) then
			frame.auras.buffs.totalAuras = 0
			self:Scan(frame.auras[frame.auras.anchor], "buffs", config.buffs, frame.auras.buffs.filter)
			self:UpdateDisplay(frame.auras.buffs, frame.unitType)
		end

		if( config.debuffs.enabled ) then
			frame.auras.debuffs.totalAuras = 0
			self:Scan(frame.auras[frame.auras.anchor], "debuffs", config.debuffs, frame.auras.debuffs.filter)
			self:UpdateDisplay(frame.auras.debuffs, frame.unitType)
		end
	end
end
