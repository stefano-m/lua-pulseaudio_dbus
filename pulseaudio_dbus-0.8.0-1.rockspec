package = "pulseaudio_dbus"
 version = "0.8.0-1"
 source = {
    url = "git://github.com/stefano-m/lua-pulseaudio_dbus",
    tag = "v0.8.0"
 }
 description = {
    summary = "Control PulseAudio devices using DBus",
    detailed = "Control PulseAudio devices using DBus",
    homepage = "https://github.com/stefano-m/lua-pulseaudio_dbus",
    license = "Apache v2.0"
 }
 dependencies = {
    "lua >= 5.1",
    "ldbus_api >= 0.8"
 }
 supported_platforms = { "linux" }
 build = {
    type = "builtin",
    modules = { pulseaudio_dbus = "pulseaudio_dbus.lua" },
    copy_directories = { "doc", "tests" }
 }
