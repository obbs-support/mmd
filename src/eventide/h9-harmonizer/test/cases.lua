-- cases.lua
--
-- Test suite for the Eventide H9 Harmonizer Pedal MMD.
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
--    the SysEx command in edit-buffer-dump-request.syx to the H9);
--  - presets-dump.syx: dump of all 99 presets (as acquired by sending
--    the SysEx command in presets-dump-request.syx to the H9);
--  - preset-N-dump.syx: dump of preset #N (each must be manually 
--    extracted from a full presets dump since the H9 does not have the
--    ability to dump just one individual preset);
--  - system-dump.syx: dump of system settings (as acquired by sending the 
--    SysEx command in system-dump-request.syx to the H9).

return {
   { -- #1
      config={ unit = 1 },
      item = "program",
      slot = 0,
      command = "edit-buffer-dump-request.syx",
      dump = "edit-buffer-dump.syx"
   },
   { -- #2
      config={ unit = 1 },
      item = "program",
      slot = 1,
      command = "presets-dump-request.syx",
      dump = "presets-dump.syx",
      load = "preset-1-dump.syx"
   },
   { -- #3
      config={ unit = 1 },
      item = "program",
      slot = 99,
      command = "presets-dump-request.syx",
      dump = "presets-dump.syx",
      load = "preset-99-dump.syx"
   },
   { -- #4
      config={ unit = 1 },
      item = "globals",
      globals = "System",
      command = "system-dump-request.syx",
      dump = "system-dump.syx"
   }
}


-- EOF cases.lua
