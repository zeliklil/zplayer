
-- ZPlayer Gstreamer backend

local lgi  = require 'lgi'
local GLib = lgi.GLib
local Gst  = lgi.require('Gst', '0.10')
--local Gst  = lgi.Gst
if tonumber(Gst._version) >= 1.0 then
   local GstVideo = lgi.GstVideo
end

local function make()
   local player = {}
   
   function player:on_error(error)
      print(error)
   end
   function player:on_eos()
      print 'end of stream'
      self:destroy()
   end
   function player:on_state_changed(old, new, pending)
      player._state = new
   end
   
   local function bus_callback(bus, message)
      if message.type.ERROR then
         player:on_error(message:parse_error().message)
      end
      if message.type.EOS then
         player:on_eos()
      end
      if message.type.STATE_CHANGED then
        local old, new, pending = message:parse_state_changed()
        player:on_state_changed(old, new, pending)
      end
      return true
   end
   
   local function make_pipeline()
      local pipeline = Gst.Pipeline.new('pipeline')
      local elements = {}
      local playbin = Gst.ElementFactory.make('playbin', 'playbin')
      local vsink = Gst.ElementFactory.make('xvimagesink', 'sink')
      playbin.video_sink = vsink
      vsink.force_aspect_ratio = true
      
      pipeline:add_many(playbin)
      pipeline.bus:add_watch(GLib.PRIORITY_DEFAULT, bus_callback)
   
      elements = {playbin = playbin, vsink = vsink}
      return pipeline, elements
   end
   
   function player:toggle_pause()
      if (self._state == 'PLAYING') then
         self._pipeline.state = 'PAUSED'
      elseif (self._state == 'PAUSED') then
         self._pipeline.state = 'PLAYING'
      else
         print('Oops: State is ' .. self._state)
      end
   end
   function player:get_info()
      local ns_to_str = function(ns)
         if (not ns) then return nil end
         seconds = ns / Gst.SECOND
         minutes = math.floor(seconds / 60)
         seconds = math.floor(seconds - (minutes * 60))
         str = minutes .. ':' .. seconds
         return str
      end
      format, position_ns = self._elements.playbin:query_position(Gst.Format.TIME)
      format, duration_ns = self._elements.playbin:query_duration(Gst.Format.TIME)
      position = position_ns and ns_to_str(position_ns) or ''
      duration = duration_ns and ns_to_str(duration_ns) or ''
      volume = string.match(self._elements.playbin.volume, '%d*%.?%d%d?')
      return position .. ' / ' .. duration .. ' v' .. volume .. '%'
   end
   function player:raise_volume(diff)
      volume = self._elements.playbin.volume + diff
      if (volume < 0) then
         self._elements.playbin.volume = 0
      elseif (volume > 10) then
         self._elements.playbin.volume = 10
      else
         self._elements.playbin.volume = volume
      end
   end
   function player:debug()
      print(self._elements.playbin:query_position(3))
   end
   function player:seek(offset)
      format, position = self._elements.playbin:query_position(Gst.Format.TIME)
      if (not position) then
         print('Oops, cannot get position')
         return
      end
      local seek = position + (offset * Gst.SECOND)
      self._elements.playbin:seek_simple(format, {Gst.SeekFlags.FLUSH, Gst.SeekFlags.KEY_UNIT}, seek)
   end
   
   function player:setURI(uri)
      self._elements.playbin.uri = uri
   end
   
   function player:attach(xid)
      self._elements.vsink:set_window_handle(xid)
   end
   
   function player:play()
      self._pipeline.state = 'PLAYING'
      self._state = 'PLAYING'
   end
   
   function player:init()
      self._pipeline, self._elements = make_pipeline()
   end
   
   function player:destroy()
      self._pipeline.state = 'NULL'
   end

   return player
end

return make

-- vim:expandtab:softtabstop=3:shiftwidth=3
