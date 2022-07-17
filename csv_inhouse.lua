function print_tcd_weapon_stats(weapon_id)
	local s = {}
	local function ins(...)
		local tbl = {...}
		if #tbl > 0 then
			table.insert(s,#s+1,table.concat(tbl," "))
		else
			table.insert(s,#s+1,"")
		end
	end
	
	local wtd = tweak_data.weapon[weapon_id]
	ins(weapon_id)
	ins("name_id",wtd.name_id,managers.localization:text(wtd.name_id))
	ins("subclasses",table.concat(wtd.subclasses or {},"; "))
	ins("magazine",wtd.stats.extra_ammo)
	
	
	
end

local stat_order = {
	"id",
	"name",
	"subclasses", --
	"magazine",
	"reserve_ammo",
	"fire_rate",
	"fire_rate_internal",
	"damage",
	"accuracy",
	"spread_internal",
	"stability",
	"recoil_internal",
	"concealment",
	"threat",
	"suppression_internal",
	"reload_partial",
	"reload_full",
	"equip",
--	"unequip",
	"zoom", --inherited
	"value", --inherited
	"price_preview",
	"pickup_low",
	"pickup_high",
	"can_pierce_wall",
	"can_pierce_enemy",
	"can_pierce_shield",
	"armor_piercing_chance",
	"kick_y_min",
	"kick_y_max",
	"kick_x_min",
	"kick_x_max"
}

local STAT_INDICES = {
	id = 1,
	class = 2,
	subclasses = 3, --(for multiple subclasses, separate with semicolons. leave blank for no subclass.)
	price = 3, --cost index, aka value
	magazine = 4, 
	reserve_ammo = 5,
	fire_rate = 6,
	damage = 7,
	accuracy = 8,
	stability = 9,
	concealment = 10,
	reload_partial = 11,
	reload_full = 12,
	equip = 13,
--	unequip = 14,
	threat = 15, --calculated from suppression
	pickup_high = 16,
	pickup_low = 17,
	pierce_wall = 18,
	pierce_enemy = 19,
	pierce_shield = 20,
--	is_firemode_toggleable = 21,
	kick_min_y = 22,
	kick_max_y = 23,
	kick_min_x = 24,
	kick_max_x = 25
}

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
local input_directory = deathvox.ModPath .. "weapon_stats/"
local file_util = _G.FileIO
local path_util = BeardLib.Utils.Path
local weapon_stats_directory = input_directory
function tcd_parser_execute(mode)
	if mode == "weapon" then end
	
	for _,filename in pairs(file_util:GetFiles(weapon_stats_directory)) do
		local extension = utf8.to_lower(path_util:GetFileExtension(filename))
		if extension == "csv" then 
			local input_file = io.open(weapon_stats_directory .. filename)
			log("Doing weapon stats file: [" .. tostring(filename) .. "]")
			
			local line_num = IGNORED_HEADERS
			for raw_line in input_file:lines() do 
				line_num = line_num + 1
				local raw_csv_values = string.split(raw_line,",",true) --csv values? nice. my favorite type of tea is chai tea
				if line_num > IGNORED_HEADERS then 
					local weapon_id = raw_csv_values[STAT_INDICES.id]
					if weapon_id and utf8.to_upper(weapon_id) ~= "NULL" and weapon_id ~= "" then 
						local wtd = tweak_data.weapon[weapon_id]
						
						if wtd then --found valid weapon data to edit
							log("Processing weapon id " .. tostring(weapon_id) .. " (" .. tostring(line_num) .. ")")
							
							local primary_class = raw_csv_values[STAT_INDICES.class]
							
							local _secondary_classes = raw_csv_values[STAT_INDICES.secondary_class]
							local secondary_classes = {}
							if _secondary_classes and _secondary_classes ~= "" then 
								for _,_secondary_class in pairs(string.split(secondary_classes,";") or {}) do 
									local secondary_class = remove_extra_spaces(_secondary_class)
									if secondary_class ~= "" and not table.contains(secondary_classes,secondary_class) then 
										table.insert(secondary_classes,secondary_class)
									end
								end
							end
							local _fire_rate = raw_csv_values[STAT_INDICES.fire_rate]
							local fire_rate = _fire_rate and convert_rof(tonumber(_fire_rate))
							
							local _is_firemode_toggleable = raw_csv_values[STAT_INDICES.is_firemode_toggleable]
							local is_firemode_toggleable
							if (_is_firemode_toggleable ~= nil) and (_is_firemode_toggleable ~= "") then 
								is_firemode_toggleable = convert_boolean(_is_firemode_toggleable)
							end
							
							local _reload_partial = raw_csv_values[STAT_INDICES.reload_partial]
							local reload_partial = _reload_partial and tonumber(_reload_partial)
							local _reload_full = raw_csv_values[STAT_INDICES.reload_full]
							local reload_full = _reload_full and tonumber(_reload_full)
							local _equip = raw_csv_values[STAT_INDICES.equip]
							local equip = _equip and tonumber(_equip)
							local _unequip = raw_csv_values[STAT_INDICES.unequip]
							local unequip = _unequip and tonumber(_unequip)
							local timers = {
								reload_not_empty = reload_partial,
								reload_empty = reload_full,
								equip = equip,
								unequip = unequip
							}
							
							local _pickup_low = raw_csv_values[STAT_INDICES.pickup_low]
							local pickup_low = _pickup_low and tonumber(_pickup_low)
							local _pickup_high = raw_csv_values[STAT_INDICES.pickup_high]
							local pickup_high = _pickup_high and tonumber(_pickup_high)
							
							local _damage = raw_csv_values[STAT_INDICES.damage]
							local damage = _damage and tonumber(_damage)
							local damage_mul
							if damage and damage > DAMAGE_CAP then 
								damage_mul = damage / DAMAGE_CAP
								damage = DAMAGE_CAP
							end
							
							local _reserve_ammo = raw_csv_values[STAT_INDICES.reserve_ammo]
							local reserve_ammo = _reserve_ammo and tonumber(_reserve_ammo)
							
							local _price = raw_csv_values[STAT_INDICES.price]
							local price = _price and tonumber(_price)
							
							local _alert_size = raw_csv_values[STAT_INDICES.alert_size]
							local alert_size = _alert_size and tonumber(_alert_size)
							
							local _threat = raw_csv_values[STAT_INDICES.threat]
							local threat = _threat and tonumber(_threat)
							local suppression
							if threat then 
								suppression = convert_threat(threat)
							end
							
							local _accuracy = raw_csv_values[STAT_INDICES.accuracy]
							local accuracy = _accuracy and tonumber(_accuracy)
							local spread
							if accuracy then 
								spread = convert_accstab(accuracy)
							end
							
							local stability = raw_csv_values[STAT_INDICES.stability]
							local stability = _stability and tonumber(_stability)
							local recoil 
							if stability then
								recoil = convert_accstab(stability)
							end
							
							local _concealment = raw_csv_values[STAT_INDICES.concealment]
							local concealment = _concealment and tonumber(_concealment)
							
							local _can_shoot_through_enemy = raw_csv_values[STAT_INDICES.can_shoot_through_enemy]
							local can_shoot_through_enemy = _can_shoot_through_enemy and convert_boolean(_can_shoot_through_enemy)
							local _can_shoot_through_shield = raw_csv_values[STAT_INDICES.can_shoot_through_shield]
							local can_shoot_through_shield = _can_shoot_through_shield and convert_boolean(_can_shoot_through_shield)
							local _can_shoot_through_wall = raw_csv_values[STAT_INDICES.can_shoot_through_wall]
							local can_shoot_through_wall = _can_shoot_through_wall and convert_boolean(_can_shoot_through_wall)
							local _armor_piercing_chance = raw_csv_values[STAT_INDICES.armor_pierce_chance]
							local armor_piercing_chance = _armor_piercing_chance and tonumber(_armor_piercing_chance)
							
							local _zoom = raw_csv_values[STAT_INDICES.zoom]
							local zoom = _zoom and tonumber(_zoom)
							
							local _extra_ammo = raw_csv_values[STAT_INDICES.extra_ammo]
							local extra_ammo = _extra_ammo and tonumber(_extra_ammo)
							
							wtd.primary_class = primary_class
							wtd.subclasses = secondary_classes
							wtd.FIRE_MODE = fire_mode or wtd.FIRE_MODE
							wtd.fire_mode_data = {
								fire_rate = fire_rate
							}
							
							if is_firemode_toggleable ~= nil then 
								wtd.CAN_TOGGLE_FIREMODE = is_firemode_toggleable
							end
							
							for timer_stat_name,timer_stat_value in pairs(timers) do 
								if timer_stat_value then 
									wtd.timers[timer_stat_name] = timer_stat_value
								end
							end
							
							local _magazine = raw_csv_values[STAT_INDICES.magazine]
							local magazine = _magazine and tonumber(_magazine)
							wtd.CLIP_AMMO_MAX = magazine
							wtd.AMMO_MAX = reserve_ammo
							if pickup_low and pickup_high then 
								wtd.AMMO_PICKUP[1] = pickup_low
								wtd.AMMO_PICKUP[2] = pickup_high
							end
							
							local new_stats = {}
							new_stats.zoom = zoom or wtd.stats.zoom --zoom is an index from 1-10. larger numbers have greater magnification
							new_stats.total_ammo_mod = 21 --total_ammo is an index for a lookup table, which is used as a multiplier for the weapon's reserve ammo amount. leave at 21 = +0x 
							new_stats.damage = damage --damage is an index from 1-210, generally linear. larger numbers than 210 can be used, as the parser will automatically convert them using the game's damage multiplier in stats_modifiers. however, this must still be an integer! bigger number more owie.
							new_stats.alert_size = alert_size --alert size is an index from 1-20 for a lookup table, ranging from 300m to 0m. larger numbers have a smaller effective radius
							new_stats.spread = spread --default accuracy deviation; index from 1-20
							new_stats.spread_moving = 8 --dummy stat
							new_stats.recoil = recoil --change in accuracy deviation over time; index from 1-20
							new_stats.value = value --value is an index from 1-10, for a lookup table that determines buy/sell value. larger numbers indicate a more expensive weapon
							new_stats.extra_ammo = extra_ammo or 101 --index from 1-200 in TCD (1-100 in the base game); should only be used for weapon attachments that modify reserve ammo count
							new_stats.reload = reload or 11 --index from 1 to 20, used as a reload speed multiplier. 20 represents a 2x reload speed multiplier, while 11 represents a 1x reload speed multiplier.
							new_stats.suppression = suppression or wtd.stats.suppression --calculates the displayed Threat stat using a lookup table, from 1-20. larger numbers have a lower threat value.
							new_stats.concealment = concealment or wtd.stats.concealment
							
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
			--				wtd.panic_suppression_chance
							
							if WIPE_PREVIOUS_STATS then 
								wtd.stats = new_stats
							else
								for k,v in pairs(new_stats) do 
									wtd.stats[k] = new_stats[k] or v
								end
							end
							if damage_mul then 
								wtd.stats_modifiers = wtd.stats_modifiers or {}
								wtd.stats_modifiers.damage = damage_mul
							end
							
						else
							olog("Error! No weapon stats exist for weapon with id: [" .. tostring(weapon_id) .. "]") 
						end
					end
				end
			end
			
			
		else
			olog("Error! Bad file type: " .. tostring(extension))
		end
	end
end