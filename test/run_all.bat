@echo off

rem run_all.bat
rem
rem Copyright (C) 2021-2023, Old Blue Bike Software Inc.
rem
rem Permission is hereby granted, free of charge, to any person obtaining
rem a copy of this software and associated documentation files (the
rem "Software"), to deal in the Software without restriction, including
rem without limitation the rights to use, copy, modify, merge, publish,
rem distribute, sublicense, and/or sell copies of the Software, and to
rem permit persons to whom the Software is furnished to do so, subject to
rem the following conditions:
rem 
rem The above copyright notice and this permission notice shall be included
rem in all copies or substantial portions of the Software.
rem 
rem THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
rem EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
rem MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
rem IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
rem CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
rem TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
rem SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

rem Run the regression test suite of every MMD in the repository:

set EXEC_DIR_PATH=%~dp0
set EXEC_DIR_PATH=%EXEC_DIR_PATH:~0,-1%
cd %EXEC_DIR_PATH%

lua verify.lua -s ../src/access/virus-ti -- virus-ti

lua verify.lua -s ../src/akai/mpk261 -- mpk261

lua verify.lua -s ../src/behringer/deepmind12 -- deepmind12

lua verify.lua -s ../src/eventide/h9-harmonizer -- h9-harmonizer

lua verify.lua -s ../src/korg/electribe2 -- electribe2
lua verify.lua -s ../src/korg/minilogue -- minilogue
lua verify.lua -s ../src/korg/miniloguexd -- miniloguexd
lua verify.lua -s ../src/korg/monologue -- monologue
lua verify.lua -s ../src/korg/prologue -- prologue

lua verify.lua -s ../src/roland/jv35-50 -- jv35-50
lua verify.lua -s ../src/roland/rd2000 -- rd2000

lua verify.lua -s ../src/sequential/ob6 -- ob6
lua verify.lua -s ../src/sequential/pro2 -- pro2
lua verify.lua -s ../src/sequential/prophet6 -- prophet6
lua verify.lua -s ../src/sequential/prophet08 -- prophet08
lua verify.lua -s ../src/sequential/prophet08se -- prophet08se
lua verify.lua -s ../src/sequential/prophet12 -- prophet12
lua verify.lua -s ../src/sequential/rev2 -- rev2
lua verify.lua -s ../src/sequential/tempest -- tempest

lua verify.lua -s ../src/yamaha/dx7 -- dx7
