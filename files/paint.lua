-- ModImage colours are 0xAABBGGRR
local M = {}

local function unpack_abgr(c)
	return bit.band(c, 0xFF), bit.band(bit.rshift(c, 8), 0xFF), bit.band(bit.rshift(c, 16), 0xFF), bit.band(bit.rshift(c, 24), 0xFF)
end

local function pack_abgr(r, g, b, a)
	local function byte(v) return math.max(0, math.min(255, math.floor(v + 0.5))) end
	return bit.bor(byte(r), bit.lshift(byte(g), 8), bit.lshift(byte(b), 16), bit.lshift(byte(a), 24))
end

local function hex_rgb(hex)
	return { tonumber(hex:sub(1, 2), 16), tonumber(hex:sub(3, 4), 16), tonumber(hex:sub(5, 6), 16) }
end

local function luminance(r, g, b)
	return 0.299 * r + 0.587 * g + 0.114 * b
end

local function shade(rgb, s)
	if s <= 1 then
		return rgb[1] * s, rgb[2] * s, rgb[3] * s
	end
	local t = math.min(s - 1, 1)
	return rgb[1] + (255 - rgb[1]) * t, rgb[2] + (255 - rgb[2]) * t, rgb[3] + (255 - rgb[3]) * t
end

local function stripe(colours, y, top, height)
	local i = math.floor((y - top + 0.5) * #colours / height) + 1
	return colours[math.max(1, math.min(#colours, i))]
end

local function bands(row_area, top, bottom, n)
	if bottom - top + 1 < n then return nil end
	local total = 0
	for y = top, bottom do total = total + row_area[y] end
	local band, k, sum, used = {}, 1, 0, 0
	for y = top, bottom do
		if k < n and used > 0 and (sum + row_area[y] / 2 > total * k / n or bottom - y < n - k) then
			k, used = k + 1, 0
		end
		band[y] = k
		sum, used = sum + row_area[y], used + 1
	end
	return band
end

function M.colours(flag)
	local out = {}
	for i, hex in ipairs(flag.stripes) do out[i] = hex_rgb(hex) end
	return out
end

function M.read(path)
	local id, w, h = ModImageMakeEditable(path, 0, 0)
	if id == 0 or w == 0 then return nil end
	local img = { w = w, h = h, px = {} }
	for y = 0, h - 1 do
		for x = 0, w - 1 do
			local r, g, b, a = unpack_abgr(ModImageGetPixel(id, x, y))
			img.px[y * w + x] = { r, g, b, a }
		end
	end
	return img
end

local function opaque(img, x, y)
	if x < 0 or y < 0 or x >= img.w or y >= img.h then return false end
	return img.px[y * img.w + x][4] > 0
end

local function edge_distance(img)
	local dist, queue, head = {}, {}, 1
	for y = 0, img.h - 1 do
		for x = 0, img.w - 1 do
			if opaque(img, x, y) and not (opaque(img, x - 1, y) and opaque(img, x + 1, y) and opaque(img, x, y - 1) and opaque(img, x, y + 1)) then
				dist[y * img.w + x] = 1
				queue[#queue + 1] = { x, y }
			end
		end
	end
	while queue[head] do
		local x, y = queue[head][1], queue[head][2]
		head = head + 1
		local d = dist[y * img.w + x] + 1
		for _, n in ipairs({ { x - 1, y }, { x + 1, y }, { x, y - 1 }, { x, y + 1 } }) do
			local i = n[2] * img.w + n[1]
			if opaque(img, n[1], n[2]) and not dist[i] then
				dist[i] = d
				queue[#queue + 1] = n
			end
		end
	end
	return dist
end

local LIGHT_X, LIGHT_Y, LIGHT_Z = -0.4, -0.5, 0.77

local function lighting(img, kind)
	local light = {}
	local lo, hi = 255, 0
	for _, p in pairs(img.px) do
		if p[4] > 0 and kind ~= "normal" then
			local l = luminance(p[1], p[2], p[3])
			lo, hi = math.min(lo, l), math.max(hi, l)
		end
	end
	for i, p in pairs(img.px) do
		if p[4] > 0 then
			if kind == "normal" then
				local nx, ny = (p[1] - 128) / 127, (p[2] - 128) / 127
				local nz = math.sqrt(math.max(0, 1 - nx * nx - ny * ny))
				light[i] = 0.75 + 0.45 * (nx * LIGHT_X + ny * LIGHT_Y + nz * LIGHT_Z)
			else
				local t = hi > lo and (luminance(p[1], p[2], p[3]) - lo) / (hi - lo) or 1
				light[i] = 0.45 + 0.8 * t
			end
		end
	end
	return light
end

local BLOOD = hex_rgb("C81E1E")

function M.body(src, dst_path, colours, kind, blood)
	local id = ModImageMakeEditable(dst_path, src.w, src.h)
	local dist = edge_distance(src)
	local light = lighting(src, kind)
	local top, bottom, row_area = src.h, -1, {}
	for y = 0, src.h - 1 do
		row_area[y] = 0
		for x = 0, src.w - 1 do
			if opaque(src, x, y) then
				top, bottom = math.min(top, y), math.max(bottom, y)
				row_area[y] = row_area[y] + 1
			end
		end
	end
	local small = math.min(src.w, src.h) <= 9
	local band = small and bands(row_area, top, bottom, #colours)
	local deepest = 1
	for _, d in pairs(dist) do deepest = math.max(deepest, d) end
	local thickness = math.max(1, math.min(math.floor(math.min(src.w, src.h) / 6), math.floor(deepest / 2)))

	for y = 0, src.h - 1 do
		for x = 0, src.w - 1 do
			local i = y * src.w + x
			if opaque(src, x, y) then
				local s = small and math.min(light[i], 1) or light[i]
				local rgb = band and colours[band[y]] or stripe(colours, y, top, bottom - top + 1)
				if blood and dist[i] <= thickness then
					rgb = BLOOD
					if dist[i] == 1 then s = s * 0.7 end
				elseif not blood and dist[i] == 1 and src.w >= 9 then
					s = s * 0.85
				end
				local r, g, b = shade(rgb, s)
				ModImageSetPixel(id, x, y, pack_abgr(r, g, b, 255))
			else
				ModImageSetPixel(id, x, y, 0)
			end
		end
	end
end

function M.recolour(path, colours, brightness, sparkle)
	local img = M.read(path)
	if not img then return end
	local id = ModImageMakeEditable(path, 0, 0)
	local light = lighting(img, "colour")
	local top, bottom = img.h, -1
	for i, p in pairs(img.px) do
		if p[4] > 0 then
			local y = math.floor(i / img.w)
			top, bottom = math.min(top, y), math.max(bottom, y)
		end
	end
	for i, p in pairs(img.px) do
		if p[4] > 0 then
			local x, y = i % img.w, math.floor(i / img.w)
			local s = light[i] * brightness
			if sparkle and light[i] >= 1.2 then s = math.max(s, 1.5) end
			local r, g, b = shade(stripe(colours, y, top, bottom - top + 1), s)
			ModImageSetPixel(id, x, y, pack_abgr(r, g, b, p[4]))
		end
	end
end

return M
