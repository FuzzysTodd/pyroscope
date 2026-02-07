# Workflow Troubleshooting Guide

This guide helps diagnose and fix issues with GitHub Actions workflows in the Pyroscope repository.

## Table of Contents

- [Quick Health Check](#quick-health-check)
- [Common Startup Issues](#common-startup-issues)
- [Environment Requirements](#environment-requirements)
- [Network Configuration](#network-configuration)
- [Debugging Failed Workflows](#debugging-failed-workflows)
- [Fork-Specific Issues](#fork-specific-issues)
- [MCP Server Configuration](#mcp-server-configuration)

## Quick Health Check

Run the workflow health check script to diagnose common issues:

```bash
.github/scripts/workflow-health-check.sh
```

This script will check:
- ✓ GitHub Actions environment
- ✓ Required tools (Go, Node, Yarn, Docker, Git)
- ✓ Go version compatibility (1.24.6+ required, 1.24.9 toolchain)
- ✓ Node version compatibility (Node 20+ required)
- ✓ Network connectivity
- ✓ Docker daemon status
- ✓ Repository structure
- ✓ Environment variables
- ✓ Runner compatibility

## Common Startup Issues

### Issue #100009: Workflow Fails to Start

**Symptoms:**
- Workflow shows "action_required" status
- Jobs fail before running any steps
- Missing or skipped job dependencies

**Common Causes:**

1. **Conditional Job Dependencies**
   - Job A depends on Job B, but Job B is skipped due to conditions
   - Example: `deploy-dev` needs `build-push`, but `build-push` only runs on main branch

   **Solution:** Ensure dependent jobs have compatible conditions:
   ```yaml
   build-push:
     if: github.event_name == 'push' && github.repository == 'grafana/pyroscope'
   
   deploy-dev:
     needs: [build-push]
     # IMPORTANT: Must have same or more restrictive condition
     if: github.event_name == 'push' && github.repository == 'grafana/pyroscope' && github.ref == 'refs/heads/main'
   ```

2. **Missing Vault Secrets**
   - Workflows using `grafana/shared-workflows/actions/get-vault-secrets` require organization secrets
   - Forks and non-Grafana repos don't have access

   **Solution:** Add conditional checks:
   ```yaml
   - name: Get secrets
     if: github.repository == 'grafana/pyroscope'
     uses: grafana/shared-workflows/actions/get-vault-secrets@...
   ```

3. **Custom Runner Unavailable**
   - Workflows specify `ubuntu-x64-large`, `ubuntu-x64-small`, etc.
   - These are only available in the Grafana organization

   **Solution:** Use fallback logic (already implemented):
   ```yaml
   runs-on: ${{ github.repository_owner == 'grafana' && 'ubuntu-x64-large' || 'ubuntu-latest' }}
   ```

4. **Missing GitHub App Token**
   - Some workflows require GitHub App credentials
   - Unavailable in forks

   **Solution:** Skip steps that require app tokens in forks:
   ```yaml
   - name: Generate token
     if: github.repository == 'grafana/pyroscope'
     ...
   ```

## Environment Requirements

### Required Tools

| Tool | Version | Purpose |
|------|---------|---------|
| Go | 1.24.6+ (toolchain 1.24.9) | Backend compilation |
| Node.js | 20+ | Frontend build |
| Yarn | Latest | Package management |
| Docker | Latest | Container builds |
| Git | Latest | Version control |

### Linux Dependencies

Standard Ubuntu runners include most dependencies. For custom builds, ensure:

```bash
# Build essentials
sudo apt-get update
sudo apt-get install -y build-essential git curl

# Go (if not using setup-go action)
wget https://go.dev/dl/go1.24.9.linux-amd64.tar.gz
sudo tar -C /usr/local -xzf go1.24.9.linux-amd64.tar.gz

# Node.js (if not using setup-node action)
curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
sudo apt-get install -y nodejs

# Yarn
npm install -g yarn
```

## Network Configuration

### Required Connectivity

Workflows need access to:

| Service | URL | Purpose |
|---------|-----|---------|
| GitHub | github.com | Source code, actions |
| Go Proxy | proxy.golang.org | Go dependencies |
| npm Registry | registry.npmjs.org | Node dependencies |
| Docker Hub | hub.docker.com | Container images |
| Grafana Vault | (internal) | Secrets (Grafana org only) |

### Port Requirements

| Port | Service | Used By |
|------|---------|---------|
| 4040 | Pyroscope Server | Local development |
| 80/443 | HTTP/HTTPS | External dependencies |
| 9090 | Prometheus | Monitoring (if enabled) |

### Firewall Configuration

Ensure outbound HTTPS (443) is allowed for:
- GitHub Actions runner → GitHub API
- GitHub Actions runner → Package registries
- GitHub Actions runner → Container registries

## Debugging Failed Workflows

### Step 1: Check Workflow Status

```bash
# View recent workflow runs
gh run list --limit 10

# Get details of a specific run
gh run view <run-id>

# View logs
gh run view <run-id> --log
```

### Step 2: Enable Debug Logging

Add secrets to your repository:
- `ACTIONS_RUNNER_DEBUG`: true
- `ACTIONS_STEP_DEBUG`: true

This provides verbose logging for all workflow steps.

### Step 3: Check Job Dependencies

Review the workflow graph in GitHub Actions UI to identify:
- Skipped jobs
- Failed job dependencies
- Conditional execution paths

### Step 4: Reproduce Locally

```bash
# Clone the repository
git clone https://github.com/FuzzysTodd/pyroscope.git
cd pyroscope

# Run health check
.github/scripts/workflow-health-check.sh

# Test Go build
make go/test

# Test frontend build
yarn install
yarn build

# Test linting
make lint
```

### Step 5: Check for Tool Version Mismatches

```bash
# Check installed versions
go version          # Should be 1.24.6+
node --version      # Should be v20+
yarn --version      # Should be latest
docker --version    # Should be latest

# Check go.mod requirements
cat go.mod | grep "^go "
```

## Fork-Specific Issues

When running workflows in a forked repository:

### Expected Behavior

| Workflow | Fork Behavior |
|----------|---------------|
| ci.yml | ✓ Runs (most jobs) |
| frontend.yml | ✓ Runs fully |
| helm-ci.yml | ✓ Runs fully |
| test-examples.yml | ✓ Runs fully |
| release.yml | ✗ Skipped (requires secrets) |
| backport.yml | ✗ Skipped (requires GitHub App) |
| deploy-dev | ✗ Skipped (requires vault access) |

### Jobs That May Fail in Forks

1. **build-push** (ci.yml)
   - Requires: Docker Hub credentials
   - Fallback: Use `build-image` job instead

2. **deploy-dev** (ci.yml)
   - Requires: Argo Workflows access
   - Fallback: Skip deployment

3. **backport-pr** (backport.yml)
   - Requires: GitHub App token
   - Fallback: Manual backporting

### Solutions for Fork Contributors

1. **Run tests locally first:**
   ```bash
   make test
   make lint
   ```

2. **Use PR to upstream:**
   - Push to your fork
   - Create PR to grafana/pyroscope
   - Workflows will run with full access in the PR context

3. **Skip failing jobs:**
   - Most essential checks (tests, linting) work in forks
   - Deployment and integration jobs can be ignored

## MCP Server Configuration

Model Context Protocol (MCP) enables AI assistants to interact with the Pyroscope codebase and development environment.

### Setup

1. **Install MCP client** (e.g., Claude Desktop, Cline VSCode extension)

2. **Configure MCP servers:**
   
   Copy the configuration template:
   ```bash
   cp .github/mcp-server-config.json ~/.config/mcp/pyroscope-servers.json
   ```

3. **Update configuration:**
   
   Edit the configuration file to set:
   - `PYROSCOPE_URL`: Your Pyroscope server URL (default: http://localhost:4040)
   - `GITHUB_TOKEN`: Your GitHub personal access token
   - File paths: Update paths to match your setup

4. **Available MCP servers:**

   - **pyroscope-dev**: Interact with Pyroscope server API
   - **github**: GitHub repository operations
   - **filesystem**: File system access for code navigation

### MCP Server Configuration File

Location: `.github/mcp-server-config.json`

```json
{
  "mcpServers": {
    "pyroscope-dev": {
      "command": "node",
      "args": ["/path/to/pyroscope-mcp-server/build/index.js"],
      "env": {
        "PYROSCOPE_URL": "http://localhost:4040",
        "LOG_LEVEL": "info"
      }
    },
    "github": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-github"],
      "env": {
        "GITHUB_PERSONAL_ACCESS_TOKEN": "${GITHUB_TOKEN}"
      }
    },
    "filesystem": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-filesystem", "."]
    }
  }
}
```

### Usage Examples

Once configured, you can:

1. **Query Pyroscope profiles** through your AI assistant
2. **Search code** across the repository
3. **Navigate file structure** efficiently
4. **Get context-aware** coding suggestions

## Additional Resources

- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [Pyroscope Documentation](https://grafana.com/docs/pyroscope/)
- [Model Context Protocol](https://modelcontextprotocol.io/)
- [Go Installation Guide](https://go.dev/doc/install)
- [Node.js Installation Guide](https://nodejs.org/)

## Getting Help

If you encounter issues not covered here:

1. **Check existing issues:** Search GitHub issues for similar problems
2. **Enable debug logging:** Add `ACTIONS_STEP_DEBUG` secret
3. **Run health check:** Use `.github/scripts/workflow-health-check.sh`
4. **Contact maintainers:** Open an issue with:
   - Workflow name and run ID
   - Error messages
   - Health check output
   - Steps to reproduce

---

**Last Updated:** 2026-02-07  
**Related Issues:** #100009
