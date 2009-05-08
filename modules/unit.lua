local Unit = ShadowUF:NewModule("Unit", "AceEvent-3.0")
local frames = {}

function Unit:InitializeFrame(config, unit)
	local mainFrame = CreateFrame("Frame", "SUFUnit" .. unit, UIParent, "SecureUnitButtonTemplate")
	mainFrame.barFrame = CreateFrame("Frame", "SUFUnit" .. unit .. "BarFrame", mainFrame)
	mainFrame.unit = unit
	
	-- Let all the modules create what they need
	self:SendMessage("SUF_CREATED_UNIT", mainFrame)
	
	ShadowUF.modules.Layout:Apply(mainFrame, unit)
	
	frames[unit] = mainframe
end

function Unit:UninitializeFrame(unit)

end


