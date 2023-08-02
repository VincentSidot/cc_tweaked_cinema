args = { ... }

local port = 80

if #args < 1 then
	print("Usage: vget <file name> <option>")
	return
end

local base_url = "http://ts.smptp.fr:80/file/"
local file_name = args[1]

-- check if file end with .lua if not add it
if string.sub(file_name, -4) ~= ".lua" then
	file_name = file_name .. ".lua"
end

shell.execute("wget", "run", base_url .. file_name)
