local Config = ShadowUF:NewModule("Config")
local AceDialog, AceRegistry, SML, registered, options
local L = ShadowUFLocals

--[[
	Interface design is a complex process, you might ask what goes into it? Well this is what it requires:
	10% bullshit, 15% tears, 15% hackery, 20% yelling at code, 40% magic
]]

local function selectDialogGroup(group, key)
	AceDialog.Status.ShadowedUF.children[group].status.groups.selected = key
	AceRegistry:NotifyChange("ShadowedUF")
end

local function isUnitHidden(info)
	return not ShadowUF.db.profile.units[info[#(info)]].enabled
end

local function checkAdvancedStatus(info)
	return not ShadowUF.db.profile.advanced
end

---------------------
-- GENERAL CONFIGURATION
---------------------
local function loadGeneralOptions()
	SML = SML or LibStub:GetLibrary("LibSharedMedia-3.0")
	
	local function set(info, value)
		ShadowUF.db.profile.layout[info[#(info) - 1]][info[#(info)]] = value

		ShadowUF.Layout:CheckMedia()
		ShadowUF.Layout:ReloadAll()
	end
	
	local function get(info)
		return ShadowUF.db.profile.layout[info[#(info) - 1]][info[#(info)]]
	end
	
	local function setColor(info, r, g, b, a)
		local parent = info[#(info) - 1]
		local key = info.arg or info[#(info)]
		
		if( parent == "color" ) then
			parent = info.arg and "powerColor" or "healthColor"
		end

		ShadowUF.db.profile.layout[parent][key].r = r
		ShadowUF.db.profile.layout[parent][key].g = g
		ShadowUF.db.profile.layout[parent][key].b = b
		ShadowUF.db.profile.layout[parent][key].a = a
		
		ShadowUF.Layout:ReloadAll()
	end
	
	local function getColor(info)
		local parent = info[#(info) - 1]
		local key = info.arg or info[#(info)]
		
		if( parent == "color" ) then
			parent = info.arg and "powerColor" or "healthColor"
		end
		
		return ShadowUF.db.profile.layout[parent][key].r, ShadowUF.db.profile.layout[parent][key].g, ShadowUF.db.profile.layout[parent][key].b, ShadowUF.db.profile.layout[parent][key].a
	end
	
	local MediaList = {}
	local function getMediaData(info)
		if( MediaList[info.arg] ) then
			for k in pairs(MediaList[info.arg]) do
				MediaList[info.arg][k] = nil
			end
		else
			MediaList[info.arg] = {}
		end
		
		if( info.arg ~= SML.MediaType.FONT ) then
			MediaList[info.arg][""] = L["None"]
		end
		
		for _, name in pairs(SML:List(info.arg)) do
			MediaList[info.arg][name] = name
		end
		
		return MediaList[info.arg]
	end
	
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
					units = {
						order = 0,
						type = "group",
						inline = true,
						name = L["Enable units"],
						args = {},
					},
					backdrop = {
						order = 1,
						type = "group",
						inline = true,
						name = L["Background/border"],
						args = {
							backgroundTexture = {
								order = 1,
								type = "select",
								name = L["Background"],
								dialogControl = "LSM30_Background",
								values = getMediaData,
								arg = SML.MediaType.BACKGROUND,
							},
							borderTexture = {
								order = 2,
								type = "select",
								name = L["Border"],
								dialogControl = "LSM30_Border",
								values = getMediaData,
								arg = SML.MediaType.BORDER,
							},
							sep = {
								order = 2.5,
								type = "description",
								name = "",
								width = "full",
							},
							backgroundColor = {
								order = 3,
								type = "color",
								name = L["Background color"],
								hasAlpha = true,
								set = setColor,
								get = getColor,
							},
							borderColor = {
								order = 4,
								type = "color",
								name = L["Border color"],
								hasAlpha = true,
								set = setColor,
								get = getColor,
							},
						},
					},
					font = {
						order = 2,
						type = "group",
						inline = true,
						name = L["Font"],
						args = {
							name = {
								order = 1,
								type = "select",
								name = L["Font"],
								dialogControl = "LSM30_Font",
								values = getMediaData,
								arg = SML.MediaType.FONT,
							},
							size = {
								order = 2,
								type = "range",
								name = L["Size"],
								min = 1,
								max = 20,
								step = 1,
							},
						},
					},
					color = {
						order = 3,
						type = "group",
						inline = true,
						name = L["Bar colors"],
						set = setColor,
						get = getColor,
						args = {
							mana = {
								order = 0,
								type = "color",
								hasAlpha = true,
								name = L["Mana"],
								arg = 0,
								width = "half",
							},
							rage = {
								order = 1,
								type = "color",
								hasAlpha = true,
								name = L["Mana"],
								arg = 1,
								width = "half",
							},
							focus = {
								order = 2,
								type = "color",
								hasAlpha = true,
								name = L["Focus"],
								arg = 2,
								width = "half",
							},
							energy = {
								order = 3,
								type = "color",
								hasAlpha = true,
								name = L["Energy"],
								arg = 3,
								width = "half",
							},
							runes = {
								order = 4,
								type = "color",
								hasAlpha = true,
								name = L["Runes"],
								arg = 5,
								width = "half",
							},
							happiness = {
								order = 5,
								type = "color",
								hasAlpha = true,
								name = L["Happiness"],
								arg = 4,
							},
							rp = {
								order = 6,
								type = "color",
								hasAlpha = true,
								name = L["Runic Power"],
								arg = 6,
							},
							green = {
								order = 7,
								type = "color",
								name = L["Health color"],
								desc = L["Standard health bar color"],
							},
						},
					},
				},
			},
			profile = {
				type = "group",
				order = 2,
				name = L["Profiles"],
				args = {},
			},
			layout = {
				type = "group",
				order = 3,
				name = L["Layout management"],
				args = {}
			},
			tags = {
				type = "group",
				order = 4,
				name = L["Tag management"],
				args = {},
			},
		},
	}

	for order, unit in pairs(ShadowUF.units) do
		options.args.general.args.general.args.units.args[unit] = {
			order = order,
			type = "toggle",
			name = L[unit],
			set = function(info, value)
				ShadowUF.db.profile.units[info[#(info)]].enabled = value
				ShadowUF:LoadUnits()
			end,
			get = function(info) return ShadowUF.db.profile.units[info[#(info)]].enabled end,
		}
	end
end

---------------------
-- UNIT CONFIGURATION
---------------------
local function loadUnitOptions()
	local modifyUnits = {}
		
	local function loadUnit(unit, order)
		return {
			type = "group",
			childGroups = "tab",
			order = order + 1,
			hidden = isUnitHidden,
			name = L[unit],
			args = {
				bars = {
					order = 1,
					name = "Bars",
					type = "group",
					args = {},
				},
				auras = {
					order = 1,
					name = "Auras",
					type = "group",
					args = {},
				},
			},
		}
	end
	
	options.args.units = {
		type = "group",
		name = L["Units"],
		args = {
			global = {
				type = "group",
				childGroups = "tab",
				order = 0,
				name = L["Global"],
				args = {
					units = {
						order = 0,
						type = "group",
						inline = true,
						name = L["Units to modify"],
						set = function(info, value) if( IsShiftKeyDown() ) then for unit in pairs(unitList) do modifyUnits[unit] = value end end modifyUnits[info[#(info)]] = value end,
						get = function(info) return modifyUnits[info[#(info)]] end,
						args = {},
					},
				},
			},
		},
	}
	
	-- Load global unit
	for k, v in pairs(loadUnit("global", 2).args) do
		options.args.units.args.global.args[k] = v
	end

	for order, unit in pairs(ShadowUF.units) do
		options.args.units.args.global.args.units.args[unit] = {
			order = order,
			type = "toggle",
			name = L[unit],
			hidden = isUnitHidden,
			desc = string.format(L["Adds %s to the list of units to be modified when you change values in this tab."], L[unit]),
		}
	end

	-- Load units already enabled
	for order, unit in pairs(ShadowUF.units) do
		options.args.units.args[unit] = loadUnit(unit, order)
	end
end

---------------------
-- LAYOUT CONFIGURATION
---------------------
local function loadLayoutOptions()
	local unitList = {}
	local modifyUnits = {}
		
	local function loadUnit(unit, order)
		return {
			type = "group",
			childGroups = "tab",
			order = order + 1,
			name = L[unit],
			hidden = isUnitHidden,
			args = {
				bars = {
					order = 1,
					name = "Bars",
					type = "group",
					args = {},
				},
				auras = {
					order = 1,
					name = "Auras",
					type = "group",
					args = {},
				},
			},
		}
	end
	
	options.args.layout = {
		type = "group",
		name = L["Layout"],
		args = {
			global = {
				type = "group",
				childGroups = "tab",
				order = 0,
				name = L["Global"],
				args = {
					units = {
						order = 0,
						type = "group",
						inline = true,
						name = L["Units to modify"],
						set = function(info, value) if( IsShiftKeyDown() ) then for unit in pairs(unitList) do modifyUnits[unit] = value end end modifyUnits[info[#(info)]] = value end,
						get = function(info) return modifyUnits[info[#(info)]] end,
						args = {},
					},
				},
			},
		},
	}
		
	-- Load global unit
	for k, v in pairs(loadUnit("global", 2).args) do
		options.args.layout.args.global.args[k] = v
	end

	for order, unit in pairs(ShadowUF.units) do
		options.args.layout.args.global.args.units.args[unit] = {
			order = order,
			type = "toggle",
			name = L[unit],
			hidden = isUnitHidden,
			desc = string.format(L["Adds %s to the list of units to be modified when you change values in this tab."], L[unit]),
		}
	
		options.args.layout.args[unit] = loadUnit(unit, order)
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
	
	local function getHelpText(info)
		if( ShadowUF.Tags.defaultHelp[info.arg] ) then
			local msg = ShadowUF.Tags.defaultHelp[info.arg] or ""
			if( msg ~= "" ) then
				msg = msg .. "\n\n"
			end
			
			return msg .. L["This tag is included by default and cannot be deleted."]
		end
		
		return ShadowUF.db.profile.tags[info.arg] and ShadowUF.db.profile.tags[info.arg].help or ""
	end
	
	local function isSearchHidden(info)
		return tagData.search ~= "" and not string.match(info.arg, tagData.search) or false
	end
	
	local function editTag(info)
		tagData.name = info.arg
		
		if( ShadowUF.Tags.defaultHelp[tagData.name] ) then
			tagData.error = L["You cannot edit this tag because it is one of the default ones included in this mod. This function is here to provide an example for your own custom tags."]
		end
		
		selectDialogGroup("tags", "edit")
	end
				
	-- Create all of the tag editor options, if it's a default tag will show it after any custom ones
	local function createTagOptions(tag)
		options.args.tags.args.general.args.list.args[tag .. "name"] = {
			type = "execute",
			order = ShadowUF.Tags.defaultTags[tag] and 100 or 1,
			name = tag,
			desc = getHelpText,
			hidden = isSearchHidden,
			func = editTag,
			arg = tag,
		}
	end

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
								tagdata.addError = L["You must enter a tag name."]
							elseif( string.match(text, "[%[%]%(%)]") ) then
								tagData.addError = string.format(L["You cannot name a tag \"%s\", tag names should contain no brackets or parenthesis."], text)
							elseif( ShadowUF:IsTagRegistered(text) ) then
								tagData.addError = string.format(L["The tag \"%s\" already exists."], text)
							else
								tagData.addError = nil
							end
							
							AceRegistry:NotifyChange("ShadowedUF")
							return tagData.v and "" or true
						end,
						set = function(info, text)
							tagData.name = text
							tagData.error = nil
							tagdata.addError = nil
							
							ShadowUF.db.profile.tags[text] = {funct = "function(unit)\n\nend"}
							createTagOptions(text)
							
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
							funct = {
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
								set = set,
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
									ShadowUF.Tags:FullUpdate()

									options.args.tags.args.general.args.list.args[tagData.name .. "name"] = nil
									options.args.tags.args.general.args.list.args[tagData.name .. "edit"] = nil
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
		createTagOptions(tag)
	end
	
	for tag, data in pairs(ShadowUF.db.profile.tags) do
		createTagOptions(tag)
	end
end

---------------------
-- VISIBILITY OPTIONS
---------------------
local function loadVisibilityOptions()
	local function set(info, value, ...)
		local key = info[#(info)]
		local unit = info[#(info) - 1]
		
		if( key == unit ) then
			key = ""
		end
		
		ShadowUF.db.profile.visibility[info.arg][unit .. key] = value
	end
	
	local function get(info)
		local key = info[#(info)]
		local unit = info[#(info) - 1]

		if( key == unit ) then
			key = ""
		end
		
		return ShadowUF.db.profile.visibility[info.arg][unit .. key]
	end
	
	local function loadArea(type, text)
		options.args.visibility.args[type] = {
			type = "group",
			order = 1,
			name = text,
			get = get,
			set = set,
			args = {},
		}
		
		for order, unit in pairs(ShadowUF.units) do
			options.args.visibility.args[type].args[unit] = {
				type = "group",
				order = order,
				inline = true,
				name = L[unit],
				hidden = isUnitHidden,
				args = {
					[unit] = {
						order = 0,
						type = "toggle",
						name = string.format(L["Enable %s frames"], L[unit]),
						tristate = true,
						arg = type,
						width = "full",
					}
				},
			}
			
			for key, name in pairs(ShadowUF.moduleNames) do
				options.args.visibility.args[type].args[unit].args[key] = {
					order = 1,
					type = "toggle",
					name = name,
					tristate = true,
					arg = type,
				}
			end
		end
	end
	
	options.args.visibility = {
		type = "group",
		childGroups = "tab",
		name = L["Visibility"],
		args = {
			start = {
				order = 0,
				type = "group",
				name = L["General"],
				inline = true,
				args = {
					help = {
						order = 0,
						type = "description",
						name = L["You can set certain units and modules to only be enabled or disabled in different instances, unchecked values are disabled, checked values are enabled, and greyed out ones are ignored."]
					},
				},
			},
		},
	}
	
	loadArea("pvp", L["Battlegrounds"])
	loadArea("arena", L["Arenas"])
	loadArea("party", L["Party instances"])
	loadArea("raid", L["Raid instances"])
end

local function loadOptions()
	options = {
		type = "group",
		name = "Shadowed UF",
		args = {}
	}
	
	loadGeneralOptions()
	loadLayoutOptions()
	loadUnitOptions()
	loadTagOptions()
	loadVisibilityOptions()	
	
	-- Ordering
	options.args.general.order = 0
	options.args.units.order = 1
	options.args.layout.order = 2
	options.args.visibility.order = 3
	options.args.tags.order = 4
	
	-- Debug mostly
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
		AceDialog:SetDefaultSize("ShadowedUF", 810, 500)
		registered = true
	end

	AceDialog:Open("ShadowedUF")
end
