-- vim: ts=2 sw=2 sts=2 et :
-- # Lib.lua
-- Misc library routines.   
-- (c) 2021 Tim Menzies (timm@ieee.org) unlicense.org

-- Create
local Lib={}

-- ## Options
function Lib.the(  new)
  new=Lib.copy( require("about") )
  Lib.seed(new.seed)
  return new end

-- ## Maths 
-- Constants
Lib.e = math.exp(1)
Lib.pi = math.pi

-- Round
function Lib.round(num, numDecimalPlaces,      mult)
  mult = 10^(numDecimalPlaces or 0)
  return math.floor(num * mult + 0.5) / mult end

function Lib.rs(t,r)
  return Lib.map(t, function (z) return Lib.round(z,r or 2) end) end

-- ## Printing  
-- String formatting
function Lib.fmt (todo, ...)
  return todo:format(...) end

function Lib.say (todo, ...)
  return print(todo:format(...)) end

-- Concat one table
function Lib.cat(t,sep) return table.concat(t,sep or ", ") end

-- Show the print string.
function Lib.o(t,pre) print(Lib.oo(t,pre))  end

-- Convert a table to a print string.
function Lib.oo(t,pre,     seen,s,sep,keys, nums,v)
  seen = seen or {}
  if seen[t] then return "..." end
  pre=pre or ""
  seen[t] = true
  if type(t) ~= "table" then return tostring(t) end
  s, sep, keys, nums = '','', {}, true
  for k, v in pairs(t) do 
    if not (type(v) == 'function') then
      if not (type(k)=='string' and k:match("^_")) then
        nums = nums and type(k) == 'number'
        keys[#keys+1] = k  end end end 
  --table.sort(keys)
  for _, k in pairs(keys) do
    v = t[k]
    if      type(v) == 'table'    then v= Lib.oo(v,pre,seen) 
    elseif  type(v) == 'function' then v= "function"
    else v= tostring(v) end
    if nums
    then s = s .. sep .. v
    else s = s .. sep .. tostring(k) .. '=' .. v end
    sep = ', ' end 
  return tostring(pre) .. '{' .. s ..'}' end

-- ## Files
-- Iterate over the records in a csv file.
function Lib.csv(file,     stream,tmp,str,row)
  stream = file and io.input(file) or io.input()
  tmp    = io.read()
  return function()
    if tmp then
      str = tmp:gsub("[\t\r ]*",""):gsub("#.*","")
      row = {}
      for cell in str:gmatch("([^,]+)") do 
        row[#row+1] = Lib.coerce(cell) end
      tmp= io.read()
      if #row > 0 then return row end
    else
      io.close(stream) end end   
end

-- ## Random number generation 
-- Lua's built-in randoms can vary across platforms.
do
  local seed0 = 10013
  local seed  = seed0
  local mod   = 2147483647.0
  local mult  = 16807.0
  function Lib.rand()  seed= (mult*seed)%mod; return seed/mod end 
  function Lib.seed(n) seed= n and n or seed0 end 
  function Lib.any(a)  return a[1 + Lib.rand() * #a // 1] end
end

-- ## Table functions
-- Subsets
function Lib.powerset(s,       t)
  t = {{}}
  for i = 1, #s do
    for j = 1, #t do
      t[#t+1] = {s[i],table.unpack(t[j])} end end
   return t end

-- Slice a table
function Lib.slice(t, lo, hi, step,   out)
  out={}
  for i = lo or 1, hi or #t, step or 1 do out[#out+1] = t[i] end
  return out end

-- Modify a list of it.
function Lib.map(a,f,     b)
  b, f = {}, f or Lib.same
  for i,v in pairs(a or {}) do b[i] = f(v) end 
  return b end 

-- Deep copy it.
function Lib.copy(t) 
  return type(t) ~= 'table' and t or Lib.map(t,Lib.copy) end

-- Sort on some field
function Lib.sorted(t,k,      f)
  if   k
  then table.sort(t, function (x,y) return x[k] < y[k] end)
  else table.sort(t)
  end
  return t end 

-- ## Meta functions
-- Return it
function Lib.same(x) return x end

-- Report rogue locals
function Lib.rogues(    skip)
  skip = {
    jit        =true, utf8=true, math=true, package=true, table=true,
    coroutine=true, bit=true, os=true, io=true, bit32=true,
    string=true, arg=true, debug=true, _VERSION=true, _G=true,
    getmetatable=true, print=true, rawequal=true, dofile=true,
    load=true, collectgarbage=true, rawget=true, loadfile=true,
    tostring=true, pairs=true, pcall=true, error=true,
    xpcall=true, select=true, assert=true, rawset=true,
    setmetatable=true, type=true, rawlen=true, next=true,
    ipairs=true, require=true, tonumber=true, warn=true}
  for k,v in pairs( _G ) do
    if not skip[k] then
      if k:match("^[^A-Z]") then
        print("-- rogue ["..k.."]") end end end end

-- Coerce a string to its right type.
function Lib.coerce(x)
  if  x=="true"  then return true  end
  if  x=="false" then return false  end
  return tonumber(x) or x end

-- ## Command-line flags
-- Update `t` with any relevant flags from the command-line.
function Lib.cli(t,     i,key,now)
  i = 0
  while i < #arg do
    i = i+1
    key, now= arg[i], Lib.coerce(arg[i+1])
    key = key:sub(2)
    if t[key] then
      i = i+1
      if type(now) == type(t[key]) then t[key] = now end end end
  return Lib.copy(t) end

-- ## Objects 
-- class - a very compact class utilities module
--
-- Taken from Steve Donovan, 2012;
-- Creates a class with an optional base class.
--
-- The resulting table can be called to make a new object, which invokes
-- an optional constructor named `_init`. If the base
-- class has a constructor, you can call it as the `super()` method.
-- Every class has a `_class` and a maybe-nil `_base` field, which can
-- be accessed through the object.
--
-- All metamethods are inherited.
-- The class is given a function `Klass.classof(obj)`.
--
--- add the key/value pairs of arrays to the first array.
-- For sets, this is their union. For the same keys,
-- the values from the first table will be overwritten.
local function update (t,...)
    for i = 1,select('#',...) do
        for k,v in pairs(select(i,...)) do t[k] = v end end
    return t end

-- Bring modules or tables into 't`.
-- If `lib` is a string, then it becomes the result of `require`
-- With only one argument, the second argument is assumed to be
-- the `ml` table itself.
local function import(t,...)
  local other
  -- explicit table, or current environment
  t = t or _ENV or getfenv(2)
  local libs = {}
  if select('#',...)==0 then 
    libs[1] = ml
  else
    for i = 1,select('#',...) do
      local lib = select(i,...)
      if type(lib) == 'string' then
        local value = _G[lib]
        if not value then -- lazy require!
          value = require (lib)
          lib = lib:match '[%w_]+$' end
        lib = {[lib]=value} end
      libs[i] = lib 
    end 
  end
  return update(t,table.unpack(libs)) end

--- class
function Lib.class(base)
  local klass, base_ctor = {}
  if base then
   import(klass,base)
   klass._base = base
   base_ctor = rawget(base,'_init')
  end
  klass.__index = klass
  klass._class = klass
  klass.classof = function(obj)
   local m = getmetatable(obj) -- object made by class() ?
   if not m or not m._class then return false end
   while m do -- follow the inheritance chain --
    if m == klass then return true end
    m = rawget(m,'_base')
   end
   return false
  end
  setmetatable(klass,{
   __call = function(klass,...)
    local obj = setmetatable({},klass)
    if rawget(klass,'_init') then
      klass.super = base_ctor
      local res = klass._init(obj,...) -- call constructor
      if res then -- which can return a new self..
       obj = setmetatable(res,klass)
      end
    elseif base_ctor then -- call base ctor automatically
      base_ctor(obj,...)
    end
    return obj end
  })
  return klass end

-- ## Exports 
return Lib
