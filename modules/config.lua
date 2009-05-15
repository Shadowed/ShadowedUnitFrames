local Config = ShadowUF:NewModule("Config")
local AceDialog, AceRegistry, AceGUI, SML, registered, options
local L = ShadowUFLocals
local unitOrder, masterUnit
local NYI = " (NYI)" -- Debug

--[[
	Interface design is a complex process, you might ask what goes into it? Well this is what it requires:
	10% bullshit, 15% tears, 15% hackery, 20% yelling at code, 40% magic
]]

-- This is a basic one for frame anchoring
local positionList = { ["RT"] = L["Right Top"], ["RC"] = L["Right Center"], ["RB"] = L["Right Bottom"], ["LT"] = L["Left Top"], ["LC"] = L["Left Center"], ["LB"] = L["Left Bottom"], ["BL"] = L["Bottom Left"], ["BC"] = L["Bottom Center"], ["BR"] = L["Bottom Right"], ["TR"] = L["Top Right"], ["TC"] = L["Top Center"], ["TL"] = L["Top Left"] }

local function selectDialogGroup(group, key)
	AceDialog.Status.ShadowedUF.children[group].status.groups.selected = key
	AceRegistry:NotifyChange("ShadowedUF")
end

-- Misc help functions
local function isUnitHidden(info)
	return not ShadowUF.db.profile.units[info[#(info)]].enabled
end

local function hideAdvancedOption(info)
	return not ShadowUF.db.profile.advanced
end

local function getName(info)
	return ShadowUF.moduleNames[info[#(info)]] or L[info[#(info)]]
end


-- Unit functions
local modifyUnits = {}
local function isModifiersSet(info)
	if( info[#(info) - 1] ~= "global" ) then return false end
	
	for unit in pairs(modifyUnits) do
		return false
	end
	
	return true
end

local function getUnitOrder(info)
	if( not unitOrder ) then
		unitOrder = {}
		
		for order, unit in pairs(ShadowUF.units) do
			unitOrder[unit] = order
		end
	end
	
	return unitOrder[info[#(info)]]
end

-- Tag functions
local function getTagName(info)
	return string.format("[%s]", info[#(info)])
end

local function getTagHelp(info)
	local tag = info[#(info)]
	if( ShadowUF.db.profile.tags[tag] ) then
		return ShadowUF.db.profile.tags[tag].help
	end
	
	return ShadowUF.Tags.defaultHelp[tag]
end

-- Module functions
local function hidePlayerOnly(info)
	local key = info[#(info)]
	local unit = info[(#info) - 1]
	if( unit ~= "player" and unit ~= "pet" and key == "xpBar" ) then
		return true
	end
	
	return false
end

local function getModuleOrder(info)
	local key = info[#(info)]
	return key == "healthBar" and 1 or key == "powerBar" and 2 or key == "castBar" and 3 or 4
end

--------------------
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
					general = {
						order = 0,
						type = "group",
						inline = true,
						name = L["General"],
						set = function(info, value) ShadowUF.db.profile[info[#(info)]] = value end,
						get = function(info) return ShadowUF.db.profile[info[#(info)]] end,
						args = {
							locked = {
								order = 0,
								type = "toggle",
								name = L["Lock frames"],
							},
							advanced = {
								order = 1,
								type = "toggle",
								name = L["Advanced"],
								desc = L["Enabling advanced settings will allow you to further tweak settings. This is meant for people who want to tweak every single thing, and should not be enabled by default as it increases the options."],
							},
						},
					},
					units = {
						order = 1,
						type = "group",
						inline = true,
						name = L["Enable units"],
						args = {},
					},
					backdrop = {
						order = 2,
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
							sep1 = {
								order = 2.5,
								type = "description",
								name = "",
								width = "full",
							},
							edgeSize = {
								order = 3,
								type = "range",
								name = L["Edge size"],
								desc = L["How large the edges should be."],
								hidden = hideAdvancedOption,
								min = 0, max = 20, step = 1,
							},
							tileSize = {
								order = 4,
								type = "range",
								name = L["Tile size"],
								desc = L["How large the background should tile"],
								hidden = hideAdvancedOption,
								min = 0, max = 20, step = 1,
							},
							clip = {
								order = 4.5,
								type = "range",
								name = L["Clip"],
								desc = L["How close the frame should clip with the border."],
								hidden = hideAdvancedOption,
								min = 0, max = 20, step = 1,
							},
							sep2 = {
								order = 5.5,
								type = "description",
								name = "",
								width = "full",
								hidden = hideAdvancedOption,
							},
							backgroundColor = {
								order = 6,
								type = "color",
								name = L["Background color"],
								hasAlpha = true,
								set = setColor,
								get = getColor,
							},
							borderColor = {
								order = 7,
								type = "color",
								name = L["Border color"],
								hasAlpha = true,
								set = setColor,
								get = getColor,
							},
						},
					},
					font = {
						order = 3,
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
						order = 4,
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
		
	local unitTable = {
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
		options.args.general.args.general.args.units.args[unit] = unitTable
	end
end

---------------------
-- UNIT CONFIGURATION
---------------------
local function loadUnitOptions()
	local function set(info, value)
		local unit = info[#(info) - 3]
		local key = info[#(info)]
		if( unit == "global" ) then
			for unit in pairs(modifyUnits) do
				ShadowUF.db.profile.units[unit][key] = value
			end
		else
			ShadowUF.db.profile.units[unit][key] = value
		end
		
		ShadowUF.Layout:CheckMedia()
		ShadowUF.Layout:ReloadAll(unit ~= "global" and unit or nil)
	end
	
	local function get(info)
		local unit = info[#(info) - 3]
		local key = info[#(info)]
		if( unit == "global" ) then
			unit = masterUnit
		end
	
		return ShadowUF.db.profile.units[unit][key]
	end

	local function setCast(info, value)
		local type, key = string.split(".", info.arg)
		local unit = info[#(info) - 3]
		if( unit == "global" ) then
			for unit in pairs(modifyUnits) do
				ShadowUF.db.profile.units[unit][type][key] = value
			end
		else
			ShadowUF.db.profile.units[unit][type][key] = value
		end
		
		ShadowUF.Layout:ReloadAll(unit ~= "global" and unit or nil)
	end
	
	local function getCast(info, value)
		local type, key = string.split(".", info.arg)
		local unit = info[#(info) - 3]
		if( unit == "global" ) then
			unit = masterUnit
		end
		
		return ShadowUF.db.profile.units[unit][type][key]
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
			name = function(info)
				local unit = info[#(info) - 3]
				if( unit == "global" ) then
					unit = masterUnit
				end
				
				return ShadowUF.db.profile.units[unit].text[tonumber(info[#(info)])].name
			end,
			hidden = function(info)
				local unit = info[#(info) - 3]
				if( unit == "global" ) then
					unit = masterUnit
				end
				
				return ShadowUF.db.profile.units[unit].text[tonumber(info[#(info)])].anchorTo ~= info[#(info) - 1]
			end,
			set = false,
			get = false,
			args = {
				text = {
					order = 0,
					type = "input",
					name = L["Text"],
					width = "full",
					hidden = hideAdvancedOption,
					set = function(info, value)
						local unit = info[#(info) - 4]
						local id = tonumber(info[#(info) - 1])
						if( unit == "global" ) then
							for unit in pairs(modifyUnits) do
								ShadowUF.db.profile.units[unit].text[id].text = value
							end
						else
							ShadowUF.db.profile.units[unit].text[id].text = value
						end
						
						ShadowUF.Layout:ReloadAll(unit ~= "global" and unit or nil)
					end,
					get = function(info)
						local unit = info[#(info) - 4]
						local id = tonumber(info[#(info) - 1])
						if( unit == "global" ) then
							unit = masterUnit
						end
						
						return ShadowUF.db.profile.units[unit].text[id].text
					end,
				},
				tags = {
					order = 1,
					type = "group",
					inline = true,
					hidden = false,
					name = L["Tags"],
					set = function(info, value)
						local unit = info[#(info) - 5]
						local id = tonumber(info[#(info) - 2])
						local key = info[#(info)]
						local text = ShadowUF.db.profile.units[unit == "global" and masterUnit or unit].text[id].text
						local tag = string.format("[%s]", key)
						
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
								ShadowUF.db.profile.units[unit].text[id].text = text
							end
						else
							ShadowUF.db.profile.units[unit].text[id].text = text
						end
						
						ShadowUF.Layout:ReloadAll(unit ~= "global" and unit or nil)
					end,
					get = function(info)
						local unit = info[#(info) - 5]
						local id = tonumber(info[#(info) - 2])
						local key = info[#(info)]
						if( unit == "global" ) then
							unit = masterUnit
						end
						
						return string.match(ShadowUF.db.profile.units[unit].text[id].text, string.format("%%[%s%%]", key))
					end,
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

	local textTable = {
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
		
		local sep = {
			order = function(info) return getTextOrder(info) + 0.10 end,
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
			values = positionList,
		}
		
		local x = {
			order = function(info) return getTextOrder(info) + 0.30 end,
			hidden = isFromParent,
			type = "range",
			name = L["X Offset"],
			min = -20, max = 20, step = 1,
		}
		
		local y = {
			order = function(info) return getTextOrder(info) + 0.40 end,
			hidden = isFromParent,
			type = "range",
			name = L["Y Offset"],
			min = -20, max = 20, step = 1
		}
		
		for id in pairs(ShadowUF.defaults.profile.units.player.text) do
			textTable.args[id .. ":header"] = header
			textTable.args[id .. ":text"] = text
			textTable.args[id .. ":sep"] = sep
			textTable.args[id .. ":anchorPoint"] = anchorPoint
			textTable.args[id .. ":x"] = x
			textTable.args[id .. ":y"] = y
		end
	end
	
	local auraTable = {
		type = "group",
		inline = true,
		name = function(info) return info[#(info)] == "buffs" and L["Buffs"] or L["Debuffs"]
		end,
		order = function(info) return info[#(info)] == "buffs" and 0 or 1 end,
		disabled = function(info)
			local unit = info[#(info) - 3]
			unit = unit == "global" and masterUnit or unit
			if( info[#(info) - 1] == "buffs" ) then
				return false
			elseif( ShadowUF.db.profile.units[unit].auras.buffs.position == ShadowUF.db.profile.units[unit].auras.debuffs.position ) then
				return true
			end
			
			return false
		end,
		set = function(info, value)
			local unit = info[#(info) - 3]
			local type = info[#(info) - 1]
			local key = info[#(info)]
			
			if( unit == "global" ) then
				for unit in pairs(ShadowUF.units) do
					ShadowUF.db.profile.units[unit].auras[type][key] = value
				end
			else
				ShadowUF.db.profile.units[unit].auras[type][key] = value
			end
			
			ShadowUF.Layout:ReloadAll(unit ~= "global" and unit or nil)
		end,
		get = function(info)
			local unit = info[#(info) - 3]
			unit = unit == "global" and masterUnit or unit			
			return ShadowUF.db.profile.units[unit].auras[info[#(info) - 1]][info[#(info)]]
		end,
		args = {
			enabled = {
				order = 0,
				type = "toggle",
				name = function(info) if( info[#(info) - 1] == "buffs" ) then return L["Buffs"] end return L["Debuffs"] end,
			},
			enlargeSelf = {
				order = 0.50,
				type = "toggle",
				name = L["Enlarge your auras"] .. NYI,
				desc = L["If you casted the aura, then the buff icon will be increased in size to make it more visible."],
			},
			sep1 = {
				order = 0.75,
				type = "description",
				name = "",
				width = "full",
			},
			PLAYER = {
				order = 1.0,
				type = "toggle",
				name = L["Show your auras only"],
				desc = L["Filter out any auras that you did not cast yourself."],
			},
			RAID = {
				order = 1.5,
				type = "toggle",
				name = L["Show castable on other auras only"],
				desc = L["Filter out any auras that you cannot cast on another player, or yourself."],
				width = "double",
			},
			sep2 = {
				order = 1.75,
				type = "description",
				name = "",
				width = "full",
			},
			inColumn = {
				order = 2,
				type = "range",
				name = L["Per column"],
				desc = L["How many auras to show in a single row."],
				min = 1, max = 50, step = 1,
			},
			rows = {
				order = 3,
				type = "range",
				name = L["Rows"],
				desc = L["How many rows to use."],
				min = 1, max = 5, step = 1,
			},
			sep3 = {
				order = 3.5,
				type = "description",
				name = "",
				width = "full",
			},
			position = {
				order = 4,
				type = "select",
				name = L["Position"],
				desc = L["How you want this aura to be anchored to the unit frame."],
				values = {["INSIDE"] = L["Inside"], ["BOTTOM"] = L["Bottom"], ["TOP"] = L["Top"], ["LEFT"] = L["Left"], ["RIGHT"] = L["Right"]},
				disabled = false,
			},
			x = {
				order = 5,
				type = "range",
				name = L["X Offset"],
				min = -20, max = 20, step = 1,
			},
			y = {
				order = 6,
				type = "range",
				name = L["Y Offset"],
				min = -20, max = 20, step = 1,
			},
		},
	}
	
	local unitTable = {
		type = "group",
		childGroups = "tab",
		order = getUnitOrder,
		name = getName,
		hidden = isUnitHidden,
		set = set,
		get = get,
		args = {
			general = {
				order = 1,
				name = L["General"],
				type = "group",
				hidden = isModifiersSet,
				args = {
					portrait = {
						order = 1,
						type = "group",
						inline = true,
						name = L["Portrait"],
						args = {
							portrait = {
								order = 0,
								type = "toggle",
								name = string.format(L["Enable %s"], L["Portrait"]),
							},
							portraitType = {
								order = 1,
								type = "select",
								name = L["Portrait type"],
								values = {["2D"] = L["2D"], ["3D"] = L["3D"]},
							},
						},
					},
					combatText = {
						order = 2,
						type = "group",
						inline = true,
						name = L["Combat text"],
						args = {
							combatText = {
								order = 0,
								type = "toggle",
								name = string.format(L["Enable %s"], L["Combat text"]) .. NYI,
								width = "full",
							},
						},
					},
				},
			},
			bars = {
				order = 2,
				name = L["Bars"],
				type = "group",
				hidden = isModifiersSet,
				args = {
					health = {
						order = 1,
						type = "group",
						inline = true,
						name = L["Health bar"],
						args = {
							healthBar = {
								order = 0,
								type = "toggle",
								name = string.format(L["Enable %s"], L["Health bar"]),
							},
							colorAggro = {
								order = 1,
								type = "toggle",
								name = L["Color on aggro"] .. NYI,
s							},
							healthColor = {
								order = 2,
								type = "select",
								name = L["Color health by"] .. NYI,
								values = {["reaction"] = L["Reaction"], ["class"] = L["Class"], ["static"] = L["Static"], ["percent"] = L["Health percent"], ["threat"] = L["Threat"]},
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
							powerBar = {
								order = 0,
								type = "toggle",
								name = string.format(L["Enable %s"], L["Power bar"]),
							},
							xpBar = {
								order = 1,
								type = "toggle",
								name = string.format(L["Enable %s"], L["XP/Rep bar"]),
								desc = L["This bar will automatically hide when you are at the level cap, or you do not have any reputations tracked."],
								hidden = function(info) if( info[#(info) - 4] ~= "player" and info[#(info) - 4] ~= "pet" ) then return true else return false end end,
							},
						},
					},
					cast = {
						order = 4,
						type = "group",
						inline = true,
						name = L["Cast bar"],
						args = {
							castBar = {
								order = 0,
								type = "toggle",
								name = string.format(L["Enable %s"], L["Cast bar"]),
								arg = unit
							},
							castName = {
								order = 0.50,
								type = "header",
								name = L["Cast name"],
							},
							nameAnchor = {
								order = 1,
								type = "select",
								name = L["Anchor point"],
								desc = L["Where to anchor the cast name text."],
								values = {["ICL"] = L["Inside Center Left"], ["ICR"] = L["Inside Center Right"]},
								set = setCast,
								get = getCast,
								arg = "castName.anchorPoint",
							},
							nameX = {
								order = 2,
								type = "range",
								name = L["X Offset"],
								min = -20, max = 20, step = 1,
								set = setCast,
								get = getCast,
								arg = "castName.x",
							},
							nameY = {
								order = 3,
								type = "range",
								name = L["Y Offset"],
								min = -20, max = 20, step = 1,
								set = setCast,
								get = getCast,
								arg = "castName.y",
							},
							castTime = {
								order = 3.50,
								type = "header",
								name = L["Cast time"],
							},
							timeAnchor = {
								order = 4,
								type = "select",
								name = L["Anchor point"],
								desc = L["Where to anchor the cast time text."],
								values = {["ICL"] = L["Inside Center Left"], ["ICR"] = L["Inside Center Right"]},
								set = setCast,
								get = getCast,
								arg = "castTime.anchorPoint",
							},
							timeX = {
								order = 5,
								type = "range",
								name = L["X Offset"],
								min = -20, max = 20, step = 1,
								set = setCast,
								get = getCast,
								arg = "castTime.x",
							},
							timeY = {
								order = 6,
								type = "range",
								name = L["Y Offset"],
								min = -20, max = 20, step = 1,
								set = setCast,
								get = getCast,
								arg = "castTime.y",
							},
						},
					},
				},
			},
			auras = {
				order = 3,
				name = L["Auras"],
				type = "group",
				hidden = isModifiersSet,
				args = {
					buffs = auraTable,
					debuffs = auraTable,
				},
			},
			text = {
				order = 4,
				name = L["Text"],
				type = "group",
				hidden = isModifiersSet,
				args = {
					healthBar = textTable,
					powerBar = textTable,
				},
			},
			tag = {
				order = 5,
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
			global = {
				type = "group",
				childGroups = "tab",
				order = 0,
				name = L["Global"],
				set = set,
				get = get,
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
							
							modifyUnits[unit] = value and true or nil
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
										name = L["Select unit(s) to modify to access the global configuration, this will let you change settings quickly on all selected units at once."],
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
	
	-- Load global unit
	for k, v in pairs(unitTable.args) do
		options.args.units.args.global.args[k] = v
	end

	-- Load all of the per unit settings
	local perUnitList = {
		order = getUnitOrder,
		type = "toggle",
		name = getName,
		hidden = isUnitHidden,
		desc = function(info)
			return string.format(L["Adds %s to the list of units to be modified when you change values in this tab."], L[info[#(info)]])
		end,
	}
	
	for order, unit in pairs(ShadowUF.units) do
		options.args.units.args.global.args.units.args.units.args[unit] = perUnitList
	end

	-- Load units already enabled
	for order, unit in pairs(ShadowUF.units) do
		options.args.units.args[unit] = unitTable
	end
end

---------------------
-- LAYOUT CONFIGURATION
---------------------
local function loadLayoutOptions()
	local pointPositions = {[""] = L["None"], ["TOPLEFT"] = L["Top Left"], ["TOPRIGHT"] = L["Top Right"], ["BOTTOMLEFT"] = L["Bottom Left"], ["BOTTOMRIGHT"] = L["Bottom Right"], ["CENTER"] = L["Center"]}
	
	local anchorList = {}
	local function getAnchorParents(info)
		for k in pairs(anchorList) do anchorList[k] = nil end		
		anchorList[""] = L["None"]
		
		for _, unit in pairs(ShadowUF.units) do
			if( unit ~= info[#(info) - 3] and ShadowUF.db.profile.units[unit].enabled ) then
				local name
				if( unit == "raid" or unit == "party" ) then
					name = string.format("#SUFHeader%s", unit)
				else
					name = string.format("#SUFUnit%s", unit)
				end
				
				anchorList[name] = string.format(L["%s frames"], L[unit])
			end
		end
		
		return anchorList
	end
	
	-- This makes sure  we don't end up with any messed up positioning due to two different anchors being used
	local function fixPositions(info)
		local unit = info[#(info) - 3]
		local type = info.arg or "layout"
		if( info[#(info)] == "point" or info[#(info)] == "relativePoint" ) then
			if( unit == "global" ) then
				for unit in pairs(modifyUnits) do
					ShadowUF.db.profile[type][unit].anchorPoint = nil
					ShadowUF.db.profile[type][unit].anchorTo = "UIParent"
				end
			else
				ShadowUF.db.profile[type][unit].anchorPoint = nil
				ShadowUF.db.profile[type][unit].anchorTo = "UIParent"
			end
		elseif( info[#(info)] == "anchorPoint" ) then
			if( unit == "global" ) then
				for unit in pairs(modifyUnits) do
					ShadowUF.db.profile[type][unit].point = nil
					ShadowUF.db.profile[type][unit].relativePoint = nil
				end
			else
				ShadowUF.db.profile[type][unit].point = nil
				ShadowUF.db.profile[type][unit].relativePoint = nil
			end
		end
	end
	
	local function set(info, value)
		fixPositions(info)
		
		local unit = info[#(info) - 3]
		local key = info[#(info)]
		local type = info.arg or "layout"
		if( unit == "global" ) then
			for unit in pairs(modifyUnits) do
				ShadowUF.db.profile[type][unit][key] = value
			end
		else
			ShadowUF.db.profile[type][unit][key] = value
		end
		
		ShadowUF.Layout:CheckMedia()
		ShadowUF.Layout:ReloadAll(unit ~= "global" and unit or nil)
	end
	
	local function get(info)
		local unit = info[#(info) - 3]
		local key = info[#(info)]
		if( unit == "global" ) then
			unit = masterUnit
		end
	
		return ShadowUF.db.profile[info.arg or "layout"][unit][key]
	end
	
	local function checkNumber(info, value)
		return tonumber(value)
	end
	
	local function setNumber(info, value)
		set(info, tonumber(value))
	end
	
	local function getString(info)
		return tostring(get(info))
	end
	
	local function isNumber(info, value)
		return tonumber(value)
	end
	
	local barTable = {
		order = getModuleOrder,
		name = getName,
		type = "group",
		inline = true,
		args = {
			order = {
				order = 0,
				type = "range",
				name = L["Order"],
				min = 0, max = 100, step = 5,
			},
			heightWeight = {
				order = 1,
				type = "range",
				name = L["Height"],
				desc = L["How much of the frames total height this bar should get, this is a weighted value, the higher it is the more it gets."],
				min = 0, max = 10, step = 0.1,
			},
			background = {
				order = 2,
				type = "toggle",
				name = L["Show background"],
				desc = L["Show a background behind the bars with the same texture/color but faded out."],
				hidden = hideAdvancedOption,
			},
		},
	}
	
	local unitTable = {
		type = "group",
		childGroups = "tab",
		order = getUnitOrder,
		name = getName,
		hidden = isUnitHidden,
		set = set,
		get = get,
		args = {
			general = {
				order = 1,
				name = L["General"],
				type = "group",
				hidden = isModifiersSet,
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
							},
							height = {
								order = 1,
								type = "range",
								name = L["Height"],
								min = 0, max = 100, step = 1,
							},
							width = {
								order = 2,
								type = "range",
								name = L["Width"],
								min = 0, max = 300, step = 1,
							},
						},
					},
					anchor = {
						order = 1,
						type = "group",
						inline = true,
						name = L["Anchor to another frame"],
						args = {
							anchorPoint = {
								order = 0,
								type = "select",
								name = L["Anchor point"],
								values = positionList,
								arg = "positions",
							},
							anchorTo = {
								order = 1,
								type = "select",
								name = L["Anchor to"],
								values = getAnchorParents,
								arg = "positions",
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
								validate = isNumber,
								set = setNumber,
								get = getString,
								arg = "positions",
							},
							y = {
								order = 4,
								type = "input",
								name = L["Y Offset"],
								validate = isNumber,
								set = setNumber,
								get = getString,
								arg = "positions",
							},
						},
					},
					orHeader = {
						order = 1.5,
						type = "header",
						name = L["Or you can set a position manually"],
						hidden = hideAdvancedOption,
					},
					position = {
						order = 2,
						type = "group",
						hidden = hideAdvancedOption,
						inline = true,
						name = L["Manual position"],
						args = {
							point = {
								order = 0,
								type = "select",
								name = L["Point"],
								values = pointPositions,
								arg = "positions",
							},
							relativePoint = {
								order = 1,
								type = "select",
								name = L["Relative point"],
								values = pointPositions,
								arg = "positions",
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
								validate = isNumber,
								set = setNumber,
								get = getString,
								arg = "positions",
							},
							y = {
								order = 4,
								type = "input",
								name = L["Y Offset"],
								validate = isNumber,
								set = setNumber,
								get = getString,
								arg = "positions",
							},
						},
					},
				},
			},
			bars = {
				order = 2,
				name = L["Widget size"],
				type = "group",
				hidden = isModifiersSet,
				set = function(info, value)
					local key = info[#(info)]
					local module = info[#(info) - 1]
					local unit = info[#(info) - 3]
					
					if( unit == "global" ) then
						for unit in pairs(modifyUnits) do
							ShadowUF.db.profile.layout[unit][module][key] = value
						end
					else
						ShadowUF.db.profile.layout[unit][module][key] = value
					end
					
					ShadowUF.Layout:ReloadAll(unit ~= "global" and unit or nil)
				end,
				get = function(info)
					local key = info[#(info)]
					local module = info[#(info) - 1]
					local unit = info[#(info) - 3]
					if( unit == "global" ) then
						unit = masterUnit
					end
					
					return ShadowUF.db.profile.layout[unit][module][key]
				end,
				args = {
					portrait = {
						order = 0,
						type = "group",
						name = L["Portrait"],
						inline = true,
						args = {
							alignment = {
								order = 0,
								type = "select",
								name = L["Alignment"],
								values = {["LEFT"] = L["Left"], ["RIGHT"] = L["Right"]},
							},
							width = {
								order = 1,
								type = "range",
								name = L["Width percent"],
								desc = L["Percentage of width the portrait should use."],
								min = 0, max = 1.0, step = 0.01,
								isPercent = true,
							},
						},
					},
					healthBar = barTable,
					powerBar = barTable,
					castBar = barTable,
					xpBar = barTable,
				},
			},
		},
	}
	
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
						name = L["Units"],
						set = function(info, value)
							local unit = info[#(info)]
							if( not masterUnit and value ) then
								masterUnit = unit
							end
							
							modifyUnits[unit] = value and true or nil
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
										name = L["Select unit(s) to modify to access the global configuration, this will let you change settings quickly on all selected units at once."],
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
	
	-- Load global unit
	for k, v in pairs(unitTable.args) do
		options.args.layout.args.global.args[k] = v
	end

	
	-- Load all of the per unit settings
	local perUnitList = {
		order = getUnitOrder,
		type = "toggle",
		name = getName,
		hidden = isUnitHidden,
		desc = function(info)
			return string.format(L["Adds %s to the list of units to be modified when you change values in this tab."], L[info[#(info)]])
		end,
	}
	
	for order, unit in pairs(ShadowUF.units) do
		options.args.layout.args.global.args.units.args.units.args[unit] = perUnitList
	end

	-- Load units already enabled
	for order, unit in pairs(ShadowUF.units) do
		options.args.layout.args[unit] = unitTable
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
		return tagData.search ~= "" and not string.match(info.arg, tagData.search) or false
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
							
							ShadowUF.db.profile.tags[text] = {funct = "function(unit)\n\nend"}
							options.args.tags.args.general.args.list.args[tag] = tagTable
							
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
	
	local areaTable = {
		type = "group",
		order = 1,
		name = getName,
		get = get,
		set = set,
		args = {},
	}
	
	local unitTable = {
		type = "group",
		order = getUnitOrder,
		inline = true,
		name = getName,
		hidden = isUnitHidden,
		args = {
			enabled = {
				order = 0,
				type = "toggle",
				name = function(info) return string.format(L["Enable %s frames"], L[info[#(info) - 1]]) end,
				tristate = true,
				hidden = false,
				width = "full",
			}
		}
	}
	
	local moduleTable = {
		order = getModuleOrder,
		type = "toggle",
		name = getName,
		tristate = true,
		hidden = hidePlayerOnly,
	}
		
	for key, name in pairs(ShadowUF.moduleNames) do
		unitTable.args[key] = moduleTable
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
				name = L["General"],
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
		AceDialog:SetDefaultSize("ShadowedUF", 835, 525)
		registered = true
	end

	AceDialog:Open("ShadowedUF")
end
