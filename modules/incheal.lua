local IncHeal = {}
local frames, playerHeals, totalHealing = {}, {}, {}
local playerName = UnitName("player")
local HealComm
local OH_WARNING = 1.30
ShadowUF:RegisterModule(IncHeal, "incHeal", ShadowUFLocals["Incoming heals"])

-- RAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAGGGGGGGGGGGGGGGGGGGGGGEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEE
function IncHeal:OnEnable(frame)
	frames[frame] = true
	frame.incHeal = frame.incHeal or ShadowUF.Units:CreateBar(frame)
	frame.incHeal:SetFrameLevel(frame.topFrameLevel - 2)

	frame:RegisterUpdateFunc(self, "UpdateFrame")
	frame:RegisterUnitEvent("UNIT_MAXHEALTH", self, "UpdateFrame")
	frame:RegisterUnitEvent("Unit_HEALTH", self, "UpdateFrame")
	
	self:Setup()
end

function IncHeal:OnDisable(frame)
	frames[frame] = nil

	self:Setup()
	self:UnregisterAll(self)
end

function IncHeal:OnLayoutApplied(frame)
	if( frame.incHeal and frame.healthBar ) then
		frame.incHeal:SetWidth(frame.healthBar:GetWidth() * OH_WARNING)
		frame.incHeal:SetHeight(frame.healthBar:GetHeight())
		frame.incHeal:SetStatusBarTexture(ShadowUF.Layout.mediaPath.statusbar)
		frame.incHeal:SetStatusBarColor(ShadowUF.db.profile.healthColors.inc.r, ShadowUF.db.profile.healthColors.inc.g, ShadowUF.db.profile.healthColors.inc.b, ShadowUF.db.profile.bars.alpha)
		frame.incHeal:SetPoint("TOPLEFT", frame.healthBar, "TOPLEFT", 0, 0)
		frame.incHeal:Hide()
	end
end

-- Check if we need to register callbacks
function IncHeal:Setup()
	local enabled
	for frame in pairs(frames) do
		enabled = true
		break
	end
	
	if( not enabled ) then
		if( HealComm ) then
			HealComm:UnregisterAllCallbacks(IncHeal)
		end
		return
	end
	
	HealComm = HealComm or LibStub("LibHealComm-3.0")
	HealComm.RegisterCallback(self, "HealComm_DirectHealStart", "DirectHealStart")
	HealComm.RegisterCallback(self, "HealComm_DirectHealStop", "DirectHealStop")
	HealComm.RegisterCallback(self, "HealComm_DirectHealDelayed", "DirectHealDelayed")
	HealComm.RegisterCallback(self, "HealComm_HealModifierUpdate", "HealModifierUpdate")
end

local function setBarColor(bar, r, g, b)
	bar:SetStatusBarColor(r, g, b, ShadowUF.db.profile.bars.alpha)
end

local function getName(unit)
	local name, server = UnitName(unit)
	if( server and server ~= "" ) then
		name = string.format("%s-%s", name, server)
	end
	
	return name
end

local function updateHealthBar(frame, target, healed, succeeded)
	healed = math.floor(healed * HealComm:UnitHealModifierGet(target))
	
	if( healed > 0 ) then
		frame.incHeal.total = UnitHealth(frame.unit) + healed
		frame.incHeal:SetMinMaxValues(0, UnitHealthMax(frame.unit) * OH_WARNING)
		frame.incHeal:SetValue(frame.incHeal.total)
		frame.incHeal.nextUpdate = nil
		frame.incHeal:Show()
	elseif( healed == 0 and frame.incHeal.total ) then
		if( succeeded ) then
			frame.incHeal.nextUpdate = true
		else
			frame.incHeal:Hide()
		end
		
		-- If it's an overheal, we won't have anything to do on a next update anyway
		local maxHealth = UnitHealthMax(frame.unit)
		if( maxHealth < frame.incHeal.total ) then
			frame.incHeal:SetValue(maxHealth)
		end
	end
end

function IncHeal:UpdateFrame(frame, event)
	local name = getName(frame.unit)
	if( name ) then
		updateHealthBar(frame, name, totalHealing[name] or 0, event)
	end
end

function IncHeal:UpdateIncoming(healer, amount, succeeded, ...)
	for i=1, select("#", ...) do
		self:UpdateHealing(select(i, ...), amount, succeeded)
	end
end

function IncHeal:UpdateHealing(target, amount, succeeded)
	totalHealing[target] = (totalHealing[target] or 0) + amount
	
	for frame in pairs(frames) do
		if( frame:IsVisible() and frame.unit and getName(frame.unit) == target ) then
			updateHealthBar(frame, target, totalHealing[target], succeeded)
		end
	end
end

-- Handle callbacks from HealComm
function IncHeal:DirectHealStart(event, healerName, amount, endTime, ...)
	self:UpdateIncoming(healerName, amount, nil, ...)
end

function IncHeal:DirectHealStop(event, healerName, amount, succeeded, ...)
	self:UpdateIncoming(healerName, -amount, succeeded, ...)
end

function IncHeal:DirectHealDelayed(event, healerName, amount, endTime, ...)
	self:UpdateIncoming(healerName, 0, nil, ...)
end

function IncHeal:HealModifierUpdate(event, unit, targetName, healMod)
	self:UpdateHealing(targetName, 0)
end



