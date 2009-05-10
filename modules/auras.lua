local Auras = ShadowUF:NewModule("Auras")

function Auras:OnInitialize()
	ShadowUF:RegisterModule(self)
end

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

function Auras:UnitCreated(frame, unit)
	-- DEBUG DEBUG DEBUG!
	if( not ShadowUF.db.profile.units[frame.configUnit].auras ) then return end
	
	frame:RegisterUnitEvent("UNIT_AURA", self.Update)
	frame:RegisterUpdateFunc(self.Update)
	
	self.Create(frame, ShadowUF.db.profile.units[frame.configUnit].auras)
end

function Auras.UpdateFilter(self, filter)
	self.filter = nil
	for key, enabled in pairs(filter) do
		if( enabled ) then
			if( self.filter ) then
				self.filter = self.filter .. "|" .. key
			else
				self.filter = key
			end
		end
	end
	
	self.filter = self.filter or self.defaultFilter
end

function Auras.Create(self)
	self.auras = self.auras or {}
	for key, config in pairs(ShadowUF.db.profile.units[self.unit].auras) do
			self.auras[key] = self.auras[key] or CreateFrame("Frame", nil, self)
			local aura = self.auras[key]
			aura.buttons = aura.buttons or {}
			aura.maxIcons = config.inColumn * config.perRow
			aura.parent = self
			aura.defaultFilter = key
			
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
			
			Auras.UpdateFilter(aura, config.filters)
	end
end

function Auras:LayoutApplied(self, unit)
	local auraConfig = ShadowUF.db.profile.units[unit].auras
	-- DEBUG
	if( not auraConfig ) then return end
	
	for key, config in pairs(auraConfig) do
			Auras.UpdateFilter(self.auras[key], config.filters)
			Auras.Position(self.auras[key], config)
	end
	
	self.aurasShared = auraConfig.HELPFUL.location == auraConfig.HARMFUL.location
end

function Auras.Position(self, config)
	for id, button in pairs(self.buttons) do
		button:SetHeight(config.size)
		button:SetWidth(config.size)
		button.border:SetHeight(config.size + 1)
		button.border:SetWidth(config.size + 1)
		button:ClearAllPoints()
		
		-- If's ahoy
		if( id > 1 ) then
			if( config.position == "BOTTOM" or config.position == "TOP" or config.position == "INSIDE" ) then
				if( id % config.inColumn == 1 ) then
					if( config.position == "TOP" ) then
						button:SetPoint("BOTTOM", self.buttons[id - config.inColumn], "TOP", 0, 3)
					else
						button:SetPoint("TOP", self.buttons[id - config.inColumn], "BOTTOM", 0, -3)
					end
				elseif( config.position == "INSIDE" ) then
					button:SetPoint("RIGHT", self.buttons[id - 1], "LEFT", -3, 0)
				else
					button:SetPoint("LEFT", self.buttons[id - 1], "RIGHT", 3, 0)
				end
			elseif( config.perRow == 1 or id % config.perRow == 1 ) then
				if( config.position == "RIGHT" ) then
						button:SetPoint("LEFT", self.buttons[id - config.perRow], "RIGHT", 2, 0)
				else
					button:SetPoint("RIGHT", self.buttons[id - config.perRow], "LEFT", -2, 0)
				end
			else
				button:SetPoint("TOP", self.buttons[id - 1], "BOTTOM", 0, -3)
			end
		elseif( config.position == "INSIDE" ) then
			button:SetPoint("TOPRIGHT", self.parent.healthBar, "TOPRIGHT", -ShadowUF.db.profile.layout.general.clip, -ShadowUF.db.profile.layout.general.clip)
		elseif( config.position == "BOTTOM" ) then
			button:SetPoint("BOTTOMLEFT", self.parent, "BOTTOMLEFT", ShadowUF.db.profile.layout.backdrop.inset, -(config.size + 2))
		elseif( config.position == "TOP" ) then
			button:SetPoint("TOPLEFT", self.parent, "TOPLEFT", ShadowUF.db.profile.layout.backdrop.inset, (config.size + 2))
		elseif( config.position == "LEFT" ) then
			button:SetPoint("TOPLEFT", self.parent, "TOPLEFT", -config.size, ShadowUF.db.profile.layout.backdrop.inset + ShadowUF.db.profile.layout.general.clip)
		elseif( config.position == "RIGHT" ) then
			button:SetPoint("TOPRIGHT", self.parent, "TOPRIGHT", config.size, (ShadowUF.db.profile.layout.backdrop.inset + ShadowUF.db.profile.layout.general.clip))
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
		self.auras.HELPFUL.totalAuras = 0
		
		Auras.Scan(self.auras.HELPFUL, self.auras.HELPFUL.filter, "buff", unit)
		Auras.Scan(self.auras.HELPFUL, self.auras.HARMFUL.filter, "debuff", unit)
		
		Auras.UpdateDisplay(self.auras.HELPFUL)
	else
		self.auras.HELPFUL.totalAuras = 0
		Auras.Scan(self.auras.HELPFUL, self.auras.HELPFUL.filter, "buff", unit)
		Auras.UpdateDisplay(self.auras.HELPFUL)

		self.auras.HARMFUL.totalAuras = 0
		Auras.Scan(self.auras.HARMFUL, self.auras.HARMFUL.filter, "buff", unit)
		Auras.UpdateDisplay(self.auras.HARMFUL)
	end
end

