local Global = require 'utils.global'
local surface_name = 'amap'
local Reset = require 'maps.amap.soft_reset'
local diff=require 'maps.amap.diff'

local Public = {}

local this = {
    active_surface_index = nil,
    surface_name = surface_name,
}

Global.register(
    this,
    function(tbl)
        this = tbl
    end
)

local starting_items = {
  ['grappling-gun'] = 1,
  ['grappling-gun-ammo'] = 200,
  ['wood'] = 200,
  ['car']=1,

}

function Public.create_surface()
  local map=diff.get()
  local cave_autoplace_controls={
        ["coal"] = {frequency = "2", size = "1", richness = "0.7"},
  			-- ["stone"] = {frequency = "0", size = "0", richness = "0.7"},
  			-- ["copper-ore"] = {frequency = "2", size = "2",richness = "0.7"},
  			["iron-ore"] = {frequency ="2", size = "2", richness = "0.7"},
        ["uranium-ore"] = {frequency ="2", size = "2", richness = "0.7"},
  			["crude-oil"] = {frequency = "3", size = "2", richness = "1.2"},
  			["trees"] = {frequency = "1", size = "0.7", richness = "0.7"},
  			["enemy-base"] = {frequency = "3", size = "2", richness = "1"},

  }
  local quarter_autoplace_controls={
        ["coal"] = {frequency = "1", size = "1",richness = "0.7"},
        -- ["stone"] = {frequency = "0", size = "0", richness = "0.7"},
        -- ["copper-ore"] = {frequency = "1", size = "2",richness = "0.7"},
        ["iron-ore"] = {frequency ="1", size = "2", richness = "0.7"},
        ["uranium-ore"] = {frequency ="1.4", size = "2", richness = "1"},
        ["crude-oil"] = {frequency = "2", size = "2", richness = "1.2"},
        ["trees"] = {frequency = "1", size = "0.7", richness = "0.7"},
      	["enemy-base"] = {frequency = "3", size = "2", richness = "1"},


  }
  local water_autoplace_controls={
    ["coal"] = {frequency = "2", size = "1", richness = "0.7"},
    -- ["stone"] = {frequency = "0", size = "0", richness = "0.7"},
    -- ["copper-ore"] = {frequency = "2", size = "2",richness = "0.7"},
    ["iron-ore"] = {frequency ="2", size = "2", richness = "0.7"},
    ["uranium-ore"] = {frequency ="2", size = "2", richness = "0.7"},
    ["crude-oil"] = {frequency = "3", size = "2", richness = "1.2"},
    ["trees"] = {frequency = "1", size = "0.7", richness = "0.7"},
    ["enemy-base"] = {frequency = "3", size = "2", richness = "1"},


  }
  local all_tree_autoplace_controls={
    ["coal"] = {frequency = "2", size = "1", richness = "0.7"},
    -- ["stone"] = {frequency = "0", size = "0", richness = "0.7"},
    -- ["copper-ore"] = {frequency = "2", size = "2",richness = "0.7"},
    -- ["iron-ore"] = {frequency ="2", size = "2", richness = "0.7"},
    ["uranium-ore"] = {frequency ="2", size = "2", richness = "0.7"},
    ["crude-oil"] = {frequency = "3", size = "2", richness = "1.2"},
    ["trees"] = {frequency = "2", size = "2", richness = "1"},
    ["enemy-base"] = {frequency = "3", size = "3", richness = "2"},


  }
  -- local all_biter_autoplace_controls={
  --   ["coal"] = {frequency = "10", size = "10", richness = "5"},
  --   ["stone"] = {frequency = "10", size = "10", richness = "5"},
  --   ["copper-ore"] = {frequency = "10", size = "10", richness = "5"},
  --   ["iron-ore"] ={frequency = "10", size = "10", richness = "5"},
  --   ["uranium-ore"] = {frequency = "10", size = "10", richness = "5"},
  --   ["crude-oil"] ={frequency = "10", size = "10", richness = "5"},
  --   ["trees"] = {frequency = "1", size = "1", richness = "1"},
  --   ["enemy-base"] = {frequency = "10", size = "10", richness = "2"},
  --
  -- }
  local winter_autoplace_controls={
    ["coal"] = {frequency = "2", size = "1", richness = "0.7"},
    -- ["stone"] = {frequency = "0", size = "0", richness = "0.7"},
    -- ["copper-ore"] = {frequency = "2", size = "2",richness = "0.7"},
    -- ["iron-ore"] = {frequency ="2", size = "2", richness = "0.7"},
    ["uranium-ore"] = {frequency ="2", size = "2", richness = "0.7"},
    ["crude-oil"] = {frequency = "3", size = "2", richness = "1.2"},
    ["trees"] = {frequency = "1", size = "0.7", richness = "0.7"},
  	["enemy-base"] = {frequency = "3", size = "2", richness = "1"},
  }

  local no_ore_autoplace_controls={
    ["coal"] = {frequency = "0", size = "0", richness = "1"},
    -- ["stone"] = {frequency = "0", size = "0", richness = "1"},
    -- ["copper-ore"] = {frequency = "0", size = "0",richness = "1"},
    -- ["iron-ore"] = {frequency ="0", size = "0", richness = "1"},
    ["uranium-ore"] = {frequency ="1.7", size = "2", richness = "0.7"},
    ["crude-oil"] = {frequency = "2", size = "2", richness = "1.2"},
    ["trees"] = {frequency = "1", size = "0.7", richness = "0.7"},
    ["enemy-base"] = {frequency = "3", size = "2", richness = "1"},
  }
  local world_autoplace_controls={
     [1]=cave_autoplace_controls,
     [2]=quarter_autoplace_controls,
     [3]=water_autoplace_controls,
     [4]=all_tree_autoplace_controls,
     [5]=winter_autoplace_controls,
     --[6]=winter_autoplace_controls,
  }

        local map_gen_settings = game.surfaces["nauvis"].map_gen_settings
        map_gen_settings.seed = math.random(1, 4294967295)
        -- map_gen_settings.tarting_area = 1.4
        map_gen_settings.default_enable_all_autoplace_controls = true
          
    -- if map.world==2 then
    --   map_gen_settings.water=0
    -- end

    -- if map.world==2 or map.world==3 then
    --   map_gen_settings.starting_area=0.8
    -- end

    -- if map.world==4 then
    --   map_gen_settings.water = 0
    --  map_gen_settings.cliff_settings = {cliff_elevation_interval = 10, cliff_elevation_0 = 10}
    --   map_gen_settings.moisture = 1

    -- end

    -- game.pollution.enabled = false

    if not global.MapWidth then
      global.MapWidth = 20000
    end
    map_gen_settings.width= global.MapWidth 

    if not global.MapHeight then
      global.MapHeight = 20000
    end
    map_gen_settings.height= global.MapHeight

    -- 禁用污染
    game.map_settings.pollution.enabled = false

    -- 禁用虫巢
    game.map_settings.enemy_expansion.enabled = false

	-- map_gen_settings.autoplace_controls =world_autoplace_controls[map.world]   -- 天使报错
    if not this.active_surface_index then
        this.active_surface_index = game.create_surface(surface_name, map_gen_settings).index
    else
        this.active_surface_index = Reset.soft_reset_map(game.surfaces[this.active_surface_index], map_gen_settings, starting_items).index
    end

-- local mgs = game.surfaces['amap'].map_gen_settings
-- game.print(mgs.cliff_settings.cliff_elevation_interval)
-- game.print(mgs.cliff_settings.cliff_elevation_0)


    if not this.cleared_nauvis then
        local mgs = game.surfaces['nauvis'].map_gen_settings
        mgs.width = 1
        mgs.height = 1
        game.surfaces['nauvis'].map_gen_settings = mgs
        --game.surfaces['nauvis'].clear()
        this.cleared_nauvis = true
    end
--local size = game.surfaces[this.active_surface_index].map_gen_settings
  --  size.width = 512
   -- size.height = 512
    --game.surfaces[this.active_surface_index].map_gen_settings = size
    return this.active_surface_index
end

function Public.get_active_surface()
    return this.active_surface
end

function Public.get_surface_name()
    return this.surface_name
end

function Public.get(key)
    if key then
        return this[key]
    else
        return this
    end
end

return Public
