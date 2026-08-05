# frozen_string_literal: true
#
# Author:: Chef Partner Engineering (<partnereng@chef.io>)
# Copyright:: Copyright (c) 2017-2024 Progress Software Corporation and/or its subsidiaries or affiliates. All Rights Reserved.
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

# knife-cloud's WinrmBootstrapProtocol does
# `require "winrm" unless defined?(WinRM::Connection)`. The upstream "winrm"
# gem is unmaintained and not a declared dependency of this plugin, so this
# raises a LoadError on every --connection-protocol winrm bootstrap. The
# actively maintained fork "chef-winrm" defines the same WinRM::Connection
# class, satisfying the guard, so we require it here first (falling back to
# "winrm" directly in case a future environment has the real gem installed).
begin
  require "chef-winrm" unless defined?(WinRM::Connection)
rescue LoadError
  require "winrm" unless defined?(WinRM::Connection)
end

require "chef/knife"
require "chef/knife/cloud/chefbootstrap/winrm_bootstrap_protocol"

class Chef
  # The main knife class
  class Knife
    # The main cloud class from knife-cloud
    class Cloud
      # Patches WinrmBootstrapProtocol: upstream's wait_for_server_ready has
      # no port default at all (unlike SSH, which falls back to --ssh-port),
      # so it probes TCPSocket.new(host, nil) and hangs forever. This adds
      # a default of 5985 (or 5986 with --winrm-ssl) and treats
      # EADDRNOTAVAIL as a transient/retryable error.
      class WinrmBootstrapProtocol
        # Standard WinRM ports used when --connection-port isn't given.
        DEFAULT_WINRM_PORT = 5985
        DEFAULT_WINRM_SSL_PORT = 5986

        def wait_for_server_ready
          print "\n#{ui.color("Waiting for winrm to host (#{@config[:bootstrap_ip_address]})", :magenta)}"

          winrm_port = @config[:connection_port] || (@config[:winrm_ssl] ? DEFAULT_WINRM_SSL_PORT : DEFAULT_WINRM_PORT)

          print(".") until tcp_test_winrm(@config[:bootstrap_ip_address], winrm_port) do
            sleep @initial_sleep_delay ||= 10
            puts("done")
          end
        end

        def tcp_test_winrm(hostname, port)
          tcp_socket = TCPSocket.new(hostname, port)
          true
        rescue SocketError
          sleep 2
          false
        rescue Errno::ETIMEDOUT
          false
        rescue Errno::EPERM
          false
        rescue Errno::ECONNREFUSED, Errno::EHOSTUNREACH, Errno::ENETUNREACH, Errno::EADDRNOTAVAIL
          sleep 2
          false
        ensure
          tcp_socket && tcp_socket.close
        end
      end
    end
  end
end
