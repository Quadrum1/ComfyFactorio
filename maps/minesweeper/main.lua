--[[
It's a Minesweeper thingy - MewMew

Cell Values:
    -- -1 = triggered mine
	-- 1 to 8 = adjacent mines
	-- 9 = empty cell with grid
	-- 10 = mine
	-- 11 = marked mine

]] --


--[[
if script.active_mods['space-age'] then
    error('This map is incompatible with the Space Age mod. Disable Space Age to run this map.', 2)
end
]]

local FlyingText = require 'utils.functions.flying_texts'

require 'modules.satellite_score'

local Functions = require 'maps.minesweeper.functions'
local Constants = require 'maps.minesweeper.constants'

local MapScore = require 'utils.gui.map_score'
local Map = require 'modules.map_info'
local Global = require 'utils.global'


local minesweeper = {}

Global.register(
    minesweeper,
    function (tbl)
        minesweeper = tbl
    end
)

local function render_cell(cell_key, position)
    local surface_index = 1
    local cell = minesweeper.cells[cell_key]

    if not cell then return end

    local tile_values = Functions.get_text_rendering_at(position, surface_index)
    local color = Functions.get_cell_color(cell)
    local text = Functions.get_cell_text(cell)

    local text_position = { position.x + tile_values.offset[1], position.y + tile_values.offset[2] }
    local surface = game.surfaces[surface_index]

    if minesweeper.graphical.texts[cell_key] then
        minesweeper.graphical.texts[cell_key].destroy()
        minesweeper.graphical.texts[cell_key] = nil
    end

    minesweeper.graphical.texts[cell_key] =
        rendering.draw_text
        {
            text = text,
            surface = surface,
            target = text_position,
            color = color,
            scale = tile_values.zoom,
            font = tile_values.font,
            draw_on_ground = true,
            scale_with_zoom = false,
            only_in_alt_mode = false
        }

    if not Functions.is_minefield_cell_paved(position, surface_index) then
        if minesweeper.graphical.rectangles[cell_key] then
            -- Cell rectangle was rendered before, but now is no longer paved.
            minesweeper.graphical.rectangles[cell_key].destroy()
            minesweeper.graphical.rectangles[cell_key] = nil
        end
        return
    end

    -- Already have a rectangle rendered, no need for more.
    if minesweeper.graphical.rectangles[cell_key] then return end

    minesweeper.graphical.rectangles[cell_key] =
        rendering.draw_rectangle
        {
            width = 2,
            filled = false,
            surface = surface,
            left_top = position,
            right_bottom = { position.x + 2, position.y + 2 },
            color = { 0, 0, 0 },
            draw_on_ground = true,
            only_in_alt_mode = false
        }
end

local function get_adjacent_mine_count(position, surface_index)
    surface_index = surface_index or 1
    local cell_position = Functions.position_to_cell_position(position, surface_index)
    
    local count = 0
    for _, vector in pairs(Constants.cell_adjacent_vectors) do
        local p = { x = cell_position.x + vector[1], y = cell_position.y + vector[2] }
        local key = Functions.position_to_string(p)
        local cell = minesweeper.cells[key]

        count = count + Functions.get_cell_minecount(cell)
    end
    return count
end

local function kill_cell(position, surface_index)
    surface_index = surface_index or 1
    local cell_position = Functions.position_to_cell_position(position, surface_index)
    local key = Functions.position_to_string(cell_position)
    local cell = minesweeper.cells[key]
    if not cell then
        return
    end
    if minesweeper.graphical.texts[key] then
        minesweeper.graphical.texts[key].destroy()
        minesweeper.graphical.texts[key] = nil
    end

    if minesweeper.graphical.rectangles[key] then
        minesweeper.graphical.rectangles[key].destroy()
        minesweeper.graphical.rectangles[key] = nil
    end
    minesweeper.cells[key] = nil
end

local function trigger_mine(cell_key, position, surface_index)
    surface_index = surface_index or 1
    local cell_position = Functions.position_to_cell_position(position, surface_index)

    minesweeper.cells[cell_key] = -1
    minesweeper.active_mines = minesweeper.active_mines - 1
    for _, vector in pairs(Constants.cell_update_vectors) do
        local p = { x = cell_position.x + vector[1], y = cell_position.y + vector[2] }
        local adjacent_key = Functions.position_to_string(p)
        local adjacent_cell = minesweeper.cells[adjacent_key]
        if adjacent_cell and adjacent_cell < 10 then
            table.insert(minesweeper.visit_queue, p)
        end
    end
end

local function launch_blast(position)
    local blast = Functions.kaboom(position)
    if blast then
        minesweeper.blasts = minesweeper.blasts or {}
        table.insert(minesweeper.blasts, blast)
    end
end


local function reveal_cell(cell_position)
    for _, vector in pairs(Constants.cell_adjacent_vectors) do
        local adjacent_position = { x = cell_position.x + vector[1], y = cell_position.y + vector[2] }
        if Functions.is_minefield_tile(adjacent_position, true) then
            local adjacent_key = Functions.position_to_string(adjacent_position)
            local adjacent_mine_count = get_adjacent_mine_count(adjacent_position)

            minesweeper.cells[adjacent_key] = adjacent_mine_count

            if adjacent_mine_count == 0 then
                table.insert(minesweeper.visit_queue, adjacent_position)
            else
                render_cell(adjacent_key, adjacent_position)
            end
        end
    end
    Functions.uncover_terrain(cell_position)
    kill_cell(cell_position)
end


local function visit_cell(position)
    if not Functions.is_minefield_tile(position, true) then
        return
    end

    local cell_position = Functions.position_to_cell_position(position)
    local key = Functions.position_to_string(cell_position)
    local cell = minesweeper.cells[key]

    if cell then
        if cell == 10 then
            trigger_mine(key, position)
            return
        end

        if cell == 11 then
            render_cell(key, position)
            return
        end
    end

    local current_mine_count = get_adjacent_mine_count(cell_position)
    minesweeper.cells[key] = current_mine_count

    if current_mine_count == 0 then
        reveal_cell(cell_position)
        return
    end

    if cell and cell ~= current_mine_count then
        for _, vector in pairs(Constants.cell_adjacent_vectors) do
            local adjacent_position = { x = position.x + vector[1], y = position.y + vector[2] }
            local adjacent_key = Functions.position_to_string(adjacent_position)
            local adjacent_cell = minesweeper.cells[adjacent_key]
            if adjacent_cell and adjacent_cell < 9 then
                table.insert(minesweeper.visit_queue, { x = adjacent_position.x, y = adjacent_position.y })
            end
        end
    end

    -- This should not be called if the cell does not exist.
    render_cell(key, position)
end

local function are_mines_marked_around_target(position)
    local marked_positions = {}
    for _, vector in pairs(Functions.get_solving_vectors(position)) do
        local p = { x = position.x + vector[1], y = position.y + vector[2] }
        local key = Functions.position_to_string(p)
        local cell = minesweeper.cells[key]
        if cell then
            if cell == 10 then
                return
            end
            if cell == 11 then
                table.insert(marked_positions, p)
            end
        end
    end
    return marked_positions
end

local function solve_attempt(position)
    local solved = false
    for _, vector in pairs(Functions.get_solving_vectors(position)) do
        local p = { x = position.x + vector[1], y = position.y + vector[2] }
        local key = Functions.position_to_string(p)
        local cell = minesweeper.cells[key]
        if cell and cell > 10 then
            local marked_positions = are_mines_marked_around_target(p)
            if marked_positions then
                solved = true
                for _, pp in pairs(marked_positions) do
                    local key = Functions.position_to_string(pp)
                    minesweeper.cells[key] = -1
                    minesweeper.active_mines = minesweeper.active_mines - 1
                end
                for _, pp in pairs(marked_positions) do
                    visit_cell(pp)
                    Functions.disarm_reward(pp)
                end
            end
        end
    end
    return solved
end


-- 
local function mark_mine(entity)
    local position = Functions.position_to_cell_position(entity.position)
    local key = Functions.position_to_string(position)
    local cell = minesweeper.cells[key]

    local surface = entity.surface

    local config = Constants.mark_mine_text[cell]
    FlyingText.flying_text(nil, surface, entity.position, config.text, config.color)  

    minesweeper.cells[key] = 11
    render_cell(key, position)

    if cell == 10 then
        return 1
    end

    return 0
end


-- Handles what should happen when a furnace is placed on a grid cell
local function handle_marker_on_grid(entity)
    local position = Functions.position_to_cell_position(entity.position)
    local key = Functions.position_to_string(position)
    local cell = minesweeper.cells[key]

    -- The player managed to diffuse a mine (or a diffused mine :D)
    if cell and cell > 9 then
        local score = mark_mine(entity)
        solve_attempt(position)
        return score
    end

    -- If the cell is known, i.e. shown, we can assume this was a mistake and not punish it
    if cell then
        return 0
    end

    -- The player tried to diffuse a cell that was not a minew
    -- and was also not yet revealed -> They guessed
    -- Make the cell itself explode and reveal the true value
    -- Maybe add a text later "Your diffusion equipment malfunctioned" ?

    -- To avoid abuse (you can place multiple furnaces before the shockwave reaches you)
    -- I disabled revealing wrong guesses of non-mines:
    launch_blast(position)
    return -1
end

local function add_mines_to_chunk(left_top, distance_to_center, restore_existing)
    local base_mine_count = 40
    local max_mine_count = 128
    local mine_count = distance_to_center * 0.043 + base_mine_count
    if mine_count > max_mine_count then
        mine_count = max_mine_count
    end

    local shuffle_index = {}
    for iv = 1, Constants.size_of_chunk_divide_vectors, 1 do
        table.insert(shuffle_index, iv)
    end
    table.shuffle_table(shuffle_index)

    for iv = 1, mine_count do
        local vector = Constants.chunk_divide_vectors[shuffle_index[iv]]
        local position = { x = left_top.x + vector[1], y = left_top.y + vector[2] }
        if not Functions.is_spawn(position) and (not restore_existing or Functions.is_minefield_tile(position, true)) then
            local key = Functions.position_to_string(position)
            minesweeper.cells[key] = 10
            minesweeper.active_mines = minesweeper.active_mines + 1
        end
    end

    for x = left_top.x - 2, left_top.x + 32, 2 do
        for y = left_top.y - 2, left_top.y + 32, 2 do
            local position = { x = x, y = y }
            local key = Functions.position_to_string(position)
            local cell = minesweeper.cells[key]
            if cell and cell == 10 then
                if get_adjacent_mine_count(position) == 8 then
                    minesweeper.cells[key] = nil
                    minesweeper.active_mines = minesweeper.active_mines - 1
                end
            end
        end
    end
end


local function remove_mines_from_chunk(top_left, surface_index)

    local cell_position = Functions.position_to_cell_position(top_left, surface_index)
    local chunk_key = Functions.position_to_string(cell_position)

    if not minesweeper.chunks[chunk_key] then
        return
    end

    for dx = 0, 32, 2 do
        for dy = 0, 32, 2 do
            local position = { x = cell_position.x + dx, y = cell_position.y + dy }
            local key = Functions.position_to_string(position)
            local cell = minesweeper.cells[key]

            -- Diffuse / Remove mine
            if cell and cell == 10 and Functions.is_near_spawn(position) then
                kill_cell(position)
                minesweeper.active_mines = minesweeper.active_mines - 1
            end
        end
    end

    for dx = 0, 32, 2 do
        for dy = 0, 32, 2 do
            local position = { x = cell_position.x + dx, y = cell_position.y + dy }
            local key = Functions.position_to_string(position)
            local cell = minesweeper.cells[key]

            -- Diffuse / Remove mine
            local is_mine = cell and cell == 10
            if not is_mine and Functions.is_near_spawn(position) and Functions.is_minefield_tile(position, true) then
                visit_cell(position)
            end
        end
    end
end

-- balance and QoL change: start area is already revealed as if clicked and cleared a free area
-- the previous implementation was not consistent with minesweeper rules
local function reveal_spawn_area()
    local spawn_chunks =
    {
        { x = -32, y = -32 },
        { x = 0, y = -32 },
        { x = -32, y = 0 },
        { x = 0, y = 0 }
    }

    -- This should not happen when generate_spawn is called before
    for _, chunk_left_top in pairs(spawn_chunks) do
        local key = Functions.position_to_string(chunk_left_top)
        if minesweeper.chunks[key] then
            remove_mines_from_chunk(chunk_left_top)
        end
    end
end

local function on_chunk_generated(event)
    local left_top = event.area.left_top
    local surface = event.surface
    if surface.index ~= 1 or not minesweeper.chunks then
        return
    end

    local key = Functions.position_to_string(left_top)
    if minesweeper.chunks[key] then
        return
    end

    local distance_to_center = math.sqrt((left_top.x + 16) ^ 2 + (left_top.y + 16) ^ 2)
    local tiles = {}

    if distance_to_center < 128 then
        for x = 0, 31, 1 do
            for y = 0, 31, 1 do
                local position = { x = left_top.x + x, y = left_top.y + y }
                if Functions.is_spawn(position) then
                    table.insert(tiles, { name = Functions.get_terrain_tile(surface, position), position = position })
                else
                    table.insert(tiles, { name = 'nuclear-ground', position = position })
                end
            end
        end
    else
        for x = 0, 31, 1 do
            for y = 0, 31, 1 do
                local position = { x = left_top.x + x, y = left_top.y + y }
                table.insert(tiles, { name = 'nuclear-ground', position = position })
            end
        end
    end
    surface.set_tiles(tiles, true)

    -- removes resources that would've spawned from normal map generation, user in map generation does no longer need to set them to 0
    for _, resource in pairs(surface.find_entities_filtered({ area = event.area, type = 'resource' })) do
        resource.destroy()
    end

    add_mines_to_chunk(left_top, distance_to_center)
    minesweeper.chunks[key] = true
end

local function on_player_changed_position(event)
    local player = game.players[event.player_index]
    -- change for 2.0 | 2.1
    -- player.position also gives position in remote view which would trigger mines before
    -- instead use character.position
    local character = player.character
    if not minesweeper.cells or player.controller_type ~= defines.controllers.character or not (character and character.valid) or character.surface.index ~= 1 then
        return
    end
    local position = character.position
    if not Functions.is_minefield_tile(position) then
        return
    end
    local cell_position = Functions.position_to_cell_position(position)
    local key = Functions.position_to_string(cell_position)
    local cell = minesweeper.cells[key]

    local score_change = Functions.calculate_cell_step_score(cell)
    visit_cell(cell_position)
    if score_change < 0 then
        solve_attempt(cell_position)
        launch_blast(cell_position)
    end
    MapScore.set_score(player, MapScore.get_score(player) + score_change)
end




-- Checks if the placement is valid, otherwise returns the item to the inventory
local function player_built_entity_on_minesweeper_cells(event)
    local player = game.players[event.player_index]
    local entity = event.entity
    local position = entity.position

    local is_marker_entity = entity.name == 'stone-furnace'
    local fits_cell = position.x % 2 == 1 and position.y % 2 == 1
    
    if is_marker_entity and fits_cell then
        local score_change = handle_marker_on_grid(entity)
        if score_change then
            MapScore.set_score(player, MapScore.get_score(player) + score_change)
        end
    end

    Functions.refund_and_destroy_entity(entity, player)

    -- Reselect the furnace if it was placed down
    if not is_marker_entity then return end
    Functions.select_furnace(player)
end


-- Currently we do not allow robots to diffuse mines
-- This should probably never be possible to avoid cheesing with huge furnace arrays.
local function on_robot_built_entity(event)
    local entity = event.entity
    if not minesweeper.cells or not entity.valid or entity.surface.index ~= 1 then
        return
    end
    local position = entity.position
    if not Functions.is_minefield_tile(position, true) then return end
    
    local inventory = event.robot.get_inventory(defines.inventory.robot_cargo)
    Functions.refund_and_destroy_entity(entity, inventory)
end

local function on_player_built_entity(event)
    local entity = event.entity
    if not minesweeper.cells or not entity.valid or entity.surface.index ~= 1 then
        return
    end

    local position = entity.position
    if Functions.is_minefield_tile(position, true) then
        player_built_entity_on_minesweeper_cells(event)
    end
end

local function update_built_tiles(event)
    if not minesweeper.cells then
        return
    end

    local surface_index = event.surface_index or 1

    local updated = {}
    for _, placed_tile in pairs(event.tiles) do
        local cell_position = Functions.position_to_cell_position(placed_tile.position)
        local key = Functions.position_to_string(cell_position)
        if not updated[key] then
            updated[key] = true
            local cell = minesweeper.cells[key]
            if not cell and Functions.is_minefield_cell_paved(cell_position, surface_index) then
                minesweeper.cells[key] = 9
                render_cell(key, cell_position)
            end
            if cell then
                render_cell(key, cell_position)
            end
        end
    end
end

local function on_player_created(event)
    local player = game.players[event.player_index]
    player.insert({ name = 'stone-furnace', count = 1 })
    player.set_quick_bar_slot(1, 1, "stone-furnace")

    MapScore.set_score(player, 0)
end

local function on_player_respawned(event)
    local player = game.players[event.player_index]
    player.insert({ name = 'stone-furnace', count = 1 })

    game.surfaces[1].destroy_decoratives({ name = 'nuclear-ground-patch' })
end

-- This revives biters that were killed using nukes
local function on_entity_died(event)
    local entity = event.entity
    if not entity then return end
    if not entity.valid then return end
    if entity.surface.index ~= 1 then return end
    if entity.force.name ~= 'enemy' then return end

    local force = event.force
    if not force then return end
    if force.name ~= 'minesweeper' then return end

    local revived_entity = entity.clone({ position = entity.position })
    if revived_entity then
        revived_entity.health = revived_entity.max_health
        entity.destroy()
    end
end

local function initialize()
    if not game.forces.minesweeper then
        game.create_force('minesweeper')
    end

    minesweeper.chunks = {}
    minesweeper.cells = {}
    minesweeper.graphical = {
        texts = {},
        rectangles = {}
    }
    minesweeper.blasts = {}
    minesweeper.priority_function_queue = {}
    minesweeper.visit_queue = {}
    minesweeper.player_data = {}
    minesweeper.active_mines = 0
    minesweeper.disarmed_mines = 0
    minesweeper.triggered_mines = 0

    local surface = game.surfaces[1]
    local mgs = surface.map_gen_settings
    mgs.water = 0
    mgs.cliff_settings = { cliff_elevation_interval = 0, cliff_elevation_0 = 0 }
    -- bugfix for Factorio 2.0 | 2.1: frequency & size & richness = 0 makes spotNoise return NaN.
    -- instead opt for ressorce removal in on_chunk_generated
    mgs.autoplace_controls =
    {
        ['trees'] = { frequency = 4, size = 0.5, richness = 0.1 }
    }
    surface.map_gen_settings = mgs
    MapScore.set_score_description('Minesweep rank:')
    local T = Map.get_map_information()
    T.localised_category = 'minesweeper'
    T.main_caption_color = { r = 255, g = 125, b = 55 }
    T.sub_caption_color = { r = 0, g = 250, b = 150 }
end

local function generate_spawn()
    local surface = game.surfaces[1]
    surface.request_to_generate_chunks({ 0, 0 }, 1)
    surface.force_generate_chunk_requests()
    for chunk in surface.get_chunks() do
        if surface.is_chunk_generated(chunk) then
            on_chunk_generated({ surface = surface, area = chunk.area })
        end
    end
end

local function on_init()
    initialize()
    table.insert(minesweeper.priority_function_queue, generate_spawn)
    table.insert(minesweeper.priority_function_queue, reveal_spawn_area)

    local surface = game.surfaces[1]
    for _, entity in pairs(surface.find_entities_filtered({ type = 'cliff' })) do
        entity.destroy()
    end
end

local function on_nth_tick()
    if #minesweeper.priority_function_queue > 0 then
        local priority_function = table.remove(minesweeper.priority_function_queue, 1)
        priority_function()
        return
    end

    local blasts = minesweeper.blasts
    if #blasts > 0 then
        for index = #blasts, 1, -1 do
            local blast = blasts[index]
            if not blast.projectile.valid then
                Functions.restore_blast_terrain(blast.terrain)
                table.remove(blasts, index)
            end
        end
        if #blasts > 0 then
            return
        end
    end

    if #minesweeper.visit_queue > 0 then
        local position = table.remove(minesweeper.visit_queue, 1)
        if position then
            visit_cell(position)
        end
    end
end

local Event = require 'utils.event'
Event.on_init(on_init)
Event.on_nth_tick(2, on_nth_tick)
Event.add(defines.events.on_chunk_generated, on_chunk_generated)
Event.add(defines.events.on_player_changed_position, on_player_changed_position)
Event.add(defines.events.on_built_entity, on_player_built_entity)
Event.add(defines.events.on_robot_built_entity, on_robot_built_entity)
Event.add(defines.events.on_entity_died, on_entity_died)
Event.add(defines.events.on_player_created, on_player_created)
Event.add(defines.events.on_player_respawned, on_player_respawned)
Event.add(defines.events.on_robot_built_tile, update_built_tiles)
Event.add(defines.events.on_player_built_tile, update_built_tiles)
Event.add(defines.events.on_robot_mined_tile, update_built_tiles)
Event.add(defines.events.on_player_mined_tile, update_built_tiles)
