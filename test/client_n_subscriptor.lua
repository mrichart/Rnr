require("copas")

local host="localhost"
local port=8184

if arg[1]~=nil then
host=arg[1]
end
if arg[2]~=nil then
port=tonumber(arg[2])
end

local message = [[
SUBSCRIBE
subscriptor_id=srid
subscription_id=snid 
FILTER
free_ram >-1
cpu_load_avg>-1
random>0.5
source=toto
END
]]

-- >10
--<1000000

local n_socks = 0

local function connectionHandler(_, skt)
	repeat
		local linea, err = copas.receive(skt)
		print(linea)
		--if linea=="NOTIFICATION" then
		--	print (os.time())
		--end
	until err == "closed"
	print ("closed!")
	n_socks = n_socks - 1
end


local connections={}
local n_connections = 1
local function connect_n_subscriptors()
	for i=1,n_connections do
		local client = assert(socket.connect(host, port))
		local m = string.gsub(message, "subscriptor_id=srid", "subscriptor_id=srid" .. i )
		m = string.gsub(m, "subscription_id=snid ", "subscription_id=snid" .. i )
		client:settimeout(0)
		client:send(m)
		connections[i]=client
		copas.addthread(connectionHandler, client)
		n_socks = n_socks + 1

		--if os.execute("/bin/sleep 0.2s") ~= 0 then break end
	end
	print("Sent subscriptions", n_connections)
end

local n_subscriptions = 10
local function connect_1_subscriptor()
	local client = assert(socket.connect(host, port))
	n_socks = n_socks + 1
	client:settimeout(0)
	for i=1,n_subscriptions do
		local m = string.gsub(message, "subscription_id=snid ", "subscription_id=snid" .. i )
		client:send(m)
		--if os.execute("/bin/sleep 0.2s") ~= 0 then break end		
	end
	connections[1]=client
	copas.addthread(connectionHandler, client)

	print("Sent subscriptions", n_subscriptions)
end


--connect_1_subscriptor()
connect_n_subscriptors()
repeat
	copas.step()
until n_socks == 0
--client:close()