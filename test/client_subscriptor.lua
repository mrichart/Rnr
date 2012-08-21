require("socket")

local host="localhost"
local port=8182

if arg[1]~=nil then
host=arg[1]
end
if arg[2]~=nil then
port=tonumber(arg[2])
end

local sub1 = [[
SUBSCRIBE
host=localhost
service=test
subscription_id= snid1
FILTER
service=generator
value<0.5
END
]]
local sub2 = [[
SUBSCRIBE
host=localhost
service=test
subscription_id= snid2
FILTER
service=generator
value>0.5
END
]]
local hello = [[
HELLO
host=localhost
service=test
END
]]

-- >10
--<1000000

local client = assert(socket.connect(host, port))

client:send(hello)
client:send(sub1)
client:send(sub2)

print("Sent.")
repeat
	--client:send(hello)
	local line, err = client:receive()
	if not err then 
		print("-", line ) 
	else
		print("err:", err)
	end
until err=="closed"
client:close()
