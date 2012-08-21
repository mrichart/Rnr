module(..., package.seeall);

local view_size=3 	--c
local view = {} 	--array of node_descriptors

local my_host=configuration.my_host
local my_descriptor = {node=my_host, hopcount=0}

for i, ip in ipairs(configuration.upstream) do
	print ("Initializing view:", ip)
	view[i]={node=ip, hopcount=1}
end


--compares two node descriptors (usually means "closer")
local function less_than(d1,d2) 
	return d1.hopcount<d2.hopcount 
end

--merge buffer 1 and buffer 2
--returns the union of b1 and b2. When a node is repeated, use the lowest
--hopcount. The return is sorted by hopcount
local function merge(buff1, buff2)
	local ret, seen_node={},{}
	for _, desc in ipairs(buff1) do
		seen_node[desc.node]=desc
	end
	for _, desc in ipairs(buff2) do
		if not seen_node[desc.node] or less_than(desc, seen_node[desc.node]) then
			seen_node[desc.node]=desc
		end
	end
	for _, desc in pairs(seen_node) do
		ret[#ret+1]=desc
	end
	table.sort(ret, less_than )
	return ret
end

--adds 1 to all hopcounts in buff
local function increase_hop_count(buff)
	for _, desc in ipairs(buff) do
		desc.hopcount=desc.hopcount+1
	end
end

--send buffer to node p
local function send_buffer(header,buff,p)
	local conn=forwarder.get_connections()
	print ("sending buffer to", p)
	for skt, _ in pairs(conn) do
		if p==skt:getpeername() then
			--build message
			local buff_msg=header
			for _, desc in ipairs(buff) do
				buff_msg=buff_msg.."\n"..desc.node.." "..desc.hopcount
				print ("        buffer",desc.node,desc.hopcount )
			end
			buff_msg=buff_msg.."\nEND\n"

			forwarder.queue(skt, buff_msg)
			return
		end
	end
	print("node not found:", p)
end

--select a random live node from active view
local function select_peer()
	if #view==0 then
		print ("0 nodes in view!")
		return
	end
	local inode=math.random(#view)
	local r_node = view[inode]
	return r_node.node
end

--select first view_size nodes (by hopcount) from buff
local function select_view(buff)

	for _,v in ipairs(buff) do
		print("Selecting from", v.node, v.hopcount)
	end

	--table.sort(buff, less_than )
	local ret={}
	for i=1,view_size do
		if buff[i] and buff[i].node ~=  my_host then
			ret[i]=buff[i]
			print("view: ", buff[i].node, buff[i].hopcount)
		end
	end

	return ret
end

function newscast_round()
	print ("Starting newscast round")
	local p = select_peer()
	if not p then 
		print ("No peer found!")
		return 
	end
	local buffer=merge(view, {[1]=my_descriptor})
	send_buffer("PS_SEND_BUFFER", buffer,p)	--this triggers PS_SEND_BUFFER_BACK as response
end

local function parse_message(lines)
	local buff={}
	for _, line in ipairs(lines) do
		local node, hopcount = string.match(line, "^%s*(.-)%s+(.-)%s*$")
		hopcount=tonumber(hopcount)
		if node and hopcount then
			local desc={node=node, hopcount=hopcount}
			buff[#buff+1]=desc
		else
			print ("Error: can't parse buffer line ", line)					
		end
	end
	return buff
end

connection.process_message["PS_SEND_BUFFER"] = function (skt, lines)
	print ("IN send_buffer")
	local p  = skt:getpeername()
	local view_p = parse_message(lines)
	increase_hop_count(view_p)
	local buffer=merge(view, {[1]=my_descriptor})
	send_buffer("PS_SEND_BUFFER_BACK",buffer,p)
	buffer=merge(view_p, view)
	view=select_view(buffer)
end

connection.process_message["PS_SEND_BUFFER_BACK"] = function (skt, lines)
	print ("IN send_buffer_back")
	local p = skt:getpeername()
	local view_p = parse_message(lines)
	increase_hop_count(view_p)
	local buffer=merge(view_p, view)
	view=select_view(buffer)
end
