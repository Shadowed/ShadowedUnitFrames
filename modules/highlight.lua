local Highlight = {}
ShadowUF:RegisterModule(Highlight, "highlight", ShadowUFLocals["Highlight"], true)

function Highlight:OnEnable(frame)
	--frame:RegisterUnitEvent("UNIT_THREAT_SITUATION_UPDATE", self, "UpdateThreat")
	--frame:RegisterUpdateFunc(self, "Update")
end

function Highlight:OnDisable(frame)
	frame:UnregisterAll(self)
end
