local WD = require 'modules.wave_defense.table'
local threat_values = require 'modules.wave_defense.threat_values'
local Event = require 'utils.event'
local BiterRolls = require 'modules.wave_defense.biter_rolls'
local BiterHealthBooster = require 'modules.biter_health_booster_v2'
local math_random = math.random
local WPT = require 'maps.amap.table'
local Token = require 'utils.token'
local Task = require 'utils.task'

local Public = {}

local function remove_unit(entity)
  local active_biters = WD.get('active_biters')
  local unit_number = entity.unit_number
  if not active_biters[unit_number] then
    return
  end
  local m = 1
  local biter_health_boost_units = BiterHealthBooster.get('biter_health_boost_units')
  if biter_health_boost_units[unit_number] then
    m = 1 / biter_health_boost_units[unit_number][2]
  end
  local active_threat_loss = math.round(threat_values[entity.name] * m, 2)
  local active_biter_threat = WD.get('active_biter_threat')
  WD.set('active_biter_threat', active_biter_threat - active_threat_loss)
  local active_biter_count = WD.get('active_biter_count')
  WD.set('active_biter_count', active_biter_count - 1)
  active_biters[unit_number] = nil

  if active_biter_count <= 0 then
    WD.set('active_biter_count', 0)
  end
  if active_biter_threat <= 0 then
    WD.set('active_biter_threat', 0)
  end
end

local function place_nest_near_unit_group()
  local unit_groups = WD.get('unit_groups')
  local random_group = WD.get('random_group')
  local group = unit_groups[random_group]
  if not group then
    return
  end
  if not group.valid then
    return
  end
  if not group.members then
    return
  end
  if not group.members[1] then
    return
  end
  local unit = group.members[math_random(1, #group.members)]
  if not unit.valid then
    return
  end
  local name = 'biter-spawner'
  if math_random(1, 3) == 1 then
    name = 'spitter-spawner'
  end
  local position = unit.surface.find_non_colliding_position(name, unit.position, 12, 1)
  if not position then
    return
  end
  local r = WD.get('nest_building_density')
  if
  unit.surface.count_entities_filtered(
  {
    type = 'unit-spawner',
    force = unit.force,
    area = {{position.x - r, position.y - r}, {position.x + r, position.y + r}}
  }
) > 0
then
  return
end
local spawner = unit.surface.create_entity({name = name, position = position, force = unit.force})
local nests = WD.get('nests')
nests[#nests + 1] = spawner
unit.surface.create_entity({name = 'blood-explosion-huge', position = position})
unit.surface.create_entity({name = 'blood-explosion-huge', position = unit.position})
remove_unit(unit)
unit.destroy()
local threat = WD.get('threat')
-- WD.set('threat', threat - threat_values[name])
return true
end

function Public.build_nest()
  local threat = WD.get('threat')
  if threat < 1024 then
    return
  end
  local index = WD.get('index')
  if index == 0 then
    return
  end
  for _ = 1, 2, 1 do
    if place_nest_near_unit_group() then
      return
    end
  end
end

function Public.build_worm()
  local threat = WD.get('threat')
  if threat < 512 then
    return
  end
  local worm_building_chance = WD.get('worm_building_chance')
  if math_random(1, worm_building_chance) ~= 1 then
    return
  end

  local index = WD.get('index')
  if index == 0 then
    return
  end

  local random_group = WD.get('random_group')
  local unit_groups = WD.get('unit_groups')
  local group = unit_groups[random_group]
  if not group then
    return
  end
  if not group.valid then
    return
  end
  if not group.members then
    return
  end
  if not group.members[1] then
    return
  end
  local unit = group.members[math_random(1, #group.members)]
  if not unit.valid then
    return
  end

  local wave_number = WD.get('wave_number')

  local k =game.forces.enemy.evolution_factor*1000
  if k >wave_number then
    wave_number=k
  end
  local position = unit.surface.find_non_colliding_position('assembling-machine-1', unit.position, 8, 1)
  BiterRolls.wave_defense_set_worm_raffle(wave_number)
  local worm = BiterRolls.wave_defense_roll_worm_name()
  if not position then
    return
  end

  local worm_building_density = WD.get('worm_building_density')
  local r = worm_building_density
  if
  unit.surface.count_entities_filtered(
  {
    type = 'turret',
    force = unit.force,
    area = {{position.x - r, position.y - r}, {position.x + r, position.y + r}}
  }
) > 0
then
  return
end
unit.surface.create_entity({name = worm, position = position, force = unit.force})
unit.surface.create_entity({name = 'blood-explosion-huge', position = position})
unit.surface.create_entity({name = 'blood-explosion-huge', position = unit.position})
remove_unit(unit)
unit.destroy()
-- WD.set('threat', threat - threat_values[worm])
end

local function shred_simple_entities(entity)
  local threat = WD.get('threat')
  if threat < 25000 then
    return
  end
  local simple_entities =
  entity.surface.find_entities_filtered(
  {
    type = 'simple-entity',
    area = {{entity.position.x - 3, entity.position.y - 3}, {entity.position.x + 3, entity.position.y + 3}}
  }
  )
  if #simple_entities == 0 then
    return
  end
  if #simple_entities > 1 then
    table.shuffle_table(simple_entities)
  end
  local r = math.floor(threat * 0.00004)
  if r < 1 then
    r = 1
  end
  local count = math.random(1, r)
  --local count = 1
  local damage_dealt = 0
  for i = 1, count, 1 do
    if not simple_entities[i] then
      break
    end
    if simple_entities[i].valid then
      if simple_entities[i].health then
        damage_dealt = damage_dealt + simple_entities[i].health
        simple_entities[i].die('neutral', simple_entities[i])
      end
    end
  end
  if damage_dealt == 0 then
    return
  end
  local simple_entity_shredding_cost_modifier = WD.get('simple_entity_shredding_cost_modifier')
  local threat_cost = math.floor(damage_dealt * simple_entity_shredding_cost_modifier)
  if threat_cost < 1 then
    threat_cost = 1
  end
  -- WD.set('threat', threat - threat_cost)
  end

  local function spawn_unit_spawner_inhabitants(entity)
  if entity.type ~= 'unit-spawner' then
    return
  end

  local wave_number = WD.get('wave_number')
  local k =game.forces.enemy.evolution_factor*1600
  if k > wave_number then
    wave_number=k
  end
  local count = 4 + math.floor(wave_number / 400)
  if count > 12 then
    count = 12
  end
  -- game.print("触发虫巢死亡:"..count.."只")

  BiterRolls.wave_defense_set_unit_raffle(wave_number)
  local unit_group = entity.surface.create_unit_group({position = {0,0}, force = 'enemy'})
  for _ = 1, count, 1 do
    local position = {entity.position.x + (-4 + math.random(0, 8)), entity.position.y + (-4 + math.random(0, 8))}
    local biter = nil
    if math.random(1, 4) == 1 then
      biter=entity.surface.create_entity({name = BiterRolls.wave_defense_roll_spitter_name(), position = position, force = 'enemy'})
    else
      biter=  entity.surface.create_entity({name = BiterRolls.wave_defense_roll_biter_name(), position = position, force = 'enemy'})
    end
    if biter then
      unit_group.add_member(biter)
    end
  end


  wave_number = WD.get('wave_number')
  k =game.forces.enemy.evolution_factor^4*1600
  if k > wave_number then
    wave_number=k
  end


  local produceBig = 0.1 + 0.8 * (wave_number / 3000)

  if math.random() > produceBig then return end


  local N = math.floor(wave_number / 50) 
  if N < 1 then N = 1 end

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
      if entity and entity.valid then
        local p = entity.surface.find_non_colliding_position(name, entity.position, 6, 1)
        if p then
            entity.surface.create_entity {name = name, position = p, force = entity.force.name}
        end
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
          rd = math_random(1, 12)
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

end

local function kill_master(entity)
  if entity.type ~= 'unit-spawner' then
    return
  end
  local wave_number = WD.get('wave_number')
  local k =game.forces.enemy.evolution_factor*1000
  if k >wave_number then
    wave_number=k
  end
  local count = 32 + math.floor(wave_number * 0.1)
  if count > 64 then
    count = 64
  end
  BiterRolls.wave_defense_set_unit_raffle(wave_number)

  local unit_group = entity.surface.create_unit_group({position = entity.position, force = 'enemy'})
  for _ = 1, count, 1 do
    local position = {entity.position.x + (-4 + math.random(0, 8)), entity.position.y + (-4 + math.random(0, 8))}
    local biter
    if math.random(1, 4) == 1 then
      biter=entity.surface.create_entity({name = BiterRolls.wave_defense_roll_spitter_name(), position = position, force = 'enemy'})
    else
      biter=entity.surface.create_entity({name = BiterRolls.wave_defense_roll_biter_name(), position = position, force = 'enemy'})
    end
    if biter then
      biter.ai_settings.allow_destroy_when_commands_fail = true
      biter.ai_settings.allow_try_return_to_spawner = true
      --biter.ai_settings.do_separation = true
      unit_group.add_member(biter)

    end
  end

  if #unit_group.members == 0 then return end
  local target
  local entities = entity.surface.find_entities_filtered{position = entity.position, radius =25, name = "character", force = game.forces.player}

  if #entities == 0 then
    local this=WPT.get()
    if this.tank[this.car_index] then
      target=this.tank[this.car_index]
      --game.print("攻击主车")
    else
      local characters = {}
      local p = game.connected_players
      for _, player in pairs(p) do
        if player.character then
          if player.character.valid then
            if player.character.surface== entity.surface then
              characters[#characters + 1] = player.character
            end
          end
        end
      end
      if #characters ~=0 then
        target=math_random(1, #characters)
        --  game.print("随机全体玩家")
      else
        for k,v in pairs(unit_group.members) do
          v.destroy()
        end
        unit_group.destroy()
        --game.print("摧毁组织")
        return
      end
    end
  else
    target=entities[math.random(#entities)]
  end

  unit_group.set_command(
  {
    type = defines.command.attack_area,
    destination = target.position,
    radius = 8,
    distraction = defines.distraction.by_anything
  }
)

end



local getSpawner = Token.register(
  function(data)
    data.surface.create_entity({name = data.name, position = data.position, force = 'enemy'})
  end
)

local function on_entity_died(event)
  local entity = event.entity

  if not entity.valid then
    return
  end

  -- 边缘虫巢无限重生
  if entity.type == 'unit-spawner' then
    local width = global.MapWidth / 2 - 127
    if entity.position.x > width or entity.position.x < -width then
      local data = {}
      data.surface = entity.surface
      data.name = entity.name
      data.position = entity.position
      Task.set_timeout_in_ticks(120, getSpawner, data)
    end
  end

  local disable_threat_below_zero = WD.get('disable_threat_below_zero')
  local biter_health_boost = BiterHealthBooster.get('biter_health_boost')

  if entity.type == 'unit' then
    -- 大虫子死亡减少威胁值

    if global.BigDieThreat == nil then global.BigDieThreat = 10000 end

    if entity.prototype.max_health > global.BigDieThreat then
      local threat = WD.get('threat')
      -- WD.set('threat', math.round(threat - entity.prototype.max_health / global.BigDieThreat, 2))
    end


    --acid_nova(entity)
    if not threat_values[entity.name] then
      return
    end

    

    
    if disable_threat_below_zero then
      local threat = WD.get('threat')
      if threat <= 0 then
        WD.set('threat', 0)
        remove_unit(entity)
        return
      end
      -- WD.set('threat', math.round(threat - threat_values[entity.name] * biter_health_boost, 2))
      remove_unit(entity)
    else
      local threat = WD.get('threat')
      -- WD.set('threat', math.round(threat - threat_values[entity.name] * biter_health_boost, 2))
      remove_unit(entity)
    end
  else
    if entity.force.index == 2 then
      if entity.health then
        if threat_values[entity.name] then
          local threat = WD.get('threat')
          -- WD.set('threat', math.round(threat - threat_values[entity.name] * biter_health_boost, 2))
        end
        local cause = event.cause
        if not cause then
          kill_master(entity)
        else
          if cause.last_user then
            local this=WPT.get()
            local  player = cause.last_user
            local index =player.index
            if not this.nest_wegiht[index] then
              this.nest_wegiht[index]=0
            end
            this.nest_wegiht[index]=this.nest_wegiht[index]+1
          end
          if cause.name =="artillery-turret" or cause.name =="artillery-wagon"  then
            local this=WPT.get()
            local unit_number=cause.unit_number
            if not this.water_arty[unit_number] then
              local water_count =entity.surface.count_tiles_filtered{position=cause.position, radius=30, name='water'}
              --game.print(water_count)
              if water_count == 0 then
                this.water_arty[unit_number]=1
              else
                this.water_arty[unit_number]=2
              end
            end

            if this.water_arty[unit_number]==2 then

              kill_master(entity)
            else
              spawn_unit_spawner_inhabitants(entity)

            end
          end


          if cause.name ~="artillery-turret" and cause.name ~="artillery-wagon" then
        if cause.destructible==false then
          kill_master(entity)
        else
            spawn_unit_spawner_inhabitants(entity)
          end
            if cause.valid then
              local this=WPT.get()
              if (cause.name == 'character' and cause.player) then
                local  player = cause.player
                local index =player.index
                if not this.nest_wegiht[index] then
                  this.nest_wegiht[index]=0
                end
                this.nest_wegiht[index]=this.nest_wegiht[index]+1
              end
            end
          end

        end
      end
    end
  end

  if entity.force.index == 3 then
    if event.cause then
      if event.cause.valid then
        if event.cause.force.index == 2 then
          shred_simple_entities(entity)
        end
      end
    end
  end
end

Event.add(defines.events.on_entity_died, on_entity_died)

return Public
