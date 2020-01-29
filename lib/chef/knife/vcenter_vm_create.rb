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
require "chef/knife/cloud/server/create_command"
require "chef/knife/cloud/server/create_options"
require_relative "cloud/vcenter_service_options"

class Chef
  # The main knife class
  class Knife
    # The main cloud class from knife-cloud
    class Cloud
      # Extends the ServerCreateCommand for specific vCenter
      class VcenterVmCreate < Chef::Knife::Cloud::ServerCreateCommand
        include VcenterServiceOptions
        include ServerCreateOptions

        banner "knife vcenter vm create NAME"

        # lazy load this file as it includes vmware deps that we only want at plugin runtime
        deps do
          require_relative "cloud/vcenter_service"
        end

        option :targethost,
          long: "--targethost HOST",
          description: "vCenter host on which the new VM should be created"

        option :folder,
          long: "--folder FOLDER",
          description: "Folder in which the machine will reside"

        option :datastore,
          long: "--datastore DATASTORE",
          description: "Datastore to be used for the disks etc"

        option :resource_pool,
          long: "--resource_pool RESOURCEPOOOL",
          description: "Resource Pool to create the machine"

        # Validates the parameters, you need that unique name person!
        #
        def validate_params!
          super

          if @name_args.empty?
            ui.error("You must provide the name of the new machine")
          end

          check_for_missing_config_values!(:targethost, :datastore, :folder)
        end

        # Sets up the create options and puts them
        #
        def before_exec_command
          super

          @create_options = {
            name: @name_args[0],
            type: "create",
            targethost: locate_config_value(:targethost),
            folder: locate_config_value(:folder),
            datastore: locate_config_value(:datastore),
            resource_pool: locate_config_value(:resource_pool),
          }

          puts @create_options
        end
      end
    end
  end
end
