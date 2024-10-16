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

local player_build = {
    'small-electric-pole', -- 小电杆
    'medium-electric-pole', -- 中电杆
    'substation', -- 变电站
    'stone-wall', -- 石墙
    'Oem-linked-chest', -- 关联箱
  }

  function Get_spawn_pos(radius)
    -- return {x = 250 + math.random(-10, 10), y = math.random(-30, 30)}

    local a = math_random(-1000, 1000) / 1000
    local b = math_random(-1000, 1000) / 1000

    local c = 160

    local surface_index = WD.get('surface_index')
    local surface = game.surfaces[surface_index]

    while true do
        local temp_pos = {x = a * c, y = b * c}
        local entities = surface.find_entities_filtered{position = temp_pos, radius = radius, name = player_build , force = game.forces.player,limit =1}
        if #entities == 0 then
            return temp_pos
        end
        c = c + 10
    end
end


-- 获取虫子生成点
local function get_spawn_pos()
    return Get_spawn_pos(100)
end


local function refresh_active_unit_threat()
    -- 清理虫子蓝图
    local surface_index = WD.get('surface_index')
    local surface = game.surfaces[surface_index]
    for _, ghost in pairs(surface.find_entities_filtered({force = "enemy", type = {'entity-ghost', 'tile-ghost'}})) do
        ghost.destroy()
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
    biter_h_boost = math_floor(threat * 0.000001)
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

local all_enemies = {
    [1] = "small-spitter",
    [2] = "small-biter",
    [3] = "medium-spitter",
    [4] = "medium-biter",
    [5] = "big-spitter",
    [6] = "brutal-small-biter",
    [7] = "big-biter",
    [8] = "brutal-medium-biter",
    [9] = "behemoth-spitter",
    [10] = "tc_fake_human_machine_gunner_1",
    [11] = "tc_fake_human_laser_1",
    [12] = "tc_fake_human_melee_1",
    [13] = "tc_fake_human_nuke_rocket_1",
    [14] = "tc_fake_human_grenade_1",
    [15] = "tc_fake_human_cluster_grenade_1",
    [16] = "tc_fake_human_electric_1",
    [17] = "tc_fake_human_erocket_1",
    [18] = "tc_fake_human_cannon_explosive_1",
    [19] = "tc_fake_human_pistol_gunner_1",
    [20] = "tc_fake_human_rocket_1",
    [21] = "tc_fake_human_cannon_1",
    [22] = "tc_fake_human_sniper_1",
    [23] = "behemoth-biter",
    [24] = "tc_fake_human_cluster_grenade_2",
    [25] = "tc_fake_human_sniper_2",
    [26] = "tc_fake_human_melee_2",
    [27] = "tc_fake_human_nuke_rocket_2",
    [28] = "tc_fake_human_erocket_2",
    [29] = "tc_fake_human_laser_2",
    [30] = "tc_fake_human_electric_2",
    [31] = "tc_fake_human_pistol_gunner_2",
    [32] = "tc_fake_human_rocket_2",
    [33] = "tc_fake_human_grenade_2",
    [34] = "tc_fake_human_machine_gunner_2",
    [35] = "tc_fake_human_cannon_2",
    [36] = "tc_fake_human_cannon_explosive_2",
    [37] = "tc_fake_human_sniper_3",
    [38] = "tc_fake_human_erocket_3",
    [39] = "tc_fake_human_melee_3",
    [40] = "tc_fake_human_grenade_3",
    [41] = "tc_fake_human_electric_3",
    [42] = "tc_fake_human_machine_gunner_3",
    [43] = "tc_fake_human_nuke_rocket_3",
    [44] = "tc_fake_human_cannon_3",
    [45] = "tc_fake_human_rocket_3",
    [46] = "tc_fake_human_pistol_gunner_3",
    [47] = "tc_fake_human_cannon_explosive_3",
    [48] = "tc_fake_human_laser_3",
    [49] = "tc_fake_human_cluster_grenade_3",
    [50] = "brutal-big-biter",
    [51] = "tc_fake_human_grenade_4",
    [52] = "tc_fake_human_sniper_4",
    [53] = "tc_fake_human_electric_4",
    [54] = "tc_fake_human_cluster_grenade_4",
    [55] = "tc_fake_human_cannon_4",
    [56] = "tc_fake_human_cannon_explosive_4",
    [57] = "tc_fake_human_erocket_4",
    [58] = "tc_fake_human_rocket_4",
    [59] = "tc_fake_human_pistol_gunner_4",
    [60] = "tc_fake_human_melee_4",
    [61] = "tc_fake_human_machine_gunner_4",
    [62] = "tc_fake_human_nuke_rocket_4",
    [63] = "tc_fake_human_laser_4",
    [64] = "tc_fake_human_nuke_rocket_5",
    [65] = "tc_fake_human_cannon_explosive_5",
    [66] = "tc_fake_human_cluster_grenade_5",
    [67] = "tc_fake_human_electric_5",
    [68] = "tc_fake_human_pistol_gunner_5",
    [69] = "tc_fake_human_melee_5",
    [70] = "tc_fake_human_cannon_5",
    [71] = "tc_fake_human_laser_5",
    [72] = "tc_fake_human_erocket_5",
    [73] = "tc_fake_human_grenade_5",
    [74] = "tc_fake_human_rocket_5",
    [75] = "tc_fake_human_sniper_5",
    [76] = "tc_fake_human_machine_gunner_5",
    [77] = "tc_fake_human_laser_6",
    [78] = "tc_fake_human_grenade_6",
    [79] = "tc_fake_human_pistol_gunner_6",
    [80] = "tc_fake_human_cannon_explosive_6",
    [81] = "tc_fake_human_nuke_rocket_6",
    [82] = "tc_fake_human_cluster_grenade_6",
    [83] = "tc_fake_human_electric_6",
    [84] = "tc_fake_human_rocket_6",
    [85] = "tc_fake_human_machine_gunner_6",
    [86] = "tc_fake_human_sniper_6",
    [87] = "tc_fake_human_melee_6",
    [88] = "tc_fake_human_cannon_6",
    [89] = "tc_fake_human_erocket_6",
    [90] = "tc_fake_human_pistol_gunner_7",
    [91] = "tc_fake_human_cannon_7",
    [92] = "tc_fake_human_sniper_7",
    [93] = "tc_fake_human_cannon_explosive_7",
    [94] = "tc_fake_human_erocket_7",
    [95] = "tc_fake_human_laser_7",
    [96] = "tc_fake_human_rocket_7",
    [97] = "tc_fake_human_machine_gunner_7",
    [98] = "tc_fake_human_cluster_grenade_7",
    [99] = "tc_fake_human_melee_7",
    [100] = "tc_fake_human_nuke_rocket_7",
    [101] = "tc_fake_human_grenade_7",
    [102] = "tc_fake_human_electric_7",
    [103] = "tc_fake_human_melee_8",
    [104] = "tc_fake_human_electric_8",
    [105] = "tc_fake_human_pistol_gunner_8",
    [106] = "tc_fake_human_cluster_grenade_8",
    [107] = "tc_fake_human_rocket_8",
    [108] = "tc_fake_human_cannon_explosive_8",
    [109] = "tc_fake_human_grenade_8",
    [110] = "tc_fake_human_sniper_8",
    [111] = "tc_fake_human_laser_8",
    [112] = "tc_fake_human_nuke_rocket_8",
    [113] = "tc_fake_human_machine_gunner_8",
    [114] = "tc_fake_human_cannon_8",
    [115] = "tc_fake_human_erocket_8",
    [116] = "tc_fake_human_pistol_gunner_9",
    [117] = "tc_fake_human_laser_9",
    [118] = "tc_fake_human_cluster_grenade_9",
    [119] = "tc_fake_human_machine_gunner_9",
    [120] = "tc_fake_human_grenade_9",
    [121] = "tc_fake_human_electric_9",
    [122] = "tc_fake_human_erocket_9",
    [123] = "tc_fake_human_cannon_explosive_9",
    [124] = "tc_fake_human_cannon_9",
    [125] = "tc_fake_human_rocket_9",
    [126] = "tc_fake_human_sniper_9",
    [127] = "tc_fake_human_melee_9",
    [128] = "tc_fake_human_nuke_rocket_9",
    [129] = "tc_fake_human_pistol_gunner_10",
    [130] = "tc_fake_human_electric_10",
    [131] = "tc_fake_human_erocket_10",
    [132] = "tc_fake_human_nuke_rocket_10",
    [133] = "tc_fake_human_grenade_10",
    [134] = "tc_fake_human_melee_10",
    [135] = "tc_fake_human_rocket_10",
    [136] = "tc_fake_human_laser_10",
    [137] = "tc_fake_human_machine_gunner_10",
    [138] = "tc_fake_human_cannon_10",
    [139] = "tc_fake_human_sniper_10",
    [140] = "tc_fake_human_cluster_grenade_10",
    [141] = "tc_fake_human_cannon_explosive_10",
    [142] = "brutal-behemoth-biter",
    [143] = "maf-boss-acid-spitter-1",
    [144] = "maf-boss-biter-1",
    [145] = "tc_fake_human_boss_cluster_grenade_1",
    [146] = "tc_fake_human_boss_erocket_1",
    [147] = "tc_fake_human_boss_machine_gunner_1",
    [148] = "tc_fake_human_boss_pistol_gunner_1",
    [149] = "tc_fake_human_boss_electric_1",
    [150] = "tc_fake_human_boss_sniper_1",
    [151] = "tc_fake_human_boss_rocket_1",
    [152] = "tc_fake_human_boss_grenade_1",
    [153] = "tc_fake_human_boss_cannon_explosive_1",
    [154] = "tc_fake_human_boss_laser_1",
    [155] = "tc_fake_human_boss_nuke_rocket_1",
    [156] = "maf-boss-acid-spitter-2",
    [157] = "tc_fake_human_boss_grenade_2",
    [158] = "tc_fake_human_boss_machine_gunner_2",
    [159] = "tc_fake_human_boss_rocket_2",
    [160] = "tc_fake_human_boss_pistol_gunner_2",
    [161] = "maf-boss-biter-2",
    [162] = "tc_fake_human_boss_erocket_2",
    [163] = "tc_fake_human_boss_cannon_explosive_2",
    [164] = "tc_fake_human_boss_laser_2",
    [165] = "tc_fake_human_boss_nuke_rocket_2",
    [166] = "tc_fake_human_boss_electric_2",
    [167] = "tc_fake_human_boss_sniper_2",
    [168] = "tc_fake_human_boss_cluster_grenade_2",
    [169] = "biterzilla21",
    [170] = "tc_fake_human_boss_nuke_rocket_3",
    [171] = "tc_fake_human_boss_cluster_grenade_3",
    [172] = "tc_fake_human_boss_grenade_3",
    [173] = "tc_fake_human_boss_laser_3",
    [174] = "tc_fake_human_boss_erocket_3",
    [175] = "tc_fake_human_boss_pistol_gunner_3",
    [176] = "tc_fake_human_boss_cannon_explosive_3",
    [177] = "tc_fake_human_boss_sniper_3",
    [178] = "tc_fake_human_boss_electric_3",
    [179] = "tc_fake_human_boss_rocket_3",
    [180] = "tc_fake_human_boss_machine_gunner_3",
    [181] = "maf-giant-acid-spitter1",
    [182] = "biterzilla11",
    [183] = "maf-giant-fire-spitter1",
    [184] = "bm-motherbiterzilla1",
    [185] = "biterzilla31",
    [186] = "maf-boss-acid-spitter-3",
    [187] = "tc_fake_human_boss_erocket_4",
    [188] = "tc_fake_human_boss_grenade_4",
    [189] = "tc_fake_human_boss_nuke_rocket_4",
    [190] = "tc_fake_human_boss_cluster_grenade_4",
    [191] = "tc_fake_human_boss_cannon_explosive_4",
    [192] = "tc_fake_human_boss_machine_gunner_4",
    [193] = "tc_fake_human_boss_laser_4",
    [194] = "tc_fake_human_boss_pistol_gunner_4",
    [195] = "tc_fake_human_boss_sniper_4",
    [196] = "tc_fake_human_boss_electric_4",
    [197] = "tc_fake_human_boss_rocket_4",
    [198] = "maf-boss-biter-3",
    [199] = "tc_fake_human_boss_electric_5",
    [200] = "tc_fake_human_boss_cannon_explosive_5",
    [201] = "tc_fake_human_boss_rocket_5",
    [202] = "tc_fake_human_boss_erocket_5",
    [203] = "tc_fake_human_boss_grenade_5",
    [204] = "tc_fake_human_boss_laser_5",
    [205] = "tc_fake_human_boss_cluster_grenade_5",
    [206] = "tc_fake_human_boss_pistol_gunner_5",
    [207] = "tc_fake_human_boss_machine_gunner_5",
    [208] = "tc_fake_human_boss_sniper_5",
    [209] = "tc_fake_human_boss_nuke_rocket_5",
    [210] = "biterzilla22",
    [211] = "tc_fake_human_boss_electric_6",
    [212] = "tc_fake_human_boss_machine_gunner_6",
    [213] = "tc_fake_human_boss_cannon_explosive_6",
    [214] = "tc_fake_human_boss_cluster_grenade_6",
    [215] = "tc_fake_human_boss_rocket_6",
    [216] = "tc_fake_human_boss_laser_6",
    [217] = "tc_fake_human_boss_erocket_6",
    [218] = "tc_fake_human_boss_sniper_6",
    [219] = "tc_fake_human_boss_grenade_6",
    [220] = "tc_fake_human_boss_nuke_rocket_6",
    [221] = "tc_fake_human_boss_pistol_gunner_6",
    [222] = "maf-boss-acid-spitter-4",
    [223] = "tc_fake_human_boss_cluster_grenade_7",
    [224] = "tc_fake_human_boss_cannon_explosive_7",
    [225] = "tc_fake_human_boss_laser_7",
    [226] = "tc_fake_human_boss_rocket_7",
    [227] = "tc_fake_human_boss_electric_7",
    [228] = "tc_fake_human_boss_pistol_gunner_7",
    [229] = "tc_fake_human_boss_sniper_7",
    [230] = "tc_fake_human_boss_machine_gunner_7",
    [231] = "tc_fake_human_boss_nuke_rocket_7",
    [232] = "tc_fake_human_boss_erocket_7",
    [233] = "tc_fake_human_boss_grenade_7",
    [234] = "biterzilla32",
    [235] = "maf-giant-fire-spitter2",
    [236] = "bm-motherbiterzilla2",
    [237] = "maf-giant-acid-spitter2",
    [238] = "biterzilla12",
    [239] = "maf-boss-biter-4",
    [240] = "tc_fake_human_boss_cannon_explosive_8",
    [241] = "tc_fake_human_boss_rocket_8",
    [242] = "tc_fake_human_boss_sniper_8",
    [243] = "tc_fake_human_boss_erocket_8",
    [244] = "tc_fake_human_boss_pistol_gunner_8",
    [245] = "tc_fake_human_boss_laser_8",
    [246] = "tc_fake_human_boss_grenade_8",
    [247] = "tc_fake_human_boss_electric_8",
    [248] = "tc_fake_human_boss_machine_gunner_8",
    [249] = "tc_fake_human_boss_cluster_grenade_8",
    [250] = "tc_fake_human_boss_nuke_rocket_8",
    [251] = "tc_fake_human_boss_nuke_rocket_9",
    [252] = "tc_fake_human_boss_machine_gunner_9",
    [253] = "tc_fake_human_boss_sniper_9",
    [254] = "tc_fake_human_boss_cannon_explosive_9",
    [255] = "tc_fake_human_boss_laser_9",
    [256] = "tc_fake_human_boss_pistol_gunner_9",
    [257] = "tc_fake_human_boss_rocket_9",
    [258] = "tc_fake_human_boss_grenade_9",
    [259] = "tc_fake_human_boss_erocket_9",
    [260] = "tc_fake_human_boss_electric_9",
    [261] = "tc_fake_human_boss_cluster_grenade_9",
    [262] = "tc_fake_human_boss_electric_10",
    [263] = "tc_fake_human_boss_rocket_10",
    [264] = "tc_fake_human_boss_erocket_10",
    [265] = "tc_fake_human_boss_sniper_10",
    [266] = "tc_fake_human_boss_nuke_rocket_10",
    [267] = "tc_fake_human_boss_cluster_grenade_10",
    [268] = "tc_fake_human_boss_machine_gunner_10",
    [269] = "tc_fake_human_boss_laser_10",
    [270] = "tc_fake_human_boss_pistol_gunner_10",
    [271] = "tc_fake_human_boss_cannon_explosive_10",
    [272] = "tc_fake_human_boss_grenade_10",
    [273] = "biterzilla23",
    [274] = "maf-boss-acid-spitter-5",
    [275] = "maf-boss-biter-5",
    [276] = "biterzilla33",
    [277] = "maf-boss-acid-spitter-6",
    [278] = "maf-giant-acid-spitter3",
    [279] = "maf-giant-fire-spitter3",
    [280] = "biterzilla13",
    [281] = "bm-motherbiterzilla3",
    [282] = "maf-boss-biter-6",
    [283] = "biterzilla24",
    [284] = "tc_fake_human_ultimate_boss_cannon_20",
    [285] = "maf-boss-acid-spitter-7",
    [286] = "maf-boss-biter-7",
    [287] = "biterzilla34",
    [288] = "maf-boss-acid-spitter-8",
    [289] = "biterzilla25",
    [290] = "maf-giant-acid-spitter4",
    [291] = "bm-motherbiterzilla4",
    [292] = "biterzilla14",
    [293] = "maf-giant-fire-spitter4",
    [294] = "maf-boss-biter-8",
    [295] = "maf-boss-acid-spitter-9",
    [296] = "biterzilla35",
    [297] = "maf-boss-biter-9",
    [298] = "maf-boss-acid-spitter-10",
    [299] = "biterzilla15",
    [300] = "bm-motherbiterzilla5",
    [301] = "maf-giant-fire-spitter5",
    [302] = "maf-giant-acid-spitter5",
    [303] = "maf-boss-biter-10",
}

-- 21
local starIndex = {1,5 ,10,24,37,51,64,77, 90,103,116,116,129,129,145,145,156,156,170,170,187,187,199,199,211,211,223,223,240,251}
local endIndex =  {5,10,24,37,51,64,77,90,103,116,129,129,145,145,156,156,170,170,187,187,199,199,211,211,223,223,240,240,251,304}

-- N = 1- 60
function GetBiterName(N)
    if N > 60 then N = 60 end
    if N < 1 then N = 1 end

    local name = "small-biter"
    for i = 1, 3 do
        local index = math_floor((N + 1) / 2)
        index = math_random(starIndex[index],endIndex[index]-1)
        name = all_enemies[index]
        if name == "tc_fake_human_ultimate_boss_cannon_20" or string.sub(name, 1, 2) ~= "tc" or math_random(1,100) <= 10 then
            if string.find(name, "nuke_rocket") then
                if math_random(1,100) <= 20  then
                    return name
                end
            else
                return name
            end
        end
    end
    return name
end

local function spawn_biter(surface, is_boss_biter, spawn_position , is_big)
    if not is_boss_biter then
        if not can_units_spawn() then
            return
        end
    end


    local wave_number = WD.get("wave_number");
    local N = math_floor(wave_number/ 50) + 1
    if is_big then
        N = N + 8
    end
    local name = GetBiterName(N)

    local position = {x = spawn_position.x + math.random(-4,4), y = spawn_position.y + math.random(-4,4)}

    -- print("生成虫子::"..name)
    local biter = surface.create_entity({name = name, position = position, force = 'enemy'})
    biter.ai_settings.allow_destroy_when_commands_fail = true
    biter.ai_settings.allow_try_return_to_spawner = true
    biter.ai_settings.do_separation = true

    local increase_health_per_wave = WD.get('increase_health_per_wave')

    if increase_health_per_wave and not is_boss_biter then
        local modified_unit_health = WD.get('modified_unit_health')
        BiterHealthBooster.add_unit(biter, modified_unit_health.current_value)
    end
    if is_boss_biter then
        BiterHealthBooster.add_boss_unit(biter, 0.1*N+2, 0.55)
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

local spawn_list = nil
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

    -- local unit_group_pos = WD.get('unit_group_pos')

    if WN < 4 then
        game.print('虫子出现了！[gps=' .. position.x .. ',' .. position.y .. ',' .. surface.name .. ']')
    end
    
    -- 每100波加入大怪兽
    local N = math.floor((WN+1) / 100) 
    -- N = 60

    
    local info = {}
    local unit_group = surface.create_unit_group({position = {0,0}, force = 'enemy'})
    info.group = unit_group
    info.biter_count = 8;
    info.boss_count = 4;
    info.big_count = 0;
    info.spawn_position = spawn_position
    info.surface = surface
    
    if spawn_list then
        info.biter_count = spawn_list.biter_count + 8
        info.boss_count = spawn_list.boss_count + 4
        info.big_count = spawn_list.big_count
    end

    if WD.get("BigWave") < N and WN > 40 then
        WD.set("BigWave", WD.get("BigWave") + 1)
        local M = 1
        if N > 25 then
            M = N - 24
        end

        game.forces.enemy.set_ammo_damage_modifier("rocket",N*N*0.05)
        game.forces.enemy.set_ammo_damage_modifier("grenade",N*N*0.05)
        game.forces.enemy.set_ammo_damage_modifier("landmine",N*N*0.05)
        game.forces.enemy.set_ammo_damage_modifier("bullet",N*N*0.05)
        game.forces.enemy.set_ammo_damage_modifier("cannon-shell",N*N*0.05)
        game.forces.enemy.set_ammo_damage_modifier("laser",N*N*0.05)
        game.forces.enemy.set_ammo_damage_modifier("electric",N*N*0.05)
        game.forces.enemy.set_ammo_damage_modifier("beam",N*N*0.05)



        game.print('第'..N..'波大怪兽来袭！炮塔伤害+1%')

        global.RPG_POINT.total = global.RPG_POINT.total + 1

        raw_print('第'..N..'波大怪兽来袭！' )
        if N > 50 then
            game.print('挑战开始！大怪兽倍速'..M)
        end
        
        info.big_count = info.big_count + M * 4
    end
    spawn_list = info
end

local function set_next_wave()
    if global.StarWave and global.StarWave < 0 then
        game_over()
        return
    end
    -- get_new_arty()
    local wave_number = WD.get('wave_number')
    if wave_number ==  1000 then
        game.print("还有2000波结束，加油！",{r = 1, g = 0, b = 0})
    elseif wave_number == 2000 then
        game.print("还有1000波结束，加油！",{r = 1, g = 0, b = 0})
    elseif wave_number == 2500 then
        game.print("还有500波结束，坚持住！",{r = 1, g = 0, b = 0})
    end
    WD.set('wave_number', wave_number + 1)
    spawn_unit_group()
    wave_number = WD.get('wave_number')

    -- local threat_gain_multiplier = WD.get('threat_gain_multiplier')
    -- local threat_gain = wave_number * threat_gain_multiplier
    -- if wave_number > 1000 then
    --     threat_gain = threat_gain * (wave_number * 0.001)^2
    -- end
    -- 设置威胁值
    local StarWave = 0;
    if global.StarWave then StarWave = global.StarWave end
    local threat_gain = 2*wave_number^2*((3 + StarWave/2)/3)^2
    local map=diff.get()
    local boss_interval = 50
    if wave_number>=1000 then boss_interval = 25 end
    if wave_number>=2000 and map.final_wave then boss_interval = 10 end
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
        -- WD.set('next_wave', game.tick + 60*30)-- 30s一波

        -- local surface_index = WD.get('surface_index')
        -- local surface = game.surfaces[surface_index]
        -- surface.clear_pollution()
        -- 生成污染
        -- local pos = {x = 0, y = 0}
        -- surface.pollute(pos, wave_number)

        local time = 120
        if wave_number == 2999 then
            time = 120 * 60
        end

        -- 多人在线修正
        local player_count = #game.connected_players
        if not player_count then player_count = 1 end

        time = time * 100 / (100 + player_count * 5)

        WD.set('next_wave', game.tick + time)
        if wave_number % 10 == 0 then
            raw_print("当前波次:"..wave_number.."/"..(3000).."在线人数:"..player_count.."下一波时间:"..(time/60))
        end


    if wave_number >= 3000 then
        game.print("*****************恭喜！挑战成功！*****************",{r = 1, g = 0, b = 0})
        game.print("*****************10s后开始下一局*****************",{r = 1, g = 0, b = 0})
        global.StarWave = -global.StarWave - 1       -- 难度+1
        WD.set('next_wave', game.tick + 60*10)-- 10s
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
    -- local unit_groups = WD.get('unit_groups')
    -- local unit_group_pos = WD.get('unit_group_pos')
    -- local target = WD.get('target')
    -- if not valid(target) then
    --     return
    -- end

    -- for k, group in pairs(unit_groups) do
    --     if group.valid then
    --         local ugp = unit_group_pos.positions
    --         if group.state == defines.group_state.finished then
    --             return command_to_main_target(group, true)
    --         end
    --         if ugp[group.group_number] then
    --             local success = is_position_near(group.position, ugp[group.group_number].position)
    --             if success then
    --                 ugp[group.group_number].index = ugp[group.group_number].index + 1
    --                 if ugp[group.group_number].index >= 2 then
    --                     command_to_main_target(group, true)
    --                     fill_tiles(group, 50)
    --                     remove_rocks(group)
    --                     remove_trees(group)
    --                     if ugp[group.group_number].index >= 4 then
    --                         unit_group_pos.positions[group.group_number] = nil
    --                         reform_group(group)
    --                     end
    --                 end
    --             end
    --         end
    --     end
    -- end
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
    -- [150] = ThreatEvent.build_nest,
    -- [180] = ThreatEvent.build_worm,
    -- [1200] = give_side_commands_to_group,
    -- [3600] = time_out_biters,
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


local function one_tick()
    if spawn_list == nil then
        return
    end
    
    local info = spawn_list
    if not info.surface.valid then
        spawn_list = nil
    elseif info.biter_count > 0 then
        local biter = spawn_biter(info.surface, false, info.spawn_position, false)
        if biter then
            if info.group.valid then
                info.group.add_member(biter)
            end
            info.biter_count = info.biter_count - 1
        end
    elseif info.boss_count > 0 then
        local biter = spawn_biter(info.surface, true, info.spawn_position, false)
        if biter then
            if info.group.valid then
                info.group.add_member(biter)
            end
            info.boss_count = info.boss_count - 1
            if info.boss_count == 0 then
                WD.set('boss_wave', false)
            end
        end
    elseif info.big_count > 0 then
        local biter = spawn_biter(info.surface, true, info.spawn_position, true)
        if biter then
            if info.group.valid then
                info.group.add_member(biter)
            end
            info.big_count = info.big_count - 1
        end
    else
        -- local unit_group = info.group
        -- local unit_groups = WD.get('unit_groups')
        -- unit_groups[unit_group.group_number] = unit_group
        -- if math_random(1, 2) == 1 then
        --     WD.set('random_group', unit_group.group_number)
        -- end
        -- WD.set('spot', 'nil')

        spawn_list = nil
    end

end

Event.on_nth_tick(2, one_tick)

return Public
