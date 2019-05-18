-- power/ctrl.lua

local me = microexpansion
local network = me.network

local function update_ctrl(pos)
	local cnetwork = me.get_network(pos)
	if cnetwork == nil then
		minetest.log("error","no network for ctrl at pos "..minetest.pos_to_string(pos))
		return
	end
	local size = cnetwork:get_item_capacity()
	local meta = minetest.get_meta(pos)
	local inv = meta:get_inventory()
	inv:set_size("main", me.int_to_stacks(size))
end

function me.insert_item(stack, inv, listname)
	if me.settings.huge_stacks == false then
		inv:add_item(listname, stack)
		return
	end
	local stack_name
	local stack_count
	if type(stack) == "string" then
		local split_string = stack:split(" ")
		stack_name = split_string[1]
		if (#split_string > 1) then
			stack_count = tonumber(split_string[2])
		else
			stack_count = 1
		end
	else
		stack_name = stack:get_name()
		stack_count = stack:get_count()
	end
	local found = false
	for i = 0, inv:get_size(listname) do
		local inside = inv:get_stack(listname, i)
		if inside:get_name() == stack_name then
			local total_count = inside:get_count() + stack_count
			-- bigger item count is not possible we only have unsigned 16 bit
			if total_count <= math.pow(2,16) then
				if not inside:set_count(total_count) then
					minetest.log("error"," adding items to stack in microexpansion network failed")
					print("stack is now " .. inside:to_string())
				end
				inv:set_stack(listname, i, inside)
				found = true
				break;
			end
		end
	end
	if not found then
		inv:add_item(listname, stack)
	end
end

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
	me_update = update_ctrl,
	after_place_node = function(pos, player)
		local name = player:get_player_name()
		local meta = minetest.get_meta(pos)
		table.insert(me.networks,network:new({controller_pos = pos}))
		me.update_connected_machines(pos)

		meta:set_string("infotext", "Network Controller (owned by "..name..")")
		meta:set_string("owner", name)
	end,
	on_destruct = function(pos)
		local net,idx = me.get_network(pos)
		if net then
			net.controller_pos = nil
		end
		if idx then
			table.remove(me.networks,idx)
		end
	end,
	after_dig_node = function(pos)
		me.update_connected_machines(pos)
	end,
	allow_metadata_inventory_put = function(pos, listname, index, stack)
		local inv = minetest.get_meta(pos):get_inventory()
		local inside_stack = inv:get_stack(listname, index)
		local stack_name = stack:get_name()
		-- improve performance by skipping unnessecary calls
		if inside_stack:get_name() ~= stack_name or inside_stack:get_count() >= inside_stack:get_stack_max()  then
			if inv:get_stack(listname, index+1):get_name() ~= "" then
				return stack:get_count()
			end
		end
		local max_slots = inv:get_size(listname)
		local max_items = math.floor(max_slots * 99)

		local slots, items = 0, 0
		-- Get amount of items in drive
		for i = 1, max_slots do
			local dstack = inv:get_stack("main", i)
			if dstack:get_name() ~= "" then
				slots = slots + 1
				local num = dstack:get_count()
				if num == 0 then num = 1 end
				items = items + num
			end
		end
		return math.max(math.min(stack:get_count(),max_items-items),0)
	end,
	on_metadata_inventory_put = function(pos, listname, _, stack)
		local inv = minetest.get_meta(pos):get_inventory()
		inv:remove_item(listname, stack)
		me.insert_item(stack, inv, listname)
	end,
	allow_metadata_inventory_take = function(_, _, _, stack)
		return math.min(stack:get_count(),stack:get_stack_max())
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
	machine = {
		type = "transporter",
	},
})
