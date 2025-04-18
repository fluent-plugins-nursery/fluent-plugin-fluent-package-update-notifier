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

  private

  def create_driver(conf=config)
    Fluent::Test::Driver::Input.new(Fluent::Plugin::FluentPackageUpdateNotifierInput).configure(conf)
  end
end
