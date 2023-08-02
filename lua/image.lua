local monitor = peripheral.wrap("top")

monitor.setTextScale(0.5)
local width, height = monitor.getSize()

local background_pixel = string.char(128)

local function fetch_image(image_name)
	local base_url = "http://ts.smptp.fr:8000/"
	local image_content = http.get(base_url .. image_name)
	if image_content then
		return image_content.readAll()
	else
		error("Could not fetch image")
	end
end

local function render_image_data(image_data)
	-- Parse image data into pixels matrix
	-- image data is binary data with 1 bit per pixel
	-- two first bytes are width and height
	-- then each byte is 8 pixels information
	-- last byte is padded with 0 to have a multiple of 8
	-- 1 means true, 0 means false
	local width = string.byte(string.sub(image_data, 1, 1))
	local height = string.byte(string.sub(image_data, 2, 2))
	local i, j = 1, 1
	monitor.setBackgroundColor(colors.black)
	monitor.clear()
	for index = 3, #image_data do
		local byte = string.byte(string.sub(image_data, index, index))
		for sub_bit = 1, 8, 1 do
			local pixel = not (bit.band(bit.blshift(byte, sub_bit - 1), 128) == 128)
			if pixel then
				monitor.setBackgroundColor(colors.white)
				monitor.write(background_pixel)
				monitor.setBackgroundColor(colors.black)
			else
				monitor.setBackgroundColor(colors.black)
				monitor.write(background_pixel)
			end
			j = j + 1
			if j > width then
				j = 1
				i = i + 1
				monitor.setCursorPos(1, i)
			end
		end
	end
end

local function main()
	local image_data = fetch_image("test.vng")
	render_image_data(image_data)
	-- local image = parse_image(image_data)
	-- render_image(image)
end

main()
