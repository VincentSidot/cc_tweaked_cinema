args = { ... }

local function get_video_id(url)
	local parts = {}
	for part in string.gmatch(url, "[^=]+") do
		parts[#parts + 1] = part
	end
	return parts[#parts]
end

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
	local ws_url = "ws://ts.smptp.fr/cinema/websocket/new"
	local url = ask_for_video()
	print("URL is " .. url)
	local new_socket = http.websocket(ws_url)
	new_socket.send(url)
	print("Downloading video...")
	local socket_id = new_socket.receive()
	local youtube_id = get_video_id(url)
	new_socket.close()
	print("Socket id is " .. socket_id)
	local video_url = "ws://ts.smptp.fr/cinema/websocket/" .. socket_id .. "/video"
	local audio_url = "http://ts.smptp.fr/cinema/file/" .. youtube_id .. "/output_left.dfpwm"
	local video_socket = assert(http.websocket(video_url))
	local monitor = setup_monitor(side)
	local width, height = monitor.getSize()
	local image_counter = 0
	local in_loop = true
	shell.run(
		"bg",
		"speaker",
		"play",
		audio_url
	)
	while in_loop do
		video_socket.send(width .. "x" .. height)
		image_counter = image_counter + 1
		local begin_time = os.epoch("utc")
		image_data = video_socket.receive()
		local end_time = os.epoch("utc")
		if #image_data == 4 then
			if image_data == "stop" then in_loop = false end
		else
			local render_time, palette_time = render_image_data(monitor, image_data)
			term.clear()
			print("Render time: " .. render_time .. "ms")
			print("Palette time: " .. palette_time .. "ms")
			print("Network time: " .. (end_time - begin_time) .. "ms")
			print("FPS: " .. math.floor(1000 / (render_time + palette_time)))
			monitor.setTextScale(0.5)
			width, height = monitor.getSize()
		end
	end
	local end_time = os.epoch("utc")
	print("Total time: " .. (end_time - begin_time) .. "ms")
	print("Total time: " .. (end_time - begin_time) / 1000 .. "s")
	monitor.clear()
end

main()

-- local function render_video(url)
-- 	local side = "top"
-- 	local monitor = setup_monitor(side)
-- 	local width, height = monitor.getSize()
-- 	local video_socket = assert(http.websocket(url))
-- 	local image_counter = 0
-- 	local in_loop = true
-- 	while in_loop do
-- 		video_socket.send(width .. "x" .. height)
-- 		image_counter = image_counter + 1
-- 		local begin_time = os.epoch("utc")
-- 		image_data = video_socket.receive()
-- 		local end_time = os.epoch("utc")
-- 		if #image_data == 4 then
-- 			if image_data == "stop" then in_loop = false end
-- 		else
-- 			local render_time, palette_time = render_image_data(monitor, image_data)
-- 			term.clear()
-- 			print("Render time: " .. render_time .. "ms")
-- 			print("Palette time: " .. palette_time .. "ms")
-- 			print("Network time: " .. (end_time - begin_time) .. "ms")
-- 			print("FPS: " .. math.floor(1000 / (render_time + palette_time)))
-- 			monitor.setTextScale(0.5)
-- 			width, height = monitor.getSize()
-- 			video_socket.send(width .. "x" .. height)
-- 		end
-- 	end
-- 	local end_time = os.epoch("utc")
-- 	print("Total time: " .. (end_time - begin_time) .. "ms")
-- 	print("Total time: " .. (end_time - begin_time) / 1000 .. "s")
-- 	monitor.clear()
-- end
--
-- local function render_audio(url, side)
-- 	local speaker = peripheral.wrap(side)
-- 	local audio_socket = assert(http.websocket(url))
-- 	local in_loop = true
-- 	local decoder = require "cc.audio.dfpwm".make_decoder()
-- 	local sample_rate = audio_socket.receive()
-- 	print("Sample rate is " .. sample_rate)
-- 	while in_loop do
-- 		local audio_data = audio_socket.receive()
-- 		if #audio_data == 4 then
-- 			if audio_data == "stop" then in_loop = false end
-- 		else
-- 			local buffer = decoder(audio_data)
-- 			while not speaker.playAudio(buffer) do
-- 				os.pullEvent("speaker_audio_empty")
-- 			end
-- 		end
-- 		audio_socket.send("ok")
-- 	end
-- end
--
-- local function render_audio_http(url, side)
-- 	local speaker = peripheral.wrap(side)
--
-- 	local handle, err = http.get { url = url, binary = true }
--
-- 	if not handle then
-- 		printError("Failed to download audio file")
-- 		error(err, 0)
-- 	end
--
-- 	local decoder = require "cc.audio.dfpwm".make_decoder()
-- 	print("Playing audio...")
-- 	local start_time = os.epoch("utc")
-- 	while true do
-- 		local chunk = handle.read(16 * 1024)
-- 		if (not chunk) then
-- 			print("Audio file ended")
-- 			break
-- 		end
-- 		local buffer = decoder(chunk)
-- 		while not speaker.playAudio(buffer) do
-- 			os.pullEvent("speaker_audio_empty")
-- 		end
-- 	end
-- 	local end_time = os.epoch("utc")
-- 	handle.close()
--
-- 	print("Audio played")
-- 	print("Time: " .. (end_time - start_time) .. "ms")
-- 	print("Time: " .. ((end_time - start_time) / 1000) .. "s")
-- end
--
-- local function main()
-- 	local ws_url = "ws://ts.smptp.fr/websocket/new"
--
-- 	local url = ask_for_video()
-- 	print("URL is " .. url)
-- 	local new_socket = http.websocket(ws_url)
-- 	new_socket.send(url)
-- 	print("Downloading video...")
-- 	local socket_id = new_socket.receive()
-- 	new_socket.close()
-- 	print("Socket id is " .. socket_id)
-- 	local video_url = "ws://ts.smptp.fr/websocket/" .. socket_id .. "/video"
-- 	local audio_right_url = "http://ts.smptp.fr/file/output_left.dfpwm"
-- 	local audio_left_url = "http://ts.smptp.fr/file/output_right.dfpwm"
-- 	parallel.waitForAll(
-- 		function()
-- 			render_audio_http(audio_right_url, "right")
-- 		end,
-- 		function()
-- 			render_video(video_url)
-- 		end
-- 	)
-- 	-- local audio_left_url = "ws://ts.smptp.fr/websocket/" .. socket_id .. "/audio/left"
-- 	-- local audio_right_url = "ws://ts.smptp.fr/websocket/" .. socket_id .. "/audio/right"
-- 	-- print("Playing video...")
-- 	-- shell.run(
-- 	-- 	"bg",
-- 	-- 	"speaker",
-- 	-- 	"play",
-- 	-- 	audio_left_url
-- 	-- )
-- 	-- render_video(video_url)
-- end
