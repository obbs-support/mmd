-- prophet08.lua
--
-- MIDI Model Description (MMD) for the Sequential Prophet '08 
-- Synthesizers.
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

-- MIDI MODEL DESCRIPTION (MMD) for the Sequential Prophet '08
-- ===========================================================
-- 
-- MIDI ports:
-- -----------
--
-- The Prophet '08 responds to MIDI SysEx messages transmitted via its 
-- 5-pin DIN connectors when enabled in the globals menu. However its 
-- SysEx messages do not include a unit identifier, and thus it is not 
-- possible address a single instrument should multiple Prophet '08s be
-- connected to the same MIDI output (via splitter or or daisy-chaining). 
--
-- Identification:
-- ---------------
--
-- The Prophet '08 responds to the standard device inquiry IDENTITY REQUEST
-- message as follows:
--
--                   F0 7E gg 06 02 01 23 01 00 00 jn F7
--                         --       -- ----- ----- --
--                          |        |   |     |    |
--          Channel # ------+        |   |     |    |
--                                   |   |     |    |
--     Manufacturer ID (Sequential) -+   |     |    |
--                                       |     |    |
--           Family ID (Prophet '08)  ---+     |    |
--                                             |    |
--                    Member ID (unused)  -----+    |
--                                                  |
--                    Software version (n.j)  ------+
--
-- where:
--  - Channel #: The MIDI channel number that this Prophet '08 is set to 
--    receive/transmit channel voice messages on, or 0x7F if set to accept 
--    messages on all channels; 
--  - manufacturer code = 0x01 (Sequential);
--  - family code = 0x0123 (Prophet '08);
--  - member code = 0x0000 (unused).
--
-- The MIDI channel number that appears in the IDENTITY REPLY message is
-- not a unit identifier as it does not appear in SysEx messages received/
-- transmitted by the Prophet '08. Thus each Prophet '08 must be connected to 
-- a separate MIDI output: it is not possible to daisy-chain multiple Prophet 
-- 12s on a single output.
--
-- Program Data:
-- -------------
--
-- The parameters of a Prophet '08 program occupy 384 bytes of memory. For 
-- transmission over MIDI, the program's data is encoded in packed MSB MIDI data
-- format. Each group of 7 consecutive bytes is encoded into an 8 x 7-bit word 
-- packet. The first 7-bit word of each packet contains the most significant bit 
-- of each of the 7 program data bytes. The first 378 bytes of program data are
-- thus packed into 54 packets, and the remaining 6 bytes into a 7-word packet, 
-- for a total of 439 bytes.
--
-- Persistent storage in the Prophet '08 consists of 2 banks of 128 programs for
-- a total of 256 program slots. All program slots are writable.

-- HELPER SUBROUTINES:

-- Remove trailing non-printable characters from given string:
function trim( s ) -- -> string
   return string.match( s, "(.-)[%s%c]*$" )
end -- trim()


-- Make a SysEx message header (common to all messages):
function get_header()
   return midi.hex_to_octets( "F0 01 23" )
end -- get_header()


-- Retrieve the unit identifier from the given configuration:
function get_unit( config ) -- -> unit
   local unit

   if type( config ) ~= "table" then 
      print( "Prophet08 get_unit(): unit identfier missing from supplied configuration" )
      return nil -- invalid argument
   end
   unit = config.unit
   if type( unit ) ~= "number" or ((unit < 0 or unit > 15) and unit ~= 0x7F) then
      print( "Prophet08 get_unit(): unit identifier out of valid range" )
      return nil -- out of range
   end
   
   return unit
end -- get_unit()


-- Extract the program name from the given program data record.
--
-- Parameters:
--  - record: octet string, program data record.
--
-- Returns:
--  - name: character string, program name.
function get_program_name( record )
   if #record == 384 then
      return trim( string.sub( record, 185, 200 ) )
   end
end -- get_program_name()


-- Replace the program name the given program data record. Replace characters
-- that are not in the set supported by the Prophet '08 with underscores (which is). 
-- Truncate or pad with whitespaces to 16 characters.
-- 
-- Parameters:
--  - record: octet string, program data record to update;
--  - name: character string, new program name.
--
-- Returns:
--  - record: octet string, updated program data record. 
function set_program_name( record, name ) -- -> record
   local len, c, filtered

   len = string.len( name )
   filtered = ""
   for i = 1, len do
      c = string.byte( name, i )
      if c < 32 or c > 127 then
         c = string.byte( "_" )
      end
      filtered = filtered .. string.char( c )
   end
   filtered = string.sub( filtered .. string.rep( " ", 16 ), 1, 16 )
   return string.sub( record, 1, 184 ) .. filtered .. string.sub( record, 201 )
end -- set_program_name()
      

-- Construct an REQUEST PROGRAM EDIT BUFFER DUMP command.
--
-- Parameters:
--  - header: SysEx header for the messages, including the unit identifier 
--    of the target device.
--
-- Returns:
--  - msgs: a list of one octet string with the encoded message.
function encode_edit_buffer_dump_command( header ) -- -> msgs
   return { header .. midi.hex_to_octets( "06 F7" ) }
end -- encode_edit_buffer_dump_command()


-- Construct a REQUEST PROGRAM DUMP command.
--
-- Parameters:
--  - header: SysEx header for the messages, including the unit identifier 
--    of the target device.
--  - slot: requested stored program slot number, 1-792.
--
-- Returns:
--  - msgs: a list of one octet string with the encoded message.
function encode_program_dump_command( header, slot ) -- -> msgs
   local bank
   
   if slot >= 1 and slot <= 256 then
      slot = slot - 1
      bank = slot // 128
      slot = slot % 128
      return { header ..  midi.hex_to_octets( { 0x05, bank, slot, 0xF7 } ) }
   end
end -- encode_program_dump_command()


-- Construct a REQUEST GLOBAL PARAMETER DUMP command.
--
-- Parameters:
--  - header: SysEx header for the messages, including the unit identifier 
--    of the target device.
--
-- Returns:
--  - msgs: a list of one octet string with the encoded message.
function encode_global_parameter_dump_command( header ) -- -> msgs
   return { header .. midi.hex_to_octets( { 0x0E, 0xF7 } ) }
end -- encode_global_parameter_dump_command()


-- Decode an PROGRAM EDIT BUFFER DATA DUMP message:
--  - msg: the message to decode.
--
-- Returns:
--  - record: octet string, program data record.
function decode_program_edit_buffer_dump( msg ) -- -> record
   if #msg == 444 then
      return midi.unpack( string.sub( msg, 5, -2 ) )
   end
end -- decode_program_edit_buffer_dump()


-- Decode a PROGRAM DATA DUMP message:
--  - msg: message to decode
--
-- Returns:
--  - record: octet string, program data record.
--  - slot: stored program slot number of the program in the source device.
function decode_program_dump( msg ) -- -> record, slot
   local bank, slot, record
   
   if #msg == 446 then
      bank = string.byte( msg, 5 )
      slot = (bank * 128) + string.byte( msg, 6 ) + 1
      record = midi.unpack( string.sub( msg, 7, -2 ) )
      return record, slot
   end
end -- decode_program_dump()


-- Decode a GLOBAL PARAMETERS DATA DUMP message:
--  - msg: message to decode;
--
-- Returns:
--  - record: octet string, global parameters data record.
function decode_global_data_dump( msg ) -- -> record
   if #msg >= 6 then
      return string.sub( msg, 5, -2 )
   end
end -- decode_global_data_dump()


-- Encode a PROGRAM EDIT BUFFER DATA DUMP message from the given data record.
-- If a new name is given for the program, the name will be used to construct
-- the message, otherwise the exising name in the given program data will
-- be used.
--
-- Parameters:
--  - records: list of one octet string, the program data to encode;
--  - header: SysEx header for the message;
--  - name: optional program name.
--
-- Returns:
--  - msgs: list of one octet string, encoded message.
function encode_edit_buffer_dump( records, header, name ) -- -> msgs
   local record
   
   record = records[1]
   if #records ~= 1 or type( record ) ~= "string" or #record ~= 384 then
      print( "Prophet08 encode_edit_buffer_dump(): invalid records argument" )
      return nil -- invalid argument
   end 
   
   if type( name ) == "string" then
      record = set_program_name( record, name )
   end
   return { header .. string.char( 0x03 ) .. midi.pack( record ) .. string.char( 0xF7 ) }
end -- encode_edit_buffer_dump()


-- Encode a PROGRAM DATA DUMP message from the given data record. If
-- a new name is given for the program, the name will be used to construct
-- the message, otherwise the exising name in the given program data will
-- be used.
--
-- Parameters:
--  - records: list of one octet string, the program data to encode;
--  - header: SysEx header for the message;
--  - slot: destination stored program slot number, 1-256;
--  - name: optional program name.
--
-- Returns:
--  - msgs: list of octet strings, encoded messages.
function encode_program_dump( records, header, slot, name )
   local record, bank

   record = records[1] 
   if #records ~= 1 or type( record ) ~= "string" or #record ~= 384 then
      print( "Prophet08 encode_program_dump(): invalid records argument" )
      return nil -- invalid argument
   end
   
   slot = slot - 1
   bank = slot // 128
   slot = slot % 128
   if type( name ) == "string" then
      record = set_program_name( record, name )
   end
   return { header .. midi.hex_to_octets( { 0x02, bank, slot } ) .. midi.pack( record ) .. 
      string.char( 0xF7 ) }
end -- encode_program_dump()


-- Encode NRPN messages to restore globals data from the given data record.
--
-- Parameters:
--  - records: list of one octet string, the global parameters data record
--    to encode;
--  - unit: the unit identifier of the destination device as provided in its
--    IDENTITY REPLY message (0-15 or 0x7F).
--
-- Returns:
--  - msgs: list of octet strings, encoded NRPN messages with global parameter
--    values.
function encode_global_data_dump( records, unit ) -- -> msgs
   local channel_setting, channel, record, msgs
   
   -- The unit ID is encoded as 127 (0-based) if the device is configured to
   -- receive on any MIDI channel, in which case we will transmit on MIDI 
   -- channel 1 (1-based).
   if unit <= 15 then
      channel_setting = unit + 1 -- 'MIDI channel' global setting 1-16
      channel = unit
   else
      channel_setting = 0 -- 'MIDI channel' global setting to 'ALL'
      channel = 0 -- transmit NRPNs on channel 1
   end

   record = records[1]
   if #records ~= 1 or type( record ) ~= "string" or #record == 0 then
      print( "Prophet08 encode_global_data_dump(): invalid records argument" )
      return nil
   end

   -- The MIDI channel assigned to the Prophet '08 is encoded into the fifth 
   -- byte of the global data. The Prophet '08 also uses this setting as its unit
   -- identifier. Update the global data record in accordance with the given
   -- unit identifier so we don't change this setting when the globals are applied.
   if #record >= 5 then
      record = string.sub( record, 1, 4 ) .. string.char( channel_setting ) .. 
         string.sub( record, 6 )
   end
   
   -- The GLOBAL PARAMETER DATA record includes the number of the program
   -- that was selected at the time of globals data capture (first and second 
   -- bytes) as well as the LCD contrast setting (19nth byte), which cannot be 
   -- restored via NRPN. Trim the record to keep only the parameters that can be 
   -- restored:
   first = 3
   last = #record
   if last > 18 then
      last = 18
   end
   record = string.sub( record, first, last )
      
   msgs = {}
   for i = 1, #record do
      msgs[i] = midi.set_nrpn( channel, i + 383, string.byte( record, i ) )
   end

   return msgs
end -- encode_global_data_dump()


-- MODULE FUNCTIONS:
local model = {}


function model.info()
   return {
      specification = 2,
      name = "Sequential Prophet '08",
      source = "Old Blue Bike Software inc.",
      version = "0.1",
      icon = "*.png", -- look for file with same path as this file with '.png' appended
      manufacturer = "01",
      family = "23 01",
      slots = 256,
      unit_first = 0x7F,
      unit_last = 0x0F, 
      unit_factory = 0x7F,
      timeout = 50,
      notes = 
         "NO DAISY CHAINING:\n" ..
         "==================\n" ..
         "\n" ..
         "For SysEx data backup and restore, each Prophet '08 synthesizer must be\n" ..
         "connected to a separate MIDI output. This is because Prophet '08 SysEx messages\n" ..
         "do not include their unit identifier, which prevents uniquely addresssing each\n" ..
         "unit. Do not daisy-chain or otherwise connect multiple Prophet '08s via the MIDI\n" ..
         "THRU port or using a MIDI splitter interface.\n" ..
         "\n" ..
         "STORED PROGRAMS:\n" ..
         "================\n" ..
         "\n" ..
         "The Prophet '08 stores 256 programs organized in 2 banks of 128 each. All 256\n" ..
         "programs can be exported from and restored to the Prophet '08 via SysEx dump.\n" }
end -- model.info()


function model.globals()
   return { "Settings" }
end -- model.globals()


function model.decode_software_version( msg ) -- -> sw_ver
   local byte, j, n

   if type( msg ) ~= "string" or #msg ~= 12 then 
      print( "Prophet08 decode_software_version(): invalid argument")
      return nil -- incorrect length
   end

   byte = string.byte( msg, 11 )
   if byte > 0x7F then
      print( "Prophet08 decode_software_version(): invalid version information" )
      return nil -- value out of range
   end

   j = ((byte >> 4) & 0x07)
   n = (byte & 0x0F)
   return n .. "." .. j
end


function model.dump_program_command( config, slot ) -- -> msgs, header, max_rsps
   local header, msgs

   header = get_header()
   if slot == nil or slot == 0 then
      msgs = encode_edit_buffer_dump_command( header )
   elseif type( slot ) == "number" then
      msgs = encode_program_dump_command( header, slot )
   else
      print( "Prophet08 dump_program_command(): invalid slot argument" )
      return nil
   end
   
   if type( msgs ) == "table" then
      return msgs, header, 1
   end
end -- model.dump_program_command()


function model.dump_globals_command( config, globals ) -- -> msgs, header, max_rsps
   local header, msgs

   header = get_header()
   if globals == "Settings" then
      msgs = encode_global_parameter_dump_command( header )
   else
      print( "Prophet08 dump_globals_command(): unknown globals \"" .. globals .. '\"' )
      return nil -- invalid configuration
   end

   if type( msgs ) == "table" then
      return msgs, header, 1
   end
end -- model.dump_globals_command()


function model.dump_globals_command( config, globals ) -- -> msgs, header, max_rsps
   local header, msgs

   header = get_header()
   if globals == "Settings" then
      msgs = encode_global_parameter_dump_command( header )
   else
      print( "Prophet08 dump_globals_command(): unknown globals \"" .. globals .. '\"' )
      return nil -- invalid configuration
   end

   if type( msgs ) == "table" then
      return msgs, header, 1
   end
end -- model.dump_globals_command()


function model.decode( msgs ) -- -> records
   local header, records, msg, ident, record, name, slot

   if type( msgs ) ~= "table" or #msgs == 0 then
      print( "Prophet08 decode(): invalid msgs argument")
      return nil -- invalid argument
   end

   header = get_header()
   records = {}
   for i = 1, #msgs do
      msg = msgs[i]

      if type( msg ) == "string" and #msg >= 8 and
         string.sub( msg, 1, 3 ) == header and 
         string.byte( msg, -1 ) == 0xF7 then
         -- Valid Prophet '08 SysEx message:
         ident = string.byte( msg, 4 )
         
         if ident == 0x03 then
            -- PROGRAM EDIT BUFFER DATA DUMP message:
            record = decode_program_edit_buffer_dump( msg )
            if type( record ) == "string" then
               records[#records + 1] = "program:0"
               name = get_program_name( record )
               if type( name ) == "string" then
                  records[#records + 1] = "name:" .. name
               end
               records[#records + 1] = "data:" .. record
            end
            
         elseif ident == 0x02 then
            -- PROGRAM DATA DUMP message:
            record, slot = decode_program_dump( msg )
            if type( record ) == "string" and type( slot ) == "number" then
               records[#records + 1] = "program:" .. slot
               name = get_program_name( record )
               if type( name ) == "string" then
                  records[#records + 1] = "name:" .. name
               end
               records[#records + 1] = "data:" .. record
            end
            
         elseif ident == 0x0F then
            -- GLOBAL PARAMETERS DATA DUMP message:
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


function model.load_program_command( config, records, slot, name ) -- -> msgs
   local header

   header = get_header()
   if type( records ) ~= "table" or #records == 0 then
      print( "Prophet08 load_program_command(): invalid records argument")
      return nil -- invalid argument
   end
   
   if slot == nil or slot == 0 then
      return encode_edit_buffer_dump( records, header, name )
   elseif type( slot ) == "number" and slot >= 1 and slot <= 256 then
      return encode_program_dump( records, header, slot, name )
   else
      print( "Prophet08 load_program_command(): invalid slot argument")
   end  
end -- model.load_program_command()


function model.load_globals_command( config, globals, records ) -- -> msgs
   local header, unit

   unit = get_unit( config )
   if unit == nil then
      return nil -- invalid configuration
   end
   if type( records ) ~= "table" or #records == 0 then
      print( "Prophet08 load_globals_command(): invalid records argument")
      return nil -- invalid argument
   end

   if globals == "Settings" then
      -- Globals are restored to the Prophet '08 by transmitting NRPN messages
      -- (not SysEx), which are voice channel messages and require a MIDI 
      -- channel number. The MIDI channel number that the device receives on
      -- is encoded as its unit ID in the IDENTITY REPLY message, which we
      -- get here in the 'config' parameter. The unit ID is encoded as 127
      -- (0-based) if the device is configured to receive on any MIDI channel,
      -- in which case we will transmit on MIDI channel 1 (1-based).   
      return encode_global_data_dump( records, unit )
   else
      print( "Prophet08 load_globals_command(): unknown globals \"" .. globals .. '\"' )
   end
end -- model.load_globals_command()


return model


-- EOF prophet08.lua
