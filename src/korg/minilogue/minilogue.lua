-- minilogue.lua
--
-- MIDI Model Description (MMD) for Korg Minilogue Synthesizers.
--
-- Copyright (C) 2021-2023, Old Blue Bike Software Inc.
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


-- MIDI MODEL DESCRIPTION (MMD) for the Korg Minilogue
-- ===================================================
--
-- Identification:
-- ---------------
--
-- The Minilogue responds to the standard device inquiry IDENTITY REQUEST
-- message as follows:
--
--                 F0 7E 0g 06 02 42 2C 01 00 00 mi mi ma ma F7
--                       --       -- ----- ----- ----- -----
--                        |        |   |     |     |     | 
--            Unit ID  ---+        |   |     |     |     | 
--                                 |   |     |     |     | 
--         Manufacturer ID (Korg) -+   |     |     |     | 
--                                     |     |     |     | 
--       Family ID (Minilogue)  -------+     |     |     | 
--                                           |     |     | 
--                 Member ID (unused)  ------+     |     | 
--                                                 |     | 
--        Software minor version (LSB, MSB)  ------+     | 
--                                                       | 
--              Software major version (LSB, MSB)  ------+ 
--
-- where:
--  - unit ID: differentiates between multiple Minilogues when they
--    are connected to the same MIDI output through a MIDI splitter or
--    or other method. Corresponds to the value of the "MIDI Ch" parameter
--    in the "GLOBAL EDIT -> Global 4" menu on the device (0x00-0x0F);
--  - manufacturer code = 0x42 (Korg);
--  - family code = 0x012C (Minilogue);
--  - member code = 0x0000 (unused).
--
-- Program Data:
-- -------------
--
-- The active program can be retrieved from the Minilogue by transmitting
-- a CURRENT PROGRAM DATA DUMP REQUEST message:
--
--                          F0 42 3g 00 01 2C 10 F7
--                             -- -- -------- 
--                              |  |     |    
--     Manufacturer ID (Korg)  -+  |     |    
--                                 |     |    
--                     Unit ID  ---+     |    
--                                       |    
--              Product ID (Minilogue) --+    
--

-- HELPER SUBROUTINES:

-- Construct SysEx message header for unit number in given configuration:
function get_header( config ) -- -> unit
   local unit

   if type( config ) ~= "table" then 
      print( "Minilogue get_header(): no unit identifier in configuration" )
      return nil -- invalid argument
   end
   unit = config.unit
   if type( unit ) ~= "number" or unit < 0 or unit > 15 then
      print( "Minilogue get_header(): unit identifier invalid" )
      return nil -- out of range
   end
   return midi.hex_to_octets( { "F0 42", 0x30 | unit, "00 01 2C" } )
end -- get_header()


-- Remove trailing whitespaces from given string:
function trim( s )
   local i

   i = #s
   while i >= 1 and string.sub( s, i, i ) == " " do
      i = i - 1
   end
   return string.sub( s, 1, i )
end -- trim()


-- Extract the name of a program from the given program data record.
--  - record: program data record.
--
-- Returns:
--  - name: name of the program or nil if the program is unnamed.
function get_program_name( record ) -- -> name
   local i
   
   i = 5 -- name field range 5-16 inclusive (length 12)
   while i <= 16 and string.byte( record, i ) ~= 0x00 do
      i = i + 1
   end
   if i > 5 then
      return trim( string.sub( record, 5, i - 1 ) )
   end
end -- get_program_name()


-- Replace the name of a program in the given program data record.
--  - record: program data record;
--  - name: new name of the program.
--
-- Returns:
--  - record: the updated program data record.
function set_program_name( record, name ) -- -> record
   name = name .. string.rep( string.char( 0 ), 12 )
   record = string.sub( record, 1, 4 ) .. string.sub( name, 1, 12 ) ..
      string.sub( record, 17 )
   return record
end -- set_program_name()


-- Construct an CURRENT PROGRAM DATA DUMP REQUEST command.
--
-- Parameters:
--  - header: SysEx header for the messages, including the unit identifier 
--    of the target device.
--
-- Returns:
--  - msgs: a list of one octet string with the encoded message.
function encode_current_program_dump_command( header ) -- -> msgs
   return { header .. midi.hex_to_octets( "10 F7" ) }
end -- encode_current_program_dump_command()


-- Construct a PROGRAM DATA DUMP REQUEST command.
--
-- Parameters:
--  - header: SysEx header for the messages, including the unit identifier 
--    of the target device.
--  - slot: requested program number.
--
-- Returns:
--  - msgs: a list of one octet string with the encoded message.
function encode_program_dump_command( header, slot  ) -- -> msgs
   local lsb, msb
   
   if slot >=1 and slot <= 200 then
      slot = slot - 1
      lsb = slot & 0x7F
      msb = slot >> 7
      return { header .. midi.hex_to_octets( { 0x1C, lsb, msb, 0xF7 } ) }
   end
end -- encode_current_pattern_dump_command()


-- Construct a GLOBAL DATA DUMP REQUEST command.
--
-- Parameters:
--  - header: SysEx header for the messages, including the unit identifier 
--    of the target device.
--
-- Returns:
--  - msgs: a list of one octet string with the encoded message.
function encode_global_data_dump_command( header ) -- -> msgs
   return { header .. midi.hex_to_octets( { 0x0E, 0xF7 } ) }
end -- encode_global_data_dump_command()


-- Decode a CURRENT PROGRAM DATA DUMP message.
--
-- Parameters:
--  - msg: the message to decode.
--
-- Returns:
--  - record: octet string, program data;
function decode_current_program_dump( msg ) -- -> record
   local record
   
   if #msg >= 520 then
      return midi.unpack( string.sub( msg, 8, -2 ) )
   end
end -- decode_current_program_dump()


-- Decode a PROGRAM DATA DUMP message.
--
-- Parameters:
--  - msg: the message to decode.
--
-- Returns:
--  - record: program data (octet string);
--  - slot: slot number of the program in the source device;
function decode_program_dump( msg ) -- -> record, slot
   local record, slot
   
   if #msg >= 522 then
      slot = string.byte( msg, 8 ) + (string.byte( msg, 9 ) << 7) + 1
      if slot >= 1 and slot <= 200 then
         record = midi.unpack( string.sub( msg, 10, -2 ) )
         return record, slot
      end
   end
end -- decode_program_dump()


-- Decode a GLOBAL DATA DUMP message.
--
-- Parameters:
--  - msg: the message to decode.
--
-- Returns:
--  - record: octet string, globals data record;
function decode_global_data_dump( msg ) -- -> record
   if #msg >= 118 then
      return midi.unpack( string.sub( msg, 8, -2 ) )
   end
end -- decode_global_data_dump()


-- Encode a CURRENT PROGRAM DATA DUMP message from the given data record. If
-- a new name is given for the program, the name will be used to construct
-- the message, otherwise the exising name in the given program data will
-- be used.
--
-- Parameters:
--  - records: list of one octet string containing the program data;
--  - header: SysEx header for the message, including the unit identifier 
--    of the target device.
--  - name: optional program name.

-- Returns:
--  - msgs: list of one octet string, encoded message.
function encode_current_program_dump( records, header, name ) -- -> msgs
   local record
   
   record = records[1] 
   if #records ~= 1 or type( record ) ~= "string" or #record < 448 or
      string.sub( record, 1, 4 ) ~= "PROG" then
      print( "Minilogue encode_current_program_dump(): invalid records argument" )
      return nil -- invalid argument
   end 
   
   if type( name ) == "string" then
      record = set_program_name( record, name )
   end
   return { header .. string.char( 0x40 ) .. midi.pack( record ) .. string.char( 0xF7 ) }
end -- encode_current_program_dump()


-- Encode a PROGRAM DATA DUMP message from the given data record. If
-- a new name is given for the program, the name will be used to construct
-- the message, otherwise the exising name in the given program data will
-- be used.
--
-- Parameters:
--  - records: list of one octet string containing the program data;
--  - header: SysEx header for the message, including the unit identifier 
--    of the target device;
--  - slot: destination stored program slot number;
--  - name: optional program name.
--
-- Returns:
--  - msgs: list of octet strings, encoded messages.
function encode_program_dump( records, header, slot, name )
   local record, lsb, msb

   record = records[1]
   if #records ~= 1 or type( record ) ~= "string" or #record < 448 or
      string.sub( record, 1, 4 ) ~= "PROG" then
      print( "Minilogue encode_program_dump(): invalid records argument" )
      return nil -- invalid argument
   end
   
   slot = slot - 1
   lsb = slot & 0x7F
   msb = slot >> 7   
   if type( name ) == "string" then
      record = set_program_name( record, name )
   end
   return { header .. midi.hex_to_octets( { 0x4C, lsb, msb } ) ..
      midi.pack( record ) .. string.char( 0xF7 ) }
end -- encode_program_dump()


-- Encode a GLOBAL DATA DUMP message from the given data record.
--
-- Parameters:
--  - records: list of one octet string, global parameter data;
--  - header: SysEx header for the message, including the unit identifier 
--    of the target device.
--
-- Returns:
--  - msgs: list of one octet string, encoded message.
function encode_global_data_dump( records, header ) -- -> msgs
   local record, unit

   record = records[1]
   if #records ~= 1 or type( record ) ~= "string" or #record < 96 or 
      string.sub( record, 1, 4 ) ~= "GLOB" then
      print( "Minilogue encode_global_data_dump(): invalid records argument" )
      return nil -- invalid argument
   end
   
   -- The unit identifier (GLOBAL CHANNEL) is encoded in the 18th byte of the
   -- global data record. Set this to the unit identifier in the given SysEx message
   -- header to prevent changing the unit's identifier when the globals are applied.
   unit = string.byte( header, 3 ) & 0x0F
   record = string.sub( record, 1, 17 ) .. string.char( unit ) .. string.sub( record, 19 )
   return { header .. string.char( 0x51 ) .. midi.pack( record ) .. string.char( 0xF7 ) }
end -- encode_global_data_dump()


-- MODULE FUNCTIONS:
local model = {}


function model.info() -- -> info
   return {
      specification = 2,
      name = "Korg Minilogue",
      source = "Old Blue Bike Software inc.",
      version = "0.1",
      icon = "*.png", -- look for file with same path as this file with '.png' appended
      manufacturer = "42",
      family = "2C 01",
      unit_first = 0x00,
      unit_last = 0x0F,
      unit_factory = 0x00,
      slots = 200,
      timeout = 500 }
end -- model.info()


function model.globals() --> globals
   return { "Settings" }
end -- model.globals()


function model.decode_software_version( msg ) -- -> sw_ver
   local mam, mal, mim, mil

   if type( msg ) ~= "string" or #msg ~= 4 then 
      print( "Minilogue decode_software_version(): invalid argument")
      return nil -- incorrect length
   end

   mil = string.byte( msg, 1 )
   mim = string.byte( msg, 2 )
   mal = string.byte( msg, 3 )
   mam = string.byte( msg, 4 )
   if mil > 0x7F or mim > 0x7F or mal > 0x7F or mam > 0x7F then
      print( "Minilogue decode_software_version(): invalid version information" )
      return nil -- value out of range
   end

   return (mam << 7) | mal .. "." .. (mim << 7) | mil
end


function model.dump_program_command( config, slot ) -- -> msgs, header, max_rsps
   local header, msg

   header = get_header( config )
   if header == nil then
      return nil -- invalid configuration
   end
   
   if slot == nil or slot == 0 then
      msgs = encode_current_program_dump_command( header )
   elseif type( slot ) == "number" then
      msgs = encode_program_dump_command( header, slot )
   else
      print( "Minilogue dump_program_command(): invalid slot argument" )
      return nil
   end
   
   if type( msgs ) == "table" then
      return msgs, header, 1
   end
end -- model.dump_program_command()


function model.dump_globals_command( config, globals ) -- -> msgs, header, max_rsps
   local msgs, header

   header =get_header( config )
   if header == nil then
      return nil -- invalid configuration
   end

   if globals == "Settings" then
      msgs = encode_global_data_dump_command( header )
   elseif globals == "Microtunings" then
      msgs = encode_microtunings_dump_command( header )
   elseif globals == "User Modules" then
      msgs = encode_user_modules_dump_command( header )
   else
      print( "Minilogue dump_globals_command(): unknown globals \"" .. globals .. '\"' )
      return nil -- invalid configuration
   end

   if type( msgs ) == "table" then
      return msgs, header, 1
   end
end -- model.dump_globals_command()


function model.decode( msgs ) -- -> records
   local records, msg, ident, last_ident, record, name, slot

   if type( msgs ) ~= "table" or #msgs == 0 then
      print( "Minilogue decode(): invalid msgs argument")
      return nil -- invalid argument
   end

   records = {}
   for i = 1, #msgs do
      msg = msgs[i]

      if type( msg ) == "string" and #msg >= 8 and
         string.sub( msg, 1, 2 ) == midi.hex_to_octets( "F0 42" ) and
         string.sub( msg, 4, 6 ) == midi.hex_to_octets( "00 01 2C" ) and
         string.sub( msg, -1 ) == string.char( 0xF7 ) then
         -- Valid Minilogue SysEx message:
         last_ident = ident
         ident = string.byte( msg, 7 )
         
         if ident == 0x40 then
            -- decode CURRENT PROGRAM DATA DUMP message:
            record = decode_current_program_dump( msg )
            if type( record ) == "string" then
               records[#records + 1] = "program:0"
               name = get_program_name( record )
               if type( name ) == "string" then
                  records[#records + 1] = "name:" .. name
               end
               records[#records + 1] = "data:" .. record
            end
            
         elseif ident == 0x4C then
            -- decode PROGRAM DATA DUMP message:
            record, slot = decode_program_dump( msg )
            if type( record ) == "string" and type( slot ) == "number" then
               records[#records + 1] = "program:" .. slot
               name = get_program_name( record )
               if type( name ) == "string" then
                  records[#records + 1] = "name:" .. name
               end
               records[#records + 1] = "data:" .. record
            end
            
         elseif ident == 0x51 then
            -- decode GLOBAL DATA DUMP message:
            record = decode_global_data_dump( msg )
            if type( record ) == "string" then
               records[#records + 1] = "globals:Settings"
               records[#records + 1] = "data:" .. record
            end
           
         end
      end
   end
   
   return records
end -- model.decode()


function model.load_program_command( config, records, slot ) -- -> msgs
   local header, msg, record

   header = get_header( config )
   if type( header ) ~= "string" then
      return nil -- invalid configuration
   end
   if type( records ) ~= "table" or #records == 0 then
      print( "Minilogue load_program_command(): invalid records argument")
      return nil -- invalid argument
   end
   
   if slot == nil or slot == 0 then
      return encode_current_program_dump( records, header, name )
   elseif type( slot ) == "number" and slot >= 1 and slot <= 200 then
      return encode_program_dump( records, header, slot, name )
   else
      print( "Minilogue load_program_command(): invalid slot argument")
   end
end -- model.load_program_command()


function model.load_globals_command( config, globals, records ) -- -> msgs
   local header

   header = get_header( config )
   if header == nil then
      return nil -- invalid configuration
   end
   if type( records ) ~= "table" or #records == 0 then
      print( "Minilogue load_globals_command(): invalid records argument")
      return nil -- invalid argument
   end

   if globals == "Settings" then
      return encode_global_data_dump( records, header )
   elseif globals == "Microtunings" then
      return encode_microtunings_dump( records, header )
   elseif globals == "User Modules" then
      return encode_user_modules_dump( records, header )
   else
      print( "Minilogue load_globals_command(): unknown globals \"" .. globals .. '\"' )
   end
end -- model.load_globals_command()


return model


-- EOF minilogue.lua
