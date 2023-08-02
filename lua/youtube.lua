args = { ... }

local function setup_monitor(side)
	local monitor = peripheral.wrap(side)
	monitor.setTextScale(0.5)
	monitor.setBackgroundColor(colors.black)
	monitor.clear()
	monitor.setCursorPos(1, 1)
	return monitor
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

local function render_image_data(monitor, image_data_str)
	-- Parse image data into pixels matrix
	-- byte 1 is width, byte 2 is height
	-- first 16*3 bytes is the palette (each 3 bytes encode a color) (16 colors) (RGB format)
	-- then the rest is the image data each byte encode two pixels (4 bits each)
	-- half byte encode the color of the pixel
	-- last byte is padded with 0 to make it 8 bits

	local start_time = os.epoch("utc")
	local background_pixel = string.char(128)
	local image_data = { string.byte(image_data_str, 1, #image_data_str) }

	-- Parse width and height
	local width = image_data[1]
	local height = image_data[2]
	-- Parse palette
	for i = 1, 16, 1 do
		local r = image_data[2 + i * 3 - 2]
		local g = image_data[2 + i * 3 - 1]
		local b = image_data[2 + i * 3 - 0]
		monitor.setPaletteColour(my_colors[i], r / 255, g / 255, b / 255)
	end

	local palette_time = os.epoch("utc")

	-- Parse image data
	local i, j = 1, 1
	monitor.setCursorPos(i, j)
	for index = 2 + (16 * 3) + 1, #image_data do -- +1 because lua is 1-indexed. FUCK OF THIS FUCKING FUCK LANGUAGE
		local byte = image_data[index]
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
	local end_time = os.epoch("utc")
	return end_time - palette_time, palette_time - start_time
end

local function ask_for_video()
	term.write("Enter youtube url: ")
	local url = read()
	return url
end


local function main()
	local side = "top"
	local ws_url = "ws://ts.smptp.fr/websocket"

	local url = ask_for_video()
	print("URL is " .. url)


	local monitor = setup_monitor(side)
	local width, height = monitor.getSize()

	local ws = assert(http.websocket(ws_url))
	ws.send("size: " .. width .. ":" .. height)
	print("Size sended...")
	ws.send("url: " .. url)
	print("URL sended...")
	print("Waiting for data")
	local audio_file = ws.receive()
	print("Audio file is " .. audio_file)
	-- shell.run("bg", "speaker", "play http://ts.smptp.fr/file/" .. audio_file)
	shell.run("bg", "sspeaker")
	local in_loop = true
	local image_counter = 0
	local begin_time = os.epoch("utc")
	while in_loop do
		image_counter = image_counter + 1
		local begin_time = os.epoch("utc")
		image_data = ws.receive()
		local end_time = os.epoch("utc")
		if #image_data == 4 then
			if image_data == "stop" then
				in_loop = false
			end
		else
			local render_time, palette_time = render_image_data(monitor, image_data)
			term.clear()
			print("Render time: " .. render_time .. "ms")
			print("Palette time: " .. palette_time .. "ms")
			print("Network time: " .. (end_time - begin_time) .. "ms")
			print("FPS: " .. math.floor(1000 / (render_time + palette_time)))
			monitor.setTextScale(0.5)
			width, height = monitor.getSize()
			ws.send("size: " .. width .. ":" .. height)
		end
	end
	local end_time = os.epoch("utc")
	print("Total time: " .. (end_time - begin_time) .. "ms")
	print("Total time: " .. (end_time - begin_time) / 1000 .. "s")
	monitor.clear()
end

main()
