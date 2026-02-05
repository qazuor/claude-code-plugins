# Security Policy

## Supported Versions

| Version | Supported |
|---------|-----------|
| 2.0.x   | Yes       |
| 1.0.x   | Yes       |

## Reporting a Vulnerability

If you discover a security vulnerability in this project, please report it responsibly.

### How to Report

1. **Do NOT open a public issue** for security vulnerabilities.
2. Email your report to the repository maintainer via [GitHub private vulnerability reporting](https://github.com/qazuor/claude-code-plugins/security/advisories/new).
3. Include:
   - Description of the vulnerability
   - Steps to reproduce
   - Potential impact
   - Suggested fix (if any)

### What to Expect

- **Acknowledgement** within 48 hours of your report.
- **Status update** within 7 days with an assessment and timeline.
- **Fix release** as soon as a patch is validated.
- **Credit** in the release notes (unless you prefer anonymity).

## Security Practices

This project follows these security practices:

- **No `eval` or dynamic code execution** in any shell script
- **No `sudo` execution** — scripts only suggest it for dependency installation
- **No hardcoded secrets** — all API keys use environment variables with safe defaults (`${VAR:-}`)
- **Secure file permissions** — sensitive files (`.env`) created with mode 600
- **Input validation** — all user inputs and paths validated before use
- **Atomic file operations** — uses `mktemp` for temporary files to prevent race conditions
- **User confirmation** — destructive operations require explicit user consent
- **Safe deletion** — `rm -rf` scoped only to managed directories with existence checks

## Scope

The following are in scope for security reports:

- Shell injection in plugin scripts
- Path traversal vulnerabilities
- Credential exposure in configuration or logs
- Unsafe file permission handling
- Symlink attacks

The following are out of scope:

- Security of third-party MCP servers (report to their maintainers)
- Vulnerabilities in Claude Code itself (report to [Anthropic](https://www.anthropic.com))
- Social engineering attacks
