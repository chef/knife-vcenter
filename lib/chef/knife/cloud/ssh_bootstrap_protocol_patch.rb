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

require "chef/knife"
require "chef/knife/cloud/chefbootstrap/ssh_bootstrap_protocol"

class Chef
  # The main knife class
  class Knife
    # The main cloud class from knife-cloud
    class Cloud
      # Patches SshBootstrapProtocol to fix a real upstream defect and to make
      # the SSH-readiness wait loop resilient and diagnosable.
      #
      # ROOT CAUSE FIX: upstream's `wait_for_server_ready` computes the SSH
      # port as `config[:connection_port] || config[:ssh_port]` with NO
      # fallback to the standard port 22 (unlike its own ssh_gateway branch a
      # few lines below, which correctly does fall back to `|| 22`). When a
      # user doesn't pass --connection-port/--ssh-port (the common case),
      # this results in `TCPSocket.new(hostname, nil)`, which deterministically
      # raises Errno::EADDRNOTAVAIL on every single attempt, forever - even
      # though the VM is genuinely reachable on port 22 the whole time. This
      # was confirmed by direct reproduction: `TCPSocket.new(ip, nil)` raises
      # exactly this error, while `TCPSocket.new(ip, 22)` against the same VM
      # at the same moment succeeds immediately. This is why clones would
      # "hang forever" waiting for sshd even though `ssh`/`nc` to the same
      # host succeeded instantly from another terminal - the code was never
      # actually testing port 22, it was testing port nil. We override
      # `wait_for_server_ready` to add the missing `|| 22` default.
      #
      # We also keep two defense-in-depth improvements from earlier hardening:
      #   * Errno::EADDRNOTAVAIL is treated as a transient, retryable error in
      #     `tcp_test_ssh` (same bucket as ECONNREFUSED/ENETUNREACH/
      #     EHOSTUNREACH) instead of aborting the bootstrap outright, in case
      #     a *genuine* transient local networking error occurs.
      #   * A capped exponential backoff with jitter, plus periodic
      #     (throttled) status output showing the attempt count, elapsed
      #     time, and the exact last error, so any remaining wait is visible
      #     and explainable instead of a silent wall of dots.
      class SshBootstrapProtocol
        # Maximum backoff between probe attempts, in seconds.
        SSH_PROBE_MAX_BACKOFF = 20
        # Minimum interval between status updates surfaced to the user, in seconds.
        SSH_PROBE_STATUS_INTERVAL = 15
        # Standard SSH port used when neither --connection-port nor --ssh-port is given.
        DEFAULT_SSH_PORT = 22

        # Waits until sshd is reachable on the bootstrap IP before returning.
        #
        # Upstream's direct (non-gateway) code path builds the port with
        # `config[:connection_port] || config[:ssh_port]` and, unlike the
        # ssh_gateway branch a few lines below it (which correctly falls back to
        # `|| 22`), never falls back to the standard SSH port. When neither
        # --connection-port nor --ssh-port is passed on the command line (the
        # common case), this passes a `nil` port straight into
        # `TCPSocket.new(hostname, nil)`, which deterministically raises
        # Errno::EADDRNOTAVAIL on every single attempt - forever - even though
        # the VM is genuinely reachable on port 22 the whole time. This is the
        # real root cause of "clone succeeds but bootstrap hangs/fails forever
        # even though the VM is sshable": we were never actually testing port
        # 22, we were testing port nil. We override the method here to apply
        # the same `|| 22` fallback the gateway branch already uses.
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

        # Records diagnostic state for a failed probe attempt and, no more often than
        # every SSH_PROBE_STATUS_INTERVAL seconds, surfaces a status line to the user
        # showing the attempt count, elapsed time, and the exact last failure - so a
        # long wait is visible and explainable instead of a silent wall of dots.
        #
        # @param [String] hostname The host being probed
        # @param [String, Exception] reason A description or exception describing why this attempt failed
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

        # Sleeps a capped exponential backoff (with jitter) before the next probe
        # attempt, instead of reconnecting immediately, to reduce connection churn
        # against the target.
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
