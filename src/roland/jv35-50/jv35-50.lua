-- jv35-50.lua
--
-- MIDI MODEL DESCRIPTION (MMD) for Roland JV-35/50 Expandable Synthesizers.
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

-- MIDI MODEL DESCRIPTION (MMD) for the Roland JV-35/50
-- ====================================================
--
-- Identification:
-- ---------------
--
-- The JV-35/50 does not respond to the standard device inquiry IDENTITY REQUEST
-- message. SYSEX messages do however include a unit identifier code which can be 
-- used to differentiate between multiple JV-35/50's connected to the same MIDI
-- output via splitter or daisy-chaining.
--
-- Programming Model:
-- ------------------
--
-- All of the JV-35/50's parameters (including programs and globals) can be 
-- queried or set via MIDI SysEx by use of Roland's REQUEST DATA (RQ1) and SET
-- DATA (DT1) messages. Each parameter is given a unique 21-bit address in the 
-- device's memory. To facilitate transmission over MIDI, all parameter addresses 
-- are expressed as three 7-bit nibbles, with the first word containing the 7 
-- most-significant bits of the address.
-- 
-- Program Data:
-- -------------
--
-- The closest thing to a program in the JV-35/50 is what Roland refers to as 
-- a "performance". For each of 16 parts, the performance parameters select the 
-- tone or drum kit, the receive and transmit MIDI channel numbers, reverb and 
-- chorus effect switch states, and so on . The performance also encodes
-- parameters of the MIDI controller function of the device, such as the keybed 
-- mode (e.g. "oct1", "oct2", "dual" or "split").
--
-- For instruments that are equiped with the optional VE-JV1 expansion board,
-- the expansion performance parameters are stored in a separate address range
-- that more or less mirrors the address range for the standard parameters.
-- 
-- Performance parameters are stored at the following address ranges 
-- (all addresses and sizes expressed in 3x7-bit nibble hexadecimal notation):
--  - Active performance:
--    . standard parameters: 28 00 00 - 28 04 23 (size 00 04 24)
--    . VE-JV1 parameters: 58 00 00 - 58 05 63 (size 00 05 64)
--  - Stored performance slot #1:
--    . standard parameters: 20 00 00 - 20 04 23 (size 00 04 24)
--    . VE-JV1 parameters: 50 00 00 - 50 05 63 (size 00 05 64)
--  - Stored performance slots #2-8:
--    . standard parameters: 20 04 64 onwards, size 00 04 24 per slot;
--    . VE-JV1 parameters: 50 05 64 onwards, size 00 05 64 per slot.
--
-- For any number of the 16 parts, a performance may reference user-defined 
-- tones or drum kits. The performance does not include the parameters of 
-- the user-defined tone/drum kit: those are kept separate from the performances
-- and treated as globals by this MMD.
-- 
-- User-Defined Tones:
-- -------------------
--
-- The parameters of user-defined tones are stored in the following address 
-- ranges:
--  - standard tones: 30 00 00 - 30 27 7F (size 00 28 00)
--  - VE-JV1 tones: 60 00 00 - 60 27 7F (size 00 28 00)
--
-- User-Defined Drum Kits:
-- -----------------------
--
-- The parameters of user-defined drum kits are stored in the following 
-- address ranges:
--  - standard kits: 38 00 00 - 38 47 7F (size 00 48 00)
--  - VE-JV1 kits: 68 00 00 - 68 3F 7F (size 00 40 00)
--
-- Parameter Data Records:
-- -----------------------
--
-- A Parameter Data Record is a group of contiguous parameter values extracted 
-- from a JV-35/50 DT1 message. All PDRs are octet strings of the form 
-- "<exp><ofst><data>" where:
--  . <exp> (first byte) is coded as 0x01 to indicate that the parameter 
--    values in the record apply to the VE-JV1 expansion board, or 0x00
--    otherwise;
--  . <ofst> (bytes 2-4 incl.) is a 3 x 7-bit integer_to_nibbles encoding the offset
--    of the data from the start of the parameter bank (LSB first);
--  . <data> (bytes 5 and following) are the parameter values.
--
-- Three types of PDRs are defined in accordance with their content:
--  - Performance PDR: contains the parameter values from a performance. Given
--    a performance slot number and the unit number of a target device, the 
--    data in the record can be restored to the active or any stored performance
--    slot in the device;
--  - User Tones PDR: contains user-defined tone parameters. Given the unit number
--    of a target device, the data in the record can be restored to the device.
--  - User Drum Kit PDR: contains user-defined drum kit parameters. Given the unit
--    number of a target device, the data in the record can be restored to the 
--    device.
--

-- HELPER SUBROUTINES:

-- Convert an unsigned integer value into a string of 7-bit nibbles:
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


-- Like nibbles_to_integer(), but takes a hexadecimal string instead:
function hex_to_integer( hex )
   return nibbles_to_integer( midi.hex_to_octets( hex ) )
end -- hex_to_integer()


-- Construct SysEx message header for unit number in given configuration:
function get_header( config )
   local unit

   if type( config ) ~= "table" then 
      print( "JV-35/50 get_header(): unit identifier missing from supplied configuration" )
      return nil -- invalid argument
   end
   unit = config.unit
   if type( unit ) ~= "number" or unit < 0 or unit > 31 then
      print( "JV-35/50 get_header(): unit identifier out of valid range" )
      return nil -- out of range
   end
   return midi.hex_to_octets( { "F0 41", unit, "4D" } )
end -- get_header()


-- Extract the expansion flag from the given record's header:
function get_record_expansion( record ) -- -> expansion
   return string.byte( record, 1 )
end -- get_record_expansion()


-- Extract the offset from the given record's header:
function get_record_offset( record ) -- -> ofst
   return nibbles_to_integer( string.sub( record, 2, 4 ) )
end -- get_record_offset()


-- Extract record ordinal from given record's header:
function get_record_ord( record ) -- -> ord
   return nibbles_to_integer( string.sub( record, 1, 4 ) )
end -- get_record_ord()


-- Extract the given record's payload:
function get_record_payload( record ) -- -> data
   return string.sub( record, 5 )
end -- get_record_payload()


-- Unpack the given data record, return its header components and payload:
function unpack_record( record ) -- -> expansion, ofst, data
   local expansion, ofst, data
   
   expansion = get_record_expansion( record )
   ofst = get_record_offset( record )
   data = get_record_payload( record )
   
   return expansion, ofst, data
end -- unpack_record()


-- Construct a neme for the given program slot. The JV-35/50 does not store names 
-- for its performances, so just return the name of the performance slot.
--
-- Parameters:
--  - slot: slot number of the performance (0: active performance, 1-8: stored
--    performance).
--
-- Returns nothing if the given slot number is invalid. Otherwise:
--  - name: performance name.
function get_program_name( slot )
   if type( slot ) == "number" then
      if slot == 0 then
         return "Active performance"
      elseif slot >= 1 and slot <= 8 then
         return "Performance #" .. slot
      end
   end
end -- get_program_name()


-- Calculate Roland-style MIDI checksum onto SYSEX payload (encoded as octet string):
function checksum( octets ) -- -> sum
   local sum
   
   sum = 0
   for i = 1, #octets do
      sum = sum + string.byte( octets, i )
   end
   return string.char( (0x80 - (sum & 0x7F)) & 0x7F )
end -- checksum()
   

-- Construct Roland RQ1 (data request) message.
--
-- Parameters:
--  - header: octet string, SysEx message header;
--  - addr: integer, address of requested data parameter (integer);
--  - size: integer, size requested data.
--
-- Returns:
--  - msg: octet string, RQ1 message.
function encode_rq1( header, addr, size )
   local payload
   
   payload =  integer_to_nibbles( addr, 3 ) .. integer_to_nibbles( size, 3 )
   return header .. string.char( 0x11 ) .. payload .. checksum( payload ) ..
      string.char( 0xF7 )
end -- encode_rq1()


-- Construct the list of SysEx messages to command the JV-35/50 to dump its user 
-- tones parameters.
--
-- Parameters:
--  - header: message header including the unit number of the target device;
--
-- Returns:
--  - msgs: list of octet strings, RQ1 messages.
function encode_dump_user_tones_command( header )
   -- User tones stored in a single contiguous block at address 30 00 00, size 00 28 00;
   -- VE-JV1 expansion board user tones similarly in a separate block at address 60 00 00
   -- size 00 28 00:
   return { 
      encode_rq1( header, hex_to_integer( "30 00 00" ), hex_to_integer( "00 28 00" ) ),
      encode_rq1( header, hex_to_integer( "60 00 00" ), hex_to_integer( "00 28 00" ) ) }
end -- encode_dump_user_tones_command()


-- Construct the list of SysEx messages to command the JV-35/50 to dump its user 
-- drums parameters.
--
-- Parameters:
--  - header: message header including the unit number of the target device;
--
-- Returns:
--  - msgs: list of octet strings, RQ1 messages.
function encode_dump_user_drums_command( header ) -- -> msgs
   -- All 9 user drum maps stored in a single contiguous block at address 38 00 00, size 
   -- 00 48 00; VE-JV1 expansion board user drum maps similarly in a separate block at
   -- address 68 00 00, size 00 40 00:
   return {
      encode_rq1( header, hex_to_integer( "38 00 00" ), hex_to_integer( "00 48 00" ) ),
      encode_rq1( header, hex_to_integer( "68 00 00" ), hex_to_integer( "00 40 00" ) ) }
end -- encode_dump_user_drums_command()


-- Extract the address and payload bytes from a Roland DT1 message.
--
-- Parameters:
--  - msg: message.
--
-- Returns:
--  - addr: integer, address of the first parameter value in the message;
--  - data: octet string, sequence of parameter values from the DT1 message.
function decode_dt1( msg ) -- -> addr, data
   local addr, data

   if type( msg ) ~= "string" or #msg < 11 or
      string.byte( msg, 1 ) ~= 0xF0 or string.byte( msg, 2 ) ~= 0x41 or
      string.byte( msg, 4 ) ~= 0x4D or string.byte( msg, 5 ) ~= 0x12 or
      checksum( string.sub( msg, 6, -3 ) ) ~= string.sub( msg, -2, -2 ) or
      string.byte( msg, -1 ) ~= 0xF7 then
      return nil -- invalid / corrupted DT1 message
   end

   -- The data record starts after the address field, and ends before the 
   -- message checksum. Don't include either:
   addr = nibbles_to_integer( string.sub( msg, 6, 8 ) )
   data = string.sub( msg, 9, -3 )
   return addr, data
end -- decode_dt1


-- Decode a DT1 message payload containing the parameters of a performance.
--
-- Parameters:
--  - addr: integer, address of the first parameter value in the given the data;
--  - data: octet string, sequence of parameter values. 
--
-- Returns nothing if the given parameter values are not fully comprised within 
-- the address range of a performance address block, otherwise: 
--  - slot: the performance number, 1-8 for a stored performance, 0 for
--    the active performance;
--  - loc: locator of the returned record;
--  - record: performance PDR.
function decode_performance_dump( addr, data ) -- -> slot, ofst, record  
   local top, slot_size, exp_slot_size, base_addr
   local expansion, slot, ofst, ord, record

   slot_size = hex_to_integer( "00 04 24" )
   exp_slot_size = hex_to_integer( "00 05 64" )
   
   top = addr + #data

   base_addr = hex_to_integer( "28 00 00" ) -- active performance
   if addr >= base_addr and top <= (base_addr + slot_size) then
      slot = 0
      ofst = addr - base_addr
      expansion = false
   else
      base_addr = hex_to_integer( "58 00 00" ) -- active VE-JV1 performance
      if addr >= base_addr and top <= (base_addr + exp_slot_size) then
         slot = 0
         ofst = addr - base_addr
         expansion = true
      else
         base_addr = hex_to_integer( "20 00 00" ) -- stored performances
         ofst = addr - base_addr
         slot = (ofst // slot_size)
         base_addr = base_addr + slot * slot_size
         if slot >= 0 and slot <= 7 and 
            addr >= base_addr and top <= (base_addr + slot_size) then
            slot = slot + 1            
            ofst = ofst % slot_size
            expansion = false
         else
            base_addr = hex_to_integer( "50 00 00" ) -- stored VE-JV1 performances
            ofst = addr - base_addr
            slot = (ofst // exp_slot_size)
            base_addr = base_addr + slot * exp_slot_size
            if slot >= 0 and slot <= 7 and 
               addr >= base_addr and top <= (base_addr + exp_slot_size) then
               slot = slot + 1
               ofst = ofst % exp_slot_size
               expansion = true
            end
         end
      end
   end
   
   if type( expansion ) == "boolean" then
      if expansion then
         expansion = string.char( 0x01 )
      else
         expansion = string.char( 0x00 )
      end
      ofst = integer_to_nibbles( ofst, 3 )
      record = expansion .. ofst .. data
      ord = get_record_ord( record ) + #data
      return slot, ord, record
   end
end -- decode_performance_dump()


-- Decode a DT1 message payload.
--
-- Parameters:
--  - addr: integer, address of the first parameter value in the given the data;
--  - data: octet string, sequence of parameter values;
--  - base_addr: integer, base address of the target parameter bank;
--  - top_addr: integer, top address of the target parameter bank;
--  - exp_base_addr: integer, base address of the target parameter bank for the VE-JV1
--    expansion board;
--  - exp_top_addr: integer, top address of the target parameter bank for the VE-JV1
--    expansion board.
--
-- Returns nothing if the given parameter values are not fully comprised within 
-- the address range of the target parameter bank, otherwise: 
--  - ord: ordinal of data record;
--  - record: PDR extracted from the message.
function decode_parameter_dump( addr, data, base_addr, top_addr, exp_base_addr, exp_top_addr )
   local top, ord, expansion, record

   top = addr + #data

   if addr >= base_addr and top <= top_addr then
      ofst = addr - base_addr
      expansion = false
   elseif addr >= exp_base_addr and top <= exp_top_addr then
      ofst = addr - exp_base_addr
      expansion = true
   end
   
   if type( expansion ) == "boolean" then
      if expansion then
         expansion = string.char( 0x01 )
      else
         expansion = string.char( 0x00 )
      end
      ofst = integer_to_nibbles( ofst, 3 )
      record = expansion .. ofst .. data
      ord = get_record_ord( record ) + #data
      return ord, record
   end
end -- decode_parameter_dump()


-- Decode a DT1 message payload containing the parameters of user-defined tones.
--
-- Parameters:
--  - addr: integer, address of the first parameter value in the given the data;
--  - data: octet string, sequence of parameter values. 
--
-- Returns nothing if the given parameter values are not fully comprised within 
-- the address range of user tones parameters, otherwise:
--  - ord: ordinal of the returned data record;
--  - record: User Tones PDR extracted from the message.
function decode_user_tones_dump( addr, data ) -- -> ofst, record
   local base_addr, top_addr, exp_base_addr, exp_top_addr

   base_addr = hex_to_integer( "30 00 00" )
   top_addr = base_addr + hex_to_integer( "00 28 00" )
   exp_base_addr = hex_to_integer( "60 00 00" )
   exp_top_addr = exp_base_addr + hex_to_integer( "00 28 00" )
   return decode_parameter_dump( addr, data, base_addr, top_addr, exp_base_addr, exp_top_addr )
end -- decode_user_tones_dump()


-- Decode a DT1 message payload containing the parameters of user-defined drums.
--
-- Parameters:
--  - addr: integer, address of the first parameter value in the given the data;
--  - data: octet string, sequence of parameter values. 
--
-- Returns nothing if the given parameter values are not fully comprised within 
-- the address range of user drums parameters, otherwise: 
--  - ord: ordinal of the returned data record;
--  - record: Drum Kit PDR extract from the message.
function decode_user_drums_dump( addr, data ) -- -> record
   local base_addr, top_addr, exp_base_addr, exp_top_addr

   base_addr = hex_to_integer( "38 00 00" )
   top_addr = base_addr + hex_to_integer( "00 48 00" )
   exp_base_addr = hex_to_integer( "68 00 00" )
   exp_top_addr = exp_base_addr + hex_to_integer( "00 40 00" )
   return decode_parameter_dump( addr, data, base_addr, top_addr, exp_base_addr, exp_top_addr )
end -- decode_user_drums_dump()


-- Construct Roland DT1 (data set) message.
--
-- Parameters:
--  - header: octet string, SysEx message header
--  - addr: integer, address to set
--  - data: octet string, sequence of parameter values.
--
-- Returns:
--  - msg: octet string, DT1 message.
function encode_dt1( header, addr, data ) -- -> msg
   local payload
   
   payload =  integer_to_nibbles( addr, 3 ) .. data
   return header .. string.char( 0x12 ) .. payload .. checksum( payload ) .. string.char( 0xF7 )
end -- encode_dt1()


-- Encode the given list of PDRs into a list of DT1 messages intended
-- for the device with the given SysEx header.
--
-- Parameters:
--  - records: a list of PDRs to encode;
--  - header: octer string, SysEx header including the unit number of the target device;
--  - base_addr: integer, address of the first standard parameter in the target 
--    range;
--  - top_addr: integer, one past the address of the last standard parameter in the
--    target range;
--  - exp_base_addr: integer, address of the first VE-JV1 expansion parameter in the
--    target range;
--  - exp_top_addr: integer, one past the address of the last VE-JV1 expansion parameter
--    in the target range;   
--
-- Returns nothing if any of the PDRs is not fully comprised within the given standard
-- or expansion parameter address range. Otherwise:
--  - msgs: list of octet strings, encoded DT1 messages;
--  - exp_recs: 'true' if any of the PDRs in the given list applies to the VE-JV1
--    exp_recs, 'false' otherwise.
-- 
function encode_records( records, header, base_addr, top_addr, exp_base_addr, exp_top_addr )
   local msgs, expansion, ofst, data, addr, top, exp_recs

   msgs = {}
   for i = 1, #records do
      record = records[i]      
      if type( record ) ~= "string" or #record < 5 then
         print( "JV-35/50 encode_record(): invalid record" )
         return nil
      end
      
      expansion, ofst, data = unpack_record( record )
      if expansion == 0x00 then
         addr = base_addr + ofst
         if (addr + #data) > top_addr then
            print( "JV-35/50 encode_record(): record #" .. i .. " offset " .. 
               midi.octets_to_hex( string.sub( record, 2, 4 ) ) .. " length " .. #data ..
               " for built-in parameter bank is outside valid range ['" ..
               midi.octets_to_hex( integer_to_nibbles( base_addr, 3 ) ) .. "'-'" ..
               midi.octets_to_hex( integer_to_nibbles( top_addr, 3 ) ) .. "'[" )
            return nil
         end
      elseif expansion == 0x01 then
         addr = exp_base_addr + ofst
         if (addr + #data) > exp_top_addr then
            print( "JV-35/50 encode_record(): record #" .. i .. " offset " .. 
               midi.octets_to_hex( string.sub( record, 2, 4 ) ) .. " length " .. #data ..
               " for VE-JV1 parameter bank is outside valid range ['" ..
               midi.octets_to_hex( integer_to_nibbles( exp_base_addr, 3 ) ) .. "'-'" ..
               midi.octets_to_hex( integer_to_nibbles( exp_top_addr, 3 ) ) .. "'[" )
            return nil
         end
         exp_recs = true
      else
         print( "JV-35/50 encode_record(): record #" .. i .. 
            " has invalid expansion bank designator" )
         return nil
      end
      
      msgs[i] = encode_dt1( header, addr, data )
   end
   return msgs, exp_recs
end -- encode_record()


-- Encode a sequence of DT1 messages from a list of User Tones PDRs.
--
-- Parameters:
--  - records: a list of User Tones PDRs.
--
-- Returns nothing if any of the PDRs is outside the user tone parameter address 
-- range. Otherwise:
--  - msgs: list of octet strings, encoded DT1 messages.
function encode_user_tones_dump( records, header )
   local base_addr, top_addr, exp_base_addr, exp_top_addr

   base_addr = hex_to_integer( "30 00 00" )
   top_addr = base_addr + hex_to_integer( "00 28 00" )
   exp_base_addr = hex_to_integer( "60 00 00" )
   exp_top_addr = exp_base_addr + hex_to_integer( "00 28 00" )
   return encode_records( records, header, base_addr, top_addr, exp_base_addr, exp_top_addr )
end -- encode_user_tones_dump()


-- Encode a sequence of DT1 messages from a list of User Drum Kit PDRs.
--
-- Parameters:
--  - records: a list of User Drum Kit PDRs.
--
-- Returns nothing if any of the PDRs is outside the user drum kit parameter address 
-- range. Otherwise:
--  - msgs: list of octet strings, encoded DT1 messages.
function encode_user_drums_dump( records, header )
   local base_addr, top_addr, exp_base_addr, exp_top_addr

   base_addr = hex_to_integer( "38 00 00" )
   top_addr = base_addr + hex_to_integer( "00 48 00" )
   exp_base_addr = hex_to_integer( "68 00 00" )
   exp_top_addr = exp_base_addr + hex_to_integer( "00 40 00" )
   return encode_records( records, header, base_addr, top_addr, exp_base_addr, exp_top_addr )
end -- encode_user_drums_dump()


-- MODULE FUNCTIONS:
local model = {}


function model.info() -- -> info
   return {
      specification = 2,
      name = "Roland JV-35/50",
      source = "Old Blue Bike Software inc.",
      version = "2.1",
      icon = "*.png", -- look for file with same path as this file with '.png' appended
      manufacturer = "41",
      family = "4D",
      probe = "scan",
      unit_first = 0,
      unit_last = 31,
      unit_factory = 16,
      slots = 8,
      timeout = 500 }
end -- model.info()


function model.globals() -- -> globals
   return {
      "User Tones",
      "User Drums" }
end -- model.globals()


function model.dump_program_command( config, slot ) -- -> msgs, header
   local header, slot_size, exp_slot_size, base_addr, exp_base_addr

   header = get_header( config )
   if header == nil then
      return nil -- invalid configuration
   end
   if slot == nil then
      slot = 0
   elseif type( slot ) ~= "number" or slot < 0 or slot > 8 then
      print( "JV-35/50 dump_program_command(): invalid slot #" )
      return nil
   end

   -- 8 performance slots stored contiguously starting at parameter address 20 00 00, each
   -- 00 04 24 in size; performance edit buffer (active performance) starting at 28 00 00.
   -- If equipped with VE-JV1 expansion, corresponding expansion performance slots starting
   -- at address 50 00 00, each 00 05 64 in size; edit buffer (active) starting at 58 00 00.
   slot_size = hex_to_integer( "00 04 24" )
   exp_slot_size = hex_to_integer( "00 05 64" )
   if slot == 0 then
      base_addr = hex_to_integer( "28 00 00" )
      exp_base_addr = hex_to_integer( "58 00 00" )
   else
      slot = slot - 1
      base_addr = hex_to_integer( "20 00 00" ) + (slot * slot_size)
      exp_base_addr = hex_to_integer( "50 00 00" ) + (slot * exp_slot_size)
   end

   return { 
      encode_rq1( header, base_addr, slot_size ),
      encode_rq1( header, exp_base_addr, exp_slot_size ) }, header
end -- model.dump_program_command()


function model.dump_globals_command( config, globals ) -- -> msgs, header
   local msgs, header

   header = get_header( config )
   if header == nil then
      return nil -- invalid configuration
   end
   if slot == nil then
      slot = 0
   elseif type( slot ) ~= "number" or slot < 0 or slot > 8 then
      print( "JV-35/50 dump_program_command(): invalid slot #" )
      return nil
   end
   
   if globals == "User Tones" then
      msgs = encode_dump_user_tones_command( header )
   elseif globals == "User Drums" then
      msgs = encode_dump_user_drums_command( header )
   else
      print( "JV-35/50 dump_globals_command(): unknown globals \"" .. globals .. '\"' )
      return nil -- invalid configuration
   end

   return msgs, header
end -- model.dump_globals_command()


function model.decode( msgs ) -- -> records
   local items, i, msg, addr, data, slot, ord, record, nrecs, tagged_records

   if type( msgs ) ~= "table" or #msgs == 0 then
      print( "JV-35/50 decode_program(): invalid msgs argument" )
      return nil -- invalid argument
   end
   
   -- The JV-35/50 bulk dumps its data in memory order. However the items that 
   -- we are interested in (performances, tones, drums) are spread across
   -- multiple memory locations. As we decode the messages to extract the data 
   -- records, we have to group the records based on which item they belong to.
   -- We'll use an associative array 'items' for this:
   --  - 'items[<n>]' where 'n' is a program slot number, 0-8 (0: active, 
   --    1-8: stored performances);
   --  - 'items.user_tones' is user tones data (globals);
   --  - 'items.user_drums' is drum tones data (globals);
   -- 
   -- Each items[x] is then an array of records in tagged record format. We 
   -- concatenate the records from every category at the end to return the list
   -- of all decoded items. We do expect the records for a given item to be 
   -- dumped in ascending order of address: if we receive record for an item
   -- whose address is before that of the last record for the same item, we 
   -- start a new item (this should never happen...):
   items = {}
   for slot = 0, 8 do
      items[slot] = {}
   end
   items.user_tones = {}
   items.user_drums = {}
   
   for i = 1, #msgs do
      msg = msgs[i]
      
      addr, data = decode_dt1( msg )
      if type( data ) == "string" then
         -- Valid DT1 message:
         slot, ord, record = decode_performance_dump( addr, data )         
         if type( slot ) == "number" and type( record ) == "string" then    
            -- Message contains performance parameters. 
            nrecs = #items[slot]
            if nrecs == 0 or ord <= items[slot].ord then
               -- Start a new performance PDR block:
               nrecs = nrecs + 1
               items[slot][nrecs] = "program:" .. slot
               nrecs = nrecs + 1
               items[slot][nrecs] = "name:" .. get_program_name( slot )
            end  
            nrecs = nrecs + 1            
            items[slot][nrecs] = "data:" .. record
            items[slot].ord = ord
            
         else
            ord, record = decode_user_tones_dump( addr, data )
            if type( record ) == "string" then
               -- Message contains user tone parameters.
               nrecs = #items.user_tones
               if nrecs == 0 or ord < items.user_tones.ord then
                  -- Start of a new User Tones globals record block:
                  nrecs = nrecs + 1
                  items.user_tones[nrecs] = "globals:User Tones"
               end
               nrecs = nrecs + 1
               items.user_tones[nrecs] = "data:" .. record
               items.user_tones.ord = ord               
            else
               ord, record = decode_user_drums_dump( addr, data )               
               if type( record ) == "string" then
                  -- Message contains user drum parameters.
                  nrecs = #items.user_drums
                  if nrecs == 0 or ord < items.user_drums.ord then
                     -- Start of a new User Drums globals record block:
                     nrecs = nrecs + 1
                     items.user_drums[nrecs] = "globals:User Drums"
                  end
                  nrecs = nrecs + 1
                  items.user_drums[nrecs] = "data:" .. record
                  items.user_drums.ord = ord
               end
            end
         end
      end
   end
   
   tagged_records = {}
   for slot = 0, 8 do
      for i = 0, #items[slot] do
         tagged_records[#tagged_records + 1] = items[slot][i]
      end      
   end
   for i = 0, #items.user_tones do
      tagged_records[#tagged_records + 1] = items.user_tones[i]
   end
   for i = 0, #items.user_drums do
      tagged_records[#tagged_records + 1] = items.user_drums[i]
   end
   
   return tagged_records
end -- model.decode()


function model.load_program_command( config, records, slot ) -- -> msgs
   local header, slot_size, exp_slot_size, base_addr, top_addr, exp_base_addr, exp_top_addr,
      msgs, exp_recs

   header = get_header( config )
   if header == nil then
      return nil -- invalid configuration
   end
   if type( records ) ~= "table" or #records == 0 then
      print( "JV-35/50 load_program_command(): invalid records argument")
      return nil -- invalid argument
   end

   if slot == nil then
      slot = 0
   elseif type( slot ) ~= "number" or slot < 0 or slot > 8 then
      print( "JV-35/50 load_program_command(): invalid slot argument" )
      return nil -- invalid argument
   end
   
   slot_size = hex_to_integer( "00 04 24" )
   exp_slot_size = hex_to_integer( "00 05 64" )
   if slot == 0 then
      base_addr = hex_to_integer( "28 00 00" )
      top_addr = base_addr + slot_size
      exp_base_addr = hex_to_integer( "58 00 00" )
      exp_top_addr = exp_base_addr + exp_slot_size
   else
      slot = slot - 1
      base_addr = hex_to_integer( "20 00 00" ) + slot * slot_size
      top_addr = base_addr + slot_size
      exp_base_addr = hex_to_integer( "50 00 00" ) + slot * exp_slot_size
      exp_top_addr = exp_base_addr + exp_slot_size
   end
   
   msgs, exp_recs = encode_records( records, header, base_addr, top_addr, exp_base_addr,
      exp_top_addr )
   if type( msgs ) == "table" then   
      if exp_recs then
         -- Program contains parameters for the VE-JV1 expansion, which must be 
         -- reset by an extract message to force it to reload the changes:
         msgs[#msgs + 1] = encode_dt1( header, hex_to_integer( "5F 00 00" ), 
            string.char( 0x00 ) )
      end
      return msgs
   end
end -- model.load_program_command()


function model.load_globals_command( config, globals, records ) -- -> msgs
   local header

   header = get_header( config )
   if header == nil then
      return nil -- invalid configuration
   end
   if type( records ) ~= "table" or #records == 0 then
      print( "JV-35/50 load_globals_command(): invalid records argument")
      return nil -- invalid argument
   end

   if globals == "User Tones" then
      return encode_user_tones_dump( records, header )
   elseif globals == "User Drums" then
      return encode_user_drums_dump( records, header )
   else
      print( "JV-35/50 load_globals_command(): unknown globals \"" .. globals .. '\"' )
      return nil -- invalid configuration
   end
end -- model.load_globals_command()


return model


-- EOF jv35-50.lua
