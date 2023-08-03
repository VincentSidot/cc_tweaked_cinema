local speaker = peripheral.wrap("left")

local handle, err = http.get { url = "http://ts.smptp.fr/file/output_left.dfpwm", binary = true }

if not handle then
  printError("Failed to download audio file")
  error(err, 0)
end

local decoder = require "cc.audio.dfpwm".make_decoder()
print("Playing audio...")
local start_time = os.epoch("utc")
while true do
  local chunk = handle.read(16 * 1024)
  if (not chunk) then
    print("Audio file ended")
    break
  end
  local buffer = decoder(chunk)
  while not speaker.playAudio(buffer) do
    os.pullEvent("speaker_audio_empty")
  end
end
local end_time = os.epoch("utc")
handle.close()

print("Audio played")
print("Time: " .. (end_time - start_time) .. "ms")
print("Time: " .. ((end_time - start_time) / 1000) .. "s")
