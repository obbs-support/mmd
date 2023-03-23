-- electribe2.lua
--
-- MIDI MODEL DESCRIPTION (MMD) for Korg Electribe 2 Music 
-- Production Stations
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


-- MIDI MODEL DESCRIPTION (MMD) for the Korg Electribe 2
-- =====================================================
--
-- Identification:
-- ---------------
--
-- The Electribe 2 responds to the standard device inquiry IDENTITY REQUEST
-- message as follows:
--
--                 F0 7E 0g 06 02 42 23 01 00 00 ma mi re xx F7
--                       --       -- ----- ----- -- -- --
--                        |        |   |     |    |  |  |
--            Unit ID  ---+        |   |     |    |  |  |
--                                 |   |     |    |  |  |
--         Manufacturer ID (Korg) -+   |     |    |  |  |
--                                     |     |    |  |  |
--       Family ID (Electribe)  -------+     |    |  |  |
--                                           |    |  |  |
--                 Member ID (unused)  ------+    |  |  |
--                                                |  |  |
--                  Software major version  ------+  |  |
--                                                   |  |
--                     Software minor version  ------+  |
--                                                      |
--                      Software version release  ------+
--
-- where:
--  - unit ID: differentiates between multiple Electribe 2s when they
--    connected to the same MIDI output through a MIDI splitter or
--    or other method. Corresponds to the value of the "GLOBAL MIDI CH." 
--    parameter as set in the "GLOBAL PARAMETERS" menu of the Electribe 2
--    (0x00-0x0F);
--  - manufacturer code = 0x42 (Korg);
--  - family code = 0x0123 (Electribe 2);
--  - member code = 0x0000 (unused).
--
-- Program Data:
-- -------------
--
-- The Electribe 2 stores 250 beat patterns, any one of which can be played 
-- and/or edited at any given time. A complete song usually consists of 
-- multiple patterns. 
--
-- Any of the 250 stored patterns can be queried and transmitted via 
-- SysEx message by sending a PATTERN DATA DUMP request to the Electribe,
-- as follows:
--
--                          F0 42 3g 00 01 23 4C ll mm F7
--                             -- -- --------    -- --
--                              |  |     |        |  |
--     Manufacturer ID (Korg)  -+  |     |        |  |
--                                 |     |        |  |
--                  Device ID   ---+     |        |  |
--                                       |        |  |
--              Product ID (Electribe) --+        |  |
--                                                |  |
--                         Pattern number LSB  ---+  |
--                                                   |
--                            Pattern number MSB  ---+
--
-- where:
--  - Device ID: 'g' is the MIDI channel number of the device as set 
--    by the "GLOBAL MIDI CH." parameter in "GLOBAL PARAMETERS" of the 
--    Electribe 2, and also the value returned in bits 0-3 of the Device 
--    ID in the IDENTITY REPLY message;
--  - Pattern number LSB/MSB: value in ramge [0-249] for patterns 1-250
--    ("00 00" to "79 01").
--
-- The single pattern that is current selected for editing can be 
-- queried with a CURRENT PATTERN DATA DUMP REQUEST message, which is 
-- similar to the PATTERN DATA DUMP request except missing the number of 
-- the stored pattern to transmit:
--
--                          F0 42 3g 00 01 23 10 F7
--                             -- -- -------- 
--                              |  |     |    
--     Manufacturer ID (Korg)  -+  |     |    
--                                 |     |    
--                  Device ID   ---+     |    
--                                       |    
--              Product ID (Electribe) --+    
--

-- HELPER SUBROUTINES:

-- Remove trailing whitespaces from given string:
function trim( s )
   local i

   i = #s
   while i >= 1 and string.sub( s, i, i ) == " " do
      i = i - 1
   end
   return string.sub( s, 1, i )
end -- trim()


-- Construct SysEx message header using unit number in given configuration:
function get_header( config )
   local unit

   if type( config ) ~= "table" then 
      print( "Electribe2 get_header(): unit identfier missing from supplied configuration" )
      return nil -- invalid argument
   end
   unit = config.unit
   if type( unit ) ~= "number" or unit < 0 or unit > 15 then
      print( "Electribe2 get_header(): unit identifier out of valid range" )
      return nil -- out of range
   end

   return midi.hex_to_octets( { "F0 42", 0x30 | unit, "00 01 23" } )
end -- get_header()


-- Extract the name of a pattern from the given pattern data record.
--
-- Parameters:
--  - record: pattern data record.
--
-- Returns:
--  - name: name of the pattern or nil if the pattern is unnamed.
function get_pattern_name( record )
   local i
   
   i = 17 -- name field range 17-34 inclusive (length 18)
   while i <= 34 and string.byte( record, i ) ~= 0 do
      i = i + 1
   end
   if i > 17 then
      return trim( string.sub( record, 17, i - 1 ) )
   end
end -- get_pattern_name()


-- Replace the name of a pattern in the given pattern data record.
--
-- Parameters:
--  - record: pattern data record;
--  - name: new name of the pattern.
--
-- Returns:
--  - record: the updated pattern data record.
function set_pattern_name( record, name ) -- -> record
   name = name .. string.rep( string.char( 0 ), 18 )
   record = string.sub( record, 1, 16 ) .. string.sub( name, 1, 18 ) ..
      string.sub( record, 35 )
   return record
end -- set_pattern_name()


-- Construct an CURRENT PATTERN DATA DUMP REQUEST command.
--
-- Parameters:
--  - header: SysEx header for the messages, including the unit identifier 
--    of the target device.
--
-- Returns:
--  - msgs: a list of one octet string with the encoded message.
function encode_current_pattern_dump_command( header ) -- -> msgs
   return { header .. midi.hex_to_octets( "10 F7" ) }
end -- encode_current_pattern_dump_command()


-- Construct an PATTERN DATA DUMP REQUEST command.
--
-- Parameters:
--  - header: SysEx header for the messages, including the unit identifier 
--    of the target device.
--  - slot: requested pattern number, 1-250.
--
-- Returns:
--  - msgs: a list of one octet string with the encoded message.
function encode_pattern_dump_command( header, slot  ) -- -> msgs
   local lsb, msb
   
   if slot >=1 and slot <= 250 then
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


-- Decode a CURRENT PATTERN DATA DUMP message.
--
-- Parameters:
--  - msg: the message to decode.
--
-- Returns:
--  - record: octet string, pattern data;
function decode_current_pattern_dump( msg ) -- -> record
   local record
   
   if #msg == 18733 then
      return midi.unpack( string.sub( msg, 8, -2 ) )
   end
end -- decode_current_pattern_dump()


-- Decode a PATTERN DATA DUMP message.
--
-- Parameters:
--  - msg: the message to decode.
--
-- Returns:
--  - record: program data (octet string);
--  - slot: slot number of the pattern in the source device;
function decode_pattern_dump( msg ) -- -> record, slot, name
   local record, slot
   
   if #msg == 18735 then
      slot = string.byte( msg, 8 ) + (string.byte( msg, 9 ) << 7) + 1
      if slot >= 1 and slot <= 250 then
         record = midi.unpack( string.sub( msg, 10, -2 ) )
         return record, slot
      end
   end
end -- decode_pattern_dump()


-- Decode a GLOBAL DATA DUMP message.
--
-- Parameters:
--  - msg: the message to decode.
--
-- Returns:
--  - record: octet string, globals data record;
function decode_global_data_dump( msg ) -- -> record
   if #msg == 301  then
      return midi.unpack( string.sub( msg, 8, -2 ) )
   end
end -- model.decode_globals()


-- Encode a CURRENT PATTERN DATA DUMP message from the given data record. If
-- a new name is given for the pattern, the name will be used to construct
-- the message, otherwise the exising name in the given pattern data will
-- be used.
--
-- Parameters:
--  - records: list of one octet string containing the pattern data;
--  - header: SysEx header for the message, including the unit identifier 
--    of the target device;
--  - name: optional new name for the pattern. 
--
-- Returns:
--  - msgs: list of one octet string, encoded message.
function encode_current_pattern_dump( records, header, name ) -- -> msgs
   local record
   
   record = records[1] 
   if #records ~= 1 or type( record ) ~= "string" or #record ~= 16384 then
      print( "Electribe2 encode_current_pattern_dump(): invalid records argument" )
      return nil -- invalid argument
   end 
   
   if type( name ) == "string" then
      record = set_pattern_name( record, name )
   end
   return { header .. string.char( 0x40 ) .. midi.pack( record ) .. string.char( 0xF7 ) }
end -- encode_current_pattern_dump()


-- Encode a PATTERN DATA DUMP message from the given data record. If
-- a new name is given for the program, the name will be used to construct
-- the message, otherwise the exising name in the given program data will
-- be used.
--
-- Parameters:
--  - records: list of one octet string containing the pattern data;
--  - header: SysEx header for the message, including the unit identifier 
--    of the target device;
--  - slot: destination stored pattern slot number, 1-250;
--  - name: optional program name.
--
-- Returns:
--  - msgs: list of octet strings, encoded messages.
function encode_pattern_dump( records, header, slot, name )
   local record, lsb, msb

   record = records[1] 
   if #records ~= 1 or type( record ) ~= "string" or #record ~= 16384 then
      print( "Electribe2 encode_pattern_dump(): invalid records argument" )
      return nil -- invalid argument
   end
   
   slot = slot - 1
   lsb = slot & 0x7F
   msb = slot >> 7   
   if type( name ) == "string" then
      record = set_pattern_name( record, name )
   end
   return { header .. midi.hex_to_octets( { 0x4C, lsb, msb } ) ..
      midi.pack( record ) .. string.char( 0xF7 ) }
end -- encode_pattern_dump()


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
   if #records ~= 1 or type( record ) ~= "string" or #record ~= 256 then
      print( "Electribe2 encode_global_data_dump(): invalid records argument" )
      return nil -- invalid argument
   end
   
   -- The unit identifier (GLOBAL CHANNEL) is encoded in the 42nd byte of the
   -- global data record. Set this to the unit identifier in the given SysEx message
   -- header to prevent changing the unit's identifier when the globals are applied.
   unit = string.byte( header, 3 ) & 0x0F
   record = string.sub( record, 1, 41 ) .. string.char( unit ) .. string.sub( record, 43 )   
   return { header .. string.char( 0x51 ) .. midi.pack( record ) .. string.char( 0xF7 ) }
end -- encode_global_data_dump()


-- MODULE FUNCTIONS:
local model = {}


function model.info() -- -> model_info
   return {
      specification = 2,
      name = "Korg Electribe 2",
      source = "Old Blue Bike Software inc.",
      version = "2.0",
      icon = "*.png", -- look for file with same path as this file with '.png' appended
      manufacturer = "42",
      family = "23 01",
      unit_first = 0,
      unit_last = 15,
      unit_factory = 15,
      slots = 250,
      timeout = 190 }
end -- model.info()


function model.globals() --> globals
   return { "Settings" }
end -- model.globals()


function model.decode_software_version( msg ) -- -> sw_ver
   local ma, mi, re

   if type( msg ) ~= "string" or #msg ~= 4 then 
      print( "Electribe2 decode_software_version(): invalid argument")
      return nil -- incorrect length
   end

   ma = string.byte( msg, 1 )
   mi = string.byte( msg, 2 )
   re = string.byte( msg, 3 )
   if ma > 0x7F or mi > 0x7F or re > 0x7F then
      print( "Electribe2 decode_software_version(): invalid version information" )
      return nil -- value out of range
   end

   return ma .. "." .. mi .. "." .. re
end


function model.dump_program_command( config, slot ) -- -> msgs, header, max_rsps
   local header, msgs

   header = get_header( config )
   if header == nil then
      return nil -- invalid configuration
   end
   
   if slot == nil or slot == 0 then
      msgs = encode_current_pattern_dump_command( header )
   elseif type( slot ) == "number" then
      msgs = encode_pattern_dump_command( header, slot )
   else
      print( "Electribe2 dump_program_command(): invalid slot argument" )
      return nil
   end
   
   if type( msgs ) == "table" then
      return msgs, header, 1
   end
end -- model.dump_program_command()


function model.dump_globals_command( config, globals ) -- -> msgs, header, max_rsps
   local header, msgs

   header = get_header( config )
   if header == nil then
      return nil -- invalid configuration
   end

   if globals == "Settings" then      
      msgs = encode_global_data_dump_command( header )
   else
      print( "Electribe2 dump_globals_command(): unknown globals \"" .. globals .. '\"' )
      return nil -- invalid configuration
   end

   if type( msgs ) == "table" then
      return msgs, header, 1
   end
end -- model.dump_globals_command()


function model.decode( msgs ) -- -> records
   local records, msg, ident, record, name, slot
   
   if type( msgs ) ~= "table" or #msgs == 0 then
      print( "Electribe2 decode(): invalid msgs argument" )
      return nil -- invalid argument
   end

   records = {}
   for i = 1, #msgs do
      msg = msgs[i]

      if type( msg ) == "string" and #msg >= 9 and 
         string.sub( msg, 1, 2 ) == midi.hex_to_octets( "F0 42" ) and
         string.sub( msg, 4, 6 ) == midi.hex_to_octets( "00 01 23" ) and
         string.byte( msg, -1 ) == 0xF7 then
         -- Valid Korg Electribe 2 SysEx message:
         ident = string.byte( msg, 7 )
         
         if ident == 0x40 then
            -- CURRENT PATTERN DATA DUMP message:
            record = decode_current_pattern_dump( msg )
            if type( record ) == "string" then
               records[#records + 1] = "program:0"
               records[#records + 1] = "data:" .. record
               name = get_pattern_name( record )
               if type( name ) == "string" then
                  records[#records + 1] = "name:" .. name
               end
            end               
            
         elseif ident == 0x4C then
            -- PATTERN DATA DUMP message:
            record, slot = decode_pattern_dump( msg )
            if type( record ) == "string" and type( slot ) == "number" then
               records[#records + 1] = "program:" .. slot
               records[#records + 1] = "data:" .. record
               name = get_pattern_name( record )
               if type( name ) == "string" then
                  records[#records + 1] = "name:" .. name
               end
            end
            
         elseif ident == 0x51 then
            -- GLOBAL DATA DUMP message:
            record = decode_global_data_dump( msg )
            if type( record ) == "string" then
               records[#records + 1] = "globals:Settings"
               records[#records + 1] = "data:" .. record
            end

         end
      end -- if type( msg ) == "string" and
   end -- for i = 1, #msgs do
   
   return records
end -- model.decode()


function model.load_program_command( config, records, slot, name ) -- -> msgs
   local header, msg

   header = get_header( config )
   if type( header ) ~= "string" then
      return nil -- invalid configuration
   end
   if type( records ) ~= "table" or #records == 0 then
      print( "Electribe2 load_program_command(): invalid records argument")
      return nil -- invalid argument
   end
   
   if slot == nil or slot == 0 then
      return encode_current_pattern_dump( records, header, name )
   elseif type( slot ) == "number" and slot >= 1 and slot <= 1024 then
      return encode_pattern_dump( records, header, slot, name )
   else
      print( "Electribe2 load_program_command(): invalid slot argument")
   end  
end -- model.load_program_command()


function model.load_globals_command( config, globals, records ) -- -> msgs
   local header

   header = get_header( config )
   if type( header ) ~= "string" then
      return nil -- invalid configuration
   end
   if type( records ) ~= "table" or #records == 0 then
      print( "Electribe2 load_globals_command(): invalid records argument")
      return nil -- invalid argument
   end
   
   if globals == "Settings" then
      return encode_global_data_dump( records, header )
   else
      print( "Electribe2 load_globals_command(): unknown globals \"" .. globals .. '\"' )
   end
end -- model.local_globals_command()


return model


-- EOF electribe2.lua
