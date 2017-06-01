# Control PulseAudio using DBus

This module provides a simple API to control
[PulseAudio](https://www.freedesktop.org/wiki/Software/PulseAudio/)
using [DBus](http://dbus.freedesktop.org/).

# Introduction

Seeking to learn some [Lua](http://www.lua.org), and customize my
[Awesome Window Manager](https://awesomewm.org), I have started to dig into
DBus in an attempt to avoid using terminal commands and parsing their outputs.

# Requirements

For this module to work, you need PulseAudio with DBus support enabled.

You need to ensure that the DBus module is loaeded by PulseAudio by adding the
following to your `/etc/pulse/default.pa` (or `~/.config/pulse/default.pa` to
set it up at the user level).

    .ifexists module-dbus-protocol.so
    load-module module-dbus-protocol
    .endif

If the module is not present or not loaded, this module will not work.

# Installation

This module can be installed with [Luarocks](http://luarocks.org/) by running

    luarocks install pulseaudio_dbus

Use the `--local` option in `luarocks` if you don't want or can't install it
system-wide.

# Example

Below is a small example of how to use the module:

    pulse = require("pulseaudio_dbus")
    address = pulse.get_address()
    connection = pulse.get_connection(address)
    core = pulse.get_core(connection)
    sink = pulse.get_device(address, core:get_sinks()[1])
    sink:set_muted(true)
    sink:toggle_muted()
    assert(not sink:is_muted())
    sink:set_volume_percent({75}) -- sets the volume to 75%

# Documentation

The documentation of this module is built using [LDoc](https://stevedonovan.github.io/ldoc/).
A copy of the documentation is already provided in the `docs` folder,
but you can build it from source by running `ldoc .` in the root of the repository.
