# Lurker

A small module which automatically hotswaps changed Lua files in a running
[LÖVE](http://love2d.org) project.


## Installation

Drop the [lurker.lua](lurker.lua?raw=1) and
[lume.lua](https://raw.github.com/rxi/lume/master/lume.lua) files into an
existing project and add the following line inside the `love.update()`
function:
```lua
require("lurker").update()
```
Lurker will automatically detect changed files and hotswap them into the
running project.


## Additional Functionality

To more easily make use of additional functionality, the lurker module can be
set to a variable when it is required into the project:
```lua
lurker = require "lurker"
```

### lurker.scan()
As opposed to using the `lurker.update()` function -- such to avoid the
overhead of repeatedly polling for file changes -- you can instead opt to
trigger a scan of the directory by calling `lurker.scan()` manually. If the
scan detects any changes a hotswap is performed.

### lurker.preswap
`lurker.preswap` can be set to a function. This function is called before a
hotswap occurs and is passed the name of the file which will be swapped.
```lua
lurker.preswap = function(f) print("File " .. f .. " swapping...") end
```

### lurker.postswap
`lurker.postswap` can be set to a function. This function is called after a
hotswap occurs and is passed the name of the file which was swapped.
```lua
lurker.postswap = function(f) print("File " .. f .. " was swapped") end
```

### lurker.interval
The interval in seconds for how often the scan of the directory is performed.
This is `.5` by default.

### lurker.path
The directory which is scanned for changes. This is `.` (The project's root) by
default.
