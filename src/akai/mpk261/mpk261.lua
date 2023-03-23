-- mpk261.lua
--
-- MIDI Model Description (MMD) for the Akai MPK261 MIDI Controller.
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


-- MIDI MODEL DESCRIPTION (MMD) for the Akai MPK261
-- ================================================
-- 
-- MIDI ports:
-- -----------
--
-- The device enumerates 4 MIDI input/output port pairs via the USB interface:
--  - port #1 ("MPK261" on Windows, "MPK261 Port A" on Mac): controller channel A;
--  - port #2 ("MIDIIN/OUT2 (MPK261)" on Windows, "MPK261 Port B" on Mac): controller
--    channel B;
--  - port #3 ("MIDIIN/OUT3 (MPK261)" on Windows, "MPK261 MIDI" on Mac): USB-MIDI 
--    interface to the 5-pin DIN connectors at the back of the controller;
--  - port #4 ("MIDIIN/OUT4 (MPK261)" on Windows, "MPK261 Remote" on Mac):
--    device control interface (SysEx messages).
--
-- The MPK261 responds to SysEx commands on port #4 only. The device responds to
-- IDENTITY REQUEST messages on every port, but does not transmit or receive SysEx 
-- dumps on the other ports.
--
-- General format of SysEx messages for the Akai MPK261:
-- -----------------------------------------------------
-- 
--       F0 47 00 25 id sm sl dd ... dd F7
--
--  where:
--   - 'id' is one of:
--      10: preset program data dump
--      20: query globals (transmit contents of globals memory at given address)
--      21: query program (transmit contents of program memory at given address)
--      30: globals data (write given <data> to globals memory at given address)
--      31: program data (write given <data> to program memory at given address)
--  - 'dd' is the message payload <data>
--  - 'sm' and 'sl' are the most and least significant 7-bits of the message
--    payload length, respectively.
--
--  Example: Write active preset number to global memory. This command causes 
--    the device to load preset #'nn' from flash to the edit buffer:
-- 
--       F0 47 00 25 30 00 04 01 00 01 nn F7
-- 
--    (device responds with F0 47 00 25 38 00 04 01 00 01 00 F7)
--
-- Identification:
-- ---------------
--
-- The MPK261 responds to the standard device inquiry IDENTITY REQUEST message 
-- as follows:
--
--              F0 7E 00 06 02 47 25 00 19 00 xx ... xx F7
--                    --       -- ----- ----- ---------
--                     |        |   |     |       |
--    device ID  ------+        |   |     |       |
--                              |   |     |       |
--      Manufacturer ID (Akai) -+   |     |       |
--                                  |     |       |
--     Family ID (MPK II series) ---+     |       |
--                                        |       |
--       Member ID (61-key variant)  -----+       |
--                                                |
--                     Software version  ---------+
--
-- where:
--  - device ID: unused (always encoded as 0x00)
--  - manufacturer code = 0x47 (Akai)
--  - family code = 0x0025 (MPK II series)
--  - member code = 0x0019 (61-key version)
--
-- Note Akai does not document the encoding of the software version information
-- "xx ... xx".
--
-- Program Data:
-- -------------
--
-- An MPK261 program / preset consists of 1544 7-bit words, encoded in
-- 1544 bytes with MSB always == 0. Any one of the 30 presets stored in
-- persistent memory can be transferred to or from the device all at once 
-- in a single 1555-byte SysEx message of the form:
--
--                      F0 47 00 25 10 0C 0B 01 4D 49 <pgm data> F7
--                                  -- ----- -- ----- ----------
--                                   |   |    |   |        |
--        Msg id (program dump)  ----+   |    |   |        |
--                                       |    |   |        |
--    Payload size (0x060B = 1547) ------+    |   |        |
--                                            |   |        |
--         Program number (range [0x01;0x1e) -+   |        |
--                                                |        |
--                                       ???   ---+        |
--                                                         |
--                        Program data (1544 bytes) -------+
--
-- A preset data dump from the device may only be triggered manually from the
-- device.
--
-- The active program can be queried or set in temporary program memory using
-- the 'query program data' (msg ID 0x21) / 'set program data' (msg ID 0x31)
-- messages. At most 127 words may be transmitted in a single 'set Program
-- data' message. Thus transferring the entire active program requires 13 
-- 'query'/'set' message pairs as follows (12 x 127 + 20 = 1544):
--
--                           F0 47 00 25 21 00 03 04 00 00 F7
--                                       -- ----- -- -----
--                                        |   |    |   |
--        Msg ID (query program data)  ---+   |    |   |
--                                            |    |   |
--                         Msg size (3 bytes)-+    |   |
--                                                 |   |
--         Number program data words to query  ----+   |
--                                                     |
--   Program data address to query (range [0;1543])  --+
--
-- Device responds with a 'set program data' message:
--
--                        F0 47 00 25 31 00 07 04 00 00 4D 49 44 49 F7
--                                    -- ----- -- ----- -----------
--                                     |   |    |   |        |
--         Msg ID (Program data)  -----+   |    |   |        |
--                                         |    |   |        |
--                Msg size (7 bytes)  -----+    |   |        |
--                                              |   |        |
--       Number program data words in message  -+   |        |
--                                                  |        |
--          Program data address to write  ---------+        |
--                                                           |
--                                     Program data words ---+
--
-- The format of the active program data differs from that of a preset and Akai
-- has not documented it. Support for this model is therefore currently limited 
-- to transferring the active program from/to the device's edit buffer.
--

-- HELPER SUBROUTINES:

-- Convert an unsigned integer value into a string of 7-bit nibbles.
--
-- Parameters:
--  - n: value to convert;
--  - len: number of nibbles to return.
--
-- Returns:
--  - octets: an octet string of the requested length, each octet containing the
--    next nibble of the input value, most-significant bits first. 
--
-- Notes:
--  - if the input value is larger than can be expressed in the given number
--    of nibbles, the excess most-significant bits are discarded.
function integer_to_nibbles( n, len )
   local octets
   
   octets = ""
   while #octets < len do
      octets = string.char( n & 0x7F ) .. octets
      n = (n >> 7)
   end
   return octets
end -- integer_to_nibbles()


-- Determine the numerical value that is encoded in the given octet string,
-- where each successive octet is presumed to contain the next 7 bits of 
-- the value. The first octet in the string contains the most-significant bits 
-- of the value.
function nibbles_to_integer( octets )
   local n
   
   n = 0
   for i = 1, #octets do
      n = (n << 7) + (string.byte(octets, i) & 0x7F)
   end
   return n
end -- nibbles_to_integer()


-- Make SysEx message header for the MPK261:
function get_header()
   return midi.hex_to_octets( "F0 47 00 25" )
end -- get_header()


-- Make a message payload (prepends the message length msb/lsb):
function make_payload( data )
   return integer_to_nibbles( #data, 2 ) .. data
end -- make_payload()


-- Construct the header for a data block transfer (prepend the message length msb/lsb
-- address msb/lsb):
function make_data_payload( addr, data )
   return make_payload( string.char( #data ) .. integer_to_nibbles( addr, 2 ) .. data )
end -- make_data_payload()

      
-- Remove trailing whitespaces from given string:
function trim( s )
   local i

   i = #s
   while i >= 1 and string.sub( s, i, i ) == " " do
      i = i - 1
   end
   return string.sub( s, 1, i )
end -- trim()


-- Extract the name of a program from the given program data. The data must be
-- based at address 0 in the edit buffer of the device.
--
-- Parameters:
--  - data: octet string, program data;
--
-- Returns:
--  - name: program name if available from the record, nil otherwise.
function get_program_name( data )
   local name
   
   if #data >= 8 then
      return trim( string.sub( data, 1, 8 ) )
   end
end -- get_program_name()


-- Replace the name of a program in the given program data. The data must be
-- based at address 0 in the edit buffer of the device.
--
-- Parameters:
--  - data: octet string, program data.
--  - name: new name of the program.
--
-- Returns:
--  - data: the updated program data.
function set_program_name( data, name ) -- -> data
   if #data >= 8 then
      name = string.sub( name .. string.rep( " ", 8 ), 1, 8 )
      data = name .. string.sub( data, 9 )
   end
   return data
end -- set_program_name()


-- Construct a program data dump command. A complete program occupies
-- 1544 bytes in the device edit buffer and must be transmitted in chunks
-- not exceeding 127 bytes. Multiple command messages are needed to retrieve 
-- every chunk.
--
-- Parameters:
--  - header: SysEx header for the messages.
--
-- Returns:
--  - msgs: a list of octet strings with the encoded messages.
function encode_program_data_dump_command( header ) -- -> msgs
   local msgs, count, addr, remaining, count
   
   header = header .. string.char( 0x21 ) -- same message type for all
   msgs = {}
   addr = 0 -- first byte of program data
   remaining = 1544 -- size of program data
   while remaining > 0 do
      if remaining > 127 then
         count = 127
      else
         count = remaining
      end
      remaining = remaining - count

      msgs[#msgs + 1] = header .. midi.hex_to_octets( { "00 03", count } ) ..
         integer_to_nibbles( addr, 2 ) .. string.char( 0xF7 )

      addr = addr + count
   end
   return msgs
end -- encode_program_data_dump_command()


-- Construct a global data dump command. The global data consists in 
-- 377 bytes that must be transmitted in chunks not exceeding 127 bytes.
-- Multiple command messages are needed to retrieve every chunk.
--
-- Parameters:
--  - header: SysEx header for the messages.
--
-- Returns:
--  - msgs: a list of octet strings with the encoded message.
function encode_global_data_dump_command( header ) -- -> msgs
   local addr, remaining, count

   header = header .. string.char( 0x20 ) -- same message type for all
   msgs = {}
   addr = 0 -- first byte of globals data
   remaining = 377 -- size of globals data
   while remaining > 0 do
      if remaining > 127 then
         count = 127
      else
         count = remaining
      end
      remaining = remaining - count

      msgs[#msgs + 1] = header .. midi.hex_to_octets( { "00 03", count } ) ..
         integer_to_nibbles( addr, 2 ) .. string.char( 0xF7 )

      addr = addr + count
   end
   return msgs
end -- encode_global_data_dump_command()


-- Decode a program data dump message.
--
-- Parameters:
--  - msg: message to decode
--
-- Returns nothing if the data block in the message is not fully comprised within
-- the active program data address space. Otherwise:
--  - addr: integer, address of the first program data byte in the message
--  - record: octet string of the form "<addr><data>" where:
--     . <addr> is the target address of the program data block (0-1543) expressed
--       as two 7-bit nibbles, most significant bits first;
--     . <data> is the program data bytes
--  - name: name of the program if available from the message, nil otherwise.
function decode_program_data_dump( msg ) -- -> addr, record, name
   local len, count, addr, record, name
   
   if #msg >= 12 then
      len = nibbles_to_integer( string.sub( msg, 6, 7 ) )
      count = string.byte( msg, 8 )
      addr = nibbles_to_integer( string.sub( msg, 9, 10 ) )
      data = string.sub( msg, 11, -2 )
      if len == (#msg - 8) and #data == count and (addr + count) <= 1544 then
         record = string.sub( msg, 9, -2 )
         if addr == 0 then
            name = get_program_name( data )
         end
         return addr, record, name
      end
   end
end -- decode_program_data_dump()


-- Decode a preset dump message.
--
-- Parameters:
--  - msg: message to decode
--
-- Returns nothing if the message is invalid. Otherwise:
--  - data: octet string of the form "<addr><prog>" where:
--     . <addr> is the value 'slot * 1544' encoded as two 7-bit nibbles, most 
--       significant bits first, and where 'slot' is the preset number, 1 to 30 
--       inclusive (1544 is chosen as the multiplier because it is the size of the
--       active program data address space, thus differentiating from an active
--       program data record whose address is always in range 0-1543 inclusive);
--     . <prog> is the preset data bytes;
--  - name: the name of the preset if comprised within the given message, nil otherwise.
--
-- NOTE: this function is currently disabled because the data record format from a
-- preset dump differs from the representation of the program in the edit buffer, 
-- and thus preset data records are not interchangeable with edit buffer data dumps.
-- 
-- function decode_preset_data_dump( msg ) -- -> data, slot, name
   -- local len, slot, addr, data, name
   
   -- if #msg >= 9 then
      -- len = nibbles_to_integer( string.sub( msg, 6, 7 ) )
      -- slot = string.byte( msg, 8 ) -- range 1-30 incl.
      -- if len == (#msg - 8) and slot >= 1 and slot <= 30 then    
         -- addr = slot * 1544
         -- data = integer_to_nibbles( addr, 2 ) .. string.sub( msg, 9, -2 )
         -- if #data >= 8 then
            -- name = trim( string.sub( data, 1, 8 ) )
         -- end   
         -- return data, slot, name
      -- end
   -- end   
-- end -- decode_preset_data_dump()


-- Decode a global data dump message.
--
-- Parameters:
--  - msg: message to decode
--
-- Returns nothing if the data block in the message is not fully comprised within
-- the global data address space. Otherwise:
--  - addr: integer, address of the first global data byte in the message
--  - record: octet string of the form "<addr><data>" where:
--     . <addr> is the target address of the global data (0-376) expressed
--       as two 7-bit nibbles, most significant bits first;
--     . <data> is the global data.
function decode_global_data_dump( msg ) -- -> addr, data
   local len, count, addr, data
   
   if #msg >= 12 then
      len = nibbles_to_integer( string.sub( msg, 6, 7 ) )
      count = string.byte( msg, 8 )
      addr = nibbles_to_integer( string.sub( msg, 9, 10 ) )
      if len == (#msg - 8) and count == (#msg - 11) and addr <= (377 - count) then
         data = string.sub( msg, 9, -2 )
         return addr, data
      end
   end
end -- model.decode_program()


-- Encode a list of PROGRAM DATA DUMP messages to restore a program from
-- the given data records. If a new name is given for the program, the name
-- will be used to construct the messages, otherwise the exising name in the 
-- given records (if any) will be used.
--
-- If a new name is given for the program, the name will be used to construct
-- the messages, otherwise the exising name in the given program data will
-- be used.
--
-- Parameters:
--  - records: list of octet string of the form "<addr><data>" where
--     . <addr> is the target address of the program data (0-1543) expressed
--       as two 7-bit nibbles, most significant bits first;
--     . <data> is program data, not exceeding 127 bytes in length.
--  - header: SysEx header for the messages.
--  - name: optional program name.
--
-- Returns:
--  - msgs: list of octet strings, encoded messages.
function encode_program_data_dump( records, header, name )
   local msgs, addr
   
   msgs={}
   header = header .. string.char( 0x31 ) -- same message type for all
   for i = 1, #records do
      record = records[i]
      if type( record ) ~= "string" or #record < 3 then
         print( "MPK261 encode_program_data_dump(): invalid records argument" )
         return nil
      end
      addr = nibbles_to_integer( string.sub( record, 1, 2 ) )
      data = string.sub( record, 3 )
      if #data > 127 or (addr + #data) > 1544 then
         print( "MPK261 encode_program_data_dump(): invalid records argument" )
         return nil
      end
      if addr == 0 and type( name ) == "string" then
         data = set_program_name( data, name )
      end
      msgs[i] = header .. make_data_payload( addr, data ) .. string.char( 0xF7 ) 
   end
   return msgs
end -- encode_program_data_dump()


-- Encode a list of GLOBAL DATA DUMP messages from the given data records.
--
-- Parameters:
--  - records: list of octet strings of the form "<addr><data>" where:
--     . <addr> is the target address of the global data (0-376) expressed
--       as two 7-bit nibbles, most significant bits first;
--     . <data> is the global data, not exceeding 127 bytes in length.
--  - header: SysEx header for the messages.
--
-- Returns:
--  - msgs: list of octet strings, encoded messages.
function encode_global_data_dump( records, header ) -- -> msgs
   local msgs, record, addr, data
   
   msgs={}
   header = header .. string.char( 0x30 ) -- same message type for all
   for i = 1, #records do
      record = records[i]
      if type( record ) ~= "string" or #record < 3 then
         print( "MPK261 load_globals_command(): invalid records argument" )
         return nil
      end
      addr = nibbles_to_integer( string.sub( record, 1, 2 ) )
      data = string.sub( record, 3 )
      if #data > 127 or (addr + #data) > 377 then
         print( "MPK261 load_globals_command(): invalid records argument" )
         return nil
      end

      msgs[i] = header .. make_data_payload( addr, data ) .. string.char( 0xF7 ) 
   end
   return msgs 
end -- encode_global_parameter_dump()


-- MODULE FUNCTIONS:
local model = {}


function model.info()
   return {
      specification = 2,
      name = "Akai MPK261",
      source = "Old Blue Bike Software inc.",
      version = "2.0",
      icon = "*.png", -- look for file with same path as this file with '.png' appended
      manufacturer = "47",
      family = "25",
      member = "19",
      slots = 0,
      timeout = 50,
      notes =
         "PRESETS CAPTURE/RESTORE:\n" ..
         "========================\n" ..
         "\n" ..
         "The MPK261 comprises on board storage for 30 preset programs. However the data\n"..
         "format of the stored programs differs from their representation in the edit\n"..
         "buffer, which precludes capturing a preset via SysEx and restoring it directly\n"..
         "into the edit buffer via SysEx. Thus, at present, this MMD only supports\n"..
         "capture/restore of the edit buffer. The 30 stored preset programs can be\n"..
         "captured using a traditional SysEx librarian, using the MPK261's 'Sysex Send Program'\n"..
         "option from its GLOBAL menu.\n" }
end -- model.info()


function model.globals() --> globals
   return { "Settings" }
end -- model.globals()


function model.dump_program_command( config, slot ) -- -> msgs, header, max_rsps
   local header, msgs

   header = get_header() 
   if slot == nil or slot == 0 then
      msgs = encode_program_data_dump_command( header )
   else
      print( "MPK261 dump_program_command(): invalid slot argument" )
      return nil
   end
   
   if type( msgs ) == "table" then
      return msgs, header, 1
   end
end -- model.dump_program_command()


function model.dump_globals_command( config, globals ) -- -> msgs, header, max_rsps
   local header, msgs

   header = get_header( config )

   if globals == "Settings" then
      msgs = encode_global_data_dump_command( header )
   else
      print( "MPK261 dump_globals_command(): unknown globals \"" .. globals .. '\"' )
      return nil -- invalid configuration
   end

   if type( msgs ) == "table" then
      return msgs, header, 1
   end
end -- model.dump_program_command()


function model.decode( msgs ) -- -> records
   local header, records, ident, idx, msg, last_ident, record, name, slot, last_idx

   if type( msgs ) ~= "table" or #msgs == 0 then
      print( "MinilogueXD decode(): invalid msgs argument")
      return nil -- invalid argument
   end

   header = get_header()
   records = {}
   for i = 1, #msgs do
      msg = msgs[i]

      if type( msg ) == "string" and #msg >= 8 and 
         string.sub( msg, 1, 4 ) == header and string.byte( msg, -1 ) == 0xF7 then
         -- Valid Minilogue XD SysEx message:
         last_ident = ident
         ident = string.byte( msg, 5 )
         
         if ident == 0x31 then
            -- program program data dump message:
            addr, record, name = decode_program_data_dump( msg )            
            if type( record ) == "string" then
               if last_ident ~= 0x31 or addr <= last_addr then
                  records[#records + 1] = "program:0"
               end
               if type( name ) == "string" then
                  records[#records + 1] = "name:" .. name
               end
               records[#records + 1] = "data:" .. record
               last_addr = addr
            end
            
         elseif ident == 0x30 then
            -- global data dump message:
            addr, data = decode_global_data_dump( msg )
            if type( data ) == "string" then
               if last_ident ~= 0x30 or addr <= last_addr then
                  records[#records + 1] = "globals:Settings"
               end            
               records[#records + 1] = "data:" .. data
               last_addr = addr
            end
            
         -- NOTE: handling of preset dump messages is currently disabled because the data 
         -- record format from a preset dump differs from the representation of the program 
         -- in the edit buffer, and thus preset data records are not interchangeable with 
         -- edit buffer data dumps.
         -- elseif ident == 0x10 then
            -- decode preset dump message:
            -- data, slot, name = decode_preset_dump( msg )
            -- if type( data ) == "string" then
               -- records[#records + 1] = "program:" .. slot
               -- if type( name ) == "string" then
                  -- records[#records + 1] = "name:" .. name
               -- end
               -- records[#records + 1] = "data:" .. data
            -- end            

         end
      end
   end
   
   return records
end -- model.decode()


function model.load_program_command( config, records, slot, name ) -- -> msgs
   local msgs, header, addr, record, rec_len

   if type( records ) ~= "table" or #records == 0 then
      print( "MPK261 load_program_command(): invalid records argument" )
      return nil
   end
   
   header = get_header()
   
   if slot == nil or slot == 0 then
      return encode_program_data_dump( records, header, name )
   else
      print( "MPK261 load_program_command(): unsupported slot #" )
   end 
end -- model.load_program_command


function model.load_globals_command( config, globals, records ) -- -> msgs
   local header, msgs, addr, record

   if type( records ) ~= "table" or #records == 0 then
      print( "MPK261 load_globals_command(): invalid records argument" )
      return nil
   end
   
   header = get_header()
   
   if globals == "Settings" then
      return encode_global_data_dump( records, header )
   else
      print( "MPK261 load_globals_command(): unknown globals \"" .. globals .. '\"' )
   end -- if globals == "Settings"
end -- model.load_program_command


return model


-- EOF mpk261.lua
