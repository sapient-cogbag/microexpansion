-- microexpansion/machines.lua

local me = microexpansion

-- [me chest] Get formspec
local function chest_formspec(pos, start_id, listname, page_max, q)
	local list
	local page_number = ""
	local buttons = ""
	local query = q or ""
	local net,cp = me.get_connected_network(pos)

	if cp then
		if listname and net:get_item_capacity() > 0 then
		  local ctrlinvname = net:get_inventory_name()
			if listname == "main" then
				list = "list[detached:"..ctrlinvname..";"
				  .. listname .. ";0,0.3;8,4;" .. (start_id - 1) .. "]"
			else
				list = "list[context;" .. listname .. ";0,0.3;8,4;" .. (start_id - 1) .. "]"
			end
			list = list .. [[
				list[current_player;main;0,5.5;8,1;]
				list[current_player;main;0,6.73;8,3;8]
				listring[detached:]]..ctrlinvname..[[;main]
				listring[current_player;main]
			]]
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
		else
			list = "label[3,2;" .. minetest.colorize("red", "No connected drives!") .. "]"
		end
	else
		list = "label[3,2;" .. minetest.colorize("red", "No connected network!") .. "]"
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
		label[0,-0.23;ME Terminal]
		field_close_on_enter[filter;false]
	]]..
		page_number ..
		buttons
end

local function update_chest(pos)
	local network = me.get_connected_network(pos)
	local meta = minetest.get_meta(pos)
	if network == nil then
		meta:set_int("page", 1)
		meta:set_string("formspec", chest_formspec(pos, 1))
		return
	end
	local size = network:get_item_capacity()
	local page_max = me.int_to_pagenum(size) + 1

	meta:set_string("inv_name", "main")
	meta:set_string("formspec", chest_formspec(pos, 1, "main", page_max))
end

--FIXME: items inserted in a search inventory vanish
--TODO: add a main inv that transfers to the network

-- [me chest] Register node
microexpansion.register_node("term", {
	description = "ME Terminal",
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
	on_metadata_inventory_take = function(pos, listname, _, stack)
		if listname == "search" then
			local net = me.get_connected_network(pos)
			local inv = net:get_inventory()
			inv:remove_item("main", stack)
		end
	end,
	on_receive_fields = function(pos, _, fields, sender)
		local net,cp = me.get_connected_network(pos)
		if net then
		  if cp then
		    minetest.log("none","network and ctrl_pos")
	    else
	     minetest.log("warning","network but no ctrl_pos")
		  end
		else
		  if cp then
		    minetest.log("warning","no network but ctrl_pos")
		  else
		    minetest.log("info","no network and no ctrl_pos")
		  end
		end
		local meta = minetest.get_meta(pos)
		local page = meta:get_int("page")
		local inv_name = meta:get_string("inv_name")
		local own_inv = meta:get_inventory()
		local ctrl_inv
		if cp then
			ctrl_inv = net:get_inventory()
		else
		  minetest.log("warning","no network connected")
		  return
		end
		local inv
		if inv_name == "main" then
			inv = ctrl_inv
			assert(inv,"no control inv")
		else
			inv = own_inv
			assert(inv,"no own inv")
		end
		local page_max = math.floor(inv:get_size(inv_name) / 32) + 1
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
			own_inv:set_size("search", 0)
			if fields.filter == "" then
				meta:set_int("page", 1)
				meta:set_string("inv_name", "main")
				meta:set_string("formspec", chest_formspec(pos, 1, "main", page_max))
			else
				local tab = {}
				for i = 1, ctrl_inv:get_size("main") do
					local match = ctrl_inv:get_stack("main", i):get_name():find(fields.filter)
					if match then
						tab[#tab + 1] = ctrl_inv:get_stack("main", i)
					end
				end
				own_inv:set_list("search", tab)
				meta:set_int("page", 1)
				meta:set_string("inv_name", "search")
				meta:set_string("formspec", chest_formspec(pos, 1, "search", page_max, fields.filter))
			end
		elseif fields.clear then
			own_inv:set_size("search", 0)
			meta:set_int("page", 1)
			meta:set_string("inv_name", "main")
			meta:set_string("formspec", chest_formspec(pos, 1, "main", page_max))
		elseif fields.tochest then
			local pinv = minetest.get_inventory({type="player", name=sender:get_player_name()})
			net:add_storage_slots(pinv:get_size("main"))
			microexpansion.move_inv({ inv=pinv, name="main" }, { inv=ctrl_inv, name="main" })
			net:add_storage_slots(true)
		end
	end,
})
