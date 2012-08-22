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

local subscriptions = require("subscriptions")
local forwarder = require("forwarder")

local rnr_port=configuration.rnr_port

local string_match=string.match
local table_concat=table.concat
local os_time=os.time


local list=require("list")
local List=list.List

--handlers for processing messages
--process_message[message_type]=function
process_message = {}

--of the previous, which still not connected

--track sources of connection (for back connect detection)
--local with_ip = {}

local function forward_all_subscriptions(skt)
	--push all the subsriptions
	local subs=subscriptions.get_all()
	local n=0
	for sid, sub in pairs(subs) do
		--forward all the subscriptions that didn't come from him, and not outlived
		if skt ~= sub.skt  then
			forwarder.queue(skt, forwarder.generate_subscription(sub))
			n=n+1
		end
	end
	print ("synced subscriptions", n)
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
	
	--insert into subscription list
	print ("+subscription:", subscript.service, skt:getpeername())
	subscriptions.add( subscript )

	--resend
	forwarder.distribute_subscription( subscript )
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
	
	--find subscriptions meeting notification
	local matching_subs = subscriptions.find_subscriptors(notification)
	
	--resend the notification to matching subcriptors
	forwarder.distribute_notification( notification, matching_subs, skt )
end

--read from the socket, store the lines in lines, and process once got a complete message
function fhandler(skt)
 	local lines, operation 	
	local line, error, partial
	local ip, _ = skt:getpeername()

	forwarder.register_client(skt)

	forward_all_subscriptions(skt)

	--with_ip[ip]=true

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
end



