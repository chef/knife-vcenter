# GitHub Copilot Instructions — knife-vcenter

> **Audience:** GitHub Copilot CLI and Copilot coding agents working in this repository.
> Follow every section of these instructions precisely. When in doubt, ask the user for clarification before proceeding.

---

## Table of Contents

1. [Project Overview](#1-project-overview)
2. [Repository Structure](#2-repository-structure)
3. [Technology Stack](#3-technology-stack)
4. [File Modification Guidelines](#4-file-modification-guidelines)
5. [Development Workflow — Prompt-Based Protocol](#5-development-workflow--prompt-based-protocol)
6. [Jira Integration](#6-jira-integration)
7. [Phase 1: Initial Setup & Analysis](#7-phase-1-initial-setup--analysis)
8. [Phase 2: Implementation](#8-phase-2-implementation)
9. [Phase 3: Testing (CRITICAL)](#9-phase-3-testing-critical)
10. [Phase 4: Pull Request Creation](#10-phase-4-pull-request-creation)
11. [DCO Compliance](#11-dco-compliance)
12. [Build System — Rake](#12-build-system--rake)
13. [Expeditor CI/CD Integration](#13-expeditor-cicd-integration)
14. [GitHub Actions & SonarQube](#14-github-actions--sonarqube)
15. [Label Management System](#15-label-management-system)
16. [Code Style & Quality Standards](#16-code-style--quality-standards)
17. [Ruby-Specific Guidelines](#17-ruby-specific-guidelines)
18. [Security & Compliance](#18-security--compliance)
19. [Code Ownership & Review Process](#19-code-ownership--review-process)
20. [Local Development Setup](#20-local-development-setup)
21. [Troubleshooting](#21-troubleshooting)
22. [Example Workflow Execution](#22-example-workflow-execution)

---

## 1. Project Overview

**knife-vcenter** is a [Chef Knife](https://docs.chef.io/workstation/knife/) plugin that enables provisioning, management, and lifecycle operations of virtual machines on **VMware vCenter** directly from the command line. It is part of the Chef ecosystem and bridges Chef's `knife-cloud` framework with VMware's vSphere Automation SDK and RbVmomi.

| Property | Value |
|---|---|
| Gem name | `knife-vcenter` |
| Current version | `5.0.7` |
| Language | Ruby >= 3.1 |
| License | Apache 2.0 |
| GitHub repo | [chef/knife-vcenter](https://github.com/chef/knife-vcenter) |
| Published to | [RubyGems.org](https://rubygems.org/gems/knife-vcenter) |
| Slack notifications | `#sustaining-notify` |

**Knife commands provided by this plugin:**

| Command | Purpose |
|---|---|
| `knife vcenter vm list` | List all VMs in vCenter |
| `knife vcenter vm create` | Create a new VM |
| `knife vcenter vm clone` | Clone a VM from a template |
| `knife vcenter vm delete` | Delete a VM |
| `knife vcenter vm show` | Show details of a VM |
| `knife vcenter cluster list` | List all clusters |
| `knife vcenter datacenter list` | List all datacenters |
| `knife vcenter host list` | List all hosts |

---

## 2. Repository Structure

```
knife-vcenter/
├── .expeditor/                         # Chef Expeditor CI/CD automation
│   ├── config.yml                      # Expeditor pipeline configuration
│   ├── verify.pipeline.yml             # Buildkite test pipeline (Ruby 3.1/3.4, Linux/Windows)
│   ├── run_linux_tests.sh              # Linux bundle + rake runner script
│   └── update_version.sh              # Version update hook (post-merge)
│
├── .github/                            # GitHub-specific configuration
│   ├── CODEOWNERS                      # Code review ownership assignments
│   ├── copilot-instructions.md         # This file — Copilot guidelines
│   ├── dependabot.yml                  # Automated Bundler dependency updates (daily)
│   ├── ISSUE_TEMPLATE/                 # GitHub issue templates
│   └── workflows/
│       └── build.yml                   # GitHub Actions — SonarQube static analysis
│
├── lib/
│   ├── chef/knife/
│   │   ├── cloud/
│   │   │   ├── vcenter_service.rb      # Core VMware API service (vSphere REST + RbVmomi)
│   │   │   ├── vcenter_service_helpers.rb  # Mixin: service factory, SSL, validation
│   │   │   └── vcenter_service_options.rb  # Mixin: CLI option definitions
│   │   ├── vcenter_cluster_list.rb     # `knife vcenter cluster list`
│   │   ├── vcenter_datacenter_list.rb  # `knife vcenter datacenter list`
│   │   ├── vcenter_host_list.rb        # `knife vcenter host list`
│   │   ├── vcenter_vm_clone.rb         # `knife vcenter vm clone`
│   │   ├── vcenter_vm_create.rb        # `knife vcenter vm create`
│   │   ├── vcenter_vm_delete.rb        # `knife vcenter vm delete`
│   │   ├── vcenter_vm_list.rb          # `knife vcenter vm list`
│   │   └── vcenter_vm_show.rb          # `knife vcenter vm show`
│   ├── knife-vcenter/
│   │   └── version.rb                  # ⛔ AUTO-MANAGED — never edit manually
│   └── support/
│       └── clone_vm.rb                 # RbVmomi VM clone helper (low-level vSphere)
│
├── spec/
│   ├── spec_helper.rb                  # RSpec configuration and global setup
│   ├── support/
│   │   ├── shared_examples_for_command.rb              # Shared: command lifecycle
│   │   ├── shared_examples_for_command_bootstrap.rb    # Shared: bootstrap command
│   │   ├── shared_examples_for_servercreatecommand.rb  # Shared: server create
│   │   ├── shared_examples_for_serverdeletecommand.rb  # Shared: server delete
│   │   └── shared_examples_for_service.rb              # Shared: service layer
│   └── unit/
│       └── vcenter_vm_list_spec.rb     # Unit tests for VcenterVmList
│
├── CHANGELOG.md                        # ⛔ AUTO-MANAGED by Expeditor — never edit manually
├── VERSION                             # ⛔ AUTO-MANAGED by Expeditor — never edit manually
├── Gemfile                             # Gem dependency groups (test, docs, debug)
├── Gemfile.lock                        # Locked dependency versions
├── Rakefile                            # Build tasks: spec, style, docs
├── knife-vcenter.gemspec              # Gem specification and runtime dependencies
├── sonar-project.properties           # SonarQube project key config
├── LICENSE                            # Apache 2.0
├── README.md                          # User-facing documentation
├── CONTRIBUTING.md                    # Points to chef/chef contributing guide
├── CODE_OF_CONDUCT.md                 # Community standards
└── SECURITY.md                        # Security policy
```

---

## 3. Technology Stack

| Category | Technology | Details |
|---|---|---|
| Language | Ruby | >= 3.1 required; tested on 3.1 and 3.4 |
| Plugin framework | knife-cloud | >= 4.0 — base classes for knife plugins |
| Chef integration | chef gem | >= 18.0 |
| VMware REST API | vsphere-automation-sdk | ~> 0.4 (vSphere Automation REST API) |
| VMware low-level | rbvmomi | >= 1.11, < 4.0 (SOAP-based vSphere API, used for cloning) |
| Testing | RSpec | ~> 3.7 |
| Linting | Chefstyle | ~> 1.0 (RuboCop-based, Chef-specific rules) |
| Style addon | rubocop-rspec | ~> 2.0 |
| Build tool | Rake | >= 10.0 |
| Documentation | YARD | API documentation generator |
| CI/CD | Expeditor | Chef's internal pipeline automation (Buildkite-based) |
| Static analysis | SonarQube | Via GitHub Actions build.yml |
| Dependency updates | Dependabot | Daily Bundler updates |

---

## 4. File Modification Guidelines

### ✅ Safe to Modify

| File/Directory | Notes |
|---|---|
| `lib/chef/knife/*.rb` | All knife command implementations |
| `lib/chef/knife/cloud/*.rb` | Service, helpers, options modules |
| `lib/support/clone_vm.rb` | RbVmomi clone support |
| `spec/**/*_spec.rb` | Unit test files |
| `spec/support/*.rb` | Shared test examples |
| `spec/spec_helper.rb` | RSpec configuration |
| `README.md` | User-facing documentation |
| `Gemfile` | Dependency group additions (not gemspec deps) |
| `knife-vcenter.gemspec` | Gem metadata and runtime dependency versions |
| `Rakefile` | Build task additions |

### ⛔ Never Modify Manually

| File | Reason |
|---|---|
| `VERSION` | Auto-managed by Expeditor `built_in:bump_version` |
| `lib/knife-vcenter/version.rb` | Auto-updated by `.expeditor/update_version.sh` |
| `CHANGELOG.md` | Auto-managed by Expeditor `built_in:update_changelog` |
| `Gemfile.lock` | Updated by Bundler — run `bundle update` to refresh |
| `.github/workflows/build.yml` | Managed by infrastructure team — contact @chef/build-engineering-systems-team |
| `.expeditor/config.yml` | Managed by @chef/build-engineering-systems-team |
| `.expeditor/verify.pipeline.yml` | Managed by @chef/build-engineering-systems-team |
| `sonar-project.properties` | Managed by infrastructure team |

### ⚠️ Restricted — Coordinate with Teams

| File/Directory | Owner |
|---|---|
| `.expeditor/` | @chef/build-engineering-systems-team (review required) |
| `*.md` files | @chef/docs-team (review required) |
| All other files | @chef/chef-workstation-owners / @chef/chef-workstation-approvers (review required) |

---

## 5. Development Workflow — Prompt-Based Protocol

**All work MUST follow a prompt-based, approval-gated workflow.** After every major phase:

1. ✅ **Summarize** what was completed
2. 📋 **State** what the next step will be
3. ❓ **Ask**: _"Do you want me to continue with the next step?"_
4. 📌 **List** remaining steps
5. ⏸️ **Wait** for explicit user approval before proceeding

**Never skip ahead.** Each phase requires user confirmation before starting the next.

---

## 6. Jira Integration

This project uses the **`mcp-atlassian`** MCP server (configured as `JiraMCP`) to interact with Jira at `https://progresssoftware.atlassian.net`.

### When a Jira ID is Provided

When the user supplies a Jira ticket ID (e.g., `CHEF-32138`), always:

1. Fetch the ticket using the JiraMCP tool
2. Read the full issue: summary, description, acceptance criteria, story points, labels, linked issues
3. Identify the issue type (Bug, Story, Task, Sub-task)
4. Extract implementation requirements from the description
5. Confirm your understanding with the user before writing any code

**Example prompt to user after fetching Jira ticket:**

```
I've read CHEF-32138. Here's my understanding:
- **Summary**: [ticket summary]
- **Type**: [Bug/Story/Task]
- **Acceptance Criteria**: [list from ticket]
- **Implementation Plan**: [what I propose to do]

Does this match your expectations? Should I proceed to Phase 1?
```

---

## 7. Phase 1: Initial Setup & Analysis

**Goal:** Understand the scope of work before writing any code.

### Steps

1. **Fetch Jira ticket** (if ID provided) — read full description and acceptance criteria
2. **Analyze affected files** — identify which `lib/` files need changes
3. **Check existing tests** — review `spec/unit/` and `spec/support/` for coverage patterns
4. **Review shared examples** — understand which shared examples apply
5. **Plan implementation** — list exact files to create/modify
6. **Plan test coverage** — list exact spec files to create/modify

### Phase 1 Completion Summary Template

```
✅ Phase 1 Complete — Analysis Summary

**Jira Ticket**: [ID] — [Summary]
**Files to modify**:
  - lib/chef/knife/[file].rb
  - lib/chef/knife/cloud/[file].rb

**Tests to create/update**:
  - spec/unit/[file]_spec.rb

**Implementation approach**: [brief description]

**Next step**: Phase 2 — Implementation
Do you want me to proceed with implementation?
```

---

## 8. Phase 2: Implementation

**Goal:** Write clean, well-structured Ruby code following project conventions.

### Implementation Rules

- All Ruby files **MUST** start with `# frozen_string_literal: true`
- All Ruby files **MUST** include the Apache 2.0 license header:

```ruby
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
```

- New knife commands **MUST** include `VcenterServiceOptions` and implement `deps` for lazy loading
- New service methods in `VcenterService` **MUST** use `VSphereAutomation::VCenter::*` APIs
- Error handling **MUST** use `raise format("message: %s", value)` pattern (not string interpolation in raise)
- All public methods **MUST** have YARD-style doc comments:

```ruby
# Brief description of what this method does
#
# @param [Type] param_name Description of the parameter
# @return [Type] Description of the return value
def my_method(param_name)
```

### Phase 2 Completion Summary Template

```
✅ Phase 2 Complete — Implementation Summary

**Files modified**:
  - lib/chef/knife/[file].rb — [what changed]
  - lib/chef/knife/cloud/vcenter_service.rb — [what changed]

**Key changes**:
  - [change 1]
  - [change 2]

**Next step**: Phase 3 — Testing (>80% coverage required)
Do you want me to proceed with test creation?
```

---

## 9. Phase 3: Testing (CRITICAL)

> ⚠️ **CRITICAL HARD REQUIREMENT: >80% test coverage is non-negotiable.**
> All implementations MUST be accompanied by comprehensive RSpec unit tests.
> PRs without adequate test coverage will be rejected.

### Testing Framework

| Tool | Version | Purpose |
|---|---|---|
| RSpec | ~> 3.7 | Unit testing framework |
| Chefstyle | ~> 1.0 | Linting (must pass with no offenses) |
| rubocop-rspec | ~> 2.0 | RSpec-specific style rules |

### Test File Naming & Location

```
lib/chef/knife/vcenter_vm_list.rb
  → spec/unit/vcenter_vm_list_spec.rb

lib/chef/knife/cloud/vcenter_service.rb
  → spec/unit/vcenter_service_spec.rb  (create if missing)

lib/support/clone_vm.rb
  → spec/unit/clone_vm_spec.rb  (create if missing)
```

### Required Test Coverage

Every implementation MUST test:

- ✅ **Happy path** — normal successful execution
- ✅ **Error conditions** — API failures, missing resources, nil values
- ✅ **Edge cases** — empty arrays, nil options, boundary values
- ✅ **Input validation** — missing required config values
- ✅ **All branches** — every `if/when/case` branch must be covered
- ✅ **Mock all external dependencies** — VMware APIs, network calls, filesystem

### RSpec Test Structure Pattern

```ruby
# frozen_string_literal: true
#
# Author:: Chef Partner Engineering (<partnereng@chef.io>)
# Copyright:: Copyright (c) Chef Software Inc.
# License:: Apache License, Version 2.0
# [... full Apache 2.0 header ...]

require "spec_helper"
require "chef/knife/vcenter_vm_example"
require "support/shared_examples_for_command"

describe Chef::Knife::Cloud::VcenterVmExample do
  # Always include the shared command lifecycle example
  it_behaves_like Chef::Knife::Cloud::Command, Chef::Knife::Cloud::VcenterVmExample.new

  subject { described_class.new }

  # Mock vCenter service to avoid real API calls
  let(:service) { instance_double(Chef::Knife::Cloud::VcenterService) }

  before do
    allow(subject).to receive(:create_service_instance).and_return(service)
  end

  describe "#method_name" do
    context "when condition is met (happy path)" do
      it "does the expected thing" do
        # Arrange
        allow(service).to receive(:list_servers).and_return([...])
        # Act & Assert
        expect(subject.method_name).to eq(expected_value)
      end
    end

    context "when an error occurs" do
      it "raises an appropriate error" do
        allow(service).to receive(:list_servers).and_raise(StandardError, "API error")
        expect { subject.method_name }.to raise_error(StandardError, /API error/)
      end
    end

    context "when input is nil" do
      it "handles nil gracefully" do
        expect(subject.method_name(nil)).to be_nil  # or raise, depending on contract
      end
    end

    context "when result is empty" do
      it "returns empty collection" do
        allow(service).to receive(:list_servers).and_return([])
        expect(subject.method_name).to eq([])
      end
    end
  end
end
```

### Shared Examples Usage

Always reuse existing shared examples where applicable:

```ruby
# Test the standard knife command lifecycle (set_default_config, validate!, etc.)
it_behaves_like Chef::Knife::Cloud::Command, Chef::Knife::Cloud::YourCommand.new

# For commands that create servers
it_behaves_like "a server create command"

# For commands that delete servers
it_behaves_like "a server delete command"
```

### Mocking VMware SDK Objects

```ruby
# Mock VSphereAutomation API responses
let(:vm_api) { instance_double(VSphereAutomation::VCenter::VMApi) }
let(:vm_summary) do
  instance_double(
    VSphereAutomation::VCenter::VcenterVMSummary,
    vm: "vm-123",
    name: "test-vm",
    power_state: "POWERED_ON",
    cpu_count: 2,
    memory_size_MiB: 4096
  )
end

before do
  allow(VSphereAutomation::VCenter::VMApi).to receive(:new).and_return(vm_api)
  allow(vm_api).to receive(:list).and_return(double(value: [vm_summary]))
end
```

### Running Tests

```bash
# Run all tests (specs + style) — this is the CI equivalent
bundle exec rake

# Run only RSpec unit tests
bundle exec rake spec

# Run only Chefstyle linting (must have zero offenses)
bundle exec rake style

# Run a specific spec file
bundle exec rspec spec/unit/vcenter_vm_list_spec.rb

# Run with verbose output
bundle exec rspec spec/unit/vcenter_vm_list_spec.rb --format documentation

# Run tests matching a description pattern
bundle exec rspec spec/ -e "format_power_status"

# Run with coverage report (add simplecov if needed)
bundle exec rspec spec/ --format progress
```

> ⚠️ **>80% test coverage is a HARD REQUIREMENT.**
> Run all tests before submitting a PR. Both `bundle exec rake spec` AND `bundle exec rake style` must pass with zero errors or failures.

### Phase 3 Completion Summary Template

```
✅ Phase 3 Complete — Testing Summary

**Test files created/modified**:
  - spec/unit/[file]_spec.rb — [N] examples added

**Test results**:
  - bundle exec rake spec: ✅ [N] examples, 0 failures
  - bundle exec rake style: ✅ 0 offenses

**Coverage**: [N]% (meets >80% requirement ✅)

**Scenarios covered**:
  - ✅ Happy path
  - ✅ Error conditions ([list])
  - ✅ Edge cases ([list])
  - ✅ All branches covered

**Next step**: Phase 4 — Pull Request Creation
Do you want me to proceed with creating the PR?
```

---

## 10. Phase 4: Pull Request Creation

### Branch Naming

Use the Jira ID as the branch name:

```bash
git checkout -b CHEF-32138
```

### Commit with DCO Signoff (REQUIRED)

> ⛔ **ALL commits MUST include `--signoff`. Builds WILL FAIL without it.** See [DCO Compliance](#11-dco-compliance).

```bash
# Stage all changes
git add .

# Commit with DCO signoff and descriptive message
git commit --signoff -m "CHEF-32138: Brief description of the change"

# Push branch to remote
git push origin CHEF-32138
```

### Create PR with GH CLI

```bash
gh pr create \
  --title "CHEF-32138: Brief description of the change" \
  --body "$(cat <<'EOF'
<h2>Summary</h2>
<p>Brief description of what this PR does and why.</p>

<h2>Jira Ticket</h2>
<p><a href="https://progresssoftware.atlassian.net/browse/CHEF-32138">CHEF-32138</a> — [Ticket Summary]</p>

<h2>Changes Made</h2>
<ul>
  <li>Added <code>method_name</code> to <code>VcenterService</code> for [purpose]</li>
  <li>Implemented <code>knife vcenter [command]</code> command</li>
  <li>Added unit tests for all new functionality</li>
</ul>

<h2>Files Modified</h2>
<ul>
  <li><code>lib/chef/knife/vcenter_example.rb</code> — [what changed]</li>
  <li><code>lib/chef/knife/cloud/vcenter_service.rb</code> — [what changed]</li>
  <li><code>spec/unit/vcenter_example_spec.rb</code> — [N] new test examples</li>
</ul>

<h2>Testing</h2>
<ul>
  <li>✅ <code>bundle exec rake spec</code> — [N] examples, 0 failures</li>
  <li>✅ <code>bundle exec rake style</code> — 0 offenses</li>
  <li>✅ Coverage: [N]% (exceeds 80% requirement)</li>
</ul>

<h2>Test Scenarios Covered</h2>
<ul>
  <li>Happy path: [description]</li>
  <li>Error handling: [description]</li>
  <li>Edge cases: [description]</li>
</ul>
EOF
)" \
  --label "Type: Enhancement" \
  --label "Aspect: Testing"
```

### Label Selection for PRs

See [Label Management System](#15-label-management-system) for the complete decision matrix.

### Phase 4 Completion Summary Template

```
✅ Phase 4 Complete — Pull Request Created

**Branch**: CHEF-32138
**PR URL**: https://github.com/chef/knife-vcenter/pull/[N]
**Title**: "CHEF-32138: [description]"
**Labels applied**: [list]

**All checks**:
  - ✅ DCO signoff on all commits
  - ✅ Tests passing (>80% coverage)
  - ✅ Chefstyle: 0 offenses
  - ✅ PR description in HTML format
  - ✅ Jira ticket linked

🎉 Task complete!
```

---

## 11. DCO Compliance

> ⛔ **CRITICAL: Every single commit MUST be signed off. CI pipelines will fail without it.**

The Developer Certificate of Origin (DCO) certifies that you wrote the code and have the right to submit it.

### Signing Off Commits

```bash
# Standard commit with signoff
git commit --signoff -m "CHEF-32138: Add feature X"

# Short form equivalent
git commit -s -m "CHEF-32138: Add feature X"
```

This adds a `Signed-off-by: Your Name <your@email.com>` trailer to every commit.

### Fix Commits Without Signoff

```bash
# Amend the most recent commit to add signoff
git commit --amend --signoff --no-edit

# Force push (only on feature branches, never main)
git push origin CHEF-32138 --force-with-lease
```

### Fix Multiple Commits Without Signoff

```bash
# Interactive rebase to fix multiple commits
git rebase --signoff HEAD~N  # Replace N with number of commits

# Or exec across all commits
git rebase HEAD~N --exec 'git commit --amend --no-edit --signoff'
```

### Verify Signoff

```bash
git log --oneline -5
# Each commit should show: CHEF-32138: description
# git show HEAD should contain: Signed-off-by: ...
```

---

## 12. Build System — Rake

The default Rake task runs **both specs and style checks** — this is what CI runs.

### Available Rake Tasks

| Command | Description |
|---|---|
| `bundle exec rake` | **Default**: runs `spec` + `style` (equivalent to CI) |
| `bundle exec rake spec` | Run all RSpec unit tests |
| `bundle exec rake style` | Run Chefstyle (RuboCop) linting — must have 0 offenses |
| `bundle exec rake docs` | Generate YARD documentation |
| `bundle exec rake build` | Build the gem (from Bundler gem tasks) |
| `bundle exec rake release` | Release the gem (Expeditor handles this automatically) |

### Running in CI Mode (Linux equivalent)

```bash
# Install dependencies (mirrors .expeditor/run_linux_tests.sh)
bundle config --local path vendor/bundle
bundle install --jobs=7 --retry=3

# Run full test suite
bundle exec rake
```

### Dependency Installation

```bash
# Install all gem groups
bundle install

# Install without development tools (mirrors Windows CI)
bundle config set --local without docs debug
bundle install --jobs=7 --retry=3
```

---

## 13. Expeditor CI/CD Integration

[Expeditor](https://expeditor.chef.io) is Chef's internal pipeline automation tool that runs on Buildkite. It triggers on PR merges and manages the release process.

### Verify Pipeline

The verify pipeline (`.expeditor/verify.pipeline.yml`) runs on every PR with:

| Step | Platform | Ruby Version |
|---|---|---|
| `run-lint-and-specs-ruby-3.1` | Linux (Docker: ruby:3.1-buster) | 3.1 |
| `run-lint-and-specs-ruby-3.4` | Linux (Docker: ruby:3.4-buster) | 3.4 |
| `run-specs-windows` | Windows (rubydistros/windows-2019:3.1) | 3.1 |
| `run-specs-windows-3.4` | Windows (rubydistros/windows-2019:3.4) | 3.4 |

All steps run `bundle exec rake` (spec + style).

### Post-Merge Automation

When a PR merges to the release branch, Expeditor automatically:

1. **Bumps the version** (`built_in:bump_version`) → updates `VERSION` and `lib/knife-vcenter/version.rb`
2. **Updates CHANGELOG** (`built_in:update_changelog`) → adds PR title to `CHANGELOG.md`
3. **Builds the gem** (`built_in:build_gem`) → creates `.gem` artifact
4. **On promotion**: publishes to RubyGems (`built_in:publish_rubygems`)

### Expeditor Skip Labels

Use these labels on PRs to control which Expeditor actions run:

| Label | Effect | When to Use |
|---|---|---|
| `Expeditor: Skip All` | Skips ALL merge actions | Infrastructure/config-only changes with no release needed |
| `Expeditor: Skip Version Bump` | Skips `built_in:bump_version` | Documentation-only changes, typo fixes |
| `Expeditor: Skip Changelog` | Skips `built_in:update_changelog` | Internal changes not worth a changelog entry |
| `Expeditor: Skip Habitat` | Skips Habitat package build | Changes not affecting Habitat packaging |
| `Expeditor: Skip Omnibus` | Skips Omnibus build trigger | Changes not affecting Omnibus packaging |
| `Expeditor: Bump Version Minor` | Bumps minor version (X.Y+1.0) | New features, non-breaking enhancements |
| `Expeditor: Bump Version Major` | Bumps major version (X+1.0.0) | Breaking changes, major API changes |

**Default behavior** (no skip labels): patch version bump + changelog update + gem build.

### Expeditor Skip Label Decision Matrix

```
Change type                          → Recommended labels
─────────────────────────────────────────────────────────
Documentation only (README, *.md)   → Expeditor: Skip Version Bump, Expeditor: Skip Changelog
                                       (or Expeditor: Skip All if purely cosmetic)

Bug fix                              → (no skip labels) — patch bump, changelog entry

New feature / enhancement           → Expeditor: Bump Version Minor

Breaking change / major API change  → Expeditor: Bump Version Major

Test-only changes                   → Expeditor: Skip Version Bump (tests don't warrant a release)
                                       (keep changelog entry)

CI/build config only                → Expeditor: Skip All

Dependency update (Dependabot PR)   → (no skip labels usually — let Dependabot handle)

Chore / tech debt (no user impact)  → Expeditor: Skip Version Bump, Expeditor: Skip Changelog
```

### Slack Notifications

Build failures are posted to the `#sustaining-notify` Slack channel.

---

## 14. GitHub Actions & SonarQube

The `.github/workflows/build.yml` workflow runs on:
- Push to `main`, `develop`, or `release/**` branches
- Pull request opened, synchronized, or reopened

It performs **SonarQube static analysis** using secrets `SONAR_TOKEN` and `SONAR_HOST_URL`. The project key is `chef_knife-vcenter_AYckW3CSJ4YHsO5MtJTz` (see `sonar-project.properties`).

**Note:** Do not modify `build.yml` without consulting @chef/build-engineering-systems-team.

---

## 15. Label Management System

### Type Labels (What kind of change)

| Label | When to Use |
|---|---|
| `Type: Bug` | Fixes something that doesn't work as expected |
| `Type: Enhancement` | Adds new functionality |
| `Type: Regression` | Fixes something that used to work |
| `Type: Breaking Change` | Changes existing behavior in a user-visible way |
| `Type: Chore` | Non-critical maintenance (dependency updates, minor refactors) |
| `Type: Deprecation` | Marks features for removal |
| `Type: Tech Debt` | Refactoring without behavior change |
| `Type: Design Proposal` | Community discussion of a proposed approach |

### Aspect Labels (What area is affected)

| Label | When to Use |
|---|---|
| `Aspect: Integration` | Changes to vCenter API interaction |
| `Aspect: Security` | Security-related changes |
| `Aspect: Testing` | Test-only changes or testing improvements |
| `Aspect: Documentation` | Documentation changes |
| `Aspect: Performance` | Performance improvements |
| `Aspect: Portability` | Cross-platform compatibility fixes |
| `Aspect: Packaging` | Gem packaging changes |
| `Aspect: Stability` | Reliability improvements |
| `Aspect: UI` | CLI output/formatting changes |
| `Aspect: UX` | User experience improvements |

### Platform Labels

| Label | When to Use |
|---|---|
| `Platform: VMware` | vCenter/vSphere-specific behavior |
| `Platform: Windows` | Windows-specific fixes |
| `Platform: Linux` | Linux-specific fixes |
| `Platform: macOS` | macOS-specific fixes |

### Priority Labels

| Label | When to Use |
|---|---|
| `Priority: Critical` | Blocks users, security issue, data loss |
| `Priority: Medium` | Significant impact, workaround exists |
| `Priority: Low` | Minor issue, cosmetic |

### Status Labels

| Label | Meaning |
|---|---|
| `Status: Adopted` | PR is being actively worked on |
| `Status: Incomplete` | PR not ready to merge |
| `Status: Waiting on Contributor` | Pending author action |
| `Status: Good First Issue` | Suitable for new contributors |
| `Status: Help Wanted` | Needs community help |
| `Status: Sustaining Backlog` | Queued for sustaining engineering |
| `Status: Untriaged` | Not yet reviewed |

### PR Label Decision Matrix

```
Scenario                              → Type label         + Aspect label(s)
──────────────────────────────────────────────────────────────────────────────
New knife command                     → Type: Enhancement  + Aspect: Integration
Bug fix in API interaction            → Type: Bug          + Aspect: Integration
Fix Windows-specific crash            → Type: Bug          + Platform: Windows
Add/improve unit tests only          → Type: Chore        + Aspect: Testing
Update README                         → Type: Chore        + Aspect: Documentation
Performance improvement               → Type: Enhancement  + Aspect: Performance
Dependency version update             → Type: Chore        + dependencies
Breaking API change                   → Type: Breaking Change + Aspect: Integration
Security vulnerability fix            → Type: Bug          + Aspect: Security + Priority: Critical
Remove deprecated feature             → Type: Deprecation  + Aspect: Integration
```

---

## 16. Code Style & Quality Standards

### Chefstyle (RuboCop)

This project uses **Chefstyle** (`~> 1.0`), a Chef-specific RuboCop configuration. It must produce **zero offenses** before a PR is merged.

```bash
# Check style
bundle exec rake style

# Auto-fix safe offenses
bundle exec rubocop --auto-correct

# Check a specific file
bundle exec rubocop lib/chef/knife/vcenter_vm_list.rb
```

### Key Style Rules

- `# frozen_string_literal: true` at top of every Ruby file
- Use `format("string: %s", value)` instead of `"string: #{value}"` in error messages
- Use `raise` not `fail`
- Two-space indentation
- No trailing whitespace
- `do...end` for multi-line blocks, `{ }` for single-line blocks
- Avoid `unless` with `else` — use `if`
- Use `attr_reader`, `attr_writer`, `attr_accessor` appropriately
- `private` methods at the bottom of the class

### YARD Documentation

All public methods must have YARD doc comments:

```ruby
# Gets the datastore by name from vCenter
#
# @param [String] name The name of the datastore to find
# @return [String] The datastore ID
# @raise [RuntimeError] If the datastore cannot be found
def get_datastore(name)
```

---

## 17. Ruby-Specific Guidelines

### Class Structure Pattern

New knife commands follow this pattern:

```ruby
# frozen_string_literal: true
# [Apache 2.0 header]

require "chef/knife"
require "chef/knife/cloud/server/list_command"   # or appropriate base class
require_relative "cloud/vcenter_service_options"

class Chef
  class Knife
    class Cloud
      class VcenterVmExample < Chef::Knife::Cloud::ServerListCommand
        include VcenterServiceOptions

        banner "knife vcenter vm example"

        # Lazy-load VMware deps — only loaded when command runs
        deps do
          require_relative "cloud/vcenter_service"
          include VcenterServiceHelpers
        end

        # @param [Object] options override options
        def before_exec_command
          @columns_with_info = [
            { label: "ID", key: "vm" },
            # ...
          ]
          @sort_by_field = "name"
        end
      end
    end
  end
end
```

### Error Handling Pattern

```ruby
# Use format() for error messages — not string interpolation
raise format("Unable to find resource: %s", name)

# Use ui.error for user-facing errors before exit
ui.error(format("Missing required parameters: %s", missing.join(", ")))
exit(1)
```

### VMware SDK Usage Patterns

```ruby
# REST API pattern (vsphere-automation-sdk)
vm_api = VSphereAutomation::VCenter::VMApi.new(api_client)
result = vm_api.list.value                          # Returns array
result = vm_api.list({ filter_names: name }).value  # Filtered

# RbVmomi pattern (SOAP API, used in clone_vm.rb)
vim = RbVmomi::VIM.connect(conn_opts)
dc = vim.serviceInstance.find_datacenter(datacenter_name)
vm = dc.find_vm(vm_name)
```

### Bundler & Gem Management

```bash
# Install dependencies
bundle install

# Add a new runtime dependency (edit gemspec, then:)
bundle install

# Update a specific gem
bundle update gem-name

# Check outdated gems
bundle outdated
```

---

## 18. Security & Compliance

### Apache 2.0 License Header

Every Ruby source file MUST include the full Apache 2.0 license header (see [Phase 2: Implementation](#8-phase-2-implementation) for the exact text). This is enforced by Chefstyle.

### SSL Verification

- SSL verification is **enabled by default** — never disable it in code without explicit user opt-in
- The `--vcenter-disable-ssl-verify` flag is provided for development environments only
- Log a warning when SSL is disabled: `Base.log.warn("SSL Verification is turned OFF")`

### Credentials Handling

- **Never hardcode** credentials (usernames, passwords, API tokens) in source files
- Credentials are passed via CLI options (`--vcenter-username`, `--vcenter-password`)
- No credentials should appear in test fixtures — use mocks

### CVE Awareness

- Monitor RubyGems advisories for runtime dependencies: `rbvmomi`, `vsphere-automation-sdk`, `knife-cloud`, `chef`
- Dependabot is configured to open daily PRs for Bundler updates — review and merge promptly
- Security-related PRs should be labeled `Aspect: Security` and `Priority: Critical`

### SonarQube

SonarQube scans run on every PR and push to main/develop/release branches. Address any security hotspots or vulnerabilities flagged before merging.

---

## 19. Code Ownership & Review Process

### CODEOWNERS

```
*                  @chef/chef-workstation-owners @chef/chef-workstation-approvers @chef/chef-workstation-reviewers
.expeditor/        @chef/build-engineering-systems-team
*.md               @chef/docs-team
```

> Note: Last matching pattern takes precedence (as noted in CODEOWNERS).

### Review Requirements

| Change area | Required reviewers |
|---|---|
| `lib/**/*.rb` | @chef/chef-workstation-owners or @chef/chef-workstation-approvers (1 approval) |
| `spec/**/*.rb` | @chef/chef-workstation-owners or @chef/chef-workstation-approvers (1 approval) |
| `.expeditor/**` | @chef/build-engineering-systems-team (required) |
| `*.md`, `README.md` | @chef/docs-team (required) |
| `knife-vcenter.gemspec` | @chef/chef-workstation-owners or @chef/chef-workstation-approvers (1 approval) |
| Security changes | @chef/chef-workstation-owners + Priority: Critical label |

### Review Checklist

Before requesting review, verify:

- [ ] All tests pass: `bundle exec rake`
- [ ] Chefstyle: 0 offenses: `bundle exec rake style`
- [ ] All commits have DCO signoff
- [ ] PR description is HTML-formatted with Jira link
- [ ] Appropriate labels applied
- [ ] Expeditor skip labels applied where appropriate
- [ ] Coverage > 80%

---

## 20. Local Development Setup

### Prerequisites

- Ruby >= 3.1 (use `rbenv` or `rvm` to manage Ruby versions)
- Bundler >= 2.0
- Git
- GH CLI (`gh`) for PR operations

### Setup Steps

```bash
# 1. Clone the repository
git clone https://github.com/chef/knife-vcenter.git
cd knife-vcenter

# 2. Install dependencies
bundle install

# 3. Verify setup — run full test suite
bundle exec rake

# 4. You should see: [N] examples, 0 failures, 0 offenses
```

### Ruby Version Management

```bash
# Check current Ruby version (must be >= 3.1)
ruby --version

# With rbenv
rbenv install 3.4.0
rbenv local 3.4.0

# With rvm
rvm install 3.4.0
rvm use 3.4.0
```

### Environment Variables (for manual testing against real vCenter)

```bash
export VCENTER_HOST="your-vcenter-host.example.com"
export VCENTER_USERNAME="administrator@vsphere.local"
export VCENTER_PASSWORD="your-password"
```

### IDE Configuration

For VS Code, recommended extensions:
- `Shopify.ruby-lsp` — Ruby LSP for code intelligence
- `misogi.ruby-rubocop` — RuboCop integration
- `castwide.solargraph` — Ruby language server

---

## 21. Troubleshooting

### Common Issues

**`bundle install` fails with native extension errors**

```bash
# On macOS, ensure Xcode command line tools are installed
xcode-select --install

# For rbvmomi, you may need
brew install libxml2
```

**`rake style` reports offenses**

```bash
# View detailed offense info
bundle exec rubocop --display-cop-names lib/

# Auto-fix safe offenses
bundle exec rubocop --auto-correct lib/

# If `frozen_string_literal` is missing from new files, add it manually
```

**RSpec tests failing with `LoadError`**

```bash
# Ensure all dependencies are installed
bundle install

# Check if chef/knife is available
bundle exec ruby -e "require 'chef/knife'; puts 'OK'"
```

**`Chef::Config.reset` errors in specs**

Ensure `spec_helper.rb` is required at the top of every spec file:
```ruby
require "spec_helper"
```

**DCO check failing on PR**

```bash
# Fix with amend (single commit)
git commit --amend --signoff --no-edit
git push origin CHEF-XXXXX --force-with-lease

# Fix multiple commits
git rebase HEAD~N --exec 'git commit --amend --no-edit --signoff'
git push origin CHEF-XXXXX --force-with-lease
```

**SSL verification errors in development**

Use `--vcenter-disable-ssl-verify` flag for self-signed certs in dev environments only.

---

## 22. Example Workflow Execution

### Complete Example: Adding a New Knife Command

Here is a full example showing the interaction pattern for adding `knife vcenter vm snapshot list`:

---

**User:** Implement CHEF-99999 — add `knife vcenter vm snapshot list` command

**Copilot (Phase 1):**

> I'll fetch the Jira ticket now...
>
> ✅ Phase 1 Complete — Analysis Summary
>
> **Jira Ticket**: CHEF-99999 — Add `knife vcenter vm snapshot list` command
> **Files to create**:
>   - `lib/chef/knife/vcenter_vm_snapshot_list.rb`
>   - `spec/unit/vcenter_vm_snapshot_list_spec.rb`
>
> **Files to modify**:
>   - `lib/chef/knife/cloud/vcenter_service.rb` — add `list_snapshots(vm_name)` method
>
> **Implementation approach**: Use `VSphereAutomation::VCenter::VmSnapshotApi` to list snapshots for a given VM, following the same pattern as `vcenter_vm_list.rb`.
>
> **Next step**: Phase 2 — Implementation
> Do you want me to proceed with implementation?

---

**User:** Yes, proceed.

**Copilot (Phase 2):**

> [implements files]
>
> ✅ Phase 2 Complete — Implementation Summary
>
> **Files created/modified**: [list]
>
> **Next step**: Phase 3 — Testing (>80% coverage required)
> Do you want me to proceed with test creation?

---

**User:** Yes.

**Copilot (Phase 3):**

> [writes comprehensive RSpec tests]
>
> ✅ Phase 3 Complete — Testing Summary
>
> - `bundle exec rake spec`: ✅ 18 examples, 0 failures
> - `bundle exec rake style`: ✅ 0 offenses
> - Coverage: 94% ✅
>
> **Next step**: Phase 4 — Pull Request Creation
> Do you want me to create the PR?

---

**User:** Yes.

**Copilot (Phase 4):**

> ```bash
> git checkout -b CHEF-99999
> git add .
> git commit --signoff -m "CHEF-99999: Add knife vcenter vm snapshot list command"
> git push origin CHEF-99999
> gh pr create --title "CHEF-99999: Add knife vcenter vm snapshot list command" \
>   --body "[HTML body with Jira link, changes, test results]" \
>   --label "Type: Enhancement" \
>   --label "Aspect: Integration"
> ```
>
> ✅ Phase 4 Complete — PR Created
>
> **PR**: https://github.com/chef/knife-vcenter/pull/NNN
>
> 🎉 Task complete!

---

*These instructions are maintained by @chef/chef-workstation-owners. For questions, reach out in `#sustaining-notify`.*
