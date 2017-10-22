-- Works with the 'busted' framework.
-- http://olivinelabs.com/busted/

package.path = "../?.lua;" .. package.path
local b = require("busted")

local pulse = require("pulseaudio_dbus")

b.describe("PulseAudio with DBus", function ()
           b.before_each(function ()
               address = pulse.get_address()
               connection = pulse.get_connection(address)
               core = pulse.get_core(connection)
			   sink = {}
			   total_number_of_sinks = #core.Sinks
			   for s=1,total_number_of_sinks do
    			   sink[s] = pulse.get_device(connection, assert(core.Sinks[s]))
				   sink[s].original = {}
                   sink[s].original.volume = sink[s]:get_volume()
                   sink[s].original.muted = sink[s]:is_muted()
			   end
           end)

           b.after_each(function ()
			   for s=1,total_number_of_sinks do
               	   sink[s]:set_volume(sink[s].original.volume)
               	   sink[s]:set_muted(sink[s].original.muted)
               	   sink[s] = nil
			   end
           end)

           b.it("Can get properties", function ()
			    for s=1,total_number_of_sinks do
                    local volume = sink[s].Volume
                    assert.is_boolean(sink[s].Mute)
                    assert.is_table(volume)
                    assert.is_number(volume[1])
                    assert.is_nil(sink[s].something_else)
                    assert.is_string(sink[s].ActivePort)
                    assert.is_equal("port", sink[s].ActivePort:match("port"))
				end
				assert.is_string(core.FallbackSink)
				assert.is_table(core.PlaybackStreams)
           end)

           b.it("Can set same volume for all channels", function ()
			   for s=1,total_number_of_sinks do
                	sink[s]:set_volume({50})
                	assert.are.same({50, 50}, sink[s]:get_volume())
		   		end
           end)

           b.it("Can set different volume for different channels", function ()
			   for s=1,total_number_of_sinks do
                  	  sink[s]:set_volume({50, 0})
                	assert.are.same({50, 0}, sink[s].Volume)
		   		end
           end)

           b.it("Can set muted", function ()
			   for s=1,total_number_of_sinks do
                	sink[s]:set_muted(true)
                	assert.is_true(sink[s].Mute)
                	sink[s]:set_muted(false)
                	assert.is_false(sink[s].Mute)
		   		end
           end)

           b.it("Can toggle muted", function ()
			   for s=1,total_number_of_sinks do
                  	  assert.are.equal(sink[s]:is_muted(), not sink[s]:toggle_muted())
		   		  end
           end)

           b.it("Can get the state", function ()
			   for s=1,total_number_of_sinks do
                  	  local available_states = {"running",
                                            	"idle",
                                            	"suspended"}

                  	  local state = sink[s]:get_state()

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
                	local volume = sink[s]:get_volume_percent()
                	local volume_step = sink[s].volume_step

                	local expected_volume = {}
                	for i, v in ipairs(volume) do
                  	  expected_volume[i] = v + volume_step
                	end

                	sink[s]:volume_up()

                	assert.are.same(expected_volume,
                                	sink[s]:get_volume_percent())
		   						end
           end)

           b.it("Will set the volume to 100 the first time step would get it above it", function ()
			   for s=1,total_number_of_sinks do
                  	  sink[s].volume_max = 110
                  	  sink[s].volume_step = 5
                  	  sink[s]:set_volume_percent({97})
                  	  sink[s]:volume_up()

                  	  assert.are.same({100, 100}, sink[s]:get_volume_percent())

                  	  sink[s]:volume_up()

                  	  assert.are.same({105, 105}, sink[s]:get_volume_percent())
		   		  end
           end)

           b.it("Can step volume up to its maximum", function ()
			   for s=1,total_number_of_sinks do
                  	  sink[s]:set_volume_percent({sink[s].volume_max})

                  	  sink[s]:volume_up()

                	for _, actual in ipairs(sink[s]:get_volume_percent()) do
                  	  assert.are.equal(sink[s].volume_max, actual)
                	end
		   		end
           end)

           	   b.it("Can step volume down", function ()
		   			for s=1,total_number_of_sinks do
              		  	local volume = sink[s]:get_volume_percent()
                		local volume_step = sink[s].volume_step

                		local expected_volume = {}
                		for i, v in ipairs(volume) do
                		  expected_volume[i] = v - volume_step
                		end

                		sink[s]:volume_down()

                		assert.are.same(expected_volume, sink[s]:get_volume_percent())
					end
           end)

           b.it("Will set the volume to 100 the first time step would get it below it", function ()
			   for s=1,total_number_of_sinks do
                  	  sink[s].volume_step = 5
                  	  sink[s]:set_volume_percent({102})
                  	  sink[s]:volume_down()

                  	  assert.are.same({100, 100}, sink[s]:get_volume_percent())

                  	  sink[s]:volume_down()

                  	  assert.are.same({95, 95}, sink[s]:get_volume_percent())
		   		  end
           end)

           b.it("Will not step the volume below zero", function ()
			   for s=1,total_number_of_sinks do
                  	  sink[s]:set_volume({0})
                  	  sink[s]:volume_down()
                  	  for _, actual in ipairs(sink[s].Volume) do
                    	assert.are.equal(0, actual)
                  	  end
		   		  end
           end)

           b.it("Will set the volume to zero if the step is too large", function ()
			   for s=1,total_number_of_sinks do
                	sink[s]:set_volume_percent({1})
                	sink[s].volume_step = 100

                	sink[s]:volume_down()

                	for _, actual in ipairs(sink[s].Volume) do
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
			       if core.FallbackSink ~= sink[s].object_path then
					   core:set_fallback_sink(sink[s].object_path)
			    	   return
			       end
			   end
		   end)

		   b.it("Will Cycle through all available PlaybackStreams and move them to the FallbackSink", function()
		   	   if #core.PlaybackStreams == 0 then
				   print("\nWARNING: Can't cycle through all available PlaybackStreams and move them to the FallbackSink because there are no PlaybackStreams in this machine")
				   return
			   else
				   stream = {}
			   	   for ps=1,#core.PlaybackStreams do
					   stream[ps] = {}
					   stream[ps].path = core.PlaybackStreams[ps]
					   stream[ps].object = pulse.get_stream(connection, stream[ps].path)
					   stream[ps].object:Move(core.FallbackSink)
				   end
			   end
		   end)
end)
