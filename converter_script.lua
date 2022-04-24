--(Un)Official Crackdown Weapon Converter Tool v3.0
--	For help/reporting bugs/etc, contact me on Discord.

-----------------------------------------
--------------SETTINGS-------------------
-----------------------------------------

--		####GENERAL
local mode = 1
--1: primary/secondary weapon
--2: melee weapon


local THREAT_ROUND_UP = true
--threat is on a lookup table, meaning some values are not possible. if true, rounds up to the next possible threat value; else, rounds down to nearest possible threat value




--		####STYLE/FORMATTING

local INCLUDE_PREFIX = true
local ADD_COMMAS = false


--		####I/O

--only used for the below two filepaths; change it accordingly if you intend to change the folder name
--or if you just want to change the destination path
local mod_path = "mods/Crackdown-Weapon-Spreadsheet-Converter/"

--where the data to be read is located and what is called
local input_filepath = mod_path .. "INPUT.txt"

--where the processed data to be saved is called
local output_filepath = mod_path .. "OUTPUT.txt"

--		####ERROR HANDLING
local BREAK_ON_ERROR = true

local tab_newline_spaces = 1



--here be dragons! 
-----------------------------------------
---------------- GUTS -------------------
-----------------------------------------


--1. Read raw copypasted data from INPUT file
--2. Parse keys and values, return weapon data table
--3. Iterate through weapon data table and return sorted, printable output table



local DEFAULT_WEAPON_STATS = { --based on mostly-vanilla amcar stats
	categories = {
		"assault_rifle"
	},
	damage_melee = 1.5,
	damage_melee_effect_mul = 1.75,
	sounds = {
		fire = "amcar_fire_single",
		fire_single = "amcar_fire_single",
		fire_auto = "amcar_fire",
		stop_fire = "amcar_stop",
		dryfire = "primary_dryfire",
		enter_steelsight = "m4_tighten",
		enter_steelsight = "primary_steel_sight_enter",
		leave_steelsight = "primary_steel_sight_exit"
	},
	timers = {
		reload_not_empty = 2.25,
		reload_empty = 3,
		unequip = 0.6,
		equip = 0.55
	},
	name_id = "bm_w_amcar",
	desc_id = "bm_w_amcar_desc",
	description_id = "des_m4",
	muzzleflash = "effects/payday2/particles/weapons/556_auto_fps",
	shell_ejection = "effects/payday2/particles/weapons/shells/shell_556",
	use_data = {
		selection_index = 1
	},
	DAMAGE = 1,
	damage_falloff = WeaponFalloffTemplate.setup_weapon_falloff_templates().ASSAULT_FALL_LOW,
	CLIP_AMMO_MAX = 20,
	NR_CLIPS_MAX = 11,
	AMMO_MAX = 20 * 11,
	AMMO_PICKUP = {0.03 * 20*11, 0.055 * 20*11},
	FIRE_MODE = "auto",
	fire_mode_data = {
		fire_rate = 0.11
	},
	CAN_TOGGLE_FIREMODE = true,
	auto = {
		fire_rate = 0.11
	},
	weapon_hold = "m4",
	animations = {
		reload = "reload",
		reload_not_empty = "reload_not_empty",
		equip_id = "equip_m4",
		recoil_steelsight = true,
		magazine_empty = "last_recoil"
	},
	panic_suppression_chance = 0.2,
	stats = {
		zoom = 1,
		total_ammo_mod = 21,
		damage = 45,
		alert_size = 7,
		spread = 10,
		spread_moving = 8,
		recoil = 20,
		value = 1,
		extra_ammo = 101, --vanilla is 51
		reload = 11,
		suppression = 10,
		concealment = 21
	}
}

local sort_order = {
	{ --weapon
		{ --level 1
			"primary_class",
			"subclasses",
			"categories",
			"FIRE_MODE",
			"CAN_TOGGLE_FIREMODE",
			"timers", --reload speed
			"fire_mode_data", --firerate
			"auto", --automatic firerate
			"CLIP_AMMO_MAX",
--			"NR_CLIPS_MAX", --not used aside from max ammo tweakdata calculations
			"AMMO_MAX",
			"stats",
			"stats_modifiers",
			"AMMO_PICKUP"
		},
		{ --level 2
			stats = {
				"zoom",
				"total_ammo_mod",
				"damage",
				"alert_size",
				"spread",
				"spread_moving", --not used in-game
				"recoil",
				"value",
				"extra_ammo",
				"reload",
				"suppression",
				"concealment"
			},
			stats_modifiers = {
				"damage"
			},
			timers = {
				"reload_not_empty",
				"reload_empty",
				"unequip",
				"equip"
			},
			AMMO_PICKUP = {1,2},
			fire_mode_data = {
				"fire_rate"
			}
		}
	},
	{ --melee
		"primary_class",
		"subclasses",
		"charge_time",
		"remove_weapon_movement_penalty",
		"concealment",
		"knockback_tier",
		"min_damage",
		"max_damage",
		"range"
	}
}

local ignore_missing_stat_errors = {
	subclasses = true
}

local key_lookups = {
	{ --weapon
		["ID"] = "weapon_id",
		["Accuracy"] = "spread", --stats table
		["Class"] = "class",
		["Stability"] = "recoil", --stats table
		["Magazine"] = "CLIP_AMMO_MAX",
		["Concealment"] = "concealment", --stats table
		["Ammo Stock"] = "AMMO_MAX",
		["Total Ammo"] = "AMMO_MAX",
		["Threat"] = "suppression", --stats table
		["Fire Rate"] = "fire_rate", --firemode-dependent table/fire_mode_data table
		["Pickup (low)"] = "pickup_low", --AMMO_PICKUP table
		["Pickup (high)"] = "pickup_high", --AMMO_PICKUP table
		["Damage"] = "damage", -- stats table; require damage multiplier to stats_modifiers table if above 200
	--the below are functional but never used, so they won't generate unless you add them to the gun_data_template table
		["Can Toggle Firemode"] = "CAN_TOGGLE_FIREMODE", --boolean value!
		["Fire Mode"] = "FIRE_MODE",
		["Armor Piercing"] = "armor_piercing_chance", --num [0-1]
		["Shield Piercing"] = "can_shoot_through_shield", --boolean flag
		["Body Piercing"] = "can_shoot_through_enemy", --boolean flag
		["Wall Piercing"] = "can_shoot_through_wall" --boolean flag (not really used)
	},
	{ --melee
	
	}
}

local primary_classes = {
	["Rapid Fire"] = "class_rapidfire",
	["Shotgun"] = "class_shotgun", --to distinguish it from the weapon category upgrades- we don't want those applying twice
	["Precision"] = "class_precision",
	["Heavy"] = "class_heavy",
	["Specialist"] = "class_specialist",
	["Saw"] = "class_saw",
	["Grenade"] = "class_grenade",
	["Throwing"] = "class_throwing", --deliberately NOT "throwable"
	["Melee"] = "class_melee"	
}
local subclasses = {
	["Quiet"] = "subclass_quiet",
	["Poison"] = "subclass_poison",
	["Area Denial"] = "subclass_areadenial"
}


--		UTILS

local function olog(s)
	log("**** Offy's very cool crakdoughnut (tm) spreadsheet-info-to-formatted-weapon-tweakdata-lua converter ****: " .. s)
end

local function remove_extra_spaces(s)
	--check for extraneous space characters here
	-- instead of *assuming* each field is delimited by " : " in string.split, in case of rare typos where the space is not present
	while (string.match(string.sub(s,1,1),"%s")) and (string.len(s) > 0) do
		s = string.sub(s,2)
	end
	while (string.match(string.sub(s,-1,-1),"%s")) and (string.len(s) > 0) do 
		s = string.sub(s,1,-2)
	end
	
	return s
end

local function get_weapon_name(weapon_id,weapon_mode)
	if tweak_data and managers and managers.localization then 
		if weapon_mode == 2 then --melee weapon mode
			if tweak_data.blackmarket and tweak_data.blackmarket.melee_weapons then 
				local td = tweak_data.blackmarket.melee_weapons[weapon_id]
				if td then 
					return managers.localization:text(td.name_id)
				end
			end
		else
			if tweak_data.weapon then 
				local td = tweak_data.weapon[weapon_id]
				if td then 
					return managers.localization:text(td.name_id)
				end
			end
		end
	end
	return tostring(weapon_id)
end

local function convert_rof(rpm) --converts rounds per minute to seconds per round
	local rounds_per_second = rpm / 60
	return 1 / rounds_per_second --could just do 60/n to save time and space but i'd rather waste even more time and space by leaving this comment saying that i'm not going to do that
end

local function convert_accstab(stat) --converts acc/stab from a [0-100] value to the weird internal multiple of 4 stat thing pd2 has going on
	return math.round((stat + 4) / 4)
end

local function convert_threat(target_threat)
	local threat_suppression_reverse_lookup = {
		--suppression : threat
		43, -- 1 (cap)
		37, -- 2
		34, -- 3
		31, -- 4
		28, -- 5
		26, -- 6
		24, -- 7
		22, -- 8
		20, -- 9
		14, -- 10
		13, -- 11
		12, -- 12
		11, -- 13
		10, -- 14
		9,  -- 15
		8,  -- 16
		6,  -- 17
		4,  -- 18
		2,  -- 19
		0   -- 20 (floor)
	}
	
	for threat_index,suppression in ipairs(threat_suppression_reverse_lookup) do 
		if suppression == target_threat then 
			return threat_index
		elseif suppression < target_threat then
			if THREAT_ROUND_UP then 
				return math.max(1,threat_index - 1)
			else --round down
				return threat_index
			end
		end
	end
	
	return 0
end

local function convert_boolean(input)
	if type(input) == "string" then 
		local s = string.lower(input)
		if string.find(s,"yes") then 
			return true
		elseif string.find(s,"no") then 
			return false
		end
	end
	return input and true or false
end


--		MEAT
--given input file, attempts to parse a stat name and a value from each line
--then attempts to place each value in the correct place in an output weapon data table
--and returns the table

--this does not attempt to fill in missing values; that will be done later
local function read_input()
	local all_results = {}
	local input_file = io.open(input_filepath,"r")
	if not input_file then 
		olog("No input file found at path " .. tostring(input_filepath))
	else
	
		local invalid
		local stat_conversion_lookup = key_lookups[mode]
		local weapon_id
		local RESULT_TEMPLATE = {
--			weapon_id = weapon_id,
			weapon_data = {
				subclasses = {},
				stats = {},
--				timers = {},
--				stats_modifiers = {},
--				fire_mode_data = {},
				AMMO_PICKUP = {}
			}
		}
		local result
		local line_num = 0
		for raw_line in input_file:lines() do 
			line_num = line_num + 1 --only used for debugging
			local line = remove_extra_spaces(raw_line)
			if line ~= "" then 
				local split = string.split(line,":")
				
				if not (split[1] and split[2]) then 
					olog("Error! Invalid formatting in line#" .. (line_num or "nil") .. ": \"" .. line .. "\"")
				end
				
				local field_name = remove_extra_spaces(split[1])
				if field_name == "ID" then
					--a new id indicates the start of a new weapon dataset
					if result then
						--in multi-parse mode, if a new weapon_id field is detected while data already exists,
						--then output existing data as finished and start a new entry
						table.insert(all_results,#all_results+1,result)
					end
					invalid = nil
					weapon_id = remove_extra_spaces(split[2])
					result = table.deep_map_copy(RESULT_TEMPLATE)
					result.weapon_id = weapon_id
				else
					local field_value = remove_extra_spaces(split[2])
					
					local stat_name = stat_conversion_lookup[field_name]
					if stat_name then 
					
					--Find weapon class
						if field_name == "Class" then 
						
							local function add_weapon_class(classname)
								if primary_classes[classname] then 
									result.weapon_data.primary_class = primary_classes[classname]
								elseif subclasses[classname] then 
									if not table.contains(result.weapon_data.subclasses,classname) then 
										table.insert(result.weapon_data.subclasses,subclasses[classname])
									end
								else
									olog("Error! Unknown class name \"" .. tostring(classname) .. "\" in \"" .. line .. "\"!")
									if BREAK_ON_ERROR then 
										return
									end
								end
							end
												
							if string.find(field_value,",") then
								for _,class_name in pairs(string.split(field_value,",") or {}) do 
									add_weapon_class(class_name)
								end
							else
								add_weapon_class(field_value)
							end
					--Find penetration properties (wall/shield/enemy piercing)
						elseif field_name == "Properties" then 
							local properties = string.split(field_value,",")
							for _,_property in pairs(properties) do 
								local property = remove_extra_spaces(_property)
								if property == "Armor Piercing" then
									result.weapon_data[stat_conversion_lookup[property]] = 1
								elseif property == "Body Piercing" then 
									result.weapon_data[stat_conversion_lookup[property]] = true
								elseif property == "Wall Piercing" or property == "Shield Piercing" then  --shield and wall piercing are the same in the overhaul
									result.weapon_data.can_shoot_through_wall = true
									result.weapon_data.can_shoot_through_shield = true
								else
									olog("Error: Unknown property " .. tostring(property))
									if BREAK_ON_UNSUPPORTED_STAT then 
										return
									end
								end
							end
					--Find firemode toggleable
						elseif field_name == "Can Toggle Firemode" then 
							result.weapon_data[field_name] = convert_boolean(field_value)
					--Find firemode name
						elseif field_name == "Fire Mode" then --string
							result.weapon_data[stat_conversion_lookup[field_name]] = field_value
					--Weapon stats table:
						else
							field_value = tonumber(field_value)
							if field_value then 
								local stat_name
								if field_name == "Accuracy" or field_name == "Stability" then 
									result.weapon_data.stats[stat_conversion_lookup[field_name]] = convert_accstab(field_value)
								elseif field_name == "Magazine" or field_name == "Ammo Stock" then
									result.weapon_data[stat_conversion_lookup[field_name]] = field_value
								elseif field_name == "Concealment" then 
									result.weapon_data.stats[stat_conversion_lookup[field_name]] = field_value
								elseif field_name == "Damage" then
									if field_value > 200 then 
										result.weapon_data.stats_modifiers = result.weapon_data.stats_modifiers or {}
										result.weapon_data.stats_modifiers.damage = field_value / 200
										field_value = 200
									end
									result.weapon_data.stats[stat_conversion_lookup[field_name]] = field_value
								elseif field_name == "Threat" then 
									result.weapon_data.stats[stat_conversion_lookup[field_name]] = convert_threat(field_value)
								elseif field_name == "Fire Rate" then 
									result.weapon_data.fire_mode_data = result.weapon_data.fire_mode_data or {}
									result.weapon_data.fire_mode_data.fire_rate = convert_rof(field_value)
								elseif field_name == "Pickup (low)" then 
									result.weapon_data.AMMO_PICKUP = result.weapon_data.AMMO_PICKUP or {}
									result.weapon_data.AMMO_PICKUP[1] = field_value
								elseif field_name == "Pickup (high)" then 
									result.weapon_data.AMMO_PICKUP = result.weapon_data.AMMO_PICKUP or {}
									result.weapon_data.AMMO_PICKUP[2] = field_value
								elseif field_name == "Total Ammo" or field_name == "Ammo Stock" then 
									result.weapon_data.AMMO_MAX = field_value
								else 
									olog("Error! Unsupported stat: \"" .. tostring(field_name) .. "\" in \"" .. line .. "\"")
									if BREAK_ON_UNSUPPORTED_STAT then 
										return
									end
									invalid = true
--									table.insert(found_unstable_fields,key)
								end
							else
								olog("Error! Unable to parse stat value \"" .. tostring(split[2]) .. "\" in \"" .. line .. "\"!")
								if BREAK_ON_ERROR then 
									return
								end
								invalid = true
							end
						end
					end
				end
			end
		end
		
		if not invalid then 
			table.insert(all_results,#all_results+1,result)
		end
		return all_results
	end	
end


--given a table of weapon stats, pick and sort them into the correct location
--then returns a printable output table
local function sort_write_data (data,weapon_id)

	local wtd = weapon_id and tweak_data.weapon[weapon_id] or DEFAULT_WEAPON_STATS
	local default_stats = DEFAULT_WEAPON_STATS.stats
	--not all stats are accounted for in the spreadsheet, 
	--though they're not significantly different between weapons (such as alert size)
	data.stats.zoom = wtd.stats.zoom or default_stats.zoom
	data.stats.total_ammo_mod = wtd.stats.total_ammo_mod or 21 --there is no total_ammo_mod in ba sing se
	data.stats.alert_size = wtd.stats.alert_size or default_stats.alert_size
	data.stats.spread_moving = wtd.stats.spread_moving or default_stats.spread_moving
	data.stats.value = wtd.stats.value or default_stats.value
	data.stats.extra_ammo = wtd.stats.extra_ammo or default_stats.extra_ammo --101 is the new lookup index for 0 extra total ammo; in base-game, it is 51, which only allows for increments of 2
	data.stats.reload = wtd.stats.reload or default_stats.reload


	local output = {}
	local weapontype_order = sort_order[mode]
	local order = weapontype_order[1]
	local stat_orders = weapontype_order[2]
	
	local prefix = ""
	if INCLUDE_PREFIX then
		if mode == 1 then
			prefix = "self." .. weapon_id .. "."
		elseif mode == 2 then 
			prefix = "self.melee_weapons." .. weapon_id .. "."
		end
	end
	
	for i,key in ipairs(order) do 
		
		--trailing commas are optional in lua but i personally can't stand them
		--so i'll check for whether or not the item is the last in a list and skip the comma if it is
		local trailing_comma_1 = ""
		if ADD_COMMAS then
			for _i = i+1,#order,1 do 
				local next_key = order[_i]
				if next_key then 
					if data[next_key] then 
						trailing_comma_1 = ","
						break
					end
				end
			end
		end
		if data[key] then 
			local tabstring_1 = string.rep("\t",tab_newline_spaces)
			local value = data[key]

			if type(value) ~= "table" then 
				if type(value) == "string" then 
					table.insert(output,#output+1,tabstring_1 .. prefix .. key .. " = \"" .. value .. "\"" .. trailing_comma_1)
				else
					table.insert(output,#output+1,tabstring_1 .. prefix .. key .. " = " .. value .. trailing_comma_1)
				end
				
			else
				local tabstring_2 = string.rep("\t",tab_newline_spaces + 1)
			
				
				local stat_order = stat_orders[key]
				if not stat_order then
					table.insert(output,#output+1,tabstring_1 .. prefix .. key .. " = {}" .. trailing_comma_1)
					if not ignore_missing_stat_errors[key] then 
						olog("No stat found for " .. key)
					end
				else
					table.insert(output,#output+1,tabstring_1 .. prefix .. key .. " = {")
					
					for j,stat_key in ipairs(stat_order) do 
						
						--check for trailing comma
						local trailing_comma_2 = ""
						if not ADD_COMMAS then
							for _j = j+1,#stat_order,1 do 
								local next_stat_key = stat_order[_j]
								if next_stat_key then 
									if value[next_stat_key] then 
	--									log("Found next stat " .. tostring(next_stat_key) .. " [" .. tostring(value[next_stat_key]) .. "] from current " .. tostring(stat_key) .. " [" .. tostring(value[stat_key]) .. "]")
										trailing_comma_2 = ","
										break
									end
								end
							end
						end
						
						local stat_value = value[stat_key]
						if stat_value then
							if type(stat_key) == "number" then 
								table.insert(output,#output+1,tabstring_2 .. stat_value .. trailing_comma_2)
							else
								table.insert(output,#output+1,tabstring_2 .. stat_key .. " = " .. stat_value .. trailing_comma_2)
							end
						else
							olog("Error: Missing stat " .. tostring(stat_key))
						end
					end
				
					table.insert(output,#output+1,tabstring_1 .. "}" .. trailing_comma_1)
				end

				
			end
			
			
		end
		
	end
	return output
end

local parsed_data = read_input()

if parsed_data then 
	local output_file = io.open(output_filepath,"w+")
	if output_file then
		for _,data in ipairs(parsed_data) do
			local weapon_id = data.weapon_id
			local output = sort_write_data(data.weapon_data,data.weapon_id)
			if output then 
			else
				olog("No weapon data found to convert! :( i'm so hungry please feed me weapon data uwu")
			end
			
			for _,_line in pairs(output) do 
				output_file:write(_line .. "\n")
			end
		end
		
		olog("Finished writing converted data!")
		output_file:flush()
		output_file:close()
	else
		olog("Error writing data to " .. output_filepath .. " (invalid destination file)")
	end
	
end



--[[




sorting order:
	WEAPON:
		primary class
		subclass
		categories
		mag size
		total ammo
		firerate
		
		(stats)
			damage
			acc
			stab
			conceal
			threat (suppression)
		
		pickup low
		pickup high
		
		
	MELEE:
		primary class
		subclasses
		remove weapon movement penalty
		concealment
		knockback_tier
		max damage
		range
		min damage
		
		

--]]