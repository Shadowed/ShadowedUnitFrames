local L = ShadowUFLocals
function ShadowUF:LoadDefaultLayout()
	self.db.profile.bars = {
		texture = "Minimalist",
		spacing = -1.25,
		alpha = 1.0,
		backgroundAlpha = 0.20,
	}

	self.db.profile.backdrop = {
		tileSize = 1,
		edgeSize = 5,
		clip = 1,
		inset = 3,
		backgroundTexture = "Chat Frame",
		backgroundColor = {r = 0, g = 0, b = 0, a = 0.80},
		borderTexture = "None",
		borderColor = {r = 0.30, g = 0.30, b = 0.50, a = 1},
	}
	self.db.profile.font = {
		name = "Myriad Condensed Web",
		size = 11,
		extra = "",
		shadowColor = {r = 0, g = 0, b = 0, a = 1.0},
		shadowX = 0.80,
		shadowY = -0.80,
	}
	self.db.profile.classColors = {
		HUNTER = {r = 0.67, g = 0.83, b = 0.45},
		WARLOCK = {r = 0.58, g = 0.51, b = 0.79},
		PRIEST = {r = 1.0, g = 1.0, b = 1.0},
		PALADIN = {r = 0.96, g = 0.55, b = 0.73},
		MAGE = {r = 0.41, g = 0.8, b = 0.94},
		ROGUE = {r = 1.0, g = 0.96, b = 0.41},
		DRUID = {r = 1.0, g = 0.49, b = 0.04},
		SHAMAN = {r = 0.14, g = 0.35, b = 1.0},
		WARRIOR = {r = 0.78, g = 0.61, b = 0.43},
		DEATHKNIGHT = {r = 0.77, g = 0.12 , b = 0.23},
		PET = {r = 0.20, g = 0.90, b = 0.20},
		VEHICLE = {r = 0.23, g = 0.41, b = 0.23},
	}
	self.db.profile.powerColors = {
		MANA = {r = 0.30, g = 0.50, b = 0.85}, 
		RAGE = {r = 0.90, g = 0.20, b = 0.30},
		FOCUS = {r = 1.0, g = 0.85, b = 0}, 
		ENERGY = {r = 1.0, g = 0.85, b = 0.10}, 
		HAPPINESS = {r = 0.50, g = 0.90, b = 0.70},
		RUNES = {r = 0.50, g = 0.50, b = 0.50}, 
		RUNIC_POWER = {b = 0.60, g = 0.45, r = 0.35},
		AMMOSLOT = {r = 0.85, g = 0.60, b = 0.55},
		FUEL = {r = 0.85, g = 0.47, b = 0.36},
	}
	self.db.profile.healthColors = {
		tapped = {r = 0.5, g = 0.5, b = 0.5},
		red = {r = 0.90, g = 0.0, b = 0.0},
		green = {r = 0.20, g = 0.90, b = 0.20},
		yellow = {r = 0.93, g = 0.93, b = 0.0},
		inc = {r = 0, g = 0.35, b = 0.23},
		enemyUnattack = {r = 0.60, g = 0.20, b = 0.20},
		hostile = {r = 0.90, g = 0.0, b = 0.0},
		friendly = {r = 0.20, g = 0.90, b = 0.20},
		neutral = {r = 0.93, g = 0.93, b = 0.0},
	}
	self.db.profile.xpColors = {
		normal = {r = 0.58, g = 0.0, b = 0.55},
		rested = {r = 0.0, g = 0.39, b = 0.88, a = 0.80},
	}
	self.db.profile.positions = {
		targettargettarget = {anchorPoint = "RC", anchorTo = "#SUFUnittargettarget", x = 0, y = 0}, 
		targettarget = {anchorPoint = "TL", anchorTo = "#SUFUnittarget", x = 0, y = 25}, 
		focustarget = {anchorPoint = "TL", anchorTo = "#SUFUnitfocus", x = 0, y = 25},
		party = {anchorPoint = "BL", anchorTo = "#SUFUnitplayer", x = 0, y = -30}, 
		focus = {anchorPoint = "RB", anchorTo = "#SUFUnittarget", x = 40, y = 0}, 
		target = {anchorPoint = "RC", anchorTo = "#SUFUnitplayer", x = 50, y = 0}, 
		player = {point = "TOPLEFT", anchorTo = "UIParent", relativePoint = "TOPLEFT", y = -25, x = 20}, 
		pet = {anchorPoint = "TL", anchorTo = "#SUFUnitplayer", x = 0, y = 25}, 
		pettarget = {anchorPoint = "C", anchorTo = "UIParent", x = 0, y = 0}, 
		partypet = {anchorPoint = "RB", anchorTo = "$parent", x = 0, y = 0},
		partytarget = {anchorPoint = "RT", anchorTo = "$parent", x = 0, y = 0},
		raid = {anchorPoint = "C", anchorTo = "UIParent", x = 0, y = 0},
	}
	
	-- Parent unit options that all the children will inherit unless they override it
	local parentUnit = {
		portrait = {enabled = false, alignment = "LEFT", width = 0.22, order = 15},
		auras = {
			buffs = {enabled = false, anchorPoint = "BL", size = 16, x = 0, y = 0},
			debuffs = {enabled = false, anchorPoint = "BL", size = 16, x = 0, y = 0},
		},
		text = {
			{width = 0.50, name = L["Left text"], anchorTo = "$healthBar", anchorPoint = "CLI", x = 3, y = 0, size = 0},
			{width = 0.60, name = L["Right text"], anchorTo = "$healthBar", anchorPoint = "CRI", x = -3, y = 0, size = 0},

			{width = 0.50, name = L["Left text"], anchorTo = "$powerBar", anchorPoint = "CLI", x = 3, y = 0, size = 0},
			{width = 0.60, name = L["Right text"], anchorTo = "$powerBar", anchorPoint = "CRI", x = -3, y = 0, size = 0},
		},
		indicators = {
			raidTarget = {anchorTo = "$parent", anchorPoint = "C", size = 20, x = 0, y = 0},
			masterLoot = {anchorTo = "$parent", anchorPoint = "TL", size = 12, x = 16, y = 3},
			leader = {anchorTo = "$parent", anchorPoint = "TL", size = 14, x = 2, y = 4},
			pvp = {anchorTo = "$parent", anchorPoint = "BL", size = 22, x = 40, y = 11},
			ready = {anchorTo = "$parent", anchorPoint = "C", size = 24, x = 0, y = 0},
		},
		combatText = {anchorTo = "$parent", anchorPoint = "C", x = 0, y = 0},
		healthBar = {background = true, height = 1.20, width = 1.0, order = 10},
		powerBar = {background = true, height = 1.0, width = 1.0, order = 20},
		xpBar = {background = true, height = 0.25, width = 1.0, order = 30},
		castBar = {background = true, height = 0.60, width = 1.0, order = 40},
		runeBar = {background = false, height = 0.40, width = 1.0, order = 50},
		totemBar = {background = false, height = 0.40, width = 1.0, order = 50}
	}
	
	-- Units configuration
	local units = {
		raid = {
			width = 100,
			height = 30,
			scale = 0.85,
			unitsPerColumn = 8,
			maxColumns = 8,
			columnSpacing = -5,
			attribPoint = "TOP",
			attribAnchorPoint = "LEFT",
			powerBar = {height = 0.60},
			indicators = {
				pvp = {anchorTo = "$parent", anchorPoint = "BL", size = 22, x = 0, y = 11},
			},
			text = {
				{text = "[afk( )][group( )][name]"},
				{text = "[curhp]"},
				{text = ""},
				{text = "[curpp]"},
			},
		},
		player = {
			width = 190,
			height = 50,
			scale = 1.0,
			portrait = {enabled = true, fullAfter = 50},
			xpBar = {order = 55},
			castBar = {order = 60},
			runeBar = {order = 70},
			totemBar = {order = 70},
			auras = {
				buffs = {enabled = true},
				debuffs = {enabled = true},
			},
			indicators = {
				status = {anchorTo = "$parent", anchorPoint = "LB", size = 16, x = 12, y = -2},
			},
			text = {
				{text = "[afk( )][name][( ()group())]"},
				{text = "[curmaxhp]"},
				{text = "[perpp]"},
				{text = "[curmaxpp]"},
			},
		},
		party = {
			width = 190,
			height = 50,
			scale = 1.0,
			attribPoint = "TOP",
			attribAnchorPoint = "LEFT",
			yOffset = -20,
			auras = {
				buffs = {enabled = true},
				debuffs = {enabled = true},
			},
			text = {
				{text = "[afk( )][name]"},
				{text = "[curmaxhp]"},
				{text = "[level( )][perpp]"},
				{text = "[curmaxpp]"},
			},
			portrait = {enabled = true},
		},
		partypet = {
			width = 90,
			height = 25,
			scale = 1.0,
			powerBar = {height = 0.60},
			text = {
				{text = "[name]"},
				{text = "[curhp]"},
				{text = ""},
				{text = ""},
			},
		},
		partytarget = {
			width = 90,
			height = 25,
			scale = 1.0,
			powerBar = {height = 0.60},
			indicators = {
				pvp = {anchorTo = "$parent", anchorPoint = "BL", size = 22, x = 0, y = 11},
			},
			text = {
				{text = "[name]"},
				{text = "[curhp]"},
				{text = ""},
				{text = ""},
			},
		},
		target = {
			width = 190,
			height = 50,
			scale = 1.0,
			portrait = {enabled = true},
			comboPoints = {anchorTo = "$parent", anchorPoint = "BR", x = -3, y = 8, size = 14, spacing = -4, growth = "UP"},
			indicators = {
				masterLoot = {anchorTo = "$parent", anchorPoint = "TR", size = 12, x = -16, y = 3},
				leader = {anchorTo = "$parent", anchorPoint = "TR", size = 14, x = -2, y = 4},
				pvp = {anchorTo = "$parent", anchorPoint = "BL", size = 22, x = -3, y = 11},
			},
			auras = {
				buffs = {enabled = true},
				debuffs = {enabled = true},
			},
			text = {
				{text = "[afk( )][name]"},
				{text = "[curmaxhp]"},
				
				{text = "[level( )][classification( )][perpp]", width = 0.50},
				{text = "[curmaxpp]", anchorTo = "$powerBar", width = 0.60},
			},
		},
		pet = {
			width = 190,
			height = 30,
			scale = 1.0,
			powerBar = {height = 0.70},
			indicators = {
				status = {anchorTo = "$parent", anchorPoint = "LB", size = 16, y = -2, x = 12},
				happiness = {anchorTo = "$parent", anchorPoint = "BR", size = 16, x = 0, y = 0},
			},
			text = {
				{text = "[name]"},
				{text = "[curmaxhp]"},
				{text = "[perpp]"},
				{text = "[curmaxpp]"},
			},
		},
		pettarget = {
			width = 190,
			height = 30,
			scale = 1.0,
			powerBar = {height = 0.70},
			indicators = {
				status = {anchorTo = "$parent", anchorPoint = "LB", size = 16, y = -2, x = 12},
			},
			text = {
				{text = "[name]"},
				{text = "[curmaxhp]"},
				{text = "[perpp]"},
				{text = "[curmaxpp]"},
			},
		},
		focus = {
			width = 120,
			height = 30,
			scale = 1.0,
			powerBar = {height = 0.70},
			indicators = {
				pvp = {anchorTo = "$parent", anchorPoint = "BL", size = 22, x = -3, y = 11},
			},
			text = {
				{text = "[afk( )][name]"},
				{text = "[curhp]"},
				{text = "[perpp]"},
				{text = "[curpp]"},
			},
		},
		focustarget = {
			width = 120,
			height = 30,
			scale = 1.0,
			powerBar = {height = 0.60},
			indicators = {
				pvp = {anchorTo = "$parent", anchorPoint = "BL", size = 22, x = -3, y = 11},
			},
			text = {
				{text = "[afk( )][name]"},
				{text = "[curhp]"},
				{text = ""},
				{text = ""},
			},
		},
		targettarget = {
			width = 110,
			height = 30,
			scale = 1.0,
			powerBar = {height = 0.90},
			indicators = {
				pvp = {anchorTo = "$parent", anchorPoint = "BL", size = 22, x = -3, y = 11},
			},
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
			powerBar = {height = 0.90},
			indicators = {
				pvp = {anchorTo = "$parent", anchorPoint = "BL", size = 22, x = -3, y = 11},
			},
			text = {
				{text = "[name]", width = 1.0},
				{text = ""},
				{text = ""},
				{text = ""},
			},
		},
	}
			 
	-- Merges all of the parentUnit options into the child if they weren't set.
	-- if it's a table, it recurses inside the table and copies any nil values in too
	local function mergeToChild(parent, child, forceMerge)
		for key, value in pairs(parent) do
			if( type(child[key]) == "table" ) then
				mergeToChild(value, child[key], forceMerge)
			elseif( type(value) == "table" ) then
				child[key] = CopyTable(value)
			elseif( forceMerge or ( value ~= nil and child[key] == nil ) ) then
				child[key] = value
			end
		end
	end

	-- This makes sure that the unit has no values it shouldn't, for example if the defaults do not set incHeal for targettarget
	-- and I try to set incHeal table here, then it'll remove it since it can't do that.
	local function verifyTable(tbl, checkTable)
		for key, value in pairs(tbl) do
			if( type(value) == "table" ) then
				if( not checkTable[key] ) then
					tbl[key] = nil
				else
					for subKey, subValue in pairs(value) do
						if( type(subValue) == "table" ) then
							verifyTable(value, checkTable[key])
						end
					end
				end
			end
		end
	end
	
	-- Set everything
	for unit, child in pairs(units) do
		-- Merge the primary parent table
		mergeToChild(parentUnit, child)
		-- Strip any invalid tables
		verifyTable(child, ShadowUF.defaults.profile.units[unit])
		-- Merge it in
		mergeToChild(child, ShadowUF.db.profile.units[unit], true)
	end

	self.db.profile.loadedLayout = true
end
	
