-- Debug
if( not ShadowUF ) then
	return
end

local L = ShadowUFLocals

--[[
		Layout format
		
		{
			texture
			backdrop = {
				tileSize
				edgeSize
				inset

				backgroundTexture 
				backgroundColor
				
				borderTexture
				borderColor
			},
			portrait = {
				point, anchorTo, relativePoint, x, y
				heightPercent, widthPercent
			},
			healthBar = {
				point, anchorTo, relativePoint, x, y
				heightPercent, widthPercent,
			},
			healthBar = {
				point, anchorTo, relativePoint, x, y
				heightPercent, widthPercent,
			},
			xpBar = {
				point, anchorTo, relativePoint, x, y
				heightPercent, widthPercent,
			},
			castBar = {
				point, anchorTo, relativePoint, x, y
				heightPercent, widthPercent,
			},
			indicators = {
				rested = {point, anchorTo, relativePoint, x, y, height, width},
				pvpFlag = {point, anchorTo, relativePoint, x, y, height, width},
				leader = {point, anchorTo, relativePoint, x, y, height, width},
				masterLoot = {point, anchorTo, relativePoint, x, y, height, width},
				raidTarget = {point, anchorTo, relativePoint, x, y, height, width},
				happiness = {point, anchorTo, relativePoint, x, y, height, width},
			},
		}
	]]

-- NTS: Change this to a serialized table once I release this.
ShadowUF:RegisterLayout("Default", {
	name = "Default",
	author = "Shadowed",
	description = "Default layout provided with sUF.",
	layout = {
		general = {
			barTexture = "Smooth",
			clip = 1,
			barSpacing = -1.25,
			backgroundFade = 0.20,
		},
		font = {
			name = "Myriad Condensed Web",
			size = 11,
			shadowColor = {r = 0, g = 0, b = 0, a = 1.0},
			shadowX = 0.80,
			shadowY = -0.80,
		},
		powerColor = {
			[0] = {r = 0.30, g = 0.50, b = 0.85},
			[1] = {r = 0.90, g = 0.20, b = 0.30},
			[2] = {r = 1.0, g = 0.85, b = 0},
			[3] = {r = 1.0, g = 0.85, b = 0.10},
			[4] = {r = 0, g = 1.0, b = 1.0},
			[5] = {r = 0.50, g = 0.50, b = 0.50},
			[6] = {b = 0.60, g = 0.45, r = 0.35},
		},
		healthColor = {
			tapped = {r = 0.5, g = 0.5, b = 0.5},
			red = {r = 1.0, g = 0.0, b = 0.0},
			green = {r = 0.20, g = 0.90, b = 0.20},
			yellow = {r = 1.0, g = 1.0, b = 0.0},
		},
		xpColor = {
			normal = {r = 0.58, g = 0.0, b = 0.55, a = 1.0},
			rested = {r = 0.0, g = 0.39, b = 0.88, a = 0.60},
		},
		player = {
			width = 200,
			height = 60,
			scale = 1.0,
			applyEffective = true,
			healthBar = {enabled = true},
			manaBar = {enabled = true},
			portrait = {enabled = true},
			text = {
					{name = L["Left text"], widthPercent = 0.60, text = "[raidcolor][name]|r", point = "LEFT", anchorTo = "$healthBar", relativePoint = "LEFT", x = 3, y = 0},
					{name = L["Right text"], widthPercent = 0.40, text = "[curmaxhp]", point = "RIGHT", anchorTo = "$healthBar", relativePoint = "RIGHT", x = -3, y = 0},
					
					{name = L["Left text"], widthPercent = 0.60, text = "[level] [race]", point = "LEFT", anchorTo = "$manaBar", relativePoint = "LEFT", x = 3, y = 0},
					{name = L["Right text"], widthPercent = 0.40, text = "[curmaxpp]", point = "RIGHT", anchorTo = "$manaBar", relativePoint = "RIGHT", x = -3, y = 0},
			},
			indicators = {
				status = {height = 19, width = 19, point = "BOTTOMLEFT", anchorTo = "$parent", relativePoint = "BOTTOMLEFT", x = 0, y = 0},
				pvp = {height = 22, width = 22, point = "TOPRIGHT", anchorTo = "$parent", relativePoint = "TOPRIGHT", x = 10, y = 2},
				leader = {height = 14, width = 14, point = "TOPLEFT", anchorTo = "$parent", relativePoint = "TOPLEFT", x = 3, y = 2},
				masterLoot = {height = 12, width = 12, point = "TOPLEFT", anchorTo = "$parent", relativePoint = "TOPLEFT", x = 15, y = 2},
			--[[
				raidTarget = {point, anchorTo, relativePoint, x, y, height, width},
				happiness = {point, anchorTo, relativePoint, x, y, height, width},
			]]
			},
			point = "TOPLEFT", anchorTo = "UIParent", relativePoint = "TOPLEFT", x = 100, y = -300,
		},
		target = {
			width = 200,
			height = 60,
			scale = 1.0,
			appleEffective = true,
			healthBar = {enabled = true},
			manaBar = {enabled = true},
			portrait = {enabled = true},
			xpBar = {enabled = true},
			text = {
					{name = L["Left text"], widthPercent = 0.60, text = "[raidcolor][name]|r", point = "LEFT", anchorTo = "$healthBar", relativePoint = "LEFT", x = 2, y = 0},
					{name = L["Right text"], widthPercent = 0.40, text = "[curmaxhp]", point = "RIGHT", anchorTo = "$healthBar", relativePoint = "RIGHT", x = -2, y = 0},
					
					{name = L["Left text"], widthPercent = 0.60, text = "[level] [race]", point = "LEFT", anchorTo = "$manaBar", relativePoint = "LEFT", x = 2, y = 0},
					{name = L["Right text"], widthPercent = 0.40, text = "[curmaxpp]", point = "RIGHT", anchorTo = "$manaBar", relativePoint = "RIGHT", x = -2, y = 0},
			},
			indicators = {
				status = {height = 19, width = 19, point = "BOTTOMLEFT", anchorTo = "$parent", relativePoint = "BOTTOMLEFT", x = 0, y = 0},
				pvp = {height = 22, width = 22, point = "TOPRIGHT", anchorTo = "$parent", relativePoint = "TOPRIGHT", x = 10, y = 2},
				leader = {height = 14, width = 14, point = "TOPLEFT", anchorTo = "$parent", relativePoint = "TOPLEFT", x = 3, y = 2},
				masterLoot = {height = 12, width = 12, point = "TOPLEFT", anchorTo = "$parent", relativePoint = "TOPLEFT", x = 15, y = 2},
			},
			point = "TOPLEFT", anchorTo = "UIParent", relativePoint = "TOPLEFT", x = 350, y = -315,
		},
		pet = {
			width = 200,
			height = 60,
			scale = 1.0,
			applyEffective = true,
			healthBar = {enabled = true},
			manaBar = {enabled = true},
			portrait = {enabled = true},
			xpBar = {enabled = true},
			text = {
					{name = L["Left text"], widthPercent = 0.60, text = "[raidcolor][name]|r", point = "LEFT", anchorTo = "$healthBar", relativePoint = "LEFT", x = 3, y = 0},
					{name = L["Right text"], widthPercent = 0.40, text = "[curmaxhp]", point = "RIGHT", anchorTo = "$healthBar", relativePoint = "RIGHT", x = -3, y = 0},
					
					{name = L["Left text"], widthPercent = 0.60, text = "[level] [race]", point = "LEFT", anchorTo = "$manaBar", relativePoint = "LEFT", x = 3, y = 0},
					{name = L["Right text"], widthPercent = 0.40, text = "[curmaxpp]", point = "RIGHT", anchorTo = "$manaBar", relativePoint = "RIGHT", x = -3, y = 0},
			},
			point = "TOPLEFT", anchorTo = "UIParent", relativePoint = "TOPLEFT", x = 100, y = -450,
		},
		focus = {
			width = 200,
			height = 60,
			scale = 1.0,
			appleEffective = true,
			healthBar = {enabled = true},
			manaBar = {enabled = true},
			portrait = {enabled = true},
			text = {
					{name = L["Left text"], widthPercent = 0.60, text = "[raidcolor][name]|r", point = "LEFT", anchorTo = "$healthBar", relativePoint = "LEFT", x = 2, y = 0},
					{name = L["Right text"], widthPercent = 0.40, text = "[curmaxhp]", point = "RIGHT", anchorTo = "$healthBar", relativePoint = "RIGHT", x = -2, y = 0},
					
					{name = L["Left text"], widthPercent = 0.60, text = "[level] [race]", point = "LEFT", anchorTo = "$manaBar", relativePoint = "LEFT", x = 2, y = 0},
					{name = L["Right text"], widthPercent = 0.40, text = "[curmaxpp]", point = "RIGHT", anchorTo = "$manaBar", relativePoint = "RIGHT", x = -2, y = 0},
			},
			point = "TOPLEFT", anchorTo = "UIParent", relativePoint = "TOPLEFT", x = 350, y = -225,
		},
		targettarget = {
			width = 200,
			height = 60,
			scale = 1.0,
			appleEffective = true,
			healthBar = {enabled = true},
			manaBar = {enabled = true},
			portrait = {enabled = true},
			text = {
					{name = L["Left text"], widthPercent = 0.60, text = "[raidcolor][name]|r", point = "LEFT", anchorTo = "$healthBar", relativePoint = "LEFT", x = 2, y = 0},
					{name = L["Right text"], widthPercent = 0.40, text = "[curmaxhp]", point = "RIGHT", anchorTo = "$healthBar", relativePoint = "RIGHT", x = -2, y = 0},
					
					{name = L["Left text"], widthPercent = 0.60, text = "[level] [race]", point = "LEFT", anchorTo = "$manaBar", relativePoint = "LEFT", x = 2, y = 0},
					{name = L["Right text"], widthPercent = 0.40, text = "[curmaxpp]", point = "RIGHT", anchorTo = "$manaBar", relativePoint = "RIGHT", x = -2, y = 0},
			},
			point = "TOPLEFT", anchorTo = "UIParent", relativePoint = "TOPLEFT", x = 350, y = -500,
		},
		backdrop = {
			tileSize = 1,
			edgeSize = 0,
			inset = 3,
			backgroundTexture = "Interface\\\\ChatFrame\\\\ChatFrameBackground",
			backgroundColor = {r = 0, g = 0, b = 0, a = 0.80},
			borderTexture = "",
			borderColor = {r = 0.30, g = 0.30, b = 0.50, a = 1},
		},
		portrait = {
			alignment = "LEFT",
			width = 0.22,
		},
		healthBar = {
			background = true,
			heightWeight = 1.20,
			width = 1.0,
			order = 0,
		},
		manaBar = {
			background = true,
			heightWeight = 1.0,
			width = 1.0,
			order = 1,
		},
		xpBar = {
			background = true,
			heightWeight = 0.25,
			width = 1.0,
			order = 2,
		},
	},
})










