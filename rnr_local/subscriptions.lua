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

--registered subscriptions
--lsubscriptions[subscription_id]=subscription
local lsubscriptions = {}

--adds a subscription
function add(data)
	--print ("SUB ADD", data.subscription_id)
	lsubscriptions[data.subscription_id]=data
end

function get_all()
	return lsubscriptions
end

function del_by_id(subscription_id)
	lsubscriptions[subscription_id]=nil
end

function del_by_source(skt)
	--print ("Purging ")
	for subscription_id, sub in pairs(lsubscriptions) do
		if sub.skt==skt then
			print ("Purging subscription", subscription_id)
			sub.subscription_id=nil
			lsubscriptions[subscription_id]=nil
		end
	end
end

--return a set of subscriptors interested in a given notification
function find_subscriptors(notification)
	local subs = {}
	local is_match
	local ev_value
	local op, filt_value, n_ev_value, n_filt_value
	for subscription_id, sub in pairs(lsubscriptions) do
		local skt=sub.skt
		--the subscriptor could be already included due to another subscription
		if not subs[skt] then 
			is_match=true
			local filters = sub.filter
			for nfilt, filt in ipairs(filters) do
				ev_value = notification[filt.attrib]
				--print( "----------",ev_value,filt.op,filt.value,"-----")		
				if ev_value == nil then
					is_match=false
				else
					op=filt.op
					filt_value=filt.value
					n_ev_value=tonumber(ev_value) or ev_value
					n_filt_value=tonumber(filt_value) or filt_value
					if (op == "=" and (ev_value~=filt_value))
					--or (op == ">" and (n_ev_value == nil or n_filt_value == nil or 
					--					n_ev_value<=n_filt_value))
					--or (op == "<" and (n_ev_value == nil or n_filt_value == nil or 
					--					n_ev_value>=n_filt_value)) then
					or (op == ">" and (n_ev_value<=n_filt_value))
					or (op == "<" and (n_ev_value>=n_filt_value)) then
						--print( "breaking...")		
						is_match=false
					
						-- idea, mover al principio? falla temprana.
						filters[1], filters[nfilt]=filters[nfilt], filters[1]
					end
				end
				if not is_match then break end
			end
			if is_match then
				--print("================adding", subscription_id)
				subs[skt] = true
			end
		end
	end
	return subs
end

