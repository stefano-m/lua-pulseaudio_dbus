-- Works with the 'busted' framework.
-- http://olivinelabs.com/busted/

require("busted")

local pulse = require("pulseaudio_dbus")

describe("PulseAudio with DBus", function ()
           local connection
           local core
           local sink
           local original_volume
           local original_muted
           local original_port
           local original_port_sink

           before_each(function ()
               local address = pulse.get_address()
               connection = pulse.get_connection(address)
               core = pulse.get_core(connection)
               local first_sink = assert(core.Sinks[1])
	       sink = pulse.get_device(connection, first_sink)
               original_volume = sink:get_volume()
               original_muted = sink:is_muted()
           end)

           after_each(function ()
               if original_port then
                 local _sink = pulse.get_device(connection, original_port_sink)
                 _sink:set_active_port(original_port)
               end
               sink:set_volume(original_volume)
               sink:set_muted(original_muted)
               sink = nil
               core = nil
               connection = nil
           end)

           it("Can get properties", function ()
                local volume = sink.Volume

                assert.is_boolean(sink.Mute)
                assert.is_table(volume)
                assert.is_number(volume[1])
                assert.is_nil(sink.something_else)
                assert.is_string(sink.ActivePort)
                assert.is_equal("port", sink.ActivePort:match("port"))
           end)

           it("Can set same volume for all channels", function ()
                sink:set_volume({50})
                assert.are.same({50, 50}, sink:get_volume())
           end)

           it("Can set different volume for different channels", function ()
                  sink:set_volume({50, 0})
                assert.are.same({50, 0}, sink.Volume)
           end)

           it("Can set muted", function ()
                sink:set_muted(true)
                assert.is_true(sink.Mute)
                sink:set_muted(false)
                assert.is_false(sink.Mute)
           end)

           it("Can toggle muted", function ()
                  assert.are.equal(sink:is_muted(), not sink:toggle_muted())
           end)

           it("Can get the state", function ()
                  local available_states = {"running",
                                            "idle",
                                            "suspended"}

                  local state = sink:get_state()

                  local found = false
                  for _, v in ipairs(available_states) do
                    if v == state then
                      found = true
                      break
                    end
                  end

                  assert.is_true(found)
           end)

           it("Can step volume up", function ()
                local volume = sink:get_volume_percent()
                local volume_step = sink.volume_step

                local expected_volume = {}
                for i, v in ipairs(volume) do
                  expected_volume[i] = v + volume_step
                end

                sink:volume_up()

                assert.are.same(expected_volume,
                                sink:get_volume_percent())
           end)

           it("Will set the volume to 100 the first time step would get it above it", function ()
                  sink.volume_max = 110
                  sink.volume_step = 5
                  sink:set_volume_percent({97})
                  sink:volume_up()

                  assert.are.same({100, 100}, sink:get_volume_percent())

                  sink:volume_up()

                  assert.are.same({105, 105}, sink:get_volume_percent())
           end)

           it("Can step volume up to its maximum", function ()
                  sink:set_volume_percent({sink.volume_max})

                  sink:volume_up()

                for _, actual in ipairs(sink:get_volume_percent()) do
                  assert.are.equal(sink.volume_max, actual)
                end
           end)

           it("Can step volume down", function ()
                local volume = sink:get_volume_percent()
                local volume_step = sink.volume_step

                local expected_volume = {}
                for i, v in ipairs(volume) do
                  expected_volume[i] = v - volume_step
                end

                sink:volume_down()

                assert.are.same(expected_volume,
                                sink:get_volume_percent())
           end)

           it("Will set the volume to 100 the first time step would get it below it", function ()
                  sink.volume_step = 5
                  sink:set_volume_percent({102})
                  sink:volume_down()

                  assert.are.same({100, 100}, sink:get_volume_percent())

                  sink:volume_down()

                  assert.are.same({95, 95}, sink:get_volume_percent())
           end)

           it("Will not step the volume below zero", function ()
                  sink:set_volume({0})
                  sink:volume_down()
                  for _, actual in ipairs(sink.Volume) do
                    assert.are.equal(0, actual)
                  end
           end)

           it("Will set the volume to zero if the step is too large", function ()
                sink:set_volume_percent({1})
                sink.volume_step = 100

                sink:volume_down()

                for _, actual in ipairs(sink.Volume) do
                  assert.are.equal(0, actual)
                end
           end)

           it("Will set the next sink as the FallbackSink", function()
                  local total_number_of_sinks = #core.Sinks
                  if total_number_of_sinks <= 1 then
                    print("\nNOTE: Won't set the next sink as the FallbackSink because there is only one sink available in this machine")
                    return
                  end
                  local sinks_array = {}
                  sinks_array[1] = sink
                  for s=2,total_number_of_sinks do
                      sinks_array[s] = pulse.get_device(connection, assert(core.Sinks[s]))
                  end
                  for s=1,total_number_of_sinks do
                    if core.FallbackSink ~= sinks_array[s].object_path then
                      core:set_fallback_sink(sinks_array[s].object_path)
                      assert.is_equal(core.FallbackSink, sinks_array[s].object_path)
                      return
                    end
                  end
           end)

           it("Will Cycle through all available PlaybackStreams and move them to the FallbackSink", function()
                  if #core.PlaybackStreams == 0 then
                    print("\nNOTE: Can't cycle through all available PlaybackStreams and move them to the FallbackSink because there are no PlaybackStreams in this machine")
                    return
                  else
                    local stream = {}
                    for ps=1,#core.PlaybackStreams do
                      stream[ps] = pulse.get_stream(connection, core.PlaybackStreams[ps])
                      stream[ps]:Move(core.FallbackSink)
                    end
                    -- This test check whether the streams' `Device` property was actually changed
                    for ps=1,#core.PlaybackStreams do
                      stream[ps] = pulse.get_stream(connection, core.PlaybackStreams[ps])
                      assert.is_equal(stream[ps].Device, core.FallbackSink)
                    end
                  end
           end)

           it("Will set the next port as the ActivePort", function()
                  for _, s in ipairs(core.Sinks) do
	                  local _sink = pulse.get_device(connection, s)
                    local total_number_of_ports = #_sink.Ports
                    -- Find a sink with more than one port
                    if total_number_of_ports > 1 then
                      -- Save the original values to restore them later
                      original_port = _sink:get_active_port()
                      assert.is_equal(original_port, _sink.ActivePort)
                      original_port_sink = _sink.object_path
                      local ports_array = {}
                      for p=1,total_number_of_ports do
                        ports_array[p] = pulse.get_port(connection, assert(_sink.Ports[p]))
                      end
                      -- Change and check whether the `ActivePort` was actually changed
                      for p=1,total_number_of_ports do
                        if _sink:get_active_port() ~= ports_array[p].object_path then
                          _sink:set_active_port(ports_array[p].object_path)
                          assert.is_equal(_sink:get_active_port(), ports_array[p].object_path)
                          return
                        end
                      end
                    end
                  end
                  print("\nTest skipped: Won't set the next port as the ActivePort because no sink in this machine has more than one port")
            end)

            it("Will fail setting wrong port as ActivePort", function()
                  assert.has_error(function() sink:set_active_port('non_existant_object_path') end)
            end)
end)
