local Public = require 'modules.rpg.table'
local Task = require 'utils.task'
local Gui = require 'utils.gui'
local Color = require 'utils.color_presets'
local Token = require 'utils.token'
local Alert = require 'utils.alert'
local WPT = require 'maps.amap.table'
local Event = require 'utils.event'


local Print = require('utils.print_override')
local raw_print = Print.raw_print

local level_up_floating_text_color = {0, 205, 0}
local visuals_delay = Public.visuals_delay
local xp_floating_text_color = Public.xp_floating_text_color
local experience_levels = Public.experience_levels
local points_per_level = Public.points_per_level
local settings_level = Public.gui_settings_levels
local floor = math.floor
local random = math.random
local round = math.round
local abs = math.abs
local math_random = math.random

--RPG Frames
local main_frame_name = Public.main_frame_name
local spell_gui_frame_name = Public.spell_gui_frame_name

local PI = 3.1415926

local travelings = {
  'bzzZZrrt',
  'WEEEeeeeeee',
  'out of my way son',
  'on my way',
  'i need to leave',
  'comfylatron seeking target',
  'gotta go fast',
  'gas gas gas',
  'comfylatron coming through'
}

local player_loader = {
  'loader',
  'inserter'
}

local function removeElement(tbl, element)
  local newTbl = {}
  for i, v in ipairs(tbl) do
      if v.valid and element.valid and v.position.x ~= element.position.x and v.position.y ~= element.position.y then
          table.insert(newTbl, v)
      end
  end
  return newTbl
end

-- 获取距离目标最近的虫子
local get_nearest_biter = function(biters, target_pos)
  local nearest_biter = nil
  local nearest_distance = 100000000
  for _, biter in pairs(biters) do
    if biter.valid  then
      local distance = (biter.position.x - target_pos.x)^2 + (biter.position.y - target_pos.y)^2

      -- 优先攻击血量大于1w的虫子
      if biter.prototype.max_health < 10000 then distance = distance + 10000 end

      if distance < nearest_distance then
        nearest_distance = distance
        nearest_biter = biter
      end
    end
  end
  return nearest_biter
end

-- 最后一击
local last_hit = function(data)

  local biter = data.biter
  local num = data.times
  local damage = data.damage
  local player = data.player

  damage = damage * num -- 伤害
  if biter and biter.valid then
    -- data.player.print("最后一击伤害:"..damage)
  else
    return
  end
  

  if biter.force.name == "enemy" then
    -- if biter.valid then
    --   biter.damage(damage, 'player', 'physical', player.character)  -- 物理
    -- end
    player.surface.create_entity({name = "flying-text", position = biter.position, text = math.floor(damage).."!", color = {255, 0, 0}})
    
    if biter.valid then
      biter.damage(damage, 'player', 'laser', player.character) -- 激光
    end
    -- if biter.valid then
    --   biter.damage(damage, 'player', 'plasma', player.character)  -- 等离子
    -- end
    if biter.valid then
      biter.damage(damage, 'player', 'poison', player.character)  -- 毒素
    end
    if biter.valid then
      biter.damage(damage, 'player', 'acid', player.character) -- 酸蚀
    end
    if biter.valid then
      biter.damage(damage, 'player', 'electric', player.character) -- 电击
    end
    if biter.valid then
      biter.damage(damage, 'player', 'explosion', player.character) -- 爆炸
    end
    if biter.valid then
      biter.damage(damage, 'player', 'fire', player.character)  -- 火焰
    end
  end

  -- 致命一击
  local value = 0.0004 * num
  if value > 0.05 then value = 0.05 end
  if biter.valid and biter.force.name == "enemy" and math.random() < value then
    game.print(player.name.."秒杀了"..biter.name,{r=1,g=0,b=0})
    raw_print(player.name.."秒杀了"..biter.name)
    local d = 2
    for i = 1,50  do
      -- 创建位置是半径为32的圆上的均匀分布的点
      local source = player.character.position
      local pos = {source.x + d * math.cos(i * 2 * PI / 50), -4 + source.y + d * math.sin(i * 2 * PI / 50)}
        
      player.surface.create_entity(
      {
        name ='laser-beam',
        position = pos,
        force = 'player',
        source = pos,
        target = biter.position,
        player = player,
        duration = 90,
      })
    end
    biter.surface.create_entity({name = 'big-explosion', position = biter.position})
    biter.die()
  end
end


Public.last_hit = Token.register(last_hit)           -- 注册最后一击函数


local attackBiter = function(data)
  
end

local lightning_func = function(data)
  local player = data.player  -- 玩家
  local source = data.source  -- 闪电链起点
  local damage = data.damage  -- 闪电链伤害
  local target = data.target  -- 闪电链目标
  local biters = data.biters  -- 上次搜索到的虫子

  local target_pos = target
  if target.position then
    target_pos = target.position
  end

  -- 如果有伤害目标

  if target and target.valid then
    if target.force.name == "enemy" then
      -- if biter.valid then
      --   biter.damage(damage, 'player', 'physical', player.character)  -- 物理
      -- end
      
		  -- player.surface.create_entity({name = "flying-text", position = target.position, text = ""..math.floor(damage), color = {150, 150, 150}})

      if target.valid then
        target.damage(damage, 'player', 'laser', player.character) -- 激光
      end
      -- if biter.valid then
      --   biter.damage(damage, 'player', 'plasma', player.character)  -- 等离子
      -- end
      if target.valid then
        target.damage(damage, 'player', 'poison', player.character)  -- 毒素
      end
      if target.valid then
        target.damage(damage, 'player', 'acid', player.character) -- 酸蚀
      end
      if target.valid then
        target.damage(damage, 'player', 'electric', player.character) -- 电击
      end
      if target.valid then
        target.damage(damage, 'player', 'explosion', player.character) -- 爆炸
      end
      if target.valid then
        target.damage(damage, 'player', 'fire', player.character)  -- 火焰
      end
    end


    if data.first and target.valid then
      data.first = false
      local times = data.times  -- 闪电链次数

      local data2 = {
        biter = target,
        times = times,
        damage = damage,
        player = player
      }
      local t_pos = target.position
      local target2 = target.position
      last_hit(data2)

      if target and target.valid then target2 = target end

      local d = 8
      local rv = math.random(1, 2000) / 1000 * PI;
      local rv2 = math.random(1, 2000) / 1000 * PI;
      for i = 1,data.times  do
        -- 创建位置是半径为32的圆上的均匀分布的点
        local source = t_pos
        local pos = {source.x + d * math.cos(i * 2 * PI / times + rv), source.y + 0.33 * d * math.sin(i * 2 * PI / times + rv2) - 40}
          
        for i = 1,3 do
          player.surface.create_entity(
          {
            name ='electric-beam',
            position = pos,
            force = 'player',
            source = pos,
            target = target2,
            player = player,
            duration = 20,
          })
        end
      end
    end
  end


  -- 创建飞行物
  local source_pos = source
  if source.position then
    source_pos = source.position
  end
  local source2 = source
  if source.valid then
    source2 = source
  elseif source.position then
    source2 = source.position
  end

  local target2 = target_pos
  if target and target.valid then
    target2 = target
  end
  for i = 1,4 do
    player.surface.create_entity(
    {
      name ='electric-beam',
      position = source_pos,
      force = 'player',
      source = source2,
      target = target2,
      player = player,
      duration = 20,
    })
  end
 

  for _ = 1,2 do
    data.times = data.times - 1
    if data.times <= 0 then
      return
    end

    if #biters < 2 then
      biters = player.surface.find_entities_filtered{position = target_pos, radius = 64, type={'unit','unit-spawner', 'turret', 'wall' } , force = game.forces.enemy}
    end

    biters = removeElement(biters, target) 
    
    if #biters < 1 then
      biters = player.surface.find_entities_filtered{position = target_pos, radius = 64, type={'unit','unit-spawner', 'turret', 'wall' } , force = game.forces.enemy}
    end


    data.target = get_nearest_biter(biters, target_pos)
    if data.target == nil then
      return
    end
    data.biters = biters
    if target and target.valid then
      data.source = target
    else 
      data.source = target_pos
    end

    Task.set_timeout_in_ticks(10, Public.lightning, data) -- 10帧后执行
  end
end

Public.lightning = Token.register(lightning_func)   -- 注册闪电链函数


-- 闪电链函数
function Public.lightning_chain(position, surface,player,times)

  local biters = surface.find_entities_filtered{position = position, radius = 128, type={'unit','unit-spawner', 'turret', 'wall' } , force = game.forces.enemy}
  if #biters == 0 then
    biters= surface.find_entities_filtered{position = position, radius = 128, type={'unit','unit-spawner', 'turret', 'wall' } , force = game.forces.neutral}
  end

  -- 没有虫子,直接返回
  if #biters == 0 then
    return false
  end

  
  global.lightning_current[player.name] = times
  -- 上局加成
  local lastNum = 0
  if global.lightning_last[player.name] then
    lastNum = global.lightning_last[player.name]
  end

  local t2 = times - 10
  -- if times > 50 then
  --   t2 = (times - 50) * 2 + 41
  --   times = 50
  -- end
  -- times = 100
  local laser = game.forces.player.get_ammo_damage_modifier("laser") -- 激光伤害加成
  laser = math.floor(laser * 10) * 0.1
  local damage = (1 + lastNum*0.01) * (1 + t2) * (1+laser)*100     -- 闪电链伤害
  player.print("次数:"..times.." 伤害:"..(1+lastNum*0.01).."(永久加加成)x"..(1+t2).."(本局加成)x"..(1+laser).."(激光伤害科技)x100")


  -- local d = 8
  -- for i = 1,times  do
  --   -- 创建位置是半径为32的圆上的均匀分布的点
  --   local source = position
  --   local pos = {source.x + d * math.cos(i * 2 * PI / times), source.y + d * math.sin(i * 2 * PI / times)}
      
  --   player.surface.create_entity(
  --   {
  --     name ='electric-beam',
  --     position = pos,
  --     force = 'player',
  --     source = pos,
  --     target = source,
  --     player = player,
  --     duration = 30,
  --   })
  -- end


  local biter = get_nearest_biter(biters, position)
  local data = {
    source = position,
    damage = damage,
    target = biter,
    times = times,
    player = player,
    first = true,
    biters = {},
  }

  
  Task.set_timeout_in_ticks(0, Public.lightning, data) -- 一帧后执行
  return true
end


local kill_turret =
Token.register(
function(data)
  local entity = data.entity
  if not entity or not entity.valid then
    return
  end
  entity.destroy()

end
)

function Public.wudi_turret(position, surface,ammo_name,player)


 if not surface.can_place_entity{name = "gun-turret", position = {x=position.x,y=position.y}, force=game.forces.player} then return false end
  local turret = surface.create_entity{
    name = 'gun-turret',
    position = {x=position.x,y=position.y},
    force=game.forces.player,
  }

  if not turret then
    return false
  else
    turret.insert{name=ammo_name, count = 25}
    turret.destructible=false
    turret.minable=false
    turret.operable=false
    turret.last_user=player
  end

  local this=WPT.get()
  this.turret_rpg[#this.turret_rpg+1]=turret

  local data = {
    entity = turret,
  }
  Task.set_timeout_in_ticks(720, kill_turret, data)
  return true
end


local desync =
Token.register(
function(data)
  local entity = data.entity
  if not entity or not entity.valid then
    return
  end
  local surface = data.surface
  local fake_shooter = surface.create_entity({name = 'character', position = entity.position, force = 'enemy'})
  for i = 1, 3 do
    surface.create_entity(
    {
      name = 'explosive-rocket',
      position = entity.position,
      force = 'player',
      speed = 1,
      max_range = 1,
      target = entity,
      source = fake_shooter
    }
  )
end
if fake_shooter and fake_shooter.valid then
  fake_shooter.destroy()
end
end
)

local function create_healthbar(player, size)
  return rendering.draw_sprite(
  {
    sprite = 'virtual-signal/signal-white',
    tint = Color.green,
    x_scale = size * 8,
    y_scale = size - 0.2,
    render_layer = 'light-effect',
    target = player.character,
    target_offset = {0, -2.5},
    surface = player.surface
  }
)
end

local function create_manabar(player, size)
  return rendering.draw_sprite(
  {
    sprite = 'virtual-signal/signal-white',
    tint = Color.blue,
    x_scale = size * 8,
    y_scale = size - 0.2,
    render_layer = 'light-effect',
    target = player.character,
    target_offset = {0, -2.0},
    surface = player.surface
  }
)
end

local function set_bar(min, max, id, mana)
  local m = min / max
  if not rendering.is_valid(id) then
    return
  end
  local x_scale = rendering.get_y_scale(id) * 8
  rendering.set_x_scale(id, x_scale * m)
  if not mana then
    rendering.set_color(id, {math.floor(255 - 255 * m), math.floor(200 * m), 0})
  end
end

local function level_up(player)
  local rpg_t = Public.get_value_from_player(player.index)
  local names = Public.auto_allocate_nodes_func

  local distribute_points_gain = 0
  for i = rpg_t.level + 1, #experience_levels, 1 do
    if rpg_t.xp > experience_levels[i] then
      rpg_t.level = i
      distribute_points_gain = distribute_points_gain + points_per_level
    else
      break
    end
  end
  if distribute_points_gain == 0 then
    return
  end

  -- automatically enable one_punch and stone_path,
  -- but do so only once.
  if rpg_t.level >= settings_level['one_punch_label'] then
    if not rpg_t.auto_toggle_features.one_punch then
      rpg_t.auto_toggle_features.one_punch = true
      rpg_t.one_punch = true
    end
  end
  if rpg_t.level >= settings_level['stone_path_label'] then
    if not rpg_t.auto_toggle_features.stone_path then
      rpg_t.auto_toggle_features.stone_path = true
      rpg_t.stone_path = true
    end
  end

  Public.draw_level_text(player)
  rpg_t.points_left = rpg_t.points_left + distribute_points_gain
  if rpg_t.allocate_index ~= 1 then
    local node = rpg_t.allocate_index
    local index = names[node]:lower()
    rpg_t[index] = rpg_t[index] + distribute_points_gain
    rpg_t.points_left = rpg_t.points_left - distribute_points_gain
    if not rpg_t.reset then
      rpg_t.total = rpg_t.total + distribute_points_gain
    end
    Public.update_player_stats(player)
  else
    Public.update_char_button(player)
  end
  if player.gui.screen[main_frame_name] then
    Public.toggle(player, true)
  end

  Public.level_up_effects(player)
end

local function add_to_global_pool(amount, personal_tax)
  local rpg_extra = Public.get('rpg_extra')

  if not rpg_extra.global_pool then
    return
  end
  local fee
  if personal_tax then
    fee = amount * rpg_extra.personal_tax_rate
  else
    fee = amount * 0.3
  end

  rpg_extra.global_pool = round(rpg_extra.global_pool + fee, 8)
  return amount - fee
end

local repair_buildings =
Token.register(
function(data)
  local entity = data.entity
  if entity and entity.valid then
    local rng = 0.1
    if math.random(1, 5) == 1 then
      rng = 0.2
    elseif math.random(1, 8) == 1 then
      rng = 0.4
    end
    local to_heal = entity.prototype.max_health * rng
    if entity.health and to_heal then
      entity.health = entity.health + to_heal
    end
  end
end
)

function Public.repair_aoe(player, position)
  local entities = player.surface.find_entities_filtered {force = player.force, area = {{position.x - 8, position.y - 8}, {position.x + 8, position.y + 8}}}
  local count = 0
  for i = 1, #entities do
    local e = entities[i]
    if e.prototype.max_health ~= e.health then
      count = count + 1
      Task.set_timeout_in_ticks(10, repair_buildings, {entity = e})
    end
  end
  return count
end

function Public.suicidal_comfylatron(pos, surface)
  local str = travelings[math.random(1, #travelings)]
  local symbols = {'', '!', '!', '!!', '..'}
  str = str .. symbols[math.random(1, #symbols)]
  local text = str
  local e =
  surface.create_entity(
  {
    name = 'compilatron',
    position = {x = pos.x, y = pos.y + 2},
    force = 'neutral'
  }
)
surface.create_entity(
{
  name = 'compi-speech-bubble',
  position = e.position,
  source = e,
  text = text
}
)
local nearest_player_unit = surface.find_nearest_enemy({position = e.position, max_distance = 512, force = 'player'})

if nearest_player_unit and nearest_player_unit.active and nearest_player_unit.force.name ~= 'player' then
  e.set_command(
  {
    type = defines.command.attack,
    target = nearest_player_unit,
    distraction = defines.distraction.none
  }
)
local data = {
  entity = e,
  surface = surface
}
Task.set_timeout_in_ticks(600, desync, data)
else
  e.surface.create_entity({name = 'medium-explosion', position = e.position})
  e.surface.create_entity(
  {
    name = 'flying-text',
    position = e.position,
    text = 'DeSyyNC - no target found!',
    color = {r = 150, g = 0, b = 0}
  }
)
e.die()
end
end

function Public.validate_player(player)
  if not player then
    return false
  end
  if not player.valid then
    return false
  end
  if not player.character then
    return false
  end
  if not player.connected then
    return false
  end
  if not game.players[player.index] then
    return false
  end
  return true
end

function Public.remove_mana(player, mana_to_remove)
  local rpg_extra = Public.get('rpg_extra')
  local rpg_t = Public.get_value_from_player(player.index)
  if not rpg_extra.enable_mana then
    return
  end

  if not mana_to_remove then
    return
  end

  mana_to_remove = floor(mana_to_remove)

  if not rpg_t then
    return
  end

  if rpg_t.debug_mode then
    rpg_t.mana = 9999
    return
  end

  if player.gui.screen[main_frame_name] then
    local f = player.gui.screen[main_frame_name]
    local data = Gui.get_data(f)
    if data.mana and data.mana.valid then
      data.mana.caption = rpg_t.mana
    end
  end

  rpg_t.mana = rpg_t.mana - mana_to_remove

  if rpg_t.mana < 0 then
    rpg_t.mana = 0
    return
  end

  if player.gui.screen[spell_gui_frame_name] then
    local f = player.gui.screen[spell_gui_frame_name]
    if f['spell_table'] then
      if f['spell_table']['mana'] then
        f['spell_table']['mana'].caption = math.floor(rpg_t.mana)
      end
      if f['spell_table']['maxmana'] then
        f['spell_table']['maxmana'].caption = math.floor(rpg_t.mana_max)
      end
    end
  end
end

function Public.update_mana(player)
  local rpg_extra = Public.get('rpg_extra')
  local rpg_t = Public.get_value_from_player(player.index)
  if not rpg_extra.enable_mana then
    return
  end

  if not rpg_t then
    return
  end

  if player.gui.screen[main_frame_name] then
    local f = player.gui.screen[main_frame_name]
    local data = Gui.get_data(f)
    if data.mana and data.mana.valid then
      data.mana.caption = rpg_t.mana
    end
  end
  if player.gui.screen[spell_gui_frame_name] then
    local f = player.gui.screen[spell_gui_frame_name]
    if f['spell_table'] then
      if f['spell_table']['mana'] then
        f['spell_table']['mana'].caption = math.floor(rpg_t.mana)
      end
      if f['spell_table']['maxmana'] then
        f['spell_table']['maxmana'].caption = math.floor(rpg_t.mana_max)
      end
    end
  end

  if rpg_t.mana < 1 then
    return
  end
  if rpg_extra.enable_health_and_mana_bars then
    if rpg_t.show_bars then
      if player.character and player.character.valid then
        if not rpg_t.mana_bar then
          rpg_t.mana_bar = create_manabar(player, 0.5)
        elseif not rendering.is_valid(rpg_t.mana_bar) then
          rpg_t.mana_bar = create_manabar(player, 0.5)
        end
        set_bar(rpg_t.mana, rpg_t.mana_max, rpg_t.mana_bar, true)
      end
    else
      if rpg_t.mana_bar then
        if rendering.is_valid(rpg_t.mana_bar) then
          rendering.destroy(rpg_t.mana_bar)
        end
      end
    end
  end
end

function Public.reward_mana(player, mana_to_add)
  local rpg_extra = Public.get('rpg_extra')
  local rpg_t = Public.get_value_from_player(player.index)
  if not rpg_extra.enable_mana then
    return
  end

  if not mana_to_add then
    return
  end

  mana_to_add = floor(mana_to_add)

  if not rpg_t then
    return
  end

  if player.gui.screen[main_frame_name] then
    local f = player.gui.screen[main_frame_name]
    local data = Gui.get_data(f)
    if data.mana and data.mana.valid then
      data.mana.caption = rpg_t.mana
    end
  end
  if player.gui.screen[spell_gui_frame_name] then
    local f = player.gui.screen[spell_gui_frame_name]
    if f['spell_table'] then
      if f['spell_table']['mana'] then
        f['spell_table']['mana'].caption = math.floor(rpg_t.mana)
      end
      if f['spell_table']['maxmana'] then
        f['spell_table']['maxmana'].caption = math.floor(rpg_t.mana_max)
      end
    end
  end

  if rpg_t.mana_max < 1 then
    return
  end

  if rpg_t.mana >= rpg_t.mana_max then
    rpg_t.mana = rpg_t.mana_max
    return
  end

  rpg_t.mana = rpg_t.mana + mana_to_add
end

function Public.update_health(player)
  local rpg_extra = Public.get('rpg_extra')
  local rpg_t = Public.get_value_from_player(player.index)

  if not player or not player.valid then
    return
  end

  if not player.character or not player.character.valid then
    return
  end

  if not rpg_t then
    return
  end

  if player.gui.screen[main_frame_name] then
    local f = player.gui.screen[main_frame_name]
    local data = Gui.get_data(f)
    if data.health and data.health.valid then
      data.health.caption = (round(player.character.health * 10) / 10)
    end
    local shield_gui = player.character.get_inventory(defines.inventory.character_armor)
    if not shield_gui.is_empty() then
      if shield_gui[1].grid then
        local shield = math.floor(shield_gui[1].grid.shield)
        local shield_max = math.floor(shield_gui[1].grid.max_shield)
        if data.shield and data.shield.valid then
          data.shield.caption = shield
        end
        if data.shield_max and data.shield_max.valid then
          data.shield_max.caption = shield_max
        end
      end
    end
  end

  if rpg_extra.enable_health_and_mana_bars then
    if rpg_t.show_bars then
      local max_life = math.floor(player.character.prototype.max_health + player.character_health_bonus + player.force.character_health_bonus)
      if not rpg_t.health_bar then
        rpg_t.health_bar = create_healthbar(player, 0.5)
      elseif not rendering.is_valid(rpg_t.health_bar) then
        rpg_t.health_bar = create_healthbar(player, 0.5)
      end
      set_bar(player.character.health, max_life, rpg_t.health_bar)
    else
      if rpg_t.health_bar then
        if rendering.is_valid(rpg_t.health_bar) then
          rendering.destroy(rpg_t.health_bar)
        end
      end
    end
  end
end

function Public.level_limit_exceeded(player, value)
  local rpg_extra = Public.get('rpg_extra')
  local rpg_t = Public.get_value_from_player(player.index)
  if not rpg_extra.level_limit_enabled then
    return false
  end

  local limits = {
    [1] = 30,
    [2] = 50,
    [3] = 70,
    [4] = 90,
    [5] = 110,
    [6] = 130,
    [7] = 150,
    [8] = 170,
    [9] = 190,
    [10] = 210
  }

  local level = rpg_t.level
  local zone = rpg_extra.breached_walls
  if zone >= 11 then
    zone = 10
  end
  if value then
    return limits[zone]
  end

  if level >= limits[zone] then
    return true
  end
  return false
end

function Public.level_up_effects(player)
  local position = {x = player.position.x - 0.75, y = player.position.y - 1}
  -- game.print("升级了2")
  player.surface.create_entity({name = 'flying-text', position = position, text = '+LVL ', color = level_up_floating_text_color})
  local b = 0.75
  for _ = 1, 5, 1 do
    local p = {
      (position.x + 0.4) + (b * -1 + math.random(0, b * 20) * 0.1),
      position.y + (b * -1 + math.random(0, b * 20) * 0.1)
    }
    player.surface.create_entity({name = 'flying-text', position = p, text = '✚', color = {255, math.random(0, 100), 0}})
  end
  player.play_sound {path = 'utility/achievement_unlocked', volume_modifier = 0.40}
end

function Public.xp_effects(player)
  local position = {x = player.position.x - 0.75, y = player.position.y - 1}
  player.surface.create_entity({name = 'flying-text', position = position, text = '+XP', color = level_up_floating_text_color})
  local b = 0.75
  for _ = 1, 5, 1 do
    local p = {
      (position.x + 0.4) + (b * -1 + math.random(0, b * 20) * 0.1),
      position.y + (b * -1 + math.random(0, b * 20) * 0.1)
    }
    player.surface.create_entity({name = 'flying-text', position = p, text = '✚', color = {255, math.random(0, 100), 0}})
  end
  player.play_sound {path = 'utility/achievement_unlocked', volume_modifier = 0.40}
end

function Public.get_melee_modifier(player)
  local rpg_t = Public.get_value_from_player(player.index)
  return (rpg_t.strength - 10) * 0.10
end

function Public.get_final_damage_modifier(player)
  local rpg_t = Public.get_value_from_player(player.index)
  local rng = random(10, 35) * 0.01
  return (rpg_t.strength - 10) * rng
end

function Public.get_final_damage(player, entity, original_damage_amount)
  local modifier = Public.get_final_damage_modifier(player)
  local damage = original_damage_amount + original_damage_amount * modifier
  if entity.prototype.resistances then
    if entity.prototype.resistances.physical then
      damage = damage - entity.prototype.resistances.physical.decrease
      damage = damage - damage * entity.prototype.resistances.physical.percent
    end
  end
  damage = round(damage, 3)
  if damage < 1 then
    damage = 1
  end
  return damage
end

function Public.get_heal_modifier(player)
  local rpg_t = Public.get_value_from_player(player.index)
  return (rpg_t.vitality - 10) * 5  -- 回血速度
end

function Public.get_heal_modifier_from_using_fish(player)
  local rpg_extra = Public.get('rpg_extra')
  if rpg_extra.disable_get_heal_modifier_from_using_fish then
    return
  end

  local base_amount = 80
  local rng = random(base_amount, base_amount * rpg_extra.heal_modifier)
  local char = player.character
  local position = player.position
  if char and char.valid then
    local health = player.character_health_bonus + 250
    local color
    if char.health > (health * 0.50) then
      color = {b = 0.2, r = 0.1, g = 1, a = 0.8}
    elseif char.health > (health * 0.25) then
      color = {r = 1, g = 1, b = 0}
    else
      color = {b = 0.1, r = 1, g = 0, a = 0.8}
    end
    player.surface.create_entity(
    {
      name = 'flying-text',
      position = {position.x, position.y + 0.6},
      text = '+' .. rng,
      color = color
    }
  )
  char.health = char.health + rng
end
end

function Public.get_mana_modifier(player)
  local rpg_t = Public.get_value_from_player(player.index)
  if rpg_t.level <= 40 then
    return (rpg_t.magicka - 10) * 0.02000
  elseif rpg_t.level <= 80 then
    return (rpg_t.magicka - 10) * 0.01800
  else
    return (rpg_t.magicka - 10) * 0.01400
  end
end

function Public.get_life_on_hit(player)
  local rpg_t = Public.get_value_from_player(player.index)
  return (rpg_t.vitality - 10) * 10
end

function Public.get_one_punch_chance(player)
  local rpg_t = Public.get_value_from_player(player.index)
  local chance = round(rpg_t.strength * 0.1, 1)
  if chance > 100 then
    chance = 100
  end
  return chance
end

function Public.get_extra_following_robots(player)
  local rpg_t = Public.get_value_from_player(player.index)
  local strength = rpg_t.strength
  local count = round(strength / 2 * 0.03, 3)
  return count
end

function Public.get_magicka(player)
  local rpg_t = Public.get_value_from_player(player.index)
  return (rpg_t.magicka - 10) * 0.10
end

--- Gives connected player some bonus xp if the map was preemptively shut down.
-- amount (integer) -- 10 levels
-- local Public = require 'modules.rpg.table' Public.give_xp(512)
function Public.give_xp(amount)
  for _, player in pairs(game.connected_players) do
    if not Public.validate_player(player) then
      return
    end
    -- game.print("加经验3")
    Public.gain_xp(player, amount)
  end
end

function Public.rpg_reset_player(player, one_time_reset)
  if not player.character then
    player.set_controller({type = defines.controllers.god})
    player.create_character()
  end
  local rpg_t = Public.get_value_from_player(player.index)
  local rpg_extra = Public.get('rpg_extra')
  if one_time_reset then
    local total = rpg_t.total
    if not total then
      total = 0
    end
    if rpg_t.text then
      rendering.destroy(rpg_t.text)
      rpg_t.text = nil
    end
    local old_level = rpg_t.level
    local old_points_left = rpg_t.points_left
    local old_xp = rpg_t.xp
    rpg_t =
    Public.set_new_player_tbl(
    player.index,
    {
      level = 1,
      xp = 0,
      strength = 10,
      magicka = 10,
      dexterity = 10,
      vitality = 10,
      mana = 0,
      mana_max = 0,
      last_spawned = 0,
      dropdown_select_index = 1,
      dropdown_select_index1 = 1,
      dropdown_select_index2 = 1,
      dropdown_select_index3 = 1,
      allocate_index = 1,
      flame_boots = false,
      explosive_bullets = false,
      enable_entity_spawn = true,
      health_bar = rpg_t.health_bar,
      mana_bar = rpg_t.mana_bar,
      points_left = 0,
      last_floaty_text = visuals_delay,
      xp_since_last_floaty_text = 0,
      reset = true,
      capped = false,
      bonus = rpg_extra.breached_walls or 1,
      rotated_entity_delay = 0,
      last_mined_entity_position = {x = 0, y = 0},
      show_bars = true,
      stone_path = false,
      one_punch = false,
      auto_toggle_features = {
        stone_path = false,
        one_punch = false
      }
    }
  )
  rpg_t.points_left = old_points_left + total
  rpg_t.xp = round(old_xp)
  rpg_t.level = old_level
else
  Public.set_new_player_tbl(
  player.index,
  {
    level = 1,
    xp = 0,
    strength = 10,
    magicka = 10,
    dexterity = 10,
    vitality = 10,
    mana = 0,
    mana_max = 0,
    last_spawned = 0,
    dropdown_select_index = 1,
    dropdown_select_index1 = 1,
    dropdown_select_index2 = 1,
    dropdown_select_index3 = 1,
    allocate_index = 1,
    flame_boots = false,
    explosive_bullets = false,
    enable_entity_spawn = true,
    points_left = 0,
    last_floaty_text = visuals_delay,
    xp_since_last_floaty_text = 0,
    reset = false,
    capped = false,
    total = 0,
    bonus = 1,
    rotated_entity_delay = 0,
    last_mined_entity_position = {x = 0, y = 0},
    show_bars = true,
    stone_path = false,
    one_punch = false,
    auto_toggle_features = {
      stone_path = false,
      one_punch = false
    }
  }
)
end
Public.draw_gui_char_button(player)
Public.draw_level_text(player)
Public.update_char_button(player)
Public.update_player_stats(player)
end

function Public.rpg_reset_all_players()
  local rpg_t = Public.get('rpg_t')
  local rpg_extra = Public.get('rpg_extra')
  for k, _ in pairs(rpg_t) do
    rpg_t[k] = nil
  end
  for _, p in pairs(game.connected_players) do
    Public.rpg_reset_player(p)
  end
  rpg_extra.breached_walls = 1
  rpg_extra.reward_new_players = 0
  rpg_extra.global_pool = 0

  for _, player in pairs(game.connected_players) do
		Public.update_player_stats(player)
	end
end

function Public.gain_xp(player, amount, added_to_pool, text)
  -- game.print("获取经验"..amount)
  if not Public.validate_player(player) then
    return
  end
  local rpg_extra = Public.get('rpg_extra')
  local rpg_t = Public.get_value_from_player(player.index)

  if Public.level_limit_exceeded(player) then
    add_to_global_pool(amount, false)
    if not rpg_t.capped then
      rpg_t.capped = true
      local message = ({'rpg_functions.max_level'})
      Alert.alert_player_warning(player, 10, message)
    end
    return
  end

  local text_to_draw

  if rpg_t.capped then
    rpg_t.capped = false
  end

  if not added_to_pool then
    Public.debug_log('RPG - ' .. player.name .. ' got org xp: ' .. amount)
    local fee = amount - add_to_global_pool(amount, true)
    Public.debug_log('RPG - ' .. player.name .. ' got fee: ' .. fee)
    amount = round(amount, 3) - fee
    if rpg_extra.difficulty then
      amount = amount + rpg_extra.difficulty
    end
    Public.debug_log('RPG - ' .. player.name .. ' got after fee: ' .. amount)
  else
    Public.debug_log('RPG - ' .. player.name .. ' got org xp: ' .. amount)
  end

  rpg_t.xp = round(rpg_t.xp + amount, 3)
  rpg_t.xp_since_last_floaty_text = round(rpg_t.xp_since_last_floaty_text + amount)

  if not experience_levels[rpg_t.level + 1] then
    return
  end

  local f = player.gui.screen[main_frame_name]
  if f and f.valid then
    local d = Gui.get_data(f)
    if d.exp_gui and d.exp_gui.valid then
      d.exp_gui.caption = math.floor(rpg_t.xp)
    end
  end

  if rpg_t.xp >= experience_levels[rpg_t.level + 1] then
    level_up(player)
  end

  if rpg_t.last_floaty_text > game.tick then
    if not text then
      return
    end
  end

  if text then
    text_to_draw = '+' .. math.floor(amount) .. ' xp'
  else
    text_to_draw = '+' .. math.floor(rpg_t.xp_since_last_floaty_text) .. ' xp'
  end

  player.create_local_flying_text {
    text = text_to_draw,
    position = player.position,
    color = xp_floating_text_color,
    time_to_live = 340,
    speed = 2
  }

  rpg_t.xp_since_last_floaty_text = 0
  rpg_t.last_floaty_text = game.tick + visuals_delay
end

function Public.global_pool(players, count)
  local rpg_extra = Public.get('rpg_extra')

  if not rpg_extra.global_pool then
    return
  end

  local pool = math.floor(rpg_extra.global_pool)

  local random_amount = math.random(5000, 10000)

  if pool <= random_amount then
    return
  end

  if pool >= 20000 then
    pool = 20000
  end

  local share = pool / count

  Public.debug_log('RPG - Share per player:' .. share)

  for i = 1, #players do
    local p = players[i]
    if p.afk_time < 5000 then
      if not Public.level_limit_exceeded(p) then
        -- game.print("加经验4")
        Public.gain_xp(p, share, false, true)
        Public.xp_effects(p)
      else
        share = share / 10
        rpg_extra.leftover_pool = rpg_extra.leftover_pool + share
        Public.debug_log('RPG - player capped: ' .. p.name .. '. Amount to pool:' .. share)
      end
    else
      local message = ({'rpg_functions.pool_reward', p.name})
      Alert.alert_player_warning(p, 10, message)
      share = share / 10
      rpg_extra.leftover_pool = rpg_extra.leftover_pool + share
      Public.debug_log('RPG - player AFK: ' .. p.name .. '. Amount to pool:' .. share)
    end
  end

  rpg_extra.global_pool = rpg_extra.leftover_pool or 0

  return
end

local damage_player_over_time_token =
Token.register(
function(data)
  local player = data.player
  if not player.character or not player.character.valid then
    return
  end
  player.character.health = player.character.health - (player.character.health * 0.05)
  player.character.surface.create_entity({name = 'water-splash', position = player.position})
end
)

--- Damages a player over time.
function Public.damage_player_over_time(player, amount)
  if not player or not player.valid then
    return
  end

  amount = amount or 10
  local tick = 20
  for _ = 1, amount, 1 do
    Task.set_timeout_in_ticks(tick, damage_player_over_time_token, {player = player})
    tick = tick + 15
  end
end

--- Distributes the global xp pool to every connected player.
function Public.distribute_pool()
  local count = #game.connected_players
  local players = game.connected_players
  Public.global_pool(players, count)
  print('Distributed the global XP pool')
end

local function on_entity_damaged(event)
	if not event.cause then return end
	if not event.cause.valid then return end
	if event.damage_type.name ~= "physical" then return end
	if event.cause.force.index == 2 then return end
	if event.cause.name ~= "character" then return end

	if not event.entity.valid then return end
	if event.cause.get_inventory(defines.inventory.character_ammo)[event.cause.selected_gun_index].valid_for_read
	and event.cause.get_inventory(defines.inventory.character_guns)[event.cause.selected_gun_index].valid_for_read then return end
	if not event.cause.player then return end

	--Grant the player life-on-hit.\
  local damage = Public.get_life_on_hit(event.cause.player)
	--Calculate modified damage.
	-- if event.entity.prototype.resistances then
	-- 	if event.entity.prototype.resistances.physical then
	-- 		damage = damage - event.entity.prototype.resistances.physical.decrease
	-- 		damage = damage - damage * event.entity.prototype.resistances.physical.percent
	-- 	end
	-- end
	damage = math.round(damage, 3)
	if damage < 1 then damage = 1 end

	--Cause a one punch.
	-- if math_random(0,999) < get_one_punch_chance(event.cause.player) * 10 then
	-- 	one_punch(event.cause, event.entity, damage)
	-- 	if event.entity.valid then
	-- 		event.entity.die(event.entity.force.name, event.cause)
	-- 	end
	-- 	return
	-- end

	--Floating messages and particle effects.
	if math_random(0,999) < Public.get_one_punch_chance(event.cause.player) * 10 then
		damage = damage * math_random(250, 350) * 0.01
    event.cause.health = event.cause.health + damage * 10
    damage = damage + damage * Public.get_melee_modifier(event.cause.player)
		event.cause.surface.create_entity({name = "flying-text", position = event.entity.position, text = "‼" .. math.floor(damage), color = {255, 0, 0}})
		event.cause.surface.create_entity({name = "blood-explosion-huge", position = event.entity.position})
	else
		damage = damage * math_random(100, 125) * 0.01
    event.cause.health = event.cause.health + damage * 10
    damage = damage + damage * Public.get_melee_modifier(event.cause.player)
		event.cause.player.create_local_flying_text({text = math.floor(damage), position = event.entity.position, color = {150, 150, 150}, time_to_live = 90, speed = 2})
	end
  

  

	--Handle the custom health pool of the biter health booster, if it is used in the map.
	if global.biter_health_boost then
		local health_pool = global.biter_health_boost_units[event.entity.unit_number]
		if health_pool then
			health_pool[1] = health_pool[1] - damage

			--Set entity health relative to health pool
			event.entity.health = health_pool[1] * health_pool[2]

			if health_pool[1] <= 0 then
				global.biter_health_boost_units[event.entity.unit_number] = nil
				event.entity.die(event.entity.force.name, event.cause)
			end
			return
		end
	end

	--Handle vanilla damage.
	event.entity.health = event.entity.health - damage
	if event.entity.health <= 0 then
		event.entity.die(event.entity.force.name, event.cause)
	end
end


Event.add(defines.events.on_entity_damaged, on_entity_damaged)


Public.add_to_global_pool = add_to_global_pool
