local Auras = ShadowUF:NewModule("Auras")
ShadowUF:RegisterModule(Auras, "auras", ShadowUFLocals["Auras"])

local function updateTooltip(self)
	if( GameTooltip:IsOwned(self) ) then
		GameTooltip:SetUnitAura(self.unit, self.aura.buffID, self.filter)
	end
end

local function showTooltip(self)
	GameTooltip:SetOwner(self, "ANCHOR_BOTTOMLEFT")
	GameTooltip:SetUnitAura(self.unit, self.aura.buffID, self.filter)

	self:SetScript("OnUpdate", updateTooltip)
end

local function hideTooltip(self)
	self:SetScript("OnUpdate", nil)
	GameTooltip:Hide()
end

local function cancelBuff(self)
	CancelUnitBuff(self.unit, self.aura.buffID, self.filter)
end

function Auras:UnitEnabled(frame, unit)
	if( not frame.unitConfig.auras ) then
		return
	end
	
	frame:RegisterUnitEvent("UNIT_AURA", self.Update)
	frame:RegisterUpdateFunc(self.Update)
	
	self.CreateIcons(frame)
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

function Auras.CreateIcons(self)
	self.auras = self.auras or {}
	for key, config in pairs(self.unitConfig.auras) do
			self.auras[key] = self.auras[key] or CreateFrame("Frame", nil, self)
			local aura = self.auras[key]
			aura.buttons = aura.buttons or {}
			aura.maxIcons = config.inColumn * config.rows
			aura.parent = self
			
			for i=#(aura.buttons)+1, aura.maxIcons do
				aura.buttons[i] = CreateFrame("Button", nil,aura)
				local button = aura.buttons[i]
				button.aura = {}
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
			
			for _, button in pairs(aura.buttons) do
				button:Hide()
			end
			
			Auras.UpdateFilter(aura, config)
	end
end

function Auras:LayoutUpdated(self, unit)
	local auraConfig = ShadowUF.db.profile.layout[self.unitType].auras
	if( auraConfig ) then
		for key, config in pairs(auraConfig) do
			Auras.UpdateFilter(self.auras[key], config)
		end
	end
end

function Auras.UpdateDisplay(self)
	for i=self.totalAuras + 1, #(self.buttons) do
		self.buttons[i].unit = nil
		self.buttons[i]:Hide()
	end
	
	for id, button in pairs(self.buttons) do
		if( button.unit ) then
			if( button.type == "debuff" ) then
				local color = button.aura.debuffType and DebuffTypeColor[button.aura.debuffType] or DebuffTypeColor.none
				button.border:SetVertexColor(color.r, color.g, color.b)
			else
				button.border:SetVertexColor(0.60, 0.60, 0.60, 1.0)
			end
			
			if( button.aura.duration > 0 and button.aura.endTime > 0 ) then
				button.cooldown:SetCooldown(button.aura.endTime - button.aura.duration, button.aura.duration)
				button.cooldown:Show()
			else
				button.cooldown:Hide()
			end
		
			button.icon:SetTexture(button.aura.texture)
			button.stack:SetText(button.aura.count > 0 and button.aura.count or "")
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
			if( self.totalAuras >= self.maxIcons ) then
				self.totalAuras = self.maxIcons
				return 0
			end
			
			local button = self.buttons[self.totalAuras]
			button.aura.name = name
			button.aura.rank = rank
			button.aura.texture = texture
			button.aura.count = count
			button.aura.debuffType = debuffType
			button.aura.duration = duration
			button.aura.endTime = endTime
			button.aura.isStealable = isStealable
			button.aura.caster = caster
			button.aura.isPlayer = caster == "player"
			button.aura.buffID = index
			button.filter = filter
			button.type = type
			button.unit = unit
			
			index = index + 1
	end
end

function Auras.Update(self, unit)
	if( self.aurasShared ) then
		self.auras.buffs.totalAuras = 0
		
		Auras.Scan(self.auras.buffs, self.auras.buffs.filter, "buff", unit)
		Auras.Scan(self.auras.buffs, self.auras.debuffs.filter, "debuff", unit)
		
		Auras.UpdateDisplay(self.auras.buffs)
	else
		self.auras.buffs.totalAuras = 0
		Auras.Scan(self.auras.buffs, self.auras.buffs.filter, "buff", unit)
		Auras.UpdateDisplay(self.auras.buffs)

		self.auras.debuffs.totalAuras = 0
		Auras.Scan(self.auras.debuffs, self.auras.debuffs.filter, "debuff", unit)
		Auras.UpdateDisplay(self.auras.debuffs)
	end
end

