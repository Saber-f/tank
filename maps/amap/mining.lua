local RPGtable = require 'modules.rpg.table'
local Loot = require "maps.amap.loot"
local BiterRolls = require 'modules.wave_defense.biter_rolls'
local Pets = require 'maps.amap.biter_pets'
local WPT = require 'maps.amap.table'
local random = math.random
local Alert = require 'utils.alert'
local WD = require 'modules.wave_defense.table'
local Task = require 'utils.task'
local Token = require 'utils.token'

local ent_to_create = {'biter-spawner', 'spitter-spawner'}
--[[
if is_mod_loaded('bobenemies') then
  ent_to_create = {'bob-biter-spawner', 'bob-spitter-spawner'}
end
]]--

local function unstuck_player(index)
  local player = game.get_player(index)
  local surface = player.surface
  local position = surface.find_non_colliding_position('character', player.position, 32, 0.5)
  if not position then
    return
  end
  player.teleport(position, surface)
end

local do_biter =
Token.register(
function(data)
  local surface=data.surface
  local name=data.name
  local pos=data.position
   surface.create_entity({name = name, position = pos,force=game.forces.enemy})
end
)
local function hidden_biter(entity)
  local pos = entity.position
  local roll = math.random(1, 3)
  local name
  if roll == 1 then
    name = BiterRolls.wave_defense_roll_spitter_name()
  elseif roll == 2 then
    name = BiterRolls.wave_defense_roll_biter_name()
  else
    name = BiterRolls.wave_defense_roll_worm_name()
  end
  if not name then return end
  local wave_number = WD.get('wave_number')
  local count = math.floor(wave_number*0.1)+math.random(1,10)
  if count>= 30 then count=30 end
  local data={}
  data.surface=entity.surface
  data.position=pos
  data.name=name
  for i=1,count do
    Task.set_timeout_in_ticks(i*30, do_biter, data)
  end

end

local function hidden_biter_pet(player, entity)
  local pos = entity.position
  local name
  local unit
  if random(1, 3) == 1 then
    name =BiterRolls.wave_defense_roll_spitter_name()
  else
    name = BiterRolls.wave_defense_roll_biter_name()
  end
  if name then
    unit = entity.surface.create_entity({name = name, position = pos,force=game.forces.player})
    Pets.biter_pets_tame_unit(game.players[player.index], unit)
  end
end
local function hidden_treasure(player, entity)
  local rpg = RPGtable.get('rpg_t')
  local magic = rpg[player.index].magicka
  local msg = 'look,you find a treasure'
  Alert.alert_player(player, 5, msg)
  Loot.add_rare(entity.surface, entity.position, 'wooden-chest', magic)
end


local function on_player_mined_entity(event)
  local entity = event.entity
  if not entity.valid then return end
  if entity.type ~= "simple-entity" and entity.type ~= "tree" then return end
  local surface = entity.surface
  local this = WPT.get()
  if event.player_index then game.players[event.player_index].insert({name = "coin", count = 1}) end
  local player = game.players[event.player_index]
  local rpg = RPGtable.get('rpg_t')
  local rpg_char = rpg[player.index]
  if rpg_char.stone_path then
    entity.surface.set_tiles({{name = 'stone-path', position = entity.position}}, true)
  end


  if random(1,1024) < 2 then
    local position = {entity.position.x , entity.position.y }
    surface.create_entity({name = 'car', position = position, force = 'player'})
    unstuck_player(player.index)
    local msg = ('you find a car!')
    Alert.alert_player(player, 15, msg)
  end

  if random(1,150) < 2 then
    local position = {entity.position.x , entity.position.y }
    local e = surface.create_entity({name = ent_to_create[random(1, #ent_to_create)], position = position, force = 'enemy'})
    e.destructible = false
    this.biter_wudi[#this.biter_wudi+1]=e
    unstuck_player(player.index)
  end
  if random(1,150)  < 2 then
    hidden_treasure(player,entity)
  end
  if random(1,170)  < 3 then
    hidden_biter_pet(player,entity)
  end
  if random(1,100)  < 3 then
    hidden_biter(entity)
   end
end

local function on_entity_died(event)

  if not event.entity then return end
  if not event.entity.valid then return end
  local this = WPT.get()
  if	not(event.entity.surface.index == game.surfaces[this.active_surface_index].index) then return end


  local force = event.entity.force
  if force.index == game.forces.player.index then
    local name = event.entity.name


    if name =="artillery-wagon" or name =="artillery-turret" then
          local unit_number=event.entity.unit_number
      if this.water_arty[unit_number] then
         this.water_arty[unit_number] =nil
      end
    end

    if name == 'flamethrower-turret' then
      this.flame = this.flame - 1
      if this.flame <= 0 then
        this.flame = 0
      end
      return
    end

    if name == 'land-mine' then
      this.now_mine = this.now_mine - 1
      if this.now_mine <= 0 then
        this.now_mine = 0
      end
        return
    end

  end

end
local Event = require 'utils.event'
Event.add(defines.events.on_entity_died, on_entity_died)
Event.add(defines.events.on_player_mined_entity, on_player_mined_entity)
