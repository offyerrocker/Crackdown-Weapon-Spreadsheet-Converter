--requires string.split() from PAYDAY 2's string util library
--requires table.concat() from PAYDAY 2's table util library
--requires table.deep_map_copy() from PAYDAY 2's table util library
--requires tweak_data.weapon table (WeaponTweakData) from PAYDAY 2 ( lib/tweak_data/weapontweakdata )



local WIPE_PREVIOUS_STATS = true

local PRIMARY_CLASS_NAME_LOOKUP = {
--yes i wrote it this way on purpose
	[utf8.to_lower("Rapid Fire")] = "class_rapidfire",
	[utf8.to_lower("Shotgun")] = "class_shotgun",
	[utf8.to_lower("Precision")] = "class_precision",
	[utf8.to_lower("Heavy")] = "class_heavy",
	[utf8.to_lower("Specialist")] = "class_specialist",
	[utf8.to_lower("Saw")] = "class_saw",
	[utf8.to_lower("Grenade")] = "class_grenade",
	[utf8.to_lower("Throwing")] = "class_throwing",
	[utf8.to_lower("Melee")] = "class_melee"
}

local VALID_PRIMARY_CLASSES = {
	["class_rapidfire"] = true,
	["class_shotgun"] = true,
	["class_precision"] = true,
	["class_heavy"] = true,
	["class_specialist"] = true,
	["class_saw"] = true,
	["class_grenade"] = true,
	["class_throwing"] = true,
	["class_melee"] = true
}

local SUBCLASS_NAME_LOOKUP = {
	["Quiet"] = "subclass_quiet",
	["Poison"] = "subclass_poison",
	["Area Denial"] = "subclass_areadenial"
}

local VALID_SUBCLASSES = {
	["subclass_quiet"] = true,
	["subclass_poison"] = true,
	["subclass_areadenial"] = true
}

--not used
local VALID_FIREMODES = {
	["auto"] = true,
	["single"] = true
}
local FIREMODE_NAME_LOOKUP = {
	["autofire"] = "auto",
	["singlefire"] = "single",
	["auto fire"] = "auto",
	["single fire"] = "single",
	["auto-fire" ] = "auto",
	["single-fire"] = "single"
}

local function table_concat(tbl,div)
	div = tostring(div or ",")
	if type(tbl) ~= "table" then 
		return "(concat error: non-table value)"
	end
	local str
	for k,v in pairs(tbl) do
		str = str and (str .. div .. tostring(v)) or tostring(v)
	end
	return str or ""
end

function print_tcd_weapon_stats(weapon_id)
	local s = {}
	local function ins(...)
		local tbl = {...}
		if #tbl > 0 then
			local a = table.remove(tbl,1)
			table.insert(s,#s+1,tostring(a) .. "\t" .. table_concat(tbl," "))
		else
			table.insert(s,#s+1,"")
		end
	end
	
	local wtd = tweak_data.weapon[weapon_id]
	ins("weapon_id",weapon_id)
	ins("name_id",wtd.name_id,managers.localization:text(wtd.name_id))
	ins("subclasses",table_concat(wtd.subclasses or {},"; "))
	ins("magazine",wtd.CLIP_AMMO_MAX)
	ins("total_ammo_mod",wtd.stats.total_ammo_mod)
	ins("extra_ammo",wtd.stats.extra_ammo)
	ins("AMMO_MAX ",wtd.AMMO_MAX)
	ins("fire_rate",wtd.fire_mode_data.fire_rate)
	ins("damage",wtd.stats.damage)
	ins("accuracy",wtd.stats.spread)
	ins("stability",wtd.stats.recoil)
	ins("concealment",wtd.stats.concealment)
	ins("suppression",wtd.stats.suppression)
	ins("reload_partial",wtd.timers.reload_not_empty)
	ins("reload_full",wtd.timers.reload_empty)
	ins("equip",wtd.timers.equip)
	ins("unequip",wtd.timers.unequip)
	ins("zoom",wtd.stats.zoom)
	ins("value",wtd.stats.value)
	ins("pickup_low",wtd.AMMO_PICKUP[1])
	ins("pickup_high",wtd.AMMO_PICKUP[2])
	ins("can_pierce_wall",wtd.can_shoot_through_wall)
	ins("can_pierce_enemy",wtd.can_shoot_through_enemy)
	ins("can_pierce_shield",wtd.can_shoot_through_shield)
	ins("armor_piercing_chance",wtd.armor_piercing_chance)
	ins("kick matrix: [ " .. table_concat({wtd.kick.standing[1],wtd.kick.standing[2],wtd.kick.standing[3],wtd.kick.standing[4]}," / ") .. " ]")
	
	
	log("Printing weapon stats for " .. tostring(weapon_id))
	for _,v in ipairs(s) do 
		log(v)
	end
	log("Done printing weapon stats")
end

local weapon_csv_order = {
	"id", --"Weapon ID"
	"name", --"Weapon Name"
	"primary_class", --"Weapon Class"
	"subclasses", --"Subclasses"
	"magazine", --"Mag" (magazine size)
	"total_ammo", --"Total Ammo"
--	"total_ammo_mod",
--	"extra_ammo",
	"fire_rate", --ROF"
	"fire_rate_internal", --"s/R"
--	"firemode",
--	"is_firemode_toggleable",
	"damage", --"DMG"
	"accuracy", --"ACC"
	"spread_internal", --"Spread"
--	"spread_moving",
	"stability", --"STB"
	"recoil_internal", --"Recoil"
	"concealment", --"Conceal"
	"threat", --"Threat"
	"suppression_internal", --"Supp. Index"
	"reload_partial", --"Partial Reload"
	"reload_full", --"Full Reload"
	"equip", --"Equip"
--	"unequip", 
--	"reload",
	"zoom", --"Zoom" (inherited)
	"value", --"Value" (inherited)
	"price_internal", --"Price"
	"pickup_low", --"Pick. Low"
	"pickup_high", --"Pick. High"
--	"alert_size",
	"can_pierce_wall", --"Wall Piercing"
	"can_pierce_enemy", --"Overpenetration"
	"can_pierce_shield", --"Shield Piercing"
	"armor_piercing_chance", --"Armor Piercing"
	"kick_y_min", --"Kick Min-Y"
	"kick_y_max", --"Kick Max-Y"
	"kick_x_min", --"Kick Min-X"
	"kick_x_max" --"Kick Max-X"
}

--generate reverse lookup table from this order
local WEAPON_STAT_INDICES = {}
for i,key in ipairs(weapon_csv_order) do 
	WEAPON_STAT_INDICES[key] = i
end

--[[
local attachment_stat_indices = {
	override_primary_class, --overrides weapon's primary class
	adds_subclasses, --semicolon separated list
	
	sub_type,
	
	perks, --semicolon separated list, can contain any of the following:
--	scope,
--	highlight,
--	silencer,
--	fire_mode_auto,
--	fire_mode_single,
--	gadget,
--	bonus,
--	bipod,
	
	--stats (same stat types as weapon stats)
	concealment,
	spread_moving,
	value,
	recoil,
	damage,
	extra_ammo,
	zoom
}
--]]

local function olog(s)
	log("\tTCD csv Parser: " .. s)
end

local function not_empty(s)
	return s and s ~= ""
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
		if string.find(s,"yes") or string.find(s,"true") then 
			return true
		elseif string.find(s,"no") or string.find(s,"false") then 
			return false
		end
	end
	return input and true or false
end

local DAMAGE_CAP = 210 --damage is technically on a lookup table from 0 to 210
local IGNORED_HEADERS = 2
local input_directory = deathvox.ModPath .. "csv/"
local file_util = _G.FileIO
local path_util = BeardLib.Utils.Path
local weapon_stats_directory = input_directory .. "weapons/"
function tcd_parser_execute(mode)
	if mode == "weapon" then 
		local STAT_INDICES = WEAPON_STAT_INDICES
		
		for _,filename in pairs(file_util:GetFiles(weapon_stats_directory)) do
			
			local extension = utf8.to_lower(path_util:GetFileExtension(filename))
			if extension == "csv" then 
				local input_file = io.open(weapon_stats_directory .. filename)
				log("Doing weapon stats file: [" .. tostring(filename) .. "]")
				
				local line_num = 0
				for raw_line in input_file:lines() do 
				
					line_num = line_num + 1
					local raw_csv_values = string.split(raw_line,",",true) --csv values? nice. my favorite type of tea is chai tea
					if line_num > IGNORED_HEADERS then 
					
						--weapon_id
						local weapon_id = raw_csv_values[STAT_INDICES.id]
						if weapon_id and utf8.to_upper(weapon_id) ~= "NULL" and weapon_id ~= "" then 
							local wtd = tweak_data.weapon[weapon_id]
							if wtd then --found valid weapon data to edit
								olog("Processing weapon id " .. tostring(weapon_id) .. " (line " .. tostring(line_num) .. ")")
								
								--Primary class
								local primary_class
								
								local _primary_class = utf8.to_lower(raw_csv_values[STAT_INDICES.primary_class])
								if _primary_class then
									if VALID_PRIMARY_CLASSES[_primary_class] then
										primary_class = _primary_class
									elseif PRIMARY_CLASS_NAME_LOOKUP[_primary_class] then 
										primary_class = PRIMARY_CLASS_NAME_LOOKUP[_primary_class]
									else
										olog("Error: bad primary_class: " .. tostring(raw_csv_values[STAT_INDICES.primary_class]))
										return
									end
								end
								
								
								--Secondary classes
								local secondary_classes = {}
								
								local _secondary_classes = remove_extra_spaces(utf8.to_lower(raw_csv_values[STAT_INDICES.subclasses]))
								if _secondary_classes and _secondary_classes ~= "" then 
									for _,_secondary_class in pairs(string.split(_secondary_classes,";") or {}) do 
										_secondary_class = remove_extra_spaces(_secondary_class)
										local secondary_class
										if VALID_SUBCLASSES[_secondary_class] then 
											secondary_class = _secondary_class
										elseif SUBCLASS_NAME_LOOKUP[_secondary_class] then
											secondary_class = SUBCLASS_NAME_LOOKUP[_secondary_class]
										end
										
										if secondary_class then 
											if secondary_class ~= "" and not table.contains(secondary_classes,secondary_class) then 
												table.insert(secondary_classes,secondary_class)
											else
												olog("Error: bad subclass: " .. tostring(_secondary_class))
												--subclass is not required so don't break here
											end
										end
									end
								end
								
								
								--Magazine size (aka CLIP_AMMO_MAX)
								local magazine
								
								local _magazine = raw_csv_values[STAT_INDICES.magazine]
								magazine = not_empty(_magazine) and math.floor(tonumber(_magazine))
								if not magazine then 
									olog("Error: bad magazine size: " .. tostring(magazine))
									return
								end
								
								
								--Total Ammo (aka Reserve Ammo) (not to be confused with total_ammo_mod)
								local total_ammo
								
								local _total_ammo = raw_csv_values[STAT_INDICES.total_ammo]
								total_ammo = not_empty(_total_ammo) and tonumber(_total_ammo)
								if not total_ammo then 
									olog("Error: bad total_ammo size: " .. tostring(_total_ammo))
									return
								end
								
								
								--Fire Rate
								local fire_rate
								
--								fire_rate = tonumber(raw_csv_values[STAT_INDICES.fire_rate_internal])
								local _fire_rate = raw_csv_values[STAT_INDICES.fire_rate]
								fire_rate = not_empty(_fire_rate) and convert_rof(tonumber(_fire_rate))
								if not fire_rate then 
									olog("Error: bad fire_rate: " .. tostring(_fire_rate))
									return
								end
								
								
								--Damage
								local damage,damage_mul
								
								local _damage = raw_csv_values[STAT_INDICES.damage]
								damage = not_empty(_damage) and tonumber(_damage)
								if damage then 
									if damage > DAMAGE_CAP then 
										damage_mul = damage / DAMAGE_CAP
										damage = DAMAGE_CAP
									end
								else
									olog("Error: bad damage: " .. tostring(_damage))
									return
								end
								
								
								--Accuracy/Spread
								local spread
								
--								spread = tonumber(raw_csv_values[STAT_INDICES.spread_internal])
								local _accuracy = raw_csv_values[STAT_INDICES.accuracy]
								local accuracy = not_empty(_accuracy) and tonumber(_accuracy)
								if accuracy then 
									spread = convert_accstab(accuracy)
								end
								if not spread then 
									olog("Error: bad accuracy: " .. tostring(_accuracy))
									return
								end
								
								--Stability/Recoil
								local recoil 
								
--								recoil = tonumber(raw_csv_values[STAT_INDICES.recoil_internal])
								local _stability = raw_csv_values[STAT_INDICES.stability]
								local stability = not_empty(_stability) and tonumber(_stability)
								if stability then
									recoil = convert_accstab(stability)
								end
								if not recoil then 
									olog("Error: bad stability: " .. tostring(_stability))
									return
								end
								
								--Concealment
								local concealment
								
								local _concealment = raw_csv_values[STAT_INDICES.concealment]
								concealment = not_empty(_concealment) and tonumber(_concealment)
								if not concealment then
									olog("Error: bad concealment: " .. tostring(_concealment))
									return
								end
								
								
								--Threat/Suppression
								local suppression
								
--								suppression = tonumber(raw_csv_values[STAT_INDICES.suppression_internal])
								local _threat = raw_csv_values[STAT_INDICES.threat]
								local threat = not_empty(_threat) and tonumber(_threat)
								if threat then 
									suppression = convert_threat(threat)
								end
								if not suppression then
									olog("Error: bad suppression: " .. tostring(_concealment))
									return
								end
								
								
								--[[
								--Firemode Toggle
								local is_firemode_toggleable
								local _is_firemode_toggleable = raw_csv_values[STAT_INDICES.is_firemode_toggleable]
								if (_is_firemode_toggleable ~= nil) and (_is_firemode_toggleable ~= "") then 
									is_firemode_toggleable = convert_boolean(_is_firemode_toggleable)
								end
								--]]
								
								--[[
								--Firemode
								local fire_mode
								local _fire_mode = utf8.to_lower(raw_csv_values[STAT_INDICES.firemode])
								if _fire_mode then 
									if VALID_FIREMODES[_fire_mode] then 
										fire_mode = _fire_mode
									elseif FIREMODE_NAME_LOOKUP[_fire_mode] then
										fire_mode = FIREMODE_NAME_LOOKUP[_fire_mode]
									end
								end
								if not fire_mode then 
									olog("Error: Bad firemode: " .. tostring(_firemode))
								end
								--]]
								
								
								--timers subsection
								local timers = {}
								
								--Partial Reload timer
								local reload_partial 
								
								local _reload_partial = raw_csv_values[STAT_INDICES.reload_partial]
								reload_partial = not_empty(_reload_partial) and tonumber(_reload_partial)
								if not reload_partial then
									olog("Error: bad reload_partial: " .. tostring(_reload_partial))
									return
								end
								
								
								--Full Reload timer
								local reload_full
								
								local _reload_full = raw_csv_values[STAT_INDICES.reload_full]
								reload_full = not_empty(_reload_full) and tonumber(_reload_full)
								if not reload_full then
									olog("Error: bad reload_full: " .. tostring(_reload_full))
									return
								end
								
								--Equip/Unequip timer
								local equip,unequip
								
								local _equip = raw_csv_values[STAT_INDICES.equip]
								equip = not_empty(_equip) and tonumber(_equip)
								if not equip then 
									olog("Error: bad equip timer: " .. tostring(_equip))
									return
								end
								unequip = equip
								--[[
								local _unequip = raw_csv_values[STAT_INDICES.unequip]
								local unequip = not_empty(_unequip) and tonumber(_unequip)
								if not unequip then 
									olog("Error: bad unequip timer: " .. tostring(_unequip))
									return
								end
								--]]
								
								
								timers.reload_not_empty = reload_partial
								timers.reload_empty = reload_full
								timers.equip = equip
								timers.unequip = unequip
								--timers subsection end
								
								
								--[[
								--Reload speed multiplier (inherited)
								local reload
								local _reload = raw_csv_values[STAT_INDICES.reload]
								reload = not_empty(_reload) and tonumber(_reload)
								--]]
								
								--zoom (optional/inherited)
								local _zoom = raw_csv_values[STAT_INDICES.zoom]
								local zoom = not_empty(_zoom) and tonumber(_zoom)
								
								
								--value aka Price (optional/inherited)
								local _price = raw_csv_values[STAT_INDICES.value]
								local price = not_empty(_price) and tonumber(_price)
								
								
								--Ammo Pickup High/Ammo Pickup Low
								local pickup_low,pickup_high
								
								local _pickup_low = raw_csv_values[STAT_INDICES.pickup_low]
								pickup_low = not_empty(_pickup_low) and tonumber(_pickup_low)
								local _pickup_high = raw_csv_values[STAT_INDICES.pickup_high]
								pickup_high = not_empty(_pickup_high) and tonumber(_pickup_high)
								if not (pickup_low and pickup_high) then 
									olog("Error: bad pickup stat(s): " .. tostring(_pickup_low) .. ", " .. tostring(_pickup_high))
									return
								end
								
								--[[
								--Alert Size (inherited)
								local alert_size
								local _alert_size = raw_csv_values[STAT_INDICES.alert_size]
								alert_size = not_empty(_alert_size) and tonumber(_alert_size)
								--]]
								
								--[[
								--spread_moving (inherited
								local spread_moving
								local _spread_moving = raw_csv_values[STAT_INDICES.spread_moving]
								spread_moving = not_empty(_spread_moving) and convert_accstab(tonumber(_spread_moving))
								--]]
								
								--assorted piercing stats
								local _can_shoot_through_enemy = raw_csv_values[STAT_INDICES.can_pierce_enemy]
								local can_shoot_through_enemy = not_empty(_can_shoot_through_enemy) and convert_boolean(_can_shoot_through_enemy)
								local _can_shoot_through_shield = raw_csv_values[STAT_INDICES.can_pierce_shield]
								local can_shoot_through_shield = not_empty(_can_shoot_through_shield) and convert_boolean(_can_shoot_through_shield)
								local _can_shoot_through_wall = raw_csv_values[STAT_INDICES.can_pierce_wall]
								local can_shoot_through_wall = not_empty(_can_shoot_through_wall) and convert_boolean(_can_shoot_through_wall)
								local _armor_piercing_chance = raw_csv_values[STAT_INDICES.armor_piercing_chance]
								local armor_piercing_chance = not_empty(_armor_piercing_chance) and tonumber(_armor_piercing_chance)
								
								--[[
								--extra magazine size bonus (inherited)
								local _extra_ammo = raw_csv_values[STAT_INDICES.extra_ammo]
								local extra_ammo = not_empty(_extra_ammo) and tonumber(_extra_ammo)
								--]]
								
								--[[
								--total_ammo_mod reserve ammo multiplier (inherited)
								local _total_ammo_mod = raw_csv_values[STAT_INDICES.total_ammo_mod]
								local total_ammo_mod = not_empty(_total_ammo_mod) and tonumber(_total_ammo_mod)
								--]]
								
								--Kick matrix (kick/stability system overhaul not yet implemented)
								--[[
								local _kick_y_min = raw_csv_values[STAT_INDICES.kick_y_min]
								local kick_y_min = not_empty(_kick_y_min) and tonumber(_kick_y_min)
								local _kick_y_max = raw_csv_values[STAT_INDICES.kick_y_max]
								local kick_y_max = not_empty(_kick_y_max) and tonumber(_kick_y_max)
								local _kick_x_min = raw_csv_values[STAT_INDICES.kick_x_min]
								local kick_x_min = not_empty(_kick_x_min) and tonumber(_kick_x_min)
								local _kick_x_max = raw_csv_values[STAT_INDICES.kick_x_max]
								local kick_x_max = not_empty(_kick_x_max) and tonumber(_kick_x_max)
								if not (kick_y_min and kick_y_max and kick_x_min and kick_x_max) then 
									olog("Error: Bad kick value(s): [ " .. table.concat({_kick_y_min,_kick_y_max,_kick_x_min,_kick_x_max}," / ") .. " ]")
									return
								end
								--]]
								
								local spread_moving
								local _spread_moving = raw_csv_values[STAT_INDICES.spread_moving]
								spread_moving = not_empty(_spread_moving) and convert_accstab(tonumber(_spread_moving))
								
								
								wtd.primary_class = primary_class
								wtd.subclasses = secondary_classes
								
								for timer_stat_name,timer_stat_value in pairs(timers) do 
									if timer_stat_value then 
										wtd.timers[timer_stat_name] = timer_stat_value
									end
								end
								
								wtd.CLIP_AMMO_MAX = magazine
								wtd.AMMO_MAX = total_ammo
								if pickup_low and pickup_high then 
									wtd.AMMO_PICKUP[1] = pickup_low
									wtd.AMMO_PICKUP[2] = pickup_high
								end
								
								wtd.fire_mode_data = {
									fire_rate = fire_rate
								}
								wtd.FIRE_MODE = fire_mode or wtd.FIRE_MODE
								if is_firemode_toggleable ~= nil then 
									wtd.CAN_TOGGLE_FIREMODE = is_firemode_toggleable
								end
								
								local new_stats = {}
								new_stats.damage = damage --damage is an index from 1-210, generally linear. larger numbers than 210 can be used, as the parser will automatically convert them using the game's damage multiplier in stats_modifiers. however, this must still be an integer! bigger number more owie.
								new_stats.spread = spread --default accuracy deviation; index from 1-20
								new_stats.spread_moving = spread_moving or wtd.stats.spread_moving --dummy stat
								new_stats.recoil = recoil --change in accuracy deviation over time; index from 1-20
								new_stats.concealment = concealment
								new_stats.suppression = suppression --calculates the displayed Threat stat using a lookup table, from 1-20. larger numbers have a lower threat value.
								new_stats.zoom = zoom or wtd.stats.zoom --zoom is an index from 1-10. larger numbers have greater magnification
								new_stats.value = price or wtd.stats.value --value is an index from 1-10, for a lookup table that determines buy/sell value. larger numbers indicate a more expensive weapon
								new_stats.alert_size = alert_size or wtd.stats.alert_size --alert size is an index from 1-20 for a lookup table, ranging from 300m to 0m. larger numbers have a smaller effective radius
								new_stats.total_ammo_mod = total_ammo_mod or 21 --total_ammo is an index for a lookup table, which is used as a multiplier for the weapon's reserve ammo amount. leave at 21 = 1x 
								new_stats.extra_ammo = extra_ammo or 101 --index from 1-201 in TCD (1-101 in the base game); should only be used for weapon attachments that modify magazine ammo count. leave at 101 = +0 bonus magazine size
								new_stats.reload = reload or 11 --index from 1 to 20, used as a reload speed multiplier. leave at 11 = 1x
								
								if can_shoot_through_enemy ~= nil then 
									wtd.can_shoot_through_enemy = can_shoot_through_enemy
								end
								if can_shoot_through_shield ~= nil then 
									wtd.can_shoot_through_shield = can_shoot_through_shield
								end
								if can_shoot_through_wall ~= nil then 
									wtd.can_shoot_through_wall = can_shoot_through_wall
								end
								if armor_piercing_chance ~= nil then 
									wtd.armor_piercing_chance = armor_piercing_chance
								end
				--				wtd.panic_suppression_chance --???
								
								--[[
								wtd.kick = {
									standing = kick,
									crouching = kick,
									steelsight = kick
								}
								--]]
								
								
								if WIPE_PREVIOUS_STATS then --does not affect inherited stats
									wtd.stats = new_stats
								else
									for k,v in pairs(new_stats) do 
										wtd.stats[k] = new_stats[k] or v
									end
								end
								
								--damage_mul for damage values above DAMAGE_CAP (210)
								wtd.stats_modifiers = wtd.stats_modifiers or {}
								wtd.stats_modifiers.damage = damage_mul
								
							else
								olog("Error! No weapon stats exist for weapon with id: [" .. tostring(weapon_id) .. "]") 
							end
						end
					end
				end
				
				input_file:close()
			else
				olog("Error! Bad file type: " .. tostring(extension))
			end
		end
	elseif mode == "attachment" then 
	elseif mode == "melee" then
	end
end