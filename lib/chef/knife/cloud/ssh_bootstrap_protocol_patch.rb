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

require "chef/knife"
require "chef/knife/cloud/chefbootstrap/ssh_bootstrap_protocol"

class Chef
  # The main knife class
  class Knife
    # The main cloud class from knife-cloud
    class Cloud
      # Patches SshBootstrapProtocol: upstream's wait_for_server_ready never
      # falls back to port 22 when --connection-port/--ssh-port aren't set,
      # so it probes TCPSocket.new(host, nil) and hangs forever. This adds
      # the missing default, treats EADDRNOTAVAIL as a transient/retryable
      # error, and adds backoff plus periodic status output while waiting.
      class SshBootstrapProtocol
        # Maximum backoff between probe attempts, in seconds.
        SSH_PROBE_MAX_BACKOFF = 20
        # Minimum interval between status updates surfaced to the user, in seconds.
        SSH_PROBE_STATUS_INTERVAL = 15
        # Standard SSH port used when neither --connection-port nor --ssh-port is given.
        DEFAULT_SSH_PORT = 22

        # Waits until sshd is reachable on the bootstrap IP before returning.
        # Falls back to the standard SSH port 22 when neither
        # --connection-port nor --ssh-port is configured (see class comment).
        #
        # @return [void]
        def wait_for_server_ready
          print "\n#{ui.color("Waiting for sshd to host (#{config[:bootstrap_ip_address]})", :magenta)}"

          ssh_gateway = get_ssh_gateway_for(config[:bootstrap_ip_address])
          ssh_port = config[:connection_port] || config[:ssh_port] || DEFAULT_SSH_PORT

          if ssh_gateway
            print(".") until tunnel_test_ssh(ssh_gateway, config[:bootstrap_ip_address]) do
              @initial_sleep_delay = !!config[:subnet_id] ? 40 : 10
              sleep @initial_sleep_delay
              puts("done")
            end
          else
            print(".") until tcp_test_ssh(config[:bootstrap_ip_address], ssh_port) do
              @initial_sleep_delay = !!config[:subnet_id] ? 40 : 10
              sleep @initial_sleep_delay
              puts("done")
            end
          end
        end

        # Tests whether sshd is accepting connections on the given host/port
        #
        # @param [String] hostname The host to test the SSH connection against
        # @param [Integer] ssh_port The port to test the SSH connection against
        # @return [Boolean] true if sshd is accepting connections, false otherwise
        def tcp_test_ssh(hostname, ssh_port)
          tcp_socket = TCPSocket.new(hostname, ssh_port)
          readable = IO.select([tcp_socket], nil, nil, 5)
          if readable
            ssh_banner = tcp_socket.gets
            if ssh_banner.nil? || ssh_banner.empty?
              record_ssh_probe_failure(hostname, "TCP connected but received no SSH banner yet")
              false
            else
              Chef::Log.debug("ssh accepting connections on #{hostname}, banner is #{tcp_socket.gets}")
              yield
              true
            end
          else
            record_ssh_probe_failure(hostname, "TCP connect did not become readable within 5s")
            false
          end
        rescue Errno::EPERM, Errno::ETIMEDOUT => e
          Chef::Log.debug("ssh timed out: #{hostname}")
          record_ssh_probe_failure(hostname, e)
          false
        rescue SocketError, Errno::ECONNREFUSED, Errno::EHOSTUNREACH, Errno::ENETUNREACH, Errno::EADDRNOTAVAIL, IOError => e
          Chef::Log.debug("ssh failed to connect: #{hostname}")
          record_ssh_probe_failure(hostname, e)
          backoff_before_next_ssh_probe
          false
        # This happens on some mobile phone networks
        rescue Errno::ECONNRESET => e
          Chef::Log.debug("ssh reset its connection: #{hostname}")
          record_ssh_probe_failure(hostname, e)
          backoff_before_next_ssh_probe
          false
        ensure
          tcp_socket && tcp_socket.close
        end

        private

        # Records a failed probe attempt and surfaces a throttled status line.
        #
        # @param [String] hostname The host being probed
        # @param [String, Exception] reason Why this attempt failed
        # @return [void]
        def record_ssh_probe_failure(hostname, reason)
          @ssh_probe_started_at ||= Time.now
          @ssh_probe_attempts = (@ssh_probe_attempts || 0) + 1

          detail = reason.is_a?(Exception) ? "#{reason.class}: #{reason.message}" : reason
          elapsed = Time.now - @ssh_probe_started_at
          Chef::Log.debug(format("SSH readiness probe attempt #%d for %s failed after %.1fs total: %s", @ssh_probe_attempts, hostname, elapsed, detail))

          return if @ssh_probe_last_status_at && (Time.now - @ssh_probe_last_status_at) < SSH_PROBE_STATUS_INTERVAL

          @ssh_probe_last_status_at = Time.now
          ui.warn(format("\nStill waiting for sshd on %s (attempt #%d, %ds elapsed) - last result: %s", hostname, @ssh_probe_attempts, elapsed.to_i, detail))
        end

        # Sleeps a capped exponential backoff (with jitter) before the next probe.
        #
        # @return [void]
        def backoff_before_next_ssh_probe
          attempt = @ssh_probe_attempts || 1
          base_delay = [2 * (2**(attempt - 1)), SSH_PROBE_MAX_BACKOFF].min
          sleep(base_delay + rand * 0.5)
        end
      end
    end
  end
end
