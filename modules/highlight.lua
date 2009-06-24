local Highlight = {}
ShadowUF:RegisterModule(Highlight, "highlight", ShadowUFLocals["Highlight"])

-- Might seem odd to hook my code in the core manually, but HookScript is ~40% slower due to secure stuff
local function OnEnter(frame, ...)
	if( ShadowUF.db.profile.units[frame.unitType].highlight.mouseover ) then
		frame.highlight.hasMouseover = true
		Highlight:Update(frame)
	end
		
	frame.highlight.OnEnter(frame, ...)
end

local function OnLeave(frame, ...)
	if( ShadowUF.db.profile.units[frame.unitType].highlight.mouseover ) then
		frame.highlight.hasMouseover = nil
		Highlight:Update(frame)
	end
		
	frame.highlight.OnLeave(frame, ...)
end

function Highlight:OnEnable(frame)
	ShadowUF.modules.auras:CheckCures()
	
	if( not frame.highlight ) then
		frame.highlight = frame.highFrame:CreateTexture(nil, "ARTWORK")
		frame.highlight:SetTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
		frame.highlight:SetBlendMode("ADD")
		frame.highlight:SetPoint("TOPLEFT", frame, 1, -3)
		frame.highlight:SetPoint("BOTTOMRIGHT", frame, -1, 3)
		frame.highlight:Hide()
	end
	
	if( ShadowUF.db.profile.units[frame.unitType].highlight.aggro ) then
		frame:RegisterUnitEvent("UNIT_THREAT_SITUATION_UPDATE", self, "UpdateThreat")
		frame:RegisterUpdateFunc(self, "UpdateThreat")
	end
	
	if( ShadowUF.db.profile.units[frame.unitType].highlight.attention and frame.unitType ~= "target" and frame.unitType ~= "focus" ) then
		frame:RegisterNormalEvent("PLAYER_TARGET_CHANGED", self, "UpdateAttention")
		frame:RegisterNormalEvent("PLAYER_FOCUS_CHANGED", self, "UpdateAttention")
		frame:RegisterUpdateFunc(self, "UpdateAttention")
	end

	if( ShadowUF.db.profile.units[frame.unitType].highlight.debuff ) then
		frame:RegisterNormalEvent("UNIT_AURA", self, "UpdateAura")
		frame:RegisterUpdateFunc(self, "UpdateAura")
	end
	
	if( ShadowUF.db.profile.units[frame.unitType].highlight.mouseover and not frame.highlight.OnEnter ) then
		frame.highlight.OnEnter = frame:GetScript("OnEnter")
		frame:SetScript("OnEnter", OnEnter)
		frame.highlight.OnLeave = frame:GetScript("OnLeave")
		frame:SetScript("OnLeave", OnLeave)
	end
end

function Highlight:OnLayoutApplied(frame)
	if( frame.visibility.highlight ) then
		self:OnDisable(frame)
		self:OnEnable(frame)
	end
end

local color
local goldColor = {r = 0.75, g = 0.75, b = 0.35}
local mouseColor = {r = 0.75, g = 0.75, b = 0.50}
function Highlight:Update(frame)
	if( frame.highlight.hasDebuff ) then
		color = DebuffTypeColor[frame.highlight.hasDebuff]
	elseif( frame.highlight.hasThreat ) then
		color = ShadowUF.db.profile.healthColors.red
	elseif( frame.highlight.hasAttention ) then
		color = goldColor
	elseif( frame.highlight.hasMouseover ) then
		color = mouseColor
	else
		color = nil
	end
		
	if( color ) then
		frame.highlight:SetVertexColor(color.r, color.g, color.b, 0.80)
		frame.highlight:Show()
	else
		frame.highlight:Hide()
	end
end

function Highlight:UpdateThreat(frame)
	frame.highlight.hasThreat = UnitThreatSituation(frame.unit) == 3 or nil
	self:Update(frame)
end

function Highlight:UpdateAttention(frame)
	frame.highlight.hasAttention = UnitIsUnit(frame.unit, "target") or UnitIsUnit(frame.unit, "focus") or nil
	self:Update(frame)
end

function Highlight:UpdateAura(frame)
	frame.highlight.hasDebuff = nil
	
	local id = 1
	while( true ) do
		local name, _, _, _, auraType = UnitDebuff(frame.unit, id)
		if( not name ) then break end
		
		if( auraType and ShadowUF.modules.auras.canRemove[auraType] ) then
			frame.highlight.hasDebuff = auraType
			break
		end
		
		id = id + 1
	end
	
	self:Update(frame)
end

function Highlight:OnDisable(frame)
	frame:UnregisterAll(self)
	
	frame.highlight.hasDebuff = nil
	frame.highlight.hasThreat = nil
	frame.highlight.hasAttention = nil
	frame.highlight:Hide()
end
