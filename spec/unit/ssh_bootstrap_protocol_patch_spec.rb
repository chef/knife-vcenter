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
require "chef/knife/cloud/ssh_bootstrap_protocol_patch"

describe Chef::Knife::Cloud::SshBootstrapProtocol do
  subject(:protocol) { described_class.new({}) }

  before do
    allow(protocol).to receive(:rand).and_return(0)
  end

  describe "#wait_for_server_ready" do
    subject(:protocol) { described_class.new(config) }

    let(:config) { { bootstrap_ip_address: "172.16.109.30" } }

    before do
      allow(protocol).to receive(:get_ssh_gateway_for).and_return(nil)
    end

    context "when neither --connection-port nor --ssh-port is configured" do
      it "defaults the probed port to 22 instead of nil (the real root cause of the hang)" do
        expect(protocol).to receive(:tcp_test_ssh).with("172.16.109.30", 22).and_return(true)

        protocol.wait_for_server_ready
      end
    end

    context "when --connection-port is configured" do
      it "uses the configured connection_port" do
        config[:connection_port] = 2222
        expect(protocol).to receive(:tcp_test_ssh).with("172.16.109.30", 2222).and_return(true)

        protocol.wait_for_server_ready
      end
    end

    context "when --ssh-port is configured" do
      it "uses the configured ssh_port" do
        config[:ssh_port] = 2200
        expect(protocol).to receive(:tcp_test_ssh).with("172.16.109.30", 2200).and_return(true)

        protocol.wait_for_server_ready
      end
    end
  end

  describe "regression: the actual root cause this patch fixes" do
    it "documents that TCPSocket.new(host, nil) is what upstream's missing default caused" do
      # This is not a mock - it demonstrates, at the Ruby level, exactly why the
      # bootstrap used to hang forever: upstream passed a nil port (because it
      # never defaulted to 22), and TCPSocket.new(host, nil) raises
      # Errno::EADDRNOTAVAIL deterministically regardless of whether the host
      # is reachable. Our wait_for_server_ready override above ensures this
      # patched protocol never passes nil for the port.
      expect { TCPSocket.new("127.0.0.1", nil) }.to raise_error(Errno::EADDRNOTAVAIL)
    end
  end

  describe "#tcp_test_ssh" do
    context "when TCPSocket.new raises Errno::EADDRNOTAVAIL" do
      it "treats it as a transient error, backs off, and returns false instead of raising" do
        allow(TCPSocket).to receive(:new).and_raise(Errno::EADDRNOTAVAIL, "connect(2)")
        allow(protocol).to receive(:sleep)

        result = protocol.tcp_test_ssh("172.16.108.240", 22)

        expect(result).to be false
        expect(protocol).to have_received(:sleep).with(2.0)
      end
    end

    context "when TCPSocket.new raises Errno::ECONNREFUSED" do
      it "still treats it as a transient error (preserves existing behavior)" do
        allow(TCPSocket).to receive(:new).and_raise(Errno::ECONNREFUSED, "connect(2)")
        allow(protocol).to receive(:sleep)

        result = protocol.tcp_test_ssh("172.16.108.240", 22)

        expect(result).to be false
        expect(protocol).to have_received(:sleep).with(2.0)
      end
    end

    context "when the socket is not readable within the timeout" do
      it "returns false without raising and without an extra sleep" do
        tcp_socket = instance_double(TCPSocket, close: nil)
        allow(TCPSocket).to receive(:new).and_return(tcp_socket)
        allow(IO).to receive(:select).and_return(nil)
        allow(protocol).to receive(:sleep)

        expect(protocol.tcp_test_ssh("172.16.108.240", 22)).to be false
        expect(protocol).not_to have_received(:sleep)
      end
    end

    context "when sshd is accepting connections" do
      it "yields and returns true" do
        tcp_socket = instance_double(TCPSocket, close: nil, gets: "SSH-2.0-OpenSSH_9.2\n")
        allow(TCPSocket).to receive(:new).and_return(tcp_socket)
        allow(IO).to receive(:select).and_return([tcp_socket])

        yielded = false
        result = protocol.tcp_test_ssh("172.16.108.240", 22) { yielded = true }

        expect(result).to be true
        expect(yielded).to be true
      end
    end

    context "backoff growth across repeated failures" do
      it "doubles the backoff on each successive failure up to the cap" do
        allow(TCPSocket).to receive(:new).and_raise(Errno::ECONNREFUSED, "connect(2)")
        allow(protocol).to receive(:sleep)

        protocol.tcp_test_ssh("172.16.108.240", 22) # attempt 1 -> 2s
        protocol.tcp_test_ssh("172.16.108.240", 22) # attempt 2 -> 4s
        protocol.tcp_test_ssh("172.16.108.240", 22) # attempt 3 -> 8s

        expect(protocol).to have_received(:sleep).with(2.0).ordered
        expect(protocol).to have_received(:sleep).with(4.0).ordered
        expect(protocol).to have_received(:sleep).with(8.0).ordered
      end

      it "never exceeds the configured maximum backoff" do
        allow(TCPSocket).to receive(:new).and_raise(Errno::ECONNREFUSED, "connect(2)")
        allow(protocol).to receive(:sleep)

        10.times { protocol.tcp_test_ssh("172.16.108.240", 22) }

        expect(protocol).to have_received(:sleep).with(described_class::SSH_PROBE_MAX_BACKOFF.to_f).at_least(:once)
        expect(protocol).not_to have_received(:sleep).with(a_value > described_class::SSH_PROBE_MAX_BACKOFF)
      end
    end

    context "diagnostic status reporting" do
      it "surfaces a throttled status update with the exact last error to the user" do
        allow(TCPSocket).to receive(:new).and_raise(Errno::EADDRNOTAVAIL, "connect(2) for boom")
        allow(protocol).to receive(:sleep)
        allow(protocol.ui).to receive(:warn)

        protocol.tcp_test_ssh("172.16.108.240", 22)

        expect(protocol.ui).to have_received(:warn).with(/Still waiting for sshd on 172.16.108.240.*Errno::EADDRNOTAVAIL/)
      end

      it "does not spam a status update on every single failed attempt" do
        allow(TCPSocket).to receive(:new).and_raise(Errno::ECONNREFUSED, "connect(2)")
        allow(protocol).to receive(:sleep)
        allow(protocol.ui).to receive(:warn)

        3.times { protocol.tcp_test_ssh("172.16.108.240", 22) }

        expect(protocol.ui).to have_received(:warn).once
      end
    end
  end
end
