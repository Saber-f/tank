local Event = require("utils.event")
local WPT = require 'maps.amap.table'

local count = {}

local ammo={}
ammo={
  -- {name='shotgun-shell'},           -- 标准
  -- {name='piercing-shotgun-shell'},  -- 穿甲
  -- {name='rfw-uranium-shotgun-shell'},
  -- {name='uranium-shotgun-ammo-rampant-arsenal'},
  -- {name='incendiary-shotgun-ammo-rampant-arsenal'},
  -- {name='bio-shotgun-ammo-rampant-arsenal'},
  -- {name='he-shotgun-ammo-rampant-arsenal'},
  -- {name='rfw-fusion-shotgun-shell'},
  -- {name='rfw-antimatter-shotgun-shell'},


  {name='firearm-magazine'},         -- 标准
  {name='piercing-rounds-magazine'}, -- 穿甲
  {name='uranium-rounds-magazine'},
  -- {name='incendiary-magazine-ammo-rampant-arsenal'},
  -- {name='bio-magazine-ammo-rampant-arsenal'},
  -- {name='he-magazine-ammo-rampant-arsenal'},
  {name='rfw-fusion-rounds-magazine'},
  {name='rfw-antimatter-rounds-magazine'},

  --[[
  [9]={name='rifle-magazine'},
  [10]={name='armor-piercing-rifle-magazine'},
  [11]={name='uranium-rifle-magazine'},
  [12]={name='imersite-rifle-magazine'},


  -- [9]={name='shotgun-shell'},
  -- [10]={name='piercing-shotgun-shell'},
  -- [11]={name='bio-shotgun-ammo-rampant-arsenal'},
  -- [12]={name='incendiary-shotgun-ammo-rampant-arsenal'},
  -- [13]={name='rfw-uranium-shotgun-shell'},
  -- [14]={name='w93-uranium-shotgun-shell'},
  -- [15]={name='uranium-shotgun-ammo-rampant-arsenal'},
  -- [16]={name='rfw-fusion-shotgun-shell'},
  -- [17]={name='rfw-antimatter-shotgun-shell'},

  
  [18]={name='cannon-shell'},
  [19]={name='explosive-cannon-shell'},
  [20]={name='bio-cannon-shell-ammo-rampant-arsenal'},
  [21]={name='he-cannon-shell-ammo-rampant-arsenal'},
  [22]={name='incendiary-cannon-shell-ammo-rampant-arsenal'},
  [23]={name='uranium-cannon-shell'},
  [24]={name='explosive-uranium-cannon-shell'},
  [25]={name='rfw-fusion-cannon-shell'},
  [26]={name='rfw-antimatter-cannon-shell'},

  [27]={name='artillery-shell'},
  [28]={name='bio-artillery-ammo-rampant-arsenal'},
  [29]={name='he-artillery-ammo-rampant-arsenal'},
  [30]={name='incendiary-artillery-ammo-rampant-arsenal'},
  [31]={name='nuclear-artillery-ammo-rampant-arsenal'},
  [32]={name='rfw-fission-artillery-shell'},
  [33]={name='rfw-thermonuclear-artillery-shell'},
  [34]={name='rfw-fusion-artillery-shell'},
  [35]={name='rfw-fusion-artillery-shell'},

  [36]={name=''},
  [37]={name=''},
  [38]={name=''},
  [39]={name=''},
  [40]={name=''},
  [41]={name=''},
  [42]={name=''},
  [43]={name=''},
  [44]={name=''},
  [45]={name=''},
  [46]={name=''},
  [47]={name=''},
  [48]={name=''},
  [49]={name=''},
  [50]={name=''},
  [51]={name=''},]]--
}

local on_built_entity = function (event)
  if not event.created_entity then return end
  if not event.created_entity.valid then return end
  if event.created_entity.type ~= "ammo-turret" then return  end
  local this=WPT.get()
  local player = game.get_player(event.player_index)
  local index=player.index
  if not this.tank[index] then return end
  local magzine_count = 20
  if global.AmmoCount then
    magzine_count = global.AmmoCount
  end
  if not(event.item == nil) then
    for i=1,#ammo do
      local ammoInYourBag = player.get_item_count(ammo[#ammo-i+1].name)
      if ammoInYourBag ~= 0 then
        if ammoInYourBag >= magzine_count then
          event.created_entity.insert{name = ammo[#ammo-i+1].name,count = magzine_count}
          player.remove_item{name = ammo[#ammo-i+1].name,count = magzine_count}
          goto workflow
        end
      end
    end
    ::workflow::
  end
end


Event.add(defines.events.on_built_entity,on_built_entity)
