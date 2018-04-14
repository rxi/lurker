package = "lurker"
version = "1.0.1-0"
source = {
   url = "git+https://github.com/rxi/lurker.git"
}
description = {
   detailed = [[
A small module which automatically hotswaps changed Lua files in a running
[LÖVE](http://love2d.org) project.]],
   homepage = "https://github.com/rxi/lurker",
   license = "MIT"
}
dependencies = {
   "lua >= 5.1, < 5.4"
}
build = {
   type = "builtin",
   modules = {
      lurker = "lurker.lua"
   }
}
