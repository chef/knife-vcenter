#!/usr/bin/env bash
#
# knife-vcenter End-to-End Test Suite
# ------------------------------------
# Exercises every `knife vcenter *` command against a real vCenter environment
# and produces per-test logs plus a QMetry-friendly CSV summary and a single
# consolidated report containing the exact command and its full output for
# every scenario, so results can be pasted/attached directly into QMetry test
# case executions.
#
# See test/e2e/README.md for full usage instructions, prerequisites, and
# known limitations.
#
# Usage:
#   VCENTER_PASSWORD=*** ./test/e2e/run_e2e_tests.sh [options]
#
# Options:
#   --quick             Only run the fast, non-destructive read-only commands
#                        (cluster/datacenter/host/vm list). No VMs are created.
#   --only ID1,ID2,...  Run only the given test IDs (see the TEST PLAN section
#                        below for IDs), e.g. --only TC05,TC06
#   --skip-cleanup      Do not delete VMs created by this run at the end
#                        (useful if you want to inspect them manually first)
#   -h, --help          Show this help text
#
# Required environment variables (no defaults, must be supplied):
#   VCENTER_PASSWORD    Password for --vcenter-username
#
# Optional environment variables (sane defaults shown):
#   VCENTER_HOST, VCENTER_USERNAME, DATACENTER, TARGETHOST, FOLDER, POOL,
#   DATASTORE, LINUX_TEMPLATE, WINDOWS_TEMPLATE, LINUX_CONNECTION_USER,
#   LINUX_CONNECTION_PASSWORD, WINDOWS_CONNECTION_USER,
#   WINDOWS_CONNECTION_PASSWORD, LINUX_CHEF_VERSIONS, WINDOWS_CHEF_VERSIONS,
#   LIST_TIMEOUT, BOOTSTRAP_TIMEOUT, CREATE_TIMEOUT, VM_PREFIX, KNIFE
#
# See test/e2e/e2e.env.example for a fill-in-the-blanks template you can
# `source` before running this script.

set -uo pipefail

# ----------------------------------------------------------------------------
# Configuration
# ----------------------------------------------------------------------------
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$REPO_ROOT" || exit 1

VCENTER_HOST="${VCENTER_HOST:-vschefvc01.bedford.progress.com}"
VCENTER_USERNAME="${VCENTER_USERNAME:-asaidala@bedford.progress.com}"
VCENTER_PASSWORD="${VCENTER_PASSWORD:-${VRA_PASS:-}}"
DATACENTER="${DATACENTER:-Marlborough}"
TARGETHOST="${TARGETHOST:-vschefvc01-vesx1.bedford.progress.com}"
FOLDER="${FOLDER:-vm}"
POOL="${POOL:-Resources}"
DATASTORE="${DATASTORE:-}"

LINUX_TEMPLATE="${LINUX_TEMPLATE:-Templates/debian-13.3.0-amd64}"
WINDOWS_TEMPLATE="${WINDOWS_TEMPLATE:-Templates/windows2022}"

LINUX_CONNECTION_USER="${LINUX_CONNECTION_USER:-progress}"
LINUX_CONNECTION_PASSWORD="${LINUX_CONNECTION_PASSWORD:-p@ssW0rd!}"
WINDOWS_CONNECTION_USER="${WINDOWS_CONNECTION_USER:-Administrator}"
WINDOWS_CONNECTION_PASSWORD="${WINDOWS_CONNECTION_PASSWORD:-p@ssW0rd!}"

# Chef Infra Client major versions to validate bootstrap against.
LINUX_CHEF_VERSIONS="${LINUX_CHEF_VERSIONS:-18 19}"
WINDOWS_CHEF_VERSIONS="${WINDOWS_CHEF_VERSIONS:-18 19}"

# Per-command timeouts, in seconds. Our knife-vcenter SSH-bootstrap fix means
# these no longer need to be "infinite" - a clone+bootstrap that hasn't
# finished within these windows is itself a test failure worth flagging.
LIST_TIMEOUT="${LIST_TIMEOUT:-120}"
SHOW_TIMEOUT="${SHOW_TIMEOUT:-60}"
DELETE_TIMEOUT="${DELETE_TIMEOUT:-180}"
BOOTSTRAP_TIMEOUT="${BOOTSTRAP_TIMEOUT:-1200}"
CREATE_TIMEOUT="${CREATE_TIMEOUT:-300}"

RUN_ID="$(date +%Y%m%d-%H%M%S)"
VM_PREFIX="${VM_PREFIX:-e2e-${RUN_ID}}"
KNIFE="${KNIFE:-bundle exec knife}"

LOG_DIR="$REPO_ROOT/test/e2e/results/${RUN_ID}"
mkdir -p "$LOG_DIR"
SUMMARY_CSV="$LOG_DIR/summary.csv"
REPORT_MD="$LOG_DIR/report.md"

# ----------------------------------------------------------------------------
# CLI argument parsing
# ----------------------------------------------------------------------------
MODE="full"
ONLY_IDS=""
SKIP_CLEANUP="false"

while [ $# -gt 0 ]; do
  case "$1" in
    --quick) MODE="quick" ;;
    --only) ONLY_IDS="$2"; shift ;;
    --skip-cleanup) SKIP_CLEANUP="true" ;;
    -h|--help) sed -n '2,40p' "$0"; exit 0 ;;
    *) echo "Unknown option: $1" >&2; exit 1 ;;
  esac
  shift
done

if [ -z "$VCENTER_PASSWORD" ]; then
  echo "ERROR: VCENTER_PASSWORD (or VRA_PASS) must be set in the environment." >&2
  exit 1
fi

# shellcheck disable=SC2206
VCENTER_COMMON_OPTS=(
  --vcenter-host "$VCENTER_HOST"
  --vcenter-username "$VCENTER_USERNAME"
  --vcenter-password "$VCENTER_PASSWORD"
  --vcenter-disable-ssl-verify
)

# shellcheck disable=SC2206
KNIFE_CMD=($KNIFE)

echo "TestID,Description,Status,DurationSeconds,LogFile" > "$SUMMARY_CSV"
{
  echo "# knife-vcenter End-to-End Test Report"
  echo
  echo "- Run ID: \`${RUN_ID}\`"
  echo "- vCenter host: \`${VCENTER_HOST}\`"
  echo "- Started: $(date -u +%FT%TZ)"
  echo
} > "$REPORT_MD"

declare -a CREATED_VMS=()
PASS_COUNT=0
FAIL_COUNT=0
TIMEOUT_COUNT=0
SKIP_COUNT=0

# ----------------------------------------------------------------------------
# Helpers
# ----------------------------------------------------------------------------

# Redacts every configured secret from a string before it is ever printed or
# logged anywhere.
redact() {
  local s="$1"
  s="${s//$VCENTER_PASSWORD/********}"
  s="${s//$LINUX_CONNECTION_PASSWORD/********}"
  s="${s//$WINDOWS_CONNECTION_PASSWORD/********}"
  printf '%s' "$s"
}

should_run() {
  local id="$1"
  if [ -n "$ONLY_IDS" ]; then
    case ",$ONLY_IDS," in
      *",$id,"*) return 0 ;;
      *) return 1 ;;
    esac
  fi
  return 0
}

# run_test ID DESCRIPTION TIMEOUT_SECONDS -- cmd args...
run_test() {
  local id="$1" desc="$2" timeout_s="$3"
  shift 3
  if [ "${1:-}" = "--" ]; then shift; fi
  local cmd=("$@")

  if ! should_run "$id"; then
    echo "[$id] SKIPPED (not in --only list): $desc"
    echo "$id,\"$desc\",SKIPPED,0," >> "$SUMMARY_CSV"
    SKIP_COUNT=$((SKIP_COUNT + 1))
    return 0
  fi

  local log_file="$LOG_DIR/${id}.log"
  local printable
  printable="$(redact "${cmd[*]}")"

  echo "==============================================================================="
  echo "[$id] $desc"
  echo "COMMAND: $printable"
  echo "-------------------------------------------------------------------------------"

  {
    echo "### [$id] $desc"
    echo
    echo '```'
    echo "\$ $printable"
  } >> "$REPORT_MD"

  {
    echo "TEST ID: $id"
    echo "DESCRIPTION: $desc"
    echo "COMMAND: $printable"
    echo "STARTED (UTC): $(date -u +%FT%TZ)"
    echo "-------------------------------------------------------------------------------"
  } > "$log_file"

  local start end duration status rc
  start=$(date +%s)
  timeout "$timeout_s" "${cmd[@]}" >>"$log_file" 2>&1
  rc=$?
  end=$(date +%s)
  duration=$((end - start))

  if [ $rc -eq 0 ]; then
    status="PASS"
    PASS_COUNT=$((PASS_COUNT + 1))
  elif [ $rc -eq 124 ]; then
    status="TIMEOUT"
    TIMEOUT_COUNT=$((TIMEOUT_COUNT + 1))
  else
    status="FAIL"
    FAIL_COUNT=$((FAIL_COUNT + 1))
  fi

  {
    echo "-------------------------------------------------------------------------------"
    echo "FINISHED (UTC): $(date -u +%FT%TZ)"
    echo "EXIT CODE: $rc"
    echo "STATUS: $status"
    echo "DURATION: ${duration}s"
  } >> "$log_file"

  echo "OUTPUT:"
  cat "$log_file"
  echo "STATUS: $status   DURATION: ${duration}s   LOG: $log_file"
  echo "==============================================================================="
  echo

  {
    echo '```'
    echo
    echo "**Status:** ${status} | **Duration:** ${duration}s | **Exit code:** ${rc}"
    echo
    echo "<details><summary>Full output</summary>"
    echo
    echo '```'
    redact "$(cat "$log_file")"
    echo
    echo '```'
    echo "</details>"
    echo
  } >> "$REPORT_MD"

  echo "$id,\"$desc\",$status,$duration,$log_file" >> "$SUMMARY_CSV"
}

# ----------------------------------------------------------------------------
# TEST PLAN
# ----------------------------------------------------------------------------
# TC01            vcenter cluster list
# TC02            vcenter datacenter list
# TC03            vcenter host list
# TC04            vcenter vm list (baseline)
# TC05.<ver>      vm clone: Linux bootstrap, Chef <ver>
# TC06.<ver>      vm show for the Linux/<ver> VM
# TC07.<ver>      vm clone: Windows bootstrap, Chef <ver>
# TC08.<ver>      vm show for the Windows/<ver> VM
# TC09            vcenter vm list (post-create, verify all VMs present)
# TC10            vm create: blank/OS-less VM (Linux-flavored naming)
# TC11            vm create: blank/OS-less VM (Windows-flavored naming)
# TC12.*          vm delete for every VM created above (--purge)
# TC13            vcenter vm list (post-cleanup, verify VMs are gone)
# ----------------------------------------------------------------------------

if [ "$MODE" = "quick" ]; then
  ONLY_IDS="TC01,TC02,TC03,TC04"
fi

# --- TC01-TC04: read-only commands, safe to run anytime -----------------------
run_test TC01 "vcenter cluster list" "$LIST_TIMEOUT" -- \
  "${KNIFE_CMD[@]}" vcenter cluster list "${VCENTER_COMMON_OPTS[@]}"

run_test TC02 "vcenter datacenter list" "$LIST_TIMEOUT" -- \
  "${KNIFE_CMD[@]}" vcenter datacenter list "${VCENTER_COMMON_OPTS[@]}"

run_test TC03 "vcenter host list" "$LIST_TIMEOUT" -- \
  "${KNIFE_CMD[@]}" vcenter host list "${VCENTER_COMMON_OPTS[@]}"

run_test TC04 "vcenter vm list (baseline before this run's VMs are created)" "$LIST_TIMEOUT" -- \
  "${KNIFE_CMD[@]}" vcenter vm list "${VCENTER_COMMON_OPTS[@]}"

# --- TC05/TC06: Linux clone + bootstrap, one VM per Chef major version -------
for ver in $LINUX_CHEF_VERSIONS; do
  vm_name="${VM_PREFIX}-lin-chef${ver}"
  run_test "TC05.${ver}" "vm clone: Linux bootstrap with Chef Infra Client ${ver}" "$BOOTSTRAP_TIMEOUT" -- \
    "${KNIFE_CMD[@]}" vcenter vm clone "$vm_name" \
      "${VCENTER_COMMON_OPTS[@]}" \
      --datacenter "$DATACENTER" \
      --template "$LINUX_TEMPLATE" \
      --targethost "$TARGETHOST" \
      --folder "$FOLDER" \
      --pool "$POOL" \
      --connection-protocol ssh \
      --image-os-type linux \
      --connection-user "$LINUX_CONNECTION_USER" \
      --connection-password "$LINUX_CONNECTION_PASSWORD" \
      --ssh-verify-host-key never \
      --bootstrap-version "$ver" \
      -N "$vm_name" \
      -y
  if should_run "TC05.${ver}"; then CREATED_VMS+=("$vm_name"); fi

  run_test "TC06.${ver}" "vm show: Linux/Chef ${ver} VM ($vm_name)" "$SHOW_TIMEOUT" -- \
    "${KNIFE_CMD[@]}" vcenter vm show "$vm_name" "${VCENTER_COMMON_OPTS[@]}"
done

# --- TC07/TC08: Windows clone + bootstrap, one VM per Chef major version -----
for ver in $WINDOWS_CHEF_VERSIONS; do
  vm_name="${VM_PREFIX}-win-chef${ver}"
  run_test "TC07.${ver}" "vm clone: Windows bootstrap with Chef Infra Client ${ver}" "$BOOTSTRAP_TIMEOUT" -- \
    "${KNIFE_CMD[@]}" vcenter vm clone "$vm_name" \
      "${VCENTER_COMMON_OPTS[@]}" \
      --datacenter "$DATACENTER" \
      --template "$WINDOWS_TEMPLATE" \
      --targethost "$TARGETHOST" \
      --folder "$FOLDER" \
      --pool "$POOL" \
      --connection-protocol winrm \
      --image-os-type windows \
      --connection-user "$WINDOWS_CONNECTION_USER" \
      --connection-password "$WINDOWS_CONNECTION_PASSWORD" \
      --winrm-no-verify-cert \
      --bootstrap-version "$ver" \
      -N "$vm_name" \
      -y
  if should_run "TC07.${ver}"; then CREATED_VMS+=("$vm_name"); fi

  run_test "TC08.${ver}" "vm show: Windows/Chef ${ver} VM ($vm_name)" "$SHOW_TIMEOUT" -- \
    "${KNIFE_CMD[@]}" vcenter vm show "$vm_name" "${VCENTER_COMMON_OPTS[@]}"
done

# --- TC09: confirm all cloned VMs are visible --------------------------------
run_test TC09 "vcenter vm list (post-clone, all VMs should be present)" "$LIST_TIMEOUT" -- \
  "${KNIFE_CMD[@]}" vcenter vm list "${VCENTER_COMMON_OPTS[@]}"

# --- TC10/TC11: vm create ------------------------------------------------------
# NOTE (known plugin limitation - see test/e2e/README.md "Known limitations"):
# `knife vcenter vm create` does not accept a template/image and always
# creates a blank VM with guest_OS "OTHER" - there is no installed OS to boot,
# get an IP, or accept SSH/WinRM connections. The post-create bootstrap phase
# is therefore EXPECTED to fail or time out; these two tests validate the
# vSphere placement/create API call and that the VM object itself gets
# created, not a working OS provisioning path. They use a shorter timeout
# accordingly. Both scenarios are only run if DATASTORE is configured, since
# `vm create` requires --datastore and this repo has no `datastore list`
# command to discover it automatically.
if [ -n "$DATASTORE" ]; then
  vm_name="${VM_PREFIX}-create-lin"
  run_test TC10 "vm create: blank VM shell (Linux-flavored name; no OS/template support in 'vm create' - see README)" "$CREATE_TIMEOUT" -- \
    "${KNIFE_CMD[@]}" vcenter vm create "$vm_name" \
      "${VCENTER_COMMON_OPTS[@]}" \
      --targethost "$TARGETHOST" \
      --folder "$FOLDER" \
      --datastore "$DATASTORE" \
      --resource_pool "$POOL" \
      --connection-protocol ssh \
      --image-os-type linux \
      --connection-user "$LINUX_CONNECTION_USER" \
      --connection-password "$LINUX_CONNECTION_PASSWORD" \
      --ssh-verify-host-key never \
      -y
  if should_run "TC10"; then CREATED_VMS+=("$vm_name"); fi

  vm_name="${VM_PREFIX}-create-win"
  run_test TC11 "vm create: blank VM shell (Windows-flavored name; no OS/template support in 'vm create' - see README)" "$CREATE_TIMEOUT" -- \
    "${KNIFE_CMD[@]}" vcenter vm create "$vm_name" \
      "${VCENTER_COMMON_OPTS[@]}" \
      --targethost "$TARGETHOST" \
      --folder "$FOLDER" \
      --datastore "$DATASTORE" \
      --resource_pool "$POOL" \
      --connection-protocol winrm \
      --image-os-type windows \
      --connection-user "$WINDOWS_CONNECTION_USER" \
      --connection-password "$WINDOWS_CONNECTION_PASSWORD" \
      --winrm-no-verify-cert \
      -y
  if should_run "TC11"; then CREATED_VMS+=("$vm_name"); fi
else
  echo "[TC10/TC11] SKIPPED: DATASTORE is not set - 'vm create' requires --datastore. Set the DATASTORE env var to enable these tests."
  echo "TC10,\"vm create: Linux\",SKIPPED,0," >> "$SUMMARY_CSV"
  echo "TC11,\"vm create: Windows\",SKIPPED,0," >> "$SUMMARY_CSV"
  SKIP_COUNT=$((SKIP_COUNT + 2))
fi

# --- TC12.*: cleanup - delete every VM this run created ----------------------
if [ "$SKIP_CLEANUP" = "true" ]; then
  if [ "${#CREATED_VMS[@]}" -gt 0 ]; then
    echo "Skipping cleanup (--skip-cleanup given). The following VMs were left behind and must be deleted manually:"
    printf '  - %s\n' "${CREATED_VMS[@]}"
  fi
else
  i=0
  for vm_name in "${CREATED_VMS[@]:-}"; do
    [ -z "$vm_name" ] && continue
    i=$((i + 1))
    run_test "TC12.${i}" "vm delete: cleanup ${vm_name}" "$DELETE_TIMEOUT" -- \
      "${KNIFE_CMD[@]}" vcenter vm delete "$vm_name" "${VCENTER_COMMON_OPTS[@]}" --purge -y
  done

  run_test TC13 "vcenter vm list (post-cleanup, this run's VMs should be gone)" "$LIST_TIMEOUT" -- \
    "${KNIFE_CMD[@]}" vcenter vm list "${VCENTER_COMMON_OPTS[@]}"
fi

# ----------------------------------------------------------------------------
# Final summary
# ----------------------------------------------------------------------------
{
  echo "## Summary"
  echo
  echo "- PASS: ${PASS_COUNT}"
  echo "- FAIL: ${FAIL_COUNT}"
  echo "- TIMEOUT: ${TIMEOUT_COUNT}"
  echo "- SKIPPED: ${SKIP_COUNT}"
  echo "- Finished: $(date -u +%FT%TZ)"
} >> "$REPORT_MD"

echo "###############################################################################"
echo "SUITE COMPLETE"
echo "  PASS: $PASS_COUNT   FAIL: $FAIL_COUNT   TIMEOUT: $TIMEOUT_COUNT   SKIPPED: $SKIP_COUNT"
echo "  Summary CSV : $SUMMARY_CSV"
echo "  Full report : $REPORT_MD"
echo "  Per-test logs: $LOG_DIR/TCxx.log"
echo "###############################################################################"

if [ "$FAIL_COUNT" -gt 0 ] || [ "$TIMEOUT_COUNT" -gt 0 ]; then
  exit 1
fi
exit 0
