#!/usr/bin/lua
-- verify.lua
--
-- Copyright (C) 2021-2023, Old Blue Bike Software Inc.
--
-- 
-- Permission is hereby granted, free of charge, to any person obtaining
-- a copy of this software and associated documentation files (the
-- "Software"), to deal in the Software without restriction, including
-- without limitation the rights to use, copy, modify, merge, publish,
-- distribute, sublicense, and/or sell copies of the Software, and to
-- permit persons to whom the Software is furnished to do so, subject to
-- the following conditions:
-- 
-- The above copyright notice and this permission notice shall be included
-- in all copies or substantial portions of the Software.
-- 
-- THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
-- EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
-- MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
-- IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
-- CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
-- TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
-- SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

require( "midi" )
require( "kit" )


function usage()
   io.stderr:write( "Usage: verify <MMD file>\n" )
   os.exit()
end


-- Given the path of a file relative to this Lua file, construct and 
-- return the path of the file relative to current working directory.
-- If no path is given, return the path of the current Lua file:
function get_rel_path( path )
   local script_dir
   
   script_dir = debug.getinfo(1).source:match("@?(.*)[/\\]")
   if type( script_dir ) ~= "string" then
      script_dir = io.popen("cd"):read('*l')
   end
   return script_dir .. "/" .. path
end -- get_rel_path()


-- Convert log severity to numerical representation to facilitate comparisons:
function get_log_severity( severity )
   if severity == "fatal" then
      return 4
   elseif severity == "error" then
      return 3
   elseif severity == "warning" then
      return 2
   elseif severity == "info" then
      return 1
   else
      return 0
   end
end -- get_log_severity()
   

function log( severity, text )
   severity = get_log_severity( severity ) -- convert to number
   if type( min_log_severity ) ~= "number" or severity >= min_log_severity then
      print( text )
   end
end -- log()


function print_message_differences( expected, actual )
   local list, current, tag, last, msg
   
   list = {}
   for i = 1, #expected do
      if type( actual ) ~= "table" or actual[i] ~= expected[i] then
         list[#list + 1] = i
      end
   end
   
   log( "error", "EXPECTED " .. #expected .. " message(s):" )
   last = 0
   for i = 1, #list do
      current = list[i]
      if current ~= (last + 1) then
         print( "..." )
      end
      tag = string.format( "%3d- ", current )
      msg = expected[current]
      if type( msg ) == "string" then
         print(  tag .. midi.octets_to_hex( msg ) )
      else
         print( tag .. "<<INVALID>>" )
      end
      last = current
   end  
   if last ~= #expected then
      print( "..." )
   end
   
   if type( actual ) == "table" then
      log( "error", "ACTUAL " .. #actual .. " message(s):" )
      last = 0
      for i = 1, #list do
         current = list[i]
         if current ~= (last + 1) then
            print( "..." )
         end
         tag = string.format( "%3d- ", current )
         msg = actual[current]
         if type( msg ) == "string" then
            print( tag .. midi.octets_to_hex( msg ) )
         else
            print( tag .. "<<INVALID>>" )
         end
         last = current
      end
      if last ~= #actual then
         print( "..." )
      end
   end
end -- print_message_differences()


function test_dump_program_command( index, config, slot, cmd_path )
   local cmd_msgs, msgs, header, max_rsps, desc
   
   cmd_msgs = midi.load( cmd_path )
   if type( cmd_msgs ) ~= "table" then
      log( "fatal", "REFERENCE COMMAND MESSAGE LIST EMPTY" )
      return nil
   end
   
   desc = "dump_program_command( slot=" .. slot .. " )"
   msgs, header, max_rsps = model.dump_program_command( config, slot )   
   if type( msgs ) ~= "table" or #msgs ~= #cmd_msgs or
      midi.compare( msgs, cmd_msgs ) ~= 0 then
      log( "error", "!!FAIL - " .. desc .. "  (incorrect 'msgs')" )
      print_message_differences( cmd_msgs, msgs )
      return nil
   elseif header ~= nil and
      (type( header ) ~= "string" or string.byte( header, 1 ) ~= 0xF0) then
      log( "error", "!!FAIL - " .. desc .. "  (incorrect 'header')" )
      return nil
   elseif max_rsps ~= nil and type( max_rsps ) ~= "number" then
      log( "error", "!!FAIL - " .. desc .. "  (incorrect 'max_rsps')" )
      return nil
   end
   log( "info", "    ok - " .. desc )
end -- test_dump_program_command()


function test_program_decode_encode( index, config, slot, dump_path, cmd_path, load_slot )
   local dump_msgs, cmd_msgs, records, name, desc

   dump_msgs = midi.load( dump_path )
   if type( dump_msgs ) ~= "table" or #dump_msgs == 0 then
      log( "fatal", "REFERENCE DUMP MESSAGE LIST EMPTY" )
      return nil
   end
   if type( cmd_path ) == "string" and cmd_path ~= dump_path then
      cmd_msgs = midi.load( cmd_path )
   else
      cmd_msgs = dump_msgs -- command to reload program same as dump by default
   end
   if type( cmd_msgs ) ~= "table" or #cmd_msgs == 0 then
      log( "error", "REFERENCE LOAD COMMAND MESSAGE LIST EMPTY" )
      return nil
   end   
   if type( load_slot ) ~= "number" then      
      load_slot = slot -- reload to same slot by default
   end
   
   desc = "decode()"
   records = model.decode( dump_msgs )
   records, name = kit.extract( records, "program:" .. slot )
   if type( records ) ~= "table" or #records == 0 then
      log( "error", "!!FAIL - " .. desc .. " (invalid 'records')" )      
      return nil
   end
   if name ~= nil and type( name ) ~= "string" then
      log( "error", "!!FAIL - " .. desc .. " (invalid 'name')" )
      return nil
   end 
   log( "info", "    ok - " .. desc )
   
   desc = "load_program_command( slot=" .. load_slot .. ", name="
   if name == nil then
      desc = desc .. "nil"
   else
      desc = desc .. "\"" .. name .. "\""
   end
   desc = desc .. " )"
   msgs = model.load_program_command( config, records, load_slot, name )
   if type( msgs ) ~= "table" or #msgs ~= #cmd_msgs or
      midi.compare( msgs, cmd_msgs ) ~= 0 then
      log( "error", "!!FAIL - " .. desc .. " (incorrect 'msgs')" )
      print_message_differences( cmd_msgs, msgs )
      return nil
   end

   log( "info", "    ok - " .. desc )         
end -- test_program_decode_encode()


function test_dump_globals_command( index, config, globals, cmd_path )
   local cmd_msgs, msgs, header, max_rsps, desc
   
   cmd_msgs = midi.load( cmd_path )
   if type( cmd_msgs ) ~= "table" or #cmd_msgs== 0 then
      log( "fatal", "REFERENCE COMMAND MESSAGE LIST EMPTY" )
      return nil
   end
   
   desc = "dump_globals_command( globals=\"" .. globals .. "\" )"
   msgs, header, max_rsps = model.dump_globals_command( config, globals )
   if type( msgs ) ~= "table" or #msgs ~= #cmd_msgs or
      midi.compare( msgs, cmd_msgs ) ~= 0 then
      log( "error", "!!FAIL - " .. desc .. "  (incorrect 'msgs')" )
      print_message_differences( cmd_msgs, msgs )
      return nil
   elseif header ~= nil and
      (type( header ) ~= "string" or string.byte( header, 1 ) ~= 0xF0) then
      log( "error", "!!FAIL - " .. desc .. "  (incorrect 'header')" )
      return nil
   elseif max_rsps ~= nil and type( max_rsps ) ~= "number" then
      log( "error", "!!FAIL - " .. desc .. "  (incorrect 'max_rsps')" )
      return nil
   end
   log( "info", "    ok - " .. desc )
end -- test_dump_program_command()


function test_globals_decode_encode( index, config, globals, dump_path, cmd_path )
   local dump_msgs, cmd_msgs, records, name, msgs, desc

   dump_msgs = midi.load( dump_path )
   if type( dump_msgs ) ~= "table" or #dump_msgs == 0 then
      log( "fatal", "REFERENCE DUMP MESSAGE LIST EMPTY" )
      return nil
   end
   if type( cmd_path ) == "string" and cmd_path ~= dump_path then
      cmd_msgs = midi.load( cmd_path )
   else
      cmd_msgs = dump_msgs
   end
   if type( cmd_msgs ) ~= "table" or #cmd_msgs == 0 then
      log( "fatal", "REFERENCE LOAD COMMAND MESSAGE LIST EMPTY" )
      return nil
   end
   
   desc = "decode()"
   records = model.decode( dump_msgs )
   records = kit.extract( records, "globals:" .. globals )
   if type( records ) ~= "table" or #records == 0 then
      log( "error", "!!FAIL - " .. desc .. " (invalid 'records')" )      
      return nil
   end
   log( "info", "    ok - " .. desc )
   
   desc = "load_globals_command( globals=\"" .. globals .. "\" )"
   msgs = model.load_globals_command( config, globals, records )
   if type( msgs ) ~= "table" or #msgs ~= #cmd_msgs or
      midi.compare( msgs, cmd_msgs ) ~= 0 then
      log( "error", "!!FAIL - " .. desc .. " (incorrect 'msgs')" )
      print_message_differences( cmd_msgs, msgs )
      return nil
   end
   
   log( "info", "    ok - " .. desc )
end -- test_globals_decode_encode()

   
function perform_test_case( index, case )
   local config, slot, globals
   
   print( "\nTEST CASE #" .. index .. ":" )
   
   if type( case ) ~= "table" then
      log( "fatal", "Invalid specification for test case #" .. index )
      return nil
   end
   
   if type( case.config ) == "table" then
      config = case.config
   elseif case.config ~= nil then
      log( "fatal", "Invalid device configuration in test case #" .. index )
      return nil
   else
      config = {}
   end

   if case.item == "program" then
      slot = case.slot
      if slot == nil then
         slot = 0
      elseif type( slot ) ~= "number" then     
         log( "fatal", "Invalid program slot number in test case #" .. index )
         return nil
      end
      
      if type( case.command ) == "string" then
         command = case.test_data_dir_path .. "/" .. case.command
         test_dump_program_command( index, config, slot, command )
      elseif case.command ~= nil then
         log( "fatal", "Invalid program command file name in test case #" .. index )
         return nil      
      end
      
      if type( case.dump ) == "string" then
         dump = case.test_data_dir_path .. "/" .. case.dump
         if type( case.load ) == "string" then
            rest = case.test_data_dir_path .. "/" .. case.load
         else
            rest = nil
         end
         test_program_decode_encode( index, config, slot, dump, rest, case.load_slot )
      elseif case.dump ~= nil then
         log( "fatal", "Invalid program dump file name in test case #" .. index )
         return nil      
      end
   elseif case.item == "globals" then
      if type( case.globals ) ~= "string" then
         log( "fatal", "Invalid or missing globals category name in test case #" .. index )         
         return nil
      end
      
      if type( case.command ) == "string" then
         command = case.test_data_dir_path .. "/" .. case.command
         test_dump_globals_command( index, config, case.globals, command )
      elseif case.command ~= nil then
         log( "fatal", "Invalid globals command file name in test case #" .. index )
         return nil
      end
      
      if type( case.dump ) == "string" then      
         dump = case.test_data_dir_path .. "/" .. case.dump
         if type( case.load ) == "string" then
            rest = case.test_data_dir_path .. "/" .. case.load
         else
            rest = nil
         end
         test_globals_decode_encode( index, config, case.globals, dump, rest )
      elseif case.dump ~= nil then
         log( "fatal", "Invalid globals dump file name in test case #" .. index )
         return nil      
      end   
   else
      log( "fatal", "Unknown item type \"" .. case.item .. " in test case #" .. case.item )
   end
   
   print( "COMPLETE." );
end -- perform_test_case()


function perform_test_cases( mmd_path, test_data_dir_path )
   if type( mmd_path ) ~= "string" or type( test_data_dir_path ) ~= "string" then
      usage()
   end
   model = dofile( mmd_path )
   cases_file_path = test_data_dir_path .. "/cases.lua"
   cases = dofile( cases_file_path )
   if type( cases ) ~= "table" then
      log( "fatal", "Invalid test case table in " .. cases_file_path )
      return nil
   end

   for i = 1, #cases do
      case = cases[i]
      case.test_data_dir_path = test_data_dir_path
      perform_test_case( i, case )
   end
end -- perform_test_cases()


-- MAIN
i = 1
while i <= #arg do
   opt = arg[i]
   if opt == "-s" then
      i = i + 1
      if i > #arg then
         usage()
      end
      mmd_src_dir = get_rel_path( arg[i] )
      i = i + 1
   elseif opt == "-q" then
      quiet = true      
      i = i + 1
   elseif opt == "--" then
      i = i + 1 
      break
   elseif string.sub( opt, 1, 1 ) ~= "-" then
      break
   end
end

if type( mmd_src_dir ) ~= "string" then
   mmd_src_dir = get_rel_path()
end
if quiet then
   min_log_severity = get_log_severity( "error" )
end

while i <= #arg do
   mmd_name = arg[i]
   i = i + 1
   
   print( "\n\nRUNNING TEST CASES FOR \"" .. mmd_name .. "\":" )
   mmd_src_path = mmd_src_dir .. "/" .. mmd_name .. ".lua"
   test_data_dir_path = mmd_src_dir .. "/test"
   perform_test_cases( mmd_src_path, test_data_dir_path )
end


-- EOF verify.lua
