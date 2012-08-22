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

local dispatch
local _,err = pcall(function() dispatch=require("dispatch") end)
print('dispatch required', tostring(err))


dispatch_handler = dispatch.newhandler()
--configuration.dispatch_handler=handler

print("CONF my_host", configuration.my_host)
local connection=require("connection")
local forwarder=require("forwarder")


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

print("### Server Listening ###")
-- simply loop stepping the server
while 1 do
	dispatch_handler:step()
	--print (".")
end

