require("socket")

local name=arg[1] or "test_subscriber"
local host=arg[2] or "localhost"
local port=arg[3] or 8182

print("Connecting...")
local client = assert(socket.connect(host, port))
assert(client:settimeout(0.1))
print("Connected.")

local function generate_subscritpion()

	local n1=math.random(1,5)
	local n2=math.random(1,5)
	while n2==n1 do
		n2=math.random(1,5)
	end

	lines = {[1]="SUBSCRIBE", 
		[2]="subscription_id=sid" .. tostring(math.random(2^30)), 
		[3]="FILTER",
		[4]="value"..n1.."<0.5",
		[5]="value"..n2.."<0.5",
		[6]="END\n"
	}

	--for i=1,10 do
	--	lines[#lines+1]="value" .. i .. "="..math.random()
	--end
	--lines[#lines+1]="END\n"

	return table.concat(lines, "\n")

end


print("===Reading===")
local last_ts=os.time()
local ns=0
repeat
	local line, err = client:receive()
	if line == "NOTIFICATION" then 
		--print(os.time(), ns,line ) 
	end
	local ts=os.time()
	if ts-5>last_ts then
		last_ts=ts
		local subs=generate_subscritpion()
		client:send(subs)
		ns=ns+1
		print(os.time(),ns,"SUBSCRIBE" ) 
	end

until err and err~="timeout"

client:close()

