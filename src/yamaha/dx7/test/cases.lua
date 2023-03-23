-- cases.lua
--
-- Test suite for the Yamaha DX7 MMD. 
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
--  - all-programs-dump.syx: dump of all 32 programs;
--  - voice-N-dump.syx: dump of individual stored program N.

return {
   { -- #1
      config = { unit = 0 },
      item = "program",
      slot = 0,
      dump = "voice-1-dump.syx",
   },
   { -- #2
      config = { unit = 0 },
      item = "program",
      slot = 0,
      dump = "voice-5-dump.syx",
   },
   { -- #3
      config = { unit = 0 },
      item = "program",
      slot = 0,
      dump = "voice-11-dump.syx",
   },
   { -- #4
      config = { unit = 0 },
      item = "program",
      slot = 0,
      dump = "voice-18-dump.syx",
   },
   { -- #5
      config = { unit = 0 },
      item = "program",
      slot = 0,
      dump = "voice-23-dump.syx",
   },
   { -- #6
      config = { unit = 0 },
      item = "program",
      slot = 0,
      dump = "voice-32-dump.syx",
   },

   { -- #7
      config = { unit = 0 },
      item = "program",
      slot = 1,
      dump = "all-programs-dump.syx",
      load = "voice-1-dump.syx",
      load_slot = 0 -- DX7 can only load individual program to edit buffer
   },
   { -- #8
      config = { unit = 0 },
      item = "program",
      slot = 10,
      dump = "all-programs-dump.syx",
      load = "voice-10-dump.syx",
      load_slot = 0 -- DX7 can only load individual program to edit buffer
   },
   { -- #9
      config = { unit = 0 },
      item = "program",
      slot = 22,
      dump = "all-programs-dump.syx",
      load = "voice-22-dump.syx",
      load_slot = 0 -- DX7 can only load individual program to edit buffer
   },
   { -- #10
      config = { unit = 0 },
      item = "program",
      slot = 29,
      dump = "all-programs-dump.syx",
      load = "voice-29-dump.syx",
      load_slot = 0 -- DX7 can only load individual program to edit buffer
   },
   { -- #11
      config = { unit = 0 },
      item = "program",
      slot = 32,
      dump = "all-programs-dump.syx",
      load = "voice-32-dump.syx",
      load_slot = 0 -- DX7 can only load individual program to edit buffer
   },
}

  
-- EOF cases.lua
