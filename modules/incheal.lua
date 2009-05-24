local IncHeal = ShadowUF:NewModule("IncHeal")
local frames, playerHeals = {}, {}
local playerName = UnitName("player")
local HealComm
local OH_WARNING = 1.30
ShadowUF:RegisterModule(IncHeal, "incHeal", ShadowUFLocals["Incoming heals"])

-- RAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAGGGGGGGGGGGGGGGGGGGGGGEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEE
function IncHeal:UnitEnabled(frame)
	if( not frame.visibility.incHeal or frame.unitType == "targettarget" or frame.unitType == "targettargettarget" or frame.unitType == "focustarget" ) then
		frames[frame] = nil
		return
	end
	
	frames[frame] = true
	frame.incHeal = frame.incHeal or ShadowUF.Units:CreateBar(frame)
	frame.incHeal:SetFrameLevel(frame.topFrameLevel - 2)

	frame:RegisterUpdateFunc(self, "UpdateFrame")

	self:Setup()
end

function IncHeal:UnitDisabled(frame)
	frames[frame] = nil
	self:Setup()
end

function IncHeal:LayoutApplied(frame)
	if( not frame.incHeal or not frame.healthBar ) then
		return
	end
	
	frame.incHeal:SetWidth(frame.healthBar:GetWidth() * OH_WARNING)
	frame.incHeal:SetHeight(frame.healthBar:GetHeight())
	frame.incHeal:SetStatusBarTexture(ShadowUF.Layout.mediaPath.statusbar)
	frame.incHeal:SetStatusBarColor(ShadowUF.db.profile.healthColors.inc.r, ShadowUF.db.profile.healthColors.inc.g, ShadowUF.db.profile.healthColors.inc.b, ShadowUF.db.profile.bars.alpha)
	frame.incHeal:SetPoint("TOPLEFT", frame.healthBar, "TOPLEFT", 0, 0)
	frame.incHeal:Hide()
end

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
	if( server ) then
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
		
		local maxHealth = UnitHealthMax(frame.unit)
		if( maxHealth < frame.incHeal.total ) then
			frame.incHeal:SetValue(maxHealth)
		end
	end
end

function IncHeal:UpdateFrame(frame)
	local name = getName(frame.unit)
	if( name and frame.incHeal ) then
		local amount = HealComm:UnitIncomingHealGet(frame.unit, GetTime()) or 0
		if( playerHeals[name] and ShadowUF.db.profile.units[frame.unitType].incHeal.showSelf ) then
			amount = amount + playerHeals[name]
		end
		
		updateHealthBar(frame, name, amount, true)
	end
end

function IncHeal:UpdateIncoming(healer, amount, succeeded, ...)
	for i=1, select("#", ...) do
		local target = select(i, ...)
		if( target == playerName ) then
			playerHeals[target] = amount
		end
		
		self:UpdateHealing(target, succeeded)
	end
end

function IncHeal:UpdateHealing(target, succeeded)
	local amount = HealComm:UnitIncomingHealGet(target, GetTime() + 10) or 0
	for frame in pairs(frames) do
		if( frame:IsVisible() and frame.unit and getName(frame.unit) == target ) then
			local healed = amount
			if( playerHeals[target] and ShadowUF.db.profile.units[frame.unitType].incHeal.showSelf ) then
				healed = healed + playerHeals[target]
			end
			
			updateHealthBar(frame, target, healed, succeeded)
		end
	end
end

-- Handle callbacks from HealComm
function IncHeal:DirectHealStart(event, healerName, amount, endTime, ...)
	self:UpdateIncoming(healerName, amount, nil, ...)
end

function IncHeal:DirectHealStop(event, healerName, amount, succeeded, ...)
	self:UpdateIncoming(healerName, 0, succeeded, ...)
end

function IncHeal:DirectHealDelayed(event, healerName, amount, endTime, ...)
	self:UpdateIncoming(healerName, amount, nil, ...)
end

function IncHeal:HealModifierUpdate(event, unit, targetName, healMod)
	self:UpdateHealing(targetName)
end



