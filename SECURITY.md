# AI Agent Security Standard

This document defines mandatory security principles and restrictions for all AI coding assistants operating in this repository. All AI agents must follow these requirements without exception.

**Authority:** Derived from [Zendesk Minimum Baseline Security Standard](https://docs.google.com/document/d/17GZ9TpjKCt6WCdw3yxL44Ra_YscbOBVnVkUVGgx5Hz0/) and internal security policies.

---

## Core Security Mandate

Security is a first-class requirement. Every code suggestion must be evaluated against these guidelines. If a request would result in insecure code:

1. **Stop** and flag the security concern
2. **Explain** why it's problematic
3. **Propose** a secure alternative

AI-generated code requires human review before merging.

---

## Absolute Prohibitions

AI agents must **NEVER** do the following:

### Secrets & Credentials
- Hardcode secrets, credentials, API keys, tokens, or passwords in source code
- Store secrets in version control (`.env` files, `action.yml` with real values)
- Log, print, or expose secret values — including `ZENDESK_AUTH` (which contains email:password)
- Expose credentials in URLs, log messages, or error output

### Security Controls
- Disable or weaken TLS certificate validation in Excon (`ssl_verify_peer: false`)
- Bypass the `Authorization: Basic` header requirement for Zendesk API calls
- Add `ALLOW_ALL` CORS headers or other permissive security bypasses

### Dangerous Code Patterns
- Use string interpolation to construct API paths from user-controlled input without sanitization
- Use `eval()` or `exec()` with content from HTML files or env vars
- Implement custom cryptographic logic (MD5 in this codebase is used only as a stable identifier, not for security)

### Data Exposure
- Log the value of `ZENDESK_AUTH`, `AUTH`, or any credential-containing variable
- Expose raw Zendesk API error bodies to end users in a web context (logging to CI stdout is acceptable)
- Send more than `MAX_BODY_LENGTH` characters of HTML body content to the API

---

## Required Security Patterns

### Credential Handling

```ruby
# Correct: credentials from environment, never logged
AUTH = ENV.fetch("ZENDESK_AUTH")
headers = { "Authorization" => "Basic #{AUTH}" }
```

```ruby
# NEVER: hardcode or log credentials
AUTH = "my@email.com:mypassword"
logger.info("Auth: #{AUTH}")
```

### API Error Logging

```ruby
# Correct: log the API error response body, not internal credential state
rescue Excon::Error::Client => err
  @logger.error(JSON.parse(err.response.body))
  raise
```

```ruby
# NEVER: include auth headers or request body containing credentials in error logs
rescue Excon::Error::Client => err
  @logger.error("Request headers: #{err.request[:headers]}")  # exposes auth
```

### Excon TLS

```ruby
# Correct: default Excon behavior (TLS verification enabled)
@excon = Excon.new(BASE_URL, persistent: true, headers: headers)
```

```ruby
# NEVER: disable certificate validation
@excon = Excon.new(BASE_URL, ssl_verify_peer: false)
```

### Environment Variables

```ruby
# Correct: ENV.fetch raises on missing required vars
TARGET_BASE_URL = ENV.fetch("TARGET_BASE_URL")
```

```ruby
# Avoid: ENV[] returns nil silently, hiding misconfiguration
TARGET_BASE_URL = ENV["TARGET_BASE_URL"]
```

---

## Security Requirements by Domain

### Authentication
- The action uses HTTP Basic authentication for the Zendesk API (`Authorization: Basic <base64>`)
- Credentials must always come from GitHub Actions secrets (never hardcoded)
- The `auth` input to the action must reference a repository or organization secret in workflow YAML

### Data Protection
- `ZENDESK_AUTH` contains plaintext `email:password` — treat as a high-sensitivity secret
- Body content is truncated to `MAX_BODY_LENGTH` before transmission (prevents oversized payloads)
- Content IDs are derived from `MD5(source_id + path)` — this is an identifier, not a security control; do not treat it as tamper-proof

### Communication Security
- All Zendesk API calls use HTTPS (enforced by constructing `BASE_URL` from `https://...`)
- Never add HTTP fallback or downgrade logic
- Never pass `ssl_verify_peer: false` to Excon

### Cryptography
- MD5 is used only to generate stable, deterministic content identifiers — this is acceptable for this non-security use case
- Do not use MD5 for password hashing, integrity verification, or any security-sensitive purpose

### Infrastructure
- The Docker image is built from `ruby:<version>` (see `Dockerfile`) — keep the base image up to date
- Dependabot is used for gem vulnerability scanning (see merged bump PRs)
- `Gemfile.lock` must be committed and kept updated via `bundle update`

---

## When to Stop and Escalate

Stop, explain the concern, and recommend involving Security if a task requires:

- Storing credentials anywhere other than GitHub Actions secrets
- Disabling TLS certificate validation
- Logging or exposing the value of `ZENDESK_AUTH` or similar credentials
- Changing the authentication scheme for the Zendesk API
- Adding new external HTTP calls to services not listed in `ARCHITECTURE.md`
- Accessing or transmitting customer PII from HTML content

---

## Security Testing

When generating features, include:

- Tests for correct handling of missing required environment variables (should raise, not silently fail)
- Tests that verify credentials are not leaked into log output
- Tests for pagination edge cases in `RecordList` (empty results, single page, multiple pages)
- Negative test cases for duplicate content ID detection

---

## References

- [Minimum Baseline Security Standard](https://docs.google.com/document/d/17GZ9TpjKCt6WCdw3yxL44Ra_YscbOBVnVkUVGgx5Hz0/)
- [Zendesk External Content API](https://developer.zendesk.com/api-reference/help_center/federated-search/external_content_records/)
- [Excon gem documentation](https://github.com/excon/excon)

---

**Questions?** Reach out to the Security team or file a ticket via the Security Engagement process.
