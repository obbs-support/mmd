-- virus-ti.lua
--
-- MIDI Model Description (MMD) for Access Virus TI Synthesizers.
-- 
-- Copyright (C) 2022-2023, Old Blue Bike Software Inc.
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


-- MIDI MODEL DESCRIPTION (MMD) for the Access Virus TI
-- ====================================================
--
-- Identification:
-- ---------------
--
-- The Virus TI does not respond to the standard IDENTITY REQUEST message and cannot be
-- auto-detected in a generic manner.
--
-- SysEx Message Format:
-- ---------------------
--
-- SysEx messages for the Virus TI have the following format:
--   
--    F0 00 20 33 01 gg id [pp .. pp] [dd .. dd ss] F7
--
-- where:
--   gg: unit number;
--   id: message identifier (see below);
--   pp: parameter bytes (if any for message type);
--   dd: data bytes (if any for message type);
--   ss: checksum.
--
-- Message identifiers:
--   10: SINGLE DUMP
--   11: MULTI DUMP
--   30: SINGLE REQUEST
--   31: MULTI REQUEST
--   32: SINGLE BANK REQUEST
--   33: MULTI BANK REQUEST
--   34: ARRANGEMENT REQUEST
--   35: GLOBAL REQUEST
--
-- The checksum is included in data dump (DUMP) messages, not in command
-- (REQUEST) messages, and is calculated as (gg + id + pp ... + dd ...) modulo 
-- 128.
--
-- Program Data:
-- -------------
--
-- The Virus TI can be set in either one of two modes designated "single" and 
-- "multi". In single mode, the TI plays a single timbre. In multi mode, it becomes
-- a multi-timbral instrument capable to play a different timbre for each of 16 
-- parts. The parts can be layered and/or assigned to different sections of a split 
-- keyboard, and different MIDI channels.
-- 
-- Single Mode Programs:
--
-- A single mode program is defined by a 513-byte data record containing its parameters.
-- The program name is encoded in ASCII and stored in the 241st to 250th bytes (length 10)
-- of the record. 
--
-- The TI holds 26 (designated A to Z) read-only (ROM) and 4 (designated A to D)
-- read/write (RAM) banks of 128 single mode programs each, for a total of 3840 programs. 
-- An additional 256 memory locations are reserved for storing the parameters of the 16 
-- parts of 16 multi mode programs, and can only be used in their respective multi 
-- mode program (multi mode programs are discussed further below). Single mode programs
-- and multi mode program part data records share the same format.
--
-- A MIDI controller can command the retrieval of a single mode data record by 
-- transmitting a SINGLE REQUEST message to the TI as follows:
--
--                 F0 00 20 33 01 gg 30 bb nn F7
--                                --    -- -- 
--                                 |     |  |
--                   Unit ID ------+     |  |
--                                       |  |
--                         Bank number --+  |
--                                          |
--                       Program number  ---+
--
-- where bank number is one of:
--  - 0: edit buffer. The program number is 0-15 to select the desired part of the active 
--    multi mode program, or 0x40 for the active single mode program.
--  - 1-4: RAM bank A-D. Program number is 0-127;
--  - 5-30: ROM bank A-Z. Program number is 0-127;
--  - 32-47: embedded multi mode program 1-16. Program number is 0-15 selects the desired
--    part of the multi mode program.
--
-- Multi Mode Programs:
--
-- A multi mode program is fully defined by 16 single mode data records (one for each of
-- 16 parts) and a multi mode program data record with additional parameters that
-- configure layering and keyboard splits. The multi program data record consists of 256
-- byte-size values in range 0-127. 
--
-- The TI stores 128 multi mode programs. Programs 1-16 are referred to as "embedded"
-- multi mode programs because their parts are stored in single mode program banks 32-47
-- which are dedicated to them. The parts for multi mode programs 17-128 are defined by 
-- single programs in banks 1-30 and are included into the multi mode program by 
-- reference only. Changing the parameters of a single mode program in RAM banks A-D
-- will also modify any and all of multi mode programs 17-128 that reference it. Multis 
-- 17-128 are referred to as "traditional" multi mode programs because they are the
-- only kind of multis that were supported in previous versions of the Virus.
--
-- The multi mode program data record contains the multi mode program name as well as 
-- the bank and program numbers of the single mode programs that define its parts:
--
--   - 5th to 14th bytes: program name (ASCII);
--   - 33rd to 48th bytes: single mode program bank number for each of parts 1-16;
--   - 49th to 64th bytes: single mode program number for each of parts 1-16.
--
-- The bank and program numbers in the records of the embedded multi mode programs are
-- ignored, as the parts for these programs are always obtained from single mode 
-- program banks 32-47.
--
-- A MIDI controller can command the retrieval of a multi mode program data record by 
-- transmitting a MULTI REQUEST message to the TI as follows:
--
--                 F0 00 20 33 01 gg 31 bb nn F7
--                                --    -- -- 
--                                 |     |  |
--                   Unit ID ------+     |  |
--                                       |  |
--                         Bank number --+  |
--                                          |
--                       Program number  ---+
--
-- Bank number:
--  - 0: edit buffer. Program number is ignored;
--  - 1: stored traditional multi mode programs. Program number is 0-127;
--  - 50: stored embedded multi mode programs. Program number is 0-15.
--
-- The TI responds by transmitting the requested multi mode program data record in 
-- a MULTI DUMP message. The single mode program data records for each of the 16
-- parts must be queried separately using SINGLE REQUEST messages as follows:
--
--   - for the edit buffer: bank 0, program numbers 0-15;
--   - for embedded multis: bank 32-47 (for multi 1-16), program numbers 0-15;
--   - for traditional multis: bank and program numbers as indicated in the multi program
--     data record.
--
-- Program Data Records:
--
-- This MMD extracts the program data from SINGLE DUMP and MULTI DUMP messages into 
-- records with the following format:
--  - single mode program data record: octet string of the form "<type><part><data>"
--    where:
--     . <type>: always coded as 0x01 (for single mode program data record);
--     . <part>: 0x40 for all single mode programs; 0-15 for parts of a multi mode program;
--     . <data>: single mode program parameter bytes.
--  - multi mode program data record: octet string of the form "<type><data>" where:
--     . <type>: always coded as 0x02 (for multi mode program data record);
--     . <data>: multi mode program parameter bytes.
--
-- Program Slots and Capture and Restore:
--
-- This MMD assigns the Virus TI program slot numbers as follows:
--  - 0: edit buffer;
--  - 1-16: embedded multis;
--  - 17-128: traditional multis;
--  - 129-256: RAM bank A;
--  - 257-384: RAM bank B;
--  - 385-512: RAM bank C;
--  - 513-640: RAM bank D;
--  - 641-768: ROM bank A;
--  - 769-896: ROM bank B;
--    ...
--  - 3841-3968: ROM bank Z;
--
-- Slots 0-640 are writable; slots 641-3968 are read-only.
--
-- The 'dump_program_command()' implementation for this MMD constructs a command with
-- requests to retrieve all applicable data records depending on the requested program slot:
--
--  - 0 (edit buffer):
--     . SINGLE REQUEST for the active single mode program;
--     . SINGLE REQUEST for each of the 16 parts of the active multi mode program;
--     . MULTI REQUEST for the active multi mode program.
--  - 1-3840 (single mode program in RAM or ROM):
--     . SINGLE REQUEST for the requested single mode program.
--  - 3841-3856 (embedded multi mode program):
--     . SINGLE REQUEST for each of the 16 parts of the requested program;
--     . MULTI REQUEST for the multi mode program data record.
--  - 3857-3968 (traditional multi mode program):
--     . MULTI REQUEST for the multi mode program data record.
--
-- Thus a TI program may consist only of a single mode data record, or a multi mode data
-- record with 16 single mode data records for its parts, or both. The 'load_program_command()'
-- function encodes the SysEx data messages to restore all applicable records for the 
-- destination slot:
--  - if the destination slot is the edit buffer (0), all available single mode and multi mode
--    records are restored;
--  - if the destination is a single mode RAM bank slot (129-640), only the single mode data
--    record is restored. Any multi mode and parts data records in the program are ignored;
--  - if the destination is an embedded multi slot (1-16), only the multi mode and parts data
--    records are restored. Any single mode record in the program is ignored;
--  - if the destination is a traditional multi mode program slot (17-128), only the multi mode
--    data record is restored. Parts and single mode data records in the program are ignored.
--
-- Global Data:
-- ------------
--
-- <<TBD>>
--


-- HELPER ROUTINES:

-- Append the elements of the second table to the first, return the result:
function merge_tables( a, b )
   if type( a ) == "table" then
      if type( b ) == "table" then
         for i = 1, #b do
            a[#a + 1] = b[i]
         end
      end
      return a
   end
end -- merge_tables()


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
function make_header( config ) -- -> header
   local unit
   
   if type( config ) ~= "table" then 
      print( "VirusTI make_header(): unit identifier not found" )
      return nil -- invalid argument
   end
   unit = config.unit
   if type( unit ) ~= "number" or unit < 0 or unit > 16 then
      print( "VirusTI make_header(): unit identifier invalid" )
      return nil -- out of range
   end
   return midi.hex_to_octets( { "F0 00 20 33 01", unit } )
end -- make_header()

   
-- Calculate the checksum for message payload:
function checksum( data )
   local sum
   
   sum = 0
   for i = 1, #data do
      sum = sum + string.byte( data, i )
   end
   return (sum & 0x7F)
end -- checksum()


-- Construct a Virus TI SysEx data dump message. Data dump (DUMP) messages are 
-- different from command (REQUEST) messages in that they include a checksum.
--
-- Parameters:
--  - header: octet string, SysEx message header including the target device unit 
--    identifier;
--  - payload: octet string, message payload including the message identifier, any
--    parameter and data bytes.
--
-- Returns:
--  - msg: encoded message.
function make_message( header, payload ) -- -> msg
   local msg
   
   msg = header .. payload
   sum = checksum( string.sub( msg, 6 ) )
   return msg .. string.char( sum ) .. string.char( 0xF7 )
end -- make_message()


-- Extract the name of a program from the given program data record.
--
-- Parameters:
--  - record: octet string of the form "<type><data>" where <type> indicates 
--    the record type, 0x01 for single mode program data, 0x02 for multi mode 
--    program data;
--
-- Returns nothing if the given record is not a program data record, otherwise:
--  - name: name of the program.
function get_program_name( record )
   if #record >= 251 and string.byte( record ) == 0x01 then
      return trim( string.sub( record, 243, 252 ) )
   elseif #record >= 15 and string.byte( record ) == 0x02 then
      return trim( string.sub( record, 6, 15 ) )
   end
end -- get_program_name()


-- Replace the name of a program in the given program data record. Pad or 
-- truncate the given name to 10 characters as necessary.
--
-- Parameters:
--  - record: octet string of the form "<type><data>" where <type> indicates 
--    the record type, 0x01 for single mode program data, 0x02 for multi mode 
--    program data;
--  - name: new name of the program.
--
-- Returns the given record unchanged if it is not a program data record, 
-- otherwise:
--  - record: the updated program data record.
function set_program_name( record, name ) -- -> record
   name = string.sub( name .. string.rep( " ", 10 ), 1, 10 )
   if #record >= 252 and string.byte( record ) == 0x01 then
      record = string.sub( record, 1, 242 ) .. name .. string.sub( record, 253 )
   elseif #record >= 15 and string.byte( record ) == 0x02 then
      record = string.sub( record, 1, 5 ) .. name .. string.sub( record, 16 )
   end
   return record
end -- set_program_name()


-- Get the VirusTI bank and program numbers corresponding to the given single mode 
-- program data record index.
--
-- Parameters:
--  - index: single mode program data record index number:
--     . 0: single mode edit buffer;
--     . 1-16: parts 1-16 of multi mode program edit buffer
--     . 17-32: parts 1-16 of embedded multi mode program #1;
--     . 33-48: parts 1-16 of embedded multi mode program #2;
--       ...
--     . 256-272: parts 1-16 of embedded multi mode program #16.
--     . 273-400: stored single mode program data records 1-128, RAM bank A;
--     . 401-528: stored single mode program data records 1-128, RAM bank B;
--     . 529-656: stored single mode program data records 1-128, RAM bank C;
--     . 657-784: stored single mode program data records 1-128, RAM bank D;
--     . 785-912: stored single mode program data records 1-128, ROM bank A;
--     . 913-1040: stored single mode program data records 1-128, ROM bank B;
--       ...
--     . 3985-4112: stored single mode program data records 1-128, ROM bank Z;
--
-- Returns nothing if the index number is invalid, otherwise:
--  - number: Virus TI program number:
--     . single mode program: 0 for edit buffer, 0-127 for stored program;
--     . multi mode program: 0-15 for part number.
--  - bank: program bank number:
--     . single mode program: 0 for edit buffer, 1-4 for stored program;
--     . multi mode program: 0 for edit buffer, 1 for stored program;
function index_to_number( index ) -- -> number, bank
   local number, bank
   
   if index == 0 then
      return 0x40, 0
   elseif index >= 1 and index <= 16 then
      return (index - 1), 0
   elseif index >= 17 and index <= 272 then
      index = index - 17           -- 0-255
      bank = 0x20 + (index // 16)  -- 0x20-0x2F
      number = index % 16          -- 0-15
      return number, bank
   elseif index >= 273 and index <= 4112 then
      index = index - 273          -- 0-3839
      bank = (index // 128) + 1    -- 1-30
      number = index % 128         -- 0-127
      return number, bank
   end
end -- index_to_number()


-- Get the program slot corresponding to the given single mode program data record
-- index.
--
-- Parameters:
--  - index: single mode program index number:
--     . 0: single mode edit buffer;
--     . 1-16: parts 1-16 of multi mode program edit buffer
--     . 17-32: parts 1-16 of embedded multi mode program #1;
--     . 33-48: parts 1-16 of embedded multi mode program #2;
--       ...
--     . 256-272: parts 1-16 of embedded multi mode program #16.
--     . 273-400: stored single mode program data records 1-128, RAM bank A;
--     . 401-528: stored single mode program data records 1-128, RAM bank B;
--     . 529-656: stored single mode program data records 1-128, RAM bank C;
--     . 657-784: stored single mode program data records 1-128, RAM bank D;
--     . 785-912: stored single mode program data records 1-128, ROM bank A;
--     . 913-1040: stored single mode program data records 1-128, ROM bank B;
--       ...
--     . 3985-4112: stored single mode program data records 1-128, ROM bank Z;
--
-- Returns nothing if the index number is invalid, otherwise:
--  - number: Virus TI program number:
--     . single mode program: 0 for edit buffer, 0-127 for stored program;
--     . multi mode program: 0-15 for part number.
--  - bank: program bank number:
--     . single mode program: 0 for edit buffer, 1-4 for stored program;
--     . multi mode program: 0 for edit buffer, 1 for stored program;
function index_to_slot( index ) -- -> slot
   local slot
   
   if index >= 0 and index <= 16 then
      -- Single or multi mode program edit buffer
      return 0
   elseif index >= 17 and index <= 272 then
      index = index - 17          -- 0-255
      return (index // 16) + 1    -- 1-128
   elseif index >= 273 and index <= 4112 then
      -- Stored single mode program
      return (index - 272) + 128  -- 129-3968
   end
end -- index_to_slot()


-- Get the single mode program slot corresponding to the given single mode program
-- data record index.
--
-- Parameters:
--  - index: single mode program index number:
--     . 0: single mode edit buffer;
--     . 273-400: stored single mode program data records 1-128, RAM bank A;
--     . 401-528: stored single mode program data records 1-128, RAM bank B;
--     . 529-656: stored single mode program data records 1-128, RAM bank C;
--     . 657-784: stored single mode program data records 1-128, RAM bank D;
--     . 785-912: stored single mode program data records 1-128, ROM bank A;
--     . 913-1040: stored single mode program data records 1-128, ROM bank B;
--       ...
--     . 3985-4112: stored single mode program data records 1-128, ROM bank Z;
--
-- Returns nothing if the index number is invalid, otherwise:
--  - number: Virus TI program number:
--     . single mode program: 0 for edit buffer, 0-127 for stored program;
--     . multi mode program: 0-15 for part number.
--  - bank: program bank number:
--     . single mode program: 0 for edit buffer, 1-4 for stored program;
--     . multi mode program: 0 for edit buffer, 1 for stored program;
function index_to_single_slot( index ) -- -> slot
   local slot
   
   if index == 0 then
      -- Single mode program edit buffer:
      return 0
   elseif index >= 273 and index <= 4112 then
      -- Stored single mode program:
      return (index - 272) + 128  -- 129-3968
   end
end -- index_to_single_slot()


-- Make the list of single mode program data records referenced by a multi mode 
-- program data record.
--
-- Parameters:
--  - record: octet string of the form "<type><data>" where <type> indicates 
--    the record type, 0x02 for multi mode program data;
--  - slot: multi mode program slot number of the given record:
--     . 0: edit buffer;
--     . 513-528: embedded multi mode stored program;
--     . 529-640: traditional multi mode stored program.
--
-- Returns nothing if the given slot does not designate a multi mode program slot,
-- otherwise:
--  - list: list of 16 single mode program data record indices, each index as follows:
--     . 0: single mode edit buffer;
--     . 1-16: parts 1-16 of multi mode program edit buffer
--     . 17-32: parts 1-16 of embedded multi mode program #1;
--     . 33-48: parts 1-16 of embedded multi mode program #2;
--       ...
--     . 257-272: parts 1-16 of embedded multi mode program #16.
--     . 273-400: stored single mode program data records 1-128, RAM bank A;
--     . 401-528: stored single mode program data records 1-128, RAM bank B;
--     . 529-656: stored single mode program data records 1-128, RAM bank C;
--     . 657-784: stored single mode program data records 1-128, RAM bank D;
--     . 785-912: stored single mode program data records 1-128, ROM bank A;
--     . 913-1040: stored single mode program data records 1-128, ROM bank B;
--       ...
--     . 3985-4112: stored single mode program data records 1-128, ROM bank Z;
function make_part_list( record, slot )
   local bank, index, list
   
   if slot == 0 then
      -- indices of 16 multi mode parts in edit buffer:
      return { 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16 }
   elseif slot >= 1 and slot <= 16 then
      -- indices of stored embedded multi mode parts:
      list = {}
      index = (slot * 16) + 1 -- 17-257 in increment of 16
      for i = 1, 16 do
         list[i] = index
         index = index + 1
      end
      return list
   elseif slot >= 17 and slot <= 128 then
      -- retrieve indices of single mode programs referenced by traditional multi mode
      -- program data record:
      list = {}
      for i = 1, 16 do
         bank = string.byte( record, 33 + i ) -- 0-3
         index =  string.byte( record, 49 + i ) -- 0-127
         list[i] = 273 + (bank * 128) + index -- 273-784
      end
      return list
   end
end -- make_part_list()


-- Construct an SINGLE REQUEST message.
--
-- Parameters:
--  - header: SysEx header for the message, including the unit identifier 
--    of the target device;
--  - bank: program bank;
--  - number: program number.

--  - slot: requested single mode program slot, 1-512 or 0 (zero) for the
--    single mode program edit buffer.
--
-- Returns:
--  - msg: octet string with the encoded message.
function encode_single_request( header, bank, number ) -- -> msg
   return header .. midi.hex_to_octets( { 0x30, bank, number, 0xF7 } )
end -- encode_single_request()
   

-- Construct an MULTI REQUEST message.
--
-- Parameters:
--  - header: SysEx header for the message, including the unit identifier 
--    of the target device.
--  - bank: bank number;
--  - number: program number.
--
-- Returns:
--  - msg: octet string with the encoded message.
function encode_multi_request( header, bank, number ) -- -> msgs
   if type( number ) ~= "number" then
      number = 0x7F
   end
   return header .. midi.hex_to_octets( { 0x31, bank, number, 0xF7 } )
end -- encode_multi_request()


-- Construct a SINGLE BANK REQUEST command.
--
-- Parameters:
--  - header: SysEx header for the message, including the unit identifier 
--    of the target device.
--  - bank: single mode program bank number, 1-4 (A-D).
--
-- Returns:
--  - msg: octet string with the encoded message.
function encode_single_bank_request( header, bank ) -- -> msg
   if bank >= 0 or bank <= 4 then
      return header .. midi.hex_to_octets( { 0x32, bank, 0xF7 } )
   end
end -- encode_single_bank_request()


-- Construct a MULTI BANK REQUEST command.
--
-- Parameters:
--  - header: SysEx header for the message, including the unit identifier 
--    of the target device.
--
-- Returns:
--  - msg: octet string with the encoded message.
function encode_multi_bank_request( header ) -- -> msg
   return header .. midi.hex_to_octets( "33 01 F7" )
end -- encode_multi_bank_request()


-- Encode a SINGLE DUMP message from the given single mode program data 
-- record. 
--
-- Parameters:
--  - record: octet string, single mode program data record;
--  - header: octet string, SysEx header for the message, including the unit
--    identifier of the target device;
--  - bank: destination bank number;
--  - number: destination program number.
--
-- Returns nothing if the given program data record or the destination slot
-- is invalid, otherwise:
--  - msg: octet string, encoded message.
function encode_single_dump( record, header, bank, number ) -- -> msgs
   return make_message( header, midi.hex_to_octets( { 0x10, bank, number } ) .. 
      string.sub( record, 3 ) )
end -- encode_single_dump()


-- Encode a MULTI DUMP message from the given multi program data record. 
--
-- Parameters:
--  - record: octet string, multi mode program data record;
--  - header: octet string, SysEx header for the message, including the unit
--    identifier of the target device;
--  - bank: destination program bank (0: edit buffer; 1: traditional multi mode
--    program; 50: embedded multi mode program);
--  - number: destination program number (bank 0: ignored; bank 1: 0-127; bank 50: 0-31).
--
-- Returns:
--  - msg: octet string, encoded message.
function encode_multi_dump( record, header, bank, number ) -- -> msg
   return make_message( header, midi.hex_to_octets( { 0x11, bank, number } ) .. 
      string.sub( record, 2 ) )
end -- encode_multi_dump()


-- Construct a command to dump the edit buffer. The edit buffer contains both a 
-- single mode program as well as a multi mode program and its parts. The command
-- accordingly returns all requests necessary to dump all components.
--
-- Parameters:
--  - header: SysEx header for the message, including the unit identifier 
--    of the target device;
--
-- Returns:
--  - msgs: list of octet strings with the encoded messages.
function encode_edit_buffer_dump_command( header ) -- -> msg
   local msgs
   
   msgs = { encode_single_request( header, 0, 0x40 ) }  -- single mode program
   for i = 1, 16 do
      msgs[#msgs + 1] = encode_single_request( header, 0, i - 1 )  -- multi mode part
   end
   msgs[#msgs + 1] = encode_multi_request( header, 0 )  -- multi mode program
   return msgs
end -- encode_edit_buffer_dump_command()


-- Construct a command to dump a single mode program.
--
-- Parameters:
--  - header: SysEx header for the message, including the unit identifier 
--    of the target device;
--  - slot: requested single mode program slot (0, 129-3968)
--
-- Returns:
--  - msgs: list of one octet string with the encoded message.
function encode_single_mode_dump_command( header, slot ) -- -> msgs
   local bank, number
   
   if slot == 0 or slot == nil then
      return { encode_single_request( header, 0, 0x40 ) }
   elseif slot >= 129 and slot <= 3968 then
      slot = slot - 129         -- 0-3839
      bank = (slot // 128) + 1  -- 1-30 (1-4: RAM, 5-30: ROM)
      number = slot % 128       -- 0-127
      return { encode_single_request( header, bank, number ) }
   end   
end -- encode_single_mode_dump_command()


-- Construct a command to dump an embedded multi mode program. The command comprises the 
-- requests to dump the multi mode program data record as well as the single mode records
-- for all 16 parts.
--
-- Parameters:
--  - header: SysEx header for the message, including the unit identifier 
--    of the target device;
--  - slot: requested program slot (1-16).
--
-- Returns:
--  - msgs: list of octet strings with the encoded messages.
function encode_embedded_multi_mode_dump_command( header, slot ) -- -> msgs
   local bank
   
   if slot >= 1 and slot <= 16 then
      slot = slot - 1        -- 0-15
      bank = 0x20 + slot     -- 0x20-0x2F
      return {
         encode_single_bank_request( header, bank ),
         encode_multi_request( header, 0x32, slot ) }
   end
end -- encode_embedded_multi_mode_dump_command()


-- Construct a command to dump all traditional multi mode programs, which include their
-- parts by reference to single mode programs. The command therefore comprises the
-- requests to dump:
--  - all single mode programs (RAM banks A-D as well as ROM banks A-Z);
--  - all traditional multi mode program data records (bank number 1, program numbers 16-127).
-- 
-- Thus the command always dumps all the data necessary to construct all 112 traditional
-- multi mode programs, regardless of which particular traditional program slot is requested.
--
-- Parameters:
--  - header: SysEx header for the message, including the unit identifier 
--    of the target device;
--
-- Returns:
--  - msgs: list of octet strings with the encoded messages.
function encode_traditional_multi_mode_dump_command( header ) -- -> msgs
   local msgs
   
   msgs = {}
   for i = 1, 30 do
      msgs[i] = encode_single_bank_request( header, i )
   end
   msgs[31] = encode_multi_bank_request( header )
   return msgs
end -- encode_embedded_multi_mode_dump_command()


-- Decode a SINGLE DUMP message to extract the single mode program
-- data record.
--
-- Parameters:
--  - msg: message to decode.
--
-- Returns:
--  - record: octet string, single mode program data record;
--  - index: program index number in the originating device:
--     . 0: single mode edit buffer;
--     . 1-16: parts 1-16 of multi mode program edit buffer
--     . 17-32: parts 1-16 of embedded multi mode program #1;
--     . 33-48: parts 1-16 of embedded multi mode program #2;
--       ...
--     . 257-272: parts 1-16 of embedded multi mode program #16.
--     . 273-400: stored single mode program data records 1-128, RAM bank A;
--     . 401-528: stored single mode program data records 1-128, RAM bank B;
--     . 529-656: stored single mode program data records 1-128, RAM bank C;
--     . 657-784: stored single mode program data records 1-128, RAM bank D;
--     . 785-912: stored single mode program data records 1-128, ROM bank A;
--     . 913-1040: stored single mode program data records 1-128, ROM bank B;
--       ...
--     . 3985-4112: stored single mode program data records 1-128, ROM bank Z;
function decode_single_dump( msg ) -- -> record, index
   local record, bank, index
   
   if #msg > 11 and checksum( string.sub( msg, 6, -3 ) ) == string.byte( msg, -2 ) then
      bank = string.byte( msg, 8 ) -- 0 for edit buffer 1-30 for stored single,
                                   -- 32-47 for part of embedded multi 1-16.
      index = string.byte( msg, 9 ) -- 0x40 or 0x7F for single mode, 0-15 for multi mode part
      if bank == 0 and (index == 0x7F or index == 0x40) then
         -- Single mode program edit buffer:
         record = string.char( 0x01 ) .. string.char( 0x40 ) .. string.sub( msg, 10, -3 )
         return record, 0
      elseif bank == 0 and index <= 15 then
         -- Multi mode program part edit buffer:
         record = string.char( 0x01 ) .. string.char( index ) .. string.sub( msg, 10, -3 )
         return record, (index + 1)
      elseif bank >= 1 and bank <= 30 and index <= 127 then
         -- Stored single mode program:
         record = string.char( 0x01 ) .. string.char( 0x40 ) .. string.sub( msg, 10, -3 )
         bank = bank - 1                  -- 0-3 for RAM bank A-D, 4-29 for ROM bank A-Z
         index = 273 + bank * 128 + index -- 273-4112
         return record, index
      elseif bank >= 0x20 and bank <= 0x2F and index <= 0x0F then         
         -- Data is from embedded multi mode program:
         record = string.char( 0x01 ) .. string.char( index ) .. string.sub( msg, 10, -3 )
         bank = bank - 0x20    -- 0-15 for embedded multi mode program 1-16
         index = 17 + (bank * 16) + index -- 17-272
         return record, index
      end
      -- else message with invalid bank and/or program number.
   end
end -- decode_single_dump()


-- Decode a MULTI DUMP message.
--
-- Parameters:
--  - msg: message to decode.
--
-- Returns:
--  - record: octet string, multi mode program data record;
--  - slot: source program slot number in the originating device:
--     . 0: edit buffer;
--     . 1-16: embedded multi mode stored program;
--     . 17-128: traditional multi mode stored program.
function decode_multi_dump( msg ) -- -> record, slot
   local record, bank, number
   
   if #msg > 11 and checksum( string.sub( msg, 6, -3 ) ) == string.byte( msg, -2 ) then
      record = string.char( 0x02 ) .. string.sub( msg, 10, -3 )
      bank = string.byte( msg, 8 )
      number = string.byte( msg, 9 )
      if bank == 0 then
         -- Program is from the edit buffer:
         return record, 0
      elseif (bank == 1 and number >= 16 and number <= 127) or
             (bank == 0x32 and number >= 0 and number <= 15) then      
         -- Stored traditional multi mode program
         return record, (number + 1)
      end
      -- else message with invalid program number.
   end
end -- decode_multi_dump()


-- Encode a SINGLE DUMP message to restore the single mode program record in the given list
-- to the given slot. If the given records list contains multiple single mode program data 
-- records, encode only the first occurrence. If a new name is given for the program, use the 
-- name to construct the message, otherwise keep the existing name.
--
-- Parameters:
--  - records: list of one octet string, single mode program data record;
--  - header: octet string, SysEx header for the message, including the unit
--    identifier of the target device;
--  - slot: destination program slot (0: edit buffer; 129-640: stored program);
--  - name: optional program name.
--
-- Returns an empty list if the given records list does not contain a single mode program
-- data record, otherwise:
--  - msgs: list of at most one octet string, encoded message.
function encode_single_mode_program( records, header, slot, name ) -- -> msgs
   local record, bank, number, msgs
   
   if slot == 0 then
      -- destination is edit buffer, restore active single mode program:
      bank = 0
      number = 0x40
   elseif slot >= 129 and slot <= 640 then
      -- destination is RAM bank, restore single mode program to corresponding
      -- slot:
      slot = slot - 129          -- 0-511
      bank = (slot // 128) + 1   -- 1-30
      number = slot %128         -- 0-127
   end
   
   msgs = {}
   for i = 1, #records do   
      record = records[i]
      if type( record ) == "string" and #record >= 3 and
         string.byte( record, 1 ) == 0x01 and string.byte( record, 2 ) == 0x40 then
         -- Found single mode program data record:
         if type( name ) == "string" then
            record = set_program_name( record, name )
         end
   
         msgs[#msgs + 1] = encode_single_dump( record, header, bank, number )
         break -- ignore remaining records
      end
   end
   return msgs
end --encode_single_mode_program()


-- Encode a multi mode program from the given records list. If the records list 
-- contains multiple single mode data records for the same part, or more than one 
-- multi mode data record, ignore the additional records.
--
-- If a new name is given for the program, use it to construct the MULTI DUMP message
-- to restored the multi mode program parameters. Otherwise, keep the existing name.
--
-- Parameters:
--  - records: list of one octet string, single mode program data record;
--  - header: octet string, SysEx header for the message, including the unit
--    identifier of the target device;
--  - slot: destination program slot (0: edit buffer; 1-512: stored program);
--  - name: optional program name.
--
-- Returns nothing if records does not contain exactly one single program data
-- record or the given slot argument does not designate a single mode program
-- slot, otherwise:
--  - msgs: list of octet strings, encoded messages.
function encode_multi_mode_program( records, header, slot, name )
   local msgs, multi_bank, multi_number, single_bank, single_number, parts, record, tag, part
   
   if slot == 0 then
      -- edit buffer:
      multi_bank = 0
      multi_number = 0x7F
      single_bank = 0
      parts = 0
   elseif slot >= 1 and slot <= 16 then
      -- embedded multi mode program:
      multi_bank = 50
      multi_number = slot - 1            -- 0-15
      single_bank = 0x20 + multi_number  -- 0x20-0x2F
      parts = 0
   elseif slot >= 17 and slot <= 128 then
      -- traditional multi mode program does not store the parameters of its 16 parts:
      multi_bank = 1
      multi_number = slot - 1            -- 16-127    
      parts = 0xFFFF
   else
      -- slot does not store a multi mode program:
      parts = 0x1FFFF
   end
   
   msgs = {}
   for i = 1, #records do
      record = records[i]
      if type( record ) == "string" and #record >= 3 then
         tag = string.byte( record, 1 )
         if tag == 0x01 then
            -- single mode data record:
            part = string.byte( record, 2 )
            if part <= 15 then
               -- for part 1-16 of multi mode program:
               single_number = part
               part = 1 << part
               if (parts & part) == 0 then
                  -- part not yet populated, encode SINGLE DUMP with data:
                  msgs[#msgs + 1] = encode_single_dump( record, header, single_bank, single_number )
                  parts = parts | part
               end
            end
         elseif tag == 0x02 then
            -- multi mode data record:
            part = 1 << 16
            if (parts & part) == 0 then
               -- not yet populated, encode MULTI DUMP with data:
               if type( name ) == "string" then
                  record = set_program_name( record, name )
               end
               msgs[#msgs + 1] = encode_multi_dump( record, header, multi_bank, multi_number )
               parts = parts | part
            end
         end
      end              
   end
   return msgs
end -- encode_multi_mode_program()


-- MMD FUNCTIONS:
local model = {}


function model.info() -- -> model_info
   return {
      specification = 2,
      name = "Access Virus TI",
      source = "Old Blue Bike Software inc.",
      version = "0.1 alpha",
      icon = "*.png", -- look for file with same path as this file with '.png' appended
      manufacturer = "00 20 33",
      family = "01",
      member = "01",
      probe = "none",
      unit_first = 0,
      unit_last = 16,
      unit_factory = 16,
      slots = 3968,
      writable_slots = "1-640",
      timeout = 1000,
      notes = 
         "This is an alpha implementation of the MMD for the Access Virus TI. It has\n" ..
         "undergone limited amount of testing: offers for help to test interoperation\n" ..
         "with an actual device are most welcome. Please contact 'support@oldbluebike.com'.\n" ..
         "\n" ..
         "The Virus TI stores both single mode as well as multi mode programs. In multi\n" ..
         "mode, it is a multitimbral instrument with up to 16 parts that can be layered\n" ..
         "and/or assigned to different sections of a split keyboard. At any given time,\n" ..
         "the edit buffer in the TI always contains both a single mode as well as a multi\n" ..
         "mode program and the user may toggle between the two modes during play.\n" ..
         "\n" ..
         "Accordingly, this MMD considers a Virus TI program to consist of both a single\n" ..
         "mode and a multi mode component, both of which optional. Capturing from the\n" ..
         "edit buffer creates a program that contains both components; capturing from a\n" ..
         "multi mode program slot produces a program with no single mode component, and\n" ..
         "capturing from a single mode program slot, a program with no multi mode\n" ..
         "component. Restoring a program to the Virus TI restores all captured program\n" ..
         "components that can be stored in the destination slot.\n" ..
         "\n" ..
         "Stored programs are referenced by the following slot numbers:\n" ..
         " - 1-128: multi mode programs;\n" ..
         " - 129-256: RAM bank A single mode programs 1-128;\n" ..
         " - 257-384: RAM bank B single mode programs 1-128;\n" ..
         " - 385-512: RAM bank C single mode programs 1-128;\n" ..
         " - 513-640: RAM bank D single mode programs 1-128;\n" ..
         " - 641-768: ROM bank A single mode programs 1-128;\n" ..
         " - 769-896: ROM bank B single mode programs 1-128;\n" ..
         "   ...\n" ..
         " - 3841-3968: ROM bank Z single mode programs 1-128.\n" }
end -- model.info()


function model.dump_program_command( config, slot ) -- -> msgs, header, max_rsps
   local header, msgs

   header = make_header( config )
   if type( header ) ~= "string" then
      return nil -- invalid configuration
   end
   
   if slot == nil or slot == 0 then
      msgs = encode_edit_buffer_dump_command( header )
   elseif slot >= 1 and slot <= 16 then 
      msgs = encode_embedded_multi_mode_dump_command( header, slot )
   elseif slot >= 17 and slot <= 128 then
      msgs = encode_traditional_multi_mode_dump_command( header )
   elseif slot >= 129 and slot <= 3968 then
      msgs = encode_single_mode_dump_command( header, slot )
   else
      print( "VirusTI dump_program_command(): invalid slot argument" )
   end

   if type( msgs ) == "table" then
      return msgs, header
   end
end -- model.dump_program_command()


function model.decode( msgs ) -- -> records
   local program, empty, parts, header, records, msg, ident, record, index, slot, part_list, multi

   if type( msgs ) ~= "table" or #msgs == 0 then
      print( "VirusTI decode(): invalid msgs argument")
      return nil -- invalid argument
   end

   -- 'program' is a table with the information about the current program being decoded:
   --  . slot: source program slot (0-3968). 'nil' if the program is uninitialized (contains
   --    neither a single nor a multi mode component);
   --  . single: single mode data record for the single mode component. 'nil' if the program
   --    does not have a single mode component;
   --  . parts: list of up to 16 single mode data records for parts of the multi mode component;
   --  . multi: multi mode data record for the multi mode component. 'nil' if the program
   --    does not have a multi mode component.
   function clear_program()
      program = { slot = nil, single = nil, parts = {}, multi = {} }
   end -- clear_program()
   
   -- 'append' is a local function that appends the records of a complete program to the
   -- 'records' list:
   function append_program()
      local record, slot
      
      slot = program.slot
      if type( slot ) == "number" then
         records[#records + 1] = "program:" .. slot
         
         if type( program.single ) == "string" then         
            -- Program has a single mode component. Use its name for the program name:
            records[#records + 1] = "name:" .. get_program_name( program.single )
         elseif type( program.multi ) == "string" then
            -- Program has no single mode component, but has a multi mode component. Use the 
            -- multi mode component's name as the program name:
            records[#records + 1] = "name:" .. get_program_name( program.multi )
         end
         
         if type( program.single ) == "string" then
            records[#records + 1] = "data:" .. program.single
         end
         if type( program.multi ) == "string" then
            for i = 1, #parts do
               record = program.parts[i]
               if type( record ) == "string" then
                  records[#records + 1] = "data:" .. record
               end
            end
            records[#records + 1] = "data:" .. program.multi
         end
         
         clear_program()
      end
   end -- append_program()

   -- Keep decoded single mode program data records for constructing multi mode programs
   -- from MULTI DUMP messages. The parts of the multi mode program appear before each 
   -- MULTI DUMP message, or else the MULTI DUMP message is ignored.
   empty = ""
   parts = {}
   for i = 1, 4112 do -- single mode program index from decode_single_dump()
      parts[i] = empty
   end

   header = midi.hex_to_octets( "F0 00 20 33 01" )
   records = {}
   clear_program()
   for i = 1, #msgs do
      msg = msgs[i]
      
      if type( msg ) == "string" and #msg >= 8 and
         string.sub( msg, 1, 5 ) == header and 
         string.byte( msg, -1 ) == 0xF7 then
         -- Valid Virus TI SysEx data message:
         ident = string.byte( msg, 7 )
         
         if ident == 0x10 then
            -- SINGLE DUMP message:
            record, index = decode_single_dump( msg )
            if type( record ) == "string" and type( index ) == "number" then
               slot = index_to_single_slot( index )
               if type( slot ) == "number" then
                  -- 'index' references a single mode program slot:
                  if slot ~= program.slot or type( program.single ) == "string" then
                     -- New record is for a different program than the current program. Flush
                     -- current program to results:
                     append_program()
                  end
                  program.slot = slot
                  program.single = record
               end
               
               -- Also store single mode program data record in case it is later
               -- referenced by a MULTI DUMP message (except the single mode edit buffer
               -- which cannot be referenced in a MULTI DUMP):
               if index > 0 then
                  parts[index] = record
               end
            end
            
         elseif ident == 0x11 then
            -- MULTI DUMP message:
            record, slot = decode_multi_dump( msg )
            
            if type( record ) == "string" and type( slot ) == "number" then
               -- Collect multi mode program parts from single mode data records:
               if slot ~= program.slot or type( program.multi ) == "string" then
                  -- New record is for a different program than the current program. Flush
                  -- current program to results:
                  append_program()
               end
               
               program.slot = slot
               program.multi = record
               
               part_list = make_part_list( record, slot )
               if type( part_list ) == "table" then
                  for i = 1, 16 do
                     index = part_list[i]
                     record = parts[index]
                     if #record > 0 then
                        -- Assign part number in data record:
                        program.parts[i] = string.char( 0x01 ) .. string.char( i - 1 ) ..
                           string.sub( record, 3 )
                     else
                        break
                     end
                  end
               end
            end 
            
         end -- elseif ident == 0x11 ...
      end -- if type( msg ) == "string" and ...
   end -- for i = 1, #msgs do
   append_program() -- flush last program to results if any
   
   return records
end -- model.decode()


function model.load_program_command( config, records, slot, name ) -- -> msgs
   local header, msgs

   header = make_header( config )
   if type( header ) ~= "string" then
      return nil -- invalid configuration
   end
   if type( records ) ~= "table" or #records == 0 then
      print( "VirusTI load_program_command(): invalid records argument")
      return nil -- invalid argument
   end

   msgs = encode_single_mode_program( records, header, slot, name )
   if #msgs > 0 then      
      msgs = merge_tables( msgs, encode_multi_mode_program( records, header, slot ) )
   else
      msgs = encode_multi_mode_program( records, header, slot, name )
   end      
   
   if #msgs > 0 then
      return msgs
   end
end -- model.load_program_command()


return model


-- EOF virus-ti.lua
