# Security Policy

## Supported Versions

| Version | Supported |
|---------|-----------|
| main (latest) | ✅ |
| Development branches | ⚠️ Best-effort |

## Reporting a Vulnerability

If you discover a security vulnerability in this project, please report it responsibly:

1. **Do not** open a public GitHub issue for security vulnerabilities
2. **Email** the maintainers directly or use [GitHub's private vulnerability reporting](https://docs.github.com/en/code-security/security-advisories/guidance-on-reporting-and-writing-information-about-vulnerabilities/privately-reporting-a-security-vulnerability)
3. Include:
   - Description of the vulnerability
   - Steps to reproduce
   - Potential impact
   - Suggested fix (if any)

### Response Timeline

- **Acknowledgment:** Within 48 hours
- **Initial assessment:** Within 1 week
- **Fix or mitigation:** Depends on severity, targeting within 30 days for critical issues

## Security Update Process

1. Vulnerability is reported and triaged
2. Fix is developed on a private branch
3. Fix is reviewed and tested
4. Security advisory is published with the fix
5. Users are notified to update

## Scope

This project handles:
- **API keys** (fal.ai `FAL_KEY`) — see [docs/security/api-key-management.md](docs/security/api-key-management.md)
- **User prompts** passed to AI services
- **Generated media files** (images, videos)

For detailed security practices, see:
- [API Key Management Review](docs/security/api-key-management.md)
- [Secret Handling Review](docs/security/secret-handling.md)
