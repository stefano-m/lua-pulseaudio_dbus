-- Works with the 'busted' framework.
-- http://olivinelabs.com/busted/

package.path = "../?.lua;" .. package.path
local b = require("busted")

local pulse = require("pulseaudio_dbus")

b.describe("PulseAudio with DBus", function ()
           local sink
           local original_volume
           local original_muted

           b.before_each(function ()
               local address = pulse.get_address()
               local connection = pulse.get_connection(address)
               local core = pulse.get_core(connection)
               local first_sink = assert(core.Sinks[1])
	       sink = pulse.get_device(connection, first_sink)
               original_volume = sink:get_volume()
               original_muted = sink:is_muted()
           end)

           b.after_each(function ()
               sink:set_volume(original_volume)
               sink:set_muted(original_muted)
               sink = nil
           end)

           b.it("Can get properties", function ()
                local volume = sink.Volume

                assert.is_boolean(sink.Mute)
                assert.is_table(volume)
                assert.is_number(volume[1])
                assert.is_nil(sink.something_else)
                assert.is_string(sink.ActivePort)
                assert.is_equal("port", sink.ActivePort:match("port"))
           end)

           b.it("Can set same volume for all channels", function ()
                sink:set_volume({50})
                assert.are.same({50, 50}, sink:get_volume())
           end)

           b.it("Can set different volume for different channels", function ()
                  sink:set_volume({50, 0})
                assert.are.same({50, 0}, sink.Volume)
           end)

           b.it("Can set muted", function ()
                sink:set_muted(true)
                assert.is_true(sink.Mute)
                sink:set_muted(false)
                assert.is_false(sink.Mute)
           end)

           b.it("Can toggle muted", function ()
                  assert.are.equal(sink:is_muted(), not sink:toggle_muted())
           end)

           b.it("Can get the state", function ()
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

           b.it("Can step volume up", function ()
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

           b.it("Will set the volume to 100 the first time step would get it above it", function ()
                  sink.volume_max = 110
                  sink.volume_step = 5
                  sink:set_volume_percent({97})
                  sink:volume_up()

                  assert.are.same({100, 100}, sink:get_volume_percent())

                  sink:volume_up()

                  assert.are.same({105, 105}, sink:get_volume_percent())
           end)

           b.it("Can step volume up to its maximum", function ()
                  sink:set_volume_percent({sink.volume_max})

                  sink:volume_up()

                for _, actual in ipairs(sink:get_volume_percent()) do
                  assert.are.equal(sink.volume_max, actual)
                end
           end)

           b.it("Can step volume down", function ()
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

           b.it("Will set the volume to 100 the first time step would get it below it", function ()
                  sink.volume_step = 5
                  sink:set_volume_percent({102})
                  sink:volume_down()

                  assert.are.same({100, 100}, sink:get_volume_percent())

                  sink:volume_down()

                  assert.are.same({95, 95}, sink:get_volume_percent())
           end)

           b.it("Will not step the volume below zero", function ()
                  sink:set_volume({0})
                  sink:volume_down()
                  for _, actual in ipairs(sink.Volume) do
                    assert.are.equal(0, actual)
                  end
           end)

           b.it("Will set the volume to zero if the step is too large", function ()
                sink:set_volume_percent({1})
                sink.volume_step = 100

                sink:volume_down()

                for _, actual in ipairs(sink.Volume) do
                  assert.are.equal(0, actual)
                end
           end)
end)
