local Config = {}
local AceDialog, AceRegistry, AceGUI, SML, registered, options, quickIDMap
local modifyUnits, globalConfig = {}, {}
local L = ShadowUFLocals

ShadowUF.Config = Config

--[[
	Interface design is a complex process, you might ask what goes into it? Well this is what it requires:
	10% bullshit, 15% tears, 15% hackery, 20% yelling at code, 40% magic
	
	TOC note suggestions from the IRC-crazies

	[28:58] <Aikiwoce> Shadow Unit Frames now with 100% less fail
	[32:11] <Aikiwoce> Shadowed Unit Frames, Made from the best stuff on Azeroth.
	[33:24] <Aikiwoce> Shadowed Unit Frames, Only you can prevent people from standing in fire.
	[33:29] <+forostie> Shadowed Unit Frames - Go hard or get mrgggl'd
	[33:54] <+forostie> Shadowed Unit Frames - Live long and be prosperous
	[34:24] <+forostie> Shadowed Unit Frames - Dick Don't Pay For Strange
	[34:24] <Aikiwoce> Shadowed Unit Frames, The champagne of unit frames.
	[34:31] <+Darkside> SUF: Carrying bad arena teams to glad since S5
	[34:44] <+forostie> Shadowed Unit Frames - The basement your daughter never had
	[35:11] <Aikiwoce> SUF: Where's the cream filling?
	[35:29] <+forostie> SUF: Almost SUP, but heaps not
	[35:35] <TNSe> Shadowed Unit Frames: Now you know what SUF stands for.
	[35:39] <+Darkside> SUF: Happy cows make happy unit frames. CAAALIFORNIA
	[36:09] <TNSe> Shadowed Unit Frames: Not the cause of BRG.
	[36:09] <+forostie> Shadowed Unit Frames: Made by the guy who also made that arena thing
	[36:59] <Aikiwoce> Shadowed Unit Frames: So easy a caveman can do it.
	[37:01] <+forostie> and post it on wowi
	[37:02] <L_J> should change the name tbh, there's no shadows in SUF :I
	[37:05] <friar> Shadowed Unit Frames: Probably no shadow option.
	[37:07] <@jabowah> Shadowed Unit Frames: CRUSHING ALL THE OPPOSITION W/ OUR MIGHTY LASER CANNON
	[41:57] <friar> SUF: Single Undead Female
	[42:48] <Kalroth> SUF: Six Under Feet.
	[44:51] <Aikiwoce> SUF: Kid tested, EJ-approved
]]

local selectDialogGroup, selectTabGroup, hideAdvancedOption, getName, getUnitOrder, set, get, setVariable, getVariable
local setColor, getColor, setUnit, getUnit, getTagName, getTagHelp, hideRestrictedOption, getModuleOrder
local unitOrder, positionList, fullReload, pointPositions, isModifiersSet, isUnitDisabled, mergeTables
local function loadData()
	-- Simple position list rather than the full one
	pointPositions = {[""] = L["None"], ["TOPLEFT"] = L["Top Left"], ["TOPRIGHT"] = L["Top Right"], ["BOTTOMLEFT"] = L["Bottom Left"], ["BOTTOMRIGHT"] = L["Bottom Right"], ["C"] = L["Center"]}
	-- This is a basic one for frame anchoring
	positionList = {[""] = L["None"], ["C"] = L["Center"], ["RT"] = L["Right Top"], ["RC"] = L["Right Center"], ["RB"] = L["Right Bottom"], ["LT"] = L["Left Top"], ["LC"] = L["Left Center"], ["LB"] = L["Left Bottom"], ["BL"] = L["Bottom Left"], ["BC"] = L["Bottom Center"], ["BR"] = L["Bottom Right"], ["TR"] = L["Top Right"], ["TC"] = L["Top Center"], ["TL"] = L["Top Left"] }
	-- Ordering of units in the side bar, enabled units, visibility, etc
	unitOrder = {}
	for order, unit in pairs(ShadowUF.units) do unitOrder[unit] = order end
	-- List of main categories that need the entire frame reloaded
	fullReload = {["bars"] = true, ["backdrop"] = true, ["font"] = true, ["classColors"] = true, ["powerColors"] = true, ["healthColors"] = true, ["xpColors"] = true}

	quickIDMap = {}
	
	-- Helper functions
	selectDialogGroup = function(group, key)
		AceDialog.Status.ShadowedUF.children[group].status.groups.selected = key
		AceRegistry:NotifyChange("ShadowedUF")
	end

	selectTabGroup = function(group, subGroup, key)
		AceDialog.Status.ShadowedUF.children[group].status.groups.selected = subGroup
		AceDialog.Status.ShadowedUF.children[group].children[subGroup].status.groups.selected = key
		AceRegistry:NotifyChange("ShadowedUF")
	end

	hideAdvancedOption = function(info)
		return not ShadowUF.db.profile.advanced
	end
	
	hideBasicOption = function(info)
		return ShadowUF.db.profile.advanced
	end

	isUnitDisabled = function(info)
		return not ShadowUF.db.profile.units[info[#(info)]].enabled
	end
	
	mergeTables = function(parent, child)
		for key, value in pairs(child) do
			if( type(parent[key]) == "table" ) then
				parent[key] = mergeTables(parent[key], value)
			elseif( type(value) == "table" ) then
				parent[key] = CopyTable(value)
			elseif( parent[key] == nil ) then
				parent[key] = value
			end
		end
		
		return parent
	end
	
	getName = function(info)
		local key = info[#(info)]
		if( ShadowUF.modules[key] and ShadowUF.modules[key].moduleName ) then
			return ShadowUF.modules[key].moduleName
		end
		
		return L.classes[key] or L.indicators[key] or L.units[key] or L[key]
	end

	getUnitOrder = function(info)
		return unitOrder[info[#(info)]]
	end
	
	isModifiersSet = function(info)
		if( info[2] ~= "global" ) then return false end
		for k in pairs(modifyUnits) do return false end
		return true
	end

	-- These are for setting simple options like bars.texture = "Default" or locked = true
	-- Basic color management
	setColor = function(info, r, g, b, a)
		local color = get(info)
		color.r, color.g, color.b, color.a = r, g, b, a
		set(info, color)
	end
	
	getColor = function(info)
		local color = get(info)
		return color.r, color.g, color.b, color.a
	end

	set = function(info, value)
		local cat, key = string.split(".", info.arg)
		if( key == "$key" ) then key = info[#(info)] end
		
		if( not key ) then
			ShadowUF.db.profile[cat] = value
		else
			ShadowUF.db.profile[cat][key] = value
		end
		
		if( cat and fullReload[cat] ) then
			ShadowUF.Layout:CheckMedia()
			ShadowUF.Layout:ReloadAll()
		end
	end

	get = function(info)
		local cat, key = string.split(".", info.arg)
		if( key == "$key" ) then key = info[#(info)] end
		if( not key ) then
			return ShadowUF.db.profile[cat]
		else
			return ShadowUF.db.profile[cat][key]
		end
	end

	-- These are for setting complex options like units.player.auras.buffs.enabled = true or units.player.portrait.enabled = true
	setVariable = function(unit, moduleKey, moduleSubKey, key, value)
		local configTable = unit == "global" and globalConfig or ShadowUF.db.profile.units[unit]
	
		-- For setting options like units.player.auras.buffs.enabled = true
		if( moduleKey and moduleSubKey and configTable[moduleKey][moduleSubKey] ) then
			configTable[moduleKey][moduleSubKey][key] = value
			ShadowUF.Layout:ReloadAll(unit)
		-- For setting options like units.player.portrait.enabled = true
		elseif( moduleKey and not moduleSubKey and configTable[moduleKey] ) then
			configTable[moduleKey][key] = value
			ShadowUF.Layout:ReloadAll(unit)
		-- For setting options like units.player.height = 50
		elseif( not moduleKey and not moduleSubKey ) then
			configTable[key] = value
			ShadowUF.Layout:ReloadAll(unit)
		end
	end

	setUnit = function(info, value)
		local unit = info[2]
		-- auras, buffs, enabled / text, 1, text / portrait, enabled
		local moduleKey, moduleSubKey, key = string.split(".", info.arg)
		if( not moduleSubKey ) then key = moduleKey moduleKey = nil end
		if( moduleSubKey and not key ) then key = moduleSubKey moduleSubKey = nil end
		if( moduleSubKey == "$parent" ) then moduleSubKey = info[#(info) - 1] end
		if( moduleKey == "$parent" ) then moduleKey = info[#(info) - 1] end
		if( tonumber(moduleSubKey) ) then moduleSubKey = tonumber(moduleSubKey) end
					
		if( unit == "global" ) then
			for unit in pairs(modifyUnits) do
				setVariable(unit, moduleKey, moduleSubKey, key, value)
			end
			
			setVariable("global", moduleKey, moduleSubKey, key, value)
		else
			setVariable(unit, moduleKey, moduleSubKey, key, value)
		end
	end
	
	getVariable = function(unit, moduleKey, moduleSubKey, key)
		local configTbl = unit == "global" and globalConfig or ShadowUF.db.profile.units[unit]
		if( moduleKey and moduleSubKey ) then
			return configTbl[moduleKey][moduleSubKey][key]
		elseif( moduleKey and not moduleSubKey ) then
			return configTbl[moduleKey][key]
		end

		return configTbl[key]
	end

	getUnit = function(info)
		local moduleKey, moduleSubKey, key = string.split(".", info.arg)
		if( not moduleSubKey ) then key = moduleKey moduleKey = nil end
		if( moduleSubKey and not key ) then key = moduleSubKey moduleSubKey = nil end
		if( moduleSubKey == "$parent" ) then moduleSubKey = info[#(info) - 1] end
		if( moduleKey == "$parent" ) then moduleKey = info[#(info) - 1] end
		if( tonumber(moduleSubKey) ) then moduleSubKey = tonumber(moduleSubKey) end
		
		return getVariable(info[2], moduleKey, moduleSubKey, key)
	end

	-- Tag functions
	getTagName = function(info)
		return string.format("[%s]", info[#(info)])
	end

	getTagHelp = function(info)
		local tag = info[#(info)]
		return ShadowUF.Tags.defaultHelp[tag] or ShadowUF.db.profile.tags[tag] and ShadowUF.db.profile.tags[tag].help
	end

	-- Module functions
	hideRestrictedOption = function(info)
		local unit = type(info.arg) == "number" and info[#(info) - info.arg] or info[2]
		local key = info[#(info)]
		if( ( key == "totemBar" and select(2, UnitClass("player")) ~= "SHAMAN" ) or ( key == "runeBar" and select(2, UnitClass("player")) ~= "DEATHKNIGHT" ) ) then
			return true
		end
											
		-- Non-standard units do not support any of these modules
		if( ( key == "incHeal" or key == "colorAggro" ) and string.match(unit, "%s+target" ) ) then
			return true
		-- Fall back for indicators, no variable table so it shouldn't be shown
		elseif( info[#(info) - 1] == "indicators" ) then
			if( ( unit == "global" and not globalConfig.indicators[key] ) or ( unit ~= "global" and not ShadowUF.db.profile.units[unit].indicators[key] ) ) then
				return true
			end
		-- Fall back, no variable table so it shouldn't be shown
		elseif( ( unit == "global" and not globalConfig[key] ) or ( unit ~= "global" and not ShadowUF.db.profile.units[unit][key] ) ) then
			return true
		end
		
		return false
	end

	getModuleOrder = function(info)
		local key = info[#(info)]
		return key == "healthBar" and 1 or key == "powerBar" and 2 or key == "castBar" and 3 or 4
	end
	
	-- Expose these for modules
	Config.hideAdvancedOption = hideAdvancedOption
	Config.isUnitDisabled = isUnitDisabled
	Config.selectDialogGroup = selectDialogGroup
	Config.selectTabGroup = selectTabGroup
	Config.getName = getName
	Config.getUnitOrder = getUnitOrder
	Config.isModifiersSet = isModifiersSet
	Config.set = set
	Config.get = get
	Config.setUnit = setUnit
	Config.setVariable = setVariable
	Config.getUnit = getUnit
	Config.getVariable = getVariable
	Config.hideRestrictedOption = hideRestrictedOption
	Config.hideBasicOption = hideBasicOption
end


--------------------
-- GENERAL CONFIGURATION
---------------------
local function loadGeneralOptions()
	SML = SML or LibStub:GetLibrary("LibSharedMedia-3.0")
	
	local MediaList = {}
	local function getMediaData(info)
		local mediaType = info[#(info)]

		MediaList[mediaType] = MediaList[mediaType] or {}

		for k in pairs(MediaList[mediaType]) do	MediaList[mediaType][k] = nil end
		for _, name in pairs(SML:List(mediaType)) do
			MediaList[mediaType][name] = name
		end
		
		return MediaList[mediaType]
	end
	
	Config.hideTable = {
		order = 0,
		type = "toggle",
		name = function(info)
			local key = info[#(info)]
			return string.format(L["Hide %s"], L.units[key] or key == "cast" and L["Cast bars"] or key == "runes" and L["Rune bar"] or key == "buffs" and L["Buff icons"])
		end,
		set = function(info, value)
			set(info, value)
			if( value ) then ShadowUF:HideBlizzard(info[#(info)]) end
		end,
		get = get,
		arg = "hidden.$key",
	}
	
	local addTextParent = {
		order = 1,
		type = "group",
		inline = true,
		name = function(info) return info[#(info)] == "$healthBar" and L["Health bar"] or info[#(info)] == "$powerBar" and L["Power bar"] end,
		hidden = function(info)
			for _, text in pairs(ShadowUF.db.profile.units.player.text) do
				if( text.anchorTo == info[#(info)] ) then
					return false
				end
			end
			
			return true
		end,
		args = {},
	}
	
	local addText = {
		order = 1,
		type = "execute",
		name = function(info) return getVariable("player", "text", tonumber(info[#(info)]), "name") end,
		hidden = function(info)
			local id = tonumber(info[#(info)])
			if( not getVariable("player", "text", nil, id) ) then return true end
			return getVariable("player", "text", id, "anchorTo") ~= info[#(info) - 1]
		end,
		disabled = function(info) return tonumber(info[#(info)]) <= 4 end,
		confirmText = L["Are you sure you want to delete this text? All settings for it will be deleted."],
		confirm = true,
		func = function(info)
			local id = tonumber(info[#(info)])
			for _, unit in pairs(ShadowUF.units) do
				table.remove(ShadowUF.db.profile.units[unit].text, id)
			end
			
			addTextParent.args[info[#(info)]] = nil
			ShadowUF.Layout:ReloadAll()
		end,
	}

	local textData = {}
	
	local moverEnabled = false
	options.args.general = {
		type = "group",
		childGroups = "tab",
		name = L["General"],
		args = {
			general = {
				type = "group",
				order = 1,
				name = L["General"],
				set = set,
				get = get,
				args = {
					general = {
						order = 1,
						type = "group",
						inline = true,
						name = L["General"],
						args = {
							locked = {
								order = 0,
								type = "toggle",
								name = L["Lock frames"],
								set = function(info, value)
									set(info, value)
									ShadowUF.modules.movers:Update()
								end,
								arg = "locked",
							},
							advanced = {
								order = 1,
								type = "toggle",
								name = L["Advanced"],
								desc = L["Enabling advanced settings will allow you to further tweak settings. This is meant for people who want to tweak every single thing, and should not be enabled by default as it increases the options."],
								arg = "advanced",
							},
							hideCombat = {
								order = 3,
								type = "toggle",
								name = L["Hide tooltips in combat"],
								desc = L["Sets if unit tooltips should be hidden while in combat."],
								arg = "tooltipCombat",
							},
							statusbar = {
								order = 4,
								type = "select",
								name = L["Bar texture"],
								dialogControl = "LSM30_Statusbar",
								values = getMediaData,
								arg = "bars.texture",
							},
						},
					},
					backdrop = {
						order = 2,
						type = "group",
						inline = true,
						name = L["Background/border"],
						args = {
							backgroundColor = {
								order = 1,
								type = "color",
								name = L["Background color"],
								hasAlpha = true,
								set = setColor,
								get = getColor,
								arg = "backdrop.backgroundColor",
							},
							borderColor = {
								order = 2,
								type = "color",
								name = L["Border color"],
								hasAlpha = true,
								set = setColor,
								get = getColor,
								arg = "backdrop.borderColor",
							},
							sep = {
								order = 3,
								type = "description",
								name = "",
								width = "full",
							},
							background = {
								order = 4,
								type = "select",
								name = L["Background"],
								dialogControl = "LSM30_Background",
								values = getMediaData,
								arg = "backdrop.backgroundTexture",
							},
							border = {
								order = 5,
								type = "select",
								name = L["Border"],
								dialogControl = "LSM30_Border",
								values = getMediaData,
								arg = "backdrop.borderTexture",
							},
							sep2 = {
								order = 6,
								type = "description",
								name = "",
								width = "full",
								hidden = hideAdvancedOption,
							},
							edgeSize = {
								order = 7,
								type = "range",
								name = L["Edge size"],
								desc = L["How large the edges should be."],
								hidden = hideAdvancedOption,
								min = 0, max = 20, step = 1,
								arg = "backdrop.edgeSize",
							},
							tileSize = {
								order = 8,
								type = "range",
								name = L["Tile size"],
								desc = L["How large the background should tile"],
								hidden = hideAdvancedOption,
								min = 0, max = 20, step = 1,
								arg = "backdrop.tileSize",
							},
							clip = {
								order = 9,
								type = "range",
								name = L["Clip"],
								desc = L["How close the frame should clip with the border."],
								hidden = hideAdvancedOption,
								min = 0, max = 20, step = 1,
								arg = "backdrop.clip",
							},
						},
					},
					font = {
						order = 3,
						type = "group",
						inline = true,
						name = L["Font"],
						args = {
							font = {
								order = 1,
								type = "select",
								name = L["Font"],
								dialogControl = "LSM30_Font",
								values = getMediaData,
								arg = "font.name",
							},
							size = {
								order = 2,
								type = "range",
								name = L["Size"],
								min = 1, max = 20, step = 1,
								arg = "font.size",
							},
						},
					},
					color = {
						order = 4,
						type = "group",
						inline = true,
						name = L["Power color"],
						set = setColor,
						get = getColor,
						args = {
							MANA = {
								order = 0,
								type = "color",
								name = L["Mana"],
								hasAlpha = true,
								width = "half",
								arg = "powerColors.MANA",
							},
							RAGE = {
								order = 1,
								type = "color",
								name = L["Mana"],
								hasAlpha = true,
								width = "half",
								arg = "powerColors.RAGE",
							},
							FOCUS = {
								order = 2,
								type = "color",
								name = L["Focus"],
								hasAlpha = true,
								arg = "powerColors.FOCUS",
								width = "half",
							},
							ENERGY = {
								order = 3,
								type = "color",
								name = L["Energy"],
								hasAlpha = true,
								arg = "powerColors.ENERGY",
								width = "half",
							},
							HAPPINESS = {
								order = 5,
								type = "color",
								name = L["Happiness"],
								hasAlpha = true,
								arg = "powerColors.HAPPINESS",
							},
							RUNIC_POWER = {
								order = 6,
								type = "color",
								name = L["Runic Power"],
								hasAlpha = true,
								arg = "powerColors.RUNIC_POWER",
							},
							AMMOSLOT = {
								order = 7,
								type = "color",
								name = L["Ammo"],
								hasAlpha = true,
								arg = "powerColors.AMMOSLOT",
								hidden = hideAdvancedOption,
							},
							FUEL = {
								order = 8,
								type = "color",
								name = L["Fuel"],
								hasAlpha = true,
								arg = "powerColors.FUEL",
								hidden = hideAdvancedOption,
							},
						},
					},
					health = {
						order = 5,
						type = "group",
						inline = true,
						name = L["Health color"],
						set = setColor,
						get = getColor,
						args = {
							green = {
								order = 1,
								type = "color",
								name = L["High health"],
								desc = L["Health bar color used as the transitional color for 100% -> 50% on players, as well as when your pet is happy."],
								arg = "healthColors.green",
							},
							yellow = {
								order = 2,
								type = "color",
								name = L["Half health"],
								desc = L["Health bar color used as the transitional color for 100% -> 0% on players, as well as when your pet is mildly unhappy."],
								arg = "healthColors.yellow",
							},
							red = {
								order = 3,
								type = "color",
								name = L["Low health"],
								desc = L["Health bar color used as the transitional color for 50% -> 0% on players, as well as when your pet is very unhappy."],
								arg = "healthColors.red",
							},
							friendly = {
								order = 4,
								type = "color",
								name = L["Friendly"],
								desc = L["Health bar color for friendly units."],
								arg = "healthColors.friendly",
							},
							neutral = {
								order = 5,
								type = "color",
								name = L["Neutral"],
								desc = L["Health bar color for neutral units."],
								arg = "healthColors.neutral",
							},
							hostile = {
								order = 6,
								type = "color",
								name = L["Hostile"],
								desc = L["Health bar color for hostile units."],
								arg = "healthColors.hostile",
							},
							inc = {
								order = 7,
								type = "color",
								name = L["Incoming heal"],
								desc = L["Health bar color to use to show how much healing someone is about to receive."],
								arg = "healthColors.inc",
							},
							enemyUnattack = {
								order = 8,
								type = "color",
								name = L["Unattackable hostile"],
								desc = L["Health bar color to use for hostile units who you cannot attack, used for reaction coloring."],
								arg = "healthColors.enemyUnattack",
							},
						},
					},
					classColors = {
						order = 6,
						type = "group",
						inline = true,
						name = L["Class colors"],
						set = setColor,
						get = getColor,
						args = {}
					},
				},
			},
			text = {
				type = "group",
				order = 4,
				name = L["Text management"],
				hidden = hideAdvancedOption,
				args = {
					help = {
						order = 0,
						type = "group",
						inline = true,
						name = L["Help"],
						args = {
							help = {
								order = 0,
								type = "description",
								name = L["You can add additional text with tags enabled using this configuration, note that any additional text added (or removed) effects all units, removing text will resettheir settings as well.\n\nKeep in mind, you cannot delete the default text included with the units."],
							},
						},
					},
					add = {
						order = 1,
						name = L["Add new text"],
						inline = true,
						type = "group",
						set = function(info, value) textData[info[#(info)] ] = value end,
						get = function(info, value) return textData[info[#(info)] ] end,
						args = {
							name = {
								order = 0,
								type = "input",
								name = L["Text name"],
								desc = L["Text name that you can use to identify this text from others when configuring."],
							},
							parent = {
								order = 1,
								type = "select",
								name = L["Text parent"],
								desc = L["Where inside the frame the text should be anchored to."],
								values = {["$healthBar"] = L["Health bar"], ["$powerBar"] = L["Power bar"]},
							},
							add = {
								order = 2,
								type = "execute",
								name = L["Add"],
								disabled = function() return not textData.name or textData.name == "" or not textData.parent end,
								func = function(info)
									-- Verify we entered a good name
									textData.name = string.trim(textData.name)
									textData.name = textData.name ~= "" and textData.name or nil
									
									-- Add the new entry
									for _, unit in pairs(ShadowUF.units) do
										table.insert(ShadowUF.db.profile.units[unit].text, {enabled = true, name = textData.name or "??", text = "", anchorTo = textData.parent, x = 0, y = 0, anchorPoint = "IC", size = 0, width = 0.50})
									end
									
									-- Add it to the GUI
									local id = tostring(#(ShadowUF.db.profile.units.player.text))
									addTextParent.args[id] = addText
									
									local parent = string.sub(textData.parent, 2)
									Config.tagWizard[parent].args[id] = Config.tagTextTable
									Config.tagWizard[parent].args[id .. ":adv"] = Config.advanceTextTable
									
									quickIDMap[id .. ":adv"] = #(ShadowUF.db.profile.units.player.text)
									
									-- Reset
									textData.name = nil
									textData.parent = nil
									
								end,
							},
						},
					},
					delete = {
						order = 2,
						type = "group",
						inline = true,
						name = L["Delete text"],
						args = {},
					},
				},
			},
			profile = LibStub("AceDBOptions-3.0"):GetOptionsTable(ShadowUF.db),
			hide = {
				type = "group",
				order = 4,
				name = L["Hide Blizzard"],
				args = {
					help = {
						order = 0,
						type = "group",
						name = L["Help"],
						inline = true,
						args = {
							description = {
								type = "description",
								name = L["If you hide a frame, you will have to do a /console reloadui for them to show back up again."],
								width = "full",
							},
						},
					},
					hide = {
						order = 1,
						type = "group",
						name = L["Frames"],
						inline = true,
						args = {
							player = Config.hideTable,
							pet = Config.hideTable,
							target = Config.hideTable,
							party = Config.hideTable,
							focus = Config.hideTable,
							targettarget = Config.hideTable,
							buffs = Config.hideTable,
							cast = Config.hideTable,
							runes = Config.hideTable,
						},
					},
				},
			},
		},
	}
	
	-- Load text
	for id, text in pairs(ShadowUF.db.profile.units.player.text) do
		addTextParent.args[tostring(id)] = addText
		options.args.general.args.text.args.delete.args[text.anchorTo] = addTextParent
	end
	
	
	Config.classTable = {
		order = 0,
		type = "color",
		name = getName,
		hasAlpha = true,
		width = "half",
		arg = "classColors.$key",
	}
	
	for classToken in pairs(RAID_CLASS_COLORS) do
		options.args.general.args.general.args.classColors.args[classToken] = Config.classTable
	end
	
	options.args.general.args.general.args.classColors.args.PET = Config.classTable
	options.args.general.args.general.args.classColors.args.VEHICLE = Config.classTable
	
	options.args.general.args.profile.order = 2
end

---------------------
-- UNIT CONFIGURATION
---------------------
local function loadUnitOptions()
	local function getFrameName(unit)
		if( unit == "raid" or unit == "party" ) then
			return string.format("#SUFHeader%s", unit)
		end
		
		return string.format("#SUFUnit%s", unit)
	end

	local anchorList = {}
	local function getAnchorParents(info)
		local unit = info[2]
		for k in pairs(anchorList) do anchorList[k] = nil end
		
		-- Party pet and targets are forced onto their parents
		if( unit == "partypet" or unit == "parttarget" ) then
			anchorList["#SUFHeaderparty"] = L["Party member"]
			return anchorList
		end
		
		anchorList["UIParent"] = L["Screen"]
		
		-- Don't let a frame anchor to a frame thats anchored to it already (Stop infinite loops-o-doom)
		local currentName = getFrameName(unit)
		for _, unitID in pairs(ShadowUF.units) do
			if( unitID ~= unit and ShadowUF.db.profile.positions[unitID] and ShadowUF.db.profile.positions[unitID].anchorTo ~= currentName ) then
				anchorList[getFrameName(unitID)] = string.format(L["%s frames"], L.units[unitID])
			end
		end
		
		return anchorList
	end

	-- This makes sure  we don't end up with any messed up positioning due to two different anchors being used
	local numberList = {}
	local function fixPositions(info)
		local unit = info[2]
		local key = info[#(info)]
		
		if( key == "point" or key == "relativePoint" ) then
			ShadowUF.db.profile.positions[unit].anchorPoint = ""
			ShadowUF.db.profile.positions[unit].anchorTo = ""
		elseif( key == "anchorPoint" ) then
			ShadowUF.db.profile.positions[unit].point = ""
			ShadowUF.db.profile.positions[unit].relativePoint = ""
		end

		-- Reset offset if it was a manually positioned frame, and it got anchored
		if( ( key == "anchorPoint" or key == "anchorTo" ) and ( ShadowUF.db.profile.positions[unit].point ~= "" or ShadowUF.db.profile.positions[unit].relativePoint ~= "" ) ) then
			ShadowUF.db.profile.positions[unit].x = 100
			ShadowUF.db.profile.positions[unit].y = -100
			
			numberList[unit .. "x"] = nil
			numberList[unit .. "y"] = nil
		end
	end
		
	-- Hide raid option in party config
	local function hideRaidOption(info)
		return info[2] == "party"
	end

	-- Not every option should be changed via global settings
	local function hideSpecialOptions(info)
		local unit = info[2]
		if( unit == "global" or unit == "partypet" ) then
			return true
		end
		
		return hideAdvancedOption(info)
	end
	
	local function checkNumber(info, value)
		return tonumber(value)
	end
	
	local function setPosition(info, value)
		ShadowUF.db.profile.positions[info[2]][info[#(info)]] = value
		fixPositions(info)
		
		if( info[2] == "raid" or info[2] == "party" ) then
			ShadowUF.Units:ReloadHeader(info[2])
		else
			ShadowUF.Layout:ReloadAll(info[2])
		end
		
		ShadowUF.modules.movers:Update()
	end
	
	local function getPosition(info)
		return ShadowUF.db.profile.positions[info[2]][info[#(info)]]
	end

	local function setNumber(info, value)
		local unit = info[2]
		local key = info[#(info)]
		local id = unit .. key
		
		numberList[id] = value

		local frame = ShadowUF.Units.unitFrames[unit]
		if( frame ) then
			local anchorTo = ShadowUF.db.profile.positions[unit].anchorTo
			if( anchorTo == "UIParent" ) then
				value = value * frame:GetEffectiveScale()
			end
		end
		
		setPosition(info, tonumber(value))
	end
	
	local function getString(info)
		local id = info[2] .. info[#(info)]
		if( numberList[id] ) then
			return numberList[id]
		end

		return tostring(getPosition(info))
	end
	
	
	-- TAG WIZARD
	local tagWizard = {}
	Config.tagWizard = tagWizard
	do
		-- Load tag list
		local tagTable = {
			order = 0,
			type = "toggle",
			name = getTagName, 
			desc = getTagHelp,
		}
		
		local tagList = {}
		for tag in pairs(ShadowUF.Tags.defaultTags) do
			tagList[tag] = tagTable
		end
			
		for tag, data in pairs(ShadowUF.db.profile.tags) do
			tagList[tag] = tagTable
		end
		
		Config.advanceTextTable = {
			order = 1,
			name = function(info) return getVariable(info[2], "text", quickIDMap[info[#(info)]], "name") or "" end,
			type = "group",
			inline = true,
			hidden = function(info)
				if( not getVariable(info[2], "text", nil, quickIDMap[info[#(info)]]) ) then return true end
				return string.sub(getVariable(info[2], "text", quickIDMap[info[#(info)]], "anchorTo"), 2) ~= info[#(info) - 1]
			end,
			set = function(info, value)
				info.arg = string.format("text.%s.%s", quickIDMap[info[#(info) - 1]], info[#(info)])
				setUnit(info, value)
			end,
			get = function(info)
				info.arg = string.format("text.%s.%s", quickIDMap[info[#(info) - 1]], info[#(info)])
				return getUnit(info)
			end,
			args = {
				anchorPoint = {
					order = 1,
					type = "select",
					name = L["Anchor point"],
					values = {["ITR"] = L["Inside Top Right"], ["ITL"] = L["Inside Top Left"], ["ICL"] = L["Inside Center Left"], ["IC"] = L["Inside Center"], ["ICR"] = L["Inside Center Right"]},
					hidden = hideAdvancedOption,
				},
				sep = {
					order = 2,
					type = "description",
					name = "",
					width = "full",
					hidden = hideAdvancedOption,
				},
				width = {
					order = 3,
					name = L["Width weight"],
					desc = L["How much weight this should use when figuring out the total text width."],
					type = "range",
					min = 0, max = 10, step = 0.1,
					hidden = false,
				},
				size = {
					order = 4,
					name = L["Size"],
					desc = L["Let's you modify the base font size to either make it larger or smaller."],
					type = "range",
					min = -5, max = 5, step = 1,
					hidden = false,
				},
				x = {
					order = 5,
					type = "range",
					name = L["X Offset"],
					min = -100, max = 100, step = 1,
					hidden = false,
				},
				y = {
					order = 6,
					type = "range",
					name = L["Y Offset"],
					min = -100, max = 100, step = 1,
					hidden = false,
				},
			},
		}
		
		local parentTable = {
			order = 0,
			type = "group",
			name = getName,
			args = {}
		}
		
		Config.tagTextTable = {
			type = "group",
			name = function(info) return getVariable(info[2], "text", nil, tonumber(info[#(info)])) and getVariable(info[2], "text", tonumber(info[#(info)]), "name") or "" end,
			hidden = function(info)
				if( not getVariable(info[2], "text", nil, tonumber(info[#(info)])) ) then return true end
				return string.sub(getVariable(info[2], "text", tonumber(info[#(info)]), "anchorTo"), 2) ~= info[#(info) - 1] end,
			set = false,
			get = false,
			args = {
				text = {
					order = 0,
					type = "input",
					name = L["Text"],
					width = "full",
					hidden = false,
					set = function(info, value) setUnit(info, string.gsub(value, "||", "|")) end,
					get = function(info) return string.gsub(getUnit(info), "|", "||") end,
					arg = "text.$parent.text",
				},
				tags = {
					order = 1,
					type = "group",
					inline = true,
					name = L["Tags"],
					hidden = false,
					set = function(info, value)
						local unit = info[2]
						local id = tonumber(info[#(info) - 2])
						local key = info[#(info)]
						local text = getVariable(unit, "text", id, "text")

						if( value ) then
							if( text == "" ) then
								text = string.format("[%s]", key)
							else
								text = string.format("%s [%s]", text, key)
							end
						else
							-- Ugly, but it works
							for matchedTag in string.gmatch(text, "%[(.-)%]") do
								local safeTag = "[" .. matchedTag .. "]"
								if( string.match(safeTag, "%[" .. key .. "%]") or string.match(safeTag, "%)" .. key .. "%]") or string.match(safeTag, "%[" .. key .. "%(") or string.match(safeTag, "%)" .. key .. "%(") ) then
									text = string.gsub(text, "%[" .. string.gsub(string.gsub(matchedTag, "%)", "%%)"), "%(", "%%(") .. "%]", "")
									text = string.gsub(text, "  ", "")
									text = string.trim(text)
									break
								end
							end
						end
						
						if( unit == "global" ) then
							for unit in pairs(modifyUnits) do
								setVariable(unit, "text", id, "text", text)
							end

							setVariable("global", "text", id, "text", text)
						else
							setVariable(unit, "text", id, "text", text)
						end
					end,
					get = function(info) 
						local text = getVariable(info[2], "text", tonumber(info[#(info) - 2]), "text")
						local tag = info[#(info)]
						
						-- FUN WITH PATTERN MATCHING
						if( string.match(text, "%[" .. tag .. "%]") or string.match(text, "%)" .. tag .. "%]") or string.match(text, "%[" .. tag .. "%(") or string.match(text, "%)" .. tag .. "%(") ) then
							return true
						end
						
						return false
					end,
					args = tagList,
				},
			},
		}
		
		local parentList = {}
		for id, text in pairs(ShadowUF.db.profile.units.player.text) do
			parentList[text.anchorTo] = parentList[text.anchorTo] or {}
			parentList[text.anchorTo][id] = text
		end
		
		local nagityNagNagTable = {
			order = 0,
			type = "group",
			name = L["Help"],
			inline = true,
			hidden = hideBasicOption,
			args = {
				help = {
					order = 0,
					type = "description",
					name = L["Select a text widget from the left side panel to set tags, you can use this page to change the truncate width and sizing."],
				},
			},
		}
	
		for parent, list in pairs(parentList) do
			parent = string.sub(parent, 2)
			tagWizard[parent] = parentTable
			parentTable.args.help = nagityNagNagTable
			
			for id in pairs(list) do
				tagWizard[parent].args[tostring(id)] = Config.tagTextTable
				tagWizard[parent].args[tostring(id) .. ":adv"] = Config.advanceTextTable
				
				quickIDMap[tostring(id) .. ":adv"] = id
			end
		end
	end
		
	local function disableSameAnchor(info)
		local anchor = getVariable(info[2], "auras", "buffs", "enabled") and "buffs" or "debuffs"
		
		if( anchor == info[#(info) - 1] or getVariable(info[2], "auras", "buffs", "anchorPoint") ~= getVariable(info[2], "auras", "debuffs", "anchorPoint") ) then return false end
		
		return true
	end
	
	Config.auraTable = {
		type = "group",
		inline = true,
		name = function(info) return info[#(info)] == "buffs" and L["Buffs"] or L["Debuffs"] end,
		order = function(info) return info[#(info)] == "buffs" and 0 or 1 end,
		disabled = function(info) return not getVariable(info[2], "auras", info[#(info) - 1], "enabled") end,
		args = {
			enabled = {
				order = 1,
				type = "toggle",
				name = function(info) if( info[#(info) - 1] == "buffs" ) then return L["Enable buffs"] end return L["Enable debuffs"] end,
				disabled = false,
				arg = "auras.$parent.enabled",
			},
			prioritize = {
				order = 2,
				type = "toggle",
				name = L["Prioritize buffs"],
				desc = L["Show buffs before debuffs when sharing the same anchor point."],
				hidden = function(info) return info[#(info) - 1] == "debuffs" or getVariable(info[2], "auras", "buffs", "anchorPoint") ~= getVariable(info[2], "auras", "debuffs", "anchorPoint") end,
				width = "double",
				arg = "auras.$parent.prioritize",
			},
			curable = {
				order = 3,
				type = "toggle",
				name = L["Show curable only"],
				desc = L["Filter out any aura that you cannot cure."],
				hidden = function(info) return info[#(info) - 1] == "buffs" end,
				width = "double",
				arg = "auras.$parent.curable",
			},
			sep1 = {
				order = 4,
				type = "description",
				name = "",
				width = "full",
			},
			player = {
				order = 5,
				type = "toggle",
				name = L["Show your auras only"],
				desc = L["Filter out any auras that you did not cast yourself."],
				arg = "auras.$parent.player",
			},
			raid = {
				order = 6,
				type = "toggle",
				name = L["Show castable on other auras only"],
				desc = L["Filter out any auras that you cannot cast on another player, or yourself."],
				width = "double",
				arg = "auras.$parent.raid",
			},
			sep2 = {
				order = 7,
				type = "description",
				name = "",
				width = "full",
			},
			enlargeSelf = {
				order = 8,
				type = "toggle",
				name = L["Enlarge your auras"],
				desc = L["If you casted the aura, then the buff icon will be increased in size to make it more visible."],
				arg = "auras.$parent.enlargeSelf",
			},
			selfTimers = {
				order = 9,
				type = "toggle",
				name = L["Timers for self auras only"],
				desc = L["Hides the cooldown ring for any auras that you did not cast."],
				width = "double",
				arg = "auras.$parent.selfTimers",
			},
			sep3 = {
				order = 10,
				type = "description",
				name = "",
				width = "full",
			},
			perRow = {
				order = 10,
				type = "range",
				name = L["Per row"],
				desc = L["How many auras to show in a single row."],
				min = 1, max = 50, step = 1,
				disabled = disableSameAnchor,
				arg = "auras.$parent.perRow",
			},
			maxRows = {
				order = 11,
				type = "range",
				name = function(info)
					local anchorPoint = getVariable(info[2], "auras", info[#(info) - 1], "anchorPoint")
					if( anchorPoint == "LEFT" or anchorPoint == "RIGHT" ) then
						return L["Per column"]
					end
					
					return L["Max rows"]
				end,
				desc = function(info)
					local anchorPoint = getVariable(info[2], "auras", info[#(info) - 1], "anchorPoint")
					if( anchorPoint == "LEFT" or anchorPoint == "RIGHT" ) then
						return L["How many auras per a column for example, entering two her will create two rows that are filled up to whatever per row is set as."]
					end
					
					return L["How many rows total should be used, rows will be however long the per row value is set at."]
				end,
				min = 1, max = 5, step = 1,
				disabled = disableSameAnchor,
				arg = "auras.$parent.maxRows",
			},
			size = {
				order = 12,
				type = "range",
				name = L["Size"],
				min = 1, max = 30, step = 1,
				disabled = disableSameAnchor,
				arg = "auras.$parent.size",
			},
			sep4 = {
				order = 13,
				type = "description",
				name = "",
				width = "full",
			},
			anchorPoint = {
				order = 14,
				type = "select",
				name = L["Position"],
				desc = L["How you want this aura to be anchored to the unit frame."],
				values = {["INSIDE"] = L["Inside"], ["BOTTOM"] = L["Bottom"], ["TOP"] = L["Top"], ["LEFT"] = L["Left"], ["RIGHT"] = L["Right"]},
				arg = "auras.$parent.anchorPoint",
			},
			x = {
				order = 15,
				type = "range",
				name = L["X Offset"],
				min = -100, max = 100, step = 1,
				disabled = disableSameAnchor,
				hidden = hideAdvancedOption,
				arg = "auras.$parent.x",
			},
			y = {
				order = 16,
				type = "range",
				name = L["Y Offset"],
				min = -100, max = 100, step = 1,
				disabled = disableSameAnchor,
				hidden = hideAdvancedOption,
				arg = "auras.$parent.y",
			},
		},
	}
	
	Config.barTable = {
		order = getModuleOrder,
		name = getName,
		type = "group",
		inline = true,
		hidden = hideRestrictedOption,
		args = {
			--[[
			fullSize = {
				order = 1,
				type = "toggle",
				name = L["Full size"],
				desc = L["Ignores the portrait and uses the entire frames width, the bar will be drawn either above or below the portrait depending on the order."],
				hidden = function(info)
					local unit = info[#(info) - 3]
					unit = unit == "global" and masterUnit or unit
					return not ShadowUF.db.profile.units[unit].portrait.enabled
				end,
			},
			]]
			background = {
				order = 2,
				type = "toggle",
				name = L["Show background"],
				desc = L["Show a background behind the bars with the same texture/color but faded out."],
				hidden = hideAdvancedOption,
				arg = "$parent.background",
			},
			--[[
			sep = {
				order = 3,
				type = "description",
				name = "",
				width = "full",
				hidden = function(info)
					local unit = info[#(info) - 3]
					unit = unit == "global" and masterUnit or unit
					if( ShadowUF.db.profile.units[unit].portrait.enabled and ShadowUF.db.profile.advanced ) then
						return false
					end
					
					return true
				end,
			},
			]]
			order = {
				order = 4,
				type = "range",
				name = L["Order"],
				min = 0, max = 100, step = 5,
				hidden = false,
				arg = "$parent.order",
			},
			height = {
				order = 5,
				type = "range",
				name = L["Height"],
				desc = L["How much of the frames total height this bar should get, this is a weighted value, the higher it is the more it gets."],
				min = 0, max = 10, step = 0.1,
				hidden = false,
				arg = "$parent.height",
			},
		},
	}
	
	Config.indicatorTable = {
		order = 0,
		name = getName,
		type = "group",
		inline = true,
		hidden = hideRestrictedOption,
		args = {
			enabled = {
				order = 0,
				type = "toggle",
				name = L["Enable indicator"],
				hidden = false,
				arg = "indicators.$parent.enabled",
			},
			sep1 = {
				order = 1,
				type = "description",
				name = "",
				width = "full",
				hidden = function() return ShadowUF.db.profile.advanced end,
			},
			anchorPoint = {
				order = 2,
				type = "select",
				name = L["Anchor point"],
				values = positionList,
				hidden = false,
				arg = "indicators.$parent.anchorPoint",
			},
			sep2 = {
				order = 3,
				type = "description",
				name = "",
				width = "full",
				hidden = hideAdvancedOption,
			},
			size = {
				order = 4,
				type = "range",
				name = L["Size"],
				min = 0, max = 40, step = 1,
				hidden = hideAdvancedOption,
				arg = "indicators.$parent.size",
			},
			x = {
				order = 5,
				type = "range",
				name = L["X Offset"],
				min = -50, max = 50, step = 1,
				hidden = false,
				arg = "indicators.$parent.x",
			},
			y = {
				order = 6,
				type = "range",
				name = L["Y Offset"],
				min = -50, max = 50, step = 1,
				hidden = false,
				arg = "indicators.$parent.y",
			},
		},
	}
	
	Config.unitTable = {
		type = "group",
		childGroups = "tab",
		order = getUnitOrder,
		name = getName,
		hidden = isUnitDisabled,
		args = {
			general = {
				order = 1,
				name = L["General"],
				type = "group",
				hidden = isModifiersSet,
				set = setUnit,
				get = getUnit,
				args = {
					vehicle = {
						order = 1,
						type = "group",
						inline = true,
						name = L["Vehicles"],
						hidden = function(info) return info[2] ~= "player" end,
						args = {
							disable = {
								order = 0,
								type = "toggle",
								name = L["Disable vehicle swap"],
								desc = L["Disables the unit turning into a vehicle frame when the unit enters a vehicle."],
								set = function(info, value)
									setUnit(info, value)
									local unit = info[2]
									if( unit == "player" ) then
										if( ShadowUF.Units.unitFrames.pet ) then
											ShadowUF.Units.unitFrames.pet:SetAttribute("disableVehicleSwap", ShadowUF.db.profile.units[unit].disableVehicle)
										end
										
										if( ShadowUF.Units.unitFrames.player ) then
											ShadowUF.Units:CheckVehicleStatus(ShadowUF.Units.unitFrames.player)
										end
									elseif( unit == "party" ) then
										for frame in pairs(ShadowUF.Units.unitFrames) do
											if( frame.unitType == "partypet" ) then
												frame:SetAttribute("disableVehicleSwap", ShadowUF.db.profile.units[unit].disableVehicle)
											elseif( frame.unitType == "party" ) then
												ShadowUF.Units:CheckVehicleStatus(frame)
											end
										end
									end
								end,
								arg = "disableVehicle",
							},
						},
					},
					portrait = {
						order = 2,
						type = "group",
						inline = true,
						name = L["Portrait"],
						args = {
							portrait = {
								order = 0,
								type = "toggle",
								name = string.format(L["Enable %s"], L["Portrait"]),
								arg = "portrait.enabled",
							},
							portraitType = {
								order = 1,
								type = "select",
								name = L["Portrait type"],
								values = {["class"] = L["Class icon"], ["2D"] = L["2D"], ["3D"] = L["3D"]},
								arg = "portrait.type",
							},
							alignment = {
								order = 2,
								type = "select",
								name = L["Alignment"],
								values = {["LEFT"] = L["Left"], ["RIGHT"] = L["Right"]},
								arg = "portrait.alignment",
							},
						},
					},
					fader = {
						order = 3,
						type = "group",
						inline = true,
						name = L["Combat fader"],
						hidden = hideRestrictedOption,
						args = {
							fader = {
								order = 0,
								type = "toggle",
								name = string.format(L["Enable %s"], L["Combat fader"]),
								hidden = false,
								arg = "fader.enabled",
							},
							combatAlpha = {
								order = 1,
								type = "range",
								name = L["Combat alpha"],
								desc = L["Alpha to use when you are in combat for this unit."],
								min = 0, max = 1.0, step = 0.1,
								arg = "fader.combatAlpha",
								hidden = false,
								isPercent = true,
							},
							inactiveAlpha = {
								order = 2,
								type = "range",
								name = L["Inactive alpha"],
								desc = L["Alpha to use when the unit is inactive meaning, not in combat, have no target and mana is at 100%."],
								min = 0, max = 1.0, step = 0.1,
								arg = "fader.inactiveAlpha",
								hidden = false,
								isPercent = true,
							},
						}
					},
					range = {
						order = 3,
						type = "group",
						inline = true,
						name = L["Range indicator"],
						hidden = hideRestrictedOption,
						args = {
							fader = {
								order = 0,
								type = "toggle",
								name = string.format(L["Enable %s"], L["Range indicator"]),
								desc = L["Fades out units who you are not in range of, this only works on people who are in your group."],
								arg = "range.enabled",
								hidden = false,
							},
							inAlpha = {
								order = 1,
								type = "range",
								name = L["In range alpha"],
								desc = L["Alpha to use when you are in combat for this unit."],
								min = 0, max = 1.0, step = 0.05,
								arg = "range.inAlpha",
								hidden = false,
								isPercent = true,
							},
							oorAlpha = {
								order = 2,
								type = "range",
								name = L["Out of range alpha"],
								min = 0, max = 1.0, step = 0.05,
								arg = "range.oorAlpha",
								hidden = false,
								isPercent = true,
							},
						}
					},
					combatText = {
						order = 4,
						type = "group",
						inline = true,
						name = L["Combat text"],
						hidden = hideRestrictedOption,
						args = {
							combatText = {
								order = 0,
								type = "toggle",
								name = string.format(L["Enable %s"], L["Combat text"]),
								arg = "combatText.enabled",
								hidden = false,
							},
							sep = {
								order = 1,
								type = "description",
								name = "",
								width = "full",
								hidden = hideAdvancedOption,
							},
							anchorPoint = {
								order = 3,
								type = "select",
								name = L["Anchor point"],
								values = positionList,
								arg = "combatText.anchorPoint",
								hidden = false,
							},
							x = {
								order = 4,
								type = "range",
								name = L["X Offset"],
								min = -50, max = 50, step = 1,
								arg = "combatText.x",
								hidden = hideAdvancedOption,
							},
							y = {
								order = 5,
								type = "range",
								name = L["Y Offset"],
								min = -50, max = 50, step = 1,
								arg = "combatText.y",
								hidden = hideAdvancedOption,
							},
						},
					},
					comboPoints = {
						order = 5,
						type = "group",
						inline = true,
						name = L["Combo points"],
						hidden = function(info) if( info[2] == "global" ) then return true end return hideRestrictedOption(info) end,
						args = {
							enabled = {
								order = 0,
								type = "toggle",
								name = string.format(L["Enable %s"], L["Combo points"]),
								hidden = false,
								arg = "comboPoints.enabled",
							},
							-- Now, technically we can't pass a function to a width, but this works just as well!
							sep1 = {
								order = 1,
								type = "description",
								name = "",
								width = "full",
								hidden = hideAdvancedOption,
							},
							growth = {
								order = 2,
								type = "select",
								name = L["Growth"],
								values = {["UP"] = L["Up"], ["LEFT"] = L["Left"], ["RIGHT"] = L["Right"], ["DOWN"] = L["Down"]},
								hidden = false,
								arg = "comboPoints.growth",
							},
							size = {
								order = 2,
								type = "range",
								name = L["Size"],
								min = 0, max = 20, step = 1,
								hidden = hideAdvancedOption,
								arg = "comboPoints.size",
							},
							spacing = {
								order = 3,
								type = "range",
								name = L["Spacing"],
								min = -10, max = 10, step = 1,
								hidden = hideAdvancedOption,
								arg = "comboPoints.spacing",
							},
							anchorPoint = {
								order = 5,
								type = "select",
								name = L["Anchor point"],
								values = positionList,
								hidden = false,
								arg = "comboPoints.anchorPoint",
							},
							x = {
								order = 6,
								type = "range",
								name = L["X Offset"],
								min = -20, max = 20, step = 1,
								hidden = false,
								arg = "comboPoints.x",
							},
							y = {
								order = 7,
								type = "range",
								name = L["Y Offset"],
								min = -20, max = 20, step = 1,
								hidden = false,
								arg = "comboPoints.y",
							},
						}
					},
				},
			},
			attributes = {
				order = 1.5,
				type = "group",
				name = function(info) return L.units[info[#(info) - 1]] end,
				hidden = function(info) return info[#(info) - 1] ~= "raid" and info[#(info) - 1] ~= "party" end,
				set = function(info, value)
					setUnit(info, value)

					ShadowUF.Units:ReloadHeader(info[2])
					ShadowUF.modules.movers:Update()
				end,
				get = getUnit,
				args = {
					general = {
						order = 0,
						type = "group",
						inline = true,
						name = L["General"],
						hidden = false,
						args = {
							hideSemiRaid = {
								order = 0,
								type = "toggle",
								name = L["Hide in 5-man raid"],
								desc = L["Party frames are hidden while in a raid group with more than 5 people inside."],
								hidden = function(info) return info[2] == "raid" end,
								set = function(info, value)
									if( value ) then
										setVariable(info[2], nil, nil, "hideAnyRaid", false)
									end

									setVariable(info[2], nil, nil, "hideSemiRaid", value)
									ShadowUF.Units:ReloadHeader(info[#(info) - 3])
									ShadowUF:RAID_ROSTER_UPDATE()
								end,
								arg = "hideSemiRaid",
							},
							hideRaid = {
								order = 0.5,
								type = "toggle",
								name = L["Hide in any raid"],
								desc = L["Party frames are hidden while in any sort of raid no matter how many people."],
								hidden = function(info) return info[2] == "raid" end,
								set = function(info, value)
									if( value ) then
										setVariable(info[2], nil, nil, "hideSemiRaid", false)
									end

									setVariable(info[2], nil, nil, "hideAnyRaid", value)
									ShadowUF.Units:ReloadHeader(info[#(info) - 3])
									ShadowUF:RAID_ROSTER_UPDATE()
								end,
								arg = "hideAnyRaid",
							},
							sep = { 
								order = 0.75,
								type = "description",
								name = "",
								width = "full",
								hidden = function(info) return info[2] == "raid" end,
							},
							xOffset = {
								order = 1,
								type = "range",
								name = L["Row offset"],
								desc = L["Spacing between each row"],
								min = -50, max = 50, step = 1,
								hidden = function(info)
									local point = getVariable(info[2], nil, nil, "attribPoint")
									return point ~= "LEFT" and point ~= "RIGHT"
								end,
								arg = "xOffset",
							},
							yOffset = {
								order = 2,
								type = "range",
								name = L["Row offset"],
								desc = L["Spacing between each row"],
								min = -50, max = 50, step = 1,
								hidden = function(info)
									local point = getVariable(info[2], nil, nil, "attribPoint")
									return point ~= "TOP" and point ~= "BOTTOM"
								end,
								arg = "yOffset",
							},
							attribPoint = {
								order = 3,
								type = "select",
								name = L["Frame growth"],
								desc = L["How the frame should grow when new group members are added."],
								values = {["TOP"] = L["Down"], ["LEFT"] = L["Right"], ["BOTTOM"] = L["Up"], ["RIGHT"] = L["Left"]},
								arg = "attribPoint",
							},
							attribAnchorPoint = {
								order = 4,
								type = "select",
								name = L["Column growth"],
								desc = L["How the columns should grow when too many people are shown in a single group."],
								values = {["TOP"] = L["Up"], ["LEFT"] = L["Left"], ["RIGHT"] = L["Right"], ["BOTTOM"] = L["Down"]},
								hidden = hideRaidOption,
								arg = "attribAnchorPoint",
							},
						},
					},
					raid = {
						order = 1,
						type = "group",
						inline = true,
						name = L["Groups"],
						hidden = hideRaidOption,
						args = {
							groupBy = {
								order = 1,
								type = "select",
								name = L["Group by"],
								values = {["GROUP"] = L["Group number"], ["CLASS"] = L["Class"]},
								arg = "groupBy",
							},
							sortOrder = {
								order = 2,
								type = "select",
								name = L["Sort order"],
								values = {["ASC"] = L["Ascending"], ["DESC"] = L["Descending"]},
								arg = "sortOrder",
							},
							sep = {
								order = 3,
								type = "description",
								name = "",
								width = "full",
							},
							maxColumns = {
								order = 4,
								type = "range",
								name = L["Max columns"],
								min = 1, max = 20, step = 1,
								arg = "maxColumns",
							},
							unitsPerColumn = {
								order = 5,
								type = "range",
								name = L["Units per column"],
								min = 1, max = 40, step = 1,
								arg = "unitsPerColumn",
							},
							columnSpacing = {
								order = 6,
								type = "range",
								name = L["Column spacing"],
								min = -100, max = 100, step = 1,
								arg = "columnSpacing",
							},
							selectedGroups = {
								order = 7,
								type = "multiselect",
								name = L["Raid groups to show"],
								values = {string.format(L["Group %d"], 1), string.format(L["Group %d"], 2), string.format(L["Group %d"], 3), string.format(L["Group %d"], 4), string.format(L["Group %d"], 5), string.format(L["Group %d"], 6), string.format(L["Group %d"], 7), string.format(L["Group %d"], 8)},
								set = function(info, key, value)
									local tbl = getVariable(info[2], nil, nil, "filters")
									tbl[key] = value
									
									setVariable(info[2], "filters", nil, tbl)
									ShadowUF.Units:ReloadHeader("raid")
									ShadowUF.modules.movers:Update()
								end,
								get = function(info, key)
									local tbl = getVariable(info[2], nil, nil, "filters")
									return tbl[key]
								end,
							},
						},
					},
				},
			},
			frame = {
				order = 2,
				name = L["Frame"],
				type = "group",
				hidden = isModifiersSet,
				set = setUnit,
				get = getUnit,
				args = {
					size = {
						order = 0,
						type = "group",
						inline = true,
						name = L["Size"],
						set = function(info, value)
							setUnit(info, value)
							ShadowUF.modules.movers:Update()
						end,
						args = {
							scale = {
								order = 0,
								type = "range",
								name = L["Scale"],
								min = 0.50, max = 1.50, step = 0.01,
								isPercent = true,
								arg = "scale",
							},
							height = {
								order = 1,
								type = "range",
								name = L["Height"],
								min = 0, max = 100, step = 1,
								arg = "height",
							},
							width = {
								order = 2,
								type = "range",
								name = L["Width"],
								min = 0, max = 300, step = 1,
								arg = "width",
							},
						},
					},
					anchor = {
						order = 1,
						type = "group",
						inline = true,
						hidden = function(info) return info[2] == "global" end,
						name = L["Anchor to another frame"],
						set = setPosition,
						get = getPosition,
						args = {
							help = {
								order = 0,
								type = "group",
								name = L["Help"],
								hidden = function(info)
									local position = ShadowUF.db.profile.positions[info[2]]
									return not position or position.anchorTo ~= "UIParent"
								end,
								args = {
									desc = {
										order = 0,
										type = "description",
										name = L["Offsets are saved using effective scaling, this is to prevent the frame from jumping around when you reload or login."],
										hidden = false,
										width = "full",
									}
								},
							},
							anchorPoint = {
								order = 0.50,
								type = "select",
								name = L["Anchor point"],
								values = positionList,
							},
							anchorTo = {
								order = 1,
								type = "select",
								name = L["Anchor to"],
								values = getAnchorParents,
							},
							sep = {
								order = 2,
								type = "description",
								name = "",
								width = "full",
							},
							x = {
								order = 3,
								type = "input",
								name = L["X Offset"],
								validate = checkNumber,
								set = setNumber,
								get = getString,
							},
							y = {
								order = 4,
								type = "input",
								name = L["Y Offset"],
								validate = checkNumber,
								set = setNumber,
								get = getString,
							},
						},
					},
					orHeader = {
						order = 1.5,
						type = "header",
						name = L["Or you can set a position manually"],
						hidden = function(info) if( info[2] == "global" or hideAdvancedOption() ) then return true else return false end end,
					},
					position = {
						order = 2,
						type = "group",
						hidden = function(info) if( info[2] == "global" or hideAdvancedOption() ) then return true else return false end end,
						inline = true,
						name = L["Manual position"],
						set = setPosition,
						get = getPosition,
						args = {
							point = {
								order = 0,
								type = "select",
								name = L["Point"],
								values = pointPositions,
							},
							anchorTo = {
								order = 0.50,
								type = "select",
								name = L["Anchor to"],
								values = getAnchorParents,
							},
							relativePoint = {
								order = 1,
								type = "select",
								name = L["Relative point"],
								values = pointPositions,
							},
							sep = {
								order = 2,
								type = "description",
								name = "",
								width = "full",
							},
							x = {
								order = 3,
								type = "input",
								name = L["X Offset"],
								validate = checkNumber,
								set = setNumber,
								get = getString,
							},
							y = {
								order = 4,
								type = "input",
								name = L["Y Offset"],
								validate = checkNumber,
								set = setNumber,
								get = getString,
							},
						},
					},
				},
			},
			bars = {
				order = 3,
				name = L["Bars"],
				type = "group",
				hidden = isModifiersSet,
				set = setUnit,
				get = getUnit,
				args = {
					healthBar = {
						order = 1,
						type = "group",
						inline = true,
						name = L["Health bar"],
						args = {
							enabled = {
								order = 1,
								type = "toggle",
								name = string.format(L["Enable %s"], L["Health bar"]),
								arg = "healthBar.enabled",
							},
							incHeal = {
								order = 2,
								type = "toggle",
								name = string.format(L["Enable %s"], L["Incoming heals"]),
								arg = "incHeal.enabled",
								hidden = hideRestrictedOption,
							},
							predictedHealth = {
								order = 3,
								type = "toggle",
								name = L["Enable quick health"],
								desc = L["This will enable fast updating of the health bar, giving you more slightly faster health bar information than you normally would get."],
								arg = "healthBar.predicted",
							},
							sep = {
								order = 4,
								type = "description",
								name = "",
								width = "full",
								--hidden = function(info) return not string.match(info[2], "%w+target") end,
							},
							healthColor = {
								order = 5,
								type = "select",
								name = L["Color health by"],
								values = {["class"] = L["Class"], ["static"] = L["Static"], ["percent"] = L["Health percent"]},
								arg = "healthBar.colorType",
							},
							colorAggro = {
								order = 6,
								type = "toggle",
								name = L["Color on aggro"],
								arg = "healthBar.colorAggro",
							},
							reaction = {
								order = 7,
								type = "toggle",
								name = L["Color by reaction"],
								desc = L["If the unit is hostile, the reaction color will override any color health by options."],
								arg = "healthBar.reaction",
								hidden = function(info) return info[2] == "player" or info[2] == "pet" end,
							},
						},
					},
					bar = {
						order = 2,
						type = "group",
						inline = true,
						name = L["General"],
						args = {
							powerBar = {
								order = 1,
								type = "toggle",
								name = string.format(L["Enable %s"], L["Power bar"]),
								arg = "powerBar.enabled",
							},
							predictPower = {
								order = 2,
								type = "toggle",
								name = L["Enable quick power"],
								desc = L["This will enable fast updating of the power bar, giving you more slightly faster power information than you normally would get."],
								arg = "powerBar.predicted",
							},
							sep = {
								order = 3,
								type = "description",
								name = "",
								hidden = function(info)
									local unit = info[2]
									if( unit == "player" and ( select(2, UnitClass("player")) == "SHAMAN" or select(2, UnitClass("player")) == "DEATHKNIGHT" ) ) then
										return false
									end
									
									return true
								end,
								width = "full",
							},
							xpBar = {
								order = 4,
								type = "toggle",
								name = string.format(L["Enable %s"], L["XP/Rep bar"]),
								desc = L["This bar will automatically hide when you are at the level cap, or you do not have any reputations tracked."],
								hidden = hideRestrictedOption,
								arg = "xpBar.enabled",
							},
							runeBar = {
								order = 5,
								type = "toggle",
								name = string.format(L["Enable %s"], L["Rune bar"]),
								hidden = hideRestrictedOption,
								arg = "runeBar.enabled",
							},
							totemBar = {
								order = 6,
								type = "toggle",
								name = string.format(L["Enable %s"], L["Totem bar"]),
								hidden = hideRestrictedOption,
								arg = "totemBar.enabled",
							},
						},
					},
					castBar = {
						order = 4,
						type = "group",
						inline = true,
						name = L["Cast bar"],
						hidden = hideRestrictedOption,
						args = {
							enabled = {
								order = 0,
								type = "toggle",
								name = string.format(L["Enable %s"], L["Cast bar"]),
								arg = "castBar.enabled",
							},
							castIcon = {
								order = 0.25,
								type = "toggle",
								name = L["Show cast icon"],
								arg = "castBar.showIcon",
								hidden = true,
							},
							castName = {
								order = 0.50,
								type = "header",
								name = L["Cast name"],
								hidden = hideAdvancedOption,
							},
							nameEnabled = {
								order = 0.75,
								type = "toggle",
								name = L["Show cast name"],
								arg = "castBar.castName.enabled",
								hidden = hideAdvancedOption,
								width = "full",
							},
							nameAnchor = {
								order = 1,
								type = "select",
								name = L["Anchor point"],
								desc = L["Where to anchor the cast name text."],
								values = {["ICL"] = L["Inside Center Left"], ["ICR"] = L["Inside Center Right"]},
								set = setCast,
								get = getCast,
								hidden = hideAdvancedOption,
								arg = "castBar.castName.anchorPoint",
							},
							nameX = {
								order = 2,
								type = "range",
								name = L["X Offset"],
								min = -20, max = 20, step = 1,
								set = setCast,
								get = getCast,
								hidden = hideAdvancedOption,
								arg = "castBar.castName.x",
							},
							nameY = {
								order = 3,
								type = "range",
								name = L["Y Offset"],
								min = -20, max = 20, step = 1,
								set = setCast,
								get = getCast,
								hidden = hideAdvancedOption,
								arg = "castBar.castName.y",
							},
							castTime = {
								order = 4,
								type = "header",
								name = L["Cast time"],
								hidden = hideAdvancedOption,
							},
							castEnabled = {
								order = 4.50,
								type = "toggle",
								name = L["Show cast time"],
								arg = "castBar.castTime.enabled",
								hidden = hideAdvancedOption,
								width = "full",
							},
							timeAnchor = {
								order = 5,
								type = "select",
								name = L["Anchor point"],
								desc = L["Where to anchor the cast time text."],
								values = {["ICL"] = L["Inside Center Left"], ["ICR"] = L["Inside Center Right"]},
								set = setCast,
								get = getCast,
								hidden = hideAdvancedOption,
								arg = "castBar.castTime.anchorPoint",
							},
							timeX = {
								order = 6,
								type = "range",
								name = L["X Offset"],
								min = -20, max = 20, step = 1,
								set = setCast,
								get = getCast,
								hidden = hideAdvancedOption,
								arg = "castBar.castTime.x",
							},
							timeY = {
								order = 7,
								type = "range",
								name = L["Y Offset"],
								min = -20, max = 20, step = 1,
								set = setCast,
								get = getCast,
								hidden = hideAdvancedOption,
								arg = "castBar.castTime.y",
							},
						},
					},
				},
			},
			widgetSize = {
				order = 4,
				name = L["Widget size"],
				type = "group",
				hidden = isModifiersSet,
				set = setUnit,
				get = getUnit,
				args = {
					portrait = {
						order = 0,
						type = "group",
						name = L["Portrait"],
						inline = true,
						args = {
							--[[
							order = {
								order = 0,
								type = "range",
								name = L["Order"],
								desc = L["Order to use for the portrait, this only applies if you have a full sized bar."],
								min = 0, max = 100, step = 5,
								arg = "portrait.order",
							},
							]]
							width = {
								order = 1,
								type = "range",
								name = L["Width percent"],
								desc = L["Percentage of width the portrait should use."],
								min = 0, max = 1.0, step = 0.01,
								isPercent = true,
								arg = "portrait.width",
							},
						},
					},
				},
			},
			auras = {
				order = 5,
				name = L["Auras"],
				type = "group",
				hidden = isModifiersSet,
				set = setUnit,
				get = getUnit,
				args = {
					buffs = Config.auraTable,
					debuffs = Config.auraTable,
				},
			},
			indicators = {
				order = 5.5,
				type = "group",
				name = L["Indicators"],
				hidden = isModifiersSet,
				set = setUnit,
				get = getUnit,
				args = {
					status = Config.indicatorTable,
					pvp = Config.indicatorTable,
					leader = Config.indicatorTable,
					masterLoot = Config.indicatorTable,
					raidTarget = Config.indicatorTable,
					happiness = Config.indicatorTable,
					ready = Config.indicatorTable,
				},
			},
			tag = {
				order = 7,
				name = L["Text"],
				type = "group",
				hidden = isModifiersSet,
				childGroups = "tree",
				args = tagWizard,
			},
		},
	}
	
	options.args.units = {
		type = "group",
		name = L["Units"],
		args = {
			enabled = {
				order = 0,
				type = "group",
				inline = true,
				name = L["Enable units"],
				args = {},
			},
			help = {
				order = 1,
				type = "group",
				inline = true,
				name = L["Help"],
				args = {
					help = {
						order = 0,
						type = "description",
						name = L["In this category you can configure all of the enabled units, both what features to enable as well as tweaking the layout. Advanced settings in the general category if you want to be able to get finer control on setting options, but it's not recommended for most people.\n\nHere's what each tab does\n\nGeneral - General settings, portrait settings, combat text, anything that doesn't fit the other categories.\n\nFrame - Frame settings, scale, height, width. You can set the frame to be anchored to another here.\n\nBars - Enabling bars (health/cast/etc) as well as setting how the health bar can be colored.\n\nWidget size - Widget sizing, ordering, height.\n\nAuras - What filters to use, where to place auras.\n\nText - Quickly add and remove tags to text, when advanced settings are enabled you can also change the width and positioning of text."],
					},
				},
			},
			global = {
				type = "group",
				childGroups = "tab",
				order = 0,
				name = L["Global"],
				args = {
					units = {
						order = 0,
						type = "group",
						name = L["Units"],
						set = function(info, value)
							local unit = info[#(info)]
							if( IsShiftKeyDown() ) then
								for _, unit in pairs(ShadowUF.units) do
									if( ShadowUF.db.profile.units[unit].enabled ) then
										modifyUnits[unit] = value and true or nil
										
										if( value ) then
											globalConfig = mergeTables(globalConfig, ShadowUF.db.profile.units[unit])
										end
									end
								end
							else
								modifyUnits[unit] = value and true or nil

								if( value ) then
									globalConfig = mergeTables(globalConfig, ShadowUF.db.profile.units[unit])
								end
							end
							
							-- Check if we have nothing else selected, if so wipe it
							local hasUnit
							for k in pairs(modifyUnits) do hasUnit = true break end
							if( not hasUnit ) then
								globalConfig = {}
							end
							
							AceRegistry:NotifyChange("ShadowedUF")
						end,
						get = function(info) return modifyUnits[info[#(info)]] end,
						args = {
							help = {
								order = 0,
								type = "group",
								name = L["Help"],
								inline = true,
								args = {
									help = {
										order = 0,
										type = "description",
										name = L["Select the units that you want to modify, any settings changed will change every unit you selected. If you want to anchor or change raid/party unit specific settings you will need to do that through their options.\n\nShift click a unit to select all/unselect all."],
									},
								},
							},
							units = {
								order = 1,
								type = "group",
								name = L["Units"],
								inline = true,
								args = {},
							},
						},
					},
				},
			},
		},
	}
	
	-- Load modules into the unit table
	for key, module in pairs(ShadowUF.modules) do
		if( module.moduleHasBar ) then
			Config.unitTable.args.widgetSize.args[key] = Config.barTable
		end
	end

	-- Load global unit
	for k, v in pairs(Config.unitTable.args) do
		options.args.units.args.global.args[k] = v
	end

	-- Load all of the per unit settings
	local perUnitList = {
		order = getUnitOrder,
		type = "toggle",
		name = getName,
		hidden = isUnitDisabled,
		desc = function(info)
			return string.format(L["Adds %s to the list of units to be modified when you change values in this tab."], L.units[info[#(info)]])
		end,
	}
	
	-- Enabled units list
	local enabledUnits = {
		order = getUnitOrder,
		type = "toggle",
		name = getName,
		set = function(info, value)
			ShadowUF.db.profile.units[info[#(info)]].enabled = value
			ShadowUF:LoadUnits()
			ShadowUF.modules.movers:Update()
		end,
		get = function(info)
			return ShadowUF.db.profile.units[info[#(info)]].enabled
		end,
	}

	for order, unit in pairs(ShadowUF.units) do
		options.args.units.args.enabled.args[unit] = enabledUnits
		options.args.units.args.global.args.units.args.units.args[unit] = perUnitList
		options.args.units.args[unit] = Config.unitTable
	end
end

---------------------
-- TAG CONFIGURATION
---------------------
local function loadTagOptions()
	local tagData = {search = ""}
	local function set(info, value)
		local key = info[#(info)]
		if( ShadowUF.Tags.defaultHelp[tagData.name] ) then
			return
		end
		
		-- Reset loaded function + reload tags
		if( key == "funct" ) then
			ShadowUF.tagFunc[tagData.name] = nil
			ShadowUF.Tags:Reload()
		end

		ShadowUF.db.profile.tags[tagData.name][key] = value
	end
	
	local function stripCode(text)
		if( not text ) then
			return ""
		end
		
		return string.gsub(string.gsub(text, "|", "||"), "\t", "")
	end
	
	local function get(info)
		local key = info[#(info)]
		
		if( key == "help" and ShadowUF.Tags.defaultHelp[tagData.name] ) then
			return ShadowUF.Tags.defaultHelp[tagData.name] or ""
		elseif( key == "events" and ShadowUF.Tags.defaultEvents[tagData.name] ) then
			return ShadowUF.Tags.defaultEvents[tagData.name] or ""
		elseif( key == "funct" and ShadowUF.Tags.defaultTags[tagData.name] ) then
			return ShadowUF.Tags.defaultTags[tagData.name] or ""
		end
				
		return ShadowUF.db.profile.tags[tagData.name] and ShadowUF.db.profile.tags[tagData.name][key] or ""
	end
		
	local function isSearchHidden(info)
		return tagData.search ~= "" and not string.match(info[#(info)], tagData.search) or false
	end
	
	local function editTag(info)
		tagData.name = info[#(info)]
		
		if( ShadowUF.Tags.defaultHelp[tagData.name] ) then
			tagData.error = L["You cannot edit this tag because it is one of the default ones included in this mod. This function is here to provide an example for your own custom tags."]
		end
		
		selectDialogGroup("tags", "edit")
	end
				
	-- Create all of the tag editor options, if it's a default tag will show it after any custom ones
	local tagTable = {
		type = "execute",
		order = function(info) return ShadowUF.Tags.defaultTags[info[#(info)]] and 100 or 1 end,
		name = function(info) return info[#(info)] end,
		desc = getTagHelp,
		hidden = isSearchHidden,
		func = editTag,
	}

	-- Tag configuration
	options.args.tags = {
		type = "group",
		childGroups = "tab",
		name = L["Tags"],
		args = {
			general = {
				order = 0,
				type = "group",
				name = L["Tag list"],
				args = {
					search = {
						order = 0,
						type = "group",
						inline = true,
						name = L["Search"],
						args = {
							search = {
								order = 1,
								type = "input",
								name = L["Search tags"],
								set = function(info, text) tagData.search = text end,
								get = function(info) return tagData.search end,
							},
						},
					},
					list = {
						order = 1,
						type = "group",
						inline = true,
						name = L["Tags"],
						args = {},
					},
				},
			},
			add = {
				order = 1,
				type = "group",
				name = L["Add new tag"],
				args = {
					help = {
						order = 0,
						type = "group",
						inline = true,
						name = L["Help"],
						args = {
							help = {
								order = 0,
								type = "description",
								name = L["You can find more information on creating your own custom tags in the \"Help\" tab above."],
							},
						},
					},
					add = {
						order = 1,
						type = "group",
						inline = true,
						name = L["Add new tag"],
						args = {
							error = {
								order = 0,
								type = "description",
								name = function() return tagData.addError or "" end,
								hidden = function() return not tagData.addError end,
							},
							errorHeader = {
								order = 0.50,
								type = "header",
								name = "",
								hidden = function() return not tagData.addError end,
							},
							tag = {
								order = 1,
								type = "input",
								name = L["Tag name"],
								desc = L["Tag that you will use to access this code, do not wrap it in brackets or parenthesis it's automatically done. For example, you would enter \"foobar\" and then access it with [foobar]."],
								validate = function(info, text)
									if( text == "" ) then
										tagData.addError = L["You must enter a tag name."]
									elseif( string.match(text, "[%[%]%(%)]") ) then
										tagData.addError = string.format(L["You cannot name a tag \"%s\", tag names should contain no brackets or parenthesis."], text)
									elseif( ShadowUF.tagFunc[text] ) then
										tagData.addError = string.format(L["The tag \"%s\" already exists."], text)
									else
										tagData.addError = nil
									end
									
									AceRegistry:NotifyChange("ShadowedUF")
									return tagData.addError and "" or true
								end,
								set = function(info, text)
									tagData.name = text
									tagData.error = nil
									tagData.addError = nil
									
									ShadowUF.db.profile.tags[text] = {func = "function(unit, unitOwner)\n\nend"}
									options.args.tags.args.general.args.list.args[text] = tagTable
									
									selectDialogGroup("tags", "edit")
								end,
							},
						},
					},
				},
			},
			edit = {
				order = 2,
				type = "group",
				name = L["Edit tag"],
				hidden = function() return not tagData.name end,
				args = {
					help = {
						order = 0,
						type = "group",
						inline = true,
						name = L["Help"],
						args = {
							help = {
								order = 0,
								type = "description",
								name = L["You can find more information on creating your own custom tags in the \"Help\" tab above.\nSUF will attempt to automatically detect what events your tag will need, so you do not generally need to fill out the events field."],
							},
						},
					},
					tag = {
						order = 1,
						type = "group",
						inline = true,
						name = function() return string.format(L["Editing %s"], tagData.name or "") end,
						args = {
							error = {
								order = 0,
								type = "description",
								name = function() return tagData.error or "" end,
								hidden = function() return not tagData.error end,
							},
							errorHeader = {
								order = 1,
								type = "header",
								name = "",
								hidden = function() return not tagData.error end,
							},
							discovery = {
								order = 1,
								type = "toggle",
								name = L["Disable event discovery"],
								desc = L["This will disable the automatic detection of what events this tag will need, you should leave this unchecked unless you know what you are doing."],
								set = function(info, value) tagData.discovery = value end,
								get = function() return tagData.discovery end,
								width = "full",
							},
							events = {
								order = 3,
								type = "input",
								name = L["Events"],
								desc = L["Events that should be used to trigger an update of this tag. Separate each event with a single space."],
								width = "full",
								validate = function(info, text)
									if( ShadowUF.Tags.defaultTags[tagData.name] ) then
										return true
									end

									if( text == "" or string.match(text, "[^_%a%s]") ) then
										tagData.error = L["You have to set the events to fire, you can only enter letters and underscores, \"FOO_BAR\" for example is valid, \"APPLE_5_ORANGE\" is not because it contains a number."]
										tagData.eventError = text
										AceRegistry:NotifyChange("ShadowedUF")
										return ""
									end
									
									tagData.eventError = text
									tagData.error = nil
									return true			
								end,
								set = set,
								get = function(info)
									if( tagData.eventError ) then
										return tagData.eventError
									end
									
									return get(info)
								end,
							},
							func = {
								order = 4,
								type = "input",
								multiline = true,
								name = L["Code"],
								desc = L["Your code must be wrapped in a function, for example, if you were to make a tag to return the units name you would do:\n\nfunction(unit)\nreturn UnitName(unit)\nend"],
								width = "full",
								validate = function(info, text)
									if( ShadowUF.Tags.defaultTags[tagData.name] ) then
										return true
									end
									
									local funct, msg = loadstring("return " .. text)
									if( not string.match(text, "function") ) then
										tagData.error = L["You must wrap your code in a function."]
										tagData.funcError = text
									elseif( not funct and msg ) then
										tagData.error = string.format(L["Failed to save tag, error:\n %s"], msg)
										tagData.funcError = text
									else
										tagData.error = nil
										tagData.funcError = nil
									end
									
									AceRegistry:NotifyChange("ShadowedUF")
									return tagData.error and "" or true
								end,
								set = function(info, value)
									value = string.gsub(value, "||", "|")
									set(info, value)
									
									-- Try and automatically identify the events this tag is going to want to use
									if( not tagData.discovery ) then
										tagData.eventError = nil
										ShadowUF.db.profile.tags[tagData.name].events = ShadowUF.Tags:IdentifyEvents(value) or ""
									end
									
									ShadowUF.Tags:Reload(tagData.name)
								end,
								get = function(info)
									if( tagData.funcError ) then
										return stripCode(tagData.funcError)
									end
									
									return stripCode(get(info))
								end,
							},
							delete = {
								order = 5,
								type = "execute",
								name = L["Delete"],
								disabled = function() return ShadowUF.Tags.defaultTags[tagData.name] end,
								confirm = true,
								confirmText = L["Are you really sure you want to delete this tag?"],
								func = function(info)
									ShadowUF.db.profile.tags[tagData.name] = nil
									ShadowUF.tagFunc[tagData.name] = nil
									ShadowUF.Tags:Reload(tagData.name)

									options.args.tags.args.general.args.list.args[tagData.name] = nil
									tagData.name = nil
									tagData.error = nil

									
									selectDialogGroup("tags", "general")
								end,
							},
						},
					},
				},
			},
			help = {
				order = 3,
				type = "group",
				name = L["Help"],
				args = {
					general = {
						order = 0,
						type = "group",
						name = L["General"],
						inline = true,
						args = {
							general = {
								order = 0,
								type = "description",
								name = L["See the documentation below for information and examples on creating tags, if you just want basic Lua or WoW API information than see the Programming in Lua and WoW Programming links."],
							},
						},
					},
					documentation = {
						order = 1,
						type = "group",
						name = L["Documentation"],
						inline = true,
						args = {
							doc = {
								order = 0,
								type = "input",
								name = L["Documentation"],
								set = false,
								get = function() return "http://wiki.github.com/Shadowed/ShadowedUnitFrames/tag-documentation" end,
								width = "full",
							},
						},
					},
					resources = {
						order = 2,
						type = "group",
						inline = true,
						name = L["Resources"],
						args = {
							lua = {
								order = 0,
								type = "input",
								name = L["Programming in Lua"],
								desc = L["This is a good guide on how to get started with programming in Lua, while you do not need to read the entire thing it is a helpful for understanding the basics of Lua syntax and API's."],
								set = false,
								get = function() return "http://www.lua.org/pil/" end,
								width = "full",
							},
							wow = {
								order = 1,
								type = "input",
								name = L["WoW Programming"],
								desc = L["WoW Programming is a good resource for finding out what difference API's do and how to call them."],
								set = false,
								get = function() return "http://wowprogramming.com/docs" end,
								width = "full",
							},
						},
					},
				},
			},
		},
	}
	
	-- Load the initial tag list
	for tag in pairs(ShadowUF.Tags.defaultTags) do
		options.args.tags.args.general.args.list.args[tag] = tagTable
	end
	
	for tag, data in pairs(ShadowUF.db.profile.tags) do
		options.args.tags.args.general.args.list.args[tag] = tagTable
	end
end

---------------------
-- VISIBILITY OPTIONS
---------------------
local function loadVisibilityOptions()
	local function set(info, value)
		local key = info[#(info)]
		local unit = info[#(info) - 1]
		local area = info[#(info) - 2]
		
		if( key == "enabled" ) then
			key = ""
		end
		
		if( value == nil ) then
			value = false
		elseif( value == false ) then
			value = nil
		end
		
		ShadowUF.db.profile.visibility[area][unit .. key] = value
		if( key == "" ) then
			ShadowUF:LoadUnits()
		else
			ShadowUF.Units:ReloadHeader(unit)
		end
	end
	
	local function get(info)
		local key = info[#(info)]
		local unit = info[#(info) - 1]
		local area = info[#(info) - 2]

		if( key == "enabled" ) then
			key = ""
		end
		
		if( ShadowUF.db.profile.visibility[area][unit .. key] == false ) then
			return nil
		elseif( ShadowUF.db.profile.visibility[area][unit .. key] == nil ) then
			return false
		end
		
		return ShadowUF.db.profile.visibility[area][unit .. key]
	end
	
	local function getHelp(info)
		local unit = info[#(info) - 1]
		local area  = info[#(info) - 2]
		local key = info[#(info)]
		if( key == "enabled" ) then
			key = ""
		end
		
		local current = ShadowUF.db.profile.visibility[area][unit .. key]
		if( current == false ) then
			return string.format(L["Disabled in %s"], L.areas[area])
		elseif( current == true ) then
			return string.format(L["Enabled in %s"], L.areas[area])
		end

		return L["Using unit settings"]
	end
	
	local areaTable = {
		type = "group",
		order = 1,
		childGroups = "tree",
		name = function(info)
			return L.areas[info[#(info)]]
		end,
		get = get,
		set = set,
		args = {},
	}
	
	Config.visibilityTable = {
		type = "group",
		order = getUnitOrder,
		name = getName,
		args = {
			enabled = {
				order = 0,
				type = "toggle",
				name = function(info) return string.format(L["Enable %s frames"], L.units[info[#(info) - 1]]) end,
				desc = getHelp,
				tristate = true,
				hidden = false,
				width = "double",
			},
			sep = {
				order = 0.5,
				type = "description",
				name = "",
				width = "full",
				hidden = false,
			},
		}
	}
	
	local moduleTable = {
		order = getModuleOrder,
		type = "toggle",
		name = getName,
		desc = getHelp,
		tristate = true,
		hidden = hideRestrictedOption,
		arg = 1,
	}
		
	for key, module in pairs(ShadowUF.modules) do
		if( module.moduleName ) then
			Config.visibilityTable.args[key] = moduleTable
		end
	end
	
	for _, unit in pairs(ShadowUF.units) do
		areaTable.args[unit] = Config.visibilityTable
	end
	
	options.args.visibility = {
		type = "group",
		childGroups = "tab",
		name = L["Visibility"],
		args = {
			start = {
				order = 0,
				type = "group",
				name = L["Help"],
				inline = true,
				args = {
					help = {
						order = 0,
						type = "description",
						name = L["You can set different units to be enabled or disabled in different areas here.\nGold checked are enabled, Gray checked are disabled, Unchecked are ignored and use the current set value no matter the zone."],
					},
				},
			},
			pvp = areaTable,
			arena = areaTable,
			party = areaTable,
			raid = areaTable,
		},
	}
end

local function loadOptions()
	options = {
		type = "group",
		name = "Shadowed UF",
		args = {}
	}
	
	loadData()
	loadGeneralOptions()
	loadUnitOptions()
	loadTagOptions()
	loadVisibilityOptions()	
	
	-- Ordering
	options.args.general.order = 0
	options.args.units.order = 1
	options.args.visibility.order = 2
	options.args.tags.order = 3
	
	-- So modules can access it easier/debug
	Config.options = options
	
	-- Options finished loading, fire callback for any non-default modules that want to be included
	ShadowUF:FireModuleEvent("OnConfigurationLoad")
end

SLASH_SSUF1 = "/suf"
SLASH_SSUF2 = "/shadowuf"
SLASH_SSUF3 = "/shadoweduf"
SLASH_SSUF4 = "/shadowedunitframes"
SlashCmdList["SSUF"] = function(msg)
	AceDialog = AceDialog or LibStub("AceConfigDialog-3.0")
	AceRegistry = AceRegistry or LibStub("AceConfigRegistry-3.0")
	
	if( not registered ) then
		loadOptions()
		
		LibStub("AceConfig-3.0"):RegisterOptionsTable("ShadowedUF", options)
		AceDialog:SetDefaultSize("ShadowedUF", 835, 525)
		registered = true
	end

	AceDialog:Open("ShadowedUF")
end