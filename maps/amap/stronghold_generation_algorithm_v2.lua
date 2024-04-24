local Public = {}
local table = {}

local Event = require 'utils.event'
local WPT = require 'maps.amap.table'
local Global = require 'utils.global'
local get_random_car =require "maps.amap.functions".get_random_car
local WD = require 'modules.wave_defense.table'
local Print = require('utils.print_override')
local raw_print = Print.raw_print

Global.register(
table,
function(tbl)
  table = tbl
end
)

function Public.reset_table()
  table.rail=false
  table.tongbu=true
  table.robot_time = 0
  table.first_pos={}
end

function Public.clear_rocket_silo()
  table.rocket_silo = nil

end

function Public.get_rocket_silo()
  if not table.rocket_silo then
    return false
  else
    return table.rocket_silo
  end
end

local player_build = {
  'small-electric-pole', -- 小电杆
  'medium-electric-pole', -- 中电杆
  'medium-electric-pole-2', -- 中电杆2
  'medium-electric-pole-3', -- 中电杆3
  'medium-electric-pole-4', -- 中电杆4
  'big-electric-pole', -- 大电杆
  'big-electric-pole-2', -- 大电杆2
  'big-electric-pole-3', -- 大电杆3
  'big-electric-pole-4', -- 大电杆4
  'substation', -- 变电站
  'substation-2', -- 变电站2
  'substation-3', -- 变电站3
  'substation-4', -- 变电站4
  'stone-wall', -- 石墙
  'reinforced-wall', -- 钢筋墙
  'Oem-linked-chest', -- 关联箱
}

local rail = {
  "straight-rail",
  "curved-rail"
}
-- 计算堡垒位置是否有冲突
-- return: true/false

local PI = 3.14157
local pi_12=0.261
local is_sh_conflict = function(sh_pos,surface)

  local ok = true
  local hight = global.MapHeight / 2 - 22

  if sh_pos.y >  hight or sh_pos.y < -hight then
    -- game.print("堡垒位置超出范围")
    ok=false
    return ok
  end


  local juli = 180
  local position=sh_pos

  local entities = surface.find_entities_filtered{position = position, radius = juli, name = player_build , force = game.forces.player,limit =1}
  if #entities~=0 then
    -- game.print("有玩家建筑")
    ok=false
    return ok
  end


  local area = {left_top = {position.x-48, position.y-48}, right_bottom = {position.x+48, position.y+48}}
  local roboports=surface.find_entities_filtered({type = {"roboport"}, area = area,force=game.forces.enemy,limit =1})
  if #roboports~=0 then
    for k,v in pairs(roboports) do
      if not v.destructible then
        -- game.print("有敌方机器人")
        ok=false
        -- table.robot_time = table.robot_time +1
        --game.print("已经有".. table.robot_time .. "个堡垒")
        return ok
      end
    end
  end

  local rails = surface.find_entities_filtered{position = position, radius = 48, name = rail , force = game.forces.player,limit =1}
  if #rails~=0 then
    -- game.print("有铁轨")
    ok=false
    if not table.rail then
      table.rail=true
      table.target=rails[1]
      table.tongbu=false
    end
    return ok
  end

  return ok
end


-- 寻找可能生成堡垒的位置
-- params:
-- car_pos - 靶车位置
-- sh_dis - 堡垒间最小距离，同时也是搜索圆增长的步长（因为 x 轴上两个堡垒至少间隔这个距离，故半径增长不能少于此)
-- return: 堡垒位置

-- 1.读取上次的角度
-- 2.计算这次的角度
-- 3.确定角度后移位置
-- 4.存储角度

function Public.find_available_stronghold_position(car_pos, sh_dis,surface,car)
  local found = false
  -- 堡垒搜索圆半径
  local sh_radius = sh_dis
  -- 堡垒角度
  local this=WPT.get()
  local sh_theta =this.theta_times*pi_12
  --  local sh_theta = 0

  local sh_pos_x = car_pos.x + sh_radius * math.cos(sh_theta)
  local sh_pos_y = car_pos.y + sh_radius * math.sin(sh_theta)
  local sh_pos = {x=sh_pos_x, y=sh_pos_y}

  local cos_theta = 1 - (sh_dis*sh_dis/(2*sh_radius*sh_radius))
  local theta = math.acos(cos_theta)
  sh_theta = sh_theta + theta
  if sh_theta >= 2*PI then
    sh_theta = sh_theta-2*PI
    -- sh_radius = sh_radius + sh_dis
  end
  --计算后的角度
  while not found do

    if table.rail and not table.tongbu then
      sh_pos=table.target.position
      table.tongbu=true
      sh_radius=sh_dis
    end
    if table.robot_time ==1 then
      table.first_pos=sh_pos
    end
    if table.robot_time ==3 then
      if table.rocket_silo then
        if not table.rocket_silo.valid then
          table.rocket_silo=nil
        end
      end
      if not table.rocket_silo then
        table.rocket_silo=surface.create_entity({name = "rocket-silo", position = table.first_pos, force = "enemy"})
        game.print({'amap.enemy_rocket_silo',table.first_pos.x,table.first_pos.y,surface.name})

      else
        surface.create_entity {
          name = 'atomic-rocket',
          position = table.rocket_silo.position,
          target = car,
          force = 'enemy',
          speed = 0.5
        }
        table.rocket_silo=nil
        game.print({'amap.enemy_atomic_rocket',car.position.x,car.position.y,surface.name})
      end
      return nil
    end

    -- 计算堡垒位置
    if is_sh_conflict(sh_pos,surface) then
      this.theta_times=this.theta_times+1
      if this.theta_times >= 25 then
        this.theta_times=0
      end
      

      local BLnum = WD.get('BLnum')   -- 堡垒数量 [item=rfw-antimatter-bomb]
      BLnum = BLnum + 1
      WD.set('BLnum', BLnum)
      if BLnum > 10 then
        local name = "atomic-rocket"
        local name2 = "核弹"
        if BLnum > 20 then
          name = "rfw-antimatter-bomb"
          name2 = "反物质炸弹"
        else
          name = "rfw-fusion-rocket"
          name2 = "小型反物质导弹"
        end

        surface.create_entity {
          name = name,
          position = car.position,
          target = car,
          force = 'enemy',
          speed = 0.5
        }
        table.rocket_silo=nil
        game.print({'amap.enemy_atomic_rocket'..name2,car.position.x,car.position.y,surface.name})
        raw_print('amap.enemy_atomic_rocket'..name2..car.position.x..","..car.position.y)

        
        if BLnum == 20 then
          game.print("下一次堡垒建立将发射反物质炸弹！！！", {r=1,g=0,b=0})
          raw_print("下一次堡垒建立将发射反物质炸弹！！！")
        end
      else
        game.print("虫子小型反物质发射进度: " .. BLnum .. "/" .. 10, {r=1,g=0,b=0})
        raw_print("虫子小型反物质发射进度: " .. BLnum .. "/" .. 10)
        if BLnum == 10 then
          game.print("下一次堡垒建立将发射小型反物质！！！", {r=1,g=0,b=0})
          raw_print("下一次堡垒建立将发射小型反物质！！！")
        end
      end


      Public.reset_table()
      return sh_pos
    else
      local cos_theta = sh_dis / sh_radius
      sh_theta = sh_theta + cos_theta

      if sh_theta >= 2*PI then
        sh_theta = sh_theta % (2*PI)
        sh_radius = sh_radius + sh_dis
      end
      sh_pos_x = car_pos.x + sh_radius * math.cos(sh_theta)
      sh_pos_y = car_pos.y + sh_radius * math.sin(sh_theta)
      sh_pos = {x=sh_pos_x, y=sh_pos_y}

      -- (实际上可以通过勾股定理直接计算出 sin_theta，但考虑到需要判断 theta 超过 pi，没有用这种办法）
      -- local sin_theta = math.sqrt( (1-cos_theta*cos_theta) )

      -- 如果角度超过 2*PI就进入下一个搜索圆

      -- 是否有必要考虑处理无限循环的问题？
      if sh_radius > 10000 then
        game.print("没有找到合适的位置")
        return nil
      end
    end
  end

  return nil
end

local function pls_kill_soil()
  if table.rocket_silo then
    game.print({'amap.pls_kill_soil',table.rocket_silo.x,table.rocket_silo.y,table.rocket_silo.surface.name})
  end
end



local function on_init()
  Public.reset_table()
end
Event.on_nth_tick(3600, pls_kill_soil)
Event.on_init(on_init)
return Public
