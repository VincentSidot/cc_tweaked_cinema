function extract_video_id(url)
	local video_id = url:match("v=([^&]+)")
	if video_id then
		return video_id
	else
		video_id = url:match("youtu%.be/([^&/]+)")
		return video_id
	end
end

-- Example usage:
local url = "https://www.youtube.com/watch?v=KoQNzd7Y1_U&pp=ygUHbG9yZW56bw%3D%3D"
local video_id = extract_video_id(url)
print("Video ID:", video_id)
