-- power/ctrl.lua

local me = microexpansion
local network = me.network

--FIXME: accept multiple controllers in one network

-- [register node] Controller
me.register_node("ctrl", {
	description = "ME Controller",
	tiles = {
		"ctrl_sides",
		"ctrl_bottom",
		"ctrl_sides",
		"ctrl_sides",
		"ctrl_sides",
		"ctrl_sides"
	},
	recipe = {
    { 1, {
        {"default:steel_ingot", "microexpansion:steel_infused_obsidian_ingot", "default:steel_ingot"},
        {"default:steel_ingot",       "microexpansion:machine_casing",         "default:steel_ingot"},
        {"default:steel_ingot",             "microexpansion:cable",            "default:steel_ingot"},
      },
    }
  },
	drawtype = "nodebox",
	paramtype = "light",
	node_box = {
		type = "fixed",
		fixed = {
			{-0.375, -0.375, -0.375, 0.375, 0.375, 0.375}, -- Core
			{0.1875, -0.5, -0.5, 0.5, 0.5, -0.1875}, -- Corner1
			{-0.5, -0.5, -0.5, -0.1875, 0.5, -0.1875}, -- Corner2
			{-0.5, -0.5, 0.1875, -0.1875, 0.5, 0.5}, -- Corner3
			{0.1875, -0.5, 0.1875, 0.5, 0.5, 0.5}, -- Corner4
			{-0.5, -0.4375, -0.5, 0.5, -0.1875, 0.5}, -- Bottom
			{-0.5, 0.1875, -0.5, 0.5, 0.5, -0.1875}, -- Top1
			{0.1875, 0.1875, -0.5, 0.5, 0.5, 0.5}, -- Top2
			{-0.5, 0.1875, -0.5, -0.1875, 0.5, 0.5}, -- Top3
			{-0.5, 0.1875, 0.1875, 0.5, 0.5, 0.5}, -- Top4
			{-0.1875, -0.5, -0.1875, 0.1875, -0.25, 0.1875}, -- Bottom2
		},
	},
	groups = { cracky = 1, me_connect = 1, },
	connect_sides = "nobottom",
	me_update = function(pos,_,ev)
    local cnet = me.get_network(pos)
    if cnet == nil then
      minetest.log("error","no network for ctrl at pos "..minetest.pos_to_string(pos))
      return
    end
    cnet:update()
  end,
  on_construct = function(pos)
    local meta = minetest.get_meta(pos)
    local net = network.new({controller_pos = pos})
    table.insert(me.networks,net)
    me.send_event(pos,"connect",{net=net})

    meta:set_string("infotext", "Network Controller")
  end,
	after_place_node = function(pos, player)
		local name = player:get_player_name()
		local meta = minetest.get_meta(pos)
		meta:set_string("infotext", "Network Controller (owned by "..name..")")
		meta:set_string("owner", name)
	end,
	on_destruct = function(pos)
    local net = me.get_network(pos)
    local net,idx = me.get_network(pos)
    --disconnect all those who need the network
    me.send_event(pos,"disconnect",{net=net})
    if net then
      net:destruct()
    end
    if idx then
      table.remove(me.networks,idx)
    end
    --disconnect all those that haven't realized the network is gone
    me.send_event(pos,"disconnect")
	end,
	after_destruct = function(pos)
    --disconnect all those that haven't realized the controller was disconnected
    me.send_event(pos,"disconnect")
	end,
	machine = {
		type = "controller",
	},
})

-- [register node] Cable
me.register_machine("cable", {
	description = "ME Cable",
	tiles = {
		"cable",
	},
	recipe = {
    { 12, "shapeless", {
        "microexpansion:steel_infused_obsidian_ingot", "microexpansion:machine_casing"
      },
    }
  },
	drawtype = "nodebox",
	node_box = {
		type = "connected",
		fixed          = {-0.25, -0.25, -0.25, 0.25,  0.25, 0.25},
		connect_top    = {-0.25, -0.25, -0.25, 0.25,  0.5,  0.25}, -- y+
		connect_bottom = {-0.25, -0.5,  -0.25, 0.25,  0.25, 0.25}, -- y-
		connect_front  = {-0.25, -0.25, -0.5,  0.25,  0.25, 0.25}, -- z-
		connect_back   = {-0.25, -0.25,  0.25, 0.25,  0.25, 0.5 }, -- z+
		connect_left   = {-0.5,  -0.25, -0.25, 0.25,  0.25, 0.25}, -- x-
		connect_right  = {-0.25, -0.25, -0.25, 0.5,   0.25, 0.25}, -- x+
	},
	paramtype = "light",
	groups = { crumbly = 1, },
	--TODO: move these functions into the registration
	on_construct = function(pos)
	 me.send_event(pos,"connect")
	end,
	after_destruct = function(pos)
	 me.send_event(pos,"disconnect")
	end,
	me_update = function(pos,_,ev)
	 if ev then
	   if ev.type ~= "disconnect" then return end
	 end
	 --maybe this shouldn't be called on every update
	 local meta = minetest.get_meta(pos)
	 if me.get_connected_network(pos) then
    meta:set_string("infotext", "Network connected")
   else
    meta:set_string("infotext", "No Network")
	 end
	end,
	machine = {
		type = "conductor",
	},
})
