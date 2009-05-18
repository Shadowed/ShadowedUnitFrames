local Range = ShadowUF:NewModule("Range")
ShadowUF:RegisterModule(Range, "range", ShadowUFLocals["Range indicator"])

local function checkRange(self, elapsed)
	self.timeElapsed = self.timeElapsed + elapsed
	if( self.timeElapsed <= 0.50 ) then
		return
	end
	
	self.timeElapsed = 0
	self.parent:SetAlpha(UnitInRange("player", self.parent.unit) and ShadowUF.db.profile.units[self.parent.unitType].range.inAlpha or ShadowUF.db.profile.units[self.parent.unitType].range.oorAlpha)
end

function Range:UnitEnabled(frame, unit)
	if( not frame.visibility.range or unit == "player" ) then
		return
	elseif( unit ~= "raid" and unit ~= "party" and unit ~= "partypet" and unit ~= "pet" ) then
		return
	end
		
	if( not frame.range ) then
		frame.range = CreateFrame("Frame", nil, frame)
		frame.range:SetScript("OnUpdate", checkRange)
		frame.range.timeElapsed = 0
		frame.range.parent = frame
	end

	frame.range:Show()
end

function Range:UnitDisabled(frame, unit)
	if( frame.range ) then
		frame.range:Hide()
	end
end

