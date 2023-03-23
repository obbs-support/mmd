-- kit.lua
--
-- Copyright (C) 2021, Old Blue Bike Software Inc.
--
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


-- MODULE DEFINITION:
kit={}


function kit.list( records )
   local record, pos, tag, value
   
   if type( records ) ~= "table" then
      return nil
   end
   for i = 1, #records do
      record = records[i]
      if type( record ) == "string" then
         pos = string.find( record, ":" )
         tag = string.sub( record, 1, pos )
         if tag == "data:" then
            value = string.sub( record, pos + 1 )
            print( tag .. midi.octets_to_hex( value ) )
         else
            print( record )
         end
      else
         printf( "INVALID" )
      end
   end
end -- kit.list()


function kit.extract( records, item ) -- -> xtract, name
   local pos, kind, xtract, i, record, tag, value, name
   
   if type( records ) ~= "table" or type( item ) ~= "string" then
      return nil
   end
   
   pos = string.find( item, ":" )
   if type( pos ) ~= "number" then
      return nil
   end
   kind = string.sub( item, 1, pos )

   xtract = {}
   i = 1
   while i <= #records do
      if type( records[i] ) ~= "string" then
         return nil
      elseif records[i] == item then
         break
      end
      i = i + 1
   end
   i = i + 1
   
   while i <= #records do 
      record = records[i]
      if type( record ) ~= "string" then
         return nil
      end
      pos = string.find( record, ":" )
      if type( pos ) ~= "number" then
         return nil
      end
      
      tag = string.sub( record, 1, pos )
      value = string.sub( record, pos + 1 )
      if tag == "data:" then
         xtract[#xtract + 1] = value
      elseif tag == "name:" then
         name = value
      elseif tag == "program:" or tag == "globals:" then
         break
      end -- ignore unrecognized tags
      i = i + 1
   end

   return xtract, name
end -- kit.extract()


return kit;


-- EOF kit.lua
