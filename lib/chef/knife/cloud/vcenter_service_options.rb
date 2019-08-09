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

class Chef
  class Knife
    class Cloud
      module VcenterServiceOptions
        # The main service options for this plugin
        #
        # @param [Object] includer are the options that can be handed off to this method
        def self.included(includer)
          includer.class_eval do
            option :vcenter_username,
              long: "--vcenter-username USERNAME",
              description: "Username to use to connect to the VCenter API"

            option :vcenter_password,
              long: "--vcenter-password PASSWORD",
              description: "Password associated with the specified user"

            option :vcenter_host,
              long: "--vcenter-host HOST",
              description: "Host to target for operations"

            option :vcenter_disable_ssl_verify,
              long: "--vcenter-disable-ssl-verify",
              description: "Skip any SSL verification for the API",
              boolean: true,
              default: false

            option :vcenter_logs,
              long: "--vcenter-logs",
              description: "Whether or not to display logs from VCenter SDK. Default: false",
              boolean: true,
              default: false
          end
        end
      end
    end
  end
end
