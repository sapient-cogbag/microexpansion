-- power/ctrl.lua

local me = microexpansion
local network = me.network

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
	me_update = function(pos)
    local cnet = me.get_network(pos)
    if cnet == nil then
      minetest.log("error","no network for ctrl at pos "..minetest.pos_to_string(pos))
      return
    end
    cnet:update()
  end,
	after_place_node = function(pos, player)
		local name = player:get_player_name()
		local meta = minetest.get_meta(pos)
		table.insert(me.networks,network.new({controller_pos = pos}))
		me.update_connected_machines(pos)

		meta:set_string("infotext", "Network Controller (owned by "..name..")")
		meta:set_string("owner", name)
	end,
	on_destruct = function(pos)
		local net,idx = me.get_network(pos)
		if net then
			net:destruct()
		end
		if idx then
			table.remove(me.networks,idx)
		end
		me.update_connected_machines(pos)
	end,
	after_dig_node = function(pos)
	  me.update_connected_machines(pos)
	end,
	machine = {
		type = "transporter",
	},
})

-- [register node] Cable
me.register_machine("cable", {
	description = "ME Cable",
	tiles = {
		"cable",
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
	after_place_node = me.update_connected_machines,
	after_dig_node = me.update_connected_machines,
	me_update = function(pos)
	 local meta = minetest.get_meta(pos)
	 if me.get_connected_network(pos) then
    meta:set_string("infotext", "Network connected")
   else
    meta:set_string("infotext", "No Network")
	 end
	end,
	machine = {
		type = "transporter",
	},
})
