local Totems = {}
local totemColors = {{r = 1, g = 0, b = 0.4}, {r = 0, g = 1, b = 0.4}, {r = 0, g = 0.4, b = 1}, {r = 0.90, g = 0.90, b = 0.90}}
ShadowUF:RegisterModule(Totems, "totemBar", ShadowUFLocals["Totem bar"], true)

function Totems:OnEnable(frame)
	if( select(2, UnitClass("player")) ~= "SHAMAN" ) then return end
			
	if( not frame.totemBar ) then
		frame.totemBar = CreateFrame("Frame", nil, frame)
		frame.totemBar:SetFrameLevel(frame.topFrameLevel)
		frame.totemBar.totems = {}
		
		for id=1, 4 do
			local totem = CreateFrame("StatusBar", frame.totemBar)
			totem:SetFrameLevel(frame.totemBar:GetFrameLevel() - 1)
			totem.id = id
			
			if( id > 1 ) then
				totem:SetPoint("TOPLEFT", frame.totemBar.totems[id - 1], "TOPRIGHT", 1, 0)
			else
				totem:SetPoint("TOPLEFT", frame.totemBar, "TOPLEFT", 0, 0)
			end
			
			frame.totemBar.totems[id] = totem
		end
	end
	
	frame:RegisterNormalEvent("PLAYER_TOTEM_UPDATE", self, "Update")
	frame:RegisterUpdateFunc(self, "Update")
end

function Totems:OnDisable(frame)
	frame:UnregisterAll(self)
end

function Totems:OnLayoutApplied(frame)
	if( frame.totemBar ) then
		local barWidth = (frame.totemBar:GetWidth() - 3 ) / 4
		
		for id, totem in pairs(frame.totemBar.totems) do
			totem:SetStatusBarTexture(ShadowUF.Layout.mediaPath.statusbar)
			totem:SetStatusBarColor(totemColors[id].r, totemColors[id].g, totemColors[id].b, ShadowUF.db.profile.bars.alpha)
			totem:SetHeight(frame.totemBar:GetHeight())
			totem:SetWidth(barWidth)
		end
		
		self:Update(frame)
	end
end

local function totemMonitor(self, elapsed)
	local time = GetTime()
	self:SetValue(self.endTime - time)
	
	if( time >= self.endTime ) then
		self:SetValue(0)
		self:SetScript("OnUpdate", nil)
	end
end

function Totems:Update(frame)
	for id, indicator in pairs(frame.totemBar.totems) do
		local have, name, start, duration = GetTotemInfo(id)
		if( have ) then
			indicator.have = true
			indicator.endTime = start + duration
			indicator:SetMinMaxValues(0, duration)
			indicator:SetValue(indicator.endTime - GetTime())
			indicator:SetScript("OnUpdate", totemMonitor)
			indicator:SetAlpha(1.0)
			
		elseif( indicator.have ) then
			indicator.have = nil
			indicator:SetMinMaxValues(0, 1)
			indicator:SetValue(1)
			indicator:SetAlpha(0.50)
		end
	end
end