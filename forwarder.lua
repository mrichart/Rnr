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

module(..., package.seeall);

local os_time=os.time
local configuration=require ("configuration")
local subscriptions=require ("subscriptions")
--local handler = configuration.dispatch_handler
local handler=dispatch_handler
local util=require("util")

local table_concat=table.concat
local string_len=string.len

--set of open sockets
local connections = {} 
setmetatable(connections, {__mode = "k"}) 

--outgoing queues
--queues[skt]={s,...}
local queues = {}
setmetatable(queues, {__mode = "k"})  -- make keys weak

--keeps on writing on a socket trying to empty queues[skt]
local function cosend(skt)
	local last = 0
	local err
	local data = table_concat(queues[skt])
	queues[skt]={}
	while 1 do
		last, err = skt:send(data , last +1 )
		if not last then
			print ("Connection error on send!", err)
			--don't close anything, main loop will process
			break
		end

		--if finished sending a message, get the next ones
		if last == string_len(data) then
			--no more messages, break
			if next(queues[skt])==nil then break end

			--join all pending messages
			data = table_concat(queues[skt])
			queues[skt]={}
			last=0
		end
	end

	--cleaning...
	queues[skt] = nil

end

--adds a message to a outgoing queue
function queue(skt, s)
	if queues[skt] then
		--there are pending messages already, enqueue
		table.insert(queues[skt], s)
	else
		--nothing pending on the socket, create queue and writing coroutine
		queues[skt]={s}
        	handler:start(function()
            		cosend(skt)
        	end)		
	end
end

function register_client (skt)
	print ("+client: ", skt:getpeername())
	connections[skt] = true
end

function unregister_client (skt)
	print ("-client")
	connections[skt] = nil
	subscriptions.del_by_source(skt)
end

function get_connections()
	return connections
end


--generates a subscription string for this node, based on a received subscription
function generate_subscription( incomming )
	
	--string for ttl, decreased
	local ttl, ttl_string = tonumber(incomming.ttl), ""
	if ttl then
		ttl_string = "ttl=".. ttl-1 .. "\n"
	end
	
	local s = {"SUBSCRIBE\n"
	--.. "host=" .. configuration.my_host .. "\n"
	.. "service=rnr\n"
	.. "subscription_id=" .. incomming.subscription_id  .. "\n"
	.. ttl_string
	.. "FILTER" }
	local incomming_filter=incomming.filter
	for _,sentence in ipairs(incomming_filter) do 
		s[#s+1] = sentence.attrib .. sentence.op .. sentence.value
	end
	s[#s+1] = "END\n"

	return table_concat(s, "\n")
end

function generate_unsubscription( incomming )	
	--string for ttl, decreased
	local ttl, ttl_string = tonumber(incomming.ttl), ""
	if ttl then
		ttl_string = "ttl=".. ttl-1 .. "\n"
	end
	
	local s = {"UNSUBSCRIBE\n" .. ttl_string }

	for attrib,value in pairs(notification) do 
		if attrib ~= "ttl" then
			s[#s+1] = attrib .. "=" .. value
		end
	end
	s[#s+1] = "END\n"
	return table_concat(s, "\n")
end

--generates a notification string for this node to emit, based on a received notification
local function generate_notification( notification )
	local s = {"NOTIFICATION"}
	for attrib,value in pairs(notification) do 
		--if attrib ~= "forwarding_node" then
			s[#s+1] =  attrib .. "=" .. value 
		--end
	end
	--s[#s+1] = "forwarding_node="..configuration.my_host
	s[#s+1] = "END\n"
	return table_concat(s, "\n")
end

function distribute_subscription( s )
	--print ("Forwarding subscription...")
	
	--check remaining ttl
	local ttl=tonumber(s.ttl)
	if ttl and ttl<=1 then
		print ("TTL expired on subscription", s.subscription_id)
		return
	end
	
	local new_subs = generate_subscription( s )

	local from_skt = s.skt
		
	for skt, _ in pairs(connections) do
		if skt ~= from_skt then
			--print ("SUB: to: ", skt:getpeername() )
			queue(skt, new_subs)
		end
	end
end

function distribute_unsubscription( s )
	--print ("Forwarding subscription...")
	
	--check remaining ttl
	local ttl=tonumber(s.ttl)
	if ttl and ttl<=1 then
		print ("TTL expired on subscription", s.subscription_id)
		return
	end
	
	local new_unsubs = generate_unsubscription( s )

	local from_skt = s.skt
		
	for skt, _ in pairs(connections) do
		if skt ~= from_skt then
			--print ("UNSUB: to: ", skt:getpeername() )
			queue(skt, new_unsubs)
		end
	end
end


function distribute_notification (notification, subs, from_skt)
	--print ("Forwarding notification...")
	
	--local source_id=notification.forwarding_node --notification.source
	local new_notification = generate_notification( notification )
	for to_skt, _ in pairs(subs) do
		if to_skt~=from_skt then 
			--print("NOTIF: sending...", sub)
			queue(to_skt, new_notification)
		end
	end	
end

