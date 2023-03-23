-- midi.lua
--
-- Copyright (C) 2021, Old Blue Bike Software Inc.
--
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


-- HELPER ROUTINES:
function to_hex_digit( n )
   -- expect n is always an integer in range [0;15]:
   if n < 10 then
      return string.char( 48 + n )
   else
      return string.char( 55 + n )
   end
end
   
   
function octets_to_hex( v )
   local hex, i, byte

   if type( v ) == "string" then
      -- v must be an octet string, each character is a byte value to be converted
      -- to 2 hexadecimal digits:
      hex = ""
      for i = 1, #v do
         byte = string.byte( v, i )
         hex = hex .. " " .. to_hex_digit( (byte & 0xF0) >> 4 ) .. to_hex_digit( byte & 0x0F )
      end
      return string.sub( hex, 2 )
   elseif type( v ) == "number" then
      -- v is a single integer value to be converted to a 2 hexadecimal digits 
      -- (use only the 8 least significant bits, ignore the rest)
      byte = (v & 0xFF)
      return to_hex_digit( (byte & 0xF0) >> 4 ) .. to_hex_digit( byte & 0x0F )
   else
      return ""
   end
end


function hex_value( c )
   if c >= 48 and c <= 57 then
      return c - 48 
   elseif c >= 65 and c <= 65 + 26 - 1 then
      return c - 55
   elseif c >= 97 and c <= 97 + 26 - 1 then
      return c - 87
   end
   return nil
end


-- Encode an octet string from a given textual representation or a single byte value
function hex_to_octets( v )
   local octets, i

   if type( v ) == "string" then
      -- expect v is the textual representation of an octet string
      octets = ""
      i = 1
      while i < #v do
         h = hex_value( string.byte( v, i ) )
         i = i + 1
         if type( h ) == "number" then
            l = hex_value( string.byte( v, i ) )
            if type( l ) == "number" then
               octets = octets .. string.char( ((h << 4) | l) )
            end
            i = i + 1
         end
      end
      return octets
   elseif type( v ) == "number" then
      -- v is an octet value:
      return string.char( v & 0xFF )
   else
      -- Can't encode unrecognized value type to ictet string
      return ""
   end
end


-- MODULE DEFINITION:
midi = {}


-- Convert an octet string into a textual representation using 2 hexadecimal digits 
-- per byte:
function midi.octets_to_hex( v )
   local hex, i, e

   if type( v ) == "table" then
      -- Convert each entry in the table
      hex = ""
      for i, e in ipairs( v ) do
         hex = hex .. " " .. octets_to_hex( e )
      end
      return string.sub( hex, 2 )
   else
      return octets_to_hex( v )
   end
end


-- Make an octet string from the given textual representation:
function midi.hex_to_octets( v )
   local octets, i, e

   if type( v ) == "table" then
      octets = ""
      for i, e in ipairs( v ) do
         octets = octets .. hex_to_octets( e )
      end
      return octets
   else
      return hex_to_octets( v )
   end
end


-- Pack an array of 8-bit bytes into an array of 7-bit words for transmission 
-- over MIDI. Each block of 7 consecutive 8-bit bytes is packed into 8 x 7-bit
-- words, where the first word contains the most significant bit of each of the
-- 7 bytes:
--
--     Unpacked: 
--        Byte#             bits
--          1:     A7 A6 A5 A4 A3 A3 A1 A0
--          2:     B7 B6 B5 B4 B3 B3 B1 B0
--          3:     C7 C6 C5 C4 C3 C3 C1 C0
--          4:     D7 D6 D5 D4 D3 D3 D1 D0
--          5:     E7 E6 E5 E4 E3 E3 E1 E0
--          6:     F7 F6 F5 F4 F3 F3 F1 F0
--          7:     G7 G6 G5 G4 G3 G3 G1 G0
--
--     Packed:
--        Word#             bits
--          1:      0 G7 F7 E7 D7 C7 B7 A7
--          2:      0 A6 A5 A4 A3 A3 A1 A0
--          3:      0 B6 B5 B4 B3 B3 B1 B0
--          4:      0 C6 C5 C4 C3 C3 C1 C0
--          5:      0 D6 D5 D4 D3 D3 D1 D0
--          6:      0 E6 E5 E4 E3 E3 E1 E0
--          7:      0 F6 F5 F4 F3 F3 F1 F0
--          8:      0 G6 G5 G4 G3 G3 G1 G0
--
-- If the unpacked data is not an exact multiple of 7 bytes long, the extra
-- bytes are encoded similarly, leaving the unused MSBs in the first word
-- set to 0, for example:
--
--     Unpacked: 
--        Byte#             bits
--          1:     A7 A6 A5 A4 A3 A3 A1 A0
--          2:     B7 B6 B5 B4 B3 B3 B1 B0
--          3:     C7 C6 C5 C4 C3 C3 C1 C0
--
--     Packed:
--        Word#             bits
--          1:      0  0  0  0  0 C7 B7 A7
--          2:      0 A6 A5 A4 A3 A3 A1 A0
--          3:      0 B6 B5 B4 B3 B3 B1 B0
--          4:      0 C6 C5 C4 C3 C3 C1 C0
--
function midi.pack( unpacked )
   local mask, packed, i, unpacked_chunk, msb, packed_chunk, j, n

   mask = { 0x01, 0x02, 0x04, 0x08, 0x10, 0x20, 0x40 }
   packed = ""
   i = 1
   while i <= #unpacked do
      unpacked_chunk = string.sub( unpacked, i, i+6 )
      i = i + 7
      msb = 0
      packed_chunk = ""
      for j = 1, #unpacked_chunk do      
         n = string.byte( unpacked_chunk, j )
         if (n & 0x80) > 0 then
            msb = msb | mask[j]
         end
         packed_chunk = packed_chunk .. string.char( n & 0x7F )
      end
      packed = packed .. string.char( msb ) .. packed_chunk
   end
   return packed
end -- pack_data()
      

-- Unpack data bytes from a MIDI message, see "midi.pack()" for format.
function midi.unpack( packed )
   local mask, msb, unpacked, i, j, n

   mask = { 0x01, 0x02, 0x04, 0x08, 0x10, 0x20, 0x40 }
   unpacked = ""
   i = 1
   while i <= #packed do
      msb = string.byte( packed, i )
      packed_chunk = string.sub( packed, i + 1, i + 7 )
      i = i + 8
      for j = 1, #packed_chunk do
         n = string.byte( packed_chunk, j )
         if (msb & mask[j]) > 0 then
            n = n | 0x80
         end
         unpacked = unpacked .. string.char( n )
      end
   end
   return unpacked
end -- unpack_data()


function midi.note_off( channel, note, velocity )
   return midi.hex_to_octets( { 0x80|channel, note, velocity } )
end -- midi.noteon()


function midi.note_on( channel, note, velocity )
   return midi.hex_to_octets( { 0x90|channel, note, velocity } )
end -- midi.noteon()


function midi.poly_key_pressure( channel, note, velocity )
   return midi.hex_to_octets( { 0xA0|channel, note, velocity } )
end -- midi.poly_key_pressure()


function midi.control_change( channel, control, value )
   return midi.hex_to_octets( { 0xB0|channel, control, value } )
end -- midi.control_change()


function midi.program_change( channel, program )
   return midi.hex_to_octets( { 0xC0|channel, program } )
end -- midi.program_change()


function midi.channel_pressure( channel, value )
   return midi.hex_to_octets( { 0xD0|channel, value } )
end -- midi.channel_pressure()


function midi.pitch_bend_change( channel, value )
   return midi.hex_to_octets( { 0xE0|channel, (value & 0x7F), ((value >> 7) & 0x7F) } )
end -- midi.pitch_bend_change()


function midi.song_position_pointer( beats )
   return midi.hex_to_octets( { 0xF2, (beats & 0x7F), ((beats >> 7) & 0x7F) } )
end -- midi.song_position_pointer()


function midi.song_select( song )
   return midi.hex_to_octets( { 0xF3, song } )
end -- midi.song_select()


function midi.tune_request()
   return string.char( 0xF6 )
end -- midi.tune_request()


function midi.timing_clock()
   return string.char( 0xF8 )
end -- midi.timing_clock()


function midi.start()
   return string.char( 0xFA )
end -- midi.start()


function midi.continue()
   return string.char( 0xFB )
end -- midi.continue()


function midi.stop()
   return string.char( 0xFC )
end -- midi.stop()


function midi.active_sensing()
   return string.char( 0xFE )
end -- midi.active_sensing()


function midi.system_reset()
   return string.char( 0xFF )
end -- midi.system_reset()


function midi.data_entry( channel, value )
   return 
      midi.control_change( channel, 0x26, (value & 0x7F) ) ..
      midi.control_change( channel, 0x06, ((value >> 7) & 0x7F) )
end -- midi.data_entry()


function midi.select_nrpn( channel, control )
   return 
      midi.control_change( channel, 0x62, (control & 0x7F) ) ..
      midi.control_change( channel, 0x63, ((control >> 7) & 0x7F) )
end -- midi.select_nrpn()


function midi.set_nrpn( channel, control, value )
   return  midi.select_nrpn( channel, control ) .. midi.data_entry( channel, value )
end -- midi.set_nrpn()


function midi.select_rpn( channel, control )
   return
      midi.control_change( channel, 0x64, (control & 0x7F) ) ..
      midi.control_change( channel, 0x65, ((control >> 7) & 0x7F) )
end -- midi.select_rpn()


function midi.set_rpn( channel, control, value )
   return midi.select_rpn( channel, control ) .. midi.data_entry( channel, value )
end -- midi.set_rpn()


function midi.select_program_bank( channel, bank )
   return 
      midi.control_change( channel, 0x20, (control & 0x7F) ) ..
      midi.control_change( channel, 0x00, ((control >> 7) & 0x7F) )
end -- midi.select_program_bank()


function midi.change_program_bank( channel, bank, program )
   return
      midi.select_program_bank( channel, bank ) .. 
      midi.changeprogram( channel, program )
end -- midi.change_program_bank()


function midi.decode( msg, pos )
   local status, typecode, len, data1, data2, info
   
   if type( pos ) ~= "number" then
      pos = 1
   end
   if type( msg ) == "string" and pos <= #msg then
      status = string.byte( msg, pos )
      if (status & 0x80) ~= 0 then
         -- Sequence starts with a valid MIDI status byte. Extract and validate
         -- the next two bytes as data for the message:
         len = #msg - pos + 1
         if len >= 2 then
            data1 = string.byte( msg, pos + 1 )
            if (data1 & 0x80) ~= 0 then
               data1 = nil
            end
            if len >= 3 then
               data2 = string.byte( msg, pos + 2 )
               if (data2 & 0x80) ~= 0 then
                  data2 = nil
               end
            end
         end
         
         -- Determine message type:
         if status < 0xF0 then
            -- strip channel number from voice channel message status byte:
            typecode = status & 0xF0
         else
            typecode = status
         end
         
         if typecode == 0x80 and data1 ~= nil and data2 ~= nil then
            info = {
               first = pos,
               last = pos + 2,
               name = "note off",
               channel = status & 0x0F,
               note = data1,
               velocity = data2 }
            
         elseif typecode == 0x90 and data1 ~= nil and data2 ~= nil then
            info = {
               first = pos,
               last = pos + 2,
               name = "note on",
               channel = status & 0x0F,
               note = data1,
               velocity = data2 }
            
         elseif typecode == 0xA0 and data1 ~= nil and data2 ~= nil then
            info = {
               first = pos,
               last = pos + 2,            
               name = "poly key pressure",
               channel = status & 0x0F,
               note = data1,
               velocity = data2 }
            
         elseif typecode == 0xB0 and data1 ~= nil and data2 ~= nil then
            info = {
               first = pos,
               last = pos + 2,            
               channel = status & 0x0F,
               control = data1 }
               
            -- Identify specific control name if known:
            if data1 == 0x26 then
               info.name = "data entry"
               info.value = data2
            elseif data1 == 0x06 then
               info.name = "data entry"
               info.value = data2 << 7
            elseif data1 == 0x62 then
               info.name = "select nrpn"
               info.number = data2
            elseif data1 == 0x63 then
               info.name = "select nrpn"
               info.number = data2 << 7
            elseif data1 == 0x64 then
               info.name = "select rpn"
               info.number = data2
            elseif data1 == 0x65 then
               info.name = "select rpn"
               info.number = data2 << 7
            elseif data1 == 0x20 then
               info.name = "select bank"
               info.bank = data2
            elseif data1 == 0x00 then
               info.name = "select bank"
               info.bank = data2 << 7
            else
               info.name = "control change"
               info.value = data2
            end
            
         elseif typecode == 0xC0 and data1 ~= nil then
            info = {
               first = pos,
               last = pos + 1,                        
               name = "program change",
               channel = status & 0x0F,               
               program = data1 }
            
         elseif typecode == 0xD0 and data1 ~= nil then
            info = {
               first = pos,
               last = pos + 1,                        
               name = "channel pressure",
               value = data1 }
            
         elseif typecode == 0xE0 and data1 ~= nil and data2 ~= nil then
            info = {
               first = pos,
               last = pos + 2,                        
               name = "pitch bend change",
               value = data1 | (data2 << 7) }
            
         elseif typecode == 0xF0 and len >= 2 then
            for i = pos + 1, #msg do
               data1 = string.byte( msg, i )
               if data1 == 0xF7 then
                  info = {
                     first = pos,
                     last = i,
                     name = "system exclusive",
                     data = string.sub( msg, pos + 1, i - 1 ) }
                  break
               elseif (data1 & 0x80) ~= 0 then
                  break
               end
            end
            
         elseif typecode == 0xF3 and data1 ~= nil then
            info = {
               first = pos,
               last = pos + 1,
               name = "song select",
               song = data1 }
            
         elseif typecode == 0xF2 and data1 ~= nil and data2 ~= nil then
            info = {
               first = pos,
               last = pos + 2,
               name = "song position pointer",
               beats = data1 | (data2 << 7) }

         elseif typecode == 0xF6 then
            info = {
               first = pos,
               last = pos,
               name = "tune request" }
            
         elseif typecode == 0xF8 then
            info = {
               first = pos,
               last = pos,
               name = "timing clock" }
            
         elseif typecode == 0xFA then
            info = {
               first = pos,
               last = pos,
               name = "start" }
            
         elseif typecode == 0xFB then
            info = {
               first = pos,
               last = pos,
               name = "continue" }
            
         elseif typecode == 0xFC then
            info = {
               first = pos,
               last = pos,
               name = "stop" }
            
         elseif typecode == 0xFE then
            info = {
               first = pos,
               last = pos,
               name = "active sensing" }
            
         elseif typecode == 0xFF then
            info = {
               first = pos,
               last = pos,
               name = "system reset" }

         end
      end -- if (status & 0x80) ~= 0
   end -- if type( msg ) == "string" and ...
   
   return info
end -- midi.decode()


function midi.load( filename )
   local file, data, msgs, pos, new, previous

   file = io.open( filename, "rb" )
   if file == nil then
      print( "midi.load(): error opening \"" .. filename .. "\" for reading." )
      return
   end
   data = file:read("a")
   file:close()
   
   -- Decode all messages in file, aggregate related message sequences into composites 
   -- where possible:
   msgs = {}
   pos = 1
   while pos <= #data do
      -- Parse and decode message starting at current file position:
      new = midi.decode( data, pos )
      if new == nil then
         -- Invalid byte sequence in file:
         break
      end

      -- Advance past decoded message:
      pos = new.last + 1
      
      -- See if new message can be aggregated with previous:
      if type( previous ) == "table" then
         if previous.name == "data entry" then
            -- Can new message aggregate with the previous "data entry"?
            if new.name == "data entry" and 
               previous.control ~= nil and new.control ~= previous.control then
               -- Aggregate consecutive "data entry" change control messages with LSB and 
               -- MSB of 14-bit value:
               previous.last = new.last
               previous.value = info.value | new.value
               previous.control = nil -- aggregate full
               new = nil
            end
         elseif previous.name == "select nrpn" then
            -- Can new message aggregate with the previous "select NRPN"?
            if new.name == "select nrpn" and
               previous.control ~= nil and new.control ~= previous.control then
               -- Aggregate consecutive "select NRPN" change control messages with LSB and
               -- MSB of 14-bit parameter number:
               previous.last = new.last
               previous.number = previous.number | new.number
               previous.control = nil -- aggregate full
               new = nil
            elseif new.name == "data entry" then
               -- Aggregate "select NRPN" and "data entry" control sequences into 
               -- "set NRPN" sequence:
               previous.last = new.last
               previous.name = "set nrpn"
               previous.control = new.control
               previous.value = new.value
               new = nil
            end
         elseif previous.name == "select rpn" then
            -- Can new message aggregate with the previous "select RPN"?
            if new.name == "select rpn" and
               previous.control ~= nil and new.control ~= previous.control then
               -- Aggregate consecutive "select RPN" change control messages with LSB and
               -- MSB of 14-bit parameter number:
               previous.last = new.last
               previous.number = previous.number | new.number
               previous.control = nil -- aggregate full
               new = nil
            elseif new.name == "data entry" then
               -- Aggregate "select RPN" and "data entry" control sequences into 
               -- "set NRPN" sequence:
               previous.last = new.last
               previous.name = "set nrpn"
               previous.control = new.control
               previous.value = new.value
               new = nil
            end
         elseif previous.name == "select bank" then
            -- Can new message aggregate with the previous "select bank"?
            if new.name == "select bank" and
               previous.control ~= nil and new.control ~= previous.control then               
               -- Aggregate consecutive "select bank" change control messages with LSB and
               -- MSB of 14-bit bank number:
               previous.last = new.last
               previous.bank = previous.bank | new.bank
               previous.control = nil -- aggregate full
               new = nil
            elseif new.name == "program change" then
               -- Aggregate consecutive "select bank" and "program change" messages into
               -- "change program bank and number" sequence:
               previous.last = new.last
               previous.name = "change program bank"
               previous.program = new.program               
               previous.control = nil
               new = nil
            end
         elseif previous.name == "set nrpn" or previous.name == "set rpn" then
            -- A "set RPN/NRPN" sequence necessarily already contains a "select RPN/NRPN" 
            -- sequence and a partial "data entry" sequence. We can only aggregate another
            -- "data entry" control change with the other half of the parameter value to set:
            if new.name == "data entry" and 
               previous.control ~= nil and new.control ~= previous.control then
               previous.last = new.last
               previous.value = previous.value | new.value
               previous.control = nil -- aggregate full
               new = nil
            end
         end
      end -- if type( previous ) == "table" 
         
      if type( new ) == "table" then
         -- New message cannot be aggregated with previous. Flush previous and continue:
         if type( previous ) == "table" then            
            msgs[#msgs + 1] = string.sub( data, previous.first, previous.last )
         end
         previous = new
      end
   end -- while pos <= #data

   -- Flush last message:
   if type( previous ) == "table" then
      msgs[#msgs + 1] = string.sub( data, previous.first, previous.last )
   end
   
   return msgs
end -- midi.load()


-- Given a list of MIDI messages encoded as octet strings, display each message as an
-- hexadecimal string.
function midi.list( msgs )
   local msg

   if type( msgs ) ~= "table" then
      print( "midi.list(): invalid msgs argument" )
      return
   end

   for i = 1, #msgs do
      msg = msgs[i]
      if type( msg ) ~= "string" then
         print( "midi.list(): invalid msgs argument" )
         return
      end
      print( midi.octets_to_hex( msgs[i] ) )
   end
end -- midi.list()


-- Save a list of MIDI messages to a file with the given name:
function midi.save( msgs, filename )
   local file

   file = io.open( filename, "wb" )
   if file == nil then
      print( "midi.save(): error opening \"" .. filename .. "\" for writing." )
      return
   end

   for i = 1, #msgs do
      file:write( msgs[i] )
   end
   file:close()
end -- midi.save()


-- Given two lists of byte strings, compare each entry one-to-one and identify those that 
-- differ. If the lists are different lengths, compare only entries that exist in both.
-- Returns the number of entries that differ between the two lists.
function midi.compare( m1, m2 )
   local n, diffs

   n = #m1
   if #m2 < n then
      n = #m2
   end

   diffs = 0
   for i = 1, n do
      if m1[i] ~= m2[i] then
         diffs = diffs + 1
      end
   end

   return diffs
end -- midi.compare()


function midi.cat( msgs )
   local msg

   msg = ""
   for i = 1, #msgs do
      msg = msg .. msgs[i]
   end
   return msg
end -- midi.cat()


return midi;


-- EOF midi.lua
