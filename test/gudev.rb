# frozen_string_literal: true

# Released under the Apache License, Version 2.0.
# Copyright, 2026, by General Intelligence Systems.

require "gudev"

describe GUdev do
  it "defines the namespace from the typelib" do
    # libgudev is a small library -- three classes and an enum -- so there is
    # no "dozens of constants" to assert here the way there is for a big
    # namespace. What there is is an exact set, and the loader either produced
    # it or half-ran.
    expect(GUdev.constants).to be(:include?, :Client)
    expect(GUdev.constants).to be(:include?, :Device)
    expect(GUdev.constants).to be(:include?, :Enumerator)
    expect(GUdev.constants).to be(:include?, :DeviceType)
    expect(GUdev.constants.size).to be > 5
  end

  it "defines them as GObject classes, not bare Ruby ones" do
    expect(GUdev::Client.ancestors).to be(:include?, GLib::Object)
    expect(GUdev::Device.ancestors).to be(:include?, GLib::Object)
    expect(GUdev::Enumerator.ancestors).to be(:include?, GLib::Object)
  end

  it "defines the device-type enum the typelib declares" do
    expect(GUdev::DeviceType.constants.sort).to be == [:BLOCK, :CHAR, :NONE]
  end

  # A loader that registered the types but defined no methods on them would
  # still satisfy every assertion above, so these three are the ones that catch
  # a half-loaded namespace. Measured against GLib::Object rather than Object,
  # because the GObject plumbing is inherited and would be there either way.
  it "maps libgudev's methods onto Client, not just the constant" do
    own = GUdev::Client.instance_methods - GLib::Object.instance_methods

    [
      :query_by_subsystem,
      :query_by_subsystem_and_name,
      :query_by_device_file,
      :query_by_sysfs_path,
      :query_by_device_number,
    ].each do |name|
      expect(own).to be(:include?, name)
    end
  end

  it "maps libgudev's methods onto Device" do
    own = GUdev::Device.instance_methods - GLib::Object.instance_methods

    expect(own.size).to be > 20
    [
      :sysfs_path, :subsystem, :devtype, :name, :number, :driver,
      :device_file, :device_file_symlinks, :device_number, :device_type,
      :initialized?, :seqnum, :action, :tags, :parent,
      :property_keys, :has_property?, :sysfs_attr_keys, :has_sysfs_attr?,
    ].each do |name|
      expect(own).to be(:include?, name)
    end
  end

  it "maps libgudev's methods onto Enumerator" do
    own = GUdev::Enumerator.instance_methods - GLib::Object.instance_methods

    [
      :add_match_subsystem, :add_nomatch_subsystem, :add_match_name,
      :add_match_property, :add_match_sysfs_attr, :add_nomatch_sysfs_attr,
      :add_match_tag, :add_match_is_initialized, :add_sysfs_path, :execute,
    ].each do |name|
      expect(own).to be(:include?, name)
    end
  end
end

describe GUdev::Client do
  # Everything below runs with no display, no session bus and no main loop,
  # which is the whole reason this namespace is worth having: libudev reads the
  # kernel's sysfs tree directly. So these are not tests about a service that is
  # missing -- they call the real library and assert on what it gives back.
  #
  # What they must not assume is that any particular device exists. A build
  # container has a /sys, but which devices are in it is not ours to decide, so
  # every assertion here is about shape rather than content.
  let(:client) {GUdev::Client.new}

  it "constructs without arguments" do
    expect(client).to be_a(GUdev::Client)
  end

  it "answers a subsystem query with an array of devices" do
    devices = client.query_by_subsystem("block")

    expect(devices).to be_a(Array)
    expect(devices.all?(GUdev::Device)).to be == true
  end

  it "answers an unknown subsystem with an empty array rather than an error" do
    expect(client.query_by_subsystem("no-such-subsystem-#{Process.pid}")).to be(:empty?)
  end

  # libgudev reports a device's absence as NULL, which the binding returns as
  # nil. The three lookups below are given paths and names that cannot exist,
  # so nil is the right answer and an exception would be the bug.
  it "answers a sysfs path that cannot exist with nil" do
    expect(client.query_by_sysfs_path("/sys/nonexistent/#{Process.pid}")).to be(:nil?)
  end

  it "answers a device file that cannot exist with nil" do
    expect(client.query_by_device_file("/dev/nonexistent/#{Process.pid}")).to be(:nil?)
  end

  it "answers a subsystem and name that cannot exist with nil" do
    expect(client.query_by_subsystem_and_name("block", "no-such-#{Process.pid}")).to be(:nil?)
  end

  it "looks a device up by its device number" do
    # 1:3 is /dev/null, a character device on every Linux kernel. Named rather
    # than discovered because the point is the dev_t round trip, and asserted
    # only if it is found because a container need not expose it.
    found = client.query_by_device_number(GUdev::DeviceType::CHAR, (1 << 8) | 3)

    expect(found.device_number).to be == ((1 << 8) | 3) if found
  end
end

describe GUdev::Enumerator do
  let(:client) {GUdev::Client.new}
  let(:enumerator) {GUdev::Enumerator.new(client)}

  # Each builder returns the receiver, which is what makes a chain of matches
  # mean what it looks like: they accumulate on one GUdevEnumerator rather than
  # each call starting a fresh search.
  it "returns the receiver from every match builder, so they chain" do
    expect(enumerator.add_match_subsystem("block")).to be(:equal?, enumerator)
    expect(enumerator.add_match_is_initialized).to be(:equal?, enumerator)
    expect(enumerator.add_match_property("DEVTYPE", "disk")).to be(:equal?, enumerator)
  end

  it "executes to an array of devices" do
    devices = enumerator.add_match_subsystem("block").add_match_is_initialized.execute

    expect(devices).to be_a(Array)
    expect(devices.all?(GUdev::Device)).to be == true
  end

  it "executes to nothing when the matches exclude everything" do
    search = enumerator
      .add_match_subsystem("block")
      .add_match_property("NO_SUCH_PROPERTY_#{Process.pid}", "1")

    expect(search.execute).to be(:empty?)
  end
end

describe GUdev::Device do
  # There is no constructor -- a device has to be found. Which devices a machine
  # has is not ours to decide and a container may have very few, so these walk
  # whatever came back and assert on the shape of it.
  let(:devices) {GUdev::Client.new.query_by_subsystem(nil).first(32)}

  it "finds devices at all, because every Linux /sys has some" do
    expect(devices).not.to be(:empty?)
  end

  it "gives every device a sysfs path, which is its identity" do
    devices.each do |device|
      expect(device.sysfs_path).to be_a(String)
    end
  end

  it "answers the nullable getters with a String or nil, never anything else" do
    devices.each do |device|
      values = [
        device.subsystem, device.devtype, device.name, device.number,
        device.driver, device.device_file, device.action,
      ]

      expect(values.all?{|value| value.nil? || value.is_a?(String)}).to be == true
    end
  end

  it "answers the list getters with arrays of strings" do
    devices.each do |device|
      [device.tags, device.device_file_symlinks, device.property_keys].each do |values|
        expect(values).to be_a(Array)
        expect(values.all?(String)).to be == true
      end
    end
  end

  it "names the device number's space as a member of the enum" do
    devices.each do |device|
      expect(GUdev::DeviceType.constants).to be(:include?, device.device_type.nick.upcase.to_sym)
    end
  end

  # #get_property here is libgudev's, not GLib::Object's: the typelib's
  # g_udev_device_get_property lands on the same name and shadows it. Worth
  # pinning, because a caller reading udev properties relies on that.
  it "reads back the udev properties it says it has" do
    devices.each do |device|
      device.property_keys.first(8).each do |key|
        expect(device.has_property?(key)).to be == true
        expect(device.get_property(key)).to be_a(String)
      end
    end
  end

  # udev has no error return for a property that is not set: the string getter
  # gives nil, each numeric coercion gives its own type's zero, and the strv
  # coercion gives nil rather than an empty array. A Ruby program branching on
  # these needs that to stay true, so it is asserted rather than assumed.
  it "reports a property that is not there as nil, and its coercions as zero" do
    absent = "NO_SUCH_PROPERTY_#{Process.pid}"

    devices.each do |device|
      expect(device.has_property?(absent)).to be == false
      expect(device.get_property(absent)).to be(:nil?)
      expect(device.get_property_as_int(absent)).to be == 0
      expect(device.get_property_as_uint64(absent)).to be == 0
      expect(device.get_property_as_double(absent)).to be == 0.0
      expect(device.get_property_as_boolean(absent)).to be == false
      expect(device.get_property_as_strv(absent)).to be(:nil?)
    end
  end

  it "reports a sysfs attribute that is not there the same way" do
    absent = "no_such_attr_#{Process.pid}"

    devices.each do |device|
      expect(device.has_sysfs_attr?(absent)).to be == false
      expect(device.get_sysfs_attr(absent)).to be(:nil?)
      expect(device.get_sysfs_attr_as_int(absent)).to be == 0
      expect(device.get_sysfs_attr_as_boolean(absent)).to be == false
      expect(device.get_sysfs_attr_as_strv(absent)).to be(:nil?)
    end
  end

  # Walking up the tree has to terminate, and every step has to be a Device.
  # The walk is bounded and the bound is asserted rather than trusted.
  it "walks the parent chain to a root" do
    devices.each do |device|
      steps = 0
      current = device.parent

      while current && steps <= 64
        expect(current).to be_a(GUdev::Device)
        current = current.parent
        steps += 1
      end

      expect(current).to be(:nil?)
    end
  end

  it "answers an ancestor query for a subsystem nothing is under with nil" do
    devices.each do |device|
      expect(device.get_parent_with_subsystem("no-such-#{Process.pid}", nil)).to be(:nil?)
    end
  end
end
