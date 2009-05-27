local Auras = {}
local canRemove
ShadowUF:RegisterModule(Auras, "auras", ShadowUFLocals["Auras"])

function Auras:CheckCures()
	local classToken = select(2, UnitClass("player"))
	-- If they are a Shaman, then we need to check what they can cure when spells change
	if( not self.eventFrame and classToken == "SHAMAN" ) then
		self.eventFrame = CreateFrame("Frame")
		self.eventFrame:RegisterEvent("SPELLS_CHANGED")
		self.eventFrame:SetScript("OnEvent", function(self) canRemove.Curse = GetSpellInfo((GetSpellInfo(51886))) and true or false	end)
	end
	
	canRemove = canRemove or {}
	canRemove.Curse = classToken == "DRUID" or classToken == "MAGE" or GetSpellInfo((GetSpellInfo(51886))) or false
	canRemove.Poison = classToken == "PALADIN" or classToken == "SHAMAN"
	canRemove.Disease = classToken == "SHAMAN" or classToken == "PRIEST" or classToken == "PALADIN"
	canRemove.Magic = classToken == "PALADIN" or classToken == "PRIEST"
end

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

function Auras:UnitEnabled(frame)
	if( not frame.visibility.auras or not ShadowUF.db.profile.units[frame.unitType].auras ) then
		return
	end
	
	if( not canRemove ) then
		self:CheckCures()
	end
	
	self:CreateIcons(frame)
		
	frame:RegisterUnitEvent("UNIT_AURA", self, "Update")
	frame:RegisterNormalEvent("PLAYER_ENTERING_WORLD", self, "Update")
	frame:RegisterUpdateFunc(self, "Update")
end

function Auras:UnitDisabled(frame)
	frame:UnregisterAll(self)
end

local filterTable = {}
function Auras:UpdateFilter(auraGroup, config)
	auraGroup.filter = config.HELPFUL and "HELPFUL" or ""
	auraGroup.filter = config.HARMFUL and "HARMFUL" or auraGroup.filter
	
	if( auraGroup.RAID ) then
		auraGroup.filter = auraGroup.filter .. "|RAID"
	end
end

local function createAnchor(self, key, config)
	self.auras[key] = self.auras[key] or CreateFrame("Frame", nil, self)

	local aura = self.auras[key]
	aura.buttons = aura.buttons or {}
	aura.maxAuras = config.perRow * config.maxRows
	aura.parent = self
	aura.totalAuras = 0
	
	for i=1, aura.maxAuras do
		if( not aura.buttons[i] ) then
			aura.buttons[i] = CreateFrame("Button", nil, aura)
			local button = aura.buttons[i]
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
	end
	
	for _, button in pairs(aura.buttons) do
		button:Hide()
	end
	
	Auras:UpdateFilter(aura, ShadowUF.db.profile.units[self.unitType].auras[key])
end

function Auras:PreLayoutApplied(frame)
	self:CreateIcons(frame)

	frame.auras.anchor = "buffs"
	if( not ShadowUF.db.profile.units[frame.unitType].auras.buffs.enabled ) then
		frame.auras.anchor = "debuffs"
	end

	self:Update(frame)
end

function Auras:CreateIcons(frame)
	frame.auras = frame.auras or {}
	
	createAnchor(frame, "buffs", ShadowUF.db.profile.units[frame.unitType].auras.buffs)
	createAnchor(frame, "debuffs", ShadowUF.db.profile.units[frame.unitType].auras.debuffs)
end

function Auras:LayoutApplied(frame)
	if( frame.auras and ShadowUF.db.profile.units[frame.unitType].auras ) then
		self:UpdateFilter(frame.auras.buffs, ShadowUF.db.profile.units[frame.unitType].auras.buffs)
		self:UpdateFilter(frame.auras.debuffs, ShadowUF.db.profile.units[frame.unitType].auras.debuffs)
		
		self:Update(frame)
	end
end

local stealableColor = { r = 1, g = 1, b = 1 }
function Auras:UpdateDisplay(frame, unitType)
	for _, button in pairs(frame.buttons) do
		button:Hide()
	end

	if( frame.totalAuras == 0 ) then
		return
	end
		
	for i=1, frame.totalAuras do
		local button = frame.buttons[i]
		if( button.auraDuration and button.auraEnd ) then
			local config = ShadowUF.db.profile.units[unitType].auras[button.type]
			if( button.type == "debuffs" ) then
				local color =  button.auraStealable and stealableColor or button.auraType and DebuffTypeColor[button.auraType] or DebuffTypeColor.none
				button.border:SetVertexColor(color.r, color.g, color.b)
			else
				button.border:SetVertexColor(0.60, 0.60, 0.60, 1.0)
			end
			
			if( ( not config.selfTimers or ( config.selfTimers and button.auraPlayers ) ) and button.auraDuration > 0 and button.auraEnd > 0 ) then
				button.cooldown:SetCooldown(button.auraEnd - button.auraDuration, button.auraDuration)
				button.cooldown:Show()
			else
				button.cooldown:Hide()
			end
			
			if( config.enlargeSelf and button.auraPlayers ) then
				button:SetScale(1.30)
			else
				button:SetScale(1)
			end
			
			button.icon:SetTexture(button.auraTexture)
			button.stack:SetText(button.auraCount > 1 and button.auraCount or "")
			button:Show()
		end
	end
end

function Auras:Scan(frame, filter, type, unit, specialFilters)
	local index = 0
	while( true ) do
		index = index + 1
		local name, rank, texture, count, debuffType, duration, endTime, caster, isStealable = UnitAura(unit, index, filter)
		if( not name ) then break end
		
		if( ( not specialFilters.CURABLE or debuffType and canRemove[debuffType] ) and ( not specialFilters.PLAYER or caster == "player" )  ) then
			frame.totalAuras = frame.totalAuras + 1
			if( frame.totalAuras >= frame.maxAuras ) then
				frame.totalAuras = frame.maxAuras
				return 0
			end
			
			local button = frame.buttons[frame.totalAuras]
			button.auraName = name
			button.auraRank = rank
			button.auraTexture = texture
			button.auraCount = count
			button.auraType = debuffType
			button.auraDuration = duration
			button.auraEnd = endTime
			button.auraStealable = isStealable
			button.auraCaster = caster
			button.auraPlayers = caster == "player"
			button.auraID = index
			button.filter = filter
			button.type = type
			button.unit = unit
		end
	end
end

function Auras:Update(frame)
	local unit = frame.unit
	local config = ShadowUF.db.profile.units[frame.unitType].auras
	if( config.buffs.anchorPoint == config.debuffs.anchorPoint ) then
		frame.auras[frame.auras.anchor].totalAuras = 0
				
		if( config.buffs.prioritize ) then
			if( config.buffs.enabled ) then
				self:Scan(frame.auras[frame.auras.anchor], frame.auras.buffs.filter, "buffs", unit, config.buffs)
			end
			if( config.debuffs.enabled ) then
				self:Scan(frame.auras[frame.auras.anchor], frame.auras.debuffs.filter, "debuffs", unit, config.debuffs)
			end
		else
			if( config.debuffs.enabled ) then
				self:Scan(frame.auras[frame.auras.anchor], frame.auras.debuffs.filter, "debuffs", unit, config.debuffs)
			end
			if( config.buffs.enabled ) then
				self:Scan(frame.auras[frame.auras.anchor], frame.auras.buffs.filter, "buffs", unit, config.buffs)
			end
		end
		
		self:UpdateDisplay(frame.auras[frame.auras.anchor], frame.unitType)
	else
		if( config.buffs.enabled ) then
			frame.auras.buffs.totalAuras = 0
			self:Scan(frame.auras.buffs, frame.auras.buffs.filter, "buffs", unit, config.buffs)
			self:UpdateDisplay(frame.auras.buffs, frame.unitType)
		end

		if( config.debuffs.enabled ) then
			frame.auras.debuffs.totalAuras = 0
			self:Scan(frame.auras.debuffs, frame.auras.debuffs.filter, "debuffs", unit, config.debuffs)
			self:UpdateDisplay(frame.auras.debuffs, frame.unitType)
		end
	end
end

