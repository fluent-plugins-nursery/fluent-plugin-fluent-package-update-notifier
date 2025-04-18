require "helper"
require "fluent/plugin/in_fluent_package_update_notifier.rb"

class FluentPackageUpdateNotifierInputTest < Test::Unit::TestCase
  setup do
    Fluent::Test.setup
  end

  test "failure" do
    flunk
  end

  private

  def create_driver(conf)
    Fluent::Test::Driver::Input.new(Fluent::Plugin::FluentPackageUpdateNotifierInput).configure(conf)
  end
end
