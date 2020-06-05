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

require "chef/knife/cloud/exceptions"
require "chef/knife/cloud/service"
require "chef/knife/cloud/helpers"
require_relative "vcenter_service_helpers"
require_relative "../../../support/clone_vm"
require "uri"
require "json"
require "ostruct"
require "vsphere-automation-cis"
require "vsphere-automation-vcenter"
require "set"

class Chef
  # The main knife class
  class Knife
    # The main cloud class from knife-cloud
    class Cloud
      # Extends the Service method, this is the bulk of the integration
      class VcenterService < Service
        include VcenterServiceHelpers

        attr_reader :api_client, :session_api, :session_id
        attr_reader :connection_options, :ipaddress

        def initialize(options = {})
          super(options)

          configuration = VSphereAutomation::Configuration.new.tap do |c|
            c.host = options[:host]
            c.username = options[:username]
            c.password = options[:password]
            c.scheme = "https"
            c.verify_ssl = options[:verify_ssl]
            c.verify_ssl_host = options[:verify_ssl]
          end

          Base.log.warn("SSL Verification is turned OFF") if options[:logs] && !options[:verify_ssl]

          @api_client = VSphereAutomation::ApiClient.new(configuration)
          api_client.default_headers["Authorization"] = configuration.basic_auth_token

          session_api = VSphereAutomation::CIS::SessionApi.new(api_client)
          session_id = session_api.create("").value

          api_client.default_headers["vmware-api-session-id"] = session_id

          # Set the class properties for the rbvmomi connections
          @connection_options = {
            user: options[:username],
            password: options[:password],
            insecure: options[:verify_ssl] ? false : true,
            host: options[:host],
          }
        end

        # Creates the server
        #
        # @param [Object] options to override anything you need to do
        def create_server(options = {})
          # Create the vm object
          vm_api = VSphereAutomation::VCenter::VMApi.new(api_client)

          # Use the option to determine now a new machine is being created
          case options[:type]
          when "clone"

            datacenter_exists?(options[:datacenter])

            # Some of ht eoptions need to be the ID of the component in VMware
            # Update these using the REST API so that they can be passed to the support library
            options[:targethost] = get_host(options[:targethost]).host

            options[:resource_pool] = get_resource_pool(options[:resource_pool])

            # Configure the folder option as a has with the name an the id
            unless options[:folder].nil?
              options[:folder] = {
                name: options[:folder],
                id: get_folder(options[:folder]),
              }
            end

            # Clone the machine using the support library
            clone_obj = ::Support::CloneVm.new(connection_options, options)
            @ipaddress = clone_obj.clone

            # return an object from the restapi
            get_server(options[:name])

          when "create"

            # Create the placement object
            placement_spec = VSphereAutomation::VCenter::VcenterVMPlacementSpec.new( ###
              folder: get_folder(options[:folder]),
              host: get_host(options[:targethost]).host,
              datastore: get_datastore(options[:datastore]),
              resource_pool: get_resource_pool(options[:resource_pool])
            )

            # Create the CreateSpec object
            create_spec = VSphereAutomation::VCenter::VcenterVMCreateSpec.new(
              name: options[:name],
              guest_OS: VSphereAutomation::VCenter::VcenterVmGuestOS::OTHER,
              placement: placement_spec
            )

            # Create the new machine
            begin
              create_model = VSphereAutomation::VCenter::VcenterVMCreate.new(spec: create_spec)
              vm_api.create(create_model).value
            rescue StandardError => e
              puts e.message
            end
          end
        end

        # Get a list of vms from the API
        #
        def list_servers
          vms = VSphereAutomation::VCenter::VMApi.new(api_client).list.value

          # list_resource_command uses .send(:name) syntax, so convert to OpenStruct to keep it compatible
          vms.map { |vmsummary| OpenStruct.new(vmsummary.to_hash) }
        end

        # Return a list of the hosts in the vCenter
        #
        def list_hosts
          VSphereAutomation::VCenter::HostApi.new(api_client).list.value
        end

        # Return a list of the datacenters in the vCenter
        #
        def list_datacenters
          VSphereAutomation::VCenter::DatacenterApi.new(api_client).list.value
        end

        # Return a list of the clusters in the vCenter
        #
        def list_clusters
          VSphereAutomation::VCenter::ClusterApi.new(api_client).list.value
        end

        # Checks to see if the datacenter exists in the vCenter
        #
        # @param [String] name is the name of the datacenter
        def datacenter_exists?(name)
          dc_api = VSphereAutomation::VCenter::DatacenterApi.new(api_client)
          dcs = dc_api.list({ filter_names: name }).value

          raise format("Unable to find data center: %s", name) if dcs.empty?
        end

        # Gets the folder
        #
        # @param [String] name is the folder of the datacenter
        def get_folder(name)
          folder_api = VSphereAutomation::VCenter::FolderApi.new(api_client)
          folders = folder_api.list({ filter_names: name }).value

          raise format("Unable to find folder: %s", name) if folders.empty?

          folders.first.folder
        end

        # Gets the host
        #
        # @param [String] name is the host of the datacenter
        def get_host(name)
          # create a host object to work with
          host_api = VSphereAutomation::VCenter::HostApi.new(api_client)

          if name.nil?
            hosts = host_api.list.value
          else
            hosts = host_api.list({ filter_names: name }).value
          end

          raise format("Unable to find target host: %s", name) if hosts.empty?

          hosts.first
        end

        # Gets the datastore
        #
        # @param [String] name is the datastore of the datacenter
        def get_datastore(name)
          ds_api = VSphereAutomation::VCenter::DatastoreApi.new(api_client)
          ds = ds_api.list({ filter_names: name }).value

          raise format("Unable to find data store: %s", name) if ds.empty?

          ds.first.datastore
        end

        # Gets the resource_pool
        #
        # @param [String] name is the resource_pool of the datacenter
        def get_resource_pool(name)
          rp_api = VSphereAutomation::VCenter::ResourcePoolApi.new(api_client)

          if name.nil?
            # Remove default pool for first pass (<= 1.2.1 behaviour to pick first user-defined pool found)
            resource_pools = rp_api.list.value.delete_if { |pool| pool.name == "Resources" }
            puts "Search of all resource pools found: " + resource_pools.map(&:name).to_s

            # Revert to default pool, if no user-defined pool found (> 1.2.1 behaviour)
            # (This one might not be found under some circumstances by the statement above)
            return get_resource_pool("Resources") if resource_pools.empty?
          else
            resource_pools = rp_api.list({ filter_names: name }).value
            puts "Search for resource pools found: " + resource_pools.map(&:name).to_s
          end

          raise format("Unable to find Resource Pool: %s", name) if resource_pools.empty?

          resource_pools.first.resource_pool
        end

        # Gets the server
        #
        # @param [String] name is the server of the datacenter
        def get_server(name)
          vm_api = VSphereAutomation::VCenter::VMApi.new(api_client)
          vm_api.list({ filter_names: name }).value.first
        end

        # Deletes the VM
        #
        # @param [String] name is the server to delete
        def delete_vm(name)
          vm = get_server(name)
          server_summary(vm)
          ui.msg("")

          ui.confirm("Do you really want to be delete this virtual machine")

          vm_api = VSphereAutomation::VCenter::VMApi.new(api_client)

          # check the power state of the machine, if it is powered on turn it off
          if vm.power_state == "POWERED_ON"
            power_api = VSphereAutomation::VCenter::VmPowerApi.new(api_client)
            ui.msg("Shutting down machine")
            power_api.stop(vm.vm)
          end

          vm_api.delete(vm.vm)
        end

        # Gets some server information
        #
        # @param [Object] server is the server object
        def server_summary(server, _coloumns_with_inf = nil)
          msg_pair("ID", server.vm)
          msg_pair("Name", server.name)
          msg_pair("Power State", server.power_state)
        end

        #         def bootstrap_common_params(bootstrap)
        #           bootstrap.config[:run_list] = config[:run_list]
        #           bootstrap.config[:environment] = get_config(:environment)
        #           bootstrap.config[:first_boot_attributes] = get_config(:first_boot_attributes)
        #           bootstrap.config[:chef_node_name] = get_config(:chef_node_name)
        #           bootstrap.config[:node_ssl_verify_mode] = get_config(:node_ssl_verify_mode)
        #           bootstrap
        #         end
        #
        #         def bootstrap_for_node
        #           Chef::Knife::Bootstrap.load_deps
        #           bootstrap = Chef::Knife::Bootstrap.new
        #           bootstrap.name_args = [config[:fqdn]]
        #           bootstrap.config[:ssh_user] = get_config(:ssh_user)
        #           bootstrap.config[:ssh_password] = get_config(:ssh_password)
        #           bootstrap.config[:ssh_port] = get_config(:ssh_port)
        #           bootstrap.config[:identity_file] = get_config(:identity_file)
        #           bootstrap.config[:use_sudo] = true unless get_config(:ssh_user) == 'root'
        #           bootstrap.config[:use_sudo_password] = true unless get_config(:ssh_user) == 'root'
        #           bootstrap.config[:log_level] = get_config(:log_level)
        #           bootstrap_common_params(bootstrap)
        #         end

        private

        def cleanup
          session_svc.delete unless session_id.nil?
        end
      end
    end
  end
end
