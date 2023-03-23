-- minilogueXD.lua
--
-- MIDI Model Description (MMD) for Korg Minilogue XD Synthesizers.
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


-- MIDI MODEL DESCRIPTION (MMD) for the Korg Minilogue XD
-- ======================================================
--
-- Identification:
-- ---------------
--
-- The Minilogue XD responds to the standard device inquiry IDENTITY REQUEST
-- message as follows:
--
--                 F0 7E 0g 06 02 42 51 01 00 00 mi mi ma ma F7
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
--  - unit ID: differentiates between multiple Minilogue XDs when they
--    are connected to the same MIDI output through a MIDI splitter or
--    or other method. Corresponds to the value of the "MIDI Ch" parameter
--    in the "GLOBAL EDIT -> Global 4" menu on the device (0x00-0x0F);
--  - manufacturer code = 0x42 (Korg);
--  - family code = 0x0151 (Minilogue XD);
--  - member code = 0x0000 (unused).
--
-- Program Data:
-- -------------
--
-- The active program can be retrieved from the Minilogue by transmitting
-- a CURRENT PROGRAM DATA DUMP REQUEST message:
--
--                          F0 42 3g 00 01 51 10 F7
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
      print( "MinilogueXD get_header(): unit identfier missing from supplied configuration" )
      return nil -- invalid argument
   end
   unit = config.unit
   if type( unit ) ~= "number" or unit < 0 or unit > 15 then
      print( "MinilogueXD get_header(): unit identifier out of valid range" )
      return nil -- out of range
   end
   return midi.hex_to_octets( { "F0 42", 0x30 | unit, "00 01 51" } )
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
   
   if slot >=1 and slot <= 500 then
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


-- Construct a sequence of USER SCALE DATA DUMP REQUEST and USER OCTAVE DATA DUMP REQUEST
-- messages to command the Minilogue XD to transmit all microtunings tables.
--
-- Parameters:
--  - header: SysEx header for the message, including the unit identifier 
--    of the target device.
--
-- Returns:
--  - msgs: a list of 12 octet strings, encoded messages (6 x user scales tables,
--    6 x user octave tables).
function encode_microtunings_dump_command( header )
   local msgs, count
   
   msgs = {}
   count = 0
   for i = 0, 5 do
      count = count + 1
      msgs[count] = header .. midi.hex_to_octets( { 0x14, i, 0xF7 } )
   end
   for i = 0, 5 do
      count = count + 1
      msgs[count] = header .. midi.hex_to_octets( { 0x15, i, 0xF7 } )
   end
   return msgs
end -- encode_microtunings_dump_command()


-- Construct a sequence of USER SLOT STATUS REQUEST and USER SLOT DATA REQUEST
-- messages to command the Minilogue XD to transmit all user modules.
--
-- Parameters:
--  - header: SysEx header for the message, including the unit identifier 
--    of the target device.
--
-- Returns:
--  - msgs: a list of 96 octet strings, encoded messages. One slot status and 
--    one slot data dump requests for each of:
--     . 16 slots for each of the 'modfx' and 'osc' modules;
--     . 8 slots for each of the 'delfx' and 'revfx' modules.
function encode_user_modules_dump_command( header )
   local msgs, count, module, max_slot, slot
   msgs = {}
   count = 0

   -- For each user module ('modfx' (1), 'delfx' (2), 'revfx' (3) and 'osc' (4)):
   --  - For each module slot (0-15 for 'modfx' and 'osc'; 0-7 for 'delfx' and 'revfx'):
   --     - USER SLOT STATUS REQUEST;
   --     - USER SLOT DATA REQUEST;
   for module = 1, 4 do
      if module == 1 or module == 4 then
         max_slot = 15
      else
         max_slot = 7
      end
      for slot = 0, max_slot do
         count = count + 1
         msgs[count] = header .. midi.hex_to_octets( { 0x19, module, slot, 0xF7 } )
         count = count + 1
         msgs[count] = header .. midi.hex_to_octets( { 0x1A, module, slot, 0xF7 } )
      end
   end
   return msgs
end -- encode_user_modules_dump_command()


-- Decode a CURRENT PROGRAM DATA DUMP message.
--
-- Parameters:
--  - msg: the message to decode.
--
-- Returns:
--  - record: octet string, program data;
function decode_current_program_dump( msg ) -- -> record
   local record
   
   if #msg >= 1179 then
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
   
   if #msg >= 1181 then
      slot = string.byte( msg, 8 ) + (string.byte( msg, 9 ) << 7) + 1
      if slot >= 1 and slot <= 500 then
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
   if #msg >= 80 then
      return midi.unpack( string.sub( msg, 8, -2 ) )
   end
end -- decode_global_data_dump()


-- Decode a USER SCALE DATA DUMP message.
--
-- Parameters:
--  - msg: the message to decode.
--
-- Returns:
--  - record: an octet string of the form "<tbl><idx><data>" where:
--    . <tbl> (first byte) coded as 0x44, indicates that the record contains user scale
--      data;
--    . <idx> (second byte) is the index of the table (0-5)
--    . <data> (third byte onwards) is the user scale data.
function decode_user_scale_data_dump( msg ) -- -> record
   local idx, data
   
   if #msg >= 393 then
      idx = string.byte( msg, 8 )
      if idx <= 5 then
         return string.char( 0x44 ) .. string.char( idx ) .. string.sub( msg, 9, -2 )
      end
   end
end -- decode_user_scale_data_dump()


-- Decode a USER OCTAVE DATA DUMP message.
--
-- Parameters:
--  - msg: the message to decode.
--
-- Returns:
--  - record: an octet string of the form "<tbl><idx><data>" where:
--    . <tbl> (first byte) coded as 0x45, indicates that the record contains user octave
--      data;
--    . <idx> (second byte) is the index of the table (0-5)
--    . <data> (third byte onwards) is the user octave data.
function decode_user_octave_data_dump( msg ) -- -> record
   local idx, data
   
   if #msg >= 45 then
      idx = string.byte( msg, 8 )
      if idx <= 5 then
         return string.char( 0x45 ) .. string.char( idx ) .. string.sub( msg, 9, -2 )
      end
   end
end -- decode_user_octave_data_dump()
      
      
-- Decode a USER SLOT STATUS message.
--
-- Parameters:
--  - msg: the message to decode.
--
-- Returns:
--  - record: octet string of the form "<type><module><slot><data>" where:
--     . <type> (first byte) is coded as 0x49, indicates that the record contains a slot
--       status;
--     . <module> (second byte) is the module identifier ('modfx':1, 'delfx':2, 'revfx':3, 
--       'osc':4);
--     . <slot> (third byte) is the module slot ('modfx' and 'osc': 0-15; 'delfx' and
--       'revfx': 0-7 )
--     . <data> (fourth byte onwards) is the data from the message.
function decode_user_slot_status( msg ) -- -> record
   local module, slot
   
   if #msg >= 10 then
      module = string.byte( msg, 8 )
      slot = string.byte( msg, 9 )
      if (module >= 1 and module <= 4) and
         ((module == 1 or module == 4) and slot <= 15) or
         ((module == 2 or module == 3) and slot <= 7) then
         return string.char( 0x49 ) .. string.char( module ) .. string.char( slot ) .. 
            midi.unpack( string.sub( msg, 10, -2 ) )
      end
   end
end -- decode_user_slot_status()


-- Decode a USER SLOT DATA message.
--
-- Parameters:
--  - msg: the message to decode.
--
-- Returns:
--  - record: octet string of the form "<type><module><slot><data>" where:
--     . <type> (first byte) is coded as 0x49, indicates that the record contains a slot 
--       data;
--     . <module> (second byte) is the module identifier ('modfx':1, 'delfx':2, 'revfx':3, 
--       'osc':4);
--     . <slot> (third byte) is the module slot ('modfx' and 'osc': 0-15; 'delfx' and
--       'revfx': 0-7 )
--     . <data> (fourth byte onwards) is the data from the message. 
function decode_user_slot_data( msg ) -- -> record
   local module, slot
   
   if #msg >= 10 then
      module = string.byte( msg, 8 )
      slot = string.byte( msg, 9 )
      if (module >= 1 and module <= 4) and
         ((module == 1 or module == 4) and slot <= 15) or
         ((module == 2 or module == 3) and slot <= 7) then
         return string.char( 0x4A ) .. string.char( module ) .. string.char( slot ) .. 
            midi.unpack( string.sub( msg, 10, -2 ) )
      end
   end
end -- decode_user_slot_status()


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
   if #records ~= 1 or type( record ) ~= "string" or #record < 1024 or
      string.sub( record, 1, 4 ) ~= "PROG" then
      print( "MinilogueXD encode_current_program_dump(): invalid records argument" )
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
   if #records ~= 1 or type( record ) ~= "string" or #record < 1024 or
      string.sub( record, 1, 4 ) ~= "PROG" then
      print( "MinilogueXD encode_program_dump(): invalid records argument" )
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
   if #records ~= 1 or type( record ) ~= "string" or #record < 63 or
      string.sub( record, 1, 4 ) ~= "GLOB" then
      print( "MinilogueXD encode_global_data_dump(): invalid records argument" )
      return nil -- invalid argument
   end
   
   -- The unit identifier (GLOBAL CHANNEL) is encoded in the 17th byte of the
   -- global data record. Set this to the unit identifier in the given SysEx message
   -- header to prevent changing the unit's identifier when the globals are applied.
   unit = string.byte( header, 3 ) & 0x0F
   record = string.sub( record, 1, 16 ) .. string.char( unit ) .. string.sub( record, 18 )
   return { header .. string.char( 0x51 ) .. midi.pack( record ) .. string.char( 0xF7 ) }
end -- encode_global_data_dump()


-- Construct a list of USER SCALE DATA DUMP and USER OCTAVE DATA DUMP messages from 
-- given list of microtunings records.
--
-- Parameters:
--  - records: a list of octet strings of the form "<tbl><idx><data>" where:
--     . <tbl> (first byte) indicates that the record contains a user scale data
--       (0x44) or user octave data (0x45);
--     . <idx> (second byte) is the index of the table (0-5)
--     . <data> (third byte onwards) is the user scale data.
--  - header: SysEx header for the message, including the unit identifier 
--    of the target device.
--
-- Returns:
--  - msgs: list of octet string, encoded messages.
function encode_microtunings_dump( records, header )
   local msgs, record, tbl, idx

   if type( records ) ~= "table" or #records == 0 then
      print( "MinilogueXD encode_microtunings_dump(): invalid records argument" )
      return nil -- invalid argument
   end
   msgs = {}
   for i = 1, #records do
      record = records[i]
      if type( record ) ~= "string" or #record < 3 then
         print( "MinilogueXD encode_microtunings_dump(): invalid records argument" )
         return nil
      end
      tbl = string.byte( record, 1 )
      idx = string.byte( record, 2 )
      if (tbl ~= 0x44 and tbl ~= 0x45) or (idx > 5) or
         (tbl == 0x44 and #record < 384) or (tbl == 0x45 and #record < 36) then
         print( "MinilogueXD encode_microtunings_dump(): invalid records argument" )
         return nil
      end
      msgs[i] = header .. string.sub( record, 1, 2 ) .. string.sub( record, 3 ) ..
         string.char( 0xF7 )
   end
   return msgs
end -- encode_microtunings_dump()


-- Construct a list of USER SLOT STATUS and USER SLOT DATA messages from given user 
-- modules data records.
--
-- Parameters:
--  - record: octet string of the form "<type><module><slot><data>" where:
--     . <type> (first byte) indicates that the record contains a slot
--       status (0x49) or slot data (0x4A);
--     . <module> (second byte) is the module identifier ('modfx':1, 'delfx':2, 'revfx':3, 
--       'osc':4);
--     . <slot> (third byte) is the module slot ('modfx' and 'osc': 0-15; 'delfx' and
--       'revfx': 0-7 )
--     . <data> (fourth byte onwards) is the data from the message.
--  - header: SysEx header for the message, including the unit identifier 
--    of the target device.
--
-- Returns:
--  - msgs: list of octet string, encoded messages.
function encode_user_modules_dump( records, header )
   local msgs, record, type_code, module, slot

   if type( records ) ~= "table" or #records == 0 then
      print( "MinilogueXD encode_user_modules_dump(): invalid records argument" )
      return nil -- invalid argument
   end
   msgs = {}
   for i = 1, #records do
      record = records[i]
      if type( record ) ~= "string" or #record < 3 then
         print( "MinilogueXD encode_user_modules_dump(): invalid records argument" )
         return nil
      end
      type_code = string.byte( record, 1 )
      module = string.byte( record, 2 )
      slot = string.byte( record, 3 )
      if (type_code ~= 0x49 and type_code ~= 0x4A) or
         (module < 1 or module > 4) or
         ((module == 1 or module == 4) and slot > 15) or
         ((module == 2 or module == 3) and slot > 7) then
         print( "MinilogueXD encode_user_modules_dump(): invalid records argument" )
         return nil
      end
      msgs[i] = header .. string.sub( record, 1, 3 ) .. midi.pack( string.sub( record, 4 ) ) .. 
         string.char( 0xF7 )
   end
   return msgs
end -- encode_user_modules_dump()


-- MODULE FUNCTIONS:
local model = {}


function model.info() -- -> info
   return {
      specification = 2,
      name = "Korg Minilogue XD",
      source = "Old Blue Bike Software inc.",
      version = "2.1",
      icon = "*.png", -- look for file with same path as this file with '.png' appended
      manufacturer = "42",
      family = "51 01",
      unit_first = 0x00,
      unit_last = 0x0F,
      unit_factory = 0x00,
      slots = 500,
      timeout = 500 }
end -- model.info()


function model.globals() --> globals
   return { 
      "Settings",
      "Microtunings",
      "User Modules" }
end -- model.globals()


function model.decode_software_version( msg ) -- -> sw_ver
   local mam, mal, mim, mil

   if type( msg ) ~= "string" or #msg ~= 4 then 
      print( "MinilogueXD decode_software_version(): invalid argument")
      return nil -- incorrect length
   end

   mil = string.byte( msg, 1 )
   mim = string.byte( msg, 2 )
   mal = string.byte( msg, 3 )
   mam = string.byte( msg, 4 )
   if mil > 0x7F or mim > 0x7F or mal > 0x7F or mam > 0x7F then
      print( "MinilogueXD decode_software_version(): invalid version information" )
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
      print( "MinilogueXD dump_program_command(): invalid slot argument" )
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
      print( "MinilogueXD dump_globals_command(): unknown globals \"" .. globals .. '\"' )
      return nil -- invalid configuration
   end

   if type( msgs ) == "table" then
      return msgs, header, 1
   end
end -- model.dump_globals_command()


function model.decode( msgs ) -- -> records
   local records, msg, ident, last_ident, record, name, slot

   if type( msgs ) ~= "table" or #msgs == 0 then
      print( "MinilogueXD decode(): invalid msgs argument")
      return nil -- invalid argument
   end

   records = {}
   for i = 1, #msgs do
      msg = msgs[i]

      if type( msg ) == "string" and #msg >= 8 and
         string.sub( msg, 1, 2 ) == midi.hex_to_octets( "F0 42" ) and
         string.sub( msg, 4, 6 ) == midi.hex_to_octets( "00 01 51" ) and
         string.sub( msg, -1 ) == string.char( 0xF7 ) then
         -- Valid Minilogue XD SysEx message:
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
            
         elseif ident == 0x44 then
            -- decode USER SCALE DATA DUMP message:
            record = decode_user_scale_data_dump( msg )
            if type( record ) == "string" then
               if last_ident ~= 0x44 and last_ident ~= 0x45 then
                  records[#records + 1] = "globals:Microtunings"
               end
               records[#records + 1] = "data:" .. record
            end
            
         elseif ident == 0x45 then
            -- decode USER OCTAVE DATA DUMP message:
            record = decode_user_octave_data_dump( msg )
            if type( record ) == "string" then
               if last_ident ~= 0x44 and last_ident ~= 0x45 then
                  records[#records + 1] = "globals:Microtunings"
               end
               records[#records + 1] = "data:" .. record
            end
            
         elseif ident == 0x49 then
            -- decode USER SLOT STATUS message:
            record = decode_user_slot_status( msg )
            if type( record ) == "string" then
               if last_ident ~= 0x49 and last_ident ~= 0x4A then
                  records[#records + 1] = "globals:User Modules"
               end
               records[#records + 1] = "data:" .. record
            end         
            
         elseif ident == 0x4A then
            -- decode USER SLOT DATA message:
            record = decode_user_slot_data( msg )
            if type( record ) == "string" then
               if last_ident ~= 0x49 and last_ident ~= 0x4A then
                  records[#records + 1] = "globals:User Modules"
               end
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
      print( "MinilogueXD load_program_command(): invalid records argument")
      return nil -- invalid argument
   end
   
   if slot == nil or slot == 0 then
      return encode_current_program_dump( records, header, name )
   elseif type( slot ) == "number" and slot >= 1 and slot <= 500 then
      return encode_program_dump( records, header, slot, name )
   else
      print( "MinilogueXD load_program_command(): invalid slot argument")
   end
end -- model.load_program_command()


function model.load_globals_command( config, globals, records ) -- -> msgs
   local header

   header = get_header( config )
   if header == nil then
      return nil -- invalid configuration
   end
   if type( records ) ~= "table" or #records == 0 then
      print( "MinilogueXD load_globals_command(): invalid records argument")
      return nil -- invalid argument
   end

   if globals == "Settings" then
      return encode_global_data_dump( records, header )
   elseif globals == "Microtunings" then
      return encode_microtunings_dump( records, header )
   elseif globals == "User Modules" then
      return encode_user_modules_dump( records, header )
   else
      print( "MinilogueXD load_globals_command(): unknown globals \"" .. globals .. '\"' )
   end
end -- model.load_globals_command()


return model


-- EOF minilogueXD.lua
