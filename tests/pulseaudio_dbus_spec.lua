-- Works with the 'busted' framework.
-- http://olivinelabs.com/busted/

package.path = "../?.lua;" .. package.path

local pulse = require("pulseaudio_dbus")

describe("PulseAudio with DBus", function ()
           local sink
           local original_volume
           local original_muted

           before_each(function ()
               local address = pulse.get_address()
               local first_sink = assert(pulse.get_sinks(address)[1])
               sink = pulse.Sink:new(address, first_sink)
               original_volume = sink.volume
               original_muted = sink.muted
           end)

           after_each(function ()
               sink.volume = original_volume
               sink.muted = original_muted
               sink = nil
           end)

           it("Can get properties", function ()
                local volume = sink.volume

                assert.is_boolean(sink.muted)
                assert.is_table(volume)
                assert.is_number(volume[1])
                assert.is_nil(sink.something_else)
           end)

           it("Can set same volume for all channels", function ()
                sink.volume = {50}
                assert.are.same({50, 50}, sink.volume)
           end)

           it("Can set different volume for different channels", function ()
                sink.volume = {50, 0}
                assert.are.same({50, 0}, sink.volume)
           end)

           it("Can set muted", function ()
                sink.muted = true
                assert.is_true(sink.muted)
                sink.muted = false
                assert.is_false(sink.muted)
           end)

           it("Cannot set invalid properties", function ()
                assert.has_error(function ()
                    sink.invalid = 1
                end, "Cannot set key (invalid) to value (1)")
           end)

           it("Can toggle muted", function ()
                local m = sink.muted
                assert.are.equal(m, not sink:toggle_muted())
           end)

           it("Can step volume up", function ()
                sink.volume = {50}
                local volume = sink.volume
                local volume_step = sink.volume_step

                local expected_volume = {}
                for i, v in ipairs(volume) do
                  expected_volume[i] = v + volume_step
                end

                sink:volume_up()

                assert.are.same(expected_volume,
                                sink.volume)
           end)

           it("Can step volume up to its maximum", function ()
                sink.volume = {sink.volume_max}

                sink:volume_up()

                for _, actual in ipairs(sink.volume) do
                  assert.are.equal(sink.volume_max, actual)
                end
           end)

           it("Can step volume down", function ()
                local volume = sink.volume
                local volume_step = sink.volume_step

                local expected_volume = {}
                for i, v in ipairs(volume) do
                  expected_volume[i] = v - volume_step
                end

                sink:volume_down()

                assert.are.same(expected_volume,
                                sink.volume)
           end)

           it("Will not step the volume below zero", function ()
                sink.volume = {0}
                sink:volume_down()
                for _, actual in ipairs(sink.volume) do
                  assert.are.equal(0, actual)
                end
           end)

           it("Will set the volume to zero if the step is too large", function ()
                sink.volume = {1}
                sink.volume_step = 100

                sink:volume_down()

                for _, actual in ipairs(sink.volume) do
                  assert.are.equal(0, actual)
                end
           end)
end)
