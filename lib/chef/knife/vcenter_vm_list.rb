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
require "chef/knife/cloud/server/list_command"
require "chef/knife/cloud/server/list_options"
require "chef/knife/cloud/vcenter_service"
require "chef/knife/cloud/vcenter_service_helpers"
require "chef/knife/cloud/vcenter_service_options"

class Chef
  # The main knife class
  class Knife
    # The main cloud class from knife-cloud
    class Cloud
      # Extends the ServerListCommand for specific vCenter
      class VcenterVmList < Chef::Knife::Cloud::ServerListCommand
        include VcenterServiceHelpers
        include VcenterServiceOptions

        banner "knife vcenter vm list"

        # Sets up the columns for listing out and sorts by name
        #
        def before_exec_command
          @columns_with_info = [
            { label: "ID",    key: "vm" },
            { label: "Name",  key: "name" },
            { label: "Power State", key: "power_state", value_callback: method(:format_power_status) },
            { label: "CPU Count", key: "cpu_count" },
            { label: "RAM Size (MB)", key: "memory_size_MiB", value_callback: method(:format_memory_value) },
          ]

          @sort_by_field = "name"
        end

        # Sets the color for the different status of the machines
        #
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

        # Formats the memory value
        #
        # @param [Object] value takes the number and formats it how you need it to
        def format_memory_value(value)
          value.to_s.reverse.gsub(/...(?=.)/, '\&,').reverse
        end
      end
    end
  end
end
