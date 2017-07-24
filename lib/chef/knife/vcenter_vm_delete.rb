# frozen_string_literal: true
#
# Author:: Chef Partner Engineering (<partnereng@chef.io>)
# Copyright:: Copyright (c) 2015 Chef Software, Inc.
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
require 'chef/knife/cloud/server/delete_options'
require 'chef/knife/cloud/server/delete_command'
require 'chef/knife/cloud/vcenter_service'
require 'chef/knife/cloud/vcenter_service_helpers'
require 'chef/knife/cloud/vcenter_service_options'

class Chef
  class Knife
    class Cloud
      class VcenterVmDelete < ServerDeleteCommand
        include ServerDeleteOptions
        include VcenterServiceOptions
        include VcenterServiceHelpers

        banner 'knife vcenter vm delete NAME [NAME] (options)'

        # rubocop:disable Style/GuardClause
        def validate_params!
          if @name_args.empty?
            ui.error('You must supply the name of the virtual machine to delete.')
            exit(1) if @name_args.empty?
          end
        end

        def execute_command
          @name_args.each do |name|
            service.delete_vm(name)
            delete_from_chef(name)
          end
        end
      end
    end
  end
end