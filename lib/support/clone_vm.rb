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

require 'rbvmomi'

class Support
  class CloneVm
    attr_reader :vim, :options

    def initialize(conn_opts, options)
      @options = options

      # Connect to vSphere
      @vim ||= RbVmomi::VIM.connect conn_opts
    end

    def clone

      # set the datacenter name
      dc = vim.serviceInstance.find_datacenter(options[:datacenter])
      src_vm = dc.find_vm(options[:template])
      hosts = dc.hostFolder.children

      # Specify where the machine is going to be created
      relocate_spec = RbVmomi::VIM.VirtualMachineRelocateSpec
      relocate_spec.host = options[:targethost]
      relocate_spec.pool = hosts.first.resourcePool

      clone_spec = RbVmomi::VIM.VirtualMachineCloneSpec(location: relocate_spec,
                                                        powerOn: options[:poweron],
                                                        template: false)

      # Set the folder to use
      dest_folder = options[:folder].nil? ? src_vm.parent : options[:folder][:id]

      puts "Cloning the template to create the new machine..."
      task = src_vm.CloneVM_Task(folder: dest_folder, name: options[:name], spec: clone_spec)
      # TODO: it would be nice to have dots to tell you it's working here
      task.wait_for_completion


      # get the IP address of the machine for bootstrapping
      # machine name is based on the path, e.g. that includes the folder
      name = options[:folder].nil? ? options[:name] : format("%s/%s", options[:folder][:name], options[:name])
      new_vm = dc.find_vm(name)

      if new_vm.nil?
        puts format("Unable to find machine: %s", name)
      else
        puts 'Waiting for network interfaces to become available...'
        sleep 2 while new_vm.guest.net.empty? || !new_vm.guest.ipAddress
        new_vm.guest.net[0].ipConfig.ipAddress.detect do |addr|
          addr.origin != 'linklayer'
        end.ipAddress
      end
    end
  end
end
