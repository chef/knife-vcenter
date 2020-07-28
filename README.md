# knife-vcenter

[![Gem Version](https://badge.fury.io/rb/knife-vcenter.svg)](https://rubygems.org/gems/knife-vcenter)
[![Build status](https://badge.buildkite.com/47217bb5529337a493a4a29c8e45ea95f88997d981c2549b42.svg?branch=master)](https://buildkite.com/chef-oss/chef-knife-vcenter-master-verify)

**Umbrella Project**: [Knife](https://github.com/chef/chef-oss-practices/blob/master/projects/knife.md)

 **Project State**: [Active](https://github.com/chef/chef-oss-practices/blob/master/repo-management/repo-states.md#active)

 **Issues [Response Time Maximum](https://github.com/chef/chef-oss-practices/blob/master/repo-management/repo-states.md)**: 14 days

 **Pull Request [Response Time Maximum](https://github.com/chef/chef-oss-practices/blob/master/repo-management/repo-states.md)**: 14 days

This is the official Chef Knife plugin for VMware REST API. This plugin gives knife the ability to create, bootstrap, and manage VMware vms.
- Documentation: [https://github.com/chef/knife-vcenter/blob/master/README.md](https://github.com/chef/knife-vcenter/blob/master/README.md)
- Source: [https://github.com/chef/knife-vcenter/tree/master](https://github.com/chef/knife-vcenter/tree/master)
- Issues: [https://github.com/chef/knife-vcenter/issues](https://github.com/chef/knife-vcenter/issues)
- Slack: sign up: https://code.vmware.com/slack/ slack channel: #chef
- Mailing list: [https://discourse.chef.io/](https://discourse.chef.io/)

This is a `knife` plugin that allows interaction with vSphere using the vSphere Automation SDK.

Please refer to the [CHANGELOG](CHANGELOG.md) for version history and known issues.

## Requirements

- Chef 13.0 higher
- Ruby 2.3.3 or higher

## Installation

Using [ChefDK](https://downloads.chef.io/chef-dk/), simply install the Gem:

```bash
chef gem install knife-vcenter
```

If you're using bundler, simply add Chef and knife-vcenter to your Gemfile:

```ruby
gem 'chef'
gem 'knife-vcenter'
```

## Configuration

In order to communicate with vSphere, you must specify your user credentials. You can specify them in your `knife.rb` file:

```ruby
knife[:vcenter_username] = "myuser"
knife[:vcenter_password] = "mypassword"
knife[:vcenter_host] = "172.16.20.2"
knife[:vcenter_disable_ssl_verify] = true # if you want to disable SSL checking
```

or alternatively you can supply them on the command-line:

```bash
knife vcenter _command_ --vcenter-username myuser --vcenter-password mypassword
```

### vCenter Permissions

You need the following permissions (at minimum) on your user to be able to use `knife-vcenter`.

* Datastore
    * Allocate space :ballot_box_with_check:
    * Browse datastore :ballot_box_with_check:
* Host
    * Local Operations
         * Create virtual machine :ballot_box_with_check:
         * Delete virtual machine :ballot_box_with_check:
         * Manage user groups :ballot_box_with_check:
         * Reconfigure virtual machine :ballot_box_with_check:
 * Network
    * Assign Network :ballot_box_with_check:
 * Resource
    * Assign virtual machine to resource pool :ballot_box_with_check:
 * Virtual Machine :ballot_box_with_check:


## Usage

### knife vcenter cluster list

Lists the clusters on the connected vSphere environment

```
$ knife vcenter cluster list
ID           Name     DRS?   HA?
domain-c123  Cluster  False  False
```

## knife vcenter datacenter list

List the data centers configures in the vSphere environment

```
$ knife vcenter datacenter list
ID             Name
datacenter-21  Datacenter
```

## knife vcenter host list

List the hosts in the vSphere in the vSphere environment

```
$ knife vcenter host list
ID       Name          Power State  Connection State
host-28  172.16.20.3   POWERED_ON   CONNECTED
host-64  172.16.20.41  POWERED_ON   CONNECTED
host-69  172.16.20.42  POWERED_ON   CONNECTED
host-74  172.16.20.43  POWERED_ON   CONNECTED
host-79  172.16.20.44  POWERED_ON   CONNECTED
```

## knife vcenter vm list

List out all the virtual machines that exist in the vSphere environment

```
$ knife vcenter vm list
ID      Name                             Power State  CPU Count  RAM Size (MB)
vm-42   alpine-docker                    POWERED_OFF  1          4,024
vm-35   automate-ubuntu                  POWERED_OFF  1          4,096
vm-44   chef                             POWERED_OFF  1          4,096
vm-33   chef-automate                    POWERED_OFF  1          4,096
vm-34   chef-buildnode                   POWERED_OFF  1          4,096
vm-43   chef-compliance                  POWERED_OFF  1          4,096
vm-71   CyberArk                         POWERED_OFF  1          8,192
vm-45   jenkins                          POWERED_ON   4          8,096
vm-36   LFS                              POWERED_OFF  2          4,096
```

## knife vcenter vm show NAME

Display details about a specific virtual machine.

```
$ knife vcenter vm show chef
ID: vm-44
Name: chef
Power State: POWERED_OFF
```

_The IP address of the machine is not returned yet as this requires a call to a different SDK_

## knife vcenter vm clone NAME

Create a new machine by cloning an existing machine or a template. This machine will be bootstrapped by Chef, as long as all the relevant details are in the `knife.rb` file.

The following parameters are required:

 - `--datacenter` - Datacenter in the vSphere environment that controls the target host
 - `--template` - Name of the virtual machine or template to use

There are some optional parameters that can be specified:

 - `--targethost` - The host that the virtual machine should be created on. If not specified the first host in the cluster is used.
 - `--folder` - Folder that machine should be stored in. If specified this must already exist.
 - `--pool` - Name of the resource pool to use when creating the machine
 - `--disable_power_on` - Do not power on the machine. Default: false

```
$ knife vcenter vm clone example-01 --targethost 172.16.20.3 --folder example --ssh-password P@ssw0rd! --datacenter Datacenter --template ubuntu16-template -N example-01
Creating new machine
Waiting for network interfaces to become available...
ID: vm-183
Name: example-01
Power State: POWERED_ON
Bootstrapping the server by using bootstrap_protocol: ssh and image_os_type: linux

Waiting for sshd to host (10.0.0.167)
...
```

## knife vcenter vm delete NAME

Deletes a virtual machine from vSphere. If you supply `--purge` the machine will be removed from the Chef Server.

NOTE: The `--purge` option default expects the node name and hostname to be the same. Use `-N` if the node name and hostname are different.

```
$ knife vcenter vm delete example-01 -N example-01 --purge
Creating new machine
Waiting for network interfaces to become available...
ID: vm-183
Name: example-01
Power State: POWERED_ON
Bootstrapping the server by using bootstrap_protocol: ssh and image_os_type: linux

Waiting for sshd to host (10.0.0.167)
WARNING: Deleted node example-01
WARNING: Deleted client example-01
```

## Contributing

For information on contributing to this project see <https://github.com/chef/chef/blob/master/CONTRIBUTING.md>

## Development

* Report issues/questions/feature requests on [GitHub Issues][issues]

Pull requests are very welcome! Make sure your patches are well tested.
Please create a topic branch for every separate change you make. For
example:

1. Fork the repo
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Run the tests and rubocop, `bundle exec rake spec` and `bundle exec rake rubocop`
4. Commit your changes (`git commit -am 'Added some feature'`)
5. Push to the branch (`git push origin my-new-feature`)
6. Create new Pull Request

## License

Author:: Russell Seymour ([rseymour@chef.io](mailto:rseymour@chef.io))

Author:: JJ Asghar ([jj@chef.io](mailto:jj@chef.io))

Copyright:: Copyright (c) 2017-2020 Chef Software, Inc.

License:: Apache License, Version 2.0

```text
Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
```
