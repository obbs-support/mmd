-- cases.lua
--
-- Test suite for the Roland JV-35/50 Expandable Synthesizer MMD.
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
--  - edit-buffer-dump.syx: dump of active performance / program (as 
--    acquired by sending the SysEx commands in edit-buffer-dump-request.syx
--    to the JV-35/50; also see note below).
--  - perf-N-dump.syx: dump of stored performance / program #N (as 
--    acquired by sending the SysEx commands in perf-N-dump-request.syx
--    to the JV-35/50; also see note below).
--  - user-tones-dump.syx: dump of the user tones (as acquired by sending 
--    the SysEx commands in user-tones-dump-request.syx to the JV-35/50);
--  - user-drums-dump.syx: dump of the user drums (as acquired by sending 
--    the SysEx commands in user-drums-dump-request.syx to the JV-35/50).
--
-- JV-35/50s that are equipped with a VE-JV1 expansion board require an 
-- additional SysEx message to "reset" the VE-JV1 following a restore of 
-- performance parameters, as follows:
--
--     F0 41 10 4D 12 5F 00 00 00 21 F7
-- 
-- This parameter address "5F 00 00" is undocumented in the MIDI implementation
-- of both the JV-35/50 and VE-JV1, but writing to it appears to trigger a 
-- transfer of the parameter memory to the VE-JV1, and a reset of its voice 
-- engine, so the new parameters take effect (any information on this welcome).

return {
   { -- #1
      config={ unit = 16 },
      item = "program",
      slot = 0,
      command = "edit-buffer-dump-request.syx",
      dump = "edit-buffer-dump.syx"
   },
   { -- #2
      config={ unit = 16 },
      item = "program",
      slot = 1,
      command = "perf-1-dump-request.syx",
      dump = "perf-1-dump.syx"
   },
   { -- #3
      config={ unit = 16 },
      item = "program",
      slot = 3,
      command = "perf-3-dump-request.syx",
      dump = "perf-3-dump.syx"
   },
   { -- #4
      config={ unit = 16 },
      item = "program",
      slot = 8,
      command = "perf-8-dump-request.syx",
      dump = "perf-8-dump.syx"
   },
   { -- #5
      config={ unit = 16 },
      item = "globals",
      globals = "User Tones",
      command = "user-tones-dump-request.syx",
      dump = "user-tones-dump.syx"
   },
   { -- #6
      config={ unit = 16 },
      item = "globals",
      globals = "User Drums",
      command = "user-drums-dump-request.syx",
      dump = "user-drums-dump.syx"
   }   
}

  
-- EOF cases.lua
      

   