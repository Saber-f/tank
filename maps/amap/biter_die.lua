local Event = require 'utils.event'
local WPT = require 'maps.amap.table'
local WD = require 'modules.wave_defense.table'
local BiterRolls = require 'modules.wave_defense.biter_rolls'
local Token = require 'utils.token'
local Task = require 'utils.task'
local WaveDefense = require 'modules.wave_defense.main'
local BiterHealthBooster = require 'modules.biter_health_booster_v2'

local entity_types = {
  ['unit'] = true,
  ['turret'] = true,
  ['unit-spawner'] = true
}
local number={
  -- ['rocket'] = {max=10,mix=3,bouns=1},
  -- ['explosive-rocket']= {max=8,mix=2,bouns=1},
  ['destroyer-capsule']= {max=8,mix=3,bouns=1},
  ['land-mine']= {max=8,mix=3,bouns=1},
  -- ['biter-spawner']= {max=2,mix=1,bouns=1},
  ['gun-turret']= {max=8,mix=1,bouns=1},
  ['grenade']= {max=8,mix=5,bouns=1},
  ['cluster-grenade']= {max=10,mix=2,bouns=1},
  ['small-biter'] =  {max=20,mix=10,bouns=1},
  ['medium-biter'] = {max=10,mix=8,bouns=1},
  ['big-biter'] =  {max=8,mix=4,bouns=1},
  ['behemoth-biter'] =  {max=8,mix=2,bouns=1},
  ['small-spitter'] =   {max=20,mix=10,bouns=1},
  ['medium-spitter'] =  {max=10,mix=8,bouns=1},
  ['big-spitter'] =  {max=9,mix=4,bouns=1},
  ['behemoth-spitter'] ={max=10,mix=2,bouns=1},
  ['small-worm-turret'] =  {max=6,mix=1,bouns=1},
  ['medium-worm-turret'] =  {max=5,mix=1,bouns=1},
  ['big-worm-turret'] = {max=4,mix=1,bouns=1},
  ['behemoth-worm-turret'] =  {max=3,mix=1,bouns=1},
}

local function unstuck_player(index)
  local player = game.get_player(index)
  local surface = player.surface
  local position = surface.find_non_colliding_position('character', player.position, 32, 0.5)
  if not position then
    return
  end
  player.teleport(position, surface)
end

local do_die =
Token.register(
function(data)
  local position = data.position
  local surface=data.surface
  local source =data.source
  local name=data.name
  local change = data.change
  if change then
    source = surface.find_non_colliding_position(name, source, 32, 0.5)
    source = {x=source.x + ( math.random(-10, 10)), y=source.y + (math.random(-10, 10))}
  end

  local  e =  surface.create_entity(
  {
    name =name ,
    position = source,
    force = 'enemy',
    source = source,
    target = position,
    speed = 0.3
  }

)
if e.name == 'gun-turret' then
  local ammo_name= require 'maps.amap.enemy_arty'.get_ammo()
  e.insert{name=ammo_name, count = 200}
end
if e.name == 'biter-spawner' then
  local this = WPT.get()
  e.destructible = false
  this.biter_wudi[#this.biter_wudi+1]=e


  for k, player in pairs(game.connected_players) do
    unstuck_player(player.index)
  end
end
end
)

local function loaded_biters(event)
  local entity = event.entity
  if not entity or not entity.valid then
    return
  end

  local position = false
  if cause then
    if cause.valid then
      position = cause.position
    end
  end
  if not position then
    position = {entity.position.x + (-20 + math.random(0, 40)), entity.position.y + (-20 + math.random(0, 40))}
  end

  local projectiles = {
    'rocket',
    'explosive-rocket',
    'destroyer-capsule'
  }

  local buliding ={
    'land-mine',
    -- 'biter-spawner',
    'gun-turret',
    [4]=BiterRolls.wave_defense_roll_worm_name(),
    [5]=BiterRolls.wave_defense_roll_spitter_name(),
    [6]=BiterRolls.wave_defense_roll_biter_name()
  }
  local boom ={
    'grenade',
    'cluster-grenade'
  }

  local k=math.random(#boom+#buliding+#projectiles)
  local k_buliding=#buliding
  local k_projectiles=#buliding+#projectiles
  local k_boom=#boom+ #buliding + #projectiles


  local ku
  if k>=1 and k <= k_buliding then
    ku=buliding
  end
  if k> k_buliding and k <= k_projectiles then
    ku=projectiles
  end
  if k> k_projectiles and k <= k_boom then
    ku=boom
  end

  if ku==boom then
    position=entity.position
  end



  local name = ku[math.random(#ku)]
  local wave_number = WD.get('wave_number')
  local k_max=number[name].max
  local k_min=number[name].mix
  local k_bouns=number[name].bouns
  local count
  if k_bouns ==1 then
    count = math.random(k_min,k_max)
  else
    count= k_min+math.floor((wave_number-1000)*0.05)*k_bouns
  end

local data ={}
data.position=position
data.surface=entity.surface
data.source=entity.position
data.name=name

if ku == buliding then
  data.change = true
end

for i=1,count do
  Task.set_timeout_in_ticks(i*30, do_die, data)
end
end


-- 死亡加经验
local dieAddExp = function(entity)
  if (entity.force.name == "neutral" and entity.type == "turret") then

    if WD.get().next_wave == game.tick then return end
    for i = 1, 4 do
      WaveDefense.set_next_wave()
    end
    WD.set().next_wave = game.tick
   
    local surface=entity.surface
    local wave_number = WD.get('wave_number')
    if wave_number > 3000 - 100 then
      game.print('最后100波不能跳',{r=1,g=0,b=0})
      return
    end

    local name = "bm-worm-boss-fire-shooter"
    -- local name = "small-worm-turret"
    -- if wave_number > 2100 then
    --   name = "bm-worm-boss-fire-shooter"
    -- elseif wave_number > 1800 then
    --   name = "bm-worm-boss-acid-shooter"
    -- elseif wave_number > 1500 then
    --   name = "maf-colossal-worm-turret"
    -- elseif wave_number > 1200 then
    --   name = "maf-behemoth-worm-turret"
    -- elseif wave_number > 900 then
    --   name = "behemoth-worm-turret"
    -- elseif wave_number > 600 then
    --   name = "big-worm-turret"
    -- elseif wave_number > 300 then
    --   name = "medium-worm-turret"
    -- end
    local biter = surface.create_entity({name = name, position = {x=0,y=70}, force = 'neutral'})
    local modified_unit_health = WD.get('modified_unit_health')
    BiterHealthBooster.add_unit(biter, modified_unit_health.current_value)
    game.print('跳波沙虫已生成，击杀直接跳5波[gps=' .. 0 .. ',' .. 70 .. ',' .. surface.name .. ']',{r=1,g=0,b=0})
  end

end


local on_entity_died = function(event)
  local entity = event.entity
  if not (entity and entity.valid) then
    return
  end
  if entity.force.index == game.forces.player.index then
    
    if (entity.name == "small-worm-turret") then
      game.print("我方保卫沙虫已被击杀！！！",{r=1,g=0,b=0})
      local this = WPT.get()
      this.reset_time=600
      this.start_game = 3
    end
    return
  end

  dieAddExp(entity)


  -- if not entity_types[entity.type] then
  --   return
  -- end

  

  -- if entity.name == 'land-mine' then
    -- loaded_biters(event)
  --   return
  -- end

  -- local wave_number = WD.get('wave_number')
  -- if wave_number <= 1000 then return end

  -- local k = wave_number*0.002-1
  -- if k >= 4 then k = 4 end
  -- if math.random(1, 100) <= k then
    -- loaded_biters(event)
  -- end
end

local no_wudi = function()
  local this = WPT.get()
  for i,v in ipairs(this.biter_wudi) do
    local e = this.biter_wudi[i]
    e.destructible = true
    this.biter_wudi[i]=nil
  end

end

Event.on_nth_tick(480, no_wudi)
Event.add(defines.events.on_entity_died, on_entity_died)
