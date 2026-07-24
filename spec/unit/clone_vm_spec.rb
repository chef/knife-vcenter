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

require "spec_helper"
require "support/clone_vm"

describe Support::CloneVm do
  subject(:clone_vm) { described_class.allocate }

  describe "#locate_new_vm" do
    let(:datacenter) { instance_double("Datacenter") }

    context "when folder scoped lookup misses" do
      before do
        clone_vm.instance_variable_set(:@options, { name: "debian-web-01", folder: { name: "vm" } })
      end

      it "falls back to a plain VM name lookup" do
        vm = double(:vm)
        expect(datacenter).to receive(:find_vm).with("vm/debian-web-01").and_return(nil)
        expect(datacenter).to receive(:find_vm).with("debian-web-01").and_return(vm)

        expect(clone_vm.send(:locate_new_vm, datacenter)).to eq(vm)
      end
    end

    context "when folder is not provided" do
      before do
        clone_vm.instance_variable_set(:@options, { name: "debian-web-01", folder: nil })
      end

      it "looks up by plain VM name" do
        vm = double(:vm)
        expect(datacenter).to receive(:find_vm).with("debian-web-01").and_return(vm)

        expect(clone_vm.send(:locate_new_vm, datacenter)).to eq(vm)
      end
    end
  end

  describe "#bootstrap_ip_for_vm" do
    it "returns a non-link-local IPv4 address from guest NIC data" do
      ip_addr = double(:ip_addr, ipAddress: "172.16.108.247")
      nic = double(:nic, ipConfig: double(:ip_config, ipAddress: [ip_addr]))
      guest = double(:guest, net: [nic], ipAddress: "172.16.108.247")
      vm = double(:vm, guest: guest)

      expect(clone_vm.send(:bootstrap_ip_for_vm, vm, timeout: 0, interval: 0)).to eq("172.16.108.247")
    end

    it "returns nil when no usable IPv4 is available before timeout" do
      guest = double(:guest, net: [], ipAddress: nil)
      vm = double(:vm, guest: guest)

      expect(clone_vm.send(:bootstrap_ip_for_vm, vm, timeout: 0, interval: 0)).to be_nil
    end
  end
end
