Control PulseAudio using DBus.

Example

    pulse = require("pulseaudio_dbus")
    address = pulse.get_address()
    sink_paths = pulse.get_sinks()
    sink = pulse.Sink:new(address, sink_paths[1])
    sink.muted = true
    sink:toggle_muted()
    print(sink.muted) -- prints false
    sink.volume = {75} -- sets the volume to 75%
