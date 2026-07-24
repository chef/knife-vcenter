# knife-vcenter End-to-End Test Suite

`run_e2e_tests.sh` exercises every `knife vcenter *` command against a real
vCenter environment and produces logs/reports suitable for attaching to
QMetry test case executions.

## What it covers

| ID          | Scenario                                                    |
|-------------|--------------------------------------------------------------|
| TC01        | `knife vcenter cluster list`                                 |
| TC02        | `knife vcenter datacenter list`                               |
| TC03        | `knife vcenter host list`                                     |
| TC04        | `knife vcenter vm list` (baseline)                            |
| TC05.18     | `knife vcenter vm clone` - Linux, bootstrap Chef Infra Client 18 |
| TC06.18     | `knife vcenter vm show` for the TC05.18 VM                    |
| TC05.19     | `knife vcenter vm clone` - Linux, bootstrap Chef Infra Client 19 |
| TC06.19     | `knife vcenter vm show` for the TC05.19 VM                    |
| TC07.18     | `knife vcenter vm clone` - Windows, bootstrap Chef Infra Client 18 |
| TC08.18     | `knife vcenter vm show` for the TC07.18 VM                    |
| TC07.19     | `knife vcenter vm clone` - Windows, bootstrap Chef Infra Client 19 |
| TC08.19     | `knife vcenter vm show` for the TC07.19 VM                    |
| TC09        | `knife vcenter vm list` (post-clone, verifies all VMs present) |
| TC10        | `knife vcenter vm create` (Linux-flavored; see limitation below) |
| TC11        | `knife vcenter vm create` (Windows-flavored; see limitation below) |
| TC12.*      | `knife vcenter vm delete --purge` for every VM this run created |
| TC13        | `knife vcenter vm list` (post-cleanup, verifies VMs are gone) |

This is every command shipped by the plugin (`lib/chef/knife/vcenter_*.rb`):
`cluster_list`, `datacenter_list`, `host_list`, `vm_list`, `vm_show`,
`vm_clone`, `vm_create`, and `vm_delete`.

## Prerequisites

- `bundle install` has been run in the repo root.
- Network/VPN access to the target vCenter and to the cloned guest VMs.
- A valid vCenter account with permission to clone/create/delete VMs in the
  configured datacenter/folder/resource pool.
- The Linux and Windows templates referenced below must already exist in
  vCenter.

## Usage

```bash
cp test/e2e/e2e.env.example test/e2e/my-e2e.env
# edit test/e2e/my-e2e.env with your real password (and DATASTORE if you want
# TC10/TC11 to run) - do NOT commit this file
source test/e2e/my-e2e.env
./test/e2e/run_e2e_tests.sh
```

Or inline for a one-off run:

```bash
VCENTER_PASSWORD="$VRA_PASS" ./test/e2e/run_e2e_tests.sh
```

### Options

- `--quick` - only run the fast, read-only commands (TC01-TC04). No VMs are
  created or deleted. Useful as a smoke test / sanity check of connectivity
  and credentials before committing to a full (~30-60 minute) run.
- `--only TC05.18,TC06.18` - run only the specified test IDs (comma
  separated). Useful for re-running a single scenario that failed.
- `--skip-cleanup` - leave every VM created by this run in place instead of
  deleting it at the end (TC12.* and TC13 are skipped). You are responsible
  for cleaning these up manually afterwards.

### Output

Each run creates a timestamped directory:

```
test/e2e/results/<RUN_ID>/
  TC01.log            # one file per test: exact command + full output + status
  TC02.log
  ...
  summary.csv         # TestID,Description,Status,DurationSeconds,LogFile
  report.md           # single consolidated report: every command + full
                       # output + PASS/FAIL/TIMEOUT/SKIPPED, ready to paste
                       # into a QMetry execution comment/attachment
```

`summary.csv` is meant for bulk-importing execution results into QMetry;
`report.md` is meant for attaching full evidence (command + output) to each
individual QMetry test case execution.

All configured passwords (`VCENTER_PASSWORD`, `LINUX_CONNECTION_PASSWORD`,
`WINDOWS_CONNECTION_PASSWORD`) are redacted from every printed command and
every log file.

Every VM created by a run is named `<VM_PREFIX>-<suffix>`, where
`VM_PREFIX` defaults to `e2e-<RUN_ID>` (e.g. `e2e-20260724-164500-lin-chef18`),
so concurrent/repeated runs never collide on VM names.

## Known limitations

- **`knife vcenter vm create` does not support templates.** Looking at
  `lib/chef/knife/vcenter_vm_create.rb` and
  `Chef::Knife::Cloud::VcenterService#create_server`'s `"create"` branch,
  this command always creates a blank VM with `guest_OS: OTHER` and no
  template/image - there is no installed OS, so the VM never boots into
  anything, gets an IP, or accepts SSH/WinRM connections. TC10/TC11
  therefore validate only the vSphere placement/create API call and that a
  VM object gets created - the post-create Chef bootstrap phase is expected
  to fail or time out, and a shorter `CREATE_TIMEOUT` is used accordingly.
  If you need a real OS-provisioned VM, use `knife vcenter vm clone`
  (TC05/TC07) instead.
- **TC10/TC11 require `DATASTORE`.** There is no `knife vcenter datastore
  list` command in this plugin to discover valid datastore names
  automatically, so these two tests are skipped unless you set the
  `DATASTORE` environment variable yourself.
- **Windows scenarios assume a default WinRM listener** (HTTP, negotiate
  auth, port 5985) is already configured on the Windows template. If your
  template requires HTTPS/Basic/Kerberos, add the relevant
  `--winrm-*`/`--kerberos-*` flags to the `vm clone`/`vm create` invocations
  in `run_e2e_tests.sh`.
- Each `vm clone`/`vm create` scenario is wrapped in a `timeout` (see
  `BOOTSTRAP_TIMEOUT`/`CREATE_TIMEOUT`). A run that legitimately needs longer
  (e.g. a slow Windows MSI download) will be marked `TIMEOUT` even though it
  might have succeeded given more time - increase the relevant timeout env
  var if you see this.
