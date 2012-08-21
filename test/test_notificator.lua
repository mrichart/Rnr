require("socket")

local name=arg[1] or "test_notificator"
local host=arg[2] or "localhost"
local port=arg[3] or 8182

local function notif()
	lines = {[1]="NOTIFICATION", [2]="notification_id=notif" .. tostring(math.random(2^30)) }

	for i=1,5 do
		lines[#lines+1]="value" .. i .. "="..math.random()
	end
	lines[#lines+1]="END\n"
	return table.concat(lines, "\n")
end

print("Connecting...")
local client = assert(socket.connect(host, port))
print("Connected.")

print("===Sending===")
while 1  do
	if os.execute("/bin/sleep 1") ~= 0 then break end	
	print(os.time())
	local subsn=notif()
	--print(subsn)
	client:send(subsn)
end


client:close()
