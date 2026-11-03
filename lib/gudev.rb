# frozen_string_literal: true

# Released under the Apache License, Version 2.0.
# Copyright, 2026, by General Intelligence Systems.

require "gobject-introspection"

require_relative "gudev/version"
require_relative "gudev/loader"

# Ruby bindings for libgudev, GNOME's GObject wrapper over libudev.
#
# This is the question "what devices does this machine have?", answered out of
# the kernel's sysfs tree. {GUdev::Client} is the handle on udev and does the
# direct lookups; {GUdev::Enumerator} is a filtered search you build up by
# chaining matches and then run; {GUdev::Device} is one device, with its
# identity, its place in the device tree, its udev properties and its sysfs
# attributes.
#
# There is no compiled extension here and nothing in this gem wraps a libgudev
# function by hand. libgudev ships a GObject Introspection typelib describing
# every class, method, property and signal it has, and ruby-gnome's
# GObjectIntrospection::Loader reads that at require time and defines the Ruby
# classes from it. {GUdev::Loader} is 20 lines; what you get is the whole
# library, and it does not drift when libgudev gains a method.
#
# This is how ruby-gnome itself ships gtksourceview5, libsecret and the rest.
#
# Note the module is +GUdev+, with a capital U: it is the typelib's namespace,
# which is what the loader defines. The gem's own +Gudev::VERSION+ is a
# different constant and deliberately so -- it has to be readable by the
# gemspec before any typelib is loaded.
#
# Nothing here needs a display, a session bus or a GLib main loop, which is why
# this namespace is usable from a plain script. The exception is libgudev's
# +uevent+ signal -- devices appearing and disappearing -- which only ever
# emits while a GLib main context is running.
#
# The typelib has to be findable at require time, which means libgudev's
# `girepository-1.0` directory on `GI_TYPELIB_PATH` (or in the system default).
# This gem cannot install it: it is a C library, so it belongs to the
# distribution -- `gir1.2-gudev-1.0` on Debian, `libgudev` on Fedora and Arch,
# `pkgs.libgudev` on nix. The dev shell in `flake.nix` wires it up.
#
# One trap, paid for already: the typelib must come from the same glib build as
# the `gobject-introspection` gem. GUdev-1.0.typelib names GObject-2.0 as its
# one dependency, and two glib builds in one process fail as
# `cannot register existing type`.
module GUdev
  LOG_DOMAIN = "GUdev"
  GLib::Log.set_log_domain(LOG_DOMAIN)

  class Error < StandardError
  end

  loader = Loader.new(self)
  loader.load
end
