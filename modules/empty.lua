local Empty = {}
ShadowUF:RegisterModule(Empty, "emptyBar", ShadowUFLocals["Empty bar"], true)

function Empty:OnEnable(frame)
	frame.emptyBar = frame.emptyBar or ShadowUF.Units:CreateBar(frame)
	frame.emptyBar:SetMinMaxValues(0, 1)
	frame.emptyBar:SetValue(0)
end

function Empty:OnDisable(frame)
	frame:UnregisterAll(self)
end

function Empty:OnLayoutApplied(frame)
	if( frame.visibility.emptyBar ) then
		local color = frame.emptyBar.background.overrideColor
		if( not color ) then
			frame.emptyBar.background:SetVertexColor(0, 0, 0, ShadowUF.db.profile.bars.alpha)
		else
			frame.emptyBar.background:SetVertexColor(color.r, color.g, color.b, ShadowUF.db.profile.bars.alpha)
		end
	end
end
