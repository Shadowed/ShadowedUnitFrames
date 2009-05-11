-- Debug
if( not ShadowUF ) then
	return
end

local L = ShadowUFLocals

--[[
		Layout format
		
		Any table tagged with <position arguments accepts the below, this are semi-directly based to SetPoint
		See: http://www.wowwiki.com/API_Region_SetPoint for more information
		anchorTo = "<frame name>/$parent/$<widget name>", -- Where to anchor this, $healthBar anchors it to the health bar $parent anchors it to units frame, UIParent anchors it to UIParent
		x = #, -- X offset
		y = #, -- Y offset
		
		point = "point", -- See above link
		relativePoint = "relativePoint", -- See above link
		
		OR instead of setting a specific point/relative point, you can use a predefined one anchorPoint = "<point>", -- Predefined anchor point, see below
		
		RT = Right Top, RC = Right Center, RB = Right Bottom
		LT = Left Top, LC = Left Center, LB = Left Bottom,
		BL = Bottom Left, BC = Bottom Center, BR = Bottom Right
		ICL = Inside Center Left, IC = Inside Center Center, ICR = Inside Center Right
		TR = Top Right, TC = Top Center, TL = Top Left
		ITR = Inside Top Right, ITL = Inside Top Left

		{
			general = {
				barTexture = "<name>", -- Texture name in SML  to use for all bars
				clip = #, -- How close widgets should clip the edge, 1 is one pixel away from clipping
				barSpacing = #, -- How much spacing to use between bars, --1.25 would space them out by 1.25 pixels
				barAlpha = #.#, -- Alpha to use for all bars
				backgroundAlpha = #.#, -- Alpha to use for the background of bars
			},
			font = {
				name = "<name>", -- Font name in SML, to use for all fonts except the stack counter in auras
				size = #, -- Font size
				shadowColor = {r = #, g = #, b = #}, -- Shadow color for text
				shadowX = #, -- X offset for shadows
				shadowY = #, -- Y offset for shadows
			},
			-- See http://www.wowwiki.com/API_Frame_SetBackdrop for more information
			backdrop = {
				backgroundTexture = "<texture path>", -- Background graphic to use ("" for none)
				backgroundColor = {r = #, g = #, b = #, a = #}, -- Background color/alpha
				borderTexture = "<texture path>", -- Edge graphic to use ("" for none)
				borderColor = {r = #, g = #, b = #, a = #}, -- Edge color/alpha
				tileSize = #, -- How large each bgFile becomes, tiling is automatically enabled if tileSize is greater than one
				edgeSize - #, -- How large each edge will be
				inset = #, -- How thick the edges should be
			},
			powerColor = {
				[0] = {r = #, g = #, b = #}, -- Power bar color for mana
				[1] = {r = #, g = #, b = #}, -- Power bar color for rage
				[2] = {r = #, g = #, b = #}, -- Power bar color for focus
				[3] = {r = #, g = #, b = #}, -- Power bar color for energy
				[4] = {r = #, g = #, b = #}, -- Power bar color for happiness
				[5] = {r = #, g = #, b = #}, -- Power bar color for runes
				[6] = {r = #, g = #, b = #}, -- Power bar color for runic power
				[7] = {r = #, g = #, b = #}, -- Power bar color for ammo slot in vehicles
				[8] = {r = #, g = #, b = #}, -- Power bar color for fuel in vehicles
			},
			healthColor = {
				tapped = {r = #, g = #, b = #}, -- Health bar color when a mob is tapped by someone besides the player/party
				red = {r = #, g = #, b = #}, -- Health bar color red
				yellow = {r = #, g = #, b = #}, -- Health bar color yellow
				green = {r = #, g = #, b = #}, -- Health bar color green
			},
			xpColor = {
				normal = {r = #, g = #, b = #}, -- Normal Xp color
				rested = {r = #, g = #, b = #}, -- Rested XP color
			},
			-- Accepts: party, raid, player, pet, partypet, focustarget, targettarget, targettargettarget
			<unit configuration> = {
				width = #, -- How wide the frame should be
				height = #, -- How tall the frame should be
				scale = #, -- Frame scaling
				effectiveScale = true/false, -- Apply the effective scaling when positioning it
				healthBar = <see healthBar below>, -- Health bar configuration for this unit
				manaBar = <see manaBar below>, -- Mana bar configuration for this unit
				xpBar = <see xpBar below>, -- XP bar configuration for this unit
				portrait = <see portrait below>, -- Portrait configuration for this unit
				text = <see text below>, -- Text configuration for this unit
				<position arguments> -- See above
			},
			<party/raid> = {
				<unit configuration> -- See above
				showRaid = true/false, -- Show the raid in this
				showParty = true/false, -- Show players party in this
				showPlayer = true/false, -- Show the player themselves in this
				showSolo = true/false, -- Show this while solo
				-- Accepts all attributes listed http://wowprogramming.com/docs/secure_template/Group_Headers by key
				<position arguments>,
			},
			-- These tables listed in the main tree are automatically inherited to all units when the layout is applied
			-- For example if you have {portrait = enabled, player = {portrait = {enabled = false}}} then portraits will be
			-- enabled for all units EXCEPT for players. Users cannot configure inherited values.
			portrait = {
				enabled = true/false, -- Enable portraits
				alignment = "LEFT/RIGHT", -- How to align the portraits, target units have it auto swapped so if this is LEFT, it'll be RIGHT for target automatically
				width = #.#, -- Percentage of bar width to use, 0.25 will use 25% of the bars width.
			},
			healthBar = {
				heightWeight = #.#, -- Weighting to use to figure out how much of the bar height this gets, higher number means it gets more of the height
				width = #.#, -- How much of the available width should be used, 1.0 will use up all available width.
				order = #, -- Ordering, lower number means it shows up higher on the list
				background = true/false, -- Show a background behind the bar
			},
			manabar = {
				heightWeight = #.#, -- Weighting to use to figure out how much of the bar height this gets, higher number means it gets more of the height
				width = #.#, -- How much of the available width should be used, 1.0 will use up all available width.
				order = #, -- Ordering, lower number means it shows up higher on the list
				background = true/false, -- Show a background behind the bar
			},
			xpBar = {
				heightWeight = #.#, -- Weighting to use to figure out how much of the bar height this gets, higher number means it gets more of the height
				width = #.#, -- How much of the available width should be used, 1.0 will use up all available width.
				order = #, -- Ordering, lower number means it shows up higher on the list
				background = true/false, -- Show a background behind the bar
			},
			-- Font strings to use inside this unit
			text = {
				{
				name = "<name>", -- Display name for this text
				widthPercent = #.#, -- Percent of bars width to use for this
				text = "<text>", -- Actual text with tags to use
				<position arguments> -- See above
			},
			-- All indicators use the same format
			indicators = {
				<indicator format> = {
					enabled = true/false, -- Enable this indicator
					width = #, -- Icon width
					height = #, -- Icon height
					
					<position arguments>, -- See above for these
				},
				
				status = <indicator format>, -- Show status (Rested/In Combat)
				pvpFlag = <indicator format>, -- Show PVP flag if any (Flagged PvP/Flagged FFA)
				leader = <indicator format>, -- Show crown if the units party/raid leader
				masterLoot = <indicator format>, -- Show master looter icon
				raidTarget = <indicator format>, -- Show raid target icon
				happiness = <indicator format>, -- Show pet happiness
			}
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
			barAlpha = 1.0,
			backgroundAlpha = 0.20,
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
			normal = {r = 0.58, g = 0.0, b = 0.55},
			rested = {r = 0.0, g = 0.39, b = 0.88, a = 0.80},
		},
		-- Default unit options
		text = {
				{enabled = true, name = L["Left text"], widthPercent = 0.60, text = "[raidcolor][name]|r", point = "LEFT", anchorTo = "$healthBar", relativePoint = "LEFT", x = 3, y = 0},
				{enabled = true, name = L["Right text"], widthPercent = 0.40, text = "[curmaxhp]", point = "RIGHT", anchorTo = "$healthBar", relativePoint = "RIGHT", x = -3, y = 0},
				
				{enabled = true, name = L["Left text"], widthPercent = 0.60, text = "[level] [race]", point = "LEFT", anchorTo = "$manaBar", relativePoint = "LEFT", x = 3, y = 0},
				{enabled = true, name = L["Right text"], widthPercent = 0.40, text = "[curmaxpp]", point = "RIGHT", anchorTo = "$manaBar", relativePoint = "RIGHT", x = -3, y = 0},
		},
		auras = {
			buffs = {enabled = true, position = "TOP", size = 16, inColumn = 8, rows = 4, x = 0, y = 0, enlargeSelf = true, filters = {HELPFUL = true}},
			debuffs = {enabled = true, position = "BOTTOM", size = 16, inColumn = 8, rows = 4, x = 0, y = 0, enlargeSelf = true, filters = {HARMFUL = true}},
		},
		portrait = {
			enabled = true,
			alignment = "LEFT",
			width = 0.22,
		},
		healthBar = {
			enabled = true,
			background = true,
			heightWeight = 1.20,
			width = 1.0,
			order = 0,
		},
		manaBar = {
			enabled = true,
			background = true,
			heightWeight = 1.0,
			width = 1.0,
			order = 1,
		},
		xpBar = {
			enabled = true,
			background = true,
			heightWeight = 0.25,
			width = 1.0,
			order = 2,
		},
		castBar = {
			enabled = false,
			background = true,
			heightWeight = 0.60,
			width = 1.0,
			order = 3,
			castName = {anchorTo = "$parent", anchorPoint = "ICL", x = 1, y = 0},
			castTime = {anchorTo = "$parent", anchorPoint = "ICR", x = -1, y = 0},
		},
		indicators = {
			status = {enabled = true, height = 19, width = 19, point = "BOTTOMLEFT", anchorTo = "$parent", relativePoint = "BOTTOMLEFT", x = 0, y = 0},
			pvp = {enabled = true, height = 22, width = 22, point = "TOPRIGHT", anchorTo = "$parent", relativePoint = "TOPRIGHT", x = 10, y = 2},
			leader = {enabled = true, height = 14, width = 14, point = "TOPLEFT", anchorTo = "$parent", relativePoint = "TOPLEFT", x = 3, y = 2},
			masterLoot = {enabled = true, height = 12, width = 12, point = "TOPLEFT", anchorTo = "$parent", relativePoint = "TOPLEFT", x = 15, y = 2},
			raidTarget = {enabled = true, height = 22, width = 22, point = "BOTTOM", anchorTo = "$parent", relativePoint = "TOP", x = 0, y = -8},
			happiness = {enabled = true, height = 16, width = 16, point = "TOPLEFT", anchorTo = "$parent", relativePoint = "TOPLEFT", x = 2, y = -2},
		},
		positions = {
			raid = {point = "CENTER", anchorTo = "UIParent", relativePoint = "CENTER", x = 100, y = -100},
			party = {anchorPoint = "BL", anchorTo = "#SSUFUnitplayer", x = 0, y = -100},
			player = {point = "TOPLEFT", anchorTo = "UIParent", relativePoint = "TOPLEFT", x = 50, y = -50},
			target = {anchorPoint = "RT", anchorTo = "#SSUFUnitplayer", x = 50, y = 0},
			pet = {anchorPoint = "BL", anchorTo = "#SSUFUnitplayer", x = 0, y = -100},
			focus = {anchorPoint = "RT", anchorTo = "#SSUFUnittarget", x = 100, y = 0},
			targettarget = {anchorPoint = "BL", anchorTo = "#SSUFUnittarget", x = 0, y = -75},
		},
		-- Units
		raid = {
			width = 80,
			height = 40,
			scale = 1.0,
			effectiveScale = true,
			showRaid = true,
			showPlayer = true,
			portrait = {enabled = false},
			castBar = {enabled = false},
			unitsPerColumn = 7,
			maxColumns = 8,
			columnSpacing = 25,
			attribPoint = "TOP",
			attribAnchorPoint = "RIGHT",
		},
		player = {
			width = 200,
			height = 60,
			scale = 1.0,
			effectiveScale = true,
		},
		party = {
			width = 200,
			height = 60,
			scale = 1.0,
			effectiveScale = true,
			attribPoint = "TOP",
			attribAnchorPoint = "TOP",
			showPlayer = true,
			showParty = true,
		},
		partypet = {
			width = 125,
			height = 30,
			scale = 1.0,
			groupWith = "parent",
			position = "BR",
			portrait = {enabled = false},
			castBar = {enabled = false},
		},
		target = {
			width = 200,
			height = 60,
			scale = 1.0,
			appleEffective = true,
		},
		pet = {
			width = 200,
			height = 60,
			scale = 1.0,
			effectiveScale = true,
		},
		focus = {
			width = 200,
			height = 60,
			scale = 1.0,
			appleEffective = true,
		},
		targettarget = {
			width = 200,
			height = 60,
			scale = 1.0,
		},
		targettargettarget = {
			width = 200,
			height = 60,
			scale = 1.0,
		},
	},
})










