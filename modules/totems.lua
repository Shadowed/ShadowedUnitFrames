local Totems = ShadowUF:NewModule("Totems")
local totemColors = {{r = 1, g = 0, b = 0.4}, {r = 0, g = 1, b = 0.4}, {r = 0, g = 0.4, b = 1}, {r = 0.80, g = 0.80, b = 0.80}}
ShadowUF:RegisterModule(Totems, "totemBar", ShadowUFLocals["Totem indicators"], "bar")

function Totems:UnitEnabled(frame, unit)
	if( not frame.visibility.totemBar or unit ~= "player" ) then
		return
	end
			
	if( not frame.totemBar ) then
		frame.totemBar = ShadowUF.Units:CreateBar(frame)
		frame.totemBar.background:SetVertexColor(0, 0, 0, 0)
		frame.totemBar:SetMinMaxValues(0, 1)
		frame.totemBar:SetValue(0)
		frame.totemBar.totems = {}
		
		for i=1, 4 do
			local totem = ShadowUF.Units:CreateBar(frame.totemBar)
			totem:SetFrameLevel(frame.totemBar:GetFrameLevel() - 1)
			totem.id = i
			
			if( i > 1 ) then
				totem:SetPoint("TOPLEFT", frame.totemBar.totems[i - 1], "TOPRIGHT", 1, 0)
			else
				totem:SetPoint("TOPLEFT", frame.totemBar, "TOPLEFT", 0, 0)
			end
			
			frame.totemBar.totems[i] = totem
		end
	end
	
	frame:RegisterNormalEvent("PLAYER_TOTEM_UPDATE", self.Update)
	frame:RegisterUpdateFunc(self.Update)
end

function Totems:UnitDisabled(frame, unit)
	frame:UnregisterAll(self.Update)
end

function Totems:LayoutApplied(frame)
	if( frame.totemBar ) then
		local barWidth = (frame.totemBar:GetWidth() - 5 ) / 4
		
		for id, totem in pairs(frame.totemBar.totems) do
			totem:SetStatusBarTexture(ShadowUF.Layout.mediaPath.statusbar)
			totem:SetStatusBarColor(totemColors[id].r, totemColors[id].g, totemColors[id].b, ShadowUF.db.profile.bars.alpha)
			totem:SetHeight(frame.totemBar:GetHeight())
			totem:SetWidth(barWidth)
		end
		
		self.Update(frame, frame.unit)
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

function Totems.Update(self, unit)
	for id, indicator in pairs(self.totemBar.totems) do
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