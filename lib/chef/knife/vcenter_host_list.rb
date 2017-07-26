# frozen_string_literal: true
#
# Author:: Chef Partner Engineering (<partnereng@chef.io>)
# Copyright:: Copyright (c) 2017 Chef Software, Inc.
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

require 'chef/knife'
require 'chef/knife/cloud/list_resource_command'
require 'chef/knife/cloud/vcenter_service'
require 'chef/knife/cloud/vcenter_service_helpers'
require 'chef/knife/cloud/vcenter_service_options'

class Chef
  class Knife
    class Cloud
      class VcenterHostList < ResourceListCommand
        include VcenterServiceHelpers
        include VcenterServiceOptions

        banner 'knife vcenter host list'

        def before_exec_command
          @columns_with_info = [
            { label: 'ID',    key: 'host' },
            { label: 'Name',  key: 'name' },
            { label: 'Power State', key: 'power_state', value_callback: method(:format_power_status) },
            { label: 'Connection State', key: 'connection_state'},
          ]

          @sort_by_field = 'name'
        end

        def query_resource
          # Call service to get the list of hosts from vcenter
          service.list_hosts
        end

        def format_power_status(status)
          status_check = status.value
          status_colour = case status_check
                          when 'POWERED_OFF'
                            :red
                          when 'POWERED_ON'
                            :green
                          when 'SUSPENDED'
                            :yellow
                          end

          ui.color(status.value, status_colour)
        end        
      end
    end
  end
end