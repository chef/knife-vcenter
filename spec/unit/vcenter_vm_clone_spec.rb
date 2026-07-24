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
require "chef/knife/vcenter_vm_clone"
require "support/shared_examples_for_command"

describe Chef::Knife::Cloud::VcenterVmClone do
  it_behaves_like Chef::Knife::Cloud::Command, Chef::Knife::Cloud::VcenterVmClone.new

  subject(:command) { described_class.new }

  describe "#after_exec_command" do
    before do
      allow(command).to receive(:cleanup_on_failure)
      allow(command).to receive(:sleep)
    end

    context "when bootstrap raises EADDRNOTAVAIL transiently" do
      it "retries and eventually succeeds" do
        attempts = 0
        allow(command).to receive(:bootstrap) do
          attempts += 1
          raise Errno::EADDRNOTAVAIL, "connect(2)" if attempts < 3
        end

        expect(command.ui).to receive(:warn).twice
        expect(command).to receive(:sleep).with(5).ordered
        expect(command).to receive(:sleep).with(10).ordered
        expect(command).not_to receive(:cleanup_on_failure)

        command.after_exec_command

        expect(attempts).to eq(3)
      end
    end

    context "when bootstrap always raises EADDRNOTAVAIL" do
      it "fails after retries and performs cleanup" do
        allow(command).to receive(:bootstrap).and_raise(Errno::EADDRNOTAVAIL, "connect(2)")

        expect(command.ui).to receive(:warn).exactly(3).times
        expect(command.ui).to receive(:fatal).with(/Bootstrap failed after 3 retries due to local networking error/)
        expect(command).to receive(:cleanup_on_failure).once

        expect do
          command.after_exec_command
        end.to raise_error(Errno::EADDRNOTAVAIL, /Bootstrap failed after 3 retries due to local networking error/)
      end
    end

    context "when bootstrap raises a non-network error" do
      it "preserves existing failure behavior" do
        allow(command).to receive(:bootstrap).and_raise(StandardError, "boom")

        expect(command.ui).to receive(:fatal).with("Check if --connection-protocol and --image-os-type is correct. boom")
        expect(command).to receive(:cleanup_on_failure).once

        expect do
          command.after_exec_command
        end.to raise_error(StandardError, "Check if --connection-protocol and --image-os-type is correct. boom")
      end
    end
  end
end
