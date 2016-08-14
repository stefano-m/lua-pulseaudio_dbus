Control PulseAudio using DBus.

Ensure that the DBus module is loaeded by PulseAudio
by adding the following to your `/etc/pulse/default.pa`

    .ifexists module-dbus-protocol.so
    load-module module-dbus-protocol
    .endif

Example usage:

    pulse = require("pulseaudio_dbus")
    address = pulse.get_address()
    sink_paths = pulse.get_sinks()
    sink = pulse.Sink:new(address, sink_paths[1])
    sink.muted = true
    sink:toggle_muted()
    print(sink.muted) -- prints false
    sink.volume = {75} -- sets the volume to 75%
