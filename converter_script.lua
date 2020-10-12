--(Un)Official Crackdown Weapon Converter Tool v1.1
--	For help/reporting bugs/etc, contact me on Discord.

--todo: 
--	organize fields so that they're in a set order?
--	search option to find weapons or attachments by their localized names?
--	attachment conversion tool?
--	melee conversion tool?

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

--	Also, this doesn't try to read the notes in the doc or add the throwables/melees/weapon attachments. You may need a to do those by hand or use a separate tool.
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



----------------------
--     OPTIONS      --
----------------------

--only used for the below two filepaths; change it accordingly if you intend to change the folder name
--or if you just want to change the destination path
local mod_path = "mods/Crackdown-Weapon-Spreadsheet-Converter/"

--where the data to be read is located and what is called
local input_filepath = mod_path .. "INPUT.txt"

--where the processed data to be saved is called
local output_filepath = mod_path .. "OUTPUT.txt"

--All text output will have this many tabs prepended to it-
--(as in "\t", the formatting character from pressing Tab)
local TAB_OFFSETS = 2

--The number of newlines (empty lines) between distinct weapon entries,
--added to the bottom of every entry.
--Set to 0 or below to disable entirely.
local NEWLINE_OFFSETS = 2


--If true,
--	writes the table for spread (standing, crouching, steelsight, move/stand,move/crouch,move/steelsight) 
--	and the table for kick (standing, crouching, steelsight).
local WRITE_FILLER_TABLES = true

--If true, writes the name of the weapon at the top of the weapon data block
-- in a Lua comment (like this one!) which will be saved and legible in the document by human eyes, but ignored by the compiler.
--This also uses your game's localization, so it'll be in your game's language. 
-- Also, make sure you don't have any mods that change weapon names.
--I mean, unless you WANT everyone to know you renamed the Blaster 9mm to the AssBlaster 69mm.
--Hey, I ain't judging.
local WRITE_WEAPON_NAME_COMMENT = false

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
local weapon_data_template = {
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
		extra_ammo = 51, --don't worry about this
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

ID: x_tec9
Accuracy: 52
Class: Rapid Fire
Stability: 100
Magazine: 40
Concealment: 30
Ammo Stock: 320
Threat: 10
Fire Rate: 896
Pickup (low): 8
Damage: 50
Pickup (high): 16

ID: sub2000
Accuracy: 100
Class: Precision
Stability: 12
Magazine: 33
Concealment: 30
Ammo Stock: 66
Threat: 10
Fire Rate: 706
Pickup (low): 3
Damage: 160
Pickup (high): 4


--]]
--[[
				--Akimbo Blaster 9mm Submachine Guns--
self.x_tec9.CLIP_AMMO_MAX = 40
self.x_tec9.fire_mode_data = {
		fire_rate = 0.066964285714286
}
self.x_tec9.stats = {
		concealment = 30,
		suppression = 10,
		reload = 1,
		extra_ammo = 1,
		spread = 14,
		spread_moving = 1,
		recoil = 26,
		value = 1,
		alert_size = 1,
		damage = 50,
		total_ammo_mod = 1,
		zoom = 1
}
self.x_tec9.AMMO_MAX = 320
self.x_tec9.primary_class = "rapidfire"
self.x_tec9.AMMO_PICKUP = {
		pickup_high = 16,
		pickup_low = 8
}
self.x_tec9.spread = {
	standing = self.new_m4.spread.standing,
	crouching = self.new_m4.spread.crouching,
	steelsight = self.new_m4.spread.steelsight,
	moving_standing = self.new_m4.spread.moving_standing,
	moving_crouching = self.new_m4.spread.moving_crouching,
	moving_steelsight = self.new_m4.spread.moving_steelsight
}
self.x_tec9.kick = {
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


				--Cavity 9mm--
self.sub2000.CLIP_AMMO_MAX = 33
self.sub2000.fire_mode_data = {
		fire_rate = 0.084985835694051
}
self.sub2000.stats = {
		concealment = 30,
		suppression = 10,
		reload = 1,
		extra_ammo = 1,
		spread = 26,
		spread_moving = 1,
		recoil = 4,
		value = 1,
		alert_size = 1,
		damage = 160,
		total_ammo_mod = 1,
		zoom = 1
}
self.sub2000.AMMO_MAX = 66
self.sub2000.primary_class = "precision"
self.sub2000.AMMO_PICKUP = {
		pickup_high = 4,
		pickup_low = 3
}
self.sub2000.spread = {
	standing = self.new_m4.spread.standing,
	crouching = self.new_m4.spread.crouching,
	steelsight = self.new_m4.spread.steelsight,
	moving_standing = self.new_m4.spread.moving_standing,
	moving_crouching = self.new_m4.spread.moving_crouching,
	moving_steelsight = self.new_m4.spread.moving_steelsight
}
self.sub2000.kick = {
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

local td_prefix = "self." --"self" here represents "tweak_data.weapon"

local classes = {
	["Rapid Fire"] = "rapidfire",
	["Shotgun"] = "class_shotgun", --to distinguish it from the weapon category upgrades- we don't want those applying twice
	["Precision"] = "precision",
	["Heavy"] = "heavy",
	["Specialist"] = "specialist",
	["Saw"] = "saw",
	["Grenade"] = "grenade",
	["Throwing"] = "throwing", --deliberately NOT "throwable"
	["Melee"] = "melee"	
}
local subclasses = {
	["Quiet"] = "quiet",
	["Poison"] = "poison",
	["Area Denial"] = "areadenial"
}

local valid_keys = {
	["ID"] = "weapon_id",
	["Accuracy"] = "spread", --stats table
	["Class"] = "class",
	["Stability"] = "recoil", --stats table
	["Magazine"] = "CLIP_AMMO_MAX",
	["Concealment"] = "concealment", --stats table
	["Ammo Stock"] = "AMMO_MAX",
	["Threat"] = "suppression", --stats table
	["Fire Rate"] = "fire_rate", --firemode-dependent table/fire_mode_data table
	["Pickup (low)"] = "pickup_low", --AMMO_PICKUP table
	["Pickup (high)"] = "pickup_high", --AMMO_PICKUP table
	["Damage"] = "damage", -- stats table; require damage multiplier to stats_modifiers table if above 200
--the below are functional but never used, so they won't generate unless you add them to the weapon_data_template table
	["Can Toggle Firemode"] = "CAN_TOGGLE_FIREMODE", --boolean value!
	["Fire Mode"] = "FIRE_MODE",
	["Shield Piercing"] = "can_shoot_through_shield",
	["Enemy Piercing"] = "can_shoot_through_enemy",
	["Wall Piercing"] = "can_shoot_through_wall"
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
	if tweak_data and tweak_data.weapon and managers and managers.localization and managers.localization then 
		 local td = tweak_data.weapon[weapon_id]
		 if td then 
			return managers.localization:text(td.name_id)
		 end
	end
	return tostring(weapon_id)
end

local function convert_rof(rpm) --converts rounds per minute to seconds per round
	local rounds_per_second = rpm / 60
	return 1 / rounds_per_second --could just do 60/n to save time and space but i'd rather waste even more time and space by leaving this comment saying that i'm not going to do that
end

local function convert_accstab(stat) --converts acc/stab from a [0-100] value to the weird internal multiple of 4 stat thing pd2 has going on
	return (stat + 4) / 4
end

local function convert_threat(input)
	return input / 2
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

	local result = table.deep_map_copy(weapon_data_template)
	local found_unstable_fields = {}

	local weapon_id
	
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
								result = table.deep_map_copy(weapon_data_template)
								all_results[weapon_id] = {result = result,found_unstable_fields = found_unstable_fields}
								found_unstable_fields = {}
							end
						elseif key == "Class" then  --this is currently the only non-number value supported aside from weapon_id and FIRE_MODE
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
						elseif key == "Fire Mode" then
							result[valid_keys[key]] = val
						elseif key == "Can Toggle Firemode" then --bool
							result[valid_keys[key]] = convert_boolean(val)
						elseif key == "Shield Piercing" then --bool
							result[valid_keys[key]] = convert_boolean(val)
						elseif key == "Enemy Piercing" then --bool; aka overpenetration
							result[valid_keys[key]] = convert_boolean(val)
						elseif key == "Wall Piercing" then --bool
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
	
	for weapon_id,all_results_data in pairs(all_results) do 
		local found_unstable_fields = all_results_data.found_unstable_fields
		local result = all_results_data.result
		
		if WRITE_WEAPON_NAME_COMMENT then 
			local weapon_name_localized = weapon_id
			if tweak_data.weapon[weapon_id] then 
				weapon_name_localized = get_weapon_name(weapon_id)
			end
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
				if datatype == "string" then 
					output(string.rep("\t",TAB_OFFSETS) .. weapon_prefix .. " = \"" .. data .. "\"")
				else
					output(string.rep("\t",TAB_OFFSETS) .. weapon_prefix .. " = " .. tostring(data))
				end
			elseif not table.empty(data) then 
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