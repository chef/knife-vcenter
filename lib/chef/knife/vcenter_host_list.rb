# frozen_string_literal: true
#
# Author:: Chef Partner Engineering (<partnereng@chef.io>)
# Copyright:: Copyright (c) 2017-2018 Chef Software, Inc.
# License:: Apache License, Version 2.0
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
#

require "chef/knife"
require "chef/knife/cloud/list_resource_command"
require_relative "cloud/vcenter_service"
require_relative "cloud/vcenter_service_helpers"
require_relative "cloud/vcenter_service_options"

class Chef
  # Main knife class
  class Knife
    # the main cloud class from knife-cloud
    class Cloud
      # Extends the ResourceListcommand for specific vCenter
      class VcenterHostList < ResourceListCommand
        include VcenterServiceHelpers
        include VcenterServiceOptions

        banner "knife vcenter host list"

        # Sets up the columns for listing out and sorts by name
        #
        def before_exec_command
          @columns_with_info = [
            { label: "ID",    key: "host" },
            { label: "Name",  key: "name" },
            { label: "Power State", key: "power_state", value_callback: method(:format_power_status) },
            { label: "Connection State", key: "connection_state" },
          ]

          @sort_by_field = "name"
        end

        # Call service to get the list of hosts from vCenter
        #
        def query_resource
          service.list_hosts
        end

        # Formats the power status
        #
        # @param [Object] status takes the number and formats it how you need it to
        def format_power_status(status)
          status_color = case status
                         when "POWERED_OFF"
                           :red
                         when "POWERED_ON"
                           :green
                         when "SUSPENDED"
                           :yellow
                         end

          ui.color(status, status_color)
        end
      end
    end
  end
end
