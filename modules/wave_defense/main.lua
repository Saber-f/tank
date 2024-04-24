local Event = require 'utils.event'
local BiterHealthBooster = require 'modules.biter_health_booster_v2'

local Print = require('utils.print_override')
local raw_print = Print.raw_print

local BiterRolls = require 'modules.wave_defense.biter_rolls'
local ThreatEvent = require 'modules.wave_defense.threat_events'
local update_gui = require 'modules.wave_defense.gui'
local threat_values = require 'modules.wave_defense.threat_values'
local WD = require 'modules.wave_defense.table'
local Alert = require 'utils.alert'
local diff=require 'maps.amap.diff'
local WPT = require 'maps.amap.table'
local get_random_car =require "maps.amap.functions".get_random_car
local get_new_arty = require "maps.amap.enemy_arty".get_new_arty
local Public = {}
local math_random = math.random
local math_floor = math.floor
local table_insert = table.insert
local math_sqrt = math.sqrt
local math_round = math.round

function setWave(v)
    WD.set('wave_number', v)
end

local group_size_modifier_raffle = {}
local group_size_chances = {
    {4, 0.4},
    {5, 0.5},
    {6, 0.6},
    {7, 0.7},
    {8, 0.8},
    {9, 0.9},
    {10, 1},
    {9, 1.1},
    {8, 1.2},
    {7, 1.3},
    {6, 1.4},
    {5, 1.5},
    {4, 1.6},
    {3, 1.7},
    {2, 1.8}
}

for _, v in pairs(group_size_chances) do
    for _ = 1, v[1], 1 do
        table_insert(group_size_modifier_raffle, v[2])
    end
end
local group_size_modifier_raffle_size = #group_size_modifier_raffle

local function valid(userdata)
    if not (userdata and userdata.valid) then
        return false
    end
    return true
end

local function find_initial_spot(surface, position)
    local spot = WD.get('spot')
    if not spot then
        local pos = surface.find_non_colliding_position('rocket-silo', position, 128, 1)
        if not pos then
            pos = surface.find_non_colliding_position('rocket-silo', position, 148, 1)
        end
        if not pos then
            pos = surface.find_non_colliding_position('rocket-silo', position, 164, 1)
        end
        if not pos then
            pos = position
        end

        WD.set('spot', pos)
        return pos
    else
        spot = WD.get('spot')
        return spot
    end
end

local function is_closer(pos1, pos2, pos)
    return ((pos1.x - pos.x) ^ 2 + (pos1.y - pos.y) ^ 2) < ((pos2.x - pos.x) ^ 2 + (pos2.y - pos.y) ^ 2)
end

local function shuffle_distance(tbl, position)
    local size = #tbl
    for i = size, 1, -1 do
        local rand = math_random(size)
        if is_closer(tbl[i].position, tbl[rand].position, position) and i > rand then
            tbl[i], tbl[rand] = tbl[rand], tbl[i]
        end
    end
    return tbl
end

local function is_position_near(pos_to_check, check_against)
    local function inside(pos)
        return pos.x >= pos_to_check.x and pos.y >= pos_to_check.y and pos.x <= pos_to_check.x and pos.y <= pos_to_check.y
    end

    if inside(check_against) then
        return true
    end

    return false
end

local function remove_trees(entity)
    if not valid(entity) then
        return
    end
    local surface = entity.surface
    local radius = 10
    local pos = entity.position
    local area = {{pos.x - radius, pos.y - radius}, {pos.x + radius, pos.y + radius}}
    local trees = surface.find_entities_filtered {area = area, type = 'tree'}
    if #trees > 0 then
        for i, tree in pairs(trees) do
            if tree and tree.valid then
                tree.destroy()
            end
        end
    end
end

local function remove_rocks(entity)
    if not valid(entity) then
        return
    end
    local surface = entity.surface
    local radius = 10
    local pos = entity.position
    local area = {{pos.x - radius, pos.y - radius}, {pos.x + radius, pos.y + radius}}
    local rocks = surface.find_entities_filtered {area = area, type = 'simple-entity'}
    if #rocks > 0 then
        for i, rock in pairs(rocks) do
            if rock and rock.valid then
                rock.destroy()
            end
        end
    end
end

local function fill_tiles(entity, size)
    if not valid(entity) then
        return
    end
    local surface = entity.surface
    local radius = size or 10
    local pos = entity.position
    local t = {
        'water',
        'water-green',
        'water-mud',
        'water-shallow',
        'deepwater',
        'deepwater-green'
    }
    local area = {{pos.x - radius, pos.y - radius}, {pos.x + radius, pos.y + radius}}
    local tiles = surface.find_tiles_filtered {area = area, name = t}
    if #tiles > 0 then
        for _, tile in pairs(tiles) do
            surface.set_tiles({{name = 'sand-1', position = tile.position}}, true)
        end
    end

if size == 50 then
    local litter_are = {{pos.x - 40, pos.y - 40}, {pos.x + 40, pos.y + 40}}
    for _, e in pairs(surface.find_entities_filtered({type = {"cliff"}, area = litter_are})) do
      e.destroy()
    end
end

end

-- 获取虫子生成点
local function get_spawn_pos()
    return {x = 250 + math.random(-10, 10), y = math.random(-50, 50)}


    -- local surface_index = WD.get('surface_index')
    -- local surface = game.surfaces[surface_index]
    -- if not surface then

    -- end

    -- local c = 0

    -- ::retry::

    -- local initial_position = WD.get('spawn_position')

    -- local located_position = find_initial_spot(surface, initial_position)
    -- local valid_position = surface.find_non_colliding_position('behemoth-biter', located_position, 32, 1)
    -- local debug = WD.get('debug')
    -- if debug then
    --     if valid_position then
    --         local x = valid_position.x
    --         local y = valid_position.y
    --         game.print('[gps=' .. x .. ',' .. y .. ',' .. surface.name .. ']')
    --     end
    -- end

    -- if not valid_position then
    --     local remove_entities = WD.get('remove_entities')
    --     if remove_entities then
    --         c = c + 1
    --         valid_position = WD.get('spawn_position')

    --         remove_trees({surface = surface, position = valid_position, valid = true})
    --         remove_rocks({surface = surface, position = valid_position, valid = true})
    --         fill_tiles({surface = surface, position = valid_position, valid = true})
    --         WD.set('spot', 'nil')
    --         if c == 5 then
    --             return
    --         end
    --         goto retry
    --     else
    --         return
    --     end
    -- end


    -- if valid_position.x < -9000 then
    --     valid_position.x = -9000
    -- end
    -- if valid_position.x > 9000 then
    --     valid_position.x = 9000
    -- end

    -- return valid_position
end

local function is_unit_valid(biter)
    local max_biter_age = WD.get('max_biter_age')
    if not biter.entity then

        return false
    end
    if not biter.entity.valid then

        return false
    end
    if not biter.entity.unit_group then

        return false
    end
    if biter.spawn_tick + max_biter_age < game.tick then

        return false
    end
    return true
end

local function refresh_active_unit_threat()
    -- 清理虫子蓝图
    local surface_index = WD.get('surface_index')
    local surface = game.surfaces[surface_index]
    for _, ghost in pairs(surface.find_entities_filtered({force = "enemy", type = {'entity-ghost', 'tile-ghost'}})) do
        ghost.destroy()
    end

    local active_biter_threat = WD.get('active_biter_threat')
    local active_biters = WD.get('active_biters')

    local biter_threat = 0
    for k, biter in pairs(active_biters) do
        if valid(biter.entity) then
            biter_threat = biter_threat + threat_values[biter.entity.name]
        else
            active_biters[k] = nil
        end
    end
    local biter_health_boost = BiterHealthBooster.get('biter_health_boost')
    WD.set('active_biter_threat', math_round(biter_threat * biter_health_boost, 2))

end

local function time_out_biters()
    local active_biters = WD.get('active_biters')
    local active_biter_count = WD.get('active_biter_count')
    local active_biter_threat = WD.get('active_biter_threat')

    if active_biter_count >= 100 and #active_biters <= 10 then
        WD.set('active_biter_count', 50)
    end

    local biter_health_boost = BiterHealthBooster.get('biter_health_boost')

    for k, biter in pairs(active_biters) do
        if not is_unit_valid(biter) then
            WD.set('active_biter_count', active_biter_count - 1)
            if biter.entity then
                if biter.entity.valid then
                    WD.set('active_biter_threat', active_biter_threat - math_round(threat_values[biter.entity.name] * biter_health_boost, 2))
                    if biter.entity.force.index == 2 then
                        biter.entity.destroy()
                    end

                end
            end
            active_biters[k] = nil
        end
    end
end

local function get_random_close_spawner()
    local nests = WD.get('nests')
    local target = WD.get('target')
    local get_random_close_spawner_attempts = WD.get('get_random_close_spawner_attempts')
    local center = target.position
    local spawner
    local retries = 0
    for i = 1, get_random_close_spawner_attempts, 1 do
        ::retry::
        if #nests < 1 then
            return false
        end
        local k = math_random(1, #nests)
        local spawner_2 = nests[k]
        if not spawner_2 or not spawner_2.valid then
            nests[k] = nil
            retries = retries + 1
            if retries == 5 then
                break
            end
            goto retry
        end
        if not spawner or (center.x - spawner_2.position.x) ^ 2 + (center.y - spawner_2.position.y) ^ 2 < (center.x - spawner.position.x) ^ 2 + (center.y - spawner.position.y) ^ 2 then
            spawner = spawner_2
        end
    end

    return spawner
end

local function get_random_character()
    local characters = {}
    local surface_index = WD.get('surface_index')
    local p = game.connected_players
    for _, player in pairs(p) do
        if player.character then
            if player.character.valid then
                if player.character.surface.index == surface_index then
                    characters[#characters + 1] = player.character
                end
            end
        end
    end
    if #characters== 0 then return nil end
    return characters[math.random(#characters)]
end

local function get_car_number()
  local this=WPT.get()
  local car_number=0
  if this.worm and this.worm.valid then
    car_number=car_number+1
  end
--   for k, player in pairs(game.connected_players) do
--     if  this.tank[player.index] and this.tank[player.index].valid then
--     car_number=car_number+1
--     end
--   end
  return car_number
end

local function set_main_target()
    local this=WPT.get()
    local target = WD.get('target')
    local main_surface= game.surfaces[this.active_surface_index]
    if target then
        if target.valid and target.destructible and target.surface==main_surface then
            return
        end
    end

    local sec_target = this.worm
    if sec_target and sec_target.valid then
        WD.set('target', sec_target)
        return
    end
    -- local number = get_car_number()
    -- if number ~= 0 then
    -- sec_target = get_random_car(true)
    -- else
    sec_target = get_random_character()
    -- end

    WD.set('target', sec_target)

end

local function set_group_spawn_position(surface)
    local spawner = get_random_close_spawner()
    if not spawner then
        -- game.print('没有可用的地点')
        return
    end
    -- spawner.y = math.random(-100,100)
    -- game.print('出生位置[gps=' .. spawner.position.position.x .. ',' .. spawner.position.position.y .. ',' .. surface.name .. ']')
    local position = surface.find_non_colliding_position('behemoth-biter', spawner.position, 32, 1)
    if not position then
        return
    end
    WD.set('spawn_position', {x = position.x, y = position.y})
    -- local spawn_position = get_spawn_pos()

end


local function set_enemy_evolution()
    local wave_number = WD.get('wave_number')
    local biter_health_boost = WD.get('biter_health_boost')
    local threat = WD.get('threat')
    local evolution_factor = wave_number * 0.0005
    local biter_h_boost = 1
    local enemy = game.forces.enemy

    if evolution_factor > 1 then
        evolution_factor = 1
    end

    -- if biter_health_boost then
    --     biter_h_boost = math_round(biter_health_boost + (threat - 5000) * 0.000044, 3)
    -- else
    --     biter_h_boost = math_round(biter_h_boost + (threat - 5000) * 0.000044, 3)
    -- end
    -- 威胁加血量
    biter_h_boost = math_round(threat * 0.00001 , 3)
    if biter_h_boost <= 1 then
        biter_h_boost = 1
    end

    BiterHealthBooster.set('biter_health_boost', biter_h_boost)
     if enemy.evolution_factor == 1 and evolution_factor == 1 then
        return
     end
    --
     if evolution_factor <= enemy.evolution_factor then return end
     enemy.evolution_factor = evolution_factor
end

local function can_units_spawn()
    -- local threat = WD.get('threat')

    -- if threat <= 0 then

    --     time_out_biters()
    --     return false
    -- end

    -- local active_biter_count = WD.get('active_biter_count')
    -- local max_active_biters = WD.get('max_active_biters')
    -- if active_biter_count >= max_active_biters then

    --     time_out_biters()
    --     return false
    -- end

    -- local active_biter_threat = WD.get('active_biter_threat')
    -- if active_biter_threat >= threat then

    --     time_out_biters()
    --     return false
    -- end
    return true
end

local function get_active_unit_groups_count()
    local unit_groups = WD.get('unit_groups')
    local count = 0

    for k, g in pairs(unit_groups) do
        if g.valid then
            if #g.members > 0 then
                count = count + 1
            else
                g.destroy()
            end
        else
            unit_groups[k] = nil
            local unit_group_last_command = WD.get('unit_group_last_command')
            if unit_group_last_command[k] then
                unit_group_last_command[k] = nil
            end
            local unit_group_pos = WD.get('unit_group_pos')
            local positions = unit_group_pos.positions
            if positions[k] then
                positions[k] = nil
            end
        end
    end

    return count
end

-- 生成大怪兽
local function spawn_big_biter(surface, N, unit_group)
    -- fake_human_machine_gunner=怀里揣着冲锋枪的靓仔
    -- fake_human_melee=拿⛏镐的靓仔
    -- fake_human_pistol_gunner=怀里揣着手枪的靓仔
    -- fake_human_sniper=怀里揣着狙击枪的靓仔
    -- fake_human_laser=怀里揣着激光枪的靓仔
    -- fake_human_electric=怀里揣着电磁枪的靓仔
    -- fake_human_erocket=怀里揣着火箭发射器的靓仔
    -- fake_human_rocket=怀里揣着火箭发射器的靓仔
    -- fake_human_grenade=怀里揣着手榴弹的靓仔 代号穿山甲
    -- fake_human_cluster_grenade=怀里揣着集束手榴弹的靓仔
    -- fake_human_nuke_rocket=怀里揣着核弹的靓仔
    -- fake_human_cannon=怀里揣着加农炮的靓仔
    -- fake_human_cannon_explosive=怀里揣着大炮的靓仔

    -- fake_human_boss_machine_gunner=怀里揣着冲锋枪的大魔王
    -- fake_human_boss_pistol_gunner=怀里揣着手枪的大魔王
    -- fake_human_boss_sniper=怀里揣着狙击枪的大魔王
    -- fake_human_boss_laser=怀里揣着激光枪的大魔王
    -- fake_human_boss_electric=怀里揣着电磁枪的大魔王
    -- fake_human_boss_erocket=怀里揣着机枪的大魔王
    -- fake_human_boss_rocket=怀里揣着机枪的大魔王
    -- fake_human_boss_grenade=怀里揣着手榴弹的大魔王
    -- fake_human_boss_cluster_grenade=怀里揣着集束手榴弹的大魔王
    -- fake_human_boss_nuke_rocket=怀里揣着核弹的大魔王
    -- fake_human_boss_cannon_explosive=怀里揣着高爆加农炮的大魔王

    -- fake_human_ultimate_boss_cannon=超级加农炮大魔王

    local nname = "";
    -- 靓仔和魔王
    local liangzai = {
        [1] = 'tc_fake_human_machine_gunner_',
        [2] = 'tc_fake_human_melee_',
        [3] = 'tc_fake_human_pistol_gunner_',
        [4] = 'tc_fake_human_sniper_',
        [5] = 'tc_fake_human_laser_',
        [6] = 'tc_fake_human_electric_',
        [7] = 'tc_fake_human_erocket_',
        [8] = 'tc_fake_human_rocket_',
        [9] = 'tc_fake_human_grenade_',
        [10] = 'tc_fake_human_cluster_grenade_',
        [11] = 'tc_fake_human_nuke_rocket_',
        [12] = 'tc_fake_human_cannon_',
        [13] = 'tc_fake_human_cannon_explosive_',

    }
    
    local mowang = {
        [1] = 'tc_fake_human_boss_machine_gunner_',
        [2] = 'tc_fake_human_boss_pistol_gunner_',
        [3] = 'tc_fake_human_boss_sniper_',
        [4] = 'tc_fake_human_boss_laser_',
        [5] = 'tc_fake_human_boss_electric_',
        [6] = 'tc_fake_human_boss_erocket_',
        [7] = 'tc_fake_human_boss_rocket_',
        [8] = 'tc_fake_human_boss_grenade_',
        [9] = 'tc_fake_human_boss_cluster_grenade_',
        [10] = 'tc_fake_human_boss_nuke_rocket_',
        [11] = 'tc_fake_human_boss_cannon_explosive_',
    }


    local function func(name)
        if nname == ""  or math_random(1, 200) < 100 then
            nname = name
        end
        if (surface ~= nil and unit_group ~= nil) then
            local position = get_spawn_pos()
            local biter = surface.create_entity({name = name, position = position, force = 'enemy'})
            biter.ai_settings.allow_destroy_when_commands_fail = false
            biter.ai_settings.allow_try_return_to_spawner = true
            biter.ai_settings.do_separation = true
            unit_group.add_member(biter)
        end
    end

    local rd = 1

    -- 人类
    local function get_hm(lv,fg)
        -- 4个靓仔
        if not fg then
            rd = math_random(1, 13)
            func(liangzai[rd]..lv)
        end

        -- 1个魔王
        if fg then
            rd = math_random(1, 11)
            func(mowang[rd]..lv)
        end
    end


    if N == 1 then
        func('maf-boss-biter-1') 
    elseif N == 2 then
        func('maf-boss-acid-spitter-1') 
    elseif N == 3 then
        func('maf-boss-biter-2') 
    elseif N == 4 then
        func('maf-boss-acid-spitter-2') 
    elseif N == 5 then
        func('maf-boss-biter-3')         
    elseif N == 6 then
        func('maf-boss-acid-spitter-3')
    elseif N == 7 then
        func('maf-boss-biter-4')  
    elseif N == 8 then
        func('maf-boss-acid-spitter-4')
    elseif N == 9 then
        func('maf-boss-biter-5') 
    elseif N == 10 then
        func('maf-boss-acid-spitter-5')
    elseif N == 11 then
        func('maf-boss-biter-6')
    elseif N == 12 then
        func('maf-boss-acid-spitter-6')
    elseif N == 13 then
        func('maf-boss-biter-7')
    elseif N == 14 then
        func('maf-boss-acid-spitter-7')
    elseif N == 15 then
        func('maf-boss-biter-8')
    elseif N == 16 then
        func('maf-boss-acid-spitter-8')
    elseif N == 17 then
        func('maf-boss-biter-9')
    elseif N == 18 then
        func('maf-boss-acid-spitter-9')
    elseif N == 19 then
        func('maf-boss-biter-10')
    elseif N == 20 then
        func('maf-boss-acid-spitter-10')
    elseif N == 21 then
        func('biterzilla21')
    elseif N == 22 then
        func('biterzilla22')
    elseif N == 23 then
        func('biterzilla11')
    elseif N == 24 then
        func('biterzilla23')
    elseif N == 25 then
        func('biterzilla12')
    elseif N == 26 then
        func('biterzilla31')
    elseif N == 27 then
        func('biterzilla24')
    elseif N == 28 then
        func('biterzilla13')
    elseif N == 29 then
        get_hm('1',false)
        func('biterzilla32')
    elseif N == 30 then
        get_hm('2',false)
        func('biterzilla25')
    elseif N == 31 then
        get_hm('3',false)
        func('biterzilla14')
    elseif N == 32 then
        get_hm('4',false)
        func('biterzilla33')
    elseif N == 33 then
        get_hm('5',false)
        func('biterzilla15')
    elseif N == 34 then
        get_hm('6',false)
        func('biterzilla34')
    elseif N == 35 then
        get_hm('7',false)
        func('biterzilla35')
    elseif N == 36 then
        get_hm('8',false)
        func('maf-giant-acid-spitter1')
    elseif N == 37 then
        get_hm('9',false)
        func('bm-motherbiterzilla1')
    elseif N == 38 then
        get_hm('10',false)
        func('maf-giant-fire-spitter1')
    elseif N == 39 then
        get_hm('1',true)
        func('maf-giant-acid-spitter2')
    elseif N == 40 then
        get_hm('2',true)
        func('bm-motherbiterzilla2')
    elseif N == 41 then
        get_hm('3',true)
        func('maf-giant-fire-spitter2')
    elseif N == 42 then
        get_hm('4',true)
        func('maf-giant-acid-spitter3')
    elseif N == 43 then
        get_hm('5',true)
        func('bm-motherbiterzilla3')
    elseif N == 44 then
        get_hm('6',true)
        func('maf-giant-fire-spitter3')
    elseif N == 45 then
        get_hm('6',true)
        func('maf-giant-acid-spitter4')
    elseif N == 46 then
        get_hm('7',true)
        func('bm-motherbiterzilla4')
    elseif N == 47 then
        get_hm('8',true)
        func('maf-giant-fire-spitter4')
    elseif N == 48 then
        get_hm('9',true)
        func('maf-giant-acid-spitter5')
    elseif N == 49 then
        get_hm('10',true)
        func('bm-motherbiterzilla5')
    elseif N == 50 then
        func('maf-giant-fire-spitter5')
        func('tc_fake_human_ultimate_boss_cannon_20')
    elseif N > 50 then
        -- N = N-50
        -- N = N * N
        -- game.print("挑战开始！大怪兽倍数:"..N,{r = 1, g = 0, b = 0})
        -- for i = 1, N do
            get_hm('10',true)
            func('maf-boss-biter-10')
            func('maf-boss-acid-spitter-10')
            func('biterzilla15')
            func('biterzilla25')
            func('biterzilla35')
            func('bm-motherbiterzilla5')
            func('maf-giant-fire-spitter5')
            func('tc_fake_human_ultimate_boss_cannon_20')
        -- end
    end

    return nname
end



local function wave_defense_roll_spitter_name()
    local wave_number = WD.get("wave_number") - global.StarWave;
    if wave_number <= 50 then return 'small-spitter' end
    if wave_number <= 100 then return 'medium-spitter' end
    if wave_number <= 150 then return 'big-spitter' end
    if wave_number <= 200 then return 'behemoth-spitter' end
    N = math_floor((wave_number - 200)/ 55) + 1
    return spawn_big_biter(nil, N, nil)
end


local function wave_defense_roll_biter_name()
    local wave_number = WD.get("wave_number") - global.StarWave;

    if wave_number <= 50 then return 'small-biter' end
    if wave_number <= 100 then return 'medium-biter' end
    if wave_number <= 150 then return 'big-biter' end
    if wave_number <= 200 then return 'behemoth-biter' end
    N = math_floor((wave_number - 200)/ 55) + 1
    return spawn_big_biter(nil, N, nil)
end


local function spawn_biter(surface, is_boss_biter)
    if not is_boss_biter then
        if not can_units_spawn() then
            return
        end
    end

    local boosted_health = BiterHealthBooster.get('biter_health_boost')

    local name
    if math_random(1, 100) > 73 then
        name = wave_defense_roll_spitter_name()
    else
        name = wave_defense_roll_biter_name()
    end
    local position = get_spawn_pos()

    local biter = surface.create_entity({name = name, position = position, force = 'enemy'})
    biter.ai_settings.allow_destroy_when_commands_fail = true
    biter.ai_settings.allow_try_return_to_spawner = true
    biter.ai_settings.do_separation = true

    local increase_health_per_wave = WD.get('increase_health_per_wave')

    if increase_health_per_wave and not is_boss_biter then
        local modified_unit_health = WD.get('modified_unit_health')
        BiterHealthBooster.add_unit(biter, modified_unit_health.current_value)
    end
    local map=diff.get()
    if is_boss_biter then
        local increase_boss_health_per_wave = WD.get('increase_boss_health_per_wave')
        if increase_boss_health_per_wave then
            local modified_boss_unit_health = WD.get('modified_boss_unit_health')
            BiterHealthBooster.add_boss_unit(biter, modified_boss_unit_health, 0.55)
        else
            local buff_k = 10
            local wave_number = WD.get('wave_number')
            if wave_number>=2000 and map.final_wave then buff_k = 15 end
            local sum = boosted_health * buff_k

            BiterHealthBooster.add_boss_unit(biter, sum, 0.55)
        end
    end

    WD.set('active_biters')[biter.unit_number] = {entity = biter, spawn_tick = game.tick}
    local active_biter_count = WD.get('active_biter_count')
    WD.set('active_biter_count', active_biter_count + 1)
    -- local active_biter_threat = WD.get('active_biter_threat')
    -- WD.set('active_biter_threat', active_biter_threat + math_round(threat_values[name] * boosted_health, 2))
    return biter
end

local function reform_group(group)
    local unit_group_command_step_length = WD.get('unit_group_command_step_length')
    local group_position = {x = group.position.x, y = group.position.y}
    local step_length = unit_group_command_step_length
    local position = group.surface.find_non_colliding_position('biter-spawner', group_position, step_length, 4)
    if position then
        local new_group = group.surface.create_unit_group {position = position, force = group.force}
        for key, biter in pairs(group.members) do
            new_group.add_member(biter)
        end

        local unit_groups = WD.get('unit_groups')
        unit_groups[new_group.group_number] = new_group

        return new_group
    else

        local unit_groups = WD.get('unit_groups')
        if unit_groups[group.group_number] then
            local unit_group_last_command = WD.get('unit_group_last_command')
            if unit_group_last_command[group.group_number] then
                unit_group_last_command[group.group_number] = nil
            end
            local unit_group_pos = WD.get('unit_group_pos')
            local positions = unit_group_pos.positions
            if positions[group.group_number] then
                positions[group.group_number] = nil
            end
            table.remove(unit_groups, group.group_number)
        end
        group.destroy()
    end
    return nil
end


local function get_main_command(group)
    local unit_group_command_step_length = WD.get('unit_group_command_step_length')
    local commands = {}
    local group_position = {x = group.position.x, y = group.position.y}
    local step_length = unit_group_command_step_length

    local target = WD.get('target')
    if not valid(target) then
        return
    end



    local target_position = target.position
    local distance_to_target = math_floor(math_sqrt((target_position.x - group_position.x) ^ 2 + (target_position.y - group_position.y) ^ 2))
    local steps = math_floor(distance_to_target / step_length) + 1
    local vector = {
        math_round((target_position.x - group_position.x) / steps, 3),
        math_round((target_position.y - group_position.y) / steps, 3)
    }



    for i = 1, steps, 1 do
        local old_position = group_position
        group_position.x = group_position.x + vector[1]
        group_position.y = group_position.y + vector[2]
        local obstacles =
            group.surface.find_entities_filtered {
            position = old_position,
            radius = step_length / 2,
            type = {'simple-entity', 'tree'},
            limit = 50
        }
        if obstacles then
            shuffle_distance(obstacles, old_position)
            for i = 1, #obstacles, 1 do
                if obstacles[i].valid then
                    commands[#commands + 1] = {
                        type = defines.command.attack,
                        target = obstacles[i],
                        distraction = defines.distraction.by_anything
                    }
                end
            end
        end
        local position = group.surface.find_non_colliding_position('behemoth-biter', group_position, step_length, 1)
        if position then
            commands[#commands + 1] = {
                type = defines.command.attack_area,
                destination = {x = position.x, y = position.y},
                radius = 16,
                distraction = defines.distraction.by_anything
            }
        end
    end

    commands[#commands + 1] = {
        type = defines.command.attack_area,
        destination = {x = target_position.x, y = target_position.y},
        radius = 8,
        distraction = defines.distraction.by_anything
    }

    commands[#commands + 1] = {
        type = defines.command.attack,
        target = target,
        distraction = defines.distraction.by_anything
    }

    return commands
end

local function command_to_main_target(group, bypass)
    if not valid(group) then
        return
    end
    local unit_group_last_command = WD.get('unit_group_last_command')
    local unit_group_command_delay = WD.get('unit_group_command_delay')
    if not bypass then
        if not unit_group_last_command[group.group_number] then
            unit_group_last_command[group.group_number] = game.tick - (unit_group_command_delay + 1)
        end

        if unit_group_last_command[group.group_number] then
            if unit_group_last_command[group.group_number] + unit_group_command_delay > game.tick then
                return
            end
        end
    end

    local fill_tiles_so_biter_can_path = WD.get('fill_tiles_so_biter_can_path')
    if fill_tiles_so_biter_can_path then
        fill_tiles(group, 10)
    end

    local tile = group.surface.get_tile(group.position)
    if tile.valid and tile.collides_with('player-layer') then
        group = reform_group(group)
    end
    if not valid(group) then
        return
    end

    local commands = get_main_command(group)



    local surface_index = WD.get('surface_index')

    if group.surface.index ~= surface_index then
        return
    end

    group.set_command(
        {
            type = defines.command.compound,
            structure_type = defines.compound_command.return_last,
            commands = commands
        }
    )

    if valid(group) then
        unit_group_last_command[group.group_number] = game.tick
    end
end

local function command_to_side_target(group)
    local unit_group_last_command = WD.get('unit_group_last_command')
    local unit_group_command_delay = WD.get('unit_group_command_delay')
    if not unit_group_last_command[group.group_number] then
        unit_group_last_command[group.group_number] = game.tick - (unit_group_command_delay + 1)
    end

    if unit_group_last_command[group.group_number] then
        if unit_group_last_command[group.group_number] + unit_group_command_delay > game.tick then
            return
        end
    end

    local tile = group.surface.get_tile(group.position)
    if tile.valid and tile.collides_with('player-layer') then
        group = reform_group(group)
    end

    local commands = get_side_targets(group)

    group.set_command(
        {
            type = defines.command.compound,
            structure_type = defines.compound_command.return_last,
            commands = commands
        }
    )

    unit_group_last_command[group.group_number] = game.tick
end


local function give_main_command_to_group()
    local target = WD.get('target')
    if not valid(target) then
        return
    end

    local unit_groups = WD.get('unit_groups')
    for k, group in pairs(unit_groups) do
        if type(group) ~= 'number' then
            if group.valid then
                if group.surface.index == target.surface.index then
                    command_to_main_target(group)
                end
            else
                get_active_unit_groups_count()
            end
        end
    end
end

local function spawn_unit_group()
    -- if not can_units_spawn() then

    --     return
    -- end
    local target = WD.get('target')
    if not valid(target) then

        return
    end

    local max_active_unit_groups = WD.get('max_active_unit_groups')
    if get_active_unit_groups_count() >= max_active_unit_groups then

        return
    end
    local surface_index = WD.get('surface_index')
    local remove_entities = WD.get('remove_entities')

    local surface = game.surfaces[surface_index]
    set_group_spawn_position(surface)

    local spawn_position = get_spawn_pos()  -- 获取虫子生成点
    if not spawn_position then
        return
    end


    if remove_entities then
        remove_trees({surface = surface, position = spawn_position, valid = true})
        remove_rocks({surface = surface, position = spawn_position, valid = true})
        fill_tiles({surface = surface, position = spawn_position, valid = true})
    end

    local wave_number = WD.get('wave_number')
    local WN = wave_number      -- 波数

    -- BiterRolls.wave_defense_set_unit_raffle(wave_number)


    local position = spawn_position

    local unit_group_pos = WD.get('unit_group_pos')

    local StarWave = global.StarWave
    if WN - StarWave < 4 then
        game.print('虫子出现了！[gps=' .. position.x .. ',' .. position.y .. ',' .. surface.name .. ']')
    end
    
    -- 每50波加入大怪兽
    local N = math.floor(WN / 50) 
    -- N = 60
    if WD.get("BigWave") < N then
        WD.set("BigWave", WD.get("BigWave") + 1)
        local M = 1
        if N > 50 then
            M = N - 50
        end
        game.print('第'..N..'波大怪兽来袭！[gps=' .. position.x .. ',' .. position.y .. ',' .. surface.name .. ']全体开局技能点+1')

        global.RPG_POINT.total = global.RPG_POINT.total + 1

        raw_print('第'..N..'波大怪兽来袭！'.. position.x .. ',' .. position.y )
        if N > 50 then
            game.print('挑战开始！大怪兽倍速'..M)
        end
        
        local unit_groups = WD.get('unit_groups')
        for i = 1, M do
            local unit_group = surface.create_unit_group({position = {0, 0}, force = 'enemy'})
            spawn_big_biter(surface, N, unit_group)
            unit_group_pos.positions[unit_group.group_number] = {position = unit_group.position, index = 0}
            unit_groups[unit_group.group_number] = unit_group
        end
    end
    
    local unit_group = surface.create_unit_group({position = {0,0 }, force = 'enemy'})
    unit_group_pos.positions[unit_group.group_number] = {position = unit_group.position, index = 0}
    -- local average_unit_group_size = WD.get('average_unit_group_size')
    -- local group_size = math_floor(average_unit_group_size * group_size_modifier_raffle[math_random(1, group_size_modifier_raffle_size)])
    local group_size = 16;
    for _ = 1, group_size, 1 do
        local biter = spawn_biter(surface)
        if not biter then
            break
        end
        unit_group.add_member(biter)

        -- command_to_side_target(unit_group)
    end

    local boss_wave = WD.get('boss_wave')
    if boss_wave then
        local count = math_random(1, math_floor(wave_number * 0.01) + 2)
        if count > 8 then
            count = 8
        end
        if count <= 1 then
            count = 4
        end
        local map=diff.get()
        if map.final_wave and count <= 12 then
          count=12
        end
        for _ = 1, count, 1 do
            local biter = spawn_biter(surface, true)
            if not biter then

                break
            end
            unit_group.add_member(biter)
        end


        WD.set('boss_wave', false)
    end

 
    local unit_groups = WD.get('unit_groups')
    unit_groups[unit_group.group_number] = unit_group
    if math_random(1, 2) == 1 then
        WD.set('random_group', unit_group.group_number)
    end
    WD.set('spot', 'nil')
    return true
end

local function set_next_wave()
    if global.StarWave and global.StarWave < 0 then
        game_over()
        return
    end
    -- get_new_arty()
    spawn_unit_group()
    local wave_number = WD.get('wave_number')
    if wave_number < global.StarWave then
        wave_number = global.StarWave - 1
    -- elseif wave_number >= global.StarWave + 300 and wave_number < global.StarWave + 303 then
    --     game.print("好消息！好消息！现在杀虫子可以加科研了！",{r = 1, g = 0, b = 0})
    --     game.print("好消息！好消息！现在杀虫子可以加科研了！",{r = 1, g = 0, b = 0})
    --     game.print("好消息！好消息！现在杀虫子可以加科研了！",{r = 1, g = 0, b = 0})
    elseif wave_number == global.StarWave + 1000 then
        game.print("还有2000波结束，加油！",{r = 1, g = 0, b = 0})
    elseif wave_number == global.StarWave + 2000 then
        game.print("还有1000波结束，加油！",{r = 1, g = 0, b = 0})
    elseif wave_number == global.StarWave + 2500 then
        game.print("还有500波结束，坚持住！",{r = 1, g = 0, b = 0})
    end
    WD.set('wave_number', wave_number + 1)
    wave_number = WD.get('wave_number')

    -- local threat_gain_multiplier = WD.get('threat_gain_multiplier')
    -- local threat_gain = wave_number * threat_gain_multiplier
    -- if wave_number > 1000 then
    --     threat_gain = threat_gain * (wave_number * 0.001)^2
    -- end
    -- 设置威胁值
    local StarWave = 0;
    if global.StarWave then StarWave = global.StarWave end
    local threat_gain = (wave_number*(3 + StarWave/100))^2
    local map=diff.get()
    local boss_interval = 25
    if wave_number>=2000 then boss_interval = 5 end
    if wave_number>=2500 and map.final_wave then boss_interval = 3 end
    if wave_number % boss_interval == 0 then
        WD.set('boss_wave', true)
        WD.set('boss_wave_warning', true)
        local alert_boss_wave = WD.get('alert_boss_wave')
        local spawn_position = get_spawn_pos()
        if alert_boss_wave then
            local msg = 'Boss Wave: ' .. wave_number
            local pos = {
                position = spawn_position
            }
            Alert.alert_all_players_location(pos, msg, {r = 0.8, g = 0.1, b = 0.1})
        end
    else
        local boss_wave_warning = WD.get('boss_wave_warning')
        if boss_wave_warning then
            WD.set('boss_wave_warning', false)
        end
    end

    local threat = WD.get('threat')
    WD.set('threat', math_floor(threat_gain))

    -- local wave_enforced = WD.get('wave_enforced')
    local next_wave = WD.get('next_wave')
    -- local wave_interval = WD.get('wave_interval')
    -- if not wave_enforced then
        WD.set('last_wave', next_wave)
        raw_print("当前波次:"..wave_number.."/"..(global.StarWave+3000))
        
        -- WD.set('next_wave', game.tick + 60*30)-- 30s一波

        -- local surface_index = WD.get('surface_index')
        -- local surface = game.surfaces[surface_index]
        -- surface.clear_pollution()

        wave_number = wave_number - global.StarWave
        if wave_number<=25 then
            WD.set('next_wave', game.tick + 60*15)
        elseif wave_number<=50 then
            WD.set('next_wave', game.tick + 60*12)
        elseif wave_number<=200 then
            WD.set('next_wave', game.tick + 60*8)
        elseif wave_number<=500 then
            WD.set('next_wave', game.tick + 60*5)
        else
            WD.set('next_wave', game.tick + 60*4)
        end

        
        -- WD.set('next_wave', game.tick + 60)   -- 一秒钟一波
        
    -- end WD.get('game_lost')

    if wave_number >= 3000 then
        game.print("*****************恭喜！挑战成功！*****************",{r = 1, g = 0, b = 0})
        game.print("*****************60s后开始下一局*****************",{r = 1, g = 0, b = 0})
        global.StarWave = -global.StarWave - 50
        WD.set('next_wave', game.tick + 60*60)-- 60s
        -- game.forces["enemy"].kill_all_units()
    end


    local clear_corpses = WD.get('clear_corpses')
    if clear_corpses then
        local surface_index = WD.get('surface_index')
        local surface = game.surfaces[surface_index]
        for _, entity in pairs(surface.find_entities_filtered {type = 'corpse'}) do
            if math_random(1, 2) == 1 then
                entity.destroy()
            end
        end
    end
end
Public.set_next_wave = set_next_wave

local function check_group_positions()
    local unit_groups = WD.get('unit_groups')
    local unit_group_pos = WD.get('unit_group_pos')
    local target = WD.get('target')
    if not valid(target) then
        return
    end

    for k, group in pairs(unit_groups) do
        if group.valid then
            local ugp = unit_group_pos.positions
            if group.state == defines.group_state.finished then
                return command_to_main_target(group, true)
            end
            if ugp[group.group_number] then
                local success = is_position_near(group.position, ugp[group.group_number].position)
                if success then
                    ugp[group.group_number].index = ugp[group.group_number].index + 1
                    if ugp[group.group_number].index >= 2 then
                        command_to_main_target(group, true)
                        fill_tiles(group, 50)
                        remove_rocks(group)
                        remove_trees(group)
                        if ugp[group.group_number].index >= 4 then
                            unit_group_pos.positions[group.group_number] = nil
                            reform_group(group)
                        end
                    end
                end
            end
        end
    end
end

local function log_threat()
    local threat_log_index = WD.get('threat_log_index')
    WD.set('threat_log_index', threat_log_index + 1)
    local threat_log = WD.get('threat_log')
    local threat = WD.get('threat')
    threat_log_index = WD.get('threat_log_index')
    threat_log[threat_log_index] = threat
    if threat_log_index > 900 then
        threat_log[threat_log_index - 901] = nil
    end
end

local tick_tasks = {
    [30] = set_main_target,
    [60] = set_enemy_evolution,
    -- [90] = spawn_unit_group,
    [120] = give_main_command_to_group,
    [150] = ThreatEvent.build_nest,
    [180] = ThreatEvent.build_worm,
    [1200] = give_side_commands_to_group,
    [3600] = time_out_biters,
    [7200] = refresh_active_unit_threat
}

local function on_tick()
    local tick = game.tick
    local game_lost = WD.get('game_lost')
    if game_lost then
        return
    end

    local next_wave = WD.get('next_wave')
    if tick > next_wave then
        set_next_wave()
    end

    local t = tick % 300
    local t2 = tick % 18000

    if tick_tasks[t] then
        tick_tasks[t]()
    end
    if tick_tasks[t2] then
        tick_tasks[t2]()
    end

    local resolve_pathing = WD.get('resolve_pathing')
    if resolve_pathing then
        if tick % 60 == 0 then
            check_group_positions()
        end
    end

    local players = game.connected_players
    for _, player in pairs(players) do
        update_gui(player)
    end
end

Event.on_nth_tick(30, on_tick)

return Public
