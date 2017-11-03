-- Works with the 'busted' framework.
-- http://olivinelabs.com/busted/

package.path = "../?.lua;" .. package.path
local b = require("busted")

local pulse = require("pulseaudio_dbus")

b.describe("PulseAudio with DBus", function ()
           local connection
           local core
           local original_volume
           local original_muted

           b.before_each(function ()
               local address = pulse.get_address()
               connection = pulse.get_connection(address)
               core = pulse.get_core(connection)
			   sink = {}
			   for s=1,#core.Sinks do
                   sink[s] = pulse.get_device(connection, assert(core.Sinks[s]))
			   end
               original_volume = sink[1]:get_volume()
               original_muted = sink[1]:is_muted()
           end)

           b.after_each(function ()
               sink[1]:set_volume(original_volume)
               sink[1]:set_muted(original_muted)
               sink = nil
               core = nil
               connection = nil
           end)

           b.it("Can get properties", function ()
                local volume = sink[1].Volume

                assert.is_boolean(sink[1].Mute)
                assert.is_table(volume)
                assert.is_number(volume[1])
                assert.is_nil(sink[1].something_else)
                assert.is_string(sink[1].ActivePort)
                assert.is_equal("port", sink[1].ActivePort:match("port"))
           end)

           b.it("Can set same volume for all channels", function ()
                sink[1]:set_volume({50})
                assert.are.same({50, 50}, sink[1]:get_volume())
           end)

           b.it("Can set different volume for different channels", function ()
                  sink[1]:set_volume({50, 0})
                assert.are.same({50, 0}, sink[1].Volume)
           end)

           b.it("Can set muted", function ()
                sink[1]:set_muted(true)
                assert.is_true(sink[1].Mute)
                sink[1]:set_muted(false)
                assert.is_false(sink[1].Mute)
           end)

           b.it("Can toggle muted", function ()
                  assert.are.equal(sink[1]:is_muted(), not sink[1]:toggle_muted())
           end)

           b.it("Can get the state", function ()
                  local available_states = {"running",
                                            "idle",
                                            "suspended"}

                  local state = sink[1]:get_state()

                  local found = false
                  for _, v in ipairs(available_states) do
                    if v == state then
                      found = true
                      break
                    end
                  end

                  assert.is_true(found)
           end)

           b.it("Can step volume up", function ()
                local volume = sink[1]:get_volume_percent()
                local volume_step = sink[1].volume_step

                local expected_volume = {}
                for i, v in ipairs(volume) do
                  expected_volume[i] = v + volume_step
                end

                sink[1]:volume_up()

                assert.are.same(expected_volume,
                                sink[1]:get_volume_percent())
           end)

           b.it("Will set the volume to 100 the first time step would get it above it", function ()
                  sink[1].volume_max = 110
                  sink[1].volume_step = 5
                  sink[1]:set_volume_percent({97})
                  sink[1]:volume_up()

                  assert.are.same({100, 100}, sink[1]:get_volume_percent())

                  sink[1]:volume_up()

                  assert.are.same({105, 105}, sink[1]:get_volume_percent())
           end)

           b.it("Can step volume up to its maximum", function ()
                  sink[1]:set_volume_percent({sink[1].volume_max})

                  sink[1]:volume_up()

                for _, actual in ipairs(sink[1]:get_volume_percent()) do
                  assert.are.equal(sink[1].volume_max, actual)
                end
           end)

           b.it("Can step volume down", function ()
                local volume = sink[1]:get_volume_percent()
                local volume_step = sink[1].volume_step

                local expected_volume = {}
                for i, v in ipairs(volume) do
                  expected_volume[i] = v - volume_step
                end

                sink[1]:volume_down()

                assert.are.same(expected_volume,
                                sink[1]:get_volume_percent())
           end)

           b.it("Will set the volume to 100 the first time step would get it below it", function ()
                  sink[1].volume_step = 5
                  sink[1]:set_volume_percent({102})
                  sink[1]:volume_down()

                  assert.are.same({100, 100}, sink[1]:get_volume_percent())

                  sink[1]:volume_down()

                  assert.are.same({95, 95}, sink[1]:get_volume_percent())
           end)

           b.it("Will not step the volume below zero", function ()
                  sink[1]:set_volume({0})
                  sink[1]:volume_down()
                  for _, actual in ipairs(sink[1].Volume) do
                    assert.are.equal(0, actual)
                  end
           end)

           b.it("Will set the volume to zero if the step is too large", function ()
                sink[1]:set_volume_percent({1})
                sink[1].volume_step = 100

                sink[1]:volume_down()

                for _, actual in ipairs(sink[1].Volume) do
                  assert.are.equal(0, actual)
                end
           end)

           b.it("Will set the next sink as the FallbackSink", function()
                  local total_number_of_sinks = #core.Sinks
                  if total_number_of_sinks <= 1 then
                    print("\nNOTE: Won't set the next sink as the FallbackSink because there is only one sink available in this machine")
                    return
                  end
                  for s=1,total_number_of_sinks do
                    if core.FallbackSink ~= sink[s].object_path then
                      core:set_fallback_sink(sink[s].object_path)
                      assert.is_equal(core.FallbackSink, sink[s].object_path)
                      return
                    end
                  end
           end)

           b.it("Will Cycle through all available PlaybackStreams and move them to the FallbackSink", function()
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
end)
