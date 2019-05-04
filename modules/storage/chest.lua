-- microexpansion/machines.lua

local me = microexpansion

-- [me chest] Get formspec
local function chest_formspec(pos, start_id, listname, page_max, query)
	local list
	local page_number = ""
	local buttons = ""
	local query = query or ""

	if not listname then
		list = "label[3,2;" .. minetest.colorize("red", "No drive!") .. "]"
	else
		list = "list[current_name;" .. listname .. ";0,0.3;8,4;" .. (start_id - 1) .. "]"
		buttons = [[
			button[3.56,4.35;1.8,0.9;tochest;To Drive]
			tooltip[tochest;Move everything from your inventory to the ME network.]
			button[5.4,4.35;0.8,0.9;prev;<]
			button[7.25,4.35;0.8,0.9;next;>]
			tooltip[prev;Previous]
			tooltip[next;Next]
			field[0.29,4.6;2.2,1;filter;;]]..query..[[]
			button[2.1,4.5;0.8,0.5;search;?]
			button[2.75,4.5;0.8,0.5;clear;X]
			tooltip[search;Search]
			tooltip[clear;Reset]
		]]
	end
	if page_max then
		page_number = "label[6.15,4.5;" .. math.floor((start_id / 32)) + 1 ..
			"/" .. page_max .."]"
	end

	return [[
		size[9,9.5]
	]]..
		microexpansion.gui_bg ..
		microexpansion.gui_slots ..
		list ..
	[[
		label[0,-0.23;ME Chest]
		list[current_player;main;0,5.5;8,1;]
		list[current_player;main;0,6.73;8,3;8]
		listring[current_name;main]
		listring[current_player;main]
		field_close_on_enter[filter;false]
	]]..
		page_number ..
		buttons
end

local function update_chest(pos)
	local network = me.get_connected_network(pos)
	local meta = minetest.get_meta(pos)
	local inv = meta:get_inventory()
	if network == nil then
		inv:set_size("main", 0)
		meta:set_int("page", 1)
		meta:set_string("formspec", chest_formspec(pos, 1))
		return
	end
	local items = network.items
	local size = network.item_capacity
	local page_max = me.int_to_pagenum(size) + 1
	inv:set_size("main", me.int_to_stacks(size))
	if items then
		inv:set_list("main", items)
	end
	meta:set_string("inv_name", "main")
	meta:set_string("formspec", chest_formspec(pos, 1, "main", page_max))
end

-- [me chest] Register node
microexpansion.register_node("chest", {
	description = "ME Chest",
	usedfor = "Can interact with storage cells in ME networks",
	tiles = {
		"chest_top",
		"chest_top",
		"chest_side",
		"chest_side",
		"chest_side",
		"chest_front",
	},
	is_ground_content = false,
	groups = { cracky = 1, me_connect = 1 },
	paramtype = "light",
	paramtype2 = "facedir",
	me_update = update_chest,
	on_construct = function(pos)
		local meta = minetest.get_meta(pos)
		meta:set_string("formspec", chest_formspec(pos, 1))
		meta:set_string("inv_name", "none")
		meta:set_int("page", 1)
		local net = me.get_connected_network(pos)
		if net then
			update_chest(pos)
		end
	end,
	can_dig = function(pos, player)
		local meta = minetest.get_meta(pos)
		local inv = meta:get_inventory()
		return inv:is_empty("main")
	end,
	allow_metadata_inventory_put = function(pos, listname, index, stack, player)
		if listname == "main" then
			local inv = minetest.get_meta(pos):get_inventory()
			local max_slots = inv:get_size(listname)
			local max_items = math.floor(max_slots * 99)

			local slots, items = 0, 0
			-- Get amount of items in drive
			for i = 1, max_items do
				local stack = inv:get_stack("main", i)
				local item = stack:get_name()
				if item ~= "" then
					slots = slots + 1
					local num = stack:get_count()
					if num == 0 then num = 1 end
					items = items + num
				end
			end

			return math.min(stack:get_count(),max_items-items)
		else
			return 0
		end
	end,
	on_metadata_inventory_put = function(pos, listname, index, stack, player)
		if listname == "main" then
			local inv = minetest.get_meta(pos):get_inventory()
			inv:remove_item(listname, stack)
			local stackname = stack:get_name()
			local found = false
			for i = 0, inv:get_size(listname) do
				local inside = inv:get_stack(listname, i)
				if inside:get_name() == stackname then
					inside:set_count(inside:get_count() + stack:get_count())
					inv:set_stack(listname, i, inside)
					found = true
					break;
				end
			end
			if not found then
				inv:add_item(listname, stack)
			end
			local network = me.get_connected_network(pos)
			network.items = inv:get_list("main")
			me.update_connected_machines(pos)
		end
	end,
	allow_metadata_inventory_take = function(pos, listname, index, stack, player)
		return math.min(stack:get_count(),stack:get_stack_max())
	end,
	on_metadata_inventory_take = function(pos, listname, index, stack, player)
		local inv = minetest.get_meta(pos):get_inventory()
		if listname == "search" then
			inv:remove_item("main", stack)
		end
		local network = me.get_connected_network(pos)
		network.items = inv:get_list("main")
		me.update_connected_machines(pos)
	end,
	on_receive_fields = function(pos, formname, fields, sender)
		local meta = minetest.get_meta(pos)
		local page = meta:get_int("page")
		local inv_name = meta:get_string("inv_name")
		local inv = meta:get_inventory()
		local page_max = math.floor(inv:get_size("main") / 32) + 1
		local network = me.get_connected_network(pos)
		if inv_name == "none" then
			return
		end
		if fields.next then
			if page + 32 > inv:get_size(inv_name) then
				return
			end
			meta:set_int("page", page + 32)
			meta:set_string("formspec", chest_formspec(pos, page + 32, inv_name, page_max))
		elseif fields.prev then
			if page - 32 < 1 then
				return
			end
			meta:set_int("page", page - 32)
			meta:set_string("formspec", chest_formspec(pos, page - 32, inv_name, page_max))
		elseif fields.search or fields.key_enter_field == "filter" then
			inv:set_size("search", 0)
			if fields.filter == "" then
				meta:set_int("page", 1)
				meta:set_string("inv_name", "main")
				meta:set_string("formspec", chest_formspec(pos, 1, "main", page_max))
			else
				local tab = {}
				for i = 1, inv:get_size("main") do
					local match = inv:get_stack("main", i):get_name():find(fields.filter)
					if match then
						tab[#tab + 1] = inv:get_stack("main", i)
					end
				end
				inv:set_list("search", tab)
				meta:set_int("page", 1)
				meta:set_string("inv_name", "search")
				meta:set_string("formspec", chest_formspec(pos, 1, "search", page_max, fields.filter))
			end
		elseif fields.clear then
			inv:set_size("search", 0)
			meta:set_int("page", 1)
			meta:set_string("inv_name", "main")
			meta:set_string("formspec", chest_formspec(pos, 1, "main", page_max))
		elseif fields.tochest then
			local pinv = minetest.get_inventory({type="player", name=sender:get_player_name()})
			microexpansion.move_inv({ inv=pinv, name="main" }, { inv=inv, name="main" })
		end
	end,
})
