local WD = require 'modules.wave_defense.table'
local Event = require 'utils.event'
local BiterHealthBooster = require 'modules.biter_health_booster_v2'
local insert = table.insert
local floor = math.floor
local WPT = require 'maps.amap.table'

local coin_yield = {
  ['behemoth-biter'] = 5,
  ['behemoth-spitter'] = 5,
  ['behemoth-worm-turret'] = 20,
  ['big-biter'] = 3,
  ['big-spitter'] = 3,
  ['big-worm-turret'] = 16,
  ['biter-spawner'] = 32,
  ['medium-biter'] = 2,
  ['medium-spitter'] = 2,
  ['medium-worm-turret'] = 12,
  ['small-biter'] = 1,
  ['small-spitter'] = 1,
  ['small-worm-turret'] = 8,
  ['spitter-spawner'] = 32
}

local entities_that_earn_coins = {
  ['artillery-turret'] = true,
  ['gun-turret'] = true,
  ['laser-turret'] = true,
  ['flamethrower-turret'] = true
}

--extra coins for "boss" biters from biter_health_booster.lua
local function get_coin_count(entity)

  return math.floor(entity.prototype.max_health^0.2)

  -- local coin_count = coin_yield[entity.name]
  -- if not coin_count then
  --   return 1
  -- end
  -- local biter_health_boost_units = BiterHealthBooster.get('biter_health_boost_units')

  -- if not biter_health_boost_units then
  --   return coin_count
  -- end
  -- local unit_number = entity.unit_number
  -- if not unit_number then
  --   return coin_count
  -- end
  -- if not biter_health_boost_units[unit_number] then
  --   return coin_count
  -- end
  -- if not biter_health_boost_units[unit_number][3] then
  --   return coin_count
  -- end
  -- local m = 1 / biter_health_boost_units[unit_number][2]
  -- coin_count = floor(coin_count * m)
  -- if coin_count < 1 then
  --   return 1
  -- end
  -- return coin_count
end

local function on_entity_died(event)
  local wave_number = WD.get('wave_number')
  

  local entity = event.entity
  if not entity.valid then
    return
  end
  if entity.force.index ~= 2 then -- 如果不是地方队伍
    return
  end

  local cause = event.cause

  local coin_count = get_coin_count(entity)
  if not coin_count then
    return
  end

  local players_to_reward = {}
  local reward_has_been_given = false

  if cause then
    if cause.valid then
      if (cause and cause.name == 'character' and cause.player) then
        -- p = cause.player
        if game.forces.enemy.evolution_factor >= 0.2 then
          local index = cause.player.index
          local this=WPT.get()
          if not this.tank[index] or not this.tank[index].valid then
            return
          end
        end
      end

      if cause.name == 'character' then
        insert(players_to_reward, cause)
        reward_has_been_given = true
      end

      if wave_number > 0 then   -- 不掉金币
        return
      end

      if cause.type == 'car' then
        local player = cause.get_driver()
        local passenger = cause.get_passenger()
        if player then
          insert(players_to_reward, player.player)
        end
        if passenger then
          insert(players_to_reward, passenger.player)
        end
        reward_has_been_given = true
      end
      if cause.type == 'locomotive' then
        local train_passengers = cause.train.passengers
        if train_passengers then
          for _, passenger in pairs(train_passengers) do
            insert(players_to_reward, passenger)
          end
          reward_has_been_given = true
        end
      end
      for _, player in pairs(players_to_reward) do

        player.insert({name = 'coin', count = coin_count})

      end
    end



    if entities_that_earn_coins[cause.name] then
      if cause.name ~='artillery-turret' then
        event.entity.surface.spill_item_stack(cause.position, {name = 'coin', count = coin_count}, true)
        reward_has_been_given = true
      else
        if cause.last_user then
          local this = WPT.get()
          local temp_player = cause.last_user
          local index =temp_player.index
          if  this.tank[index] then
            event.entity.surface.spill_item_stack(cause.position, {name = 'coin', count = coin_count}, true)
            reward_has_been_given = true
          end
        end
      end
    end
  end

  if reward_has_been_given == false then
    event.entity.surface.spill_item_stack(event.entity.position, {name = 'coin', count = coin_count}, true)
  end
end

-- 添加炮塔
local function addTurrent(event)
  if event.created_entity.force.index == 2 then return end  -- 地方炮塔
  if global.Turrent == nil then
    global.Turrent = {}
  end
  if event.created_entity  and event.created_entity.kills then
    table.insert(global.Turrent, event.created_entity)
    game.print("放炮塔了:"..#global.Turrent)
  end
end

-- 移除炮塔
local function removeTurrent(event)
  local entity = event.entity
  if entity.force.index == 2 then return end    -- 地方炮塔
  if not entity.kills then return end
  for k,v in pairs(global.Turrent) do
    if v == entity then
      table.remove(global.Turrent, k)
      game.print("移除炮塔了:"..#global.Turrent)
    end
  end
end

-- Event.add(defines.events.on_entity_died, on_entity_died)
-- Event.add(defines.events.on_built_entity, addTurrent)    -- 玩家建造
-- Event.add(defines.events.on_robot_built_entity, addTurrent)  -- 机器人建造
-- Event.add(defines.events.on_robot_mined_entity, removeTurrent)    -- 机器人挖矿
-- Event.add(defines.events.on_player_mined_entity, removeTurrent)    -- 玩家挖矿
-- Event.add(defines.events.on_entity_died, removeTurrent)

