
--(Un)Official Crackdown Weapon Converter Tool v2.1
--	For help/reporting bugs/etc, contact me on Discord.

--todo: 
--	organize fields so that they're in a set order?
--	search option to find weapons or attachments by their localized names?
--	attachment conversion tool?

-------------------------------------
--        ABOUT THIS SCRIPT        --
-------------------------------------
--	This script was written by Offy to save people some time (hopefully) and carpal tunnel progression.
--	It is designed to read and convert weapon data from the tables in Kith's weapon docs to a Lua format that can be read by PAYDAY 2.
--	The script is run via a keybind, and reads information from a file with a name and location that you specify. 
--	There are several options, which you can find below, as well as some usage instructions, but please feel free to contact me for assistance.

--	Side note: technically, you could run this from any Lua IDE- the only thing it really depends on PAYDAY 2 for are
--	the localization manager function and the weapontweakdata to get the localized weapon names, and the methods table.deep_map_copy(), table.empty(), and string.split, which are not part of the standard Lua library.
--	If you're so inclined, you can define that and redirect the output log/file paths.

--	Also, this doesn't try to read the notes in the doc or add the throwables/weapon attachments. You may need a to do those by hand or use a separate tool.
--	This tool is not for attachments and also does not know how to interpret the English language, though that would be pretty handy.

--	P.S. Since it writes to disk and operates on a keybind, I recommend binding it to something you won't accidentally press during gameplay, 
--	and/or not having it installed for normal gameplay sessions.



-------------------------------------
--    INSTALLATION INSTRUCTIONS:   --
-------------------------------------
--1. Drag the Crackdown Weapon Spreadsheet Converter folder into your mods folder
--2. Launch the game
--3. Bind a key in the Mod Options menu to run the script



-------------------------------------
--       USAGE INSTRUCTIONS:       --
-------------------------------------
--0. Make sure the mode variable (below) is set to "melee" or "weapon", according to if your data comes from a melee weapon or a main weapon (gun).
--1. Open INPUT.txt (or whatever file you specify in the input_filepath option below)
--2. Paste in one or more* formatted table data sets from one of Kith's Crackdown weapons spreadsheets; it should look like the example (scroll down, see: EXAMPLE INPUT DATA)
-- *This converter script also supports pasting multiple stat blocks in at the same time, delimited by weapon_ids;
--	If you do, just make sure that ID is at the beginning or end of each block of weapon data in your input!
--	Newlines and spaces will NOT matter to the input reader!
--	Also, the weapons in the output (as well as the stats in each weapon's data block) may not be in 
-- 	 exactly the same order as the order in your input.
--	However, all the data for a weapon should still be clumped together in a block.

--3. SAVE THE FILE! This is very important. This script reads from the disk, so it can only see the latest saved version of the script, not unsaved changes in your text editor.
--4. Press the keybind to run the script. This should generate lua-formatted data at the path you specify;
--		by default, this should be in the same folder as this script,
--		in a file called "OUTPUT.txt". (I didn't include it in the download since it's generated automatically upon keybind, and overwritten each run after that.)
--		You can change the name or path of this file if you want.
--5. Copy your data out of that output file. The output file's entire contents are overwritten when you run the script,
--		so I recommend either doing batch processing (see Step 2 above) all at once and then copying out the results, or 
--		just being extra-sure not to assume that the contents of the previous weapon will still be there when you run the script again.

--Gimmick melee weapons will need to have their effects (and potentially stats, for some artifacts like dot_data) set/written manually,
--but their stats can still be set here.

----------------------
--     OPTIONS      --
----------------------

--if "melee", then it is set to use the melee weapon stat keys;
--else if "weapon", or else unspecified, then uses the normal gun stat keys
local mode = "weapon"

--only used for the below two filepaths; change it accordingly if you intend to change the folder name
--or if you just want to change the destination path
local mod_path = "mods/Crackdown-Weapon-Spreadsheet-Converter/"

--where the data to be read is located and what is called
local input_filepath = mod_path .. "INPUT.txt"

--where the processed data to be saved is called
local output_filepath = mod_path .. "OUTPUT.txt"

--All text output will have this many tabs prepended to it-
--(as in "\t", the formatting character from pressing Tab)
local TAB_OFFSETS = 1


--The number of newlines (empty lines) between distinct weapon entries,
--added to the bottom of every entry.
--Set to 0 or below to disable entirely.
local NEWLINE_OFFSETS = 2


--If true,
-- writes each entry as a table instead of overwriting the entire table
--eg. writes
--		self.g32.stats.damage = 69
--		stats.recoil = 32
--instead of 
--g32.stats = {
--	damage = 69,
--	recoil = 32
--}
local WRITE_INDIVIDUAL_TABLE_ENTRIES = false

--If true,
--	writes tables that are specified but don't have any data.
--This is useful for inserting things that are intentionally empty (such as a subclasses table, if the weapon does not have any subclasses)
--	but this can overwrite existing tables, so use with caution.
local INCLUDE_EMPTY_TABLES = true

--If true,
--	writes the table for spread (standing, crouching, steelsight, move/stand,move/crouch,move/steelsight) 
--	and the table for kick (standing, crouching, steelsight).
local WRITE_FILLER_TABLES = mode == "weapon"

--If true, writes the name of the weapon at the top of the weapon data block
-- in a Lua comment (like this one!) which will be saved and legible in the document by human eyes, but ignored by the compiler.
--This also uses your game's localization, so it'll be in your game's language. 
-- Also, make sure you don't have any mods that change weapon names.
--I mean, unless you WANT everyone to know you renamed the Blaster 9mm to the AssBlaster 69mm.
--Hey, I ain't judging.
local WRITE_WEAPON_NAME_COMMENT = true 

--If true, cancels conversion and writes a message to the SBLT Console upon encountering any unexpected/unknown stat from input
local BREAK_ON_UNSUPPORTED_STAT = false

--If true, cancels conversion and writes a message to the SBLT Console upon encountering an error
local BREAK_ON_ERROR = true

--If true, allows ordered/indexed pairs (sequential table indices 1,2,3 etc) to be invisible since they're implied by the value order
--I don't think tweakdata uses this so you can probably leave it
local ALLOW_IMPLIED_NUMBER_INDICES = true

local LOG_RESULT_TO_BLT = false
--If true, also writes to the SBLT Console everything that it writes to the output file.

--You can add default tweakdata values to this table; they'll be overwritten or used, depending on whether your input contains an entry for that field
local gun_data_template = {
	primary_class = nil,
	subclasses = {},
	fire_mode_data = {},
	AMMO_PICKUP = {
		1,
		2
	},
	stats = {
		damage = 69,
		spread = 69,
		recoil = 69,
		suppression = 69,
		concealment = 69,
--the stats below aren't defined in the expected formatted input from the doc; you will need to change these manually.
--(I recommend doing that BEFORE you start processing weapons.)
		spread_moving = 1,
		value = 1, --cost?
		extra_ammo = 101, --don't worry about this
		total_ammo_mod = 21, --or this
		alert_size = 7,
		zoom = 1,
		reload = 11 --doesn't affect anything
	},
--[[ you can uncomment any of these (remove them from the block-commented section) in order to enable generating them with default values. also uncomment them if you plan to convert them through input
	single = {
		fire_rate = 1
	},
	auto = {
		fire_rate = 1
	},
	timers = {
		reload_not_empty = 1,
		reload_empty = 1,
		unequip = 1,
		equip = 1
	},
	FIRE_MODE = "single",
	CAN_TOGGLE_FIREMODE = false,
	NR_CLIPS_MAX = 1, --only used for reference to calculate the actually used value AMMO_MAX afaik; try not to use this
	can_shoot_through_enemy = false,
	can_shoot_through_shield = false,
	can_shoot_through_wall = false,
	panic_suppression_chance = 0,
	armor_piercing_chance = 0,
--stats_modifiers = {damage = 1}, --commented out because damage stat mult is done by this script automatically if damage exceeds 200, but you could add it if you wanted
	
--]]
}
local melee_data_template = {
	primary_class = "class_melee",
	subclasses = {},
	stats = {
		remove_weapon_movement_penalty = true,
		min_damage = 3,
		max_damage = 8,
--		min_damage_effect = 1,
--		max_damage_effect = 1,
		charge_time = 2,
		range = 185,
		concealment = 30
	},
	--below three stats not yet implemented
--	repeat_expire_t = 0.6,
--	expire_t = 1.2,
--	melee_damage_delay = 0.1,
}
--unchanged and therefore inherited from original; here for reference, and not used in the converter script

--[[
local unchanged_melee_data = {
	type = "knife", --"knife", "axe", "flag", "fists"
	name_id = "bm_melee_WEAPONID", --naming convention, so unreliable to generate; the id of the localized name
	unit = "units/DLC_PATH/PATH_TO_WEAPON_UNIT",
	third_unit = "units/DLC_PATH/PATH_TO_3P_WEAPON_UNIT",
	animation = nil, 
	hit_pre_calculation = true,
	dlc = "bex",
	texture_bundle_folder = "bex",
	weapon_type = "sharp", --"blunt" or "sharp"
	melee_charge_shaker = "player_melee_charge_wing",
	align_objects = {
		"a_weapon_right"
	},
	anims = {
		var1_attack = {
			anim = "var1"
		},
		var2_attack = {
			anim = "var2"
		},
		charge = {
			loop = false,
			anim = "charge"
		}
	},
	anim_global_param = "melee_knife",
	anim_attack_vars = {
		"var1",
		"var2",
		"var3",
		"var4"
	},
	sounds = {
		equip = "WEAPONID_equip",
		hit_air = "WEAPONID_air",
		hit_gen = "WEAPONID_gen",
		hit_body = "WEAPONID_body",
		charge = "WEAPONID_charge"
	},
	dot_data = {
		type = "poison",
		custom_data = {
			dot_length = 3,
			hurt_animation_chance = 0
		}
	}
}
]]

local filler_melee_data_template = { --not used
	[[
	
	]]
}

--These are other things that sure are generated which reference other table values in weapontweakdata,
-- so I'm just writing string literals to paste in wholesale. You could change them if you really wanted (though I don't think they're used);
-- this is really just for saving you a few ctrl-c/ctrl-v strokes
local filler_weapon_data_template = {
--old spread values based off of new_m4, as usual. change the new_m4 reference if you like. (WEAPONPREFIX is substituted for the weapon_id you're using.)
[[WEAPONPREFIX.spread = {
	standing = self.new_m4.spread.standing,
	crouching = self.new_m4.spread.crouching,
	steelsight = self.new_m4.spread.steelsight,
	moving_standing = self.new_m4.spread.moving_standing,
	moving_crouching = self.new_m4.spread.moving_crouching,
	moving_steelsight = self.new_m4.spread.moving_steelsight
}
WEAPONPREFIX.kick = {
	standing = {
		3,
		4.8,
		-0.3,
		0.3
	},
	crouching = {
		3,
		4.8,
		-0.3,
		0.3
	},
	steelsight = {
		3,
		4.8,
		-0.3,
		0.3
	}
}]]
}



--[[EXAMPLE INPUT DATA (extra spaces or empty newlines are okay; multiple weapons at a time are also okay, as shown)

ID: m95
Accuracy: 100
Class: Heavy
Stability: 0
Magazine: 5
Concealment: 0
Ammo Stock: 20
Threat: 43
Fire Rate: 40
Pickup (low): 0.25
Damage: 3500
Pickup (high): 0.5

Properties: Armor Piercing, Body Piercing, Shield Piercing

--]]
--[[ EXAMPLE OUTPUT DATA (ready for copypasting)

		self.m95.CLIP_AMMO_MAX = 5
		self.m95.fire_mode_data = {
			fire_rate = 1.5
		}
		self.m95.stats_modifiers = {
			damage = 17.5
		}
		self.m95.can_shoot_through_shield = true
		self.m95.stats = {
			concealment = 0,
			suppression = 21.5,
			reload = 11,
			extra_ammo = 51,
			spread_moving = 1,
			spread = 26,
			recoil = 1,
			value = 1,
			alert_size = 7,
			damage = 200,
			total_ammo_mod = 21,
			zoom = 1
		}
		self.m95.armor_piercing_chance = 1
		self.m95.can_shoot_through_enemy = true
		self.m95.can_shoot_through_wall = true
		self.m95.AMMO_PICKUP = {
			0.25,
			0.5
		}
		self.m95.primary_class = "heavy"
		self.m95.AMMO_MAX = 20
		self.m95.spread = {
			standing = self.new_m4.spread.standing,
			crouching = self.new_m4.spread.crouching,
			steelsight = self.new_m4.spread.steelsight,
			moving_standing = self.new_m4.spread.moving_standing,
			moving_crouching = self.new_m4.spread.moving_crouching,
			moving_steelsight = self.new_m4.spread.moving_steelsight
		}
		self.m95.kick = {
			standing = {
				3,
				4.8,
				-0.3,
				0.3
			},
			crouching = {
				3,
				4.8,
				-0.3,
				0.3
			},
			steelsight = {
				3,
				4.8,
				-0.3,
				0.3
			}
		}



--]]


---------- You shouldn't NEED to change anything below here, but hey, mi casa es su casa, right?

local weapon_td_prefix = "self." --"self" here represents "tweak_data.weapon"
local melee_td_prefix = "self.melee_weapons." --"self" here represents "tweak_data.blackmarket"

local classes = {
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

local valid_keys = {
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
	["Wall Piercing"] = "can_shoot_through_wall", --boolean flag (not really used)
	["Properties"] = "properties" --placeholder/reference; should not be used
--the below stat values aren't used and may not be fully functional
--since this script is deliberately designed to convert values copypasted from the doc,
--the script only explicitly supports stats that are listed on the doc.
--contact me if you want support for these
--[[
	["Reload"] = "reload", --stats table
	["Value"] = "value", --stats table
	["Alert Size"] = "alert_size", --stats table
	["Zoom"] = "zoom", --stats table
	["Total Ammo"] = "total_ammo_mod", --stats table
	["Reload (Empty)"] = "reload_empty", --timers table
	["Reload (Not Empty)"] = "reload_not_empty", --timers table
	["Unequip"] = "unequip", --timers table
	["Equip"] = "equip" --timers table
--]]
}



--Here be dragons... DON'T LOOK AT ME I'M HIDEOUS

local function olog(s)
	log("**** Offy's very cool crakdoughnut (tm) spreadsheet-info-to-formatted-weapon-tweakdata-lua converter ****: " .. s)
end

local queued_write = {}
local function output(outputme)
	if LOG_RESULT_TO_BLT then
		log(outputme)
	end
	
	--save to an ordered table, to be written and flushed at the end of the read+parse operation
	table.insert(queued_write,#queued_write + 1,outputme)
end

local function sort_tbl(_tbl)
	local len_tbl = {}
	for a,b in ipairs(_tbl) do 
		table.insert(len_tbl,#len_tbl + 1,a)
	end
	for a,b in pairs(_tbl) do 
		if not table.contains(len_tbl,a) then 
			table.insert(len_tbl,#len_tbl + 1,a)
		end
	end
	return len_tbl
end
local function OutputTable(tbl,tab_offset,prefix,no_commas)
	tab_offset = tab_offset or 0
	if type(tbl) ~= "table" then 
		local s = string.rep("\t",tab_offset) .. tostring(prefix or "")
		if type(tbl) == "string" then 
			s = s .. "\"" .. tbl .. "\""
		else
			s = s .. tostring(tbl)
		end
		if not no_commas then 
			s = s .. ","
		end
		output(s)
		return
	end
	
	local table_ordered_by_key = sort_tbl(tbl)
	local table_length = #table_ordered_by_key
	local output_tbl = {}
	for i,key in ipairs(table_ordered_by_key) do 
		local data = tbl[key]
		local key_name 
		if type(key) == "number" then 
			key_name = "[" .. tostring(key) .. "] = "
		else
			key_name = tostring(key) .. " = "
		end
		if (i == key) and ALLOW_IMPLIED_NUMBER_INDICES then 
			key_name = ""
		end
		local s = ""
		if type(data) == "table" then
			if not no_commas then 
				output(string.rep("\t",tab_offset) .. key_name .. "{")
				OutputTable(data,tab_offset+1)
				s = string.rep("\t",tab_offset) .. "}"
			end
		else
			s = string.rep("\t",tab_offset)
			if prefix then 
				s = s .. prefix
			end
			s = s .. key_name
			if type(data) == "string" then 
				s = s .. "\"" .. data .. "\""
			else
				s = s .. tostring(data)
			end
		end
		if s then 
			if i < table_length then 
				s = s .. ","
			end
			output(s)
		end
	end
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

local function get_weapon_name(weapon_id)
	if tweak_data and managers and managers.localization and managers.localization then 
		if mode == "melee" then 
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
	local THREAT_ROUND_UP = true
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

local all_results = {} --used to hold all results, with an individual child table for each weapon processed

local input_file = io.open(input_filepath,"r")
if input_file then 
	local result 
	local found_unstable_fields = {}
	local weapon_id
	local td_prefix
	if mode == "melee" then 
		td_prefix = melee_td_prefix
		local line_num = 0
		for raw_line in input_file:lines() do 
			line_num = line_num + 1
			local line = remove_extra_spaces(raw_line) 
			if line ~= "" then 
				local split = string.split(line,":")
				if not (split[1] and split[2]) then 
					olog("Error! Invalid formatting in line#" .. (line_num or "nil") .. ": \"" .. line .. "\"")
				else
					local key = remove_extra_spaces(split[1])
					local val = remove_extra_spaces(split[2])
					if key == "ID" then
						weapon_id = remove_extra_spaces(val)
						if weapon_id then 
							result = table.deep_map_copy(melee_data_template)
							all_results[weapon_id] = {result = result,found_unstable_fields = found_unstable_fields}
							found_unstable_fields = {}
						end
					elseif weapon_id then 
						if val == "nil" then 
						else
							val = tonumber(val)
						end
						if key == "Damage" then 
							result.stats.min_damage = val / 10
						elseif key == "Charged Damage" then 
							result.stats.max_damage = val / 10
						elseif key == "Charge Time" then 
							result.stats.charge_time = val
						elseif key == "Knockback" then 
							result.stats.knockback_tier = val --used in cd only
--							result.stats.min_damage_effect = val / 10
--							result.stats.max_damage_effect = val / 10
						elseif key == "Range" then  --range on the docs is in meters, but internally it is centimeters
							result.stats.range = val * 100
						elseif key == "Concealment" then 
							result.stats.concealment = val
							
							--not implemented yet
						elseif key == "Repeat Delay" then 
							result.repeat_expire_t = val
						elseif key == "Damage Delay" then 
							result.melee_damage_delay = val
						elseif key == "Expire Time" then 
							result.expire_t = val
						else
							olog("Error! Unable to parse stat value \"" .. tostring(split[2]) .. "\" in \"" .. line .. "\"!")
							if BREAK_ON_ERROR then 
								return
							end
						end
						
						
					end
				end
			end
		end
	else
		td_prefix = weapon_td_prefix
		result = table.deep_map_copy(gun_data_template)
		for raw_line in input_file:lines() do 
			local line = remove_extra_spaces(raw_line)
			if line ~= "" then 
				local split = string.split(line,":")
				if split and #split > 0 then 
					if not (split[1] and split[2]) then 
						olog("Error! Invalid formatting in line #" .. (line_num or "nil") .. ": \"" .. line .. "\"")
					else
						local key = split[1]
						key = remove_extra_spaces(key)
						local val = split[2]
						val = remove_extra_spaces(val)
						if valid_keys[key] then 
							if key == "ID" then 
								weapon_id = remove_extra_spaces(val)
								if weapon_id then 
									result = table.deep_map_copy(gun_data_template)
									all_results[weapon_id] = {result = result,found_unstable_fields = found_unstable_fields}
									found_unstable_fields = {}
								end
							elseif key == "Class" then --string
								local function add_weapon_class(_classname)
									local classname = remove_extra_spaces(_classname)
									if classes[classname] then 
										result.primary_class = classes[classname]
									elseif subclasses[classname] then 
										table.insert(result.subclasses,subclasses[classname])
									else
										olog("Error! Unknown class name \"" .. tostring(classname) .. "\" in \"" .. line .. "\"!")
										if BREAK_ON_ERROR then 
											return
										end
									end
								end
								if string.find(val,",") then
									for _,_classname in pairs(string.split(val,",") or {}) do 
										add_weapon_class(_classname)
									end
								else
									add_weapon_class(val)
								end
							elseif key == "Fire Mode" then --string
								result[valid_keys[key]] = val
							elseif key == "Properties" then -- various (formatted in one line in the document)
								local properties = string.split(val,",")
								for _,_property in pairs(properties) do 
									local property = remove_extra_spaces(_property)
									if property == "Armor Piercing" then
										result[valid_keys[property]] = 1
									elseif property == "Body Piercing" then 
										result[valid_keys[property]] = true
									elseif property == "Wall Piercing" or property == "Shield Piercing" then  --shield and wall piercing are the same in the overhaul
										result.can_shoot_through_wall = true
										result.can_shoot_through_shield = true
									else
										olog("Error: Unknown property " .. tostring(property))
										if BREAK_ON_UNSUPPORTED_STAT then 
											return
										end
									end
								end
							elseif key == "Can Toggle Firemode" then --bool
								result[valid_keys[key]] = convert_boolean(val)
							else
								val = tonumber(val)
								if val then 
									if key == "Accuracy" or key == "Stability" then 
										result.stats[valid_keys[key]] = convert_accstab(val)
									elseif key == "Magazine" or key == "Ammo Stock" then
										result[valid_keys[key]] = val
									elseif key == "Concealment" then 
										result.stats[valid_keys[key]] = val
									elseif key == "Damage" then
										if val > 200 then 
											result.stats_modifiers = result.stats_modifiers or {}
											result.stats_modifiers.damage = val / 200 
											val = 200
										end
										result.stats[valid_keys[key]] = val
									elseif key == "Threat" then 
										result.stats[valid_keys[key]] = convert_threat(val)
									elseif key == "Fire Rate" then 
										result.fire_mode_data.fire_rate = convert_rof(val)
									elseif key == "Pickup (low)" then 
										result.AMMO_PICKUP[1] = val
									elseif key == "Pickup (high)" then 
										result.AMMO_PICKUP[2] = val
									else 
										if BREAK_ON_UNSUPPORTED_STAT then 
											olog("Error! Unsupported stat: \"" .. tostring(key) .. "\" in \"" .. line .. "\"")
											return
										end
										table.insert(found_unstable_fields,key)
									end
								else
									olog("Error! Unable to parse stat value \"" .. tostring(split[2]) .. "\" in \"" .. line .. "\"!")
									if BREAK_ON_ERROR then 
										return
									end
								end
							end
						else
							olog("Error! Invalid field name \"" .. tostring(key) .. "\" in \"" .. line .. "\"!")
							if BREAK_ON_ERROR then 
								return
							end
						end
					end
				end
			end
		end
	end
	for weapon_id,all_results_data in pairs(all_results) do 
		local found_unstable_fields = all_results_data.found_unstable_fields
		local result = all_results_data.result
		
		if WRITE_WEAPON_NAME_COMMENT then 
			local weapon_name_localized = get_weapon_name(weapon_id)
			output(string.rep("\t",2 + TAB_OFFSETS) .. "--" .. weapon_name_localized .. "--")
		end
		
		for key,data in pairs(result) do 
			local weapon_prefix = td_prefix .. tostring(weapon_id)
			if type(key) == "number" then 
				weapon_prefix = weapon_prefix .. "[" .. key .. "]"
			else
				weapon_prefix = weapon_prefix .. "." .. key
			end
			local datatype = type(data)
			if datatype ~= "table" then 
				if datatype == "string" and data ~= "nil" then
					output(string.rep("\t",TAB_OFFSETS) .. weapon_prefix .. " = \"" .. data .. "\"")
				else
					output(string.rep("\t",TAB_OFFSETS) .. weapon_prefix .. " = " .. tostring(data))
				end
			else
				local is_empty = table.empty(data)
				
			
				if WRITE_INDIVIDUAL_TABLE_ENTRIES and not is_empty then
					for m,n in pairs(data) do 
						if type(n) ~= "table" then 
							output(string.rep("\t",TAB_OFFSETS) .. weapon_prefix .. "." .. tostring(m) .. " = " .. tostring(n))
						else
							olog("WARNING: Subtables are not fully supported in WRITE_INDIVIDUAL_TABLE_ENTRIES")
							OutputTable(data,TAB_OFFSETS + 1,prefix)
						end
					end
				elseif not is_empty or INCLUDE_EMPTY_TABLES then 
					output(string.rep("\t",TAB_OFFSETS) .. weapon_prefix .. " = {")
					local tbl_len = sort_tbl(data)
					local i = 0
					local ordered = true
					for _key,_data in pairs(data) do 
						i = i + 1
						local prefix 
						if ordered and (i ~= _key) then 
							ordered = false
						end
						if (type(_key) == "number") then 
							if not (ordered and ALLOW_IMPLIED_NUMBER_INDICES) then 
								prefix = "[" .. _key .. "]" .. " = "
							end
						else
							ordered = false
							prefix = _key .. " = " 
						end
						if i >= #tbl_len then 
							OutputTable(_data,TAB_OFFSETS + 1,prefix,true)
						else
							OutputTable(_data,TAB_OFFSETS + 1,prefix)
						end
					end
					output(string.rep("\t",TAB_OFFSETS) .. "}")
				end
			end
		end
		
		if WRITE_FILLER_TABLES then 
			for _,filler_line in pairs(filler_weapon_data_template) do 
				local s = string.rep("\t",TAB_OFFSETS) .. string.gsub(filler_line,"\n","\n" .. string.rep("\t",TAB_OFFSETS))
				output(string.gsub(s,"WEAPONPREFIX",td_prefix .. tostring(weapon_id)))
			end
		end
		if #found_unstable_fields > 0 then 
			olog("Caution- potentially unsupported fields found! Please double-check in your output that the following values are valid:")
			for _,field in pairs(found_unstable_fields) do 
				olog(field)
			end
			olog("(/END UNSUPPORTED FIELDS)")
		end
		
		if NEWLINE_OFFSETS > 0 then 
			output(string.rep("\n",NEWLINE_OFFSETS - 1)) --offsets the other newline i put in automatically 
		end
	end
else
	olog("Error: Input file at \"" .. tostring(input_filepath) .. tostring(input_filename) .. "\" was not found")
	return
end

if not table.empty(queued_write) then 
	local output_file = io.open(output_filepath,"w+")
	if output_file then
		for _,_line in pairs(queued_write) do 
			output_file:write(_line .. "\n")
		end
		olog("Finished writing converted data!")
		output_file:flush()
		output_file:close()
	else
		olog("Error writing data to " .. output_filepath .. (result and ("for " .. get_weapon_name(result and result.weapon_id)) or "") .. "(invalid destination file)")
	end
else
	olog("No weapon data found to convert! :( i'm so hungry please feed me weapon data uwu")
end

































