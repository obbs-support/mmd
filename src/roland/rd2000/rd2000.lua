-- rd2000.lua
--
-- MIDI Model Description (MMD) for Roland RD-2000 Digital Stage Pianos.
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


-- MIDI MODEL DESCRIPTION (MMD) for the Roland RD-2000
-- ===================================================
--
-- Identification:
-- ---------------
--
-- The RD-2000 responds to the standard device inquiry IDENTITY REQUEST
-- message as follows:
--
--                   F0 7E 10 06 02 41 75 02 00 01 aa bb cc dd F7
--                         --       -- ----- ----- -----------
--                          |        |   |     |        | 
--              Unit ID  ---+        |   |     |        |
--                                   |   |     |        | 
--         Manufacturer ID (Roland) -+   |     |        | 
--                                       |     |        | 
--                 Family ID (RD-2000)  -+     |        | 
--                                             |        | 
--                   Member ID (RD-2000)  -----+        | 
--                                                      | 
--                              Software version  ------+ 
--                                                    
-- where:
--  - unit ID: serves to uniquely address exactly each of multiple devices of
--    the same model when connected to the same MIDI output via a MIDI splitter
--    or daisy-chaining. This value is set to 0x10 for the RD-2000 and there does
--    not seem to be a user interface to change it, which precludes chaining
--    multiple RD-2000s via 5-pin DIN MIDI;
--  - manufacturer code = 0x41 (Roland);
--  - family code = 0x0275 (RD-2000);
--  - member code = 0x0100 (RD-2000).
--
-- Program Data:
-- -------------
--
-- The RD-2000's active program parameters can be queried or set
-- via MIDI SysEx by use of the REQUEST DATA (RQ1) and SET DATA (DT1)
-- messages. Each parameter is given a unique 4 x 7-bit word address,
-- and groups of parameters located at consecutive addresses can be 
-- queried or set in a single operation. The complete active program 
-- can be retrieved by querying all parameters, and consists of 
-- 28 groups of parameters. Refer to the RD-2000 MIDI implementation chart
-- for details.
--
-- The RD-2000 does not handle (receive or transmit) MIDI messages larger
-- than 256 bytes. Larger data blocks must be broken into smaller messages.


-- HELPER SUBROUTINES:

-- Remove trailing whitespaces from given string:
function trim( s ) -- -> string
   local i
   
   i = #s
   while i >= 1 and string.sub( s, i, i ) == " " do
      i = i - 1
   end
   return string.sub( s, 1, i )
end -- trim()


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


-- Return the common header to be used for all RD-2000 SysEx messages:
function get_header()
   return midi.hex_to_octets( "F0 41 10 00 00 75" )
end


-- Calculate Roland-style MIDI checksum over given octet string. Return the checksum as
-- a 1-octet string.
function checksum( octets )
   local sum

   sum = 0
   for i = 1, #octets do
      sum = sum + string.byte( octets, i )
   end
   return string.char( (0x80 - (sum & 0x7F)) & 0x7F )
end -- checksum()
   

-- Construct Roland RQ1 (data request) message with:
--  - addr: address of requested data parameter as 3 hex string ("aa bb cc")
--  - size: size of requested data as 3 hex string ("dd ee ff")
function rq1( addr, size ) -- -> msg
   local payload

   payload = midi.hex_to_octets( {addr, size} )
   return get_header() .. string.char( 0x11 ) .. payload .. checksum( payload )..
      string.char( 0xF7 )
end -- rq1()


-- Construct Roland DT1 (data set) message with:
--  - addr: address of parameter or first of group of parameters to set;
--  - data: value to write at parameter address.
function dt1( data ) -- -> msg
   return get_header() .. string.char( 0x12 ) .. data .. checksum( data ) .. 
      string.char( 0xF7 )
end


-- Decode a Roland DT1 (data set) message:
--
-- Parameters:
--  - msg: octet string, message to decode.
--
-- Returns nothing if the 'msg' is not an RD-2000 DT1 SysEx message, otherwise:
--  - record: octet string of the form "<addr><data>" where <data> is a sequence
--       of device parameter values and <addr> is the address of the first value
--       in <data>;
--  - addr: decoded parameter address of the data as an integer.
function decode_dt1( msg ) -- -> data, addr
   local data, addr

   if type( msg ) == "string" and #msg >= 13 and
      string.sub( msg, 1, 7 ) == midi.hex_to_octets( "F0 41 10 00 00 75 12" ) and
      checksum( string.sub( msg, 8, -3 ) ) == string.sub( msg, -2, -2 ) and
      string.sub( msg, -1, -1 ) == string.char( 0xF7 ) then
      -- Valid DT1 message:
      data = string.sub( msg, 8, -3 )
      addr = nibbles_to_integer( string.sub( data, 1, 4 ) )
      
      return data, addr
   end
end -- decode_dt1()


-- Extract the name of a program from the given program data record.
--
-- Parameters:
--  - record: octet string of the form "<addr><data>" where <comms> (first byte)
--    is the communications protocol version of the data, and <data> (byte 2
--    onwards) is the program data;
--
-- Returns:
--  - name: name of the program or nil if the communications protocol version
--    of the record is unsupported or the program is unnamed.
function get_program_name( record ) -- -> name
   if #record >= 20 and 
      nibbles_to_integer( string.sub( record, 1, 4 ) ) == 
      hex_to_integer( "10 00 00 00" ) then
      return trim( string.sub( record, 5, 20 ) )
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
-- Returns nothing unless the given record is the first record of active program
-- parameters (which contains the program name), otherwise: 
--  - record: the updated program data record.
function set_program_name( record, name ) -- -> record
   if #record >= 20 and 
      nibbles_to_integer( string.sub( record, 1, 4 ) ) == 
      hex_to_integer( "10 00 00 00" ) then
      name = string.sub( name .. string.rep( " ", 16 ), 1, 16 )
      return  string.sub( record, 1, 4 ) .. name .. string.sub( record, 21 )
   end
end -- set_program_name()


-- Construct a list of DT1 messages from the given list of parameter data records.
-- The first 4 bytes of each record is the target parameter address of the data
-- in the destination device. Ignore records whose data is not fully contained
-- within the address given address range. 
--  - records: list of records to encode (indexed table of octet strings);
--  - base_addr: address of the first parameter within the target range (integer);
--  - top_addr: one above the address of the last parameter within the target
--    range (integer).  
--
-- Returns:
--  - msgs: a list of DT1 messages, one per valid input record that contains data
--    for the target parameter address range.
function encode_records( records, base_addr, top_addr ) -- -> msgs
   local msgs, data, addr, top
   
   msgs = {}
   if type( records ) == "table" then
      for i = 1, #records do
         data = records[i]
         if type( data ) == "string" and #data >= 4 then
            addr = nibbles_to_integer( string.sub( data, 1, 4 ) )
            top = addr + (#data - 4)
            if addr >= base_addr and top <= top_addr then
               msgs[#msgs + 1] = dt1( data )
            end
         end
      end
   end

   return msgs
end -- encode_records()


-- MMD FUNCTIONS:
local model = {}


function model.info() -- -> info
   return {
      specification = 2,
      name = "Roland RD-2000",
      source = "Old Blue Bike Software inc.",
      version = "2.0",
      icon = "*.png", -- look for file with same path as this file with '.png' appended
      manufacturer = "41",
      family = "75 02",
      member = "00 01",
      slots = 0, -- has no method to dump programs in persistent memory
      timeout = 80,
      notes = 
         "NO STORED PROGRAMS:\n" ..
         "===================\n" ..
         "\n" ..
         "The RD-2000 internally stores up to 300 programs but provides no method\n" ..
         "to export or restore the programs via MIDI SysEx messaging. This MMD can\n" ..
         "retrieve or restore the active program in the RD-2000 edit buffer only.\n" }
end -- model.info()


function model.globals() --> globals
   return {
      "Common",
      "Compressor" }
end -- model.globals()


-- Decode the software version information from the IDENTITY REPLY
-- message transmitted by the device. The message must conform to the 
-- MIDI and RD-2000 specifications as follows:
--
-- This function expects the 'msg' argument to be an octet string
-- containing the 13th to 16th bytes (inclusive) of the IDENTITY
-- REPLY. It then returns a single string with the software 
-- version number as follows: "<aa><bb>.<cc><dd>".
--
-- NOTE: The RD-2000 MIDI implementation sheet is unclear as
-- to the meaning of the <aa>..<dd> bytes, but the values appear
-- to be version digits in range 0-9 (correlating with "01.00" on
-- an original system). Also, it was noted that on a system that 
-- has been updated to version 1.50, the version information still 
-- appears in the IDENTITY REPLY message as "00 01 00 00".
function model.decode_software_version( msg ) -- -> sw_ver
   local aa, bb, cc, dd

   if type( msg ) ~= "string" or #msg ~= 4 then 
      return nil -- incorrect length
   end

   aa = string.byte( msg, 1 )
   bb = string.byte( msg, 2 )
   cc = string.byte( msg, 3 )
   dd = string.byte( msg, 4 )

   if aa > 0x09 or bb > 0x09 or cc > 0x09 or dd > 0x09 then
      return nil -- value out of range
   end

   return aa .. bb .. "." .. cc .. dd
end


function model.dump_program_command( config, slot ) -- -> msgs, header, max_rsps
   -- Temporary program parameters for RD-2000 are broken into
   -- sections in the address space, with gaps between them. Also RD-2000 
   -- SysEx messages may not exceed 512 bytes or the device hangs (oops, 
   -- firmware doesn't protect itself against buffer overlow?... bug...).
   return {
      rq1( "10 00 00 00", "00 00 01 44" ),   -- Program Common
      rq1( "10 00 02 00", "00 00 00 05" ),   -- Program Song/Rythm
      rq1( "10 00 04 00", "00 00 00 55" ),   -- Program Delay
      rq1( "10 00 06 00", "00 00 00 52" ),   -- Program Reverb
      rq1( "10 00 10 00", "00 00 01 07" ),   -- Program Modulation FX (Zone 1)
      rq1( "10 00 12 00", "00 00 01 07" ),   -- Program Tremolo/Amp Simulator (Zone 1)
      rq1( "10 00 14 00", "00 00 01 07" ),   -- Program Modulation FX (Zone 2)
      rq1( "10 00 16 00", "00 00 01 07" ),   -- Program Tremolo/Amp Simulator (Zone 2)
      rq1( "10 00 18 00", "00 00 01 07" ),   -- Program Modulation FX (Zone 3)
      rq1( "10 00 1A 00", "00 00 01 07" ),   -- Program Tremolo/Amp Simulator (Zone 3)
      rq1( "10 00 1C 00", "00 00 01 07" ),   -- Program Modulation FX (Zone 4)
      rq1( "10 00 1E 00", "00 00 01 07" ),   -- Program Tremolo/Amp Simulator (Zone 4)
      rq1( "10 00 20 00", "00 00 02 00" ),   -- Program Internal Zone (Zone 1)
      rq1( "10 00 22 00", "00 00 02 00" ),   --   ... cont'd
      rq1( "10 00 24 00", "00 00 02 00" ),   --   ... cont'd
      rq1( "10 00 26 00", "00 00 00 78" ),   --   ... cont'd
      rq1( "10 00 28 00", "00 00 02 00" ),   -- Program Internal Zone (Zone 2)
      rq1( "10 00 2A 00", "00 00 02 00" ),   --   ... cont'd
      rq1( "10 00 2c 00", "00 00 02 00" ),   --   ... cont'd
      rq1( "10 00 2E 00", "00 00 00 78" ),   --   ... cont'd
      rq1( "10 00 30 00", "00 00 02 00" ),   -- Program Internal Zone (Zone 3)
      rq1( "10 00 32 00", "00 00 02 00" ),   --   ... cont'd
      rq1( "10 00 34 00", "00 00 02 00" ),   --   ... cont'd
      rq1( "10 00 36 00", "00 00 00 78" ),   --   ... cont'd
      rq1( "10 00 38 00", "00 00 02 00" ),   -- Program Internal Zone (Zone 4)
      rq1( "10 00 3A 00", "00 00 02 00" ),   --   ... cont'd
      rq1( "10 00 3C 00", "00 00 02 00" ),   --   ... cont'd
      rq1( "10 00 3E 00", "00 00 00 78" ),   --   ... cont'd
      rq1( "10 00 40 00", "00 00 00 4c" ),   -- Program External Zone (Zone 1)
      rq1( "10 00 42 00", "00 00 00 4c" ),   -- Program External Zone (Zone 2)
      rq1( "10 00 44 00", "00 00 00 4c" ),   -- Program External Zone (Zone 3)
      rq1( "10 00 46 00", "00 00 00 4c" ),   -- Program External Zone (Zone 4)
      rq1( "10 00 50 00", "00 00 02 00" ),   -- Program Internal Zone (Zone 5)
      rq1( "10 00 52 00", "00 00 02 00" ),   --   ... cont'd
      rq1( "10 00 54 00", "00 00 02 00" ),   --   ... cont'd
      rq1( "10 00 56 00", "00 00 00 78" ),   --   ... cont'd
      rq1( "10 00 58 00", "00 00 02 00" ),   -- Program Internal Zone (Zone 6)
      rq1( "10 00 5A 00", "00 00 02 00" ),   --   ... cont'd
      rq1( "10 00 5C 00", "00 00 02 00" ),   --   ... cont'd
      rq1( "10 00 5E 00", "00 00 00 78" ),   --   ... cont'd
      rq1( "10 00 60 00", "00 00 02 00" ),   -- Program Internal Zone (Zone 7)
      rq1( "10 00 62 00", "00 00 02 00" ),   --   ... cont'd
      rq1( "10 00 64 00", "00 00 02 00" ),   --   ... cont'd
      rq1( "10 00 66 00", "00 00 00 78" ),   --   ... cont'd
      rq1( "10 00 68 00", "00 00 02 00" ),   -- Program Internal Zone (Zone 8)
      rq1( "10 00 6A 00", "00 00 02 00" ),   --   ... cont'd
      rq1( "10 00 6C 00", "00 00 02 00" ),   --   ... cont'd
      rq1( "10 00 6E 00", "00 00 00 78" ),   --   ... cont'd
      rq1( "10 00 70 00", "00 00 00 4c" ),   -- Program External Zone (Zone 5)
      rq1( "10 00 72 00", "00 00 00 4c" ),   -- Program External Zone (Zone 6)
      rq1( "10 00 74 00", "00 00 00 4c" ),   -- Program External Zone (Zone 7)
      rq1( "10 00 76 00", "00 00 00 4c" ) }, -- Program External Zone (Zone 8)
      get_header(),                          -- Response message header
      1                                      -- expected # responses per request
end -- model.dump_program_command()


function model.dump_globals_command( config, globals ) -- -> msgs, header, max_rsps
   local msgs

   if globals == "Common" then
      msgs = { rq1( "00 00 00 00", "00 00 00 20" ) }
   elseif globals == "Compressor" then
      msgs = { rq1( "00 00 01 00", "00 00 00 12" ) }
   else
      print( "RD-2000 dump_globals_command(): unknown globals \"" .. globals .. '\"' )
      return nil -- invalid configuration
   end

   return msgs, get_header(), 1
end -- model.dump_globals_command()


function model.decode( msgs ) -- -> records
   local sys_base, sys_top, pgm_base, pgm_top, records, last_top, record, addr, top, name

   if type( msgs ) ~= "table" or #msgs == 0 then
      print( "RD-2000 decode(): invalid msgs argument")
      return nil -- invalid argument
   end

   common_base = hex_to_integer( "00 00 00 00" )
   common_top = hex_to_integer( "00 00 00 20" )   
   compressor_base = hex_to_integer( "00 00 01 00" )
   compressor_top = hex_to_integer( "00 00 01 12" )
   pgm_base = hex_to_integer( "10 00 00 00" )
   pgm_top = hex_to_integer( "10 00 78 00" )
   
   records = {}
   last_addr = nil
   for i = 1, #msgs do
      msg = msgs[i]
      record, addr = decode_dt1( msg )
      if type( record ) == "string" and type( addr ) == "number" then
         -- Valid DT1 message.
         top = addr + (#record - 4)
         if addr >= pgm_base and top <= pgm_top then
            -- DT1 message contains active program parameters (edit buffer):
            if type( last_top ) ~= "number" or 
               last_top < pgm_base or last_top >= pgm_top or
               addr < last_top then
               -- Start a new program record block:
               records[#records + 1] = "program:0"
            end
            if addr == pgm_base then
               -- This record should contain the program's name:
               name = get_program_name( record )
               if type( name ) == "string" then
                  records[#records + 1] = "name:" .. name
               end
            end
            records[#records + 1] = "data:" .. record
            
         elseif addr >= common_base and top <= common_top then
            -- DT1 message contains system common parameters:
            if type( last_top ) ~= "number" or 
               last_top < pgm_base or last_top >= pgm_top or
               addr < last_top then
               -- Start a new system common parameters block:
               records[#records + 1] = "globals:Common"
            end
            records[#records + 1] = "data:" .. record
            
         elseif addr >= compressor_base and top <= compressor_top then
            -- DT1 message contains compressor parameters:
            if type( last_top ) ~= "number" or 
               last_top < compressor_base or last_top >= compressor_top or
               addr < last_top then
               -- Start a new compressor parameters block:
               records[#records + 1] = "globals:Compressor"
            end
            records[#records + 1] = "data:" .. record
                        
         end
         last_top = top
      end
   end -- for i = 1, #msgs do

   return records
end -- model.decode()


function model.load_program_command( config, records, slot, name ) -- -> msgs
   local base_addr, top_addr
   
   if type( records ) ~= "table" or #records == 0 or type( records[1] ) ~= "string" then
      print( "RD-2000 load_program_command(): invalid records argument" )
      return nil
   end
   if type( slot ) ~= "nil" and (type( slot ) ~= "number" or slot ~= 0)  then
      print( "RD-2000 load_program_command(): invalid slot argument" )
      return nil
   end

   -- Active program parameter address range:
   base_addr = hex_to_integer( "10 00 00 00" )
   top_addr = hex_to_integer( "10 00 78 00" )
   
   -- Update the record that contains the program's name with the given name:
   if nibbles_to_integer( string.sub( records[1], 1, 4 ) ) == base_addr then
      records[1] = set_program_name( records[1], name )
      name = get_program_name( records[1] )
   end
   return encode_records( records, base_addr, top_addr )
end -- model.load_program_command()


function model.load_globals_command( config, globals, records ) -- -> msgs
   local base_addr, top_addr
   
   if globals == "Common" then
      base_addr = hex_to_integer( "00 00 00 00" )
      top_addr = hex_to_integer( "00 00 00 20" )
   elseif globals == "Compressor" then
      base_addr = hex_to_integer( "00 00 01 00" )
      top_addr = hex_to_integer( "00 00 01 12" )
   else
      print( "RD-2000 load_globals_command(): unknown globals \"" .. globals .. '\"' )
      return nil -- invalid configuration
   end
   
   return encode_records( records, base_addr, top_addr )
end -- model.local_globals_command()


return model


-- EOF rd2000.lua
