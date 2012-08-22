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

local table_insert=table.insert
local table_getn=table.getn
local string_len=string.len
local table_remove=table.remove

function newStack ()
  	return {""}   -- starts with an empty string
end

function addString (stack, s)
  	table_insert(stack, s)    -- push 's' into the the stack
  	for i=table_getn(stack)-1, 1, -1 do
	    if string_len(stack[i]) > string_len(stack[i+1]) then
	      	break
	    end
    	stack[i] = stack[i] .. table_remove(stack)
	end
end
