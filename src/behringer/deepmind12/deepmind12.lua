-- deepmind12.lua
--
-- MIDI Model Description (MMD) for Behringer DeepMind 12 Synthesizers.
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


-- MIDI MODEL DESCRIPTION (MMD) for the Behringer DeepMind 12
-- ==========================================================
--
-- Identification:
-- ---------------
--
-- The DeepMind 12 responds to the standard device inquiry IDENTITY REQUEST
-- message as follows:
--
--                   F0 7E gg 06 02 00 20 32 20 00 01 00 jn 00 ii nn F7
--                         --       -------- ----- ----- --    -----
--                          |           |      |     |    |      |
--            Unit ID ------+           |      |     |    |      |
--                                      |      |     |    |      |
--         Manufacturer ID (Behringer) -+      |     |    |      |
--                                             |     |    |      |
--                 Family ID (DeepMind 12)  ---+     |    |      |
--                                                   |    |      |
--                         Member ID (desktop)  -----+    |      |
--                                                        |      |
--                           Main software version  ------+      |
--                                                               |
--                             Voice software version  ----------+
--
-- where:
--  - unit ID: corresponds to the value of the "DEVICE-ID" global parameter in
--    the DeepMind 12, and is used to uniquely address each DeepMind 12 when
--    multiples are connected to the same MIDI output (either through a MIDI splitter
--    or daisy-chaining via the MIDI thru port);
--  - manufacturer code = 0x3220 (DeepMind 12D);
--  - family code = 0x0020 (DeepMind 12);
--  - member code = 0x0001 (desktop);
--  - main sofware version (n.j);
--  - voice software version (nn.ii).
--
-- Program Data:
-- -------------
--
-- Program data for the DeepMind 12 consists of 242 8-bit bytes. 
-- Each group of 7 consecutive bytes is encoded into an 8 x 7-bit word
-- packet for transmission over MIDI. The first 7-bit word of each packet 
-- contains the most significant bit of each of the 7 program data bytes. 
-- The first 238 bytes of program data are thus packed into 34 packets, 
-- and the remaining 4 bytes into a 5-word packet, for a total of 277 words.
--
-- Message identifiers:
-- --------------------
--
--  SysEx messages for the DeepMind12 have the following layout:
--   
--    F0 00 20 32 20 gg id ... F7
--
--  where:
--   gg: unit number (value of the "DEVICE-ID" parameter in globals);
--   id: message identifier (see below).
--
--   id  Description
--   00  APP NOTIFY REQUEST
--   01  PROGRAM DUMP REQUEST
--   02  PROGRAM DUMP RESPONSE
--   03  EDIT BUFFER DUMP REQUEST
--   04  EDIT BUFFER DUMP RESPONSE
--   05  GLOBAL PARAMETER DUMP REQUEST
--   06  GLOBAL PARAMETER DUMP RESPONSE
--   07  SINGLE USER PATTERN DUMP REQUEST
--   08  SINGLE USER PATTERN DUMP RESPONSE
--   09  PROGRAM BANK DUMP REQUEST
--   0A  PROGRAM BANK NAMES DUMP REQUEST
--   0B  PROGRAM BANK NAMES DUMP RESPONSE
--   0C  SINGLE PROGRAM NAME DUMP REQUEST
--   0D  SINGLE PROGRAM NAME DUMP RESPONSE
--   0E  EDIT BUFFER PATTERN DUMP REQUEST 
--   0F  EDIT BUFFER PATTERN DUMP RESPONSE
--   10  APP NOTIFY RESPONSE
--   11  CALIBRATION DATA DUMP REQUEST
--   12  CALIBRATION DATA DUMP RESPONSE
--   1B  CHORD MEMORY DUMP REQUEST
--   1C  CHORD MEMORY DUMP RESPONSE
--   1D  POLYCHORD MEMORY DUMP REQUEST
--   1E  POLYCHORD MEMORY DUMP RESPONSE
--
-- Communications Protocol Versioning:
-- -----------------------------------
--
-- Many DeepMind 12 messages include a communications protocol version code 
-- indicating the particular version of the messages. At the time of this
-- writing, only two versions are known to exist:
--  - 0x06: version used by the original released firmware;
--  - 0x07: version used by the upgraded firmware 1.1.2.
--
-- This MMD preserves the protocol version code of messages received from 
-- the DeepMind 12 and transmits such messages using the same protocol version.
-- As new versions of the DeepMind 12 firmware become available, they are
-- expected to be backward-compatible and able to interpret older versions of 
-- the protocol. However restoring settings from a device running newer firmware
-- to one running older firmware is unlikely to work as the older firmware
-- device won't know how to interpret new versions of the protocol. All devices
-- should be upgraded to the latest version of the firmware before settings
-- from one can reliably be applied to another.
--

-- HELPER ROUTINES:

-- Remove trailing whitespaces from given string:
function trim( s )
   local i
   
   i = #s
   while i >= 1 and string.sub( s, i, i ) == " " do
      i = i - 1
   end
   return string.sub( s, 1, i )
end -- trim()


-- Make SysEx message header including the unit number from supplied configuration:
function get_header( config ) -- -> header
   local unit
   
   if type( config ) ~= "table" then 
      print( "DeepMind12 get_header(): unit identifier not found" )
      return nil -- invalid argument
   end
   unit = config.unit
   if type( unit ) ~= "number" or 
      ((unit < 0 or unit > 15) and unit ~= 0x7F) then
      print( "DeepMind12 get_header(): unit identifier invalid" )
      return nil -- out of range
   end
   return midi.hex_to_octets( { "F0 00 20 32 20", unit } )
end -- get_header()

   
-- Extract the name of a program from the given program data record.
--
-- Parameters:
--  - record: octet string of the form "<comms><data>" where <comms> (first byte)
--    is the communications protocol version of the data, and <data> (byte 2
--    onwards) is the program data;
--
-- Returns:
--  - name: name of the program or nil if the communications protocol version
--    of the record is unsupported or the program is unnamed.
function get_program_name( record )
   local i
   
   if string.byte( record, 1 ) == 0x07 then
      i = 225 -- name field range 225-240 inclusive (length 16)
      while i <= 240 and string.byte( record, i ) ~= 0 do
         i = i + 1
      end
      if i > 225 then
         return trim( string.sub( record, 225, i - 1 ) )
      end
   end
end -- get_program_name()


-- Replace the name of a program if the communications protocol version 
-- of its data record is supported, otherwise return the given record unmodified.
-- Truncate the new name if its length exceeds the maximum allowed.
--
-- Parameters:
--  - record: octet string of the form "<comms><data>" where <comms> (first byte)
--    is the communications protocol version of the data, and <data> (byte 2
--    onwards) is the program data;
--  - name: new name of the program
--
-- Returns:
--  - record: the updated program data record.
function set_program_name( record, name ) -- -> record
   if string.byte( record, 1 ) == 0x07 then
      name = name .. string.rep( " ", 16 )
      record = string.sub( record, 1, 224 ) .. string.sub( name, 1, 16 ) ..
         string.sub( record, 241 )
   end
   return record
end -- set_program_name()


-- Construct an EDIT BUFFER DUMP REQUEST command.
--
-- Parameters:
--  - header: SysEx header for the messages, including the unit identifier 
--    of the target device.
--
-- Returns:
--  - msgs: a list of one octet string with the encoded message.
function encode_edit_buffer_dump_command( header ) -- -> msgs
   return { header .. midi.hex_to_octets( "03 F7" ) }
end -- encode_edit_buffer_dump_command()


-- Construct a PROGRAM DUMP REQUEST command.
--
-- Parameters:
--  - header: SysEx header for the messages, including the unit identifier 
--    of the target device.
--  - slot: requested stored program slot number, 1-1024.
--
-- Returns:
--  - msgs: a list of one octet string with the encoded message.
function encode_program_dump_command( header, slot ) -- -> msgs
   local bank
   
   if slot >= 1 and slot <= 1024 then
      slot = slot - 1
      bank = slot // 128
      slot = slot % 128
      return { header .. midi.hex_to_octets( { "01", bank, slot, "F7" } ) }
   end
end -- encode_program_dump_command()


-- Construct a GLOBAL PARAMETER DUMP REQUEST command.
--
-- Parameters:
--  - header: SysEx header for the messages, including the unit identifier 
--    of the target device.
--
-- Returns:
--  - msgs: a list of one octet string with the encoded message.
function encode_global_parameter_dump_command( header ) -- -> msgs
   return { header .. midi.hex_to_octets( { 0x05, 0xF7 } ) }
end -- encode_global_parameter_dump_command()


-- Construct a sequence of SINGLE USER PATTERN DUMP REQUEST messages to 
-- command a DeepMind 12 to transmit all its user-defined sequencer patterns.
--
-- Parameters:
--  - header: SysEx header for the messages, including the unit identifier 
--    of the target device.
--
-- Returns:
--  - msgs: a list of one octet string with the encoded message.
function encode_user_patterns_dump_command( header ) -- -> msgs
   local msgs
   
   msgs = {}
   for i = 0, 31 do
      msgs[i + 1] = header .. midi.hex_to_octets( { 0x07, i, 0xF7 } )
   end
   return msgs
end -- encode_user_patterns_dump_command()


-- Construct a CHORD MEMORY DUMP REQUEST command.
--
-- Parameters:
--  - header: SysEx header for the messages, including the unit identifier 
--    of the target device.
--
-- Returns:
--  - msgs: a list of one octet string with the encoded message.
function encode_chord_memory_dump_command( header ) -- -> msgs
   return { header .. midi.hex_to_octets( { 0x1B, 0xF7 } ) }
end -- encode_chord_memory_dump_command()


-- Construct a POLY CHORD MEMORY DUMP REQUEST command.
--
-- Parameters:
--  - header: SysEx header for the messages, including the unit identifier 
--    of the target device.
--
-- Returns:
--  - msgs: a list of one octet string with the encoded message.
function encode_poly_chord_memory_dump_command( header )
   return { header .. midi.hex_to_octets( { 0x1D, 0xF7 } ) }
end -- encode_poly_chord_memory_dump_command()


-- Construct a CALIBRATION DATA DUMP REQUEST command.
--
-- Parameters:
--  - header: SysEx header for the messages, including the unit identifier 
--    of the target device.
--
-- Returns:
--  - msgs: a list of one octet string with the encoded message.
function encode_calibration_data_dump_command( header )
   return { header .. midi.hex_to_octets( { 0x11, 0xF7 } ) }
end -- encode_calibration_data_dump_command()


-- Decode an EDIT BUFFER DUMP RESPONSE message.
--
-- Parameters:
--  - msg: message to decode.
--
-- Returns:
--  - record: octet string of the form "<comms><data>" where <comms> (first byte)
--    is the communications protocol version of the data, and <data> (byte 2
--    onwards) is the program data;
function decode_edit_buffer_dump( msg ) -- -> record
   local comms_version, record
   
   comms_version = string.byte( msg, 8 )
   record = string.char( comms_version ) .. midi.unpack( string.sub( msg, 9, -2 ) )
   return record
end -- decode_edit_buffer_dump()


-- Decode a PROGRAM DUMP RESPONSE message.
--
-- Parameters:
--  - msg: message to decode
--
-- Returns:
--  - record: octet string of the form "<comms><data>" where <comms> (first byte)
--    is the communications protocol version of the data, and <data> (byte 2
--    onwards) is the program data;
--  - slot: stored program slot number of the program in the source device;
--  - name: program name (character string if known, nil otherwise).
function decode_program_dump( msg ) -- -> record, slot
   local comms_version, bank, slot, record
   
   if #msg >= 12 then
      comms_version = string.byte( msg, 8 )
      bank = string.byte( msg, 9 )
      slot = ((bank * 128 + string.byte( msg, 10 )) % 1024) + 1
      record = string.char( comms_version ) .. midi.unpack( string.sub( msg, 11, -2 ) )
      return record, slot
   end
end -- decode_program_dump()


-- Decode a GLOBAL PARAMETER DUMP RESPONSE message.
--
-- Parameters:
--  - msg: message to decode;
--
-- Returns:
--  - record: octet string of the form "<comms><data>" where <comms> (first byte)
--    is the communications protocol version of the data, and <data> (byte 2
--    onwards) is the global parameter data;
function decode_global_parameter_dump( msg ) -- -> record
   local comms_version, data
   
   if #msg >= 10 then
      comms_version = string.byte( msg, 8 )
      data = midi.unpack( string.sub( msg, 9, -2 ) )
      return string.char( comms_version ) .. data
   end
end -- decode_global_parameter_dump()


-- Decode a SINGLE USER PATTERN DUMP RESPONSE message.
--
-- Parameters:
--  - msg: message to decode;
--
-- Returns:
--  - record: octet string of the form "<comms><idx><data>" where:
--     . <comms> (first byte) is the communications protocol version of the 
--       data;
--     . <idx> (second byte) is the index of the pattern (range 0-31);
--     . <data> (byte 3 onwards) is the sequencer pattern data.
--  - idx: index of the pattern (range 0-31).
function decode_user_pattern_dump( msg, header ) -- -> record, idx
   local comms_version, idx, record

   if #msg >= 11 then
      comms_version = string.byte( msg, 8 )
      idx = string.byte( msg, 9 )
      record = string.char( comms_version ) .. string.char( idx ) .. 
         midi.unpack( string.sub( msg, 10, -2 ) )
      return record, idx
   end
end -- decode_user_pattern_dump()

  
-- Decode a CHORD MEMORY DUMP RESPONSE message.
--
-- Parameters:
--  - msg: message to decode;
--
-- Returns:
--  - record: octet string of the form "<comms><data>" where <comms> (first byte)
--    is the communications protocol version of the data, and <data> (byte 2
--    onwards) is the chord memory data;
function decode_chord_memory_dump( msg ) -- -> record
   local comms_version, data
   
   if #msg >= 10 then
      comms_version = string.byte( msg, 8 )
      data = midi.unpack( string.sub( msg, 9, -2 ) )
      return string.char( comms_version ) .. data 
   end
end -- decode_chord_memory_dump()


-- Decode a POLY CHORD MEMORY DUMP RESPONSE message.
--
-- Parameters:
--  - msg: message to decode;
--
-- Returns:
--  - record: octet string of the form "<comms><data>" where <comms> (first byte)
--    is the communications protocol version of the data, and <data> (byte 2
--    onwards) is the poly chord memory data;
function decode_poly_chord_memory_dump( msg ) -- -> record
   local comms_version, data
   
   if #msg >= 10 then
      comms_version = string.byte( msg, 8 )
      data = midi.unpack( string.sub( msg, 9, -2 ) )
      return string.char( comms_version ) .. data    
   end
end -- decode_poly_chord_memory_dump()


-- Decode a CALIBRATION DATA DUMP RESPONSE message.
--
-- Parameters:
--  - msg: message to decode;
--
-- Returns:
--  - record: octet string of the form "<comms><data>" where <comms> (first byte)
--    is the communications protocol version of the data, and <data> (byte 2
--    onwards) is the calibration data;
function decode_calibration_data_dump( msg ) -- -> record
   local comms_version, data
   
   if #msg >= 10 then
      comms_version = string.byte( msg, 8 )
      data = midi.unpack( string.sub( msg, 9, -2 ) )
      return string.char( comms_version ) .. data
   end
end -- decode_calibration_data_dump()


-- Encode a EDIT BUFFER DUMP RESPONSE message from the given data record. If
-- a new name is given for the program, the name will be used to construct
-- the message, otherwise the exising name in the given program data will
-- be used.
--
-- Parameters:
--  - records: list of one octet string of the form "<comms><data>" where <comms>
--    (first byte) is the communications protocol version of the data, and <data>
--    (byte 2 onwards) is the program data;
--  - header: SysEx header for the message, including the unit identifier 
--    of the target device;
--  - name: optional program name.
--
-- Returns:
--  - msgs: list of one octet string, encoded message.
function encode_edit_buffer_dump( records, header, name ) -- -> msgs
   local record, comms_version, data
   
   record = records[1] 
   if #records ~= 1 or type( record ) ~= "string" or #record < 2 then
      print( "DeepMind12 encode_edit_buffer_dump(): invalid records argument" )
      return nil -- invalid argument
   end 
   
   if type( name ) == "string" then
      record = set_program_name( record, name )
   end
   comms_version = string.byte( record, 1 )
   data = string.sub( record, 2 )
   return { header .. midi.hex_to_octets( { 0x04, comms_version } ) ..
      midi.pack( data ) ..  string.char( 0xF7 ) }
end -- encode_edit_buffer_dump()


-- Encode a PROGRAM DUMP RESPONSE message from the given data record. If
-- a new name is given for the program, the name will be used to construct
-- the message, otherwise the exising name in the given program data will
-- be used.
--
-- Parameters:
--  - records: list of one octet string of the form "<comms><data>" where <comms>
--    (first byte) is the communications protocol version of the data, and <data>
--    (byte 2 onwards) is the program data;
--  - header: SysEx header for the message, including the unit identifier 
--    of the target device;
--  - slot: destination stored program slot number, 1-1024;
--  - name: optional program name.
--
-- Returns:
--  - msgs: list of octet strings, encoded messages.
function encode_program_dump( records, header, slot, name )
   local record, bank, comms_version

   record = records[1] 
   if #records ~= 1 or type( record ) ~= "string" or #record < 2 then
      print( "DeepMind12 encode_program_dump(): invalid records argument" )
      return nil -- invalid argument
   end
   
   slot = slot - 1
   bank = slot // 128
   slot = slot % 128
   if type( name ) == "string" then
      record = set_program_name( record, name )
   end
   comms_version = string.byte( record, 1 )
   data = string.sub( record, 2 )
   return { header .. midi.hex_to_octets( { 0x02, comms_version, bank, slot } ) ..
      midi.pack( data ) .. string.char( 0xF7 ) }
end -- encode_program_dump()


-- Encode a GLOBAL PARAMETER DUMP RESPONSE message from the given data record.
--
-- Parameters:
--  - records: list of one octet string of the form "<comms><data>" where <comms>
--    (first byte) is the communications protocol version of the data, and <data>
--    (byte 2 onwards) is the global parameter data;
--  - header: SysEx header for the message, including the unit identifier 
--    of the target device.
--
-- Returns:
--  - msgs: list of one octet string, encoded message.
function encode_global_parameter_dump( records, header ) -- -> msgs
   local record, comms_version, data, unit

   record = records[1] 
   if #records ~= 1 or type( record ) ~= "string" or #record < 2 then
      print( "DeepMind12 encode_global_parameter_dump(): invalid records argument" )
      return nil -- invalid argument
   end
   
   comms_version = string.byte( record, 1 )
   data = string.sub( record, 2 )
   
   -- The unit identifier ("DEVICE-ID") is encoded into the third byte of the
   -- data. Set this to the unit identifier in the given SysEx message header
   -- to prevent changing the unit's identifier when the globals are applied.
   -- NOTE: this is true at least for comms. protocol version 0x07, and is expected to
   -- be true for protocol version 0x06. If this was to change, the following needs
   -- to be amended to adjust in accordance with the version of the given record.
   unit = string.byte( header, 6 )
   data = string.sub( data, 1, 2 ) .. string.char( unit ) .. string.sub( data, 4 )
   
   return { header .. string.char( 0x06 ) .. string.char( comms_version ) ..
      midi.pack( data ) .. string.char( 0xF7 ) }
end -- encode_global_parameter_dump()


-- Construct a list of SINGLE USER PATTERN DUMP RESPONSE messages from given 
-- user-defined sequencer data records.
--
-- Parameters:
--  - records: list of octet strings of the form "<comms><idx><data>" where:
--     . <comms> (first byte) is the communications protocol version of the 
--       data;
--     . <idx> (second byte) is the index of the pattern (range 0-31);
--     . <data> (byte 3 onwards) is the sequencer pattern data.
--  - header: SysEx header for the message, including the unit identifier 
--    of the target device.
--
-- Returns:
--  - msgs: list of octet strings, encoded messages (one per input record).
function encode_user_pattern_dump( records, header ) -- -> msgs
   local msgs, record, comms_version, idx, data

   msgs = {}
   header = header .. string.char( 0x08 ) -- same msg type code in every msg
   for i = 1, #records do
      record = records[i]
      if type( record ) ~= "string" or #record < 3 then
         print( "DeepMind12 encode_user_pattern_dump(): invalid records argument" )
         return nil
      end
      
      comms_version = string.byte( record, 1 )
      idx = string.byte( record, 2 )
      data = string.sub( record, 3 )      
      msgs[i] = header .. string.char( comms_version ) .. string.char( idx ) ..
         midi.pack( data ) .. string.char( 0xF7 )
   end
   return msgs
end -- encode_user_pattern_dump()
   

-- Construct a CHORD MEMORY DUMP RESPONSE message.
--
-- Parameters:
--  - records: list of one octet string of the form "<comms><data>" where <comms>
--    (first byte) is the communications protocol version of the data, and <data>
--    (byte 2 onwards) is the global parameter data;
--  - header: SysEx header for the message, including the unit identifier 
--    of the target device.
--
-- Returns:
--  - msgs: list of one octet string, encoded message.
function encode_chord_memory_dump( records, header )
   local record, comms_version, data
   
   record = records[1] 
   if #records ~= 1 or type( record ) ~= "string" or #record < 2 then
      print( "DeepMind12 encode_chord_memory_dump(): invalid records argument" )
      return nil -- invalid argument
   end
   
   comms_version = string.byte( record, 1 )
   data = string.sub( record, 2 )
   return { header .. string.char( 0x1C ) .. string.char( comms_version ) .. 
      midi.pack( data ) .. string.char( 0xF7 ) }
end -- encode_chord_memory_dump()


-- Construct a POLY CHORD MEMORY DUMP RESPONSE message.
--
-- Parameters:
--  - records: list of one octet string of the form "<comms><data>" where <comms>
--    (first byte) is the communications protocol version of the data, and <data>
--    (byte 2 onwards) is the global parameter data;
--  - header: SysEx header for the message, including the unit identifier 
--    of the target device.
--
-- Returns:
--  - msgs: list of one octet string, encoded message.
function encode_poly_chord_memory_dump( records, header )
   local record, comms_version, data

   record = records[1] 
   if #records ~= 1 or type( record ) ~= "string" or #record < 2 then
      print( "DeepMind12 encode_poly_chord_memory_dump(): invalid records argument" )
      return nil -- invalid argument
   end
   
   comms_version = string.byte( record, 1 )
   data = string.sub( record, 2 )
   return { header .. string.char( 0x1E ) .. string.char( comms_version ) .. 
      midi.pack( data ) .. string.char( 0xF7 ) }
end -- encode_poly_chord_memory_dump()


-- Construct a CALIBRATION DATA DUMP RESPONSE message.
--
-- Parameters:
--  - records: list of one octet string of the form "<comms><data>" where <comms>
--    (first byte) is the communications protocol version of the data, and <data>
--    (byte 2 onwards) is the global parameter data;
--  - header: SysEx header for the message, including the unit identifier 
--    of the target device.
--
-- Returns:
--  - msgs: list of one octet string, encoded message.
function encode_calibration_data_dump( records, header )
   local record, comms_version, data

   record = records[1] 
   if #records ~= 1 or type( record ) ~= "string" or #record < 2 then
      print( "DeepMind12 encode_calibration_data_dump(): invalid records argument" )
      return nil -- invalid argument
   end
   
   comms_version = string.byte( record, 1 )
   data = string.sub( record, 2 )
   return { header .. string.char( 0x12 ) .. string.char( comms_version ) .. 
      midi.pack( data ) .. string.char( 0xF7 ) }
end -- encode_calibration_data_dump()


-- MMD FUNCTIONS:
local model = {}


function model.info() -- -> model_info
   return {
      specification= 2,
      name = "Behringer DeepMind 12",
      source = "Old Blue Bike Software inc.",
      version = "2.0",
      icon = "*.png", -- look for file with same path as this file with '.png' appended
      manufacturer = "00 20 32",
      family = "20",
      member = "01",
      unit_first = 0,
      unit_last = 15,
      unit_factory = 0,
      slots = 1024,
      timeout = 400 }
end -- model.info()


function model.globals() --> cat_list
   return {
      "Settings",
      "Sequencer Patterns", 
      "Chords",
      "Poly Chords",
      "Calibration" }
end -- model.globals()


function model.decode_software_version( msg ) -- -> sw_ver
   local n, ma, mi, va, vi

   if type( msg ) ~= "string" or #msg ~= 4 then 
      print( "DeepMind12 decode_software_version(): invalid argument")
      return nil -- incorrect length
   end

   n = string.byte( string.sub( msg, 1, 1 ) )
   if n > 0x7F then
      print( "DeepMind12 decode_software_version(): invalid version information" )
      return nil -- value out of range
   end

   ma = ((n >> 4) & 0x07)
   mi = (n & 0x0F)
   va = string.byte( string.sub( msg, 3, 3 ) )
   vi = string.byte( string.sub( msg, 4, 4 ) )

   if va > 0x7F or vi > 0x7F then
      print( "DeepMind12 decode_software_version(): invalid version information" )
      return nil -- value out of range
   end

   return { main = ma .. "." .. mi, voice = va .. "." .. vi }
end


function model.dump_program_command( config, slot ) -- -> msgs, header, max_rsps
   local header, msgs

   header = get_header( config )
   if type( header ) ~= "string" then
      return nil -- invalid configuration
   end
   
   if slot == nil or slot == 0 then
      msgs = encode_edit_buffer_dump_command( header )
   elseif type( slot ) == "number" then
      msgs = encode_program_dump_command( header, slot )
   else
      print( "DeepMind12 dump_program_command(): invalid slot argument" )
      return nil
   end
   
   if type( msgs ) == "table" then
      return msgs, header, 1
   end
end -- model.dump_program_command()


function model.dump_globals_command( config, globals ) -- -> msgs, header, max_rsps
   local header, msgs

   header = get_header( config )
   if type( header ) ~= "string" then
      return nil -- invalid configuration
   end
   
   if globals == "Settings" then
      msgs = encode_global_parameter_dump_command( header )
   elseif globals == "Sequencer Patterns" then
      msgs = encode_user_patterns_dump_command( header )
   elseif globals == "Chords" then
      msgs = encode_chord_memory_dump_command( header )
   elseif globals == "Poly Chords" then
      msgs = encode_poly_chord_memory_dump_command( header )
   elseif globals == "Calibration" then
      msgs = encode_calibration_data_dump_command( header )
   else
      print( "DeepMind12 dump_globals_command(): unknown globals \"" .. globals .. '\"' )
      return nil -- invalid configuration
   end

   if type( msgs ) == "table" then
      return msgs, header, 1
   end
end -- model.dump_globals_command()


function model.decode( msgs ) -- -> records
   local header, records, ident, idx, msg, last_ident, record, name, slot, last_idx

   if type( msgs ) ~= "table" or #msgs == 0 then
      print( "DeepMind12 decode(): invalid msgs argument")
      return nil -- invalid argument
   end

   header = midi.hex_to_octets( "F0 00 20 32 20" )
   records = {}
   for i = 1, #msgs do
      msg = msgs[i]

      if type( msg ) == "string" and #msg >= 8 and
         string.sub( msg, 1, 5 ) == header and 
         string.byte( msg, -1 ) == 0xF7 then
         -- Valid DeepMind 12 SysEx message:
         last_ident = ident
         ident = string.byte( msg, 7 )
         
         if ident == 0x04 then
            -- EDIT BUFFER DUMP RESPONSE message:
            record = decode_edit_buffer_dump( msg )
            if type( record ) == "string" then
               records[#records + 1] = "program:0"
               records[#records + 1] = "data:" .. record
               name = get_program_name( record )
               if type( name ) == "string" then
                  records[#records + 1] = "name:" .. name
               end
            end
            
         elseif ident == 0x02 then
            -- PROGRAM DUMP RESPONSE message:
            record, slot = decode_program_dump( msg )
            if type( record ) == "string" and type( slot ) == "number" then
               records[#records + 1] = "program:" .. slot
               records[#records + 1] = "data:" .. record
               name = get_program_name( record )
               if type( name ) == "string" then
                  records[#records + 1] = "name:" .. name
               end
            end
            
         elseif ident == 0x06 then
            -- GLOBAL PARAMETER DUMP RESPONSE message:
            record = decode_global_parameter_dump( msg )
            if type( record ) == "string" then
               records[#records + 1] = "globals:Settings"
               records[#records + 1] = "data:" .. record
            end
           
         elseif ident == 0x08 then
            -- SINGLE USER PATTERN DUMP RESPONSE message:
            last_idx = idx
            record, idx = decode_user_pattern_dump( msg )
            if type( record ) == "string" and type( idx ) == "number" then
               -- Start a new "Sequencer Patterns" records block only
               -- if the last message was not also a SINGLE USER PATTERN DUMP
               -- RESPONSE message for a lower-index pattern. This groups together
               -- the records of a sequencer patterns data dump in a single
               -- globals record block:
               if last_ident ~= 0x08 or type( last_idx ) ~= "number" or 
                  idx <= last_idx then
                  -- Start a new "Sequencer Patterns" globals data block:
                  records[#records + 1] = "globals:Sequencer Patterns"
               end
               records[#records + 1] = "data:" .. record
               last_idx = idx
            end
            
         elseif ident == 0x1C then
            -- CHORD MEMORY DUMP RESPONSE message:
            record = decode_chord_memory_dump( msg )
            if type( record ) == "string" then
               records[#records + 1] = "globals:Chords"
               records[#records + 1] = "data:" .. record
            end
            
         elseif ident == 0x1E then
            -- POLY CHORD MEMORY DUMP RESPONSE message:
            record = decode_poly_chord_memory_dump( msg )
            if type( record ) == "string" then
               records[#records + 1] = "globals:Poly Chords"
               records[#records + 1] = "data:" .. record
            end

         elseif ident == 0x12 then
            -- CALIBRATION DATA DUMP RESPONSE message:
            record = decode_calibration_data_dump( msg )
            if type( record ) == "string" then
               records[#records + 1] = "globals:Calibration"
               records[#records + 1] = "data:" .. record
            end
            
         -- else, ignore unsupported SysEx message type
         end 
      end -- if type( msg ) == "string" and ...
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
      print( "DeepMind12 load_program_command(): invalid records argument")
      return nil -- invalid argument
   end
   
   if slot == nil or slot == 0 then
      return encode_edit_buffer_dump( records, header, name )
   elseif type( slot ) == "number" and slot >= 1 and slot <= 1024 then
      return encode_program_dump( records, header, slot, name )
   else
      print( "DeepMind12 load_program_command(): invalid slot argument")
   end  
end -- model.load_program_command()


function model.load_globals_command( config, globals, records ) -- -> msgs
   local header

   header = get_header( config )
   if type( header ) ~= "string" then
      return nil -- invalid configuration
   end
   if type( records ) ~= "table" or #records == 0 then
      print( "DeepMind12 load_globals_command(): invalid records argument")
      return nil -- invalid argument
   end
   
   if globals == "Settings" then
      return encode_global_parameter_dump( records, header )
   elseif globals == "Sequencer Patterns" then
      return encode_user_pattern_dump( records, header )
   elseif globals == "Chords" then
      return encode_chord_memory_dump( records, header )
   elseif globals == "Poly Chords" then
      return encode_poly_chord_memory_dump( records, header )
   elseif globals == "Calibration" then
      return encode_calibration_data_dump( records, header )
   else
      print( "DeepMind12 load_globals_command(): unknown globals \"" .. globals .. '\"' )
   end
end -- model.load_globals_command()


return model


-- EOF deepmind12.lua
