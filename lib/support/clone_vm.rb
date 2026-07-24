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

require "rbvmomi"

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

      raise format("Unable to find template: %s", options[:template]) if src_vm.nil?

      # Specify where the machine is going to be created
      relocate_spec = RbVmomi::VIM.VirtualMachineRelocateSpec
      relocate_spec.host = options[:targethost]

      # Set the resource pool
      relocate_spec.pool = options[:resource_pool]

      clone_spec = RbVmomi::VIM.VirtualMachineCloneSpec(location: relocate_spec,
                                                        powerOn: options[:poweron],
                                                        template: false)

      # Set the folder to use
      dest_folder = options[:folder].nil? ? src_vm.parent : options[:folder][:id]

      puts "Cloning the template '#{options[:template]}' to create the VM..."
      task = src_vm.CloneVM_Task(folder: dest_folder, name: options[:name], spec: clone_spec)
      # TODO: it would be nice to have dots to tell you it's working here
      task.wait_for_completion

      # get the IP address of the machine for bootstrapping
      new_vm = locate_new_vm(dc)

      if new_vm.nil?
        puts format("Unable to find machine: %s", options[:name])
      else
        puts "Waiting for network interfaces to become available..."
        bootstrap_ip_for_vm(new_vm)
      end
    end

    private

    def locate_new_vm(datacenter)
      vm_name = options[:name]

      if options[:folder]
        folder_vm_name = format("%s/%s", options[:folder][:name], vm_name)
        vm = datacenter.find_vm(folder_vm_name)
        return vm unless vm.nil?
      end

      datacenter.find_vm(vm_name)
    end

    def bootstrap_ip_for_vm(vm, timeout: 300, interval: 2)
      deadline = Time.now + timeout

      loop do
        ipaddress = extract_bootstrap_ip(vm)
        return ipaddress unless ipaddress.nil?

        return nil if Time.now >= deadline

        sleep interval
      end
    end

    def extract_bootstrap_ip(vm)
      guest = vm.guest

      addresses = guest.net.to_a.flat_map do |nic|
        nic.ipConfig&.ipAddress.to_a.map(&:ipAddress)
      end.compact

      ipv4 = addresses.find { |addr| addr.include?(".") && !addr.start_with?("169.254.") }
      return ipv4 unless ipv4.nil?

      return nil if guest.ipAddress.nil? || !guest.ipAddress.include?(".")

      guest.ipAddress.start_with?("169.254.") ? nil : guest.ipAddress
    end
  end
end
