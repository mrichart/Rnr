#!/usr/bin/lua
--[[

 Copyright 2008 MINA Group, Facultad de Ingenieria, Universidad de la
Republica, Uruguay.

 This file is part of the RAN System.

    The RAN System is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    The RAN System is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with the RAN System.  If not, see <http://www.gnu.org/licenses/>.

--]]

local configuration=require("configuration")
if arg[1] then configuration.load(arg[1]) end
local time_step=configuration.time_step

local dispatch = require("dispatch")
dispatch_handler = dispatch.newhandler()
--configuration.dispatch_handler=handler

print("CONF my_host", configuration.my_host)
for _,address in pairs(configuration.upstream) do
	print ("CONF upstream" ,address)
end

local connection=require("connection")
local forwarder=require("forwarder")
local overlay=require("overlay")
--local peer_sampling=require("peer_sampling")


local os_time=os.time

local server = assert(dispatch_handler.tcp())
assert(server:setoption("reuseaddr", true))
assert(server:bind(configuration.my_host, configuration.rnr_port))
assert(server:listen(32))

-- handler for the server object loops accepting new connections
dispatch_handler:start(function()
	local client
    	while 1 do
        	client = assert(server:accept())
        	assert(client:settimeout(0))
		-- for each new connection, start a new client handler
		dispatch_handler:start(function()
			connection.fhandler(client)
		end)
	end
end)

for _,adress in ipairs (configuration.upstream) do
	connection.add_upstream(adress)
end

print("### Server Listening ###")
local last_timestamp = os_time()
local last_newscast_round = os_time()

-- simply loop stepping the server
while 1 do
	dispatch_handler:step()
	--print (".")

	--maintenance
	local ts = os_time()
	if ts - last_timestamp >= time_step then
		connection.check_inactive_upstreams(ts)	
		connection.maintain_seen_notifids(ts)
		last_timestamp=ts
	end 
	--print (ts-last_newscast_round,configuration.newscast_round_time)
	if ts - last_newscast_round >= configuration.newscast_round_time then
		overlay.newscast_round(ts)
		last_newscast_round = ts
	end

end

