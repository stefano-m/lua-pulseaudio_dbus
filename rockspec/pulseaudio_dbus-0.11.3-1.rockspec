package = "pulseaudio_dbus"
version = "0.11.3-1"
source = {
   url = "git://github.com/stefano-m/lua-pulseaudio_dbus",
   tag = "v0.11.3"
}
description = {
   summary = "Control PulseAudio devices using DBus",
   detailed = "Control PulseAudio devices using DBus",
   homepage = "git+https://github.com/stefano-m/lua-pulseaudio_dbus",
   license = "Apache v2.0"
}
supported_platforms = {
   "linux"
}
dependencies = {
   "lua >= 5.1",
   "dbus_proxy >= 0.8.0, < 0.9"
}
build = {
   type = "builtin",
   modules = {
      pulseaudio_dbus = "src/pulseaudio_dbus/init.lua"
   },
   copy_directories = {
      "docs",
      "tests"
   }
}
