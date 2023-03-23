-- ob6.lua
--
-- MIDI Model Description (MMD) for Sequential OB-6 Synthesizers.
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


-- MIDI MODEL DESCRIPTION (MMD) for the Sequential OB-6
-- ====================================================
-- 
-- MIDI ports:
-- -----------
--
-- The OB-6 responds to MIDI SysEx messages transmitted via USB
-- and/or its 5-pin DIN connectors when enabled in the globals menu.
-- However its SysEx messages do not include a unit identifier, and
-- thus it is not possible address a single instrument should multiple
-- OB-6s be connected to the same MIDI output (via splitter or
-- or daisy-chaining). 
--
-- Identification:
-- ---------------
--
-- The OB-6 responds to the standard device inquiry IDENTITY REQUEST message 
-- as follows:
--
--                   F0 7E gg 06 02 01 2E 01 00 00 jn F7
--                         --       -- ----- ----- --
--                          |        |   |     |    |
--          Channel # ------+        |   |     |    |
--                                   |   |     |    |
--     Manufacturer ID (Sequential) -+   |     |    |
--                                       |     |    |
--                  Family ID (OB-6)  ---+     |    |
--                                             |    |
--                    Member ID (unused)  -----+    |
--                                                  |
--                    Software version (n.j)  ------+
--
-- where:
--  - Channel #: The MIDI channel number that this OB-6 is set to 
--    receive/transmit channel voice messages on, or 0x7F if set to accept 
--    messages on all channels; 
--  - manufacturer code = 0x01 (Sequential);
--  - family code = 0x012E (OB-6);
--  - member code = 0x0000 (unused).
--
-- The MIDI channel number that appears in the IDENTITY REPLY message is
-- not a unit identifier as it does not appear in SysEx messages received/
-- transmitted by the OB-6. Thus each OB-6 must be connected to 
-- a separate MIDI output: it is not possible to daisy-chain multiple OB-6s 
-- on a single output.
--
-- Program Data:
-- -------------
--
-- Program data for the OB-6 consists of 1024 8-bit bytes encoded in packed
-- MIDI data format for transmission over MIDI. Each group of 7 consecutive
-- bytes is encoded into an 8 x 7-bit word packet. The first 7-bit word of 
-- each packet contains the most significant bit of each of the 7 program data 
-- bytes. The first 1022 bytes of program data are thus packed into 146 packets, 
-- and the remaining 2 bytes into a 3-word packet, for a total of 1171 bytes.
--
-- Persistent storage in the OB-6 consists of 10 banks of 100 programs for
-- a total of 1000 program slots. Banks 1-5 (slots 1-500) contain user-defined 
-- programs and can be overwritten; banks 6-10 (slots 501-1000) contain factory
-- programs that cannot be modified except by a firmware update. All 1000
-- programs can be downloaded via SysEx using the OB-6's REQUEST PROGRAM DUMP 
-- SysEx command message, but only the first 500 can be restored by transmitting 
-- PROGRAM DATA DUMP messages.
--

-- HELPER SUBROUTINES:

-- Make a SysEx message header (common to all messages):
function get_header()
   return midi.hex_to_octets( "F0 01 2E" )
end -- get_header()


-- Retrieve the unit identifier from the given configuration:
function get_unit( config ) -- -> unit
   local unit

   if type( config ) ~= "table" then 
      print( "OB6 get_unit(): unit identfier missing from supplied configuration" )
      return nil -- invalid argument
   end
   unit = config.unit
   if type( unit ) ~= "number" or ((unit < 0 or unit > 15) and unit ~= 0x7F) then
      print( "OB6 get_unit(): unit identifier out of valid range" )
      return nil -- out of range
   end
   
   return unit
end -- get_unit()


-- Construct a neme for the given program slot. The OB-6 does not store names 
-- for its programs, so just return the name of the program slot.
--
-- Parameters:
--  - slot: slot number of the program (0: edit buffer, 1-1000: stored program).
--
-- Returns nothing if the given slot number is invalid. Otherwise:
--  - name: program name.
function get_program_name( slot )
   local bank
   
   if type( slot ) == "number" then
      if slot >= 1 and slot <= 1000 then
         slot = slot - 1
         bank = slot // 100
         slot = slot % 100
         return "Bank " .. bank.. " Program " .. slot
      end
   end
end -- get_program_name()


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
   
   if slot >= 1 and slot <= 1000 then
      slot = slot - 1
      bank = slot // 100
      slot = slot % 100
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
   if #msg == 1176 then
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
   
   if #msg == 1178 then
      bank = string.byte( msg, 5 )
      slot = (bank * 100) + string.byte( msg, 6 ) + 1
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
--
-- Parameters:
--  - records: list of one octet string, the program data to encode;
--  - header: SysEx header for the message;
--
-- Returns:
--  - msgs: list of one octet string, encoded message.
function encode_edit_buffer_dump( records, header ) -- -> msgs
   local record
   
   record = records[1] 
   if #records ~= 1 or type( record ) ~= "string" or #record ~= 1024 then
      print( "OB-6 encode_edit_buffer_dump(): invalid records argument" )
      return nil -- invalid argument
   end 
   
   if type( name ) == "string" then
      record = set_program_name( record, name )
   end
   return { header .. string.char( 0x03 ) .. midi.pack( record ) .. string.char( 0xF7 ) }
end -- encode_edit_buffer_dump()


-- Encode a PROGRAM DATA DUMP message from the given data record.
--
-- Parameters:
--  - records: list of one octet string, the program data to encode;
--  - header: SysEx header for the message;
--  - slot: destination stored program slot number, 1-1024;
--
-- Returns:
--  - msgs: list of octet strings, encoded messages.
function encode_program_dump( records, header, slot )
   local record, bank

   record = records[1] 
   if #records ~= 1 or type( record ) ~= "string" or #record ~= 1024 then
      print( "OB-6 encode_program_dump(): invalid records argument" )
      return nil -- invalid argument
   end
   
   slot = slot - 1
   bank = slot // 100
   slot = slot % 100
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
   local channel_setting, channel, record, msgs, nrpn_map, count
   
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
      print( "OB-6 load_globals_command(): invalid records argument" )
      return nil
   end
   
   -- The MIDI channel assigned to the OB-6 is encoded into the third 
   -- byte of the global data. The OB-6 also uses this setting as its unit
   -- identifier. Update the global data record in accordance with the given
   -- unit identifier so we don't change this setting when the globals are applied.
   if #record >= 3 then
      record = string.sub( record, 1, 2 ) .. string.char( channel_setting ) .. 
         string.sub( record, 4 )
   end
   
   nrpn_map={ 1024, 1025, 1026, 1027, 1028, 1029, 1030, 1031, 1032, 1033,
              1035, 1037, 1039, 1040, 1041, 1042, 1043, 1044 }
   if #record > #nrpn_map then
      count = #nrpn_map
   else
      count = #record
   end
   msgs = {}
   for i = 1, count do
      msgs[i] = midi.set_nrpn( channel, nrpn_map[i], string.byte( record, i ) )
   end

   return msgs
end -- encode_global_data_dump()


-- MODULE FUNCTIONS:
local model = {}


function model.info()
   -- In the case of multiple OB-6s in a studio, each must be connected on a 
   -- separate MIDI output because SysEx messages for the OB-6 don't include a
   -- unit identifier to uniquely address each unit. However the unit identifier is 
   -- needed to restore the globals because this is accomplished via NRPN messages, 
   -- and the unit identifier designates the MIDI channel to transmit these messages 
   -- on.
   return {
      specification = 2,
      name = "Sequential OB-6",
      source = "Old Blue Bike Software inc.",
      version = "0.1",
      icon = "*.png", -- look for file with same path as this file with '.png' appended
      manufacturer = "01",
      family = "2E 01",
      slots = 1000,
      writable_slots = "1-500",
      unit_first = 0x7F,
      unit_last = 0x0F, 
      unit_factory = 0x7F,
      timeout = 50,
      notes = 
         "NO DAISY CHAINING:\n" ..
         "==================\n" ..
         "\n" ..
         "For SysEx data backup and restore, each OB-6 synthesizer must be connected to\n" ..
         "a separate MIDI output. This is because OB-6 SysEx messages do not include\n" ..
         "their unit identifier, which prevents uniquely addresssing each unit. Do not\n" ..
         "daisy-chain or otherwise connect multiple OB-6s via the MIDI THRU port or using\n" ..
         "a MIDI splitter interface.\n" ..
         "\n" ..
         "STORED PROGRAMS:\n" ..
         "================\n" ..
         "\n" ..
         "The OB-6 stores 1000 programs organized in 10 banks of 100 each. Banks 1-5\n" ..
         "(slots 1-500) contain user-defined programs that can be overwritten; banks\n" ..
         "6-10 (slots 501-1000) store the factory programs and cannot be modified. All\n" ..
         "1000 programs can be exported from the OB-6 via SysEx dump, but only the\n" ..
         "first 500 can be restored to the OB-6.\n" }      
end -- model.info()


function model.globals()
   return { "Settings" }
end -- model.globals()


function model.decode_software_version( msg ) -- -> sw_ver
   local byte, j, n

   if type( msg ) ~= "string" or #msg ~= 12 then 
      print( "OB6 decode_software_version(): invalid argument")
      return nil -- incorrect length
   end

   byte = string.byte( msg, 11 )
   if byte > 0x7F then
      print( "OB6 decode_software_version(): invalid version information" )
      return nil -- value out of range
   end

   j = ((byte >> 4) & 0x07)
   n = (byte & 0x0F)
   return n .. "." .. j
end


function model.dump_program_command( config, slot ) -- -> msgs, header, max_rsps
   local header, msgs

   header = get_header()
   if type( header ) ~= "string" then
      return nil -- invalid configuration
   end
   
   if slot == nil or slot == 0 then
      msgs = encode_edit_buffer_dump_command( header )
   elseif type( slot ) == "number" then
      msgs = encode_program_dump_command( header, slot )
   else
      print( "OB-6 dump_program_command(): invalid slot argument" )
      return nil
   end
   
   if type( msgs ) == "table" then
      return msgs, header, 1
   end
end -- model.dump_program_command()


function model.dump_globals_command( config, globals ) -- -> msgs, header, max_rsps
   local header, msgs

   header = get_header()
   if type( header ) ~= "string" then
      return nil -- invalid configuration
   end
   
   if globals == "Settings" then
      msgs = encode_global_parameter_dump_command( header )
   else
      print( "OB-6 dump_globals_command(): unknown globals \"" .. globals .. '\"' )
      return nil -- invalid configuration
   end

   if type( msgs ) == "table" then
      return msgs, header, 1
   end
end -- model.dump_globals_command()


function model.decode( msgs ) -- -> records
   local header, records, msg, ident, record, name, slot, bank

   if type( msgs ) ~= "table" then
      print( "OB-6 decode(): invalid msgs argument")
      return nil -- invalid argument
   end

   header = get_header()
   records = {}
   for i = 1, #msgs do
      msg = msgs[i]

      if type( msg ) == "string" and #msg >= 8 and
         string.sub( msg, 1, 3 ) == header and 
         string.byte( msg, -1 ) == 0xF7 then
         -- Valid OB-6 SysEx message:
         ident = string.byte( msg, 4 )
         
         if ident == 0x03 then
            -- PROGRAM EDIT BUFFER DATA DUMP message:
            record = decode_program_edit_buffer_dump( msg )
            if type( record ) == "string" then
               records[#records + 1] = "program:0"
               records[#records + 1] = "data:" .. record
            end
            
         elseif ident == 0x02 then
            -- PROGRAM DATA DUMP message:
            record, slot = decode_program_dump( msg )
            if type( record ) == "string" and type( slot ) == "number" then
               records[#records + 1] = "program:" .. slot
               name = get_program_name( slot )
               records[#records + 1] = "name:" .. name
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


function model.load_program_command( config, records, slot ) -- -> msgs
   local header

   header = get_header()
   if type( header ) ~= "string" then
      return nil -- invalid configuration
   end
   if type( records ) ~= "table" or #records == 0 then
      print( "OB-6 load_program_command(): invalid records argument")
      return nil -- invalid argument
   end
   
   if slot == nil or slot == 0 then
      return encode_edit_buffer_dump( records, header )
   elseif type( slot ) == "number" and slot >= 1 and slot <= 500 then
      return encode_program_dump( records, header, slot )
   else
      print( "OB-6 load_program_command(): invalid slot argument")
   end  
end -- model.load_program_command()


function model.load_globals_command( config, globals, records ) -- -> msgs
   local header, unit

   unit = get_unit( config )
   if unit == nil then
      return nil -- invalid configuration
   end
   if type( records ) ~= "table" or #records == 0 then
      print( "OB-6 load_globals_command(): invalid records argument")
      return nil -- invalid argument
   end

   header = get_header()
   
   if globals == "Settings" then
      -- Globals are restored to the OB-6 by transmitting NRPN messages
      -- (not SysEx), which are voice channel messages and require a MIDI 
      -- channel number. The MIDI channel number that the device receives on
      -- is encoded as its unit ID in the IDENTITY REPLY message, which we
      -- get here in the 'config' parameter. The unit ID is encoded as 127
      -- (0-based) if the device is configured to receive on any MIDI channel,
      -- in which case we will transmit on MIDI channel 1 (1-based).   
      return encode_global_data_dump( records, unit )
   else
      print( "OB-6 load_globals_command(): unknown globals \"" .. globals .. '\"' )
   end
end -- model.load_globals_command()


return model


-- EOF ob6.lua
