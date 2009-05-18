local Auras = ShadowUF:NewModule("Auras")
local buttonCache ={}
ShadowUF:RegisterModule(Auras, "auras", ShadowUFLocals["Auras"])

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

function Auras:UnitEnabled(frame, unit)
	if( not frame.visibility.auras or not ShadowUF.db.profile.units[frame.unitType].auras ) then
		return
	end
	
	self.CreateIcons(frame)

	frame:RegisterUnitEvent("UNIT_AURA", self.Update)
	frame:RegisterUpdateFunc(self.Update)
end

function Auras:UnitDisabled(frame, unit)
	frame:UnregisterAll(self.Update)
end

local filterTable = {}
function Auras.UpdateFilter(self, config)
	for i=#(filterTable), 1, -1 do table.remove(filterTable, i) end
	table.insert(filterTable, config.HELPFUL and "HELPFUL" or nil)
	table.insert(filterTable, config.HARMFUL and "HARMFUL" or nil)
	table.insert(filterTable, config.PLAYER and "PLAYER" or nil)
	table.insert(filterTable, config.RAID and "RAID" or nil)
	table.insert(filterTable, config.CANCELABLE and "CANCELABLE" or nil)
	table.insert(filterTable, config.NOT_CANCELABLE and "NOT_CANCELABLE" or nil)
	
	self.filter = table.concat(filterTable, "|") or ""
end

local function createAnchor(self, key, config)
	self.auras[key] = self.auras[key] or CreateFrame("Frame", nil, self)

	local aura = self.auras[key]
	aura.buttons = aura.buttons or {}
	aura.maxAuras = config.inColumn * config.rows
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
	
	Auras.UpdateFilter(aura, ShadowUF.db.profile.units[self.unitType].auras[key])
end

function Auras:PreLayoutApplied(self)
	Auras.CreateIcons(self)

	self.auras.anchor = "buffs"
	if( not ShadowUF.db.profile.units[self.unitType].auras.buffs.enabled ) then
		self.auras.anchor = "debuffs"
	end

	Auras.Update(self, self.unit)
end

function Auras.CreateIcons(self)
	self.auras = self.auras or {}
	createAnchor(self, "buffs", ShadowUF.db.profile.units[self.unitType].auras.buffs)
	createAnchor(self, "debuffs", ShadowUF.db.profile.units[self.unitType].auras.debuffs)
end

function Auras:LayoutApplied(self)
	if( self.auras and ShadowUF.db.profile.units[self.unitType].auras ) then
		Auras.UpdateFilter(self.auras.buffs, ShadowUF.db.profile.units[self.unitType].auras.buffs)
		Auras.UpdateFilter(self.auras.debuffs, ShadowUF.db.profile.units[self.unitType].auras.debuffs)
		
		Auras.Update(self, self.unit)
	end
end

function Auras.UpdateDisplay(self, unitType)
	for _, button in pairs(self.buttons) do
		button:Hide()
	end

	if( self.totalAuras == 0 ) then
		return
	end
		
	for i=1, self.totalAuras do
		local button = self.buttons[i]
		if( button.auraDuration and button.auraEnd ) then
			local config = ShadowUF.db.profile.units[unitType].auras[button.type]
			if( button.type == "debuffs" ) then
				local color = button.auraType and DebuffTypeColor[button.auraType] or DebuffTypeColor.none
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

function Auras.Scan(self, filter, type, unit)
	local index = 1
	while( true ) do
		local name, rank, texture, count, debuffType, duration, endTime, caster, isStealable = UnitAura(unit, index, filter)
		if( not name ) then break end
		
		self.totalAuras = self.totalAuras + 1
		if( self.totalAuras >= self.maxAuras ) then
			self.totalAuras = self.maxAuras
			return 0
		end
		
		local button = self.buttons[self.totalAuras]
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
		
		index = index + 1
	end
end

function Auras.Update(self, unit)
	local config = ShadowUF.db.profile.units[self.unitType].auras
	if( config.buffs.anchorPoint == config.debuffs.anchorPoint ) then
		self.auras[self.auras.anchor].totalAuras = 0
				
		if( config.buffs.prioritize ) then
			if( config.buffs.enabled ) then
				Auras.Scan(self.auras[self.auras.anchor], self.auras.buffs.filter, "buffs", unit)
			end
			if( config.debuffs.enabled ) then
				Auras.Scan(self.auras[self.auras.anchor], self.auras.debuffs.filter, "debuffs", unit)
			end
		else
			if( config.debuffs.enabled ) then
				Auras.Scan(self.auras[self.auras.anchor], self.auras.debuffs.filter, "debuffs", unit)
			end
			if( config.buffs.enabled ) then
				Auras.Scan(self.auras[self.auras.anchor], self.auras.buffs.filter, "buffs", unit)
			end
		end
		
		Auras.UpdateDisplay(self.auras[self.auras.anchor], self.unitType)
	else
		if( config.buffs.enabled ) then
			self.auras.buffs.totalAuras = 0
			Auras.Scan(self.auras.buffs, self.auras.buffs.filter, "buffs", unit)
			Auras.UpdateDisplay(self.auras.buffs, self.unitType)
		end

		if( config.debuffs.enabled ) then
			self.auras.debuffs.totalAuras = 0
			Auras.Scan(self.auras.debuffs, self.auras.debuffs.filter, "debuffs", unit)
			Auras.UpdateDisplay(self.auras.debuffs, self.unitType)
		end
	end
end

