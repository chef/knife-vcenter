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

require "spec_helper"
require "chef/knife/vcenter_vm_list"
require "support/shared_examples_for_command"

class PowerStatus < BasicObject
  attr_reader :value
  def initialize(state)
    @value = state
  end
end

describe Chef::Knife::Cloud::VcenterVmList do
  it_behaves_like Chef::Knife::Cloud::Command, Chef::Knife::Cloud::VcenterVmList.new

  subject { described_class.new }

  describe "#format_power_status" do
    context 'when the power is "POWERED_ON"' do
      it "displays with green" do
        expect(subject.ui).to receive(:color).with("POWERED_ON", :green)
        subject.format_power_status(PowerStatus.new("POWERED_ON"))
      end
    end

    context 'when the power is "POWERED_OFF"' do
      it "displays with red" do
        expect(subject.ui).to receive(:color).with("POWERED_OFF", :red)
        subject.format_power_status(PowerStatus.new("POWERED_OFF"))
      end
    end

    context 'when the power is "SUSPENDED"' do
      it "displays with red" do
        expect(subject.ui).to receive(:color).with("SUSPENDED", :yellow)
        subject.format_power_status(PowerStatus.new("SUSPENDED"))
      end
    end
  end

  describe "#format_memory_value" do
    context "when the memory value is 8192" do
      it "displays as 8,192" do
        expect(subject.ui).to receive(:text).with("8,192")
        subject.format_memory_value(8192)
      end
    end
  end
end
