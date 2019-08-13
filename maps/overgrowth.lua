--overgrowth-- by mewmew --

require "on_tick_schedule"
require "modules.dynamic_landfill"
require "modules.satellite_score"
require "modules.spawners_contain_biters"
require "modules.no_deconstruction_of_neutral_entities"
require "modules.biters_yield_coins"
require "modules.rocks_yield_ore"
require "modules.ores_are_mixed"
require "modules.biters_attack_moving_players"

require "modules.trees_grow"
require "modules.trees_randomly_die"

require "maps.overgrowth_map_info"

local unearthing_biters = require "functions.unearthing_biters"

local event = require 'utils.event' 
local math_random = math.random

local function create_particles(surface, name, position, amount, cause_position)
	local math_random = math.random
	
	local direction_mod = (-100 + math_random(0,200)) * 0.0004
	local direction_mod_2 = (-100 + math_random(0,200)) * 0.0004
	
	if cause_position then
		direction_mod = (cause_position.x - position.x) * 0.025
		direction_mod_2 = (cause_position.y - position.y) * 0.025
	end
	
	for i = 1, amount, 1 do 
		local m = math_random(4, 10)
		local m2 = m * 0.005
		
		surface.create_entity({
			name = name,
			position = position,
			frame_speed = 1,
			vertical_speed = 0.130,
			height = 0,
			movement = {
				(m2 - (math_random(0, m) * 0.01)) + direction_mod,
				(m2 - (math_random(0, m) * 0.01)) + direction_mod_2
			}
		})
	end	
end

local function spawn_market(surface, position)
	local market = surface.create_entity({name = "market", position = position, force = "neutral"})
	market.destructible = false
	market.add_market_item({price = {{'coin', 1}}, offer = {type = 'give-item', item = "wood", count = 50}})
	market.add_market_item({price = {{"coin", 3}}, offer = {type = 'give-item', item = 'iron-ore', count = 50}})
	market.add_market_item({price = {{"coin", 3}}, offer = {type = 'give-item', item = 'copper-ore', count = 50}})
	market.add_market_item({price = {{"coin", 3}}, offer = {type = 'give-item', item = 'stone', count = 50}})
	market.add_market_item({price = {{"coin", 3}}, offer = {type = 'give-item', item = 'coal', count = 50}})
	market.add_market_item({price = {{"coin", 5}}, offer = {type = 'give-item', item = 'uranium-ore', count = 50}})
	
	market.add_market_item({price = {{'coin', 2}}, offer = {type = 'give-item', item = "raw-fish", count = 1}})
	market.add_market_item({price = {{'coin', 8}}, offer = {type = 'give-item', item = "grenade", count = 1}})
	market.add_market_item({price = {{'coin', 1}}, offer = {type = 'give-item', item = "firearm-magazine", count = 1}})
	market.add_market_item({price = {{'coin', 16}}, offer = {type = 'give-item', item = "submachine-gun", count = 1}})
	market.add_market_item({price = {{'coin', 32}}, offer = {type = 'give-item', item = "car", count = 1}})
end

local function on_player_joined_game(event)	
	local player = game.players[event.player_index]	
	if player.online_time == 0 then
		player.insert({name = "pistol", count = 1})
		player.insert({name = "firearm-magazine", count = 8})
	end
	
	if not global.market then
		spawn_market(player.surface, {x = 0, y = -8})
		game.map_settings.enemy_evolution.time_factor = 0.00003
		global.market = true
	end
end	

local function trap(entity)
	if math_random(1,8) == 1 then unearthing_biters(entity.surface, entity.position, math_random(4,8)) end	
end

local function on_player_mined_entity(event)
	local entity = event.entity
	if not entity.valid then return end	
	if entity.type ~= "tree" then return end
		
	trap(entity)
	entity.surface.spill_item_stack(entity.position,{name = "coin", count = 1}, true)
	
	if event.player_index then
		create_particles(entity.surface, "wooden-particle", entity.position, 128, game.players[event.player_index].position)
		return
	end
	create_particles(entity.surface, "wooden-particle", entity.position, 128)
end

local function on_entity_died(event)
	on_player_mined_entity(event)
end
	
event.add(defines.events.on_player_joined_game, on_player_joined_game)
event.add(defines.events.on_player_mined_entity, on_player_mined_entity)
event.add(defines.events.on_entity_died, on_entity_died)