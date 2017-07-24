# knife-vcenter

This is a Kniffe plugin that allows interaction with vSphere using the vSphere Automation SDK.

# vCenter

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
knife vcenter _command_ --vcenter-username myuser --vcanter-password mypassword
```

## Usage

### knife vcenter cluster list

Lists the clusters on the connected vSphere environment

```
$ knife vcenter cluster list
ID           Name     DRS?   HA?
domain-c123  Cluster  False  False
```

## knife vcenter datacenter list

List the data centers configures in the vSPeher envirnonment

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

Parameters that are required are:

 - `--targethost` - The host that the virtual machine should be created on
 - `--folder` - Folder that machine should be stored in. This must already exist.
 - `--datacenter` - Datacenter in the vSphere environment that controls the target host
 - `--template` - Name of the virtual machine or template to use

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

NOTE: If the node name is different to the host name then the `-N` argument must be specified in conjunction with the `--purge` option

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