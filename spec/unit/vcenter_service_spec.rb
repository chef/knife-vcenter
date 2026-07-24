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
require "chef/config"
require "chef/knife/cloud/vcenter_service"

describe Chef::Knife::Cloud::VcenterService do
  subject(:service) { described_class.allocate }

  before do
    service.instance_variable_set(:@connection_options, { user: "test-user", host: "vcenter.example.test" })
  end

  describe "#validate_list_response!" do
    let(:resource_type) { "clusters" }

    context "when response is an array" do
      it "returns the original resources" do
        resources = [double(:cluster)]

        expect(service.send(:validate_list_response!, resources, resource_type)).to eq(resources)
      end
    end

    context "when response is unauthenticated" do
      before do
        stub_const("VSphereAutomation", Module.new)
        vsphere_vcenter = Module.new
        unauthenticated_class = Class.new
        vsphere_vcenter.const_set(:VapiStdErrorsUnauthenticated, unauthenticated_class)
        VSphereAutomation.const_set(:VCenter, vsphere_vcenter)
      end

      it "raises a clear authentication error" do
        resources = VSphereAutomation::VCenter::VapiStdErrorsUnauthenticated.new

        expect do
          service.send(:validate_list_response!, resources, resource_type)
        end.to raise_error(RuntimeError, "Authentication to vCenter failed for user test-user on host vcenter.example.test")
      end
    end

    context "when response is an unexpected object" do
      it "raises a clear unexpected response error" do
        expect do
          service.send(:validate_list_response!, Object.new, resource_type)
        end.to raise_error(RuntimeError, /Unexpected vCenter response while listing clusters: Object/)
      end
    end
  end

  describe "#create_api_session_id" do
    let(:session_api) { instance_double(VSphereAutomation::CIS::SessionApi) }
    let(:api_client) { double(:api_client) }

    before do
      service.instance_variable_set(:@api_client, api_client)
      service.instance_variable_set(:@connection_options, { user: "test-user", host: "vcenter.example.test" })
      allow(VSphereAutomation::CIS::SessionApi).to receive(:new).with(api_client).and_return(session_api)
    end

    context "when vCenter returns a valid session token" do
      it "returns the token" do
        response = double(:session_response, value: "session-token")
        allow(session_api).to receive(:create).with("").and_return(response)

        token = service.send(:create_api_session_id)

        expect(token).to eq("session-token")
      end
    end

    context "when vCenter returns unauthenticated response" do
      it "raises a clear authentication error" do
        response = VSphereAutomation::VCenter::VapiStdErrorsUnauthenticated.new
        allow(session_api).to receive(:create).with("").and_return(response)

        expect do
          service.send(:create_api_session_id)
        end.to raise_error(RuntimeError, "Authentication to vCenter failed for user test-user on host vcenter.example.test")
      end
    end
  end
end
