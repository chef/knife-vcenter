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

class UnexpectedSystemExit < RuntimeError
  def self.from(system_exit)
    new(system_exit.message).tap { |e| e.set_backtrace(system_exit.backtrace) }
  end
end

RSpec.configure do |c|
  c.raise_errors_for_deprecations!
  c.raise_on_warning = true
  c.filter_run_excluding exclude: true
  c.before(:each) do
    Chef::Config.reset
    Chef::Config[:knife] = {}
  end

  c.around(:example) do |ex|
    begin
      ex.run
    rescue SystemExit => e
      raise UnexpectedSystemExit.from(e)
    end
  end
end
