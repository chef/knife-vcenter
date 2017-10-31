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
  # The main knife class
  class Knife
    # The main cloud class from knife-cloud
    class Cloud
      # Extends the ResourceListCommand for specific vCenter
      class VcenterDatacenterList < ResourceListCommand
        include VcenterServiceHelpers
        include VcenterServiceOptions

        banner 'knife vcenter datacenter list'

        # Sets up the columns for listing out and sorts by name
        #
        def before_exec_command
          @columns_with_info = [
            { label: 'ID',    key: 'datacenter' },
            { label: 'Name',  key: 'name' },
          ]

          @sort_by_field = 'name'
        end

        # Call service to get the list of hosts from vcenter
        #
        def query_resource
          service.list_datacenters
        end
      end
    end
  end
end
