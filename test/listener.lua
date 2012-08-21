socket = require("socket")

local server = assert(socket.bind("*", 8183))

--mjpg_streamer --input "input_uvc.so --device /dev/video0 --fps 5 --resolution 640x480
--" --output "output_http.so -w /mnt/usbdrive/webcam_www --port 8181"

local function process(res, fps, port)
	port = port or 8181
	os.execute("killall mjpeg-streamer")
	os.execute("mjpg_streamer --input \"input_uvc.so --device /dev/video0 --fps " .. fps
		.." --resolution " ..res
		.."\" --output \"output_http.so --port " .. port .."\"")
end

process("640x480","5","8181")
while true do
	local client = server:accept()
	repeat
		local line, err = client:receive()
		if not err then 
			print(line ) 
			local res, fps, port = string.match(line, "(%S+)%s+")
			if value then
				precess(rx, ry, fps, port)
			end
		end
	until err=="closed"
	client:close()
end
