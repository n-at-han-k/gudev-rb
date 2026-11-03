# frozen_string_literal: true

# Released under the Apache License, Version 2.0.
# Copyright, 2026, by General Intelligence Systems.

module GUdev
  # Defines everything in the GUdev namespace from `GUdev-1.0.typelib`.
  #
  # Modelled on ruby-gnome's own loaders -- see
  # gtksourceview5/lib/gtksourceview5/loader.rb for one that has to call the
  # library's init function first, and libsecret/lib/libsecret/loader.rb for
  # one that does not.
  #
  # The version string is the typelib's rather than the library's release
  # number, and the two differ here: libgudev 238 ships `GUdev-1.0.typelib`,
  # so the version is "1.0".
  class Loader < GObjectIntrospection::Loader
    def load
      self.version = "1.0"
      super("GUdev")
    end

    private

    # There is no `g_udev_init`: GUdev-1.0.typelib declares no namespace-level
    # functions at all -- every entry point is a method on Client, Device or
    # Enumerator, and a GUdevClient is live the moment it is constructed. So
    # there is no pre_load hook here, unlike GtkSource's loader which has to
    # call `gtk_source_init` before anything else will work. This is Secret's
    # situation rather than GtkSource's, and the suite asserts it by
    # constructing a client and running a real query.

    def post_load(repository, namespace)
      require_libraries
    end

    def require_libraries
      # Nothing yet. Hand-written Ruby that improves on what the typelib gives
      # -- an each that yields, a to_s, a properties hash built from
      # property_keys -- goes in files required from here, which is the
      # convention ruby-gnome uses for exactly that purpose.
    end
  end
end
