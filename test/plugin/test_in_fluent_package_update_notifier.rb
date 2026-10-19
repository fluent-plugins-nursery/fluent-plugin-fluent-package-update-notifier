require 'helper'
require 'fluent/plugin/in_fluent_package_update_notifier'
require 'tmpdir'
require 'securerandom'

class FluentPackageUpdateNotifierInputTest < Test::Unit::TestCase

  setup do
    Fluent::Test.setup
    @tmp_dir = tmp_dir
    FileUtils.mkdir_p(@tmp_dir)
  end

  teardown do
    Fluent::Engine.stop
    cleanup_directory(@tmp_dir)
  end

  def tmp_dir
    File.join(File.dirname(__FILE__), "..", "tmp", SecureRandom.hex(10))
  end

  def cleanup_directory(path)
    FileUtils.remove_entry_secure(path, true)
  end

  def config
    %[
      log_level info
    ]
  end

  test "multi worker" do
    d = create_driver
    assert_true d.instance.multi_workers_ready?
  end

  sub_test_case "configuration test" do
    test "default configuration" do
      assert_nothing_raised do
        d = create_driver
        expected = [true, true, :info]
        assert_equal(expected, [d.instance.lts,
                                d.instance.notify_major_upgrade,
                                d.instance.notify_level])
      end
    end

    test "disable LTS channel" do
      assert_nothing_raised do
        d = create_driver(%[lts false])
        assert_equal(false, d.instance.lts)
      end
    end

    test "disable notifying major upgrade" do
      assert_nothing_raised do
        d = create_driver(%[notify_major_upgrade false])
        assert_equal(false, d.instance.notify_major_upgrade)
      end
    end

    test "change notify_level to :info" do
      assert_nothing_raised do
        d = create_driver(%[notify_level info])
        assert_equal(:info, d.instance.notify_level)
      end
    end
  end

  def write_config_version(version = "5.0.6")
    File.open(ENV["FLUENT_PACKAGE_CONFIG"], "w+") { |f| f.puts("PACKAGE_VERSION = \"#{version}\"") }
  end

  def cache_tags_path(path, versions)
    results = versions.collect do |version|
      { "name": "v#{version}" }
    end
    File.open(path, "w+") { |f| f.puts(JSON.dump(results)) }
  end

  sub_test_case "LTS channel updates" do
    setup do
      ENV["FLUENT_PACKAGE_CONFIG"] = "#{@tmp_dir}/config.rb"
      ENV["FLUENT_PACKAGE_TAGS_PATH"] = "#{@tmp_dir}/tags.json"
      stub.instance_of(Fluent::Plugin::FluentPackage::UpdateChecker).check_package_released?(anything) { true }
    end

    test "no LTS update" do
      assert_nothing_raised do
        write_config_version
        cache_tags_path(ENV["FLUENT_PACKAGE_TAGS_PATH"], ["5.0.6"])
        d = create_driver
        d.run
        assert_match(/\[info\]: No update for fluent-package 5.0.6/, d.logs.last)
      end
    end

    data("notify info" => "info",
         "notify warn" => "warn")
    test "teeny LTS update is available " do |level|
      assert_nothing_raised do
        write_config_version
        cache_tags_path(ENV["FLUENT_PACKAGE_TAGS_PATH"], ["5.0.7", "5.0.6"])
        d = create_driver("notify_level #{level}")
        d.run
        assert_match(/\[#{level}\]: fluent-package v5.0.7 is available/, d.logs.last)
      end
    end

    data("notify info" => "info",
         "notify warn" => "warn")
    test "major LTS upgrade is available " do |level|
      assert_nothing_raised do
        write_config_version
        cache_tags_path(ENV["FLUENT_PACKAGE_TAGS_PATH"], ["6.0.1", "6.0.0", "5.0.7", "5.0.6"])
        d = create_driver(%[
          notify_major_upgrade
          notify_level #{level}
        ])
        d.run
        assert_match(/\[#{level}\]: fluent-package v6.0.1 is available/, d.logs.last)
      end
    end

    data("notify info" => "info",
         "notify warn" => "warn")
    test "major LTS upgrade (6.0.x) is available " do |level|
      assert_nothing_raised do
        write_config_version
        cache_tags_path(ENV["FLUENT_PACKAGE_TAGS_PATH"], ["6.1.0", "6.0.1", "6.0.0", "5.0.7", "5.0.6"])
        d = create_driver(%[
          notify_major_upgrade
          notify_level #{level}
        ])
        d.run
        # 6.1.0 should be ignored
        assert_match(/\[#{level}\]: fluent-package v6.0.1 is available/, d.logs.last)
      end
    end
  end

  sub_test_case "standard channel updates" do
    setup do
      ENV["FLUENT_PACKAGE_CONFIG"] = "#{@tmp_dir}/config.rb"
      ENV["FLUENT_PACKAGE_TAGS_PATH"] = "#{@tmp_dir}/tags.json"
      stub.instance_of(Fluent::Plugin::FluentPackage::UpdateChecker).check_package_released?(anything) { true }
    end

    test "no update" do
      assert_nothing_raised do
        write_config_version("5.2.0")
        cache_tags_path(ENV["FLUENT_PACKAGE_TAGS_PATH"], ["5.2.0"])
        d = create_driver(%[
          lts false
        ])
        d.run
        d.logs
        assert_match(/\[info\]: No update for fluent-package 5.2.0/, d.logs.last)
      end
    end

    data("notify info" => "info",
         "notify warn" => "warn")
    test "teeny update is available " do |level|
      assert_nothing_raised do
        write_config_version("5.2.0")
        cache_tags_path(ENV["FLUENT_PACKAGE_TAGS_PATH"], ["5.2.1", "5.2.0"])
        d = create_driver(%[
          lts false
          notify_level #{level}
        ])
        d.run
        assert_match(/\[#{level}\]: fluent-package v5.2.1 is available/, d.logs.last)
      end
    end

    data("notify info" => "info",
         "notify warn" => "warn")
    test "major upgrade (6.0.x) is available" do |level|
      assert_nothing_raised do
        write_config_version("5.1.0")
        cache_tags_path(ENV["FLUENT_PACKAGE_TAGS_PATH"], ["6.0.1", "6.0.0", "5.2.0"])
        d = create_driver(%[
          lts false
          notify_major_upgrade
          notify_level #{level}
        ])
        d.run
        assert_match(/\[#{level}\]: fluent-package v6.0.1 is available/, d.logs.last)
      end
    end

    data("notify info" => "info",
         "notify warn" => "warn")
    test "major upgrade (6.x) is available " do |level|
      assert_nothing_raised do
        write_config_version("5.1.0")
        cache_tags_path(ENV["FLUENT_PACKAGE_TAGS_PATH"], ["6.1.0", "6.0.1", "6.0.0", "5.2.0"])
        d = create_driver(%[
          lts false
          notify_major_upgrade
          notify_level #{level}
        ])
        d.run
        assert_match(/\[#{level}\]: fluent-package v6.1.0 is available/, d.logs.last)
      end
    end
  end

  sub_test_case "rpm package url" do
    setup do
      ENV["FLUENT_PACKAGE_CONFIG"] = "#{@tmp_dir}/config.rb"
      ENV["FLUENT_PACKAGE_TAGS_PATH"] = "#{@tmp_dir}/tags.json"
    end

    data("redhat 9 x86_64" => [{family: "redhat", release: "9.8", arch: "x86_64"},
                               "lts/5/redhat/9/x86_64/fluent-package-5.0.7-1.el9.x86_64.rpm"],
         "redhat 8 aarch64" => [{family: "redhat", release: "8.10", arch: "aarch64"},
                                "lts/5/redhat/8/aarch64/fluent-package-5.0.7-1.el8.aarch64.rpm"],
         "amazon 2023 x86_64" => [{family: "amazon", release: "2023.12.20260930", arch: "x86_64"},
                                  "lts/5/amazon/2023/x86_64/fluent-package-5.0.7-1.amzn2023.x86_64.rpm"],
         "amazon 2 aarch64" => [{family: "amazon", release: "2", arch: "aarch64"},
                                "lts/5/amazon/2/aarch64/fluent-package-5.0.7-1.amzn2.aarch64.rpm"])
    test "check rpm package of the release" do |(os_info, path)|
      config = RbConfig::CONFIG.merge("host_os" => "linux")
      stub(RbConfig::CONFIG).[](anything) { |key| config[key] }
      backend = Object.new
      stub(backend).os_info { os_info }
      stub(Specinfra).backend { backend }
      urls = []
      stub(URI).open(anything) { |url| urls << url }
      write_config_version("5.0.6")
      cache_tags_path(ENV["FLUENT_PACKAGE_TAGS_PATH"], ["5.0.7", "5.0.6"])
      d = create_driver
      d.run
      assert_equal(["https://packages.treasuredata.com/#{path}"], urls)
      assert_match(/\[info\]: fluent-package v5.0.7 is available/, d.logs.last)
    end
  end

  sub_test_case "package directory of each channel" do
    setup do
      ENV["FLUENT_PACKAGE_CONFIG"] = "#{@tmp_dir}/config.rb"
      ENV["FLUENT_PACKAGE_TAGS_PATH"] = "#{@tmp_dir}/tags.json"
    end

    data("redhat on standard channel" => [false, "linux", {family: "redhat", release: "9", arch: "aarch64"},
                                          "5/redhat/9/aarch64"],
         "amazon on standard channel" => [false, "linux", {family: "amazon", release: "2023", arch: "aarch64"},
                                          "5/amazon/2023/aarch64"],
         "windows on standard channel" => [false, "mingw32", {family: "windows"},
                                           "5/windows"],
         "redhat on LTS channel" => [true, "linux", {family: "redhat", release: "9", arch: "aarch64"},
                                     "lts/5/redhat/9/aarch64"])
    test "check package in the directory of the channel" do |(lts, host_os, os_info, dir)|
      config = RbConfig::CONFIG.merge("host_os" => host_os)
      stub(RbConfig::CONFIG).[](anything) { |key| config[key] }
      backend = Object.new
      stub(backend).os_info { os_info }
      stub(Specinfra).backend { backend }
      urls = []
      stub(URI).open(anything) { |url| urls << url }
      write_config_version("5.0.6")
      cache_tags_path(ENV["FLUENT_PACKAGE_TAGS_PATH"], ["5.0.7", "5.0.6"])
      d = create_driver("lts #{lts}")
      d.run
      assert_equal(["https://packages.treasuredata.com/#{dir}"], urls.collect { |url| File.dirname(url) })
      assert_match(/\[info\]: fluent-package v5.0.7 is available/, d.logs.last)
    end
  end

  sub_test_case "each platforms" do
    setup do
      ENV["FLUENT_PACKAGE_CONFIG"] = "#{@tmp_dir}/config.rb"
      ENV["FLUENT_PACKAGE_TAGS_PATH"] = "#{@tmp_dir}/tags.json"
    end

    data("trixie" => [%W(ID=debian\n VERSION_CODENAME=trixie\n)],
         "ubuntu" => [%W(ID=plucky]\n VERSION_CODENAME=plucky\n)],
         "rockylinux/8" => [%W(ID="rocky"\n CPE_NAME="cpe:/o:rocky:rocky:8:GA"\n)],
         "rockylinux/9" => [%W(ID="rocky"\n CPE_NAME="cpe:/o:rocky:rocky:9:GA"\n)],
         "almalinux/8" => [%W(ID="almalinux"\n CPE_NAME="cpe:/o:almalinux:almalinux:8::baseos"\n)],
         "almalinux/9" => [%W(ID="almalinux"\n CPE_NAME="cpe:/o:almalinux:almalinux:8::baseos"\n)],
         "amazonlinux/2" => [%W(ID="amzn"\n CPE_NAME="cpe:2.3:o:amazon:amazon_linux:2"\n)],
         "amazonlinux/2023" => [%W(ID="amzn"\n CPE_NAME="cpe:2.3:o:amazon:amazon_linux:2023"\n)])
    test "released, but not shipped yet for linux" do
      assert_nothing_raised do |os_release|
        stub(File).readlines { os_release }
        write_config_version("5.0.6")
        cache_tags_path(ENV["FLUENT_PACKAGE_TAGS_PATH"], ["5.0.404"])
        d = create_driver
        d.run
        assert_match(/\[info\]: No update for fluent-package 5.0.6/, d.logs.last)
      end
    end

    test "released, but not shipped yet for windows" do
      assert_nothing_raised do |os_release|
        stub(RbConfig::CONFIG) { {'host_os' => "mingw32"} }
        write_config_version("5.0.6")
        cache_tags_path(ENV["FLUENT_PACKAGE_TAGS_PATH"], ["5.0.404"])
        d = create_driver
        d.run
        assert_match(/\[info\]: No update for fluent-package 5.0.6/, d.logs.last)
      end
    end

    data("x64" => ["x64", "fluent-package-6.0.1-x64.msi"],
         "arm64" => ["aarch64", "fluent-package-6.0.1-arm64.msi"])
    test "check msi of the same architecture for windows" do |(host_cpu, msi)|
      config = RbConfig::CONFIG.merge("host_os" => "mingw32", "host_cpu" => host_cpu)
      stub(RbConfig::CONFIG).[](anything) { |key| config[key] }
      urls = []
      stub(URI).open(anything) { |url| urls << url }
      write_config_version("6.0.0")
      cache_tags_path(ENV["FLUENT_PACKAGE_TAGS_PATH"], ["6.0.1", "6.0.0"])
      d = create_driver
      d.run
      assert_equal(["https://packages.treasuredata.com/lts/6/windows/#{msi}"], urls)
      assert_match(/\[info\]: fluent-package v6.0.1 is available/, d.logs.last)
    end
  end

  private

  def create_driver(conf=config)
    Fluent::Test::Driver::Input.new(Fluent::Plugin::FluentPackageUpdateNotifierInput).configure(conf)
  end
end
