package = "pulseaudio_dbus"
 version = "devel-1"
 source = {
    url = "git://github.com/stefano-m/lua-pulseaudio_dbus",
    tag = "master"
 }
 description = {
    summary = "Control PulseAudio devices using DBus",
    detailed = "Control PulseAudio devices using DBus",
    homepage = "https://github.com/stefano-m/lua-pulseaudio_dbus",
    license = "Apache v2.0"
 }
 dependencies = {
    "lua >= 5.1",
    "dbus_proxy"
 }
 supported_platforms = { "linux" }
 build = {
    type = "builtin",
    modules = { pulseaudio_dbus = "src/pulseaudio_dbus/init.lua" },
    copy_directories = { "docs", "tests" }
 }
