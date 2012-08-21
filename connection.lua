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

local configuration = require("configuration")
local handler = dispatch_handler --configuration.dispatch_handler
local max_lines_in_message=configuration.max_lines_in_message
local subscription_dupe_window_size=configuration.subscription_dupe_window_size
local subscription_dupe_window_amount=configuration.subscription_dupe_window_amount
local notification_dupe_window_size=configuration.notification_dupe_window_size
local notification_dupe_window_amount=configuration.notification_dupe_window_amount

local subscriptions = require("subscriptions")
local forwarder = require("forwarder")

local upstream_check_sleep=configuration.upstream_check_sleep
local rnr_port=configuration.rnr_port

local string_match=string.match
local table_concat=table.concat
local os_time=os.time


local list=require("list")
local List=list.List

--keep track of seen notifications, to avoid dupes
--{{data=v, ts=ts}... }
local seen_notifids_list=List.new()
--notif_id  ->  ts
local seen_notifids = {}
setmetatable(seen_notifids, 
	{__mode = "k",  -- make keys weak
	 __newindex = function (t,k,v)     --insert in list for time keeping
	        rawset(t, k, v) --seen_notifids[k] = v 
		List.pushright(seen_notifids_list, {data=k, ts=os_time()} )
		end
	}
) 
--handlers for processing messages
--process_message[message_type]=function
process_message = {}

--upstream connections
--upstream[ip]
local upstream = {}

--of the previous, which still not connected
--upstream_inactive[ip]=last_check_ts
local upstream_inactive = {}

--track sources of connection (for back connect detection)
--local with_ip = {}

--attempts to connect to a upstream server, and send a hello
local function check_upstream(ip)
	assert(type(ip)=="string")

	--TODO
	if upstream[ip]=="connected" then
		--print ("-----skipping upstream", ip)
		return
	end

  	handler:start(function()
		local upskt = assert(handler.tcp())
		--assert(upskt:settimeout(0))
		assert(upskt:setoption("reuseaddr", true))
		assert(upskt:bind(configuration.my_host, 0))
 	    	local _, err = upskt:connect(ip, rnr_port)

		--print ("+upstream connecting...")
		--local upskt, err = socket.connect(ip, rnr_port, configuration.my_host, 0)
	    	if err then
			upstream_inactive[ip]=os_time()
			upskt:close()
			upskt=nil
	    		--print ("Error checking upstream:", err )
	    		return 
	    	end
		assert(upskt:settimeout(0))

	    	upstream_inactive[ip] = nil
					
		local upskt_ip, upskt_port= upskt:getsockname()
		print ("+upstream connection from ", upskt_ip, upskt_port, "to", upskt:getpeername())
	        fhandler(upskt)
    	end)
end


function add_upstream (ip)
	print ("=upstream",ip)

	upstream[ip]=""
	upstream_inactive[ip]=0
	--check_upstream(ip) --if done, init doesnt reach accept loop
end

--iterate trough inactive ipstreams connecting them
function check_inactive_upstreams(ts)
	local ts=ts or os_time()

	for ip,last_check in pairs (upstream_inactive) do
		if ts - last_check > upstream_check_sleep then
--print ("--checking upstream", ip)
			--upstream_inactive[ip]=ts
			check_upstream(ip)
		end
	end
end

local function forward_all_subscriptions(skt)
	--push all the subsriptions
	local subs=subscriptions.get_all()
	local n=0
	for sid, sub in pairs(subs) do
		--forward all the subscriptions that didn't come from him, and not outlived ttl
		local ttl=tonumber(sub.ttl)
		if skt ~= sub.skt and ((not ttl) or (ttl > 1)) then
			forwarder.queue(skt, forwarder.generate_subscription(sub))
			n=n+1
		end
	end
	print ("synced subscriptions", n)
end

function maintain_seen_notifids(ts)
	local ts=ts or os_time()
	local ts_cutout=ts - notification_dupe_window_size
	while seen_notifids_list[seen_notifids_list.first] 
	and (tonumber(seen_notifids_list[seen_notifids_list.first].ts) < ts_cutout)
	or (seen_notifids_list.last - seen_notifids_list.first > notification_dupe_window_amount) do
--print ("//////dropping", seen_notifids_list.first, seen_notifids_list.last, 
--			seen_notifids_list[seen_notifids_list.first].data)
		rawset(seen_notifids, seen_notifids_list[seen_notifids_list.first].data, nil)
		local v=List.popleft(seen_notifids_list)
		rawset(seen_notifids, v.data, nil)
	end
end

--Process subscription message
process_message["SUBSCRIBE"] = function (skt, lines)

	--will hold subscription
	local subscript = {}
	subscript.skt=skt
	
	--list of {attrib, operator, value}
	subscript.filter = {}
	local subscript_filter=subscript.filter

	local reading_filter=false
	local attrib, operator, value
--print ("===============================")
	for _,line in ipairs(lines) do 
--print ("===", line)
		if not reading_filter then
			--read first fields until reaching "FILTER" label
			if line == "FILTER" then
				reading_filter=true
			else
				attrib, value = string_match(line, "^%s*(.-)%s*=%s*(.-)%s*$")
				if attrib then
					subscript[attrib]=value
					--print ("IN subscription: ", attrib,"=",value)	
				else
					print ("Error: can't parse subscription line", line)
				end
			end
		else
			--reading filter lines
			attrib, operator, value = string_match(line, "^%s*(.-)%s*([=<>])%s*(.-)%s*$")
			if attrib then
				subscript_filter[#subscript_filter+1] = {attrib=attrib, op=operator, value=value}
				--print ("filter : ", attrib, operator, value)	
			else
				print ("Error: can't parse filter line ", line)					
			end
		end
	end

	local subscription_id=subscript.subscription_id

	--check for dupes
	if (subscriptions.get_all())[subscription_id] then
		print("dupe subscription", subscription_id)
		return
	end

	--if seen_subsids[subscription_id] then
	--	print("dupe subscription", subscription_id)
	--	return
	--end
	--seen_subsids[subscription_id]=true

	
	--insert into subscription list
	print ("+subscription:", subscript.service, skt:getpeername())
	subscriptions.add( subscript )

	--resend
	forwarder.distribute_subscription( subscript )

	--check upstream connections, just in case
	--check_inactive_upstreams()
end

--Process unsubscription message
process_message["UNSUBSCRIBE"] = function (skt, lines)
	--load from subscription
	local unsubscript = {}
	subscript.skt=skt

	local attrib, value
	for _,line in ipairs(lines) do 
		attrib, value = string_match(line, "^%s*(.-)%s*=%s*(.-)%s*$")
		if attrib then
			unsubscript[attrib]=value
		else
			print ("Error: can't parse unsubscription line", line)					
		end
	end

	local unsubscription_id=unsubscript.unsubscription_id
	local subscription_id=unsubscript.subscription_id


	--check for dupes
	if not ((subscription.get_all())[subscription_id]) then
		print("dupe unsubscription for", subscription_id)
		return
	end

	--check for dupes
	--if seen_subsids[unsubscription_id] then
	--	print("dupe unsubscription", unsubscription_id)
	--	return
	--end
	--seen_subsids[unsubscription_id]=true

	--resend
	forwarder.distribute_unsubscription( subscript )

	if subscription_id then
		subscriptions.del_by_id( subscription_id )
	end

end


--Process notification message
process_message["NOTIFICATION"] = function (skt,lines) 
	local notification = {}
	local attrib, value
	--print ("IN notification")	
	for _,line in ipairs(lines) do 
--print ("##############",line)
		if line ~= "" then
			attrib, value = string_match(line, "^%s*(.-)%s*=%s*(.-)%s*$")
			if attrib then
				notification[attrib]=value
				--print ("IN notification: ", attrib,"=",value)	
			else
				print ("Error: can't parse notification line ", line)					
			end
		end
	end	

	local notification_id = notification.notification_id

	if not notification_id then
		print ("Missing notification_id!!!")
		return
	end

	--check for dupes
	if seen_notifids[notification_id] then
		print("dupe notification", notification_id)
		return
	else
		seen_notifids[notification_id]=true
	end
	
	--find subscriptions meeting notification
	local matching_subs = subscriptions.find_subscriptors(notification)
	
	--check upstream connections, just in case
	--check_inactive_upstreams()
	
	--resend the notification to matching subcriptors
	forwarder.distribute_notification( notification, matching_subs, skt )
end

--[[
--Process hello message
process_message["HELLO"] = function (skt,data) 
		
	print ("IN hello: ", skt:getpeername())	

	--answer to the hello
	forwarder.queue(skt, hello_reply_msg)
	
	--and push all the subsriptions
	forward_all_subscriptions(skt)

end

--Process hello_reply message
process_message["HELLO_REPLY"] = function (skt,data) 

	print ("IN hello reply: ", skt:getpeername())	

	forward_all_subscriptions(skt)
end
--]]

--read from the socket, store the lines in lines, and process once got a complete message
function fhandler(skt)
 	local lines, operation 	
	local line, error, partial
	local ip, _ = skt:getpeername()

	forwarder.register_client(skt)

	forward_all_subscriptions(skt)

	--with_ip[ip]=true
	if upstream[ip] then upstream[ip]="connected" end --for back detection

  	while 1 do
   	 	--print("+++++")
		if partial then
        		line, error, partial = skt:receive("*l", partial)
		else
        		line, error, partial = skt:receive()
		end
		--print ("----", line, error, partial)
        	if error =="closed" or (error == "timeout" and not partial) then 
        		print("Closing!", error,skt:getpeername(), line)
        		break
        	end
		
		if line~=nil then 
			if operation==nil then
				--waiting for a message start label
				if process_message[line] then
					lines, operation={}, line
				end
			else
				--reading a message
				if line=="END" then
					--end of message, process according to operation
					process_message[operation](skt,lines)
					operation,lines=nil, nil
				else
					if #lines<max_lines_in_message then
						--read message content
						lines[ #lines+1 ] = line
					else
						--message too long, purge
						operation,lines=nil,nil
					end
				end
			end	
		end
 	end    	
	skt:close()
	forwarder.unregister_client(skt)

 	if upstream[ip] then
		upstream[ip]="" --reset for back detection
		upstream_inactive[ip]=os_time()
		--check_upstream(ip)
 	end
end



