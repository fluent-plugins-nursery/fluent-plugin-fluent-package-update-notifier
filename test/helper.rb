require "test/unit"
require "test/unit/rr"
require "fluent/test"
require "fluent/test/driver/input"
require "fluent/test/helpers"
require 'fluent/config/element'
require 'fluent/system_config'
require 'fluent/engine'

Test::Unit::TestCase.include(Fluent::Test::Helpers)
Test::Unit::TestCase.extend(Fluent::Test::Helpers)
