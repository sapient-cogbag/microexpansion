--- Microexpansion network
-- @type network
-- @field #table controller_pos the position of the controller
-- @field #number power_load the power currently provided to the network
-- @field #number power_storage the power that can be stored for the next tick
-- @field #table items the itemstacks stored in the networks drives
-- @field #number item_capacity the amount of items that can be stored in the networks drives
local network = {
	power_load = 0,
	power_storage = 0,
	--for testing it's at 3200 will be set to 0 when the drives work
	item_capacity = 3200,
}
microexpansion.network = network

--- construct a new network
-- @function [parent=#network] new
-- @param #table o the object to become a network or nil
function network:new(o)
	local n = setmetatable(o or {}, {__index = self})
	o.items = {}
	return o
end

--- check if a node can be connected
-- @function [parent=#network] can_connect
-- @param #table pos the position of the node to be checked
-- @return #boolean whether this node has the group me_connect
function network.can_connect(pos)
	local node = microexpansion.get_node(pos)
	return minetest.get_item_group(node.name, "me_connect") > 0
end

--- get all adjacent connected nodes
-- @function [parent=#network] adjacent_connected_nodes
-- @param #table pos the position of the base node
-- @param #boolean include_ctrl whether to check for the controller
-- @return #table all nodes that have the group me_connect
function network.adjacent_connected_nodes(pos, include_ctrl)
	local adjacent = {
		{x=pos.x+1, y=pos.y,   z=pos.z},
		{x=pos.x-1, y=pos.y,   z=pos.z},
		{x=pos.x,   y=pos.y+1, z=pos.z},
		{x=pos.x,   y=pos.y-1, z=pos.z},
		{x=pos.x,   y=pos.y,   z=pos.z+1},
		{x=pos.x,   y=pos.y,   z=pos.z-1},
	}

	local nodes = {}

	for _,pos in pairs(adjacent) do
		if network.can_connect(pos) then
			if include_ctrl == false then
				if not microexpansion.get_node(pos).name == "microexpansion:ctrl" then
					table.insert(nodes, pos)
				end
			else
				table.insert(nodes, pos)
			end
		end
	end

	return nodes
end

--- provide power to the network
-- @function [parent=#network] provide
-- @param #number power the amount of power provided
function network:provide(power)
	self.power_load = self.power_load + power
end

--- demand power from the network
-- @function [parent=#network] demand
-- @param #number power the amount of power demanded
-- @return #boolean whether the power was provided
function network:demand(power)
	if self.power_load - power < 0 then
		return false
	end
	self.power_load = self.power_load - power
	return true
end

--- add power capacity to the network
-- @function [parent=#network] add_power_capacity
-- @param #number power the amount of power that can be stored
function network:add_power_capacity(power)
	self.power_storage = self.power_storage + power
end

--- add power capacity to the network
-- @function [parent=#network] add_power_capacity
-- @param #number power the amount of power that can't be stored anymore
function network:remove_power_capacity(power)
	self.power_storage = self.power_storage - power
	if self.power_storage < 0 then
		minetest.log("warning","[Microexpansion] power storage of network "..self.." dropped below zero")
	end
end

--- remove overload
-- to be called by the controller every turn
-- @function [parent=#network] remove_overload
function network:remove_overload()
	self.power_load = math.min(self.power_load, self.power_storage)
end
