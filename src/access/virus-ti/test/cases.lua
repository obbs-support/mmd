-- cases.lua
--
-- Test suite for the Access Virus TI MMD.
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
--  - edit-buffer-dump.syx: dump of both single- and multi-mode parts of
--    the edit buffer (as acquired by sending the SysEx command in 
--    edit-buffer-dump-request.syx to the Virus TI);
--  - all-banks-dump.syx: dump of all stored program banks (as acquired
--    by sending the SysEx commands in all-banks-dump-request.syx to the
--    Virus TI);
--  - program-NNN-dump.syx: dump of stored program slot #NNN (1 message
--    for single-mode program; 17 messages for multi-mode program, 
--    including the 16 parts referenced by the multi-mode program record,
--    must be extracted manually from all-banks-dump.syx because the 
--    Virus TI does not have a command to dump only one stored program);
--  - program-NNN-edit-buffer-dump.syx: dump of the edit buffer containing 
--    stored program #NNN (17 messages for multi-mode program, including 
--    the 16 parts referenced by the multi-mode program record).

return {
   { -- #1
      config={ unit = 14 },
      item = "program",
      slot = 0,
      command = "edit-buffer-dump-request.syx",
      dump = "edit-buffer-dump.syx"
   },   
   { -- #2
      config={ unit = 14 },
      item = "program",
      slot = 129,
      command = "program-129-dump-request.syx",
      dump = "program-129-dump.syx",
   },
   { -- #3
      config={ unit = 14 },
      item = "program",
      slot = 192,
      command = "program-192-dump-request.syx",
      dump = "all-banks-dump.syx",
      load = "program-192-dump.syx"
   },
   { -- #4
      config={ unit = 14 },
      item = "program",
      slot = 256,
      command = "program-256-dump-request.syx",
      dump = "program-256-dump.syx"
   },
   { -- #5
      config={ unit = 14 },
      item = "program",
      slot = 304,
      command = "program-304-dump-request.syx",
      dump = "all-banks-dump.syx",
      load = "program-304-dump.syx"
   },
   { -- #6
      config={ unit = 14 },
      item = "program",
      slot = 384,
      command = "program-384-dump-request.syx",
      dump = "program-384-dump.syx"
   },
   { -- #7
      config={ unit = 14 },
      item = "program",
      slot = 487,
      command = "program-487-dump-request.syx",
      dump = "all-banks-dump.syx",
      load = "program-487-dump.syx"
   },
   { -- #8
      config={ unit = 14 },
      item = "program",
      slot = 640,
      command = "program-640-dump-request.syx",
      dump = "all-banks-dump.syx",
      load = "program-640-dump.syx"
   },
   { -- #9
      config={ unit = 14 },
      item = "program",
      slot = 1,
      command = "program-1-dump-request.syx",
      dump = "program-1-dump.syx",
   },
   { -- #10
      config={ unit = 14 },
      item = "program",
      slot = 13,
      command = "program-13-dump-request.syx",
      dump = "program-13-dump.syx"
   },
   { -- #11
      config={ unit = 14 },
      item = "program",
      slot = 13,
      command = "program-13-dump-request.syx",
      dump = "all-banks-dump.syx",
      load = "program-13-edit-buffer-dump.syx",
      load_slot = 0
   },
   { -- #12
      config={ unit = 14 },
      item = "program",
      slot = 16,
      command = "program-16-dump-request.syx",
      dump = "all-banks-dump.syx",
      load = "program-16-dump.syx"
   },
   { -- #13
      config={ unit = 14 },
      item = "program",
      slot = 17,
      command = "all-banks-dump-request.syx",
      dump = "all-banks-dump.syx",
      load = "program-17-edit-buffer-dump.syx",
      load_slot = 0
   },
   { -- #14
      config={ unit = 14 },
      item = "program",
      slot = 128,
      command = "all-banks-dump-request.syx",
      dump = "all-banks-dump.syx",
      load = "program-128-edit-buffer-dump.syx",
      load_slot = 0
   }
}


-- EOF cases.lua
