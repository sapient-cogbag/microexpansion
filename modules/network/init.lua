local me       = microexpansion
me.networks    = {}
local networks = me.networks
local path     = microexpansion.get_module_path("network")

-- load Resources

dofile(path.."/network.lua") -- Network Management

-- generate iterator to find all connected nodes
function me.connected_nodes(start_pos)
	-- nodes to be checked
	local open_list = {start_pos}
	-- nodes that were checked
	local closed_set = {}
	-- local connected nodes function to reduce table lookups
	local adjacent_connected_nodes = me.network.adjacent_connected_nodes
	-- return the generated iterator
	return function ()
		-- start looking for next pos
		local open = false
		-- pos to be checked
		local current_pos
		-- find next unclosed
		while not open do
			-- get unchecked pos
			current_pos = table.remove(open_list)
			-- none are left
			if current_pos == nil then return end
			-- assume it's open
			open = true
			-- check the closed positions
			for _,closed in pairs(closed_set) do
				-- if current is unclosed
				if vector.equals(closed,current_pos) then
					--found one was closed
					open = false
				end
			end
		end
		-- get all connected nodes
		local next_pos = adjacent_connected_nodes(current_pos)
		-- iterate through them
		for _,p in pairs(next_pos) do
			-- mark position to be checked
			table.insert(open_list,p)
		end
		-- add this one to the closed set
		table.insert(closed_set,current_pos)
		-- return the one to be checked
		return current_pos
	end
end

-- get network connected to position
function me.get_connected_network(start_pos)
	for npos in me.connected_nodes(start_pos) do
		if me.get_node(npos).name == "microexpansion:ctrl" then
			local network = me.get_network(npos)
			if network then
				return network
			end
		end
	end
end

function me.update_connected_machines(start_pos)
	--print("updating connected machines")
	for npos in me.connected_nodes(start_pos) do
		me.update_node(npos)
	end
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
	local res = io.open(me.worldpath.."/microexpansion.txt", "r")
	if res then
		res = minetest.deserialize(res:read("*all"))
		if type(res) == "table" then
			for _,n in pairs(res.networks) do
				table.insert(networks,me.network:new(n))
			end
		end
	end
end

-- load now
me.load()

-- save networks
function me.save()
	local data = {
		networks = networks,
	}

	io.open(me.worldpath.."/microexpansion.txt", "w"):write(minetest.serialize(data))
end

-- save on server shutdown
minetest.register_on_shutdown(me.save)
