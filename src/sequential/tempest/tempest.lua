-- tempest.lua
--
-- MIDI Model Description (MMD) for Dave Smith Instruments / Roger Linn Tempest
-- Analog Drum Machines.
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


-- MIDI MODEL DESCRIPTION (MMD) for the Dave Smith Instruments / Roger Linn Tempest
-- ================================================================================
-- 
-- Little is known of the MIDI SysEx implementation in the Tempest drum machine,
-- as DSI never published a proper MIDI implementation chart for this device. 
-- It appears that the Tempest cannot be remotely commanded to perform MIDI 
-- SysEx dumps. However the Save/Load menu that is accessible from the 
-- instrument offers options to perform the following dumps:
--  - transmit a single sound from the current project;
--  - transmit a single beat from the current project;
--  - transmit the entire current project;
--  - transmit a file from persistent storage (which can be a sound, a beat or
--    an entire project).
--
-- This interface module provides the functions to decode the messages from
-- an entire project received from the edit buffer, and encode same to restore
-- into the edit buffer. 
--
-- MIDI ports:
-- -----------
--
-- The Tempest doest not have the option to set a unit identifier / global MIDI
-- channel, and does not have a MIDI Thru port.
--
-- Identification:
-- ---------------
--
-- The Tempest does *not* respond to the standard device inquiry IDENTITY REQUEST
-- message and thus cannot be automatically detected by controllers.
--
-- Inspection of the messages that the Tempest does transmit in SysEx dumps reveals
-- every message starting with the following header, with our educated guess as to
-- its meaning:
--
--                                        F0 01 28 tt ...
--                                           -- -- --
--                                            |  |  |
--          Manufacturer ID (DSI/Sequential) -+  |  |
--                                               |  |
--                          Family ID (Tempest) -+  |
--                                                  |
--                                 Message type ----+
--
-- The following message type codes and message counts are observed depending on the
-- type of dump that is commanded from the instrument (main O/S ver. 1.5.0.2):
--  - 0x60: sound (1 message, 157 bytes);
--  - 0x5F: beat (1 message, 8197 bytes);
--  - 0x5E: project info (1 message);
--  - 0x5C: project beat (16 messages, 8198 bytes each).
--
-- A dump of the project in the edit buffer generates a sequence of one (1) project 
-- info message following by 16 beat messages):
--  - the payload of the project info message (starting a the 5th byte of the message)
--    is in packed MSB format. The project name appears at the 69th to 88th unpacked bytes,
--    inclusive (20 ASCII characters);
--  - the payload of the beat messages is in format "<idx><data>" where:
--     . <idx> is the beat number (0-15);
--     . <data> is the beat information in packed MSB format. The long name of the beat
--       appears at the 25th to 44th bytes of the unpacked data (20 ASCII characters) and
--       the short name at the 45th to 52th bytes (8 ASCII characters).


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


-- Make a SysEx message header (common to all messages):
function get_header()
   return midi.hex_to_octets( "F0 01 28" )
end -- get_header()


-- Extract the name of a project from the given project information record.
--
-- Parameters:
--  - record: octet string of the form "<tag><data>" where <tag> is 0x00 and indicates
--    that this is a project information record, and <data> is the project information.
--
-- Returns:
--  - name: name of the project or nil if the project is unnamed.
function get_project_name( record )
   if type( record ) == "string" and #record > 90 and string.byte( record, 1 ) == 0x00 then
      return trim(string.sub( record, 70, 89 ))
   end
end -- get_project_name()


-- Update the name of the project in a project information record. Substitute unsupported 
-- characters with underscores (which the Tempest supports) and pad result with whitespaces
-- to 20 characters.
--
-- Parameters:
--  - record: octet string of the form "<tag><data>" where <tag> is 0x00 and indicates
--    that this is a project information record, and <data> is the project information.
--
-- Returns:
--  - record: project information record with updated name.
function set_project_name( record, name )
   local alphabet, filtered

   alphabet = " ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789!\"#$%&'()+,-.;=@[]^_`{}"
   filtered = ""
   for i = 1, #name do
      c = string.sub( name, i, i )
      if string.find( alphabet, c ) == nil then
         c = '_'
      end
      filtered = filtered .. c
   end
   filtered = string.sub( filtered .. string.rep( " ", 20 ), 1, 20 )
   return string.sub( record, 2, 69 ) .. filtered .. string.sub( record, 90 )
end -- set_project_name()


-- Decode a project dump message.
--
-- Parameters:
--  - msg: message to decode.
--
-- Returns:
--  - record: octet string of the form "<tag><data>" where <tag> is 0x00 and indicates
--    that this is a project information record, and <data> is the project information.
function decode_project_info_dump( msg ) -- -> record
   if #msg >= 6 then
      return string.char( 0x00 ) .. midi.unpack( string.sub( msg, 5, -2 ) )
   end
end -- decode_project_info_dump()


-- Decode a beat dump message.
--
-- Parameters:
--  - msg: message to decode.
--
-- Returns:
--  - record: octet string of the form "<tag><idx><data>" where <tag> is 0x01 and
--    indicates that this is a beat record, <idx> is the beat number (0-15) <data> is 
--    the beat information.
function decode_beat_dump( msg ) -- -> record
   local idx, data
   
   if #msg >= 6 then
      idx = string.byte( msg, 5 )
      data = midi.unpack( string.sub( msg, 6, -2 ) )   
      if idx <= 0x0F then
         return string.char( 0x01 ) .. string.char( idx ) .. data
      end
   end
end -- decode_beat_dump()


-- Encode messages to restore project information and beats into the Tempest's edit 
-- buffer. If a new name is given for the project and the given record list includes a
-- project information record, the name will be used to construct the messages. 
-- Otherwise the exising name in the given project information record will be used.
--
-- Parameters:
--  - records: list of octet strings of the form "<tag><data>" where <tag>
--    (first byte) is coded as 0x00 to indicates a project information record, or
--    0x01 for a beat record, and <data> (byte 2 onwards) is the corresponding data.
--  - header: SysEx header for the message;
--  - name: optional project name.
--
-- Returns:
--  - msgs: list of octet strings, encoded messages.
function encode_active_project_dump( records, header, name ) -- -> msgs
   local record, msgs, idx, data
   
   msgs = {}
   for i = 1, #records do
      record = records[i]
      if type( record ) ~= "string" or #record < 3 then
         print( "Tempest encode_active_project_dump(): invalid records argument" )
         return nil -- invalid argument
      end
      ident = string.byte( record, 1 )
      if ident == 0x00 then
         data = string.sub( record, 2 )
         if type( name ) == "string" then
            record = set_project_name( record, name )
         end
         msgs[i] = header .. string.char( 0x5E ) .. midi.pack( data ) .. string.char( 0xF7 ) 
      elseif ident == 0x01 and string.byte( record, 2 ) <= 0x0F then
         idx = string.byte( record, 2 )
         data = string.sub( record, 3 )
         msgs[i] = header .. string.char( 0x5C ) .. string.char( idx ) .. midi.pack( data ) .. 
            string.char( 0xF7 )
      else
         print( "Tempest encode_active_project_dump(): invalid records argument" )
         return nil -- invalid argument
      end
   end   
   return msgs
end -- encode_active_project_dump()

-- MODULE FUNCTIONS:
local model = {}


function model.info()
   return {
      specification = 2,
      name = "DSI Tempest",
      source = "Old Blue Bike Software inc.",
      version = "2.1",
      icon = "*.png", -- look for file with same path as this file with '.png' appended
      manufacturer = "01",
      family = "28 01",
      probe = "none",
      timeout = 200,
      notes =
         "This MMD applies to the Dave Smith / Roger Linn Tempest Analog Drum Machine\n"..
         "\n"..
         "A program for the Tempest is what the Tempest calls a 'project'. Support is\n"..
         "currently limited as follows:\n"..
         " - no MIDI port sharing: the Tempest does not have a MIDI Thru port, and does not\n"..
         "   use unit numbers;\n"..
         " - no MIDI SysEx dump commands: all SysEx dumps must be manually initiated by the\n"..
         "   user from Tempest's 'Save/Load' menu;\n"..
         " - full project import/export only: a program is a complete Tempest project (16\n"..
         "   beats of 32 sounds each, and a playlist);\n"..
         " - no Tempest SysEx files, only projects exported from the Tempest via MIDI.\n"..
         "\n"..
         "To capture a program from the Tempest:\n"..
         " 1) on the Tempest, create the desired sounds/beats/playlist, or load an\n"..
         "    existing project file ('Save/Load' button -> 'Load File (Sound/Beat/\n"..
         "    Project)' and choose a project file to load);\n"..
         " 2) when ready to capture, initiate a SysEx dump of the active program ('Save/\n"..
         "    Load' button -> 'Export Project over MIDI').\n" }
end -- model.info()


function model.decode( msgs ) -- -> records
   local header, records, msg, ident, record, name, slot

   if type( msgs ) ~= "table" or #msgs == 0 then
      print( "Tempest decode(): invalid msgs argument")
      return nil -- invalid argument
   end

   header = get_header()
   records = {}
   for i = 1, #msgs do
      msg = msgs[i]

      if type( msg ) == "string" and #msg >= 8 and
         string.sub( msg, 1, 3 ) == header and 
         string.byte( msg, -1 ) == 0xF7 then
         -- Valid Prophet 12 SysEx message:
         ident = string.byte( msg, 4 )
         
         if ident == 0x5E then
            record = decode_project_info_dump( msg )
            if type( record ) == "string" then
               records[#records + 1] = "program:0"
               name = get_project_name( record )
               if type( name ) == "string" then
                  records[#records + 1] = "name:" .. name
               end
               records[#records + 1] = "data:" .. record
            end
            
         elseif ident == 0x5C then
            record = decode_beat_dump( msg )
            if type( record ) == "string" then
               records[#records + 1] = "data:" .. record
            end
         end
      end
   end
   
   return records
end -- model.decode()


function model.load_program_command( config, records, slot, name ) -- -> msgs
   local header

   if type( records ) ~= "table" or #records == 0 then
      print( "DeepMind12 load_program_command(): invalid records argument")
      return nil -- invalid argument
   end
   
   header = get_header()

   if slot == nil or slot == 0 then
      return encode_active_project_dump( records, header, name )
   elseif type( slot ) == "number" and slot >= 1 and slot <= 1024 then
      return encode_program_dump( records, header, slot, name )
   else
      print( "DeepMind12 load_program_command(): invalid slot argument")
   end  

   if type( msgs ) == "table" then
      return msgs
   end
end -- model.load_program_command()


return model


-- EOF tempest.lua
