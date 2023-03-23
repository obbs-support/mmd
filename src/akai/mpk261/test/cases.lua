-- cases.lua
--
-- Test suite for the Akai MPK261 MMD.
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
--  - edit-buffer-dump.syx: dump of active program (as obtained by sending
--    the SysEx commands in edit-buffer-dump-request.syx);
--  - globals-dump.syx: dump of the globals (as obtained by sending the 
--    SysEx commands in globals-dump-request.syx).

return {
   { -- #1
      item = "program",
      slot = 0,
      command = "edit-buffer-dump-request.syx",
      dump = "edit-buffer-dump.syx"
   },
   { -- #2
      item = "globals",
      globals = "Settings",
      command = "globals-dump-request.syx",
      dump = "globals-dump.syx"
   }
}

  
-- EOF cases.lua
      

   