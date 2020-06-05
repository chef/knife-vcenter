# frozen_string_literal: true

#
# Author:: Chef Partner Engineering (<partnereng@chef.io>)
# Copyright:: Copyright (c) Chef Software Inc.
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
      class VcenterVmClone < Chef::Knife::Cloud::ServerCreateCommand
        include VcenterServiceOptions
        include ServerCreateOptions

        banner "knife vcenter vm clone NAME (options)"

        # lazy load this file as it includes vmware deps that we only want at plugin runtime
        deps do
          require_relative "cloud/vcenter_service"
        end

        option :template,
          long: "--template NAME",
          description: "Name of VM or template to use to clone machine from"

        option :targethost,
          long: "--targethost HOST",
          description: "Host that the machine should be created on"

        option :datacenter,
          long: "--datacenter NAME",
          description: "The datacenter for vSphere"

        option :disable_power_on,
          long: "--disable-power-on",
          boolean: true,
          default: false

        option :folder,
          long: "--folder NAME",
          description: "Folder to deploy the new machine into"

        option :pool,
          long: "--pool NAME",
          description: "Name of resource pool to use when creating the machine"

        option :node_ssl_verify_mode,
          long: "--node-ssl-verify-mode [peer|none]",
          description: "Whether or not to verify the SSL cert for all HTTPS requests."

        # Validates the parameters and maksessure you have a template, name, or datacenter
        #
        def validate_params!
          super

          if @name_args.empty?
            ui.error("You must provide the name of the new machine")
          end

          check_for_missing_config_values!(:template, :datacenter)
        end

        # Creates the @create_options to hand off to the next step
        #
        def before_exec_command
          super

          @create_options = {
            name: @name_args[0],
            type: "clone",
            template: config[:template],
            targethost: config[:targethost],
            datacenter: config[:datacenter],
            poweron: !config[:disable_power_on],
            folder: config[:folder],
            resource_pool: config[:pool],
          }
        end

        # determine the IP address to use to bootstrap the machine with chef
        #
        def before_bootstrap
          super

          config[:chef_node_name] = config[:chef_node_name] || server.name

          config[:bootstrap_ip_address] = hostname_for_server
        end

        # Gets the ipaddress for the VM to bootstrap with
        #
        def hostname_for_server
          ipaddress = service.ipaddress

          ipaddress.nil? ? server.name : ipaddress
        end
      end
    end
  end
end
