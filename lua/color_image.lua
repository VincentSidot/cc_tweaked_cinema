args = { ... }

local monitor = peripheral.wrap("top")

monitor.setTextScale(0.5)
local width, height = monitor.getSize()

local background_pixel = string.char(128)

local function fetch_image(image_name)
	local base_url = "http://ts.smptp.fr/file/"
	local image_content = http.get(base_url .. image_name)
	if image_content then
		return image_content.readAll()
	else
		error("Could not fetch image")
	end
end

local my_colors = {
	colors.black,
	colors.white,
	colors.orange,
	colors.magenta,
	colors.lightBlue,
	colors.yellow,
	colors.lime,
	colors.pink,
	colors.gray,
	colors.lightGray,
	colors.cyan,
	colors.purple,
	colors.blue,
	colors.brown,
	colors.green,
	colors.red,
}

local function render_image_data(image_data)
	-- Parse image data into pixels matrix
	-- byte 1 is width, byte 2 is height
	-- first 16*3 bytes is the palette (each 3 bytes encode a color) (16 colors) (RGB format)
	-- then the rest is the image data each byte encode two pixels (4 bits each)
	-- half byte encode the color of the pixel
	-- last byte is padded with 0 to make it 8 bits

	-- Parse width and height
	local width = string.byte(string.sub(image_data, 1, 1))
	local height = string.byte(string.sub(image_data, 2, 2))

	-- Parse palette
	for i = 1, 16, 1 do
		local r = string.byte(string.sub(image_data, 2 + i * 3 - 2, 2 + i * 3 - 2))
		local g = string.byte(string.sub(image_data, 2 + i * 3 - 1, 2 + i * 3 - 1))
		local b = string.byte(string.sub(image_data, 2 + i * 3 - 0, 2 + i * 3 - 0))
		print("Setting color " .. i .. " to " .. r .. " " .. g .. " " .. b)
		monitor.setPaletteColour(my_colors[i], r / 255, g / 255, b / 255)
	end

	-- Parse image data
	local i, j = 1, 1
	monitor.setCursorPos(i, j)
	print("Image size: " .. width .. "x" .. height)
	print("Rest of image data size: " .. (#image_data - 2 - (16 * 3)))
	print("It should be " .. (width * height / 2) .. " pixels")
	for index = 2 + (16 * 3) + 1, #image_data + 1 do
		local byte = string.byte(string.sub(image_data, index, index))
		local color1 = bit.brshift(byte, 4)
		local color2 = bit.band(byte, 15)
		monitor.setBackgroundColor(my_colors[color1 + 1]) -- +1 because lua is 1-indexed (WHO THE FUCK DECIDED THAT??)
		monitor.write(background_pixel)
		j = j + 1
		if j > width then
			j = 1
			i = i + 1
			monitor.setCursorPos(1, i)
		end
		monitor.setBackgroundColor(my_colors[color2 + 1]) -- +1 because lua is 1-indexed
		monitor.write(background_pixel)
		j = j + 1
		if j > width then
			j = 1
			i = i + 1
			monitor.setCursorPos(1, i)
		end
	end
end

local function main()
	local file_name = "controle.vng"
	local image_data = fetch_image(file_name)
	render_image_data(image_data)
	-- local image = parse_image(image_data)
	-- render_image(image)
end

main()
