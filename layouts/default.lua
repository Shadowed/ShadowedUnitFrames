local L = ShadowUFLocals

-- NTS: Change this to a serialized table once I release this.
ShadowUF:RegisterLayout("Default", {
	name = "Default",
	author = "Shadowed",
	description = "Default layout provided with sUF.",
	layout = {
		bars = {
			texture = "Aluminium",
			spacing = -1.25,
			alpha = 1.0,
			backgroundAlpha = 0.20,
		},
		backdrop = {
			tileSize = 1,
			edgeSize = 5,
			clip = 1,
			inset = 3,
			backgroundTexture = "Chat Frame",
			backgroundColor = {r = 0, g = 0, b = 0, a = 0.80},
			borderTexture = "None",
			borderColor = {r = 0.30, g = 0.30, b = 0.50, a = 1},
		},
		font = {
			name = "Myriad Condensed Web",
			size = 11,
			shadowColor = {r = 0, g = 0, b = 0, a = 1.0},
			shadowX = 0.80,
			shadowY = -0.80,
		},
		powerColor = {
			[0] = {r = 0.30, g = 0.50, b = 0.85}, -- Mana
			[1] = {r = 0.90, g = 0.20, b = 0.30}, -- Rage
			[2] = {r = 1.0, g = 0.85, b = 0}, -- Focus (Hunter pets)
			[3] = {r = 1.0, g = 0.85, b = 0.10}, -- Energy
			[4] = {r = 0, g = 1.0, b = 1.0}, -- Happiness
			[5] = {r = 0.50, g = 0.50, b = 0.50}, -- Runes
			[6] = {b = 0.60, g = 0.45, r = 0.35}, -- Runic Power
		},
		healthColor = {
			tapped = {r = 0.5, g = 0.5, b = 0.5},
			red = {r = 1.0, g = 0.0, b = 0.0},
			green = {r = 0.20, g = 0.90, b = 0.20},
			yellow = {r = 1.0, g = 1.0, b = 0.0},
			enemyUnattack = {r = 0.60, g = 0.20, b = 0.20},
		},
		xpColor = {
			normal = {r = 0.58, g = 0.0, b = 0.55},
			rested = {r = 0.0, g = 0.39, b = 0.88, a = 0.80},
		},
		-- Default unit options
		portrait = {
			alignment = "LEFT",
			width = 0.22,
		},
		auras = {
			buffs = {anchorPoint = "BOTTOM", size = 16, x = 0, y = 0},
			debuffs = {anchorPoint = "BOTTOM", size = 16, x = 0, y = 0},
		},
		indicators = {
			happiness = {anchorTo = "$parent", anchorPoint = "BR", x = 0, y = 0},
			raidTarget = {anchorTo = "$parent", anchorPoint = "TC", size = 20, y = -14},
			status = {anchorTo = "$parent", anchorPoint = "LB", size = 16, y = -2, x = 12},
			masterLoot = {anchorTo = "$parent", anchorPoint = "TL", size = 12, x = 35, y = 3},
			leader = {anchorTo = "$parent", anchorPoint = "TL", size = 14, x = 2, y = 4},
			pvp = {anchorTo = "$parent", anchorPoint = "BL", size = 22, y = 11, x = 40},
		},
		healthBar = {
			background = true,
			height = 1.20,
			width = 1.0,
			order = 10,
		},
		powerBar = {
			background = true,
			height = 1.0,
			width = 1.0,
			order = 20,
		},
		xpBar = {
			background = true,
			height = 0.25,
			width = 1.0,
			order = 30,
		},
		castBar = {
			background = true,
			height = 0.60,
			width = 1.0,
			order = 40,
		},
		runeBar = {
			background = false,
			height = 0.80,
			width = 1.0,
			order = 50,
		},
		positions = {
			targettargettarget = {anchorPoint = "RC", anchorTo = "#SUFUnittargettarget", x = 0, y = 0}, 
			targettarget = {anchorPoint = "TL", anchorTo = "#SUFUnittarget", x = 0, y = 25}, 
			focustarget = {anchorPoint = "TL", anchorTo = "#SUFUnitfocus", x = 0, y = 25},
			party = {anchorPoint = "BL", anchorTo = "#SUFUnitplayer", x = 0, y = -30}, 
			focus = {anchorPoint = "RB", anchorTo = "#SUFUnittarget", x = 40, y = 0}, 
			target = {anchorPoint = "RC", anchorTo = "#SUFUnitplayer", x = 50, y = 0}, 
			player = {point = "TOPLEFT", anchorTo = "UIParent", relativePoint = "TOPLEFT", y = -25, x = 20}, 
			partypet = {anchorPoint = "RB", anchorTo = "#SUFHeaderparty", x = 0, y = 0},
			raid = {anchorPoint = "C", anchorTo = "UIParent", x = 0, y = 0},
		},
		-- Units
		raid = {
			width = 100,
			height = 30,
			scale = 0.85,
			showPlayer = true,
			unitsPerColumn = 8,
			maxColumns = 8,
			columnSpacing = -5,
			attribPoint = "TOP",
			attribAnchorPoint = "RIGHT",
			powerBar = {height = 0.60},
			text = {
				{text = "[name]"},
				{text = "[curhp]"},
				{text = ""},
				{text = "[curpp]"},
			},
		},
		player = {
			width = 190,
			height = 55,
			scale = 1.0,
			text = {
				{width = 0.60, text = "[name]", anchorTo = "$healthBar", anchorPoint = "ICL", x = 3, y = 0},
				{width = 0.40, text = "[curmaxhp]", anchorTo = "$healthBar", anchorPoint = "ICR", x = -3, y = 0},
				
				{width = 0.60, text = "[perpp]", anchorTo = "$powerBar", anchorPoint = "ICL", x = 3, y = 0},
				{width = 0.40, text = "[curmaxpp]", anchorTo = "$powerBar", anchorPoint = "ICR", x = -3, y = 0},
			},
		},
		party = {
			width = 190,
			height = 50,
			scale = 1.0,
			attribPoint = "TOP",
			attribAnchorPoint = "LEFT",
			yOffset = -20,
		},
		partypet = {
			width = 125,
			height = 30,
			scale = 1.0,
			powerBar = {height = 0.60},
			text = {
				{text = "[name]"},
				{text = "[curhp]"},
				{text = ""},
				{text = ""},
			},
		},
		target = {
			width = 190,
			height = 55,
			scale = 1.0,
			comboPoints = {anchorTo = "$parent", anchorPoint = "BL", x = 0, y = 0, growth = "UP"},
			indicators = {
				happiness = {anchorTo = "$parent", anchorPoint = "BR", x = 0, y = 0},
				raidTarget = {anchorTo = "$parent", anchorPoint = "TC", size = 20, y = -15},
				status = {anchorTo = "$parent", anchorPoint = "BL", size = 16, y = -2, x = 12},
				masterLoot = {anchorTo = "$parent", anchorPoint = "TR", size = 12, x = -37, y = -9},
				leader = {anchorTo = "$parent", anchorPoint = "TR", size = 14, x = -2, y = -10},
				pvp = {anchorTo = "$parent", anchorPoint = "BR", size = 22, y = 11, x = -34},
			},
		},
		pet = {
			width = 200,
			height = 60,
			scale = 1.0,
			text = {
				{text = "[name]"},
				{text = "[curhp]"},
				{text = "[perpp]"},
				{text = "[curpp]"},
			},
		},
		focus = {
			width = 120,
			height = 30,
			scale = 1.0,
			powerBar = {width = 1.0, height = 0.70},
			text = {
				{text = "[name]"},
				{text = "[curhp]"},
				{text = "[perpp]"},
				{text = "[curpp]"},
			},
		},
		focustarget = {
			width = 120,
			height = 30,
			scale = 1.0,
			powerBar = {width = 1.0, height = 0.60},
			text = {
				{text = "[name]"},
				{text = "[maxhp]"},
				{text = ""},
				{text = ""},
			},
		},
		targettarget = {
			width = 110,
			height = 30,
			scale = 1.0,
			powerBar = {width = 1.0, height = 0.70},
			text = {
				{text = "[name]"},
				{text = "[curhp]"},
				{text = "[perpp]"},
				{text = "[curpp]"},
			},
		},
		targettargettarget = {
			width = 80,
			height = 30,
			scale = 1.0,
			powerBar = {width = 1.0, height = 0.60},
			text = {
				{text = "[name]"},
				{text = ""},
				{text = ""},
				{text = ""},
			},
		},
	},
})










