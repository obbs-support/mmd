-- cases.lua
--
-- Test suite for the Sequential Prophet 6 MMD.
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

-- REQUIRED TEST DATA FILES:
--
-- This test suite uses test data in SysEx files that must be obtained 
-- (dumped) from an actual device:
--  - edit-buffer-dump.syx: dump of active program (as acquired by sending
--    the SysEx command in edit-buffer-dump-request.syx to the Prophet-6);
--  - program-N-dump.syx: dump of stored program #N (as acquired by sending
--    the SysEx command in program-N-dump-request.syx to the Prophet-6);
--  - globals-dump.syx: dump of the settings in SysEx format (as acquired 
--    by sending the SysEx command in globals-dump-request.syx to the 
--    Prophet-6);
--
-- "globals-dump.midi" is a sequence of MIDI CC messages that one would 
-- transmit to the Prophet-6 in order to restore the globals acquired via SysEx
-- dump. The Prophet-6 encapsulates and dumps its global parameters in a SysEx 
-- message when commanded, but does not handle this SysEx message. Instead 
-- the parameters must be restored individually via MIDI CC messages.

return {
   { -- #1
      config={ unit = 0x7F },
      item = "program",
      slot = 0,
      command = "edit-buffer-dump-request.syx",
      dump = "edit-buffer-dump.syx"
   },
   { -- #2
      config={ unit = 0x7F },
      item = "program",
      slot = 1,
      command = "program-1-dump-request.syx",
      dump = "program-1-dump.syx"
   },
   { -- #3
      config={ unit = 0x7F },
      item = "program",
      slot = 500,
      command = "program-500-dump-request.syx",
      dump = "program-500-dump.syx"
   },
   { -- #4
      config={ unit = 0x7F },
      item = "program",
      slot = 1000,
      command = "program-1000-dump-request.syx",
      -- slots 501-1000 are factory programs and are read-only.
   },
   { -- #5
      -- Prophet 6 dumps globals in SysEx format, but globals must be
      -- set via MIDI CC messages only:
      config={ unit = 0x7F },
      item = "globals",
      globals = "Settings",
      command = "globals-dump-request.syx",
      dump = "globals-dump.syx",
      load = "globals-dump.midi"
   }
}


-- EOF cases.lua
      

   