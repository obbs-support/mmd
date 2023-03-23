-- h9-harmonizer.lua
--
-- MIDI Model Description (MMD) for the Eventide H9 Harmonizer Pedal.
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


-- MIDI MODEL DESCRIPTION (MMD) for the Eventide H9 Harmonizer pedal
-- =================================================================
--
-- Identification:
-- ---------------
--
-- The H9 responds to the standard device inquiry IDENTITY REQUEST
-- message as follows:
--
--                 F0 7E gg 06 02 1C 00 06 15 00 ss ss ss ss xx ... F7
--                       --       -- ----- ----- ----------- ------
--                        |        |   |     |        |        |
--            Unit ID  ---+        |   |     |        |        |
--                                 |   |     |        |        |
--     Manufacturer ID (Eventide) -+   |     |        |        |
--                                     |     |        |        |
--                   Family ID  -------+     |        |        |
--                                           |        |        |
--                          Member ID  ------+        |        |
--                                                    |        |
--                      Software version  ------------+        |
--                                                             |
--                    Information string  ---------------------+ 
--
-- where:
--  - unit ID: differentiates between multiple H9 pedals when they
--    connected to the same MIDI output through a MIDI splitter or
--    or other method. Corresponds to the value of the "MIDI SysEx ID"
--    ("[SYS ID]") parameter as set in the "MIDI" section of the 
--    H9's system menu (0x01-0x10);
--  - manufacturer code = 0x1C (Eventide);
--  - family code = 0x0600;
--  - member code = 0x0015.
-- 
-- The information string is in XML  format (7-bit "clear" ASCII) and 
-- provides additional details about the device.
--
-- Program Data:
-- -------------
--
-- The H9 pedal holds 99 preset slots in persistent memory, in addition to 
-- to the active program in its edit buffer.  
--
-- The active program can be retrieved by sending a "program want" message 
-- to the unit as follows:
--
--                             F0 1C 70 gg 4E F7
--                                -- -- -- -- 
--                                 |  |  |  |
--    Manufacturer ID (Eventide)  -+  |  |  |
--                                    |  |  |
--                       Model ID  ---+  |  |
--                                       |  |
--                             Unit ID --+  |
--                                          |
--          Message ID ("program want")  ---+
--
-- The active program is encoded is a "program dump" message that can be
-- transmitted or received by the device:
--
--                             F0 1C 70 gg 4F xx ... 00 F7
--                                -- -- -- -- ------
--                                 |  |  |  |   |
--    Manufacturer ID (Eventide)  -+  |  |  |   |
--                                    |  |  |   |
--                       Model ID  ---+  |  |   |
--                                       |  |   |
--                             Unit ID --+  |   |
--                                          |   |
--          Message ID ("program dump")  ---+   |
--                                              |
--                  Program data  --------------+
--
-- Similarly all 99 presets can be retrieved at once by sending a "presets want"
-- message to the unit as follows:
--
--                             F0 1C 70 gg 48 F7
--                                -- -- -- -- 
--                                 |  |  |  |
--    Manufacturer ID (Eventide)  -+  |  |  |
--                                    |  |  |
--                       Model ID  ---+  |  |
--                                       |  |
--                             Unit ID --+  |
--                                          |
--          Message ID ("presets want")  ---+
--
-- The presets are encoded into a "presets dump" message that can be transmitted 
-- or received by the device:
--
--                             F0 1C 70 gg 49 xx ... 00 F7
--                                -- -- -- -- ------
--                                 |  |  |  |   |
--    Manufacturer ID (Eventide)  -+  |  |  |   |
--                                    |  |  |   |
--                       Model ID  ---+  |  |   |
--                                       |  |   |
--                             Unit ID --+  |   |
--                                          |   |
--          Message ID ("presets dump")  ---+   |
--                                              |
--                  Presets data  --------------+
--
-- The program data in a "program dump" message is in the same format as in the 
-- "presets dump" message: the presets data in a "presets dump" message is just a
-- concatenation of 99 program data records, one for each of the 99 presets. A 
-- "program dump" message may contain any number of program data records to 
-- restore only a subset of the presets in the device.
--
-- A program data record consists of 7 lines of plain-ASCII text, each line
-- terminated by a carriage return - line feed pair (ASCII codes 13 and 10). The
-- following template highlights the elements of interest for this MMD
-- implementation. More detailed information is available from Eventide's 
-- documentation: 
--
--  line #1: "[<preset>] <algorithm> <encoding>..."
--  line #2: " <algorithm> <parameters>..."
--  line #3: " <parameters> ..."
--  line #4: " <parameters> ..."
--  line #5: " <parameters> ..."
--  line #6: "C_<sum>"
--  line #7: "<name>"
--   
-- where:
--  - <preset> is the preset slot number where this program is stored in the 
--    pedal's persistent memory (1-99);
--  - <algorithm> is the numerical identifier of the algorithm that this 
--    program uses;
--  - <parameters> is a sequence of parameters for the algorithm;
--  - <sum> is a checksum for the preset, expressed as a 4-hexadecimal digit
--    value (lowercase letters);
--  - <name> is the name of the preset made of characters from the set 0-9, A-Z,
--    whitespace ( ), asterisk (*), plus sign (+), minus sign (-), underscore (_),
--    and exclamation mark (!).


-- HELPER SUBROUTINES:

-- Construct SysEx message header using unit number in given configuration:
function get_header( config )
   local unit

   if type( config ) ~= "table" then 
      print( "H9 get_header(): unit identfier missing from supplied configuration" )
      return nil -- invalid argument
   end
   unit = config.unit
   if type( unit ) ~= "number" or unit < 1 or unit > 16 then
      print( "H9 get_header(): unit identifier out of valid range" )
      return nil -- out of range
   end
   return midi.hex_to_octets( { "F0 1C 70", unit } )
end -- get_header()


-- Given a preset data record, extract its preset number and name.
--
-- Parameters:
--  - record: octet string, of the form "[<slot>]<data>" where:
--     . <slot> is the preset number of the program;
--     . <data> is the program data.
--
-- Returns:
--  - slot: integer, preset number, 1-99;
--  - name: character string, preset name if not empty;
--  - data: the program data extracted from the record;
function get_preset_info( record ) -- -> slot, data
   local slot, data, name
   
   -- Match the number in square brackets on the first line of the preset data
   -- to extract the slot number, and the last line of text in the program data 
   -- block to extract the program name (that is the sequence comprised between
   -- the last two CR-LF pairs):
   slot, data, name = string.match( record, "^%[(%d+)%](.-\r\n([^\r\n]+)\r\n)$" )
   slot = tonumber( slot )
   if type( name ) == "string" and #name == 0 then
      name = nil
   end
   return slot, name, data
end -- get_preset_number()


-- Replace the preset number and name in the given preset data record. Convert 
-- given name string to a suitable preset name for the H9 pedal:
--  1) remove trailing non-printable characters (leave any leading spaces...);
--  2) convert lowercase letters to uppercase;
--  3) replace characters that are not in the supported character set with underscore 
--     (which is); 
--  4) truncate to maximum length (16 characters).
--
-- Parameters:
--  - record: octet string, of the form "[<slot>]<data>" where:
--     . <slot> is the preset number of the program;
--     . <data> is the program data.
--  - slot: new preset number;
--  - name: new preset name.
--
-- Returns:
--  - record: the updated preset data record.
function set_preset_info( record, slot, name )
   local s, n, a, b, c
   
   s, n = get_preset_info( record )
   if type( slot ) ~= "number" then
      slot = s
   end
   if type( name ) ~= "string" then
      name = n
   else
      name = name:match( "^(.-)[%s%c]*$" ):upper():
         gsub( "[^ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789+-* _!]", "_" ):sub( 1, 16 )
   end

   a, b, c = string.match( record, "^(%[)%d+(%].-\r\n)[^\r\n]+(\r\n)$" )
   return a .. slot .. b .. name .. c
end -- set_preset_info()


-- Calculates the checksum for a list of system variable values that were extracted
-- from a system variables data record. 
--
-- Parameters:
--  - values: an indexed table of unsigned integer and 'nil' values. 'nil' items 
--    indicate that the preceding value was at the end of a line in the record, and 
--    are ignored in the checksum calculation.
--
-- Returns:
--  - sum: the checksum for the given list of values.
function checksum( values )
   local value, sum
   
   sum = 0
   for i = 1, #values do
      value = values[i]
      if type( value ) == "number" then
         sum = sum + value
      end
   end
   sum = sum & 0xFFFF
   return sum
end -- checksum()


-- Decode a system variables data record to extract all the values. This is the 
-- sequence of unsigned integer values that are included within a SYSVARS DUMP
-- message following the heading line ("[SYSTEM]...") and preceding the checksum line
-- ("C_xxxx" where xxxx is an unsigned 16-bit value in hexadecimal). This function
-- extracts and the sequence of values and verifies the checksum from the record.
--
-- Parameters:
--  - record: system variables record from a SYSVARS DUMP message;
--
-- Returns nothing in case of an invalid record (bad format or incorrect checksum).
-- Otherwise:
--  - heading: the record heading, being the first line of text in the record, 
--    starting with the "[SYSTEM]..." tag and ending with a CR-LF ("\r\n") end-of-line
--    indicator;  
--  - values: an indexed table of unsigned integer and 'nil' values extracted from
--    the record, in the order that they appeared in the record. 'nil' indicates
--    that the preceding value was at the end of a line in the record;
--    an end of line in the record;
function decode_sysvars( record ) -- -> values, sum
   local heading, data, sum, values, value, eol
   
   heading, data, sum = string.match( record, "^(.-\r\n)(.-)C_(%x+)\r\n$" )
   if type( sum ) == "string" then
      sum = tonumber( sum, 16 )
   end
   if type( data ) == "string" and type( sum ) == "number" then      
      values={}
      while string.len( data ) > 0 do
         value, eol, data = string.match( data, " *(%x+) *(\r?\n?)(.*)$" )
         if type( value ) == "string" and type( eol ) == "string" then
            values[#values + 1] = tonumber( value, 16 )
         end
         if type( eol ) == "string" and string.len( eol ) > 0 then
               values[#values + 1] = eol
         end
      end
      if sum == checksum( values ) then
         return heading, values
      end
   end
end -- decode_sysvars()
      

-- Encodes a system variables data record from a list of values of the kind 
-- produced by 'decode_sysvars()'. This function constructs the record and calculates
-- and appends the checksum.
--
-- Parameters:
--  - heading: a system variables data record heading, to be used as the first line of 
--    the record, starting with the '[SYSTEM]...' tag, and ending with a CR-LF ('\r\n') 
--    end of line indicator;
--  - values: an indexed table of unsigned integer and 'nil' values in the order that 
--    they are to appear in the record. 'nil' marks the end of a line of values and
--    causes the record to continue on the next line.
--
-- Returns:
--  - record: constructed system variables record.
function encode_sysvars( heading, values ) -- -> record
   local sum, data, value
   
   sum = checksum( values )
   data = heading
   for i = 1, #values do
      value = values[i]
      if type( value ) == "number" then
         data = data .. string.format( "%x", value ) .. " "
      else
         data = data .. "\r\n"
      end
   end
   data = data .. "C_" .. string.format( "%04x", sum ) .. "\r\n"
   return data
end -- encode_sysvars()


-- Construct an PROGRAM WANT command.
--
-- Parameters:
--  - header: SysEx header for the messages, including the unit identifier 
--    of the target device.
--
-- Returns:
--  - msgs: a list of one octet string with the encoded message.
function encode_program_want_command( header ) -- -> msgs
   return { header .. midi.hex_to_octets( "4E F7" ) }
end -- encode_program_want_command()


-- Construct a PRESETS WANT command.
--
-- Parameters:
--  - header: SysEx header for the messages, including the unit identifier 
--    of the target device.
--  - slot: requested stored program slot number, 1-1024.
--
-- Returns:
--  - msgs: a list of one octet string with the encoded message.
function encode_presets_want_command( header ) -- -> msgs
   return { header .. midi.hex_to_octets( "48 F7" ) }
end -- encode_presets_want_command()


-- Construct a SYSVARS WANT command.
--
-- Parameters:
--  - header: SysEx header for the messages, including the unit identifier 
--    of the target device.
--
-- Returns:
--  - msgs: a list of one octet string with the encoded message.
function encode_sysvars_want_command( header ) -- -> msgs
   return { header .. midi.hex_to_octets( { "4C F7" } ) } 
end -- encode_sysvars_want_command()


-- Decode a PROGRAM DUMP message.
--
-- Parameters:
--  - msg: the message to decode.
--
-- Returns:
--  - record: octet string, of the form "[<slot>]<data>" where:
--     . <slot> is the preset number of the program;
--     . <data> is the program data.
function decode_program_dump( msg ) -- -> record
   return string.sub( msg, 6, -3 )
end -- decode_program_dump()


-- Decode a PRESETS DUMP message. The message may contain up to 99 presets:
-- this function extracts all program data records in the message.
--
-- Parameters:
--  - msg: message to decode
--
-- Returns:
--  - records: a list of up to 99 octet strings, each the parameters of a
--       preset data record from the message.
function decode_presets_dump( msg ) -- -> records
   local all, records, pattern, record
   
   all = string.sub( msg, 6, -3 )
   records = {}
   for slot = 1, 99 do
      -- Search a match for a block that starts with the requested slot number in 
      -- brackets and ends with the subsequent preset number in brackets. If the 
      -- slot number is 99 (last preset), match to end of message payload instead:
      pattern = "(%[" .. slot .. "%].-)"
      if slot < 99 then
         pattern = pattern .. "%[" .. slot + 1 .. "%]"
      else
         pattern = pattern .. "$"
      end
      record = string.match( all, pattern )
      if type( record ) == "string" and #record > 0 then
         records[#records + 1] = record
      end
   end
   
   return records
end -- decode_presets_dump()


-- Decode a SYSVARS DUMP message:
--  - msg: the message to decode.
--
-- Returns:
--  - record: octet string, system variables data record;
function decode_sysvars_dump( msg ) -- -> record
   return string.sub( msg, 6, -3 )
end -- decode_sysvars_dump()


-- Encode a program dump message from the given data record.  If
-- a new name is given for the program, the name will be used to construct
-- the message, otherwise the exising name in the given program data will
-- be used.
--
-- Parameters:
--  - records: a list of one octet string, of the form "[<slot>]<data>" where:
--     . <slot> is the preset number of the program;
--     . <data> is the program data.
--  - header: SysEx header for the message.
--  - name: optional program name.
--
-- Returns:
--  - msgs: list of one octet string, encoded message.
function encode_program_dump( records, header, name ) -- -> msgs
   local record
   
   record = records[1]
   if #records ~= 1 or type( record ) ~= "string" or #record == 0 then
      print( "H9 encode_program_dump(): invalid records argument")
      return nil
   end
   record = set_preset_info( record, nil, name ) -- keep slot number as is
   return { header .. string.char( 0x4F ) .. record .. midi.hex_to_octets( "00 F7" ) }     
end -- encode_program_dump()


-- Encode a preset dump message from the given preset data record. If
-- a new name is given for the preset, the name will be used to construct
-- the message, otherwise the exising name in the given preset data will
-- be used.
--
-- Parameters:
--  - records: a list of one octet string, of the form "[<slot>]<data>" where:
--     . <slot> is the preset number of the program;
--     . <data> is the program data.
--  - header: SysEx header for the message, including the unit identifier 
--    of the target device.
--  - name: optional program name.
--
-- Returns:
--  - msgs: list of one octet string, encoded message.
--
-- Note:
--  - Although the H9 preset dump message may contain an arbitrary (at 
--    least up to 99) preset data records, this function encodes a 
--    single preset for transmission.
function encode_preset_dump( records, header, slot, name ) -- -> msgs
   local record
   
   record = records[1]
   if #records ~= 1 or type( record ) ~= "string" or #record == 0 then
      print( "H9 encode_preset_dump(): invalid records argument")
      return nil
   end
   record = set_preset_info( record, slot, name )
   return { header .. string.char( 0x49 ) .. record .. midi.hex_to_octets( "00 F7" ) }     
end -- encode_program_dump()


-- Encode a SYSVARS DUMP message from the given data record.
--
-- Parameters:
--  - records: list of one octet string, the global parameter data;
--  - header: SysEx header for the message, including the unit identifier 
--    of the target device.
--
-- Returns:
--  - msgs: list of one octet string, encoded message.
function encode_sysvars_dump( records, header ) -- -> msgs
   local record, heading, values, unit

   record = records[1] 
   if #records ~= 1 or type( record ) ~= "string" or #record == 0 then
      print( "H9 encode_sysvars_dump(): invalid records argument" )
      return nil 
   end
   
   -- The unit identifier (SYSTEM ID) is encoded in the record as the value of the 
   -- 5th system variable. Set this to the identifier in the given SysEx message 
   -- header to prevent changing the unit's identifier when the globals are applied:
   heading, values = decode_sysvars( record )
   if type( values ) ~= "table" then
      print( "H9 encode_sysvars_dump(): invalid records argument" )
      return nil 
   end
   unit = string.byte( header, 4 )
   values[5] = unit - 1 -- one-based in the SysEx header, but zero-based in the record
   record = encode_sysvars( heading, values )
   
   -- Construct and return complete message:
   return { header .. string.char( 0x4D ) .. record .. midi.hex_to_octets( "00 F7" ) }
end -- encode_sysvars_dump()


-- MODULE FUNCTIONS:
local model = {}


function model.info()
   return {
      specification = 2,
      name = "Eventide H9 Harmonizer",
      source = "Old Blue Bike Software inc.",
      version = "2.1",
      icon = "*.png", -- look for file with same path as this file with '.png' appended
      manufacturer = "1C",
      family = "00 06",
      member = "15 00",
      unit_first = 1,
      unit_last = 16,
      unit_factory = 1,
      slots = 99,
      timeout = 1000 } -- SysEx transfers slow with long gaps
end -- model.info()


function model.globals() --> globals
   return { "System" }
end -- model.globals()


function model.decode_software_version( msg ) -- -> sw_ver
   local ma, mi, re

   if type( msg ) ~= "string" or #msg ~= 4 then 
      print( "H9 decode_software_version(): invalid argument")
      return nil -- incorrect length
   end

   ma = string.byte( msg, 1 )
   mi = string.byte( msg, 2 )
   re = string.byte( msg, 3 )
   if ma > 0x7F or mi > 0x7F or re > 0x7F then
      print( "H9 decode_software_version(): invalid version information" )
      return nil -- value out of range
   end

   return ma .. "." .. mi .. "." .. re
end


function model.dump_program_command( config, slot ) -- -> msgs, header, max_rsps, slots
   local header, slots

   header = get_header( config )
   if header == nil then
      return nil -- invalid configuration
   end
   if slot == nil then
      slot = 0
   elseif type( slot ) ~= "number" or slot < 0 or slot > 99 then
      print( "H9 dump_program_command(): invalid slot argument" )
      return nil
   end

   if slot == nil or slot == 0 then
      msgs = encode_program_want_command( header )
   elseif type( slot ) == "number" then
      msgs = encode_presets_want_command( header )
      slots = "1-99"
   else
      print( "H9 dump_program_command(): invalid slot argument" )
      return nil
   end
   
   if type( msgs ) == "table" then
      return msgs, header, 1, slots
   end
end -- model.dump_program_command()


function model.dump_globals_command( config, globals ) -- -> msgs, header, max_rsps
   local msgs, header

   header = get_header( config )
   if header == nil then
      return nil -- invalid configuration
   end

   if globals == "System" then
      msgs = encode_sysvars_want_command( header )
   else
      print( "H9 dump_globals_command(): unknown globals \"" .. 
         globals .. '\"' )
      return nil -- invalid configuration
   end

   if type( msgs ) == "table" then
      return msgs, header, 1
   end
end -- model.dump_globals_command()


function model.decode( msgs ) -- -> records
   local header, records, ident, msg, record, name, presets, slot

   if type( msgs ) ~= "table" or #msgs == 0 then
      print( "H9 decode(): invalid msgs argument" )
      return nil -- invalid argument
   end

   header = midi.hex_to_octets( "F0 1C 70" )
   records = {}
   for i = 1, #msgs do
      msg = msgs[i]

      if type( msg ) == "string" and #msg >= 6 and
         string.sub( msg, 1, 3 ) == header and 
         string.sub( msg, -2, -1 ) == midi.hex_to_octets( "00 F7" ) then
         -- Value H9 SysEx message:
         ident = string.byte( msg, 5 )
         
         if ident == 0x4F then
            -- PROGRAM DUMP message:
            record = decode_program_dump( msg )
            if type( record ) == "string" then
               records[#records + 1] = "program:0"
               slot, name = get_preset_info( record )
               if type( name ) == "string" then
                  records[#records + 1] = "name:" .. name
               end
               records[#records + 1] = "data:" .. record
            end

         elseif ident == 0x49 then
            -- Message is PRESETS DUMP message:
            presets = decode_presets_dump( msg )
            if type( presets ) == "table" then
               for i = 1, #presets do
                  record = presets[i]
                  if type( record ) == "string" then
                     slot, name = get_preset_info( record )
                     records[#records + 1] = "program:" .. slot
                     if type( name ) == "string" then                        
                        records[#records + 1] = "name:" .. name
                     end
                     records[#records + 1] = "data:" .. record
                  end
               end
            end
         
         elseif ident == 0x4D then
            -- Message is a SYSVARS DUMP message:
            record = decode_sysvars_dump( msg )
            if type( record ) == "string" then
               records[#records + 1] = "globals:System"
               records[#records + 1] = "data:" .. record
            end
            
         -- else, ignore unsupported SysEx message type            
         end
      end -- if string.sub( msg, 1, 3 ) == header and ...
   end -- for i = 1, #msgs do

   return records
end -- model.decode()


function model.load_program_command( config, records, slot, name ) -- -> msgs
   local header

   header = get_header( config )
   if type( header ) ~= "string" then
      return nil -- invalid configuration
   end
   if type( records ) ~= "table" or #records == 0 then
      print( "H9 load_program_command(): invalid records argument")
      return nil -- invalid argument
   end
   
   if slot == nil or slot == 0 then
      return encode_program_dump( records, header, name )
   elseif type( slot ) == "number" and slot >= 1 and slot <= 1024 then
      return encode_preset_dump( records, header, slot, name )
   else
      print( "H9 load_program_command(): invalid slot argument")
   end  
end -- model.load_program_command()


function model.load_globals_command( config, globals, records ) -- -> msgs
   local header, record

   header = get_header( config )
   if type( header ) ~= "string" then
      return nil -- invalid configuration
   end
   if type( records ) ~= "table" or #records == 0 then
      print( "H9 load_globals_command(): invalid records argument")
      return nil -- invalid argument
   end
   
   if globals == "System" then
      msgs = encode_sysvars_dump( records, header )
   else
      print( "H9 load_globals_command(): unknown globals \"" .. globals .. '\"' )
      return nil -- invalid configuration
   end
   
   return msgs
end -- model.loal_globals_command()


return model


-- EOF h9-harmonizer.lua
