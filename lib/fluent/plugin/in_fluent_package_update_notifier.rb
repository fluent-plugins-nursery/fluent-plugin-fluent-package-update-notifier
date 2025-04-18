#
# Copyright 2025- Kentaro Hayashi
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

require "fluent/plugin/input"
require "fluent/log"
require "fluent/config/error"
require_relative "./fluent_package_update_checker"

module Fluent
  module Plugin
    class FluentPackageUpdateNotifierInput < Fluent::Plugin::Input
      Fluent::Plugin.register_input("fluent_package_update_notifier", self)

      helpers :timer

      desc "Notify fluent-package updates which depends on channel (e.g. Monitor LTS by default)"
      config_param :lts, :bool, default: true

      desc "Notify whether major upgrade is available or not (e.g. from v5 to v6)"
      config_param :notify_major_upgrade, :bool, default: true

      desc "Specify notification log level when update is available"
      config_param :notify_level, :enum, list: [:info, :warn], default: :info

      desc "Notify checking update intervals"
      config_param :notify_interval, :integer, default: 60 * 60 * 24

      def configure(conf)
        super
      end

      def start
        super
        check_fluent_pacakge_update_information
        timer_execute(:in_fluent_package_update_notifier_worker, @notify_interval, &method(:run))
      end

      def shutdown
        super
      end

      def run
        check_fluent_pacakge_update_information
      end

      private

      def check_fluent_pacakge_update_information
        begin
          options = {
            lts: @lts,
            notify_major_upgrade: @notify_major_upgrade,
            notify_level: @notify_level,
            logger: log
          }
          checker = Fluent::Plugin::FluentPackage::UpdateChecker.new(options)
          checker.run
        rescue => e
          log.error "Failed to check updates: #{e.message}"
        end
      end
    end
  end
end
