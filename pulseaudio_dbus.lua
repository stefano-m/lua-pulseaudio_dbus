--[[
  Copyright 2017 Stefano Mazzucco

  Licensed under the Apache License, Version 2.0 (the "License");
  you may not use this file except in compliance with the License.
  You may obtain a copy of the License at

  http://www.apache.org/licenses/LICENSE-2.0

  Unless required by applicable law or agreed to in writing, software
  distributed under the License is distributed on an "AS IS" BASIS,
  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
  See the License for the specific language governing permissions and
  limitations under the License.
]]

--[[--
  Control audio devices using the
  [pulseaudio DBus interface](https://www.freedesktop.org/wiki/Software/PulseAudio/Documentation/Developer/Clients/DBus/).

  For this to work, you need the line
  `load-module module-dbus-protocol`
  in `/etc/pulse/default.pa`
  or `~/.config/pulse/default.pa`

  @usage
  pulse = require("pulseaudio_dbus")
  address = pulse.get_address()
  connection = pulse.get_connection(address)
  core = pulse.get_core(connection)
  sink = pulse.get_device(address, core:get_sinks()[1])
  sink:set_muted(true)
  sink:toggle_muted()
  assert(not sink:is_muted())
  sink:set_volume_percent({75}) -- sets the volume to 75%

  @license Apache License, version 2.0
  @author Stefano Mazzucco <stefano AT curso DOT re>
  @copyright 2017 Stefano Mazzucco
]]

local proxy = require("dbus_proxy")
local lgi =  require("lgi")
local DBusConnectionFlags = lgi.Gio.DBusConnectionFlags


local function _update_table(from_t, to_t)
  for k, v in pairs(from_t) do
    assert(to_t[k] == nil, "Cannot override attribute " .. k)
    to_t[k] = v
  end
end


local pulse = {}

--- Get the pulseaudio DBus address
-- @return a string representing the pulseaudio
-- [DBus address](https://dbus.freedesktop.org/doc/dbus-tutorial.html#addresses).
function pulse.get_address()
  local server = proxy.Proxy:new(
    {
      bus=proxy.Bus.SESSION,
      name="org.PulseAudio1",
      path="/org/pulseaudio/server_lookup1",
      interface="org.PulseAudio.ServerLookup1"
    }
  )
  return server.Address
end

--- Get a connection to the pulseaudio server
-- @tparam string address DBus address
-- @tparam[opt] boolean dont_assert whether we should *not* assert that the
-- connection is closed.
-- @return an `lgi.Gio.DBusConnection` to the pulseaudio server
-- @see pulse.get_address
function pulse.get_connection(address, dont_assert)

  local bus = lgi.Gio.DBusConnection.new_for_address_sync(
                     address,
                     DBusConnectionFlags.AUTHENTICATION_CLIENT)

  if not dont_assert then
    assert(not bus.closed,
           string.format("Bus from '%s' is closed!", address))
  end

  return bus
end

--- Pulseaudio
-- [core server functionality](https://www.freedesktop.org/wiki/Software/PulseAudio/Documentation/Developer/Clients/DBus/Core/)
-- @type Core
pulse.Core = {}

--- Get all currently available sinks.
-- Note the the `Sinks` property may not be up-to-date.
-- @return array of all available object path sinks
function pulse.Core:get_sinks()
  return self:Get("org.PulseAudio.Core1", "Sinks")
end

--- Get all currently available cards.
-- Note the the `Cards` property may not be up-to-date.
-- @return array of all available object path cards
function pulse.Core:get_cards()
    return self:Get("org.PulseAudio.Core1", "Cards")
end

--- Get all currently available sources.
-- Note the the `Sources` property may not be up-to-date.
-- @return array of all available object path sources
function pulse.Core:get_sources()
    return self:Get("org.PulseAudio.Core1", "Sources")
end

--- Get the current fallback source object path
-- @return fallback source object path
-- @return nil if no falback source is set
-- @see pulse.Core:set_fallback_source
function pulse.Core:get_fallback_source()
  return self:Get("org.PulseAudio.Core1", "FallbackSource")
end

--- Set the current fallback source object path
-- @tparam string value fallback source object path
-- @see pulse.Core:get_fallback_source
function pulse.Core:set_fallback_source(value)
  self:Set("org.PulseAudio.Core1.Device",
           "FallbackSource",
           lgi.GLib.Variant("o", value))
  self.Volume = {signature="o", value=value}
end

--- Get the pulseaudio [core object](https://www.freedesktop.org/wiki/Software/PulseAudio/Documentation/Developer/Clients/DBus/Core/)
-- @tparam lgi.Gio.DBusConnection connection DBus connection to the
-- pulseaudio server
-- @return the pulseaudio core object that allows you to access the
-- various sound devices
function pulse.get_core(connection)
  local core = proxy.Proxy:new(
    {
      bus=connection,
      name=nil, -- nil, because bus is *not* a message bus.
      path="/org/pulseaudio/core1",
      interface="org.PulseAudio.Core1"
    }
  )

  _update_table(pulse.Core, core)

  return core
end

--- Pulseaudio
-- [Device](https://www.freedesktop.org/wiki/Software/PulseAudio/Documentation/Developer/Clients/DBus/Device/). <br>
-- Use @{pulse.get_device} to obtain a device object.
-- @type Device
pulse.Device = {}

-- https://www.freedesktop.org/wiki/Software/PulseAudio/Documentation/Developer/Clients/DBus/Enumerations/
local device_states = {
  "running",  -- the device is being used by at least one non-corked stream.
  "idle",     -- the device is active, but no non-corked streams are connected to it.
  "suspended" -- the device is not in use and may be currently closed.
}

--- Get the current state of the device. This can be one of:
--
-- - "running": the device is being used by at least one non-corked stream.
-- - "idle": the device is active, but no non-corked streams are connected to it.
-- - "suspended": the device is not in use and may be currently closed.
-- @return the device state as a string
function pulse.Device:get_state()
  local current_state =  self:Get("org.PulseAudio.Core1.Device",
                                  "State")
  return device_states[current_state + 1]
end

--- Get the volume of the device.
-- You could also use the `Device.Volume` field, but it's not guaranteed
-- to be in sync with the actual changes.
-- @return the volume of the device as an array of numbers
-- (one number) per channel
-- @see pulse.Device:get_volume_percent
function pulse.Device:get_volume()
  return self:Get("org.PulseAudio.Core1.Device",
                  "Volume")
end

--- Get the volume of the device as a percentage.
-- @return the volume of the device as an array of numbers
-- (one number) per channel
-- @see pulse.Device:get_volume
function pulse.Device:get_volume_percent()
  local volume = self:get_volume()

  local volume_percent = {}
  for i, v in ipairs(volume) do
    volume_percent[i] = math.ceil(v / self.BaseVolume * 100)
  end

  return volume_percent
end

--- Set the volume of the device on each channel.
-- You could also use the `Device.Volume` field, but it's not guaranteed
-- to be in sync with the actual changes.
-- @tparam table value an array with the value of the volume.
-- If the array contains only one element, its value will be set
-- for all channels.
-- @see pulse.Device:set_volume_percent
function pulse.Device:set_volume(value)
  self:Set("org.PulseAudio.Core1.Device",
           "Volume",
           lgi.GLib.Variant("au", value))
  self.Volume = {signature="au", value=value}
end

--- Set the volume of the device as a percentage on each channel.
-- @tparam table value an array with the value of the volume.
-- If the array contains only one element, its value will be set
-- for all channels.
-- @see pulse.Device:set_volume
function pulse.Device:set_volume_percent(value)
  local volume = {}
  for i, v in ipairs(value) do
    volume[i] = v * self.BaseVolume / 100
  end
  self:set_volume(volume)
end

--- Step up the volume (percentage) by an amount equal to
-- `self.volume_step`.
-- Calling this function will never set the volume above `self.volume_max`
-- @see pulse.Device:volume_down
function pulse.Device:volume_up()
  local volume = self:get_volume_percent()
  local up
  for i, v in ipairs(volume) do
    up = v + self.volume_step
    if up > self.volume_max then
      volume[i] = self.volume_max
    else
      volume[i] = up
    end
  end
  self:set_volume_percent(volume)
end

--- Step down the volume (percentage) by an amount equal to
-- `self.volume_step`.
-- Calling this function will never set the volume below zero (which is,
-- by the way, an error).
-- @see pulse.Device:volume_up
function pulse.Device:volume_down()
  local volume = self:get_volume_percent()
  local down
  for i, v in ipairs(volume) do
    down = v - self.volume_step
    if down >= 0 then
      volume[i] = down
    else
      volume[i] = 0
    end
  end
  self:set_volume_percent(volume)
end

--- Get whether the device is muted.
-- @return a boolean value that indicates whether the device is muted.
-- @see pulse.Device:toggle_muted
-- @see pulse.Device:set_muted
function pulse.Device:is_muted()
  return self:Get("org.PulseAudio.Core1.Device",
                  "Mute")
end

--- Set the muted state of the device.
-- @tparam boolean value whether the device should be muted
-- You could also use the `Device.Mute` field, but it's not guaranteed
-- to be in sync with the actual changes.
-- @see pulse.Device:is_muted
-- @see pulse.Device:toggle_muted
function pulse.Device:set_muted(value)
  self:Set("org.PulseAudio.Core1.Device",
           "Mute",
           lgi.GLib.Variant("b", value))
  self.Mute = {signature="b", value=value}
end

--- Toggle the muted state of the device.
-- @return a boolean value that indicates whether the device is muted.
-- @see pulse.Device:set_muted
-- @see pulse.Device:is_muted
function pulse.Device:toggle_muted()
  local muted = self:is_muted()
  self:set_muted(not muted)
  return self:is_muted()
end

--- Get an DBus proxy object to a pulseaudio
-- [Device](https://www.freedesktop.org/wiki/Software/PulseAudio/Documentation/Developer/Clients/DBus/Device/). <br>
-- Setting a property will be reflected on the pulseaudio device.
-- Trying to set other properties will result in an error.
-- @tparam lgi.Gio.DBusConnection connection The connection to pulseaudio
-- @tparam string path The device object path as a string
-- @tparam[opt] number volume_step The volume step in % (defaults to 5)
-- @tparam[opt] number volume_max The maximum volume in % (defaults to 150)
-- @return A new Device object
-- @see pulse.get_connection
-- @see pulse.get_core
-- @usage
-- -- get a pulseaudio sink (e.g. audio output)
-- sink = pulse.get_device(address, core:get_sinks()[1])
-- -- get a pulseaudio source (e.g. microphone)
-- source = pulse.get_device(address, core:get_sources([1]))
function pulse.get_device(connection, path, volume_step, volume_max)
  local device = proxy.Proxy:new(
    {
      bus=connection,
      name=nil,
      path=path,
      interface="org.PulseAudio.Core1.Device"
    }
  )

  device.volume_step = volume_step or 5
  device.volume_max = volume_max or 150

  _update_table(pulse.Device, device)

  return device
end

return pulse
