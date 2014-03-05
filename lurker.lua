--
-- lurker 
--
-- Copyright (c) 2014, rxi
--
-- This library is free software; you can redistribute it and/or modify it
-- under the terms of the MIT license. See LICENSE for details.
--

local lume = require "lume"

local lurker = { _version = "1.0.0" }


local dir = love.filesystem.enumerate or love.filesystem.getDirectoryItems
local isdir = love.filesystem.isDirectory
local time = love.timer.getTime or os.time
local lastmodified = love.filesystem.getLastModified


function lurker.init()
  lurker.print("Initing lurker")
  lurker.path = "."
  lurker.preswap = function() end
  lurker.postswap = function() end
  lurker.interval = .5
  lurker.last = 0
  lurker.files = {}
  lume.each(lurker.getchanged(), lurker.resetfile)
  return lurker
end


function lurker.print(...)
  print("[lurker] " .. lume.format(...))
end


function lurker.listdir(path, recursive, skipdotfiles)
  path = (path == ".") and "" or path
  local function fullpath(x) return path .. "/" .. x end
  local t = {}
  for _, f in pairs(lume.map(dir(path), fullpath)) do
    if not skipdotfiles or not f:match("/%.[^/]*$") then
      if recursive and isdir(f) then
        lume.merge(t, lurker.listdir(f, true, true))
      else
        table.insert(t, lume.trim(f, "/"))
      end
    end
  end
  return t
end


function lurker.update() 
  local diff = time() - lurker.last 
  if diff > lurker.interval then
    lurker.last = lurker.last + diff
    lurker.scan()
  end
end


function lurker.getchanged()
  local function fn(f)
    return f:match("%.lua$") and lurker.files[f] ~= lastmodified(f)
  end
  return lume.filter(lurker.listdir(lurker.path, true, true), fn)
end


function lurker.modname(f)
  return (f:gsub("%.lua$", ""):gsub("[/\\]", "."))
end


function lurker.resetfile(f)
  lurker.files[f] = lastmodified(f)
end


function lurker.scan()
  for _, f in pairs(lurker.getchanged()) do
    lurker.print("Hotswapping '{f}'...", {f = f})
    lurker.preswap(f)
    local modname = lurker.modname(f)
    local t, ok, err = lume.time(lume.hotswap, modname)
    if ok then
      lurker.print("Swapped '{f}' in {t} secs", {f = f, t = t})
    else 
      lurker.print("Failed to swap '{f}' : {e}", {f = f, e = err})
    end
    lurker.resetfile(f)
    lurker.postswap(f)
  end
end


return lurker.init()
