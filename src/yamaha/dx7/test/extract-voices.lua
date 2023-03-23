-- dx7/test.lua
--
-- Copyright (C) 2021, Old Blue Bike Software Inc.
--
-- Due to lack of access to a complete set of SysEx data files for the DX7 (BULK
-- DATA DUMP for 1 voice / edit buffer in particular), the DX7 MMD encode/decode
-- functions were verified with the following script, which also generates test 
-- files that can then be used for regression testing with the MMD test kit.
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


dofile("../../../../test/midi.lua")
dofile("../../../../test/kit.lua")
model = dofile("../dx7.lua")

msgs = midi.load("all-programs-dump.syx")

records = model.decode(msgs) -- tagged record list
voices = {} -- voice data records
for i = 1, 32 do
   voices[i] = kit.extract( records, "program:" .. i )[1]
end

config = { unit = 0 } -- test device configuration
for i = 1, 32 do
   record = voices[i]
   name = get_voice_name( record )
   
   voice = decode_voice( record ) -- voice table
   packed = pack_voice( voice ) -- packed voice data record
   voice = unpack_voice( packed ) -- back to voice table
   record = set_voice_name( encode_voice( voice ), name ) -- back to voice data record

   if record == voices[i] then
      print( i .. " ok" )
      msgs = model.load_program_command( config, { record } )
      midi.save( msgs, "voice-" .. i .. "-dump.syx" )
   else
      print( i .. " FAIL" )
   end
end
