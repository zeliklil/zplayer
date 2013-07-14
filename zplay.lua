#! /usr/bin/env lua

-- ZPlayer

local lgi  = require 'lgi'
local GLib = lgi.GLib
local Gtk  = lgi.Gtk
local Gdk  = lgi.Gdk
local GdkX11 = lgi.GdkX11
local Gio  = lgi.Gio
local gstPlayer = require 'gst_backend'

local app = Gtk.Application.new ('org.zplayer',Gio.ApplicationFlags.HANDLES_OPEN)
window = nil

local player = gstPlayer()
function player:on_eos()
   self:destroy()
   window:destroy()
end

local function updateInfo()
   window.title = player:get_info()
end

keybindings = {
   [string.byte(' ')] = function() player:toggle_pause() end,
   [Gdk.KEY_Left] = function() player:seek(-10) end,
   [Gdk.KEY_Right] = function() player:seek(10) end,
   [Gdk.KEY_Down] = function() player:seek(-60) end,
   [Gdk.KEY_Up] = function() player:seek(60) end,
   [Gdk.KEY_Escape] = function() player:on_eos() end,
   [string.byte('*')] = function() player:raise_volume(0.1) end,
   [string.byte('/')] = function() player:raise_volume(-0.1) end,
   [string.byte('d')] = function() player:debug() end,
   [string.byte('o')] = function() window.title = player:get_info() end,
}

function create_window()
   local window = Gtk.Window {
      application = app,
      title = "ZPlayer",
      Gtk.Box {
         orientation = 'VERTICAL',
         Gtk.DrawingArea {
   	 id = 'video',
   	 expand = true,
   	 width = 300,
   	 height = 150,
         },
      }
   }
   function window.child.video:on_realize()
      player:attach(self.window:get_xid())
      player:play()
   end
   function window:on_key_press_event(event)
      f = keybindings[event.keyval]
      if f then
         f()
         updateInfo()
      end
   end
   window:show_all()
   return window
end

function app:on_activate()
   window = create_window()
end

function app:on_open(files)
   file = files[1] and files[1]:get_parse_name() --or 'v4l2:///dev/video'
   if(file) then
      if (string.find(file, '://')) then
         uri = file
      else
         uri = 'file://' .. file
      end
   end
   print('Playing', uri)
   player:init()
   player:setURI(uri)
   window = create_window()
end

app:run { arg[0], ... }

-- vim:expandtab:softtabstop=3:shiftwidth=3
