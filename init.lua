--[[ Config ]]--
local disable_inventory = false
local R = 1 -- Size of vbar radius
local shape = "belt" -- Mode (belt or ring)

local visuals = {}
local hud = {}
local toggle = {}

local def_size = vector.multiply({x = 0.25, y = 0.25, z = 0.25}, R)
local def_sel = vector.multiply({x = 0.265, y = 0.265, z = 0.265}, R)

-- Swap hotbar items around
local function set_item(entity, player)
	local inv = player:get_inventory()
	local main = inv:get_list("main")
	inv:set_stack("main", entity.idx, player:get_wielded_item())
	player:set_wielded_item(main[entity.idx])
	visuals[player:get_player_name()] = nil
end

vector.cross = vector.cross or function(a, b)
	return {
		x = a.y * b.z - a.z * b.y,
		y = a.z * b.x - a.x * b.z,
		z = a.x * b.y - a.y * b.x
	}
end

local function dir_to_pitch(dir)
    local pitch = minetest.dir_to_yaw({x = -dir.y, y = 0, z = math.sqrt(1 - dir.y * dir.y)})
    return (pitch > math.pi) and (pitch - math.pi * 2) or pitch
end

local shapes = {
	belt = function(player, slot)
		local pos = player:get_pos()
		pos.y = pos.y + 1
		local angle = (-(360 / 8) * slot) + 45
		local y = player:get_look_horizontal()
		local rel = vector.multiply(minetest.yaw_to_dir(math.rad(angle) + y), R)
		local target = vector.add(rel, pos)
		local rot = vector.direction(target, pos)
		return target, {x = 0, y = math.rad(angle) + y, z = 0}
	end,
	ring = function(player, slot) -- Thanks to Aaron Suen (Warr1024) for this
		local camera_z = player:get_look_dir()
		local camera_x = minetest.yaw_to_dir(player:get_look_horizontal() + math.pi / 2)
		local camera_y = vector.cross(camera_x, camera_z)
		local angle = ((360 / 8) * slot) + 45
		local cv = {x = math.cos(math.rad(angle)) * R, y = math.sin(math.rad(angle)) * R, z = R * 2}
		local wv = player:get_pos()
		wv.y = wv.y + player:get_properties().eye_height
		wv = vector.add(wv, vector.multiply(camera_x, cv.x))
		wv = vector.add(wv, vector.multiply(camera_y, cv.y))
		wv = vector.add(wv, vector.multiply(camera_z, cv.z))
		return wv, {x = dir_to_pitch(camera_z), y = minetest.dir_to_yaw(camera_z), z = 0}
	end,
}

minetest.register_entity("visualbar:item", {
	initial_properties = {
		visual = "wielditem",
		wield_item = "",
		visual_size = def_size,
		selectionbox = {-0.25 * R, -0.25 * R, -0.25 * R, 0.25 * R, 0.25 * R, 0.25 * R},
		collisionbox = {-0.25 * R, -0.25 * R, -0.25 * R, 0.25 * R, 0.25 * R, 0.25 * R},
	},
	parent = nil, -- You aren't really supposed to store references, but... sue me
	timer = 0,
	idx = 0,
	on_activate = function(self)
		self.object:set_armor_groups({immortal = 1})
	end,
	on_step = function(self, dt) -- Most of this is just fancy visuals
		self.timer = self.timer + dt
		if self.timer > 0.1 then
			if not self.parent or not visuals[self.parent:get_player_name()] then
				self.object:remove()
			elseif self.object:get_properties().wield_item ~= "" then
				local pointed = false
				local player = self.parent
				local pos = player:get_pos()
				pos.y = pos.y + player:get_properties().eye_height
				local dir = player:get_look_dir()
				local ray = minetest.raycast(pos, vector.add(pos, vector.multiply(dir, 2)))
				for pt in ray do
					if pt.type == "object" and pt.ref == self.object then
						pointed = true
						break
					end
				end
				if pointed then
					self.object:set_properties({
						visual_size = def_sel
					})
				else
					self.object:set_properties({
						visual_size = def_size
					})
				end
			end
			self.timer = 0
		end
	end,
	on_punch = set_item,
	on_rightclick = set_item,
})

local function display(player)
	local name = player:get_player_name()
	local inv = player:get_inventory()
	local list = inv:get_list("main")
	local pos = player:get_pos()

	visuals[name] = table.copy(pos)

	for i = 1, 8 do
		local target, rot = shapes[shape](player, i)
		local ent = minetest.add_entity(target, "visualbar:item")
		local luen = ent:get_luaentity()
		local item = list[i]:get_name()
		if item ~= "" then
			ent:set_properties({wield_item = item, infotext = minetest.registered_items[item].description or item})
			ent:set_rotation(rot)
			if list[i]:get_count() > 1 then
				ent:set_nametag_attributes({
					color = "white",
					text = list[i]:get_count()
				})
			end
		else
			ent:set_properties({visual_size = {x = 0, y = 0, z = 0}})
		end
		luen.parent = player
		luen.idx = i
	end
end

minetest.register_on_joinplayer(function(player)
	local name = player:get_player_name()

	player:hud_set_flags({
		hotbar = false
	})
	player:hud_set_hotbar_itemcount(1) -- Force player to hold selected item

	-- Display stack size
	hud[name] = player:hud_add({
		hud_elem_type = "text",
		position = {x = 0.5, y = 1},
		text = "",
		alignment = 0,
		offset = {x = 0, y = -20},
		number = 0xFFFFFF,
	})	

	if disable_inventory then
		minetest.after(0, function(name)
			local player = minetest.get_player_by_name(name)
			if player then
				player:set_inventory_formspec("size[0,0] no_prepend[] bgcolor[#00000000]")
			end
		end, name)
		player:get_inventory():set_size("main", 8)
	else
		player:get_inventory():set_size("main", 8 * 4)
		minetest.register_on_player_inventory_action(function(player)
			visuals[player:get_player_name()] = nil
		end)
	end

	minetest.register_on_placenode(function(_, _, player)
		visuals[player:get_player_name()] = nil
	end)
	minetest.register_on_dignode(function(_, _, player)
		visuals[player:get_player_name()] = nil
	end)
end)

minetest.register_on_leaveplayer(function(player)
	visuals[player:get_player_name()] = nil
end)

local function precise_time()
	return minetest.get_us_time() / 1000000
end

minetest.register_globalstep(function()
	for _, player in pairs(minetest.get_connected_players()) do
		local name = player:get_player_name()
		local ctrl = player:get_player_control()
		if visuals[name] then -- Remove visuals if aux1 is pressed or the player moves
			if ctrl.aux1 or not vector.equals(vector.floor(player:get_pos()), vector.floor(visuals[name])) then
				visuals[name] = nil
				toggle[name] = 0
			end
		else
			if ctrl.aux1 then -- Start the timer if aux1 is pressed
				toggle[name] = toggle[name] or precise_time()
			elseif toggle[name] then
				if precise_time() - toggle[name] <= 0.12 then
					display(player) -- Display if aux1 was released within 0.12 seconds
				end
				toggle[name] = nil
			end
		end

		-- Update stack count HUD element
		local count = player:get_wielded_item():get_count()
		if count < 1 then
			count = ""
		end
		player:hud_change(hud[name], "text", count)
	end
end)
