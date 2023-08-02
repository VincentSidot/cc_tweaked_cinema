local monitor = peripheral.wrap("top")

-- local str = ""
-- for i = 127, 160, 7 do
-- 	for j = 0, 6 do
-- 		str = str .. (i + j) .. ": " .. string.char(i + j) .. "\t"
-- 	end
-- 	str = str .. "\n"
-- end
--
-- monitor.clear()
-- monitor.setTextScale(0.5)
-- monitor.write(str)

local str = string.char(127)

while true do
	monitor.clear()
	monitor.setTextScale(1)
	local width, height = monitor.getSize()
	print("width: " .. width .. " height: " .. height)
	monitor.setCursorPos(0, math.floor(height / 2) - 1)
	monitor.write(str)
	print("Press any key to continue")
	os.pullEvent("key")
	monitor.clear()
	monitor.setTextScale(0.5)
	local width, height = monitor.getSize()
	print("width: " .. width .. " height: " .. height)
	monitor.setCursorPos(0, math.floor(height / 2) - 1)
	monitor.write(str)
	print("Press any key to continue")
	os.pullEvent("key")
end
