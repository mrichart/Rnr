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

local function randomize ()
	local fl = io.open("/dev/urandom");
	local res = 0;
        local mult={256,256,256,128} --en el kamikaze8.09.1 los enteros son de 31 bits... signo?                                            
        for f = 1, 4 do res = res*mult[f]+(fl:read(1)):byte(1, 1); end;                                                                     
	fl:close();
	math.randomseed(res);
end;

randomize()

--default values
time_step=1

my_host="127.0.0.1"
rnr_port=9182

max_lines_in_message=500
sockets_timeout=60*60*24 + math.random(-1, 1) --time with no traffic on a socket before closing&reconecting

--loads from a configuration file
function load(file)
	local f, err = loadfile(file)
	assert(f,err)
	setfenv(f, configuration)
	f()
end

