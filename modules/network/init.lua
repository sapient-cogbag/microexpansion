local me       = microexpansion
me.networks    = {}
local networks = me.networks
local path     = microexpansion.get_module_path("network")

local function split_stack_values(stack)
  local stack_name, stack_count, stack_meta
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
    stack_meta = stack:get_meta()
  end
  return stack_name, stack_count, stack_meta
end

function me.insert_item(stack, inv, listname)
  if me.settings.huge_stacks == false then
    return inv:add_item(listname, stack)
  end
  local stack_name,stack_count,stack_meta = split_stack_values(stack)
  local found = false
  for i = 0, inv:get_size(listname) do
    local inside = inv:get_stack(listname, i)
    if inside:get_name() == stack_name then
      if inside:get_meta():equals(stack_meta) then
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
  end
  if not found then
    return inv:add_item(listname, stack)
  end
end

dofile(path.."/network.lua") -- Network Management

-- generate iterator to find all connected nodes
function me.connected_nodes(start_pos,include_ctrl)
	-- nodes to be checked
	local open_list = {{pos = start_pos}}
	-- nodes that were checked
	local closed_set = {}
	-- local connected nodes function to reduce table lookups
	local adjacent_connected_nodes = me.network.adjacent_connected_nodes
	-- return the generated iterator
	return function ()
		-- start looking for next pos
		local open = false
		-- pos to be checked
		local current
		-- find next unclosed
		while not open do
			-- get unchecked pos
			current = table.remove(open_list)
			-- none are left
			if current == nil then return end
			-- assume it's open
			open = true
			-- check the closed positions
			for _,closed in pairs(closed_set) do
				-- if current is unclosed
				if vector.equals(closed,current.pos) then
					--found one was closed
					open = false
				end
			end
		end
		-- get all connected nodes
		local nodes = adjacent_connected_nodes(current.pos,include_ctrl)
		-- iterate through them
		for _,n in pairs(nodes) do
			-- mark position to be checked
			table.insert(open_list,n)
		end
		-- add this one to the closed set
		table.insert(closed_set,current.pos)
		-- return the one to be checked
		return current.pos,current.name
	end
end

-- get network connected to position
function me.get_connected_network(start_pos)
	for npos,nn in me.connected_nodes(start_pos,true) do
		if nn == "microexpansion:ctrl" then
			local network = me.get_network(npos)
			if network then
				return network,npos
			end
		end
	end
end

function me.update_connected_machines(start_pos,event,include_start)
  minetest.log("action","updating connected machines")
  local ev = event or {type = "n/a"}
  local sn = microexpansion.get_node(start_pos)
  local sd = minetest.registered_nodes[sn.name]
  local sm = sd.machine or {}
  ev.origin = {
    pos = start_pos,
    name = sn.name,
    type = sm.type
  }
  --print(dump2(ev,"event"))
  for npos in me.connected_nodes(start_pos) do
    if include_start or not vector.equals(npos,start_pos) then
      me.update_node(npos,ev)
    end
	end
end

function me.send_event(spos,type,data)
  local d = data or {}
  local event = {
    type = type,
    net = d.net,
    payload = d.payload
  }
  me.update_connected_machines(spos,event,false)
end

function me.get_network(pos)
	for i,net in pairs(networks) do
		if net.controller_pos then
			if vector.equals(pos, net.controller_pos) then
				return net,i
			end
		end
	end
end

dofile(path.."/ctrl.lua") -- Controller/wires

-- load networks
function me.load()
	local f = io.open(me.worldpath.."/microexpansion_networks", "r")
	if f then
		local res = minetest.deserialize(f:read("*all"))
		f:close()
		if type(res) == "table" then
			for _,n in pairs(res) do
			 local net = me.network.new(n)
			 net:load()
			 table.insert(me.networks,net)
			end
		end
	end
end

-- load now
me.load()

-- save networks
function me.save()
  local data = {}
  for _,v in pairs(me.networks) do
    table.insert(data,v:serialize())
  end
	local f = io.open(me.worldpath.."/microexpansion_networks", "w")
	f:write(minetest.serialize(data))
	f:close()
end

-- save on server shutdown
minetest.register_on_shutdown(me.save)
