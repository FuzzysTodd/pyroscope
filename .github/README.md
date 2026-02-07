# GitHub Configuration

This directory contains GitHub-specific configuration files and scripts for the Pyroscope repository.

## Contents

### Workflows (.github/workflows/)

All GitHub Actions workflows are stored in the `workflows/` subdirectory. Key workflows include:

- **ci.yml**: Main continuous integration workflow with build, test, and lint jobs
- **frontend.yml**: Frontend-specific testing and building
- **release.yml**: Release automation
- **helm-ci.yml**: Helm chart validation
- **test-examples.yml**: Example application testing

See [Workflow Troubleshooting Guide](docs/WORKFLOW_TROUBLESHOOTING.md) for detailed information.

### Scripts (.github/scripts/)

Utility scripts for workflow operations:

- **workflow-health-check.sh**: Diagnostic script to check workflow environment and dependencies

### Documentation (.github/docs/)

- **WORKFLOW_TROUBLESHOOTING.md**: Comprehensive guide for diagnosing and fixing workflow issues

### MCP Server Configuration

- **mcp-server-config.json**: Model Context Protocol server configuration for AI-assisted development

## Quick Start

### Running Health Check

To diagnose workflow issues, run:

```bash
.github/scripts/workflow-health-check.sh
```

This will check:
- GitHub Actions environment
- Required tools (Go, Node, Docker, etc.)
- Version compatibility
- Network connectivity
- Repository structure

### Understanding Workflow Failures

1. **Check the workflow run logs** in the GitHub Actions UI
2. **Run the health check script** to identify environment issues
3. **Review the troubleshooting guide** at `.github/docs/WORKFLOW_TROUBLESHOOTING.md`
4. **Check for conditional job dependencies** that may be skipped

### Common Issues

#### Issue #100009: Workflow Startup Failures

Workflows may fail to start due to:
- Missing vault secrets (required for Grafana organization workflows)
- Custom runner unavailability (in forked repositories)
- Conditional job dependencies (jobs depending on skipped jobs)
- GitHub App token requirements

See the [troubleshooting guide](docs/WORKFLOW_TROUBLESHOOTING.md#common-startup-issues) for solutions.

## MCP Server Setup

The Model Context Protocol (MCP) enables AI assistants to interact with the Pyroscope codebase.

### Setup Instructions

1. Install an MCP-compatible client (Claude Desktop, Cline VSCode extension, etc.)
2. Copy the MCP configuration:
   ```bash
   cp .github/mcp-server-config.json ~/.config/mcp/pyroscope-servers.json
   ```
3. Update the configuration with your environment settings
4. Restart your MCP client

See the [troubleshooting guide](docs/WORKFLOW_TROUBLESHOOTING.md#mcp-server-configuration) for detailed setup instructions.

## Environment Requirements

### Required Tools

| Tool | Version | Purpose |
|------|---------|---------|
| Go | 1.24.6+ (toolchain 1.24.9) | Backend compilation |
| Node.js | 20+ | Frontend build |
| Yarn | Latest | Package management |
| Docker | Latest | Container builds |
| Git | Latest | Version control |

### For Contributors

When contributing to this repository:

1. **Fork workflows** may have limited functionality due to missing secrets
2. **Essential checks** (tests, linting) work in all repositories
3. **Deployment jobs** only work in the main Grafana repository
4. **Run tests locally** before pushing: `make test && make lint`

## Additional Resources

- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [Pyroscope Documentation](https://grafana.com/docs/pyroscope/)
- [Model Context Protocol](https://modelcontextprotocol.io/)

## Getting Help

If you encounter workflow issues:

1. Run `.github/scripts/workflow-health-check.sh`
2. Check `.github/docs/WORKFLOW_TROUBLESHOOTING.md`
3. Enable debug logging (set `ACTIONS_STEP_DEBUG` secret)
4. Open an issue with health check output and error logs

---

**Last Updated:** 2026-02-07  
**Maintainers:** Pyroscope team
