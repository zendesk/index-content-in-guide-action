# index-content-in-guide-action

A Docker-based GitHub Action written in Ruby that synchronizes local HTML files into the Zendesk Guide Federated Search index using the External Content API. It creates, updates, and deletes search records to keep Guide in sync with the local content source.

## Setup & Commands

```bash
# Install dependencies
bundle install

# Run the action locally (requires .env with all variables)
ruby sync.rb

# Run tests (CI integration test — runs the full action against test/hello.html)
# Triggered automatically on push via .github/workflows/test.yml
```

Local development requires a `.env` file (gitignored) with the required environment variables. See `action.yml` for the full list of inputs mapped to env vars.

## Environment Variables

| Variable | Source Input | Description |
|---|---|---|
| `TARGET_BASE_URL` | `target-base-url` | Base URL prefixed to each HTML file path |
| `EXTERNAL_CONTENT_SOURCE_ID` | `source-id` | Zendesk External Content Source ID |
| `EXTERNAL_CONTENT_TYPE_ID` | `type-id` | Zendesk External Content Type ID |
| `ZENDESK_BASE_URL` | `zendesk-subdomain` | Constructed as `https://<subdomain>.zendesk.com` |
| `ZENDESK_AUTH` | `auth` | Basic auth credentials (`email:password`), Base64-encoded |
| `CONTENT_DIR` | `content-dir` | Directory of HTML files to index (default: `.`) |
| `WORKING_DIR` | `working-dir` | Working directory for relative path resolution (default: `.`) |
| `CONTENT_CSS_SELECTOR` | `content-css-selector` | Nokogiri CSS selector for body text (default: `body`) |

## Code Conventions

- Ruby idioms: `snake_case` methods/variables, `PascalCase` classes, `SCREAMING_SNAKE_CASE` constants
- Use `Struct.new` for simple data classes (`Content`)
- Use `include Enumerable` + `each` for collection wrappers (`RecordList`)
- Environment variables accessed via `ENV.fetch` (raises on missing) or `ENV.fetch(key, default)`
- `excon` gem for HTTP — use keyword arguments (`path:`, `body:`, `expects:`, `idempotent:`)
- `nokogiri` for HTML parsing — use `html.at(selector).text` for body extraction
- All logging through the Ruby `Logger` with `ColoredLoggingFormatter`

## Testing

- No unit test framework in use — the integration test in `.github/workflows/test.yml` runs the full action against `test/hello.html` on every push
- `test/` contains fixture HTML files used by the CI workflow
- When adding test fixtures, place HTML files in `test/`

## Do

- Use `ENV.fetch("VAR")` (not `ENV["VAR"]`) so missing variables raise clearly
- Truncate `body` to `MAX_BODY_LENGTH` (9000) before sending to the API
- Filter existing records by both `source_id` AND `type_id` before comparing (see `RecordList`)
- Detect and raise on duplicate content IDs before syncing
- Use `idempotent: true` on `PUT`/`DELETE` Excon calls for safe retries
- Keep `lib/` classes single-responsibility (API client, collection, value object, parser)
- Use `persistent: true` on the Excon connection for efficiency across multiple API calls

## Don't

- Don't add runtime logic to `sync.rb`; delegate to `lib/` classes
- Don't use `ENV["VAR"]` (returns nil on missing); use `ENV.fetch`
- Don't send body content longer than `MAX_BODY_LENGTH` to the API
- Don't skip the duplicate-ID check before syncing
- Don't modify `Gemfile.lock` manually; run `bundle install` or `bundle update`
- Don't commit `.env` files (already in `.gitignore`)

## Architecture

See `ARCHITECTURE.md` for system architecture, component relationships, and data flow.

## Security

See `SECURITY.md` for mandatory security requirements, credential handling rules, and escalation triggers.

## Safety & Permissions

Allowed without approval:
- Read/list files
- Run `bundle install`
- Run the action locally with test credentials

Ask before:
- Adding or updating gems (`bundle add`, `bundle update`)
- Modifying `action.yml` inputs or the Dockerfile base image
- Changing the Zendesk API endpoint paths or auth scheme
- Modifying `.github/workflows/test.yml`

## PR & Commit Guidelines

- No enforced Jira ticket prefix (see recent merged PRs for examples)
- PR titles use plain English: `Add CODEOWNERS file`, `Bump nokogiri from X to Y`
- Keep PRs focused; one logical change per PR
