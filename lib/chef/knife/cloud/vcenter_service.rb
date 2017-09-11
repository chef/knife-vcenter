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

require 'chef/knife/cloud/exceptions'
require 'chef/knife/cloud/service'
require 'chef/knife/cloud/helpers'
require 'chef/knife/cloud/vcenter_service_helpers'
require 'net/http'
require 'uri'
require 'json'
require 'ostruct'
require 'lookup_service_helper'
require 'vapi'
require 'com/vmware/cis'
require 'com/vmware/vcenter'
require 'com/vmware/vcenter/vm'
require 'sso'
require 'base'
require 'set'
require 'support/clone_vm'

class Chef
  class Knife
    class Cloud
      class VcenterService < Service
        include VcenterServiceHelpers

        attr_reader :vapi_config, :session_svc, :session_id
        attr_reader :connection_options, :ipaddress

        def initialize(options={})
          super(options)

          # Using the information supplied, configure the connection to vCentre
          lookup_service_helper = LookupServiceHelper.new(options[:host])

          vapi_urls = lookup_service_helper.find_vapi_urls()
          vapi_url = vapi_urls.values[0]
          Base.log.info(format('Vapi URL: %s', vapi_url)) if options[:vcenter_logs]

          # Create the VAPI config object
          ssl_options = {}
          ssl_options[:verify] = if options[:verify_ssl]
                                   :peer
                                 else
                                   Base.log.warn('SSL Verification is turned OFF') if options[:vcenter_logs]
                                   :none
                                 end
          @vapi_config = VAPI::Bindings::VapiConfig.new(vapi_url, ssl_options)

          # get the SSO url
          sso_url = lookup_service_helper.find_sso_url()
          sso = SSO::Connection.new(sso_url).login(options[:username], options[:password])
          token = sso.request_bearer_token()
          vapi_config.set_security_context(
            VAPI::Security.create_saml_bearer_security_context(token.to_s)
          )

          # Login and get the session information
          @session_svc = Com::Vmware::Cis::Session.new(vapi_config)
          @session_id = session_svc.create()
          vapi_config.set_security_context(
            VAPI::Security.create_session_security_context(session_id)
          )

          # Set the class properties for the rbvmomi connections
          @connection_options = {
            user: options[:username],
            password: options[:password],
            insecure: options[:verify_ssl] ? false : true,
            host: options[:host],
          }
        end

        def create_server(options={})

          # Create the vm object
          vmobj = Com::Vmware::Vcenter::VM.new(vapi_config)

          # Use the option to determine now a new machine is being created
          case options[:type]
          when "clone"

            # Some of ht eoptions need to be the ID of the component in VMWAre
            # Update these using the REST API so that they can be passed to the support library
            options[:targethost] = get_host(options[:targethost])

            options[:resource_pool] = get_resource_pool(options[:resource_pool])

            # Configure the folder option as a has with the name an the id
            options[:folder] = {
              name: options[:folder],
              id: get_folder(options[:folder])
            } unless options[:folder].nil?

            # Clone the machine using the support library
            clone_obj = Support::CloneVm.new(connection_options, options)
            @ipaddress = clone_obj.clone()

            # return an object from the restapi
            return get_server(options[:name])

          when "create"

            # Create the placement object
            placementspec = Com::Vmware::Vcenter::VM::PlacementSpec.new()
            placementspec.folder = get_folder(options[:folder])
            placementspec.host = get_host(options[:targethost])
            placementspec.datastore = get_datastore(options[:datastore])
            placementspec.resource_pool = get_resourcepool(options[:resource_pool])

            # Create the CreateSpec object
            createspec = Com::Vmware::Vcenter::VM::CreateSpec.new()

            createspec.name = options[:name]#
            puts "seting the OS"
            createspec.guest_OS = Com::Vmware::Vcenter::Vm::GuestOS::UBUNTU_64
            puts "setting the placement"
            createspec.placement = placementspec

            # Create the new machine
            begin
              vm = vmobj.create(createspec)
            rescue => e
              puts e.message
            end
          end
        end

        def list_servers
          # get a list of vms from the API
          Com::Vmware::Vcenter::VM.new(vapi_config).list()
        end

        def list_hosts
          # return a list of the hosts in the vcenter
          Com::Vmware::Vcenter::Host.new(vapi_config).list()
        end

        def list_datacenters
          Com::Vmware::Vcenter::Datacenter.new(vapi_config).list()
        end

        def list_clusters
          Com::Vmware::Vcenter::Cluster.new(vapi_config).list()
        end

        def get_folder(name)
          # Create a filter to ensure that only the named folder is returned
          filter = Com::Vmware::Vcenter::Folder::FilterSpec.new({names: Set.new([name])})
          # filter.names = name
          folder_obj = Com::Vmware::Vcenter::Folder.new(vapi_config)
          folder = folder_obj.list(filter)

          folder[0].folder
        end

        def get_host(name)
          host_obj = Com::Vmware::Vcenter::Host.new(vapi_config)

          if name.nil?
            host = host_obj.list
          else
            filter = Com::Vmware::Vcenter::Host::FilterSpec.new({names: Set.new([name])})
            host = host_obj.list(filter)
          end

          host[0].host
        end

        def get_datastore(name)
          datastore_obj = Com::Vmware::Vcenter::Datastore.new(vapi_config)

          if name.nil?
            datastore = datastore_obj.list
          else
            filter = Com::Vmware::Vcenter::Datastore::FilterSpec.new({names: Set.new([name])})
            datastore = datastore_obj.list(filter)
          end

          datastore[0].datastore
        end

        def get_resource_pool(name)
          # Create a resource pool object
          rp_obj = Com::Vmware::Vcenter::ResourcePool.new(vapi_config)

          # If a name has been set then try to find it, otherwise use the first
          # resource pool that can be found
          if name.nil?
            resource_pool = rp_obj.list
          else
            # create a filter to find the named resource pool
            filter = Com::Vmware::Vcenter::ResourcePool::FilterSpec.new(names: Set.new([name]))
            resource_pool = rp_obj.list(filter)
            raise format('Unable to find Resource Pool: %s', name) if resource_pool.nil?
          end

          resource_pool[0].resource_pool
        end

        def get_server(name)
          filter = Com::Vmware::Vcenter::VM::FilterSpec.new({names: Set.new([name])})
          vm_obj = Com::Vmware::Vcenter::VM.new(vapi_config)
          vm_obj.list(filter)[0]
        end

        def delete_vm(name)
          vm = get_server(name)
          server_summary(vm)
          ui.msg('')

          ui.confirm('Do you really want to be delete this virtual machine')

          vm_obj = Com::Vmware::Vcenter::VM.new(vapi_config)

          # check the power state of the machine, if it is powered on turn it off
          if vm.power_state.value == "POWERED_ON"
            power = Com::Vmware::Vcenter::Vm::Power.new(vapi_config)
            ui.msg('Shutting down machine')
            power.stop(vm.vm)
          end

          vm_obj.delete(vm.vm)
        end

        def server_summary(server, _coloumns_with_inf=nil)
          msg_pair('ID', server.vm)
          msg_pair('Name', server.name)
          msg_pair('Power State', server.power_state)
        end

=begin
        def bootstrap_common_params(bootstrap)
          bootstrap.config[:run_list] = config[:run_list]
          bootstrap.config[:environment] = get_config(:environment)
          bootstrap.config[:first_boot_attributes] = get_config(:first_boot_attributes)
          bootstrap.config[:chef_node_name] = get_config(:chef_node_name)
          bootstrap.config[:node_ssl_verify_mode] = get_config(:node_ssl_verify_mode)
          bootstrap
        end

        def bootstrap_for_node
          Chef::Knife::Bootstrap.load_deps
          bootstrap = Chef::Knife::Bootstrap.new
          bootstrap.name_args = [config[:fqdn]]
          bootstrap.config[:ssh_user] = get_config(:ssh_user)
          bootstrap.config[:ssh_password] = get_config(:ssh_password)
          bootstrap.config[:ssh_port] = get_config(:ssh_port)
          bootstrap.config[:identity_file] = get_config(:identity_file)
          bootstrap.config[:use_sudo] = true unless get_config(:ssh_user) == 'root'
          bootstrap.config[:use_sudo_password] = true unless get_config(:ssh_user) == 'root'
          bootstrap.config[:log_level] = get_config(:log_level)
          bootstrap_common_params(bootstrap)
        end
=end
        private

        def cleanup
          session_svc.delete() unless session_id.nil?
        end
      end
    end
  end
end
