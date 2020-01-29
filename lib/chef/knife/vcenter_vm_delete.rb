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
require "chef/knife/cloud/server/delete_options"
require "chef/knife/cloud/server/delete_command"
require_relative "cloud/vcenter_service_options"

class Chef
  class Knife
    class Cloud
      # Extends the SeverDeleteCommand for specifically vCenter
      class VcenterVmDelete < ServerDeleteCommand
        include ServerDeleteOptions
        include VcenterServiceOptions

        banner "knife vcenter vm delete NAME [NAME] (options)"

        # lazy load this file as it includes vmware deps that we only want at plugin runtime
        deps do
          require_relative "cloud/vcenter_service"
        end

        # rubocop:disable Style/GuardClause
        # Validates the parameters to make sure we're good.
        #
        def validate_params!
          if @name_args.empty?
            ui.error("You must supply the name of the virtual machine to delete.")
            exit(1) if @name_args.empty?
          end
        end

        # Executes the command against vCenter and the Chef Server
        #
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
