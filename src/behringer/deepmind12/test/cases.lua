-- cases.lua
--
-- Test suite for the Behringer Deepmind 12 MMD.
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
--  - edit-buffer-dump.syx: dump of active program (acquire by sending
--    the SysEx command in edit-buffer-dump-request.syx to the DM12);
--  - program-N-dump.syx: dump of stored program #N (acquire by sending
--    the SysEx command in program-N-dump-request.syx to the DM12);
--  - settings-dump.syx: dump of the settings (acquire by sending
--    the SysEx command in settings-dump-request.syx to the DM12);
--  - chords-dump.syx: dump of the chords memory (acquire by sending
--    the SysEx command in chords-dump-request.syx to the DM12);
--  - polychords-dump.syx: dump of the polychords memory (acquire by 
--    sending the SysEx command in polychords-dump-request.syx to the 
--    DM12);
--  - patterns-dump.syx: dump of the sequencer patterns (acquire by 
--    sending the SysEx commands in patterns-dump-request.syx to the 
--    DM12);
--  - calibration-dump.syx: dump of the calibration data (acquire by
--    sending the SysEx commands in calibration-dump-request.syx to the 
--    DM12).

return {
   { -- #1
      config={ unit = 0 },
      item = "program",
      slot = 0,
      command = "edit-buffer-dump-request.syx",
      dump = "edit-buffer-dump.syx"
   },
   { -- #2
      config={ unit = 0 },
      item = "program",
      slot = 1,
      command = "program-1-dump-request.syx",
      dump = "program-1-dump.syx"
   },
   { -- #3
      config={ unit = 0 },
      item = "program",
      slot = 1024,
      command = "program-1024-dump-request.syx",
      dump = "program-1024-dump.syx"
   },
   { -- #4
      config={ unit = 0 },
      item = "globals",
      globals = "Settings",
      command = "settings-dump-request.syx",
      dump = "settings-dump.syx"
   }, 
   { -- #5
      config={ unit = 0 },
      item = "globals",
      globals = "Chords",
      command = "chords-dump-request.syx",
      dump = "chords-dump.syx"
   }, 
   { -- #6
      config={ unit = 0 },
      item = "globals",
      globals = "Poly Chords",
      command = "polychords-dump-request.syx",
      dump = "polychords-dump.syx"
   }, 
   { -- #7
      config={ unit = 0 },
      item = "globals",
      globals = "Sequencer Patterns",
      command = "patterns-dump-request.syx",
      dump = "patterns-dump.syx"
   }, 
   { -- #8
      config={ unit = 0 },
      item = "globals",
      globals = "Calibration",
      command = "calibration-dump-request.syx",
      dump = "calibration-dump.syx"
   } 
}


-- EOF cases.lua
      

   