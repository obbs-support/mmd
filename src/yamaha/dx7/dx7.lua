-- dx7.lua
--
-- MIDI Model Description (MMD) for Yamaha DX7 Synthesizers.

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


-- MIDI MODEL DESCRIPTION (MMD) for the Yamaha DX7
-- ===============================================
--
-- Identification:
-- ---------------
--
-- The DX7 does not implement the MIDI device inquiry protocol, and does not 
-- respond to IDENTITY REQUEST messages.
--
-- Program Data:
-- -------------
--
-- Yamaha refers to a DX7 program as a "voice". The DX7 has 32 stored program 
-- slots in addition to its edit buffer which contains the parameters of the
-- active voice.
--
-- A voice is defined by 155 parameters. The voice parameters are arranged 
-- into an array of 155 bytes forming a "voice data record", which can be
-- transmitted or received as part of a BULK VOICE DATA DUMP message with 
-- the following format:
--
--              F0 43 0g 00 01 1b xx ... xx ss F7
--                    --    ----- --------- --
--                     |      |       |      |
--         Unit ID  ---+      |       |      |
--                            |       |      |
--  Payload byte count,  -----+       |      |
--  MSB/LSB (155)                     |      |
--                                    |      |
--             Voice parameters  -----+      |
--                  (155 bytes)              |
--                                           |
--                            Checksum ------+
--
--
-- where:
--  - 'Unit ID' is the MIDI channel number assigned to this synthesizer
--    ("FUNCTION CONTROL MIDI CH=" global parameter); and
--  - 'Checksum' is the modulo 128 2's complement of the sum of the 155 payload
--    bytes, 
--
-- Multiple DX7 synthesizers can be daisy-chained on a single MIDI output by
-- assigning each a different MIDI channel number and connecting them via their
-- "MIDI THRU" ports.
--
-- 32 stored program slots can only be retrieved or set all at once in a single 
-- 32 VOICES BULK DATA message with the following format:
--
--              F0 43 0g 09 20 00 xx ... xx ss F7
--                    --    ----- --------- --
--                     |      |       |      |
--         Unit ID  ---+      |       |      |
--                            |       |      |
--  Payload byte count,  -----+       |      |
--  MSB/LSB (4096)                    |      |
--                                    |      |
--             Voice parameters  -----+      |
--                 (4096 bytes)              |
--                                           |
--                            Checksum ------+
--
-- In this message, the parameters of each of the 32 voices are repacked
-- to occupy 128 bytes per voice. This MMD uses the expression "packed
-- voice data record" to refer to this format. Credit to https://github.com/asb2m10/
-- dexed/blob/master/Documentation/sysex-format.txt for the information about
-- the packed voice data record format.


-- HELPER SUBROUTINES:

-- Remove trailing whitespaces from given string:
function trim( s )
   local i
   
   i = #s
   while i >= 1 and string.sub( s, i, i ) == " " do
      i = i - 1
   end
   return string.sub( s, 1, i )
end -- trim()


-- Construct SysEx message header using unit number in given configuration:
function get_header( config )
   local unit

   if type( config ) ~= "table" then 
      print( "DX7 get_header(): unit identfier missing from supplied configuration" )
      return nil -- invalid argument
   end
   unit = config.unit
   if type( unit ) ~= "number" or unit < 0 or unit > 15 then
      print( "DX7 get_header(): unit identifier out of valid range" )
      return nil -- out of range
   end
   return midi.hex_to_octets( { "F0 43", unit } )
end -- get_header()


-- Deserialize the parameters of an FM operator from a voice data record. Each
-- voice data record contains an array of 6 of these structures, one per operator.
--
-- Parameters:
--  - op_rec: a 21-octet string, the parameters of the operator as arranged 
--    in a voice data record.
--
-- Returns:
--  - op: a table with the operator's parameters. 
function decode_operator( op_rec ) -- -> op
   if #op_rec == 21 then
      return {
         eg = { 
            rate = {
               string.byte( op_rec, 1 ),
               string.byte( op_rec, 2 ),
               string.byte( op_rec, 3 ),
               string.byte( op_rec, 4 )
            },
            level = {
               string.byte( op_rec, 5 ),
               string.byte( op_rec, 6 ),
               string.byte( op_rec, 7 ),
               string.byte( op_rec, 8 )
            }
         },
         kbd_lev_scl = {
            brk_pt = string.byte( op_rec, 9 ),
            lft_depth = string.byte( op_rec, 10 ),
            rht_depth = string.byte( op_rec, 11 ),
            lft_curve = string.byte( op_rec, 12 ),
            rht_curve = string.byte( op_rec, 13 )
         },
         kbd_rate_scaling = string.byte( op_rec, 14 ),
         amp_mod_sensitivity = string.byte( op_rec, 15 ),
         key_vel_sensitivity = string.byte( op_rec, 16 ),
         output_level = string.byte( op_rec, 17 ),
         osc = {
            mode = string.byte( op_rec, 18 ),
            freq_coarse = string.byte( op_rec, 19 ),
            freq_fine = string.byte( op_rec, 20 ),
            detune = string.byte( op_rec, 21 ) 
         }
      }
   end
end -- decode_operator()


-- Deserialize the parameters of a voice from a voice data record.
--
-- Parameters:
--  - record: a 155-octet string, voice data record. 
--
-- Returns:
--  - voice: a table with the parameters of the voice.
function decode_voice( record ) -- -> voice
   if #record == 155 then
      return {
         op = {
            decode_operator( string.sub( record, 106, 126 ) ), -- OP1
            decode_operator( string.sub( record, 85, 105 ) ), -- OP2
            decode_operator( string.sub( record, 64, 84 ) ), -- OP3
            decode_operator( string.sub( record, 43, 63 ) ), -- OP4
            decode_operator( string.sub( record, 22, 42 ) ), -- OP5
            decode_operator( string.sub( record, 1, 21 ) ), -- OP6
         },
         pitch_eg = {
            rate = {
               string.byte( record, 127 ),
               string.byte( record, 128 ),
               string.byte( record, 129 ),
               string.byte( record, 130 )
            },
            level = {
               string.byte( record, 131 ),
               string.byte( record, 132 ),
               string.byte( record, 133 ),
               string.byte( record, 134 )
            }
         },
         algo = string.byte( record, 135 ),
         feedback = string.byte( record, 136 ),
         osc_sync = string.byte( record, 137 ),
         lfo = {
            speed = string.byte( record, 138 ),
            delay = string.byte( record, 139 ),
            pitch_mod_depth = string.byte( record, 140 ),
            amp_mod_depth = string.byte( record, 141 ),
            sync = string.byte( record, 142 ),
            waveform = string.byte( record, 143 ),
            pitch_mod_sensitivity = string.byte( record, 144 )
         },
         transpose = string.byte( record, 145 ),
         name = trim( string.sub( record, 146, 155 ) )
      }
   end
end -- decode_voice()


-- Unpack the parameters of an FM operator from a packed voice data record. Each
-- packed voice data record contains an array of 6 of these structures, one per
-- operator.
--
-- Parameters:
--  - packed_op_rec: a 17-octet string, the parameters of the operator as arranged 
--    in a packed voice data record.
--
-- Returns:
--  - op: a table with the operator's parameters.
function unpack_operator( packed_op_rec ) -- -> op   
   if #packed_op_rec == 17 then
      return {
         eg = { 
            rate = {
               string.byte( packed_op_rec, 1 ),
               string.byte( packed_op_rec, 2 ),
               string.byte( packed_op_rec, 3 ),
               string.byte( packed_op_rec, 4 )
            },
            level = {
               string.byte( packed_op_rec, 5 ),
               string.byte( packed_op_rec, 6 ),
               string.byte( packed_op_rec, 7 ),
               string.byte( packed_op_rec, 8 )
            }
         },
         kbd_lev_scl = {
            brk_pt = string.byte( packed_op_rec, 9 ),
            lft_depth = string.byte( packed_op_rec, 10 ),
            rht_depth = string.byte( packed_op_rec, 11 ),
            lft_curve = string.byte( packed_op_rec, 12 ) & 0x03,
            rht_curve = (string.byte( packed_op_rec, 12 ) >> 2) & 0x03
         },
         kbd_rate_scaling = string.byte( packed_op_rec, 13 ) & 0x07,
         amp_mod_sensitivity = string.byte( packed_op_rec, 14 ) & 0x03,
         key_vel_sensitivity = (string.byte( packed_op_rec, 14 ) >> 2) & 0x07,
         output_level = string.byte( packed_op_rec, 15 ),
         osc = {
            mode = string.byte( packed_op_rec, 16 ) & 0x01,
            freq_coarse = (string.byte( packed_op_rec, 16 ) >> 1) & 0x1F,
            freq_fine = string.byte( packed_op_rec, 17 ),
            detune = (string.byte( packed_op_rec, 13 ) >> 3) & 0x0F
         }
      }
   end
end -- unpack_operator()


-- Unpack the parameters of a voice from a packed voice data record.
--
-- Parameters:
--  - packed_rec: 128-octet string, packed voice data record.
--
-- Returns:
--  - voice: a table with the parameters of the voice.
function unpack_voice( packed_rec ) -- -> voice
   if #packed_rec == 128 then
      return {
         op = {
            unpack_operator( string.sub( packed_rec, 86, 102 ) ), -- OP1
            unpack_operator( string.sub( packed_rec, 69, 85 ) ), -- OP2
            unpack_operator( string.sub( packed_rec, 52, 68 ) ), -- OP3
            unpack_operator( string.sub( packed_rec, 35, 51 ) ), -- OP4
            unpack_operator( string.sub( packed_rec, 18, 34 ) ), -- OP5
            unpack_operator( string.sub( packed_rec, 1, 17 ) ), -- OP6
         },
         pitch_eg = {
            rate = {
               string.byte( packed_rec, 103 ),
               string.byte( packed_rec, 104 ),
               string.byte( packed_rec, 105 ),
               string.byte( packed_rec, 106 )
            },
            level = {
               string.byte( packed_rec, 107 ),
               string.byte( packed_rec, 108 ),
               string.byte( packed_rec, 109 ),
               string.byte( packed_rec, 110 )
            }
         },
         algo = string.byte( packed_rec, 111 ),
         feedback = string.byte( packed_rec, 112 ) & 0x07,
         osc_sync = (string.byte( packed_rec, 112 ) >> 3) & 0x01,
         lfo = {
            speed = string.byte( packed_rec, 113 ),
            delay = string.byte( packed_rec, 114 ),
            pitch_mod_depth = string.byte( packed_rec, 115 ),
            amp_mod_depth = string.byte( packed_rec, 116 ),
            sync = string.byte( packed_rec, 117 ) & 0x01,
            waveform = (string.byte( packed_rec, 117 ) >> 1) & 0x0F,
            pitch_mod_sensitivity = (string.byte( packed_rec, 117 ) >> 5) & 0x03
         },
         transpose = string.byte( packed_rec, 118 ),
         name = trim( string.sub( packed_rec, 119, 128 ) )
      }
   end
end -- unpack_voice()


-- Serialize the parameters of an FM operator for inclusion into a voice data record.
--
-- Parameters:
--  - op: a table with the operator's parameters. See decode_operator() and unpack_operator()
--    for the names of the parameters.
--
-- Returns:
--  - op_rec: a 21-octet string, the parameters of the operator as arranged 
--    in a voice data record.
function encode_operator( op ) -- -> op_rec
   return
      string.char( op.eg.rate[1] ) ..
      string.char( op.eg.rate[2] ) ..
      string.char( op.eg.rate[3] ) ..
      string.char( op.eg.rate[4] ) ..
      string.char( op.eg.level[1] ) ..
      string.char( op.eg.level[2] ) ..
      string.char( op.eg.level[3] ) ..
      string.char( op.eg.level[4] ) ..
      string.char( op.kbd_lev_scl.brk_pt ) ..
      string.char( op.kbd_lev_scl.lft_depth ) ..
      string.char( op.kbd_lev_scl.rht_depth ) ..
      string.char( op.kbd_lev_scl.lft_curve ) ..
      string.char( op.kbd_lev_scl.rht_curve ) ..
      string.char( op.kbd_rate_scaling ) ..
      string.char( op.amp_mod_sensitivity ) ..
      string.char( op.key_vel_sensitivity ) ..
      string.char( op.output_level ) ..
      string.char( op.osc.mode ) ..
      string.char( op.osc.freq_coarse ) ..
      string.char( op.osc.freq_fine ) ..
      string.char( op.osc.detune )
end -- encode_operator()
         
    
-- Serialize the parameters of a voice into a voice data record.
--
-- Parameters:
--  - voice: a table with the parameters of the voice. See decode_voice() and unpack_voice()
--    for the names of the parameters.
--
-- Returns:
--  - record: a 155-octet string, voice data record. 
function encode_voice( voice ) -- -> record
   return
      encode_operator( voice.op[6] ) .. -- 1-21
      encode_operator( voice.op[5] ) .. -- 22-42
      encode_operator( voice.op[4] ) .. -- 43-63
      encode_operator( voice.op[3] ) .. -- 64-84
      encode_operator( voice.op[2] ) .. -- 85-105
      encode_operator( voice.op[1] ) .. -- 106-126
      string.char( voice.pitch_eg.rate[1] ) .. -- 127
      string.char( voice.pitch_eg.rate[2] ) .. -- 128
      string.char( voice.pitch_eg.rate[3] ) .. -- 129
      string.char( voice.pitch_eg.rate[4] ) .. -- 130
      string.char( voice.pitch_eg.level[1] ) .. -- 131
      string.char( voice.pitch_eg.level[2] ) .. -- 132
      string.char( voice.pitch_eg.level[3] ) .. -- 133
      string.char( voice.pitch_eg.level[4] ) .. -- 134
      string.char( voice.algo ) .. -- 135
      string.char( voice.feedback ) .. -- 136
      string.char( voice.osc_sync ) .. -- 137
      string.char( voice.lfo.speed ) .. -- 138
      string.char( voice.lfo.delay ) .. -- 139
      string.char( voice.lfo.pitch_mod_depth ) .. -- 140
      string.char( voice.lfo.amp_mod_depth ) .. -- 141
      string.char( voice.lfo.sync ) .. -- 142
      string.char( voice.lfo.waveform ) .. -- 143
      string.char( voice.lfo.pitch_mod_sensitivity ) .. -- 144
      string.char( voice.transpose ) .. -- 145
      string.sub( voice.name .. string.rep( " ", 10 ), 1, 10 ) -- 146-155
end -- encode_voice()


-- Pack the parameters of an FM operator for inclusion into a packed voice data record.
--
-- Parameters:
--  - op: a table with the operator's parameters. See decode_operator() and unpack_operator()
--    for the names of the parameters.
--
-- Returns:
--  - op_rec: a 17-octet string, the parameters of the operator as arranged in a packed voice 
--    data record.
function pack_operator( op ) -- -> op_rec
   return
      string.char( op.eg.rate[1] ) ..
      string.char( op.eg.rate[2] ) ..
      string.char( op.eg.rate[3] ) ..
      string.char( op.eg.rate[4] ) ..
      string.char( op.eg.level[1] ) ..
      string.char( op.eg.level[2] ) ..
      string.char( op.eg.level[3] ) ..
      string.char( op.eg.level[4] ) ..
      string.char( op.kbd_lev_scl.brk_pt ) ..
      string.char( op.kbd_lev_scl.lft_depth ) ..
      string.char( op.kbd_lev_scl.rht_depth ) ..
      string.char( 
         (op.kbd_lev_scl.lft_curve & 0x03) |
         ((op.kbd_lev_scl.rht_curve & 0x03) << 2) ) ..
      string.char( 
         (op.kbd_rate_scaling & 0x07) |
         ((op.osc.detune & 0x0F) << 3) ) ..
      string.char(
         (op.amp_mod_sensitivity & 0x03) |
         ((op.key_vel_sensitivity & 0x07) << 2) ) ..
      string.char( op.output_level ) ..
      string.char( 
         (op.osc.mode & 0x01) |
         ((op.osc.freq_coarse & 0x1F) << 1) ) ..
      string.char( op.osc.freq_fine )
end -- pack_operator()
         
      
-- Pack the parameters of a voice into a packed voice data record.
--
-- Parameters:
--  - voice: a table with the parameters of the voice. See decode_voice() and unpack_voice()
--    for the names of the parameters.
--
-- Returns:
--  - packed_rec: a 155-octet string, voice data record.
function pack_voice( voice ) -- -> packed_rec
   return
      pack_operator( voice.op[6] ) .. -- 1-17
      pack_operator( voice.op[5] ) .. -- 18-34
      pack_operator( voice.op[4] ) .. -- 35-51
      pack_operator( voice.op[3] ) .. -- 52-68
      pack_operator( voice.op[2] ) .. -- 69-85
      pack_operator( voice.op[1] ) .. -- 86-102
      string.char( voice.pitch_eg.rate[1] ) .. -- 103
      string.char( voice.pitch_eg.rate[2] ) .. -- 104
      string.char( voice.pitch_eg.rate[3] ) .. -- 105
      string.char( voice.pitch_eg.rate[4] ) .. -- 106
      string.char( voice.pitch_eg.level[1] ) .. -- 107
      string.char( voice.pitch_eg.level[2] ) .. -- 108
      string.char( voice.pitch_eg.level[3] ) .. -- 109
      string.char( voice.pitch_eg.level[4] ) .. -- 110
      string.char( voice.algo ) .. -- 111
      string.char( 
         (voice.feedback & 0x07) |
         ((voice.osc_sync & 0x01) << 3) ) .. -- 112
      string.char( voice.lfo.speed ) .. -- 113
      string.char( voice.lfo.delay ) .. -- 114
      string.char( voice.lfo.pitch_mod_depth ) .. -- 115
      string.char( voice.lfo.amp_mod_depth ) .. -- 116
      string.char( 
         (voice.lfo.sync & 0x01) |
         ((voice.lfo.waveform & 0x0F) << 1) |
         ((voice.lfo.pitch_mod_sensitivity & 0x03) << 5) ) .. -- 117
      string.char( voice.transpose ) .. --118
      string.sub( voice.name .. string.rep( " ", 10 ), 1, 10 ) -- 119-128
end -- pack_voice()
        
        
-- Calculate the checksum for the given sequence of octets:
function checksum( octets ) -- -> sum
   local sum
   
   sum = 0
   for i = 1, #octets do
      sum = sum + string.byte( octets, i )
   end
   return ((0x80 - (sum & 0x7F)) & 0x7F)
end -- checksum()


-- Extract the name of a program from the given voice data record.
--
-- Parameters:
--  - record: voice data record.
--
-- Returns:
--  - name: name of the program or nil if the program is unnamed.
function get_voice_name( record ) -- -> name
   local i
   
   i = 146 -- name field range 146-155 inclusive (length 10)
   while i <= 155 and string.byte( record, i ) ~= 0x00 do
      i = i + 1
   end
   if i > 146 then
      return trim( string.sub( record, 146, i - 1 ) )
   end
end -- get_voice_name()


-- Replace the name of a voice in the given voice data record.
--  - record: voice data record;
--  - name: new name of the voice.
--
-- Returns:
--  - record: the updated program data record.
function set_voice_name( record, name ) -- -> record
   if #record == 155 then
      -- Pad given name with whitespace, truncate to 10 characters:
      name = string.sub( name .. string.rep( " ", 10 ), 1, 10 )

      -- Name is stored in octets #146-155 inclusive:
      record = string.sub( record, 1, 145 ) .. name
   end
   return record
end -- set_voice_name()


-- Decode and verify a DX7 SysEx message payload.
--
-- Parameters:
--  - packed: octet string of the form "<msb><lsb><payload><sum>" where:
--     . <msg>, <lsb> are the most and least significant bits of the count of 
--       the number of bytes in <payload>;
--     . <payload> is the data to extract;
--     . <sum> is the data checksum.
--
-- Returns nothing if the payload size does not match the payload byte count,
-- or the checksum is incorrect, otherwise:
--  - payload: data extracted from the payload.
function decode_payload( packed ) -- -> payload
   local count, sum
   
   if #packed > 3 then -- there must be at least one payload byte
      count = (string.byte( packed, 1 ) << 7) | string.byte( packed, 2 )
      data = string.sub( packed, 3, -2 )
      sum = checksum( data )
      if count == #data and sum == string.byte( packed, -1 ) then
         return data
      end
   end
end -- decode_payload()


-- Encode a DX7 SysEx message payload, formatting it with checksum.
--
-- Parameters:
--  - payload: payload data to encode.
--
-- Returns:
--  - packed: octet string of the form "<msb><lsb><payload><sum>" where:
--     . <msg>, <lsb> are the most and least significant bits of the count of 
--       the number of bytes in <payload>;
--     . <payload> is the data as given on input;
--     . <sum> is the data checksum.
function encode_payload( payload ) -- -> packed
   local count, sum
   
   count = #payload
   sum = checksum( payload )
   
   return string.char( (count >> 7) & 0x7F ) .. string.char( count & 0x7F ) .. 
      payload .. string.char( sum )
end -- encode_payload()


-- Decode a BULK VOICE DATA DUMP message.
--
-- Parameters:
--  - msg: the message to decode.
--
-- Returns nothing if the message is the wrong length or the checksum is incorrect, 
-- otherwise:
--  - record: 155 octet string, the voice data record.
function decode_voice_bulk_data_dump( msg ) -- -> record
   if #msg == 163 then -- SysEx header, 155-octet payload, checksum & trailer
      return decode_payload( string.sub( msg, 5, -2 ) )
   end
end -- decode_voice_bulk_data_dump()


-- Decode a 32 VOICES BULK DATA DUMP message. Unpack the voice data record for each 
-- of the 32 voices in the bank.
--
-- Parameters:
--  - msg: message to decode
--
-- Returns nothing if the message is the wrong length or the checksum is incorrect,
-- otherwise:
--  - records: a list of 32 octet strings, each a voice data record for the corresponding
--    voice 1-32 in the message.
--
function decode_32_voice_bulk_data_dump( msg ) -- -> records
   local data, records, first, last, voice
   
   if #msg == 4104 then -- SysEx header + 4096 bytes + checksum + trailer
      data = decode_payload( string.sub( msg, 5, -2 ) )
      if type( data ) == "string" then 
         -- valid payload, good checksum
         records = {}
         for i = 1, 32 do
            last = i * 128
            first = last - 127
            packed_rec = string.sub( data, first, last )
            voice = unpack_voice( packed_rec )               
            records[i] = encode_voice( voice )
         end
         return records
      end
   end
end -- decode_32_voice_bulk_data_dump()


-- Encode a voice bulk data dump message from the given voice data record.  If
-- a new name is given for the voice, the name will be used to construct
-- the message, otherwise the exising name in the given voice data record will
-- be used.
--
-- Parameters:
--  - records: a list of one 155 octet string, the voice data record.
--  - header: SysEx header for the message.
--  - name: optional voice name.
--
-- Returns:
--  - msgs: list of one octet string, encoded message.
function encode_voice_bulk_data_dump( records, header, name ) -- -> msgs
   local record
   
   record = records[1]
   if #records ~= 1 or type( record ) ~= "string" or #record ~= 155 then
      print( "DX7 encode_voice_bulk_data_dump(): invalid records argument")
      return nil
   end
   if type( name ) == "string" then
      record = set_voice_name( record, name )
   end
   return { header .. string.char( 0x00 ) .. encode_payload( record ) .. string.char( 0xF7 ) }
end -- encode_voice_bulk_data_dump()


-- MODULE FUNCTIONS:
local model = {}


function model.info()
   return {
      specification = 2,
      name = "Yamaha DX7",
      source = "Old Blue Bike Software inc.",
      version = "0.1",
      icon = "*.png", -- look for file with same path as this file with '.png' appended
      manufacturer = "43",
      family = "00 00", -- undefined by Yamaha, assigned by MMD
      member = "00 01", -- undefined by Yamaha, assigned by MMD
      probe = "none",
      unit_first = 0,
      unit_last = 15,
      unit_factory = 0,
      slots = 32,
      writable_slots = "", -- stored program slots must be written all 32 at once, unsupported
      timeout = 500,
      notes = 
         "This is an alpha implementation of the MMD for the Yamaha DX7. Testing has so\n" ..
         "far been very limited: offers for help to test interoperation with an actual\n" ..
         "device are most welcome. Please contact 'support@oldbluebike.com'.\n" ..
         "\n" ..
         "The DX7 provides commands to dump its programs (Yamaha calls them 'voices') which the\n" ..
         "user can initiate manually from its panel. There is no method to initiate SysEx dumps\n" ..
         "remotely via MIDI. The BULK VOICE DATA DUMP command causes the DX7 to transmit the\n" ..
         "currently-active program from its edit buffer; a 32-VOICE BULK DATA DUMP command\n" ..
         "transmits all 32 stored programs from the DX7's persistent memory. This MMD extracts\n" ..
         "individual programs from the DX7's SysEx dumps, and can thereafter construct the\n" ..
         "SysEx messages to restore any of the captured programs back to its edit buffer.\n" }
end -- model.info()


function model.decode( msgs ) -- -> records
   local header, records, ident, msg, record, name, voices

   if type( msgs ) ~= "table" or #msgs == 0 then
      print( "DX7 decode(): invalid msgs argument" )
      return nil -- invalid argument
   end

   header = midi.hex_to_octets( "F0 43" )
   records = {}
   for i = 1, #msgs do
      msg = msgs[i]

      if type( msg ) == "string" and #msg >= 6 and
         string.sub( msg, 1, 2 ) == header and 
         string.byte( msg, 3 ) & 0xF0 == 0 and
         string.byte( msg, -1 ) == 0xF7 then
         -- Valid DX7 SysEx message:
         ident = string.byte( msg, 4 )
         
         if ident == 0x00 then
            -- BULK VOICE DATA DUMP message:
            record = decode_voice_bulk_data_dump( msg )
            if type( record ) == "string" then
               records[#records + 1] = "program:0"
               name = get_voice_name( record )
               if type( name ) == "string" then
                  records[#records + 1] = "name:" .. name
               end
               records[#records + 1] = "data:" .. record
            end

         elseif ident == 0x09 then
            -- 32 VOICES BULK DATA DUMP message:
            voices = decode_32_voice_bulk_data_dump( msg )
            if type( voices ) == "table" then
               for slot = 1, #voices do                  
                  record = voices[slot]
                  if type( record ) == "string" then
                     name = get_voice_name( record )
                     records[#records + 1] = "program:" .. slot
                     if type( name ) == "string" then                        
                        records[#records + 1] = "name:" .. name
                     end
                     records[#records + 1] = "data:" .. record
                  end
               end
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
      print( "DX7 load_program_command(): invalid records argument")
      return nil -- invalid argument
   end
   
   if slot == nil or slot == 0 then
      return encode_voice_bulk_data_dump( records, header, name )
   else
      print( "DX7 load_program_command(): invalid slot argument")
   end  
end -- model.load_program_command()


return model


-- EOF dx7.lua
