-- microexpansion/machines.lua

local me = microexpansion

local function update_drive(pos)
	--FIXME: check if we got connected/disconnected and reroute items
end

local function write_to_cell(cell, items, item_count)
	local size = microexpansion.get_cell_size(cell:get_name())
	local item_meta = cell:get_meta()
	item_meta:set_string("items", minetest.serialize(items))
	local base_desc = minetest.registered_craftitems[cell:get_name()].microexpansion.base_desc
	-- Calculate Percentage
	local percent = math.floor(item_count / size * 100)
	-- Update description
	item_meta:set_string("description", base_desc.."\n"..
		minetest.colorize("grey", tostring(item_count).."/"..tostring(size).." Items ("..tostring(percent).."%)"))
	return cell
end

-- [me chest] Register node
microexpansion.register_node("drive", {
	description = "ME Drive",
	usedfor = "Stores items into ME storage cells",
	tiles = {
		"chest_top",
		"chest_top",
		"chest_side",
		"chest_side",
		"chest_side",
		"drive_full",
	},
	is_ground_content = false,
	groups = { cracky = 1, me_connect = 1 },
	paramtype = "light",
	paramtype2 = "facedir",
	me_update = update_drive,
	on_construct = function(pos)
		local meta = minetest.get_meta(pos)
		meta:set_string("formspec",
			"size[9,9.5]"..
			microexpansion.gui_bg ..
			microexpansion.gui_slots ..
		[[
			label[0,-0.23;ME Drive]
			list[context;main;0,0.3;8,4]
			list[current_player;main;0,5.5;8,1;]
			list[current_player;main;0,6.73;8,3;8]
			listring[current_name;main]
			listring[current_player;main]
			field_close_on_enter[filter;false]
		]])
		local inv = meta:get_inventory()
		inv:set_size("main", 10)
	end,
	can_dig = function(pos)
		local meta = minetest.get_meta(pos)
		local inv = meta:get_inventory()
		return inv:is_empty("main")
	end,
	allow_metadata_inventory_put = function(_, _, _, stack)
		if minetest.get_item_group(stack:get_name(), "microexpansion_cell") ~= 0 then
			return 1
		else
			return 0
		end
	end,
	on_metadata_inventory_put = function(pos, _, _, stack)
		me.update_connected_machines(pos)
		local network,cp = me.get_connected_network(pos)
		if network == nil then
			return
		end
		local ctrl_meta = minetest.get_meta(cp)
		local ctrl_inv = ctrl_meta:get_inventory()
		local items = minetest.deserialize(stack:get_meta():get_string("items"))
		if items == nil then
			print("no items")
			me.update_connected_machines(pos)
			return
		end
		for _,s in pairs(items) do
			me.insert_item(s, ctrl_inv, "main")
		end
		me.update_connected_machines(pos)
	end,
	allow_metadata_inventory_take = function(pos,_,_,stack) --args: pos, listname, index, stack, player
		--FIXME sometimes items vanish if one cell is filled
		local meta = minetest.get_meta(pos)
		local own_inv = meta:get_inventory()
		local network,cp = me.get_connected_network(pos)
		if network == nil then
			return stack:get_count()
		end
		local ctrl_meta = minetest.get_meta(cp)
		local ctrl_inv = ctrl_meta:get_inventory()
		local cells = {}
		for i = 1, own_inv:get_size("main") do
			local cell = own_inv:get_stack("main", i)
			local name = cell:get_name()
			if name ~= "" then
				table.insert(cells, i, cell)
			end
		end
		local cell_idx = next(cells)
		local items_in_cell_count = 0
		local cell_items = {}
		if cell_idx == nil then
			minetest.log("warning","too many items to store in drive")
			return stack:get_count()
		end

		for i = 1, ctrl_inv:get_size("main") do
			local stack_inside = ctrl_inv:get_stack("main", i)
			local stack_name = stack_inside:get_name()
			if stack_name ~= "" then
				local item_count = stack_inside:get_count()
				while item_count ~= 0 and cell_idx ~= nil do
					local size = microexpansion.get_cell_size(cells[cell_idx]:get_name())
					if size < items_in_cell_count + item_count then
						local rest = size - items_in_cell_count
						item_count = item_count - rest
						table.insert(cell_items,stack_name.." "..rest)
						items_in_cell_count = items_in_cell_count + rest

						own_inv:set_stack("main", cell_idx, write_to_cell(cells[cell_idx],cell_items,items_in_cell_count))
						items_in_cell_count = 0
						cell_items = {}
						cell_idx = next(cells, cell_idx)
						if cell_idx == nil then
							minetest.log("info","too many items to store in drive")
						end
					else
						items_in_cell_count = items_in_cell_count + item_count
						table.insert(cell_items,stack_inside:to_string())
						item_count = 0
					end
				end
			end
			if cell_idx == nil then
				break
			end
		end
		while cell_idx ~= nil do
			own_inv:set_stack("main", cell_idx, write_to_cell(cells[cell_idx],cell_items,items_in_cell_count))
			items_in_cell_count = 0
			cell_items = {}
			cell_idx = next(cells, cell_idx)
		end

		return stack:get_count()
	end,
	on_metadata_inventory_take = function(pos, _, _, stack)
		local network,cp = me.get_connected_network(pos)
		if network == nil then
			return
		end
		local ctrl_meta = minetest.get_meta(cp)
		local ctrl_inv = ctrl_meta:get_inventory()
		local items = minetest.deserialize(stack:get_meta():get_string("items"))
		if items == nil then
			me.update_connected_machines(pos)
			return
		end
		for _,ostack in pairs(items) do
			--this returns 99 (max count) even if it removes more
			ctrl_inv:remove_item("main", ostack)
		end
		print(stack:to_string())

		me.update_connected_machines(pos)
	end,
})
