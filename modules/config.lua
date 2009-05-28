local Config = {}
local AceDialog, AceRegistry, AceGUI, SML, registered, options
local modifyUnits = {}
local L = ShadowUFLocals

ShadowUF.Config = Config

--[[
	Interface design is a complex process, you might ask what goes into it? Well this is what it requires:
	10% bullshit, 15% tears, 15% hackery, 20% yelling at code, 40% magic
]]

local selectDialogGroup, selectTabGroup, hideAdvancedOption, getName, getUnitOrder, set, get, setVariable
local setColor, getColor, setUnit, getUnit, getTagName, getTagHelp, hideRestrictedOption, getModuleOrder
local unitOrder, globalConfig, positionList, fullReload, pointPositions, isModifiersSet
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

	isUnitDisabled = function(info)
		return not ShadowUF.db.profile.units[info[#(info)]].enabled
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
		for k in pairs(modifyUnits) do return true end
		return false
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
		if( tonumber(moduleSubKey) ) then moduleSubKey = tonumber(moduleSubKey) end
		if( moduleSubKey == "$parent" ) then moduleSubKey = info[#(info) - 1] end
		if( moduleKey == "$parent" ) then moduleKey = info[#(info) - 1] end
		
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
		local unit = info[2]
		local key = info[#(info)]
		if( ( key == "totemBar" and select(2, UnitClass("player")) ~= "SHAMAN" ) or ( key == "runeBar" and select(2, UnitClass("player")) ~= "DEATHKNIGHT" ) ) then
			return true
		end
		
		-- Non-standard units do not support any of these modules
		if( ( key == "castBar" or key == "incHeal" or key == "range" or key == "enabledHeal" or key == "enabledSelf" or key == "colorAggro" ) and string.match(unit, "%s+target" ) ) then
			return true
		-- Of course, nobody except for players and pets have XP (that we can query)
		elseif( key == "xpBar" and unit ~= "pet" and unit ~= "player" ) then
			return true
		-- And rune as well as totem bars are only for player
		elseif( ( key == "runeBar" or key == "totems" ) and unit ~= "player" ) then
			return true
		-- Combo points only for target
		elseif( key == "comboPoints" and unit ~= "target" ) then
			return true
		end
		return false
	end

	getModuleOrder = function(info)
		local key = info[#(info)]
		return key == "healthBar" and 1 or key == "powerBar" and 2 or key == "castBar" and 3 or 4
	end
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
		desc = L["You must do a /console reloadui for an object to show up again."],
		set = function(info, value)
			set(info, value)
			if( value ) then ShadowUF:HideBlizzard(info[#(info)]) end
		end,
		get = get,
	}
	
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
								arg = "locked",
							},
							advanced = {
								order = 1,
								type = "toggle",
								name = L["Advanced"],
								desc = L["Enabling advanced settings will allow you to further tweak settings. This is meant for people who want to tweak every single thing, and should not be enabled by default as it increases the options."],
								arg = "advanced",
							},
							statusbar = {
								order = 2,
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
							background = {
								order = 1,
								type = "select",
								name = L["Background"],
								dialogControl = "LSM30_Background",
								values = getMediaData,
								arg = "backdrop.backgroundTexture",
							},
							border = {
								order = 2,
								type = "select",
								name = L["Border"],
								dialogControl = "LSM30_Border",
								values = getMediaData,
								arg = "backdrop.borderTexture",
							},
							sep1 = {
								order = 3,
								type = "description",
								name = "",
								width = "full",
							},
							edgeSize = {
								order = 4,
								type = "range",
								name = L["Edge size"],
								desc = L["How large the edges should be."],
								hidden = hideAdvancedOption,
								min = 0, max = 20, step = 1,
								arg = "backdrop.edgeSiz",
							},
							tileSize = {
								order = 5,
								type = "range",
								name = L["Tile size"],
								desc = L["How large the background should tile"],
								hidden = hideAdvancedOption,
								min = 0, max = 20, step = 1,
								arg = "backdrop.tileSize",
							},
							clip = {
								order = 6,
								type = "range",
								name = L["Clip"],
								desc = L["How close the frame should clip with the border."],
								hidden = hideAdvancedOption,
								min = 0, max = 20, step = 1,
								arg = "backdrop.clip",
							},
							sep2 = {
								order = 7,
								type = "description",
								name = "",
								width = "full",
								hidden = hideAdvancedOption,
							},
							backgroundColor = {
								order = 8,
								type = "color",
								name = L["Background color"],
								hasAlpha = true,
								set = setColor,
								get = getColor,
								arg = "backdrop.backgroundColor",
							},
							borderColor = {
								order = 9,
								type = "color",
								name = L["Border color"],
								hasAlpha = true,
								set = setColor,
								get = getColor,
								arg = "backdrop.borderColor",
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
						name = L["Bar colors"],
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
								width = "half",
							},
							RUNIC_POWER = {
								order = 6,
								type = "color",
								name = L["Runic Power"],
								hasAlpha = true,
								arg = "powerColors.RUNIC_POWER",
								width = "half",
							},
							green = {
								order = 7,
								type = "color",
								name = L["Health color"],
								desc = L["Standard health bar color"],
								arg = "healthColors.green",
							},
							yellow = {
								order = 8,
								type = "color",
								name = L["Yellow health"],
								desc = L["Health bar color to use when health bars are showing yellow, neutral units."],
								arg = "healthColors.yellow",
								hidden = hideAdvancedOption,
							},
							red = {
								order = 9,
								type = "color",
								name = L["Red health"],
								desc = L["Health bar color to use when health bars are showing red, hostile units, transitional color from green -> red and so on."],
								arg = "healthColors.red",
								hidden = hideAdvancedOption,
							},
							sep = {
								order = 10,
								type = "description",
								name = "",
								width = "full",
								hidden = hideAdvancedOption,
							},
							inc = {
								order = 11,
								type = "color",
								name = L["Incoming heal"],
								desc = L["Health bar color to use to show how much healing someone is about to receive."],
								arg = "healthColors.inc",
							},
							enemyUnattack = {
								order = 12,
								type = "color",
								name = L["Unattackable health"],
								desc = L["Health bar color to use for hostile units who you cannot attack, used for reaction coloring."],
								arg = "healthColors.enemyUnattack",
								hidden = hideAdvancedOption,
							},
						},
					},
					classColors = {
						order = 5,
						type = "group",
						inline = true,
						name = L["Class colors"],
						set = setColor,
						get = getColor,
						args = {}
					},
				},
			},
			profile = LibStub("AceDBOptions-3.0"):GetOptionsTable(ShadowUF.db),
			hide = {
				type = "group",
				order = 3,
				name = L["Hide Blizzard"],
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
	}
	
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
	
	options.args.general.args.profile.order = 1
	
	-- Load layout management info
	local function storeActiveLayout(layout)
		-- First let us grab the main stuff, this is the easy part
		for key in pairs(ShadowUF.mainLayout) do
			layout[key] = ShadowUF.db.profile[key]
		end
		
		-- Now load all of the units
		for unit, data in pairs(ShadowUF.db.profile.units) do
			layout.units[unit] = CopyTable(data)
			layout.units[unit] = ShadowUF:VerifyTable(layout.units[unit])
		end
		
		return layout
	end
	
	local layoutData = {author = UnitName("player")}
	local layoutTable = {
		order = function(info) return ShadowUF.db.profile.activeLayout == info[#(info)] and 0 or 1 end,
		type = "group",
		inline = true,
		name = function(info)
			local layout = ShadowUF.layoutInfo[info[#(info)]]
			local prefix = ShadowUF.db.profile.activeLayout == info[#(info)] and  L["|cffffffffActive:|r "] or ""
			if( layout.author ) then
				return string.format(L["%s%s by %s"], prefix, layout.name, layout.author)
			else
				return prefix .. layout.name
			end
		end,
		args = {
			desc = {
				order = 0,
				type = "description",
				name = function(info) return ShadowUF.layoutInfo[info[#(info) - 1]].description end,
				width = "full",
			},
			sep = {
				order = 1,
				type = "header",
				name = "",
				width = "full",
			},
			activate = {
				order = 2,
				type = "execute",
				name = L["Activate"],
				disabled = function(info) return info[#(info) - 1] == ShadowUF.db.profile.activeLayout end,
				confirm = true,
				confirmText = L["By activating this layout, all of your positioning, sizing and so on settings will be reset to load this layout, are you sure you want to activate this?"],
				func = function(info)
					ShadowUF:SetLayout(info[#(info) - 1], true)
					ShadowUF:LoadUnits()
					ShadowUF.Layout:ReloadAll()
				end,
				width = "half",
			},
			export = {
				order = 3,
				type = "execute",
				name = L["Export"],
				width = "half",
				func = function(info)
					local id = info[#(info) - 1]
					local data = ""
					local newInfo = {id = id, name = ShadowUF.layoutInfo[id].name, author = ShadowUF.layoutInfo[id].author, description = ShadowUF.layoutInfo[id].description}
					-- If it's not the active layout we can just directly use the layout
					if( ShadowUF.db.profile.activeLayout ~= id ) then
						newInfo.layout = ShadowUF.layoutInfo[id].layout
					-- ... and if it's not, we extract the data manually
					else
						newInfo.layout = storeActiveLayout({units = {}})
					end
					
					layoutData.export = id
					layoutData.exportName = ShadowUF.layoutInfo[id].name
					layoutData.exportData = ShadowUF:CompressLayout(ShadowUF:WriteTable(newInfo))
					
					selectTabGroup("general", "layout", "export")
				end,
			},
			delete = {
				order = 4,
				type = "execute",
				name = L["Delete"],
				disabled = function(info) return info[#(info) - 1] == "default" end,
				width = "half",
				confirm = true,
				confirmText = L["Are you sure you want to delete this layout?"],
				func = function(info)
					local id = info[#(info) - 1]
					ShadowUF.layoutInfo[id] = nil
					ShadowUF.db.profile.layoutInfo[id] = nil
					ShadowUF:SetLayout("default", true)
					ShadowUF:LoadUnits()
					ShadowUF.Layout:ReloadAll()
					
					options.args.general.args.layout.args.manage.args[id] = nil
				end,
			},
		},
	}
	
	options.args.general.args.layout = {
		order = 2,
		type = "group",
		name = L["Layouts"],
		childGroups = "tab",
		args = {
			manage = {
				order = 1,
				type = "group",
				name = L["Management"],
				args = {
				
				},
			},
			create = {
				order = 1.5,
				type = "group",
				name = L["Create"],
				args = {
					desc = {
						order = 0,
						type = "group",
						name = L["Help"],
						inline = true,
						args = {
							info = {
								order = 0,
								type = "description",
								name = L["Create a new layout using your current layout as a template. You must fill out all of the fields before you can create it."],
							},
						},
					},
					layout = {
						order = 1,
						type = "group",
						name = L["Layout"],
						inline = true,
						set = function(info, value) layoutData[info[#(info)]] = value end,
						get = function(info) return layoutData[info[#(info)]] or "" end,
						args = {
							name = {
								order = 0,
								type = "input",
								name = L["Layout name"],
							},
							author = {
								order = 1,
								type = "input",
								name = L["Author"],
							},
							description = {
								order = 2,
								type = "input",
								name = L["Description"],
								width = "full",
							},
							create = {
								order = 3,
								type = "execute",
								name = L["Create"],
								disabled = function()
									if( layoutData.name and layoutData.author and layoutData.description ) then
										return false
									end
								
									return true
								end,
								func = function()
									local id = "layout" .. time()
									local layout = {id = id, name = layoutData.name, author = layoutData.author, description = layoutData.description, layout = storeActiveLayout({units = {}})}
									ShadowUF.db.profile.layoutInfo[id] = ShadowUF:WriteTable(layout)
									ShadowUF.db.profile.activeLayout = id
									
									layoutData.name = nil
									layoutData.author = nil
									layoutData.description = nil
									
									selectTabGroup("general", "layout", "manage")
									
									options.args.general.args.layout.args.manage.args[id] = layoutTable
								end,
							},
						},
					},
				},
			},
			import = {
				order = 2,
				type = "group",
				name = L["Import"],
				args = {
					desc = {
						order = 0,
						type = "group",
						name = function() return layoutData.error and L["Error"] or L["Importing"] end,
						inline = true,
						hidden = false,
						args = {
							info = {
								order = 0,
								type = "description",
								name = function() return layoutData.error or L["Import a new layout using the layout data string another user gave you."] end,
							},
						},
					},
					text = {
						order = 1,
						type = "group",
						name = L["Data"],
						inline = true,
						hidden = false,
						args = {
							data = {
								order = 0,
								type = "input",
								name = "",
								multiline = true,
								set = function(info, value)
									-- Do basic verifications to make sure it's good
									local value = ShadowUF:UncompressLayout(value)
									if( not value or value == "" ) then
										layoutData.error = string.format(L["Failed to import layout:\n\n%s"], L["No layout data entered."])
										return
									elseif( not string.match(value, "id=") or not string.match(value, "name=") or not string.match(value, "description=") or not string.match(value, "author=") ) then
										layoutData.error = string.format(L["Failed to import layout:\n\n%s"], L["Layout information fields are not all set, make sure that id, name, description and author was included."])
										layoutData.importData = value
										return
									end
									
									-- Now load and it and see what happens
									local data, msg = loadstring("return " .. value)()
									if( msg ) then
										layoutData.importData = value
										layoutData.error = string.format(L["Failed to import layout:\n\n%s"], msg)
										return
									-- Ugly I know, fuck you it's 3 AM
									elseif( ShadowUF.db.profile.layoutInfo[data.id] ) then
										layoutData.importData = value
										layoutData.error = string.format(L["Failed to import layout:\n\n%s"], string.format(L["You already have a layout named %s, delete it first if you want to reimport it."], data.name))
										return
									end
									
									-- Excellent, register it then
									layoutData.error = nil
									layoutData.importData = nil
									ShadowUF:RegisterLayout(data.id, data)
									
									options.args.general.args.layout.args.manage.args[data.id] = layoutTable
									selectTabGroup("general", "layout", "manage")
								end,
								get = function(info, value) return layoutData.importData or "" end,
								width = "full",
							},
						},
					},
				},
			},
			export = {
				order = 3,
				type = "group",
				name = L["Export"],
				hidden = function() return not layoutData.export end,
				args = {
					desc = {
						order = 0,
						type = "group",
						name = function(info) return string.format(L["Exporting %s"], layoutData.exportName) end,
						inline = true,
						hidden = false,
						args = {
							info = {
								order = 0,
								type = "description",
								name = L["You can now give the string below to other Shadowed Unit Frames users, they can then import it through the import tab to use this layout."],
							},
						},
					},
					text = {
						order = 1,
						type = "group",
						name = L["Data"],
						inline = true,
						hidden = false,
						args = {
							data = {
								order = 0,
								type = "input",
								name = "",
								multiline = true,
								get = function() return layoutData.exportData end,
								width = "full",
							},
						},
					},
				},
			},
		},
	}
	
	for name in pairs(ShadowUF.db.profile.layoutInfo) do
		options.args.general.args.layout.args.manage.args[name] = layoutTable
	end
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
		
		-- Don't let a frame anchor to a frame thats anchored to it already (Stop infinite loops-o-doom
		local currentName = getFrameName(unit)
		for _, unitID in pairs(ShadowUF.units) do
			if( unitID ~= unitID and ShadowUF.db.profile.units[unitID] and ShadowUF.db.profile.positions[unit].anchorTo ~= currentName ) then
				anchorList[getFrameName(unitID)] = string.format(L["%s frames"], L.units[unit])
			end
		end
		
		return anchorList
	end

	-- This makes sure  we don't end up with any messed up positioning due to two different anchors being used
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
	end
	
	--[[
		if( info.arg == "positions" and ( unit == "raid" or unit == "party" or unit == "partypet" or unit == "partytarget" ) ) then
			ShadowUF.Units:ReloadUnit(unit)
		end
	]]
		
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
		
		if( info[2] == "raid" or info[2] == "party" ) then
			ShadowUF.Units:ReloadUnits(info[2])
		else
			ShadowUF.Layout:ReloadAll(info[2])
		end
	end
	
	local function getPosition(info)
		return ShadowUF.db.profile.positions[info[2]][info[#(info)]]
	end

	local numberList = {}
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

		local parentList = {
			order = 0,
			type = "group",
			name = getName,
			args = {}
		}
		
		local textTbl = {
			type = "group",
			name = function(info) return getUnit(info[2], "text." .. info[#(info)]).name end,
			hidden = function(info)	return string.sub(getUnit(info[2], "text." .. info[#(info)]).anchorTo, 2) ~= info[#(info) - 1] end,
			set = false,
			get = false,
			args = {
				text = {
					order = 0,
					type = "input",
					name = L["Text"],
					width = "full",
					hidden = false,
					set = setUnit,
					get = getUnit,
					arg = "text.$parent.text",
				},
				tags = {
					order = 1,
					type = "group",
					inline = true,
					hidden = false,
					name = L["Tags"],
					hidden = false,
					set = function(info, value)
						local unit = info[2]
						local id = tonumber(info[#(info) - 2])
						local key = info[#(info)]
						local text = unit == "global" and globalConfig.text[id].text or ShadowUF.db.profile.units[unit].text[id].text
						
						if( value ) then
							if( text == "" ) then
								text = tag
							else
								text = string.format("%s %s", text, tag)
							end
						else
							text = string.gsub(text, string.format("%%[%s%%]", key), "")
							text = string.gsub(text, "  ", "")
							text = string.trim(text)
						end
						
						if( unit == "global" ) then
							for unit in pairs(modifyUnits) do
								setVariable(unit, "text", id, "text", value)
							end

							setVariable("global", "text", id, "text", value)
						else
							setVariable(unit, "text", id, "text", value)
						end
					end,
					get = function(info) return string.match(getVariable(unit, "text", info[#(info) - 2], "text"), string.format("%%[%s%%]", info[#(info)])) end,
					args = tagList,
				},
			},
		}
	
		-- NTS: If I ever allow people to add more tag text, this has to be changed to a regular variable
		for _, parent in pairs({"$healthBar", "$powerBar"}) do
			parent = string.sub(parent, 2)
			tagWizard[parent] = parentList
			
			for id in pairs(ShadowUF.defaults.profile.units.player.text) do
				tagWizard[parent].args[tostring(id)] = textTbl
			end
		end
	end
	
	-- TEXT CONFIGURATION
	local function setText(info, value)
		local id, key = string.split(":", info[#(info)])
		local unit = info[#(info) - 3]
		if( unit == "global" ) then
			for unit in pairs(modifyUnits) do
				ShadowUF.db.profile.units[unit].text[tonumber(id)][key] = value
			end
		else
			ShadowUF.db.profile.units[unit].text[tonumber(id)][key] = value
		end
		
		ShadowUF.Layout:ReloadAll(unit ~= "global" and unit or nil)
	end
	
	local function getText(info, value)
		local id, key = string.split(":", info[#(info)])
		local unit = info[#(info) - 3]
		if( unit == "global" ) then
			unit = masterUnit
		end
		
		return ShadowUF.db.profile.units[unit].text[tonumber(id)][key]
	end

	local function getTextOrder(info)
		local key = info[#(info)]
		if( key == "healthBar" ) then
			return 0
		elseif( key == "powerBar" ) then
			return 1
		end

		return tonumber((string.split(":", key)))
	end

	Config.textTable = {
		order = getTextOrder,
		name = getName,
		type = "group",
		inline = true,
		set = setText,
		get = getText,
		args = {}
	}

	do
		local function getTextName(info)
			local unit = info[#(info) - 3]
			local id = tonumber((string.split(":", info[#(info)])))
			unit = unit == "global" and masterUnit or unit			
			return ShadowUF.db.profile.units[unit].text[id].name
		end
		
		local function isFromParent(info)
			local unit = info[#(info) - 3]
			local id = tonumber((string.split(":", info[#(info)])))
			unit = unit == "global" and masterUnit or unit
			return string.sub(ShadowUF.db.profile.units[unit].text[id].anchorTo, 2) ~= info[#(info) - 1]
		end
		
		local header = {
			order = getTextOrder,
			name = getTextName,
			hidden = isFromParent,
			type = "header",
		}
		
		local text = {
			order = function(info) return getTextOrder(info) + 0.05 end,
			hidden = isFromParent,
			name = L["Text"],
			type = "input",
			width = "double",
		}

		local width = {
			order = function(info) return getTextOrder(info) + 0.10 end,
			hidden = isFromParent,
			name = L["Width"],
			desc = L["Percentage of the frames width that this text should use."],
			type = "range",
			min = 0, max = 1, step = 0.01,
			isPercent = true,
		}
		
		local sep = {
			order = function(info) return getTextOrder(info) + 0.15 end,
			hidden = isFromParent,
			name = "",
			type = "description",
			width = "full",
		}
		
		local anchorPoint = {
			order = function(info) return getTextOrder(info) + 0.20 end,
			hidden = isFromParent,
			type = "select",
			name = L["Anchor point"],
			values = {["ITR"] = L["Inside Top Right"], ["ITL"] = L["Inside Top Left"], ["ICL"] = L["Inside Center Left"], ["IC"] = L["Inside Center"], ["ICR"] = L["Inside Center Right"]},
		}
		
		local x = {
			order = function(info) return getTextOrder(info) + 0.30 end,
			hidden = isFromParent,
			type = "range",
			name = L["X Offset"],
			min = -50, max = 50, step = 1,
		}
		
		local y = {
			order = function(info) return getTextOrder(info) + 0.40 end,
			hidden = isFromParent,
			type = "range",
			name = L["Y Offset"],
			min = -50, max = 50, step = 1
		}
		
		for id in pairs(ShadowUF.defaults.profile.units.player.text) do
			Config.textTable.args[id .. ":header"] = header
			Config.textTable.args[id .. ":text"] = text
			Config.textTable.args[id .. ":width"] = width
			Config.textTable.args[id .. ":sep"] = sep
			Config.textTable.args[id .. ":anchorPoint"] = anchorPoint
			Config.textTable.args[id .. ":x"] = x
			Config.textTable.args[id .. ":y"] = y
		end
	end
	
	local function disableSameAnchor(info)
		local anchor = ShadowUF.db.profile.units[info[2]].auras.buffs.enabled and "buffs" or "debuffs"
		
		if( anchor == info[#(info) - 1] or ShadowUF.db.profile.units[info[2]].auras.buffs.anchorPoint ~= ShadowUF.db.profile.units[info[2]].auras.debuffs.anchorPoint ) then return false end
		
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
				min = -20, max = 20, step = 1,
				disabled = disableSameAnchor,
				hidden = hideAdvancedOption,
				arg = "auras.$parent.x",
			},
			y = {
				order = 16,
				type = "range",
				name = L["Y Offset"],
				min = -20, max = 20, step = 1,
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
				arg = "$parent.order",
			},
			height = {
				order = 5,
				type = "range",
				name = L["Height"],
				desc = L["How much of the frames total height this bar should get, this is a weighted value, the higher it is the more it gets."],
				min = 0, max = 10, step = 0.1,
				arg = "$parent.height",
			},
		},
	}
	
	Config.indicatorTable = {
		order = 0,
		name = getName,
		type = "group",
		inline = true,
		hidden = false,
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
	
	-- These are all always friendly, so don't show reaction setting
	local isFriendlyUnit = {["player"] = true, ["pet"] = true, ["partypet"] = true, ["raid"] = true, ["party"] = true}
	
	local unitTable = {
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
								values = {["2D"] = L["2D"], ["3D"] = L["3D"]},
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
						args = {
							fader = {
								order = 0,
								type = "toggle",
								name = string.format(L["Enable %s"], L["Combat fader"]),
								arg = "fader.enabled",
							},
							combatAlpha = {
								order = 1,
								type = "range",
								name = L["Combat alpha"],
								desc = L["Alpha to use when you are in combat for this unit."],
								min = 0, max = 1.0, step = 0.1,
								arg = "fader.combatAlpha",
								isPercent = true,
							},
							inactiveAlpha = {
								order = 2,
								type = "range",
								name = L["Inactive alpha"],
								desc = L["Alpha to use when the unit is inactive meaning, not in combat, have no target and mana is at 100%."],
								min = 0, max = 1.0, step = 0.1,
								arg = "fader.inactiveAlpha",
								isPercent = true,
							},
						}
					},
					range = {
						order = 3,
						type = "group",
						inline = true,
						name = L["Range indicator"],
						hidden = function(info) if( info[#(info) - 2] == "global" or info[#(info) - 2] == "target" ) then return false elseif( info[#(info) - 2] == "player" ) then return true end return not isFriendlyUnit[info[#(info) - 2]] end,
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
						args = {
							combatText = {
								order = 0,
								type = "toggle",
								name = string.format(L["Enable %s"], L["Combat text"]),
								arg = "combatText.enabled",
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
						hidden = hideRestrictedOption,
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
								hidden = hideadvancedOption,
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
							sep2 = {
								order = 4,
								type = "description",
								name = "",
								width = "full",
								hidden = false,
							},
							anchorPoint = {
								order = 5,
								type = "select",
								name = L["Anchor point"],
								values = positionList,
								arg = "positions",
								hidden = false,
							},
							x = {
								order = 6,
								type = "range",
								name = L["X Offset"],
								min = -20, max = 20, step = 1,
								hidden = false,
							},
							y = {
								order = 7,
								type = "range",
								name = L["Y Offset"],
								min = -20, max = 20, step = 1,
								hidden = false,
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
					ShadowUF.Units:ReloadUnit(info[2])
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
							hideInRaid = {
								order = 0,
								type = "toggle",
								name = L["Hide in raid"],
								desc = L["Party frames are hidden while in a raid group with more than 5 people inside."],
								hidden = function(info) return info[#(info) - 3] == "raid" end,
								set = function(info, value)
									setUnit(info, value)
									ShadowUF.Units:ReloadUnit(info[#(info) - 3])
									ShadowUF:RAID_ROSTER_UPDATE()
								end,
								arg = "hideInRaid",
							},
							xOffset = {
								order = 1,
								type = "range",
								name = L["X Offset"],
								min = -50, max = 50, step = 1,
								hidden = function(info)
									local point = getVariable(info[2], nil, "attribPoint")
									return point ~= "LEFT" and point ~= "RIGHT"
								end,
								arg = "xOffset",
							},
							yOffset = {
								order = 2,
								type = "range",
								name = L["Y Offset"],
								min = -50, max = 50, step = 1,
								hidden = function(info)
									local point = getVariable(info[2], nil, "attribPoint")
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
									return position and position.anchorTo == "UIParent" and true or false
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
						hidden = hideAdvancedAndGlobal,
					},
					position = {
						order = 2,
						type = "group",
						hidden = hideAdvancedAndGlobal,
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
								order = 0,
								type = "toggle",
								name = string.format(L["Enable %s"], L["Health bar"]),
								arg = "healthBar.enabled",
							},
							enabledHeal = {
								order = 1,
								type = "toggle",
								name = string.format(L["Enable %s"], L["Incoming heals"]),
								arg = "incHeal.enabled",
							},
							enabledSelf = {
								order = 2,
								type = "toggle",
								name = L["Show your heals"],
								desc = L["When showing incoming heals, include your heals in the total incoming."],
								arg = "incHeal.showSelf",
							},
							healthColor = {
								order = 4,
								type = "select",
								name = L["Color health by"],
								values = {["class"] = L["Class"], ["static"] = L["Static"], ["percent"] = L["Health percent"]},
								arg = "healthBar.colorType",
							},
							colorAggro = {
								order = 5,
								type = "toggle",
								name = L["Color on aggro"],
								arg = "healthBar.colorAggro",
							},
							reaction = {
								order = 6,
								type = "toggle",
								name = L["Color by reaction"],
								desc = L["If the unit is hostile, the reaction color will override any color health by options."],
								arg = "healthBar.reaction",
								hidden = function(info) return isFriendlyUnit[info[2]] end,
							},
						},
					},
					bar = {
						order = 2,
						type = "group",
						inline = true,
						name = L["General bars"],
						width = "half",
						args = {
							runeBar = {
								order = 0,
								type = "toggle",
								name = string.format(L["Enable %s"], L["Rune bar"]),
								hidden = function(info)
									local hidden = hideRestrictedOption(info)
									if( hidden ) then return true end
									
									return hideRestrictedOption(info)
								end,
								arg = "runeBar.enabled",
							},
							totemBar = {
								order = 0,
								type = "toggle",
								name = string.format(L["Enable %s"], L["Totem bar"]),
								hidden = function(info)
									local hidden = hideRestrictedOption(info)
									if( hidden ) then return true end
									
									return hideRestrictedOption(info)
								end,
								arg = "totemBar.enabled",
							},
							powerBar = {
								order = 1,
								type = "toggle",
								name = string.format(L["Enable %s"], L["Power bar"]),
								arg = "powerBar.enabled",
							},
							xpBar = {
								order = 2,
								type = "toggle",
								name = string.format(L["Enable %s"], L["XP/Rep bar"]),
								desc = L["This bar will automatically hide when you are at the level cap, or you do not have any reputations tracked."],
								hidden = function(info) if( info[#(info) - 3] ~= "player" and info[#(info) - 4] ~= "pet" ) then return true else return false end end,
								arg = "xpBar.enabled",
							},
							castBar = {
								order = 3,
								type = "toggle",
								name = string.format(L["Enable %s"], L["Cast bar"]),
								arg = "castBar.enabled",
								hidden = function() return ShadowUF.db.profile.advanced end,
							},
						},
					},
					cast = {
						order = 4,
						type = "group",
						inline = true,
						name = L["Cast bar"],
						hidden = hideAdvancedOption,
						args = {
							enabled = {
								order = 0,
								type = "toggle",
								name = string.format(L["Enable %s"], L["Cast bar"]),
								arg = "castBar.enabled",
							},
							castName = {
								order = 0.50,
								type = "header",
								name = L["Cast name"],
								hidden = hideAdvancedOption,
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
				},
			},
			text = {
				order = 6,
				name = L["Text"],
				type = "group",
				set = setUnit,
				get = getUnit,
				hidden = function(info)
					local hidden = isModifiersSet(info)
					if( hidden ) then return true end
					
					return hideAdvancedOption(info)
				end,
				args = {
					healthBar = Config.textTable,
					powerBar = Config.textTable,
				},
			},
			tag = {
				order = 7,
				name = L["Tag wizard"],
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
						name = L["In this category you can configure all of the enabled units, both what features to enable as well as tweaking the layout. Advanced settings in the general category if you want to be able to get finer control on setting options, but it's not recommended for most people.\n\nHere's what each tab does\n\nGeneral - General settings, portrait settings, combat text, anything that doesn't fit the other categories.\n\nFrame - Frame settings, scale, height, width. You can set the frame to be anchored to another here.\n\nBars - Enabling bars (health/cast/etc) as well as setting how the health bar can be colored.\n\nWidget size - Widget sizing, ordering, height.\n\nAuras - What filters to use, where to place auras.\n\nText (Advanced only) - Allows changing how the text anchors and the offset, you can set tags here as well.\n\nTag Wizard - Quickly add and remove tags to text."],
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
							if( not masterUnit and value ) then
								masterUnit = unit
							end
							
							if( IsShiftKeyDown() ) then
								for _, unit in pairs(ShadowUF.units) do
									if( ShadowUF.db.profile.units[unit].enabled ) then
										modifyUnits[unit] = value and true or nil
									end
								end
							else
								modifyUnits[unit] = value and true or nil
							end
							
							if( not modifyUnits[unit] and masterUnit == unit ) then
								masterUnit = nil
								for unit in pairs(modifyUnits) do
									masterUnit = unit
									break
								end
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
			unitTable.args.widgetSize.args[key] = Config.barTable
		end
	end

	-- Load global unit
	for k, v in pairs(unitTable.args) do
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
		end,
		get = function(info)
			return ShadowUF.db.profile.units[info[#(info)]].enabled
		end,
	}

	for order, unit in pairs(ShadowUF.units) do
		options.args.units.args.enabled.args[unit] = enabledUnits
		options.args.units.args.global.args.units.args.units.args[unit] = perUnitList
		options.args.units.args[unit] = unitTable
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
			ShadowUF.Tags:FullUpdate()
		end

		ShadowUF.db.profile.tags[tagData.name][key] = value
	end
	
	local function stripCode(text)
		if( not text ) then
			return ""
		end
		
		return string.gsub(text, "\t", "")
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
							elseif( ShadowUF:IsTagRegistered(text) ) then
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
							
							ShadowUF.db.profile.tags[text] = {func = "function(unit)\n\nend"}
							options.args.tags.args.general.args.list.args[text] = tagTable
							
							selectDialogGroup("tags", "edit")
						end,
					},
				},
			},
			edit = {
				order = 2,
				type = "group",
				name = L["Edit tag"],
				hidden = function() return not tagData.name end,
				args = {
					tag = {
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
							help = {
								order = 2,
								type = "input",
								name = L["Help text"],
								desc = L["Help text to show that describes what this tag does."],
								width = "full",
								set = set,
								get = get,
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
									set(info, value)
									
									ShadowUF.Tags:FullUpdate(tagData.name)
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
									ShadowUF.Tags:FullUpdate(tagData.name)

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
			ShadowUF.Units:ReloadUnit(unit)
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
		name = function(info)
			return L.areas[info[#(info)]]
		end,
		get = get,
		set = set,
		args = {},
	}
	
	local unitTable = {
		type = "group",
		order = getUnitOrder,
		inline = true,
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
		hidden = function(info)
			local hidden = hideRestrictedOption(info)
			if( hidden ) then return true end
			
			return hideRestrictedOption(info)
		end,
	}
		
	for key, module in pairs(ShadowUF.modules) do
		if( module.moduleName ) then
			unitTable.args[key] = moduleTable
		end
	end
	
	for _, unit in pairs(ShadowUF.units) do
		areaTable.args[unit] = unitTable
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
	ShadowUF:FireModuleEvent("ConfigurationLoaded", options)
end

SLASH_SSUF1 = "/suf"
SLASH_SSUF2 = "/shadowuf"
SLASH_SSUS3 = "/shadoweduf"
SLASH_SSUS4 = "/shadowedunitframes"
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
