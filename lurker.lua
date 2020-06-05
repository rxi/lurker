--
-- lurker
--
-- Copyright (c) 2018 rxi
--
-- This library is free software; you can redistribute it and/or modify it
-- under the terms of the MIT license. See LICENSE for details.
--

-- Assumes lume is in the same directory as this file if it does not exist
-- as a global
local lume = rawget(_G, "lume") or require((...):gsub("[^/.\\]+$", "lume"))

local lurker = { _version = "1.0.1" }


local dir = love.filesystem.enumerate or love.filesystem.getDirectoryItems
local time = love.timer.getTime or os.time

local function isdir(path)
    local info = love.filesystem.getInfo(path)
    return info.type == "directory"
end

local function lastmodified(path)
    local info = love.filesystem.getInfo(path, "file")
    return info.modtime
end

local lovecallbacknames = {
  "update",
  "load",
  "draw",
  "mousepressed",
  "mousereleased",
  "keypressed",
  "keyreleased",
  "focus",
  "quit",
}


function lurker.init()
  lurker.print("Initing lurker")
  lurker.path = "."
  lurker.preswap = function() end
  lurker.postswap = function() end
  lurker.interval = .5
  lurker.protected = true
  lurker.quiet = false
  lurker.lastscan = 0
  lurker.lasterrorfile = nil
  lurker.files = {}
  lurker.funcwrappers = {}
  lurker.lovefuncs = {}
  lurker.state = "init"
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
        t = lume.concat(t, lurker.listdir(f, true, true))
      else
        table.insert(t, lume.trim(f, "/"))
      end
    end
  end
  return t
end


function lurker.initwrappers()
  for _, v in pairs(lovecallbacknames) do
    lurker.funcwrappers[v] = function(...)
      local args = {...}
      xpcall(function()
        return lurker.lovefuncs[v] and lurker.lovefuncs[v](unpack(args))
      end, lurker.onerror)
    end
    lurker.lovefuncs[v] = love[v]
  end
  lurker.updatewrappers()
end


function lurker.updatewrappers()
  for _, v in pairs(lovecallbacknames) do
    if love[v] ~= lurker.funcwrappers[v] then
      lurker.lovefuncs[v] = love[v]
      love[v] = lurker.funcwrappers[v]
    end
  end
end


function lurker.onerror(e, nostacktrace)
  lurker.print("An error occurred; switching to error state")
  lurker.state = "error"

  -- Release mouse
  local setgrab = love.mouse.setGrab or love.mouse.setGrabbed
  setgrab(false)

  -- Set up callbacks
  for _, v in pairs(lovecallbacknames) do
    love[v] = function() end
  end

  love.update = lurker.update

  love.keypressed = function(k)
    if k == "escape" then
      lurker.print("Exiting...")
      love.event.quit()
    end
  end

  local stacktrace = nostacktrace and "" or
                     lume.trim((debug.traceback("", 2):gsub("\t", "")))
  local msg = lume.format("{1}\n\n{2}", {e, stacktrace})
  local colors = {
    { lume.color("#1e1e2c", 256) },
    { lume.color("#f0a3a3", 256) },
    { lume.color("#92b5b0", 256) },
    { lume.color("#66666a", 256) },
    { lume.color("#cdcdcd", 256) },
  }
  love.graphics.reset()
  love.graphics.setFont(love.graphics.newFont(12))

  love.draw = function()
    local pad = 25
    local width = love.graphics.getWidth()

    local function drawhr(pos, color1, color2)
      local animpos = lume.smooth(pad, width - pad - 8, lume.pingpong(time()))
      if color1 then love.graphics.setColor(color1) end
      love.graphics.rectangle("fill", pad, pos, width - pad*2, 1)
      if color2 then love.graphics.setColor(color2) end
      love.graphics.rectangle("fill", animpos, pos, 8, 1)
    end

    local function drawtext(str, x, y, color, limit)
      love.graphics.setColor(color)
      love.graphics[limit and "printf" or "print"](str, x, y, limit)
    end

    love.graphics.setBackgroundColor(colors[1])
    love.graphics.clear()

    drawtext("An error has occurred", pad, pad, colors[2])
    drawtext("lurker", width - love.graphics.getFont():getWidth("lurker") -
             pad, pad, colors[4])
    drawhr(pad + 32, colors[4], colors[5])
    drawtext("If you fix the problem and update the file the program will " ..
             "resume", pad, pad + 46, colors[3])
    drawhr(pad + 72, colors[4], colors[5])
    drawtext(msg, pad, pad + 90, colors[5], width - pad * 2)

    love.graphics.reset()
  end
end


function lurker.exitinitstate()
  lurker.state = "normal"
  if lurker.protected then
    lurker.initwrappers()
  end
end


function lurker.exiterrorstate()
  lurker.state = "normal"
  for _, v in pairs(lovecallbacknames) do
    love[v] = lurker.funcwrappers[v]
  end
end


function lurker.update()
  if lurker.state == "init" then
    lurker.exitinitstate()
  end
  local diff = time() - lurker.lastscan
  if diff > lurker.interval then
    lurker.lastscan = lurker.lastscan + diff
    local changed = lurker.scan()
    if #changed > 0 and lurker.lasterrorfile then
      local f = lurker.lasterrorfile
      lurker.lasterrorfile = nil
      lurker.hotswapfile(f)
    end
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


function lurker.hotswapfile(f)
  lurker.print("Hotswapping '{1}'...", {f})
  if lurker.state == "error" then
    lurker.exiterrorstate()
  end
  if lurker.preswap(f) then
    lurker.print("Hotswap of '{1}' aborted by preswap", {f})
    lurker.resetfile(f)
    return
  end
  local modname = lurker.modname(f)
  local t, ok, err = lume.time(lume.hotswap, modname)
  if ok then
    lurker.print("Swapped '{1}' in {2} secs", {f, t})
  else
    lurker.print("Failed to swap '{1}' : {2}", {f, err})
    if not lurker.quiet and lurker.protected then
      lurker.lasterrorfile = f
      lurker.onerror(err, true)
      lurker.resetfile(f)
      return
    end
  end
  lurker.resetfile(f)
  lurker.postswap(f)
  if lurker.protected then
    lurker.updatewrappers()
  end
end


function lurker.scan()
  if lurker.state == "init" then
    lurker.exitinitstate()
  end
  local changed = lurker.getchanged()
  lume.each(changed, lurker.hotswapfile)
  return changed
end


return lurker.init()
