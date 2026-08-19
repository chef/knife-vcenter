# QMetry Test Cases — knife-vcenter E2E Suite

Copy/paste per test case into QMetry. `TC00` is a shared setup/precondition; all other cases assume it has been completed so vCenter/Chef Server credentials do not need to be repeated on every command.

## TC00 — Shared setup: configure vCenter + Chef Server connection once via .chef/config.rb and validate connectivity

**Precondition:** knife-vcenter plugin installed/bundled; vCenter lab reachable; Chef Infra Server reachable (if bootstrapped nodes must register); valid credentials for both

**Priority:** Critical | **Type:** Setup/Precondition | **Automation Status:** Manual | **Labels/Component:** Environment/Setup

| Step Detail | Test Data | Expected Result |
|---|---|---|
| 1. Create/update .chef/config.rb (or ~/.chef/config.rb) with: chef_server_url, node_name, client_key (Chef Server identity) and knife[:vcenter_host], knife[:vcenter_username], knife[:vcenter_password], knife[:vcenter_disable_ssl_verify] = true (vCenter identity) ; 2. Run: knife ssl fetch ; 3. Run: knife ssl check | chef_server_url=https://<chef-server>/organizations/<org>; node_name=<user>; vcenter_host=vcenter.example.com; vcenter_username=administrator@vsphere.local; vcenter_disable_ssl_verify=true | config.rb is valid Ruby and loads without error. 'knife ssl fetch' downloads and trusts the Chef Server's SSL certificate into .chef/trusted_certs with no errors. 'knife ssl check' reports 'Successfully verified certificates from ...' with exit code 0. When running 'knife vcenter *' commands manually from the command line, subsequent commands (TC01-TC13) need NO --vcenter-host/--vcenter-username/--vcenter-password/--vcenter-disable-ssl-verify flags, since they are read from .chef/config.rb automatically. (Note: the automated test/e2e/run_e2e_tests.sh harness always passes these flags explicitly from its own environment variables and does not rely on .chef/config.rb.) |

## TC01 — Verify 'knife vcenter cluster list' returns available clusters

**Precondition:** TC00 completed (vCenter + Chef Server config present in .chef/config.rb); vCenter lab reachable; valid credentials available; knife-vcenter plugin installed/bundled

**Priority:** High | **Type:** Functional | **Automation Status:** Automated | **Labels/Component:** vCenter/Cluster

| Step Detail | Test Data | Expected Result |
|---|---|---|
| 1. Run: knife vcenter cluster list | host=vcenter.example.com; datacenter=DC01 | Command exits 0. Output lists all vSphere clusters in the datacenter with ID and Name columns, no errors. |

## TC02 — Verify 'knife vcenter datacenter list' returns available datacenters

**Precondition:** TC00 completed (vCenter + Chef Server config present in .chef/config.rb); vCenter lab reachable; valid credentials available

**Priority:** High | **Type:** Functional | **Automation Status:** Automated | **Labels/Component:** vCenter/Datacenter

| Step Detail | Test Data | Expected Result |
|---|---|---|
| 1. Run: knife vcenter datacenter list | host=vcenter.example.com | Command exits 0. Output lists all datacenters with ID and Name columns, no errors. |

## TC03 — Verify 'knife vcenter host list' returns available ESXi hosts

**Precondition:** TC00 completed (vCenter + Chef Server config present in .chef/config.rb); vCenter lab reachable; valid credentials available

**Priority:** High | **Type:** Functional | **Automation Status:** Automated | **Labels/Component:** vCenter/Host

| Step Detail | Test Data | Expected Result |
|---|---|---|
| 1. Run: knife vcenter host list | host=vcenter.example.com | Command exits 0. Output lists ESXi hosts with ID, Name, Power State, Connection State columns, no errors. |

## TC04 — Verify 'knife vcenter vm list' baseline listing before test VMs are created

**Precondition:** TC00 completed (vCenter + Chef Server config present in .chef/config.rb); vCenter lab reachable; valid credentials available

**Priority:** Medium | **Type:** Functional | **Automation Status:** Automated | **Labels/Component:** vCenter/VM

| Step Detail | Test Data | Expected Result |
|---|---|---|
| 1. Run: knife vcenter vm list | host=vcenter.example.com | Command exits 0. Output lists existing VMs (ID, Name, Power State, CPU Count, RAM Size) or an empty table if none exist, no errors. |

## TC05.18 — Verify 'knife vcenter vm clone' clones a Linux template and bootstraps it with Chef Infra Client 18 over SSH

**Precondition:** TC00 completed (vCenter + Chef Server config present in .chef/config.rb); vCenter lab reachable; Linux template 'Templates/debian-13.3.0-amd64' exists; target host/folder/pool valid; SSH guest credentials valid

**Priority:** Critical | **Type:** Functional | **Automation Status:** Automated | **Labels/Component:** vCenter/VM Clone/Linux/SSH/Chef18

| Step Detail | Test Data | Expected Result |
|---|---|---|
| 1. Run: knife vcenter vm clone <vm_name> --datacenter DC01 --template Templates/debian-13.3.0-amd64 --targethost <targethost> --folder vm --pool Resources --connection-protocol ssh --image-os-type linux --connection-user progress --connection-password <pass> --ssh-verify-host-key never --bootstrap-version 18 -N <vm_name> -y ; 2. Wait for clone, network assignment, and bootstrap to complete | template=Templates/debian-13.3.0-amd64; bootstrap-version=18; vm_name=e2e-<run>-lin-chef18 | Command exits 0. VM is cloned, powered on, receives an IP, SSH becomes reachable, and Chef Infra Client 18 bootstraps successfully (node registers, no bootstrap errors/timeouts). |

## TC06.18 — Verify 'knife vcenter vm show' displays details for the Linux/Chef18 VM created in TC05.18

**Precondition:** TC00 completed (vCenter + Chef Server config present in .chef/config.rb); TC05.18 completed successfully; VM exists in vCenter

**Priority:** Medium | **Type:** Functional | **Automation Status:** Automated | **Labels/Component:** vCenter/VM Show

| Step Detail | Test Data | Expected Result |
|---|---|---|
| 1. Run: knife vcenter vm show <vm_name> | vm_name=e2e-<run>-lin-chef18 | Command exits 0. Output shows correct VM ID, Name, and Power State = POWERED_ON, no errors. |

## TC05.19 — Verify 'knife vcenter vm clone' clones a Linux template and bootstraps it with Chef Infra Client 19 over SSH

**Precondition:** TC00 completed (vCenter + Chef Server config present in .chef/config.rb); vCenter lab reachable; Linux template exists; target host/folder/pool valid; SSH guest credentials valid

**Priority:** Critical | **Type:** Functional | **Automation Status:** Automated | **Labels/Component:** vCenter/VM Clone/Linux/SSH/Chef19

| Step Detail | Test Data | Expected Result |
|---|---|---|
| 1. Run: knife vcenter vm clone <vm_name> --datacenter DC01 --template Templates/debian-13.3.0-amd64 --targethost <targethost> --folder vm --pool Resources --connection-protocol ssh --image-os-type linux --connection-user progress --connection-password <pass> --ssh-verify-host-key never --bootstrap-version 19 -N <vm_name> -y ; 2. Wait for clone, network assignment, and bootstrap to complete | template=Templates/debian-13.3.0-amd64; bootstrap-version=19; vm_name=e2e-<run>-lin-chef19 | Command exits 0. VM is cloned, powered on, receives an IP, SSH becomes reachable, and Chef Infra Client 19 bootstraps successfully (node registers, no bootstrap errors/timeouts). |

## TC06.19 — Verify 'knife vcenter vm show' displays details for the Linux/Chef19 VM created in TC05.19

**Precondition:** TC00 completed (vCenter + Chef Server config present in .chef/config.rb); TC05.19 completed successfully; VM exists in vCenter

**Priority:** Medium | **Type:** Functional | **Automation Status:** Automated | **Labels/Component:** vCenter/VM Show

| Step Detail | Test Data | Expected Result |
|---|---|---|
| 1. Run: knife vcenter vm show <vm_name> | vm_name=e2e-<run>-lin-chef19 | Command exits 0. Output shows correct VM ID, Name, and Power State = POWERED_ON, no errors. |

## TC07.18 — Verify 'knife vcenter vm clone' clones a Windows template and bootstraps it with Chef Infra Client 18 over WinRM

**Precondition:** TC00 completed (vCenter + Chef Server config present in .chef/config.rb); vCenter lab reachable; Windows template 'Templates/windows2022' exists and has WinRM enabled/listening on 5985; target host/folder/pool valid; WinRM guest credentials valid

**Priority:** Critical | **Type:** Functional | **Automation Status:** Automated | **Labels/Component:** vCenter/VM Clone/Windows/WinRM/Chef18

| Step Detail | Test Data | Expected Result |
|---|---|---|
| 1. Run: knife vcenter vm clone <vm_name> --datacenter DC01 --template Templates/windows2022 --targethost <targethost> --folder vm --pool Resources --connection-protocol winrm --image-os-type windows --connection-user Administrator --connection-password <pass> --winrm-no-verify-cert --bootstrap-version 18 -N <vm_name> -y ; 2. Wait for clone, network assignment, and bootstrap to complete | template=Templates/windows2022; bootstrap-version=18; vm_name=e2e-<run>-win-chef18 | Command exits 0. VM is cloned, powered on, receives an IP, WinRM (port 5985/5986) becomes reachable, and Chef Infra Client 18 bootstraps successfully (node registers, no bootstrap errors/timeouts). |

## TC08.18 — Verify 'knife vcenter vm show' displays details for the Windows/Chef18 VM created in TC07.18

**Precondition:** TC00 completed (vCenter + Chef Server config present in .chef/config.rb); TC07.18 completed successfully; VM exists in vCenter

**Priority:** Medium | **Type:** Functional | **Automation Status:** Automated | **Labels/Component:** vCenter/VM Show

| Step Detail | Test Data | Expected Result |
|---|---|---|
| 1. Run: knife vcenter vm show <vm_name> | vm_name=e2e-<run>-win-chef18 | Command exits 0. Output shows correct VM ID, Name, and Power State = POWERED_ON, no errors. |

## TC07.19 — Verify 'knife vcenter vm clone' clones a Windows template and bootstraps it with Chef Infra Client 19 over WinRM

**Precondition:** TC00 completed (vCenter + Chef Server config present in .chef/config.rb); vCenter lab reachable; Windows template 'Templates/windows2022' exists and has WinRM enabled/listening on 5985; target host/folder/pool valid; WinRM guest credentials valid

**Priority:** Critical | **Type:** Functional | **Automation Status:** Automated | **Labels/Component:** vCenter/VM Clone/Windows/WinRM/Chef19

| Step Detail | Test Data | Expected Result |
|---|---|---|
| 1. Run: knife vcenter vm clone <vm_name> --datacenter DC01 --template Templates/windows2022 --targethost <targethost> --folder vm --pool Resources --connection-protocol winrm --image-os-type windows --connection-user Administrator --connection-password <pass> --winrm-no-verify-cert --bootstrap-version 19 -N <vm_name> -y ; 2. Wait for clone, network assignment, and bootstrap to complete | template=Templates/windows2022; bootstrap-version=19; vm_name=e2e-<run>-win-chef19 | Command exits 0. VM is cloned, powered on, receives an IP, WinRM (port 5985/5986) becomes reachable, and Chef Infra Client 19 bootstraps successfully (node registers, no bootstrap errors/timeouts). |

## TC08.19 — Verify 'knife vcenter vm show' displays details for the Windows/Chef19 VM created in TC07.19

**Precondition:** TC00 completed (vCenter + Chef Server config present in .chef/config.rb); TC07.19 completed successfully; VM exists in vCenter

**Priority:** Medium | **Type:** Functional | **Automation Status:** Automated | **Labels/Component:** vCenter/VM Show

| Step Detail | Test Data | Expected Result |
|---|---|---|
| 1. Run: knife vcenter vm show <vm_name> | vm_name=e2e-<run>-win-chef19 | Command exits 0. Output shows correct VM ID, Name, and Power State = POWERED_ON, no errors. |

## TC09 — Verify 'knife vcenter vm list' shows all VMs created by TC05-TC08 (post-clone)

**Precondition:** TC00 completed (vCenter + Chef Server config present in .chef/config.rb); TC05.18/TC05.19/TC07.18/TC07.19 completed (successfully or not); vCenter reachable

**Priority:** Medium | **Type:** Functional | **Automation Status:** Automated | **Labels/Component:** vCenter/VM List

| Step Detail | Test Data | Expected Result |
|---|---|---|
| 1. Run: knife vcenter vm list | N/A | Command exits 0. Output includes all 4 VMs created in this run (2 Linux, 2 Windows) with correct names and POWERED_ON state. |

## TC10 — Verify 'knife vcenter vm create' provisions a blank VM shell (Linux-flavored name)

**Precondition:** TC00 completed (vCenter + Chef Server config present in .chef/config.rb); vCenter lab reachable; valid --datastore name known (plugin has no 'datastore list' command); DATASTORE env var set to enable this test

**Priority:** Low | **Type:** Functional/Known-Limitation | **Automation Status:** Automated (gated) | **Labels/Component:** vCenter/VM Create

| Step Detail | Test Data | Expected Result |
|---|---|---|
| 1. Run: knife vcenter vm create <vm_name> --datacenter DC01 --targethost <targethost> --folder vm --pool Resources --datastore <datastore> -N <vm_name> -y | vm_name=e2e-<run>-lin-create; datastore=<user-provided> | Command exits 0. A blank VM (guest OS = OTHER, no template/OS installed - documented plugin limitation) is created and powered on in vCenter. Note: bootstrap is NOT expected to succeed since no OS is installed. |

## TC11 — Verify 'knife vcenter vm create' provisions a blank VM shell (Windows-flavored name)

**Precondition:** TC00 completed (vCenter + Chef Server config present in .chef/config.rb); Same as TC10

**Priority:** Low | **Type:** Functional/Known-Limitation | **Automation Status:** Automated (gated) | **Labels/Component:** vCenter/VM Create

| Step Detail | Test Data | Expected Result |
|---|---|---|
| 1. Run: knife vcenter vm create <vm_name> --datacenter DC01 --targethost <targethost> --folder vm --pool Resources --datastore <datastore> -N <vm_name> -y | vm_name=e2e-<run>-win-create; datastore=<user-provided> | Command exits 0. A blank VM (guest OS = OTHER, no template/OS installed - documented plugin limitation) is created and powered on in vCenter. Note: bootstrap is NOT expected to succeed since no OS is installed. |

## TC12.1 — Verify 'knife vcenter vm delete --purge' removes the Linux/Chef18 VM created in TC05.18

**Precondition:** TC00 completed (vCenter + Chef Server config present in .chef/config.rb); TC05.18 ran (VM exists, whether or not bootstrap succeeded)

**Priority:** High | **Type:** Cleanup | **Automation Status:** Automated | **Labels/Component:** vCenter/VM Delete

| Step Detail | Test Data | Expected Result |
|---|---|---|
| 1. Run: knife vcenter vm delete <vm_name> --purge -y | vm_name=e2e-<run>-lin-chef18 | Command exits 0. VM is powered off and removed from vCenter inventory; associated Chef node/client (if registered) is also deleted. |

## TC12.2 — Verify 'knife vcenter vm delete --purge' removes the Linux/Chef19 VM created in TC05.19

**Precondition:** TC00 completed (vCenter + Chef Server config present in .chef/config.rb); TC05.19 ran (VM exists, whether or not bootstrap succeeded)

**Priority:** High | **Type:** Cleanup | **Automation Status:** Automated | **Labels/Component:** vCenter/VM Delete

| Step Detail | Test Data | Expected Result |
|---|---|---|
| 1. Run: knife vcenter vm delete <vm_name> --purge -y | vm_name=e2e-<run>-lin-chef19 | Command exits 0. VM is powered off and removed from vCenter inventory; associated Chef node/client (if registered) is also deleted. |

## TC12.3 — Verify 'knife vcenter vm delete --purge' removes the Windows/Chef18 VM created in TC07.18

**Precondition:** TC00 completed (vCenter + Chef Server config present in .chef/config.rb); TC07.18 ran (VM exists, whether or not bootstrap succeeded)

**Priority:** High | **Type:** Cleanup | **Automation Status:** Automated | **Labels/Component:** vCenter/VM Delete

| Step Detail | Test Data | Expected Result |
|---|---|---|
| 1. Run: knife vcenter vm delete <vm_name> --purge -y | vm_name=e2e-<run>-win-chef18 | Command exits 0. VM is powered off and removed from vCenter inventory. Note: if bootstrap never completed, a benign 404 'could not find node to delete' warning is expected and does not indicate a VM-deletion failure - the VM purge itself must still succeed (verify via TC13). |

## TC12.4 — Verify 'knife vcenter vm delete --purge' removes the Windows/Chef19 VM created in TC07.19

**Precondition:** TC00 completed (vCenter + Chef Server config present in .chef/config.rb); TC07.19 ran (VM exists, whether or not bootstrap succeeded)

**Priority:** High | **Type:** Cleanup | **Automation Status:** Automated | **Labels/Component:** vCenter/VM Delete

| Step Detail | Test Data | Expected Result |
|---|---|---|
| 1. Run: knife vcenter vm delete <vm_name> --purge -y | vm_name=e2e-<run>-win-chef19 | Command exits 0. VM is powered off and removed from vCenter inventory. Note: if bootstrap never completed, a benign 404 'could not find node to delete' warning is expected and does not indicate a VM-deletion failure - the VM purge itself must still succeed (verify via TC13). |

## TC12.5 — Verify 'knife vcenter vm delete --purge' removes the vm create Linux VM created in TC10 (if run)

**Precondition:** TC00 completed (vCenter + Chef Server config present in .chef/config.rb); TC10 ran and created a VM

**Priority:** Low | **Type:** Cleanup | **Automation Status:** Automated (gated) | **Labels/Component:** vCenter/VM Delete

| Step Detail | Test Data | Expected Result |
|---|---|---|
| 1. Run: knife vcenter vm delete <vm_name> --purge -y | vm_name=e2e-<run>-lin-create | Command exits 0. VM is powered off and removed from vCenter inventory. |

## TC12.6 — Verify 'knife vcenter vm delete --purge' removes the vm create Windows VM created in TC11 (if run)

**Precondition:** TC00 completed (vCenter + Chef Server config present in .chef/config.rb); TC11 ran and created a VM

**Priority:** Low | **Type:** Cleanup | **Automation Status:** Automated (gated) | **Labels/Component:** vCenter/VM Delete

| Step Detail | Test Data | Expected Result |
|---|---|---|
| 1. Run: knife vcenter vm delete <vm_name> --purge -y | vm_name=e2e-<run>-win-create | Command exits 0. VM is powered off and removed from vCenter inventory. |

## TC13 — Verify 'knife vcenter vm list' shows none of this run's VMs remain (post-cleanup)

**Precondition:** TC00 completed (vCenter + Chef Server config present in .chef/config.rb); All TC12.* cleanup steps executed

**Priority:** Medium | **Type:** Cleanup Verification | **Automation Status:** Automated | **Labels/Component:** vCenter/VM List

| Step Detail | Test Data | Expected Result |
|---|---|---|
| 1. Run: knife vcenter vm list | N/A | Command exits 0. Output does not contain any VM name matching this run's VM_PREFIX (e.g. e2e-<run>-*); confirms full cleanup with no orphaned VMs left in vCenter. |
