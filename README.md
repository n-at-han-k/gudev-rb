# gudev

Ruby bindings for [libgudev](https://gitlab.gnome.org/GNOME/libgudev), GNOME's
GObject wrapper over libudev: what devices does this machine have, read out of
the kernel's sysfs tree.

```ruby
require "gudev"

client = GUdev::Client.new

client.query_by_subsystem("block").each do |device|
  puts "#{device.name}\t#{device.device_file}\t#{device.get_property("ID_MODEL")}"
end

# Or build a filtered search and run it.
disks = GUdev::Enumerator.new(client)
  .add_match_subsystem("block")
  .add_match_property("DEVTYPE", "disk")
  .execute
```

No display, no session bus and no GLib main loop — this works from a plain
script. The one exception is libgudev's `uevent` signal, devices appearing and
disappearing, which only emits while a GLib main context is running.

## How this works, and what it costs to install

libgudev ships a GObject Introspection typelib — `GUdev-1.0.typelib` —
describing every class, method, property and signal it has. `GUdev::Loader`,
about twenty lines, hands that to ruby-gnome's
`GObjectIntrospection::Loader`, which defines the Ruby classes from it at
`require` time.

So there is no extension of its own here, no Cargo workspace and no
per-platform binary. You get the whole library rather than the subset somebody
got round to wrapping by hand, and it does not drift when libgudev gains API.

Be precise about install, though. `gem install gudev` still compiles C, because
`gobject-introspection` and `glib2` both declare `spec.extensions` and build
against glib — so a compiler and glib's development headers are needed. What
this gem adds on top of that is nothing: those two are the extensions every
ruby-gnome application already has, since `gtk4` depends on them. If you are
writing a Ruby GNOME app, gudev costs you no build step you were not already
paying.

This is how [ruby-gnome](https://github.com/ruby-gnome/ruby-gnome) itself ships
gtksourceview5, libsecret and the rest.

## The one thing you must install

The typelib is a C-library artefact, so it belongs to your distribution and
this gem cannot install it:

| | |
|---|---|
| Debian / Ubuntu | `gir1.2-gudev-1.0` (the library is `libgudev-1.0-0`) |
| Fedora | `libgudev` |
| Arch | `libgudev` |
| nix | `pkgs.libgudev` |

If it is not in the default search path, point `GI_TYPELIB_PATH` at the
directory holding `GUdev-1.0.typelib`. The dev shell in `flake.nix` does this.

**One trap worth knowing.** The typelib must come from the same glib build as
the `gobject-introspection` gem. `GUdev-1.0.typelib` names `GObject-2.0` as its
one dependency, and two glib builds in one process fail with
`cannot register existing type`. Under nix, take both from one nixpkgs — and
note that glib's typelibs live in its `out` output, not the default `bin` one.

## What the namespace gives you

| | |
|---|---|
| `GUdev::Client` | the handle on udev; direct lookups by subsystem, name, device file, sysfs path or device number |
| `GUdev::Enumerator` | a filtered search built up by chaining `add_match_*` / `add_nomatch_*` and then `execute` |
| `GUdev::Device` | one device: its identity, its place in the tree, its udev properties and its sysfs attributes |
| `GUdev::DeviceType` | `BLOCK`, `CHAR`, `NONE` — the space a device number lives in |

udev has no error return for something that is not set: a missing property or
sysfs attribute reads back as `nil`, and the numeric coercions
(`get_property_as_int` and friends) give their own type's zero. The suite pins
that, because it is what a caller branches on.

## Development

```sh
nix develop
bin/test
```

## Licence

Apache-2.0. libgudev itself is LGPL-2.1-or-later; this gem links nothing and
copies no libgudev code — it reads a description of it at runtime.
