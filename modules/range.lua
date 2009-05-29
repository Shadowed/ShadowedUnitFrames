local Range = {}
ShadowUF:RegisterModule(Range, "range", ShadowUFLocals["Range indicator"])

local function checkRange(self, elapsed)
	self.timeElapsed = self.timeElapsed + elapsed
	if( self.timeElapsed <= 0.50 ) then
		return
	end
	
	self.timeElapsed = 0
	self.parent:SetAlpha(UnitInRange(self.parent.unit, "player") and ShadowUF.db.profile.units[self.parent.unitType].range.inAlpha or ShadowUF.db.profile.units[self.parent.unitType].range.oorAlpha)
end

function Range:OnEnable(frame)
	if( not frame.range ) then
		frame.range = CreateFrame("Frame", nil, frame)
		frame.range:SetScript("OnUpdate", checkRange)
		frame.range.timeElapsed = 0
		frame.range.parent = frame
	end

	frame.range:Show()
end

function Range:OnDisable(frame)
	if( frame.range ) then
		frame.range:Hide()
		frame:SetAlpha(1.0)
	end
end

