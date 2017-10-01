-- Works with the 'busted' framework.
-- http://olivinelabs.com/busted/

package.path = "../?.lua;" .. package.path
local b = require("busted")

local pulse = require("pulseaudio_dbus")

b.describe("PulseAudio with DBus", function ()
           b.before_each(function ()
               local address = pulse.get_address()
               local connection = pulse.get_connection(address)
               core = pulse.get_core(connection)
			   sink = {}
			   total_number_of_sinks = #core.Sinks
			   for s=1,total_number_of_sinks do
				   sink[s] = {}
                   sink[s].path = assert(core.Sinks[s])
	               sink[s].object = pulse.get_device(connection, sink[s].path)
				   sink[s].original = {}
                   sink[s].original.volume = sink[s].object:get_volume()
                   sink[s].original.muted = sink[s].object:is_muted()
			   end
           end)

           b.after_each(function ()
			   for s=1,total_number_of_sinks do
               	   sink[s].object:set_volume(sink[s].original.volume)
               	   sink[s].object:set_muted(sink[s].original.muted)
               	   sink[s].object = nil
			   end
           end)

           b.it("Can get properties", function ()
			    for s=1,total_number_of_sinks do
                    local volume = sink[s].object.Volume
                    assert.is_boolean(sink[s].object.Mute)
                    assert.is_table(volume)
                    assert.is_number(volume[1])
                    assert.is_nil(sink[s].object.something_else)
                    assert.is_string(sink[s].object.ActivePort)
                    assert.is_equal("port", sink[s].object.ActivePort:match("port"))
				end
				assert.is_string(core.FallbackSink)
           end)

           b.it("Can set same volume for all channels", function ()
			   for s=1,total_number_of_sinks do
                	sink[s].object:set_volume({50})
                	assert.are.same({50, 50}, sink[s].object:get_volume())
		   		end
           end)

           b.it("Can set different volume for different channels", function ()
			   for s=1,total_number_of_sinks do
                  	  sink[s].object:set_volume({50, 0})
                	assert.are.same({50, 0}, sink[s].object.Volume)
		   		end
           end)

           b.it("Can set muted", function ()
			   for s=1,total_number_of_sinks do
                	sink[s].object:set_muted(true)
                	assert.is_true(sink[s].object.Mute)
                	sink[s].object:set_muted(false)
                	assert.is_false(sink[s].object.Mute)
		   		end
           end)

           b.it("Can toggle muted", function ()
			   for s=1,total_number_of_sinks do
                  	  assert.are.equal(sink[s].object:is_muted(), not sink[s].object:toggle_muted())
		   		  end
           end)

           b.it("Can get the state", function ()
			   for s=1,total_number_of_sinks do
                  	  local available_states = {"running",
                                            	"idle",
                                            	"suspended"}

                  	  local state = sink[s].object:get_state()

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
                	local volume = sink[s].object:get_volume_percent()
                	local volume_step = sink[s].object.volume_step

                	local expected_volume = {}
                	for i, v in ipairs(volume) do
                  	  expected_volume[i] = v + volume_step
                	end

                	sink[s].object:volume_up()

                	assert.are.same(expected_volume,
                                	sink[s].object:get_volume_percent())
		   						end
           end)

           b.it("Will set the volume to 100 the first time step would get it above it", function ()
			   for s=1,total_number_of_sinks do
                  	  sink[s].object.volume_max = 110
                  	  sink[s].object.volume_step = 5
                  	  sink[s].object:set_volume_percent({97})
                  	  sink[s].object:volume_up()

                  	  assert.are.same({100, 100}, sink[s].object:get_volume_percent())

                  	  sink[s].object:volume_up()

                  	  assert.are.same({105, 105}, sink[s].object:get_volume_percent())
		   		  end
           end)

           b.it("Can step volume up to its maximum", function ()
			   for s=1,total_number_of_sinks do
                  	  sink[s].object:set_volume_percent({sink[s].object.volume_max})

                  	  sink[s].object:volume_up()

                	for _, actual in ipairs(sink[s].object:get_volume_percent()) do
                  	  assert.are.equal(sink[s].object.volume_max, actual)
                	end
		   		end
           end)

           	   b.it("Can step volume down", function ()
		   			for s=1,total_number_of_sinks do
              		  	local volume = sink[s].object:get_volume_percent()
                		local volume_step = sink[s].object.volume_step

                		local expected_volume = {}
                		for i, v in ipairs(volume) do
                		  expected_volume[i] = v - volume_step
                		end

                		sink[s].object:volume_down()

                		assert.are.same(expected_volume, sink[s].object:get_volume_percent())
					end
           end)

           b.it("Will set the volume to 100 the first time step would get it below it", function ()
			   for s=1,total_number_of_sinks do
                  	  sink[s].object.volume_step = 5
                  	  sink[s].object:set_volume_percent({102})
                  	  sink[s].object:volume_down()

                  	  assert.are.same({100, 100}, sink[s].object:get_volume_percent())

                  	  sink[s].object:volume_down()

                  	  assert.are.same({95, 95}, sink[s].object:get_volume_percent())
		   		  end
           end)

           b.it("Will not step the volume below zero", function ()
			   for s=1,total_number_of_sinks do
                  	  sink[s].object:set_volume({0})
                  	  sink[s].object:volume_down()
                  	  for _, actual in ipairs(sink[s].object.Volume) do
                    	assert.are.equal(0, actual)
                  	  end
		   		  end
           end)

           b.it("Will set the volume to zero if the step is too large", function ()
			   for s=1,total_number_of_sinks do
                	sink[s].object:set_volume_percent({1})
                	sink[s].object.volume_step = 100

                	sink[s].object:volume_down()

                	for _, actual in ipairs(sink[s].object.Volume) do
                  	  assert.are.equal(0, actual)
                	end
		   		end
           end)

		   b.it("Will set the next sink as the FallbackSink", function()
		   	   if total_number_of_sinks <= 1 then
				   print("\nWARNING: won't set the next sink as the FallbackSink because there is only one sink available in this machine")
				   return
			   end
			   for s=1,total_number_of_sinks do
			       if core.FallbackSink ~= sink[s].path then
					   core:set_fallback_sink(sink[s].path)
			    	   return
			       end
			   end
		   end)
end)
