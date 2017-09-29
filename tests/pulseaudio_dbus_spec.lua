-- Works with the 'busted' framework.
-- http://olivinelabs.com/busted/

package.path = "../?.lua;" .. package.path
local b = require("busted")

local pulse = require("pulseaudio_dbus")

b.describe("PulseAudio with DBus", function ()
           b.before_each(function ()
               local address = pulse.get_address()
               local connection = pulse.get_connection(address)
               local core = pulse.get_core(connection)
			   sink = {}
			   sink_device = {}
			   original_volume = {}
			   original_muted = {}
			   total_number_of_sinks = #core.Sinks
			   for s=1,total_number_of_sinks do
                   sink[s] = assert(core.Sinks[s])
	               sink_device[s] = pulse.get_device(connection, sink[s])
                   original_volume[s] = sink_device[s]:get_volume()
                   original_muted[s] = sink_device[s]:is_muted()
			   end
           end)

           b.after_each(function ()
			   for s=1,total_number_of_sinks do
               	   sink_device[s]:set_volume(original_volume[s])
               	   sink_device[s]:set_muted(original_muted[s])
               	   sink_device[s] = nil
			   end
           end)

           b.it("Can get properties", function ()
			    for s=1,total_number_of_sinks do
                    local volume = sink_device[s].Volume
                    assert.is_boolean(sink_device[s].Mute)
                    assert.is_table(volume)
                    assert.is_number(volume[1])
                    assert.is_nil(sink_device[s].something_else)
                    assert.is_string(sink_device[s].ActivePort)
                    assert.is_equal("port", sink_device[s].ActivePort:match("port"))
				end
           end)

           b.it("Can set same volume for all channels", function ()
			   for s=1,total_number_of_sinks do
                	sink_device[s]:set_volume({50})
                	assert.are.same({50, 50}, sink_device[s]:get_volume())
		   		end
           end)

           b.it("Can set different volume for different channels", function ()
			   for s=1,total_number_of_sinks do
                  	  sink_device[s]:set_volume({50, 0})
                	assert.are.same({50, 0}, sink_device[s].Volume)
		   		end
           end)

           b.it("Can set muted", function ()
			   for s=1,total_number_of_sinks do
                	sink_device[s]:set_muted(true)
                	assert.is_true(sink_device[s].Mute)
                	sink_device[s]:set_muted(false)
                	assert.is_false(sink_device[s].Mute)
		   		end
           end)

           b.it("Can toggle muted", function ()
			   for s=1,total_number_of_sinks do
                  	  assert.are.equal(sink_device[s]:is_muted(), not sink_device[s]:toggle_muted())
		   		  end
           end)

           b.it("Can get the state", function ()
			   for s=1,total_number_of_sinks do
                  	  local available_states = {"running",
                                            	"idle",
                                            	"suspended"}

                  	  local state = sink_device[s]:get_state()

                  	  local found = false
                  	  for _, v in ipairs(available_states) do
                    	if v == state then
                      	  found = true
                      	  break
                    	end
                  	  end

                  	  assert.is_true(found)
		   		  end
           end)

           b.it("Can step volume up", function ()
			   for s=1,total_number_of_sinks do
                	local volume = sink_device[s]:get_volume_percent()
                	local volume_step = sink_device[s].volume_step

                	local expected_volume = {}
                	for i, v in ipairs(volume) do
                  	  expected_volume[i] = v + volume_step
                	end

                	sink_device[s]:volume_up()

                	assert.are.same(expected_volume,
                                	sink_device[s]:get_volume_percent())
		   						end
           end)

           b.it("Will set the volume to 100 the first time step would get it above it", function ()
			   for s=1,total_number_of_sinks do
                  	  sink_device[s].volume_max = 110
                  	  sink_device[s].volume_step = 5
                  	  sink_device[s]:set_volume_percent({97})
                  	  sink_device[s]:volume_up()

                  	  assert.are.same({100, 100}, sink_device[s]:get_volume_percent())

                  	  sink_device[s]:volume_up()

                  	  assert.are.same({105, 105}, sink_device[s]:get_volume_percent())
		   		  end
           end)

           b.it("Can step volume up to its maximum", function ()
			   for s=1,total_number_of_sinks do
                  	  sink_device[s]:set_volume_percent({sink_device[s].volume_max})

                  	  sink_device[s]:volume_up()

                	for _, actual in ipairs(sink_device[s]:get_volume_percent()) do
                  	  assert.are.equal(sink_device[s].volume_max, actual)
                	end
		   		end
           end)

           	   b.it("Can step volume down", function ()
		   			for s=1,total_number_of_sinks do
              		  	local volume = sink_device[s]:get_volume_percent()
                		local volume_step = sink_device[s].volume_step

                		local expected_volume = {}
                		for i, v in ipairs(volume) do
                		  expected_volume[i] = v - volume_step
                		end

                		sink_device[s]:volume_down()

                		assert.are.same(expected_volume, sink_device[s]:get_volume_percent())
					end
           end)

           b.it("Will set the volume to 100 the first time step would get it below it", function ()
			   for s=1,total_number_of_sinks do
                  	  sink_device[s].volume_step = 5
                  	  sink_device[s]:set_volume_percent({102})
                  	  sink_device[s]:volume_down()

                  	  assert.are.same({100, 100}, sink_device[s]:get_volume_percent())

                  	  sink_device[s]:volume_down()

                  	  assert.are.same({95, 95}, sink_device[s]:get_volume_percent())
		   		  end
           end)

           b.it("Will not step the volume below zero", function ()
			   for s=1,total_number_of_sinks do
                  	  sink_device[s]:set_volume({0})
                  	  sink_device[s]:volume_down()
                  	  for _, actual in ipairs(sink_device[s].Volume) do
                    	assert.are.equal(0, actual)
                  	  end
		   		  end
           end)

           b.it("Will set the volume to zero if the step is too large", function ()
			   for s=1,total_number_of_sinks do
                	sink_device[s]:set_volume_percent({1})
                	sink_device[s].volume_step = 100

                	sink_device[s]:volume_down()

                	for _, actual in ipairs(sink_device[s].Volume) do
                  	  assert.are.equal(0, actual)
                	end
		   		end
           end)
end)
