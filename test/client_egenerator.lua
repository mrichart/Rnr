require("socket")

--local host="192.168.1.157"
local host=arg[1] or "localhost"
local port=tonumber(arg[2]) or 8182

local subscription = [[
SUBSCRIBE
subscriptor_id=srid
subscription_id= snid 
FILTER
timestamp > 100
END
]]

local notification=[[
NOTIFICATION
host=localhost
service=generator
notification_id=niii
timestamp=ttt
value=vvv
END
]]


local client = assert(socket.connect(host, port))
--client:send(subscription)
--print("Subscription Sent.")

while 1 do
	local e=string.gsub(notification, "ttt", tostring(os.time()))
	e=string.gsub(e, "iii", tostring(os.time()))
	local vvv=tostring(math.random())
	e=string.gsub(e, "vvv", vvv)
	client:send(e)
	print("Notification Sent", vvv)
	socket.sleep(5)
end


--repeat
--	local line, err = client:receive()
--	if not err then 
--		print(line ) 
--	else
--		--print("err:", err)
--	end
--until err=="closed"
client:close()
