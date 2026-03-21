# Security Policy

We take security extremely seriously, especially since Me is designed for children.

## Child Safety is Paramount

Me is designed with child safety as the top priority:

- **No internet access**: Programs cannot make network requests
- **No file system access**: Programs cannot read or write files
- **No code execution**: Cannot execute arbitrary system commands
- **Sandboxed environment**: All code runs in a safe, isolated sandbox
- **No data collection**: We never collect any data from users

## Reporting a Vulnerability

### Preferred Method: GitHub Security Advisories

1. Navigate to
   [Report a Vulnerability](https://github.com/hyperpolymath/me-dialect-playground/security/advisories/new)
2. Click **"Report a vulnerability"**
3. Complete the form with as much detail as possible

### Alternative: Email

|           |                         |
| --------- | ----------------------- |
| **Email** | hyperpolymath@proton.me |

> **Important:** Do not report security vulnerabilities through public GitHub issues.

## Scope

### Critical for Child Safety

We treat the following as highest priority:

- **Sandbox escapes**: Any way to break out of the safe environment
- **Network access bypass**: Any way to make network requests
- **File system access**: Any way to read or write files
- **Code injection**: Any way to execute arbitrary code
- **Data leakage**: Any way to collect or transmit user data

### Also Important

- Memory safety issues
- Denial of service vulnerabilities
- Error messages that reveal system information

## Response Timeline

Given the child safety implications:

| Stage                | Timeframe           |
| -------------------- | ------------------- |
| **Initial Response** | 24 hours            |
| **Triage**           | 48 hours            |
| **Resolution**       | As fast as possible |

## Safe Harbor

If you conduct security research in accordance with this policy:

- We will not initiate legal action against you
- We will not report your activity to law enforcement
- We will work with you in good faith to resolve issues

---

_Keeping children safe while they learn to code is our top priority._

<sub>Last updated: 2025</sub>
