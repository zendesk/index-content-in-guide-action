# index-content-in-guide-action

Indexes local HTML files in Zendesk Guide's search index.

## Input Parameters

### `content-dir`

Path to directory where HTML files are located.

Required: yes \
Default: `.`

### `target-base-url`

Base URL that should prefix all paths found in `content-dir`. If `working-dir` is provided, the paths will be relative to that dir. So if your HTML files are in the `public/` directory and you specify `working-dir: public` and `target-base-url: https://hello.org`, then `public/hello/world.html` will get the URL `https://hello.org/hello/world.html`.

Required: yes

### `source-id`

The ID of the External Content Source in Zendesk Guide. See the [Zendesk API docs](https://developer.zendesk.com/api-reference/help_center/federated-search/external_content_sources/) for how to create an External Content Source.

Required: yes

### `type-id`

The ID of the External Content Type in Zendesk Guide. See the [Zendesk API docs](https://developer.zendesk.com/api-reference/help_center/federated-search/external_content_types/) for how to create an External Content Type.

Required: yes

### `client-id`

The Unique Identifier of a Zendesk OAuth client. See [Migrating from v6](#migrating-from-v6) for how to create one.

Required: yes

### `client-secret`

The Secret of the OAuth client identified by `client-id`. Store this as a repository secret, not in the workflow file.

Required: yes

### `zendesk-subdomain`

The subdomain of your Zendesk account.

Required: yes

### `working-dir`

Working directory. See `target-base-url` for when to use this.

Required: yes \
Default: `.`

### `content-css-selector`

CSS selector that will be passed to [Nokogiri’s `at` method](https://nokogiri.org/rdoc/Nokogiri/XML/Node.html#method-i-at). Only this node from each HTML file will sent to Zendesk Guide. By default, we post all text found in `<body>`, but you can set this selector to something more narrow (for example, `main` or `article`).

Required: no
Default: `body`

## Example Workflow

This workflow uses Hugo to build a static site, then synchronizes the HTML files with the Guide search index:

```yaml
name: Index in Guide Search

on:
  push:
    # Only index changes to the default branch, e.g. `master` or `main`.
    branches: [ $default-branch ]

jobs:
  sync:
    runs-on: ubuntu-latest

    steps:
      - name: Check out source code
        uses: actions/checkout@v4

      - name: Build Hugo site
        uses: klakegg/actions-hugo@1.0.0

      - name: Sync with the Guide Search Index
        uses: zendesk/index-content-in-guide-action@v7
        with:
          client-id: ${{ secrets.ZENDESK_CLIENT_ID }}
          client-secret: ${{ secrets.ZENDESK_CLIENT_SECRET }}
          zendesk-subdomain: my-zendesk-subdomain
          source-id: some-source-id
          type-id: some-type-id
          content-dir: public # defaults to `.`
          target-base-url: https://example.com
          content-css-selector: main # defaults to `body`
```

If you want to index multiple External Content types you can use the [matrix feature](https://docs.github.com/en/free-pro-team@latest/actions/reference/workflow-syntax-for-github-actions#jobsjob_idstrategymatrix) of Github Actions:


```yaml
# ...

jobs:
  sync:
    runs-on: ubuntu-latest

    strategy:
      matrix:
        include:
          - type-id: type-id-1
            content-dir: guides
          - type-id: type-id-1
            content-dir: api-docs

    name: "Sync ${{ matrix.content-dir }}"

    steps:
      - name: Check out source code
        uses: actions/checkout@v4

      - name: Build Hugo site
        uses: klakegg/actions-hugo@1.0.0

      - name: Sync with the Guide Search Index
        uses: zendesk/index-content-in-guide-action@v7
        with:
          client-id: ${{ secrets.ZENDESK_CLIENT_ID }}
          client-secret: ${{ secrets.ZENDESK_CLIENT_SECRET }}
          zendesk-subdomain: my-zendesk-subdomain
          source-id: some-source-id
          type-id: ${{ matrix.type-id }}         # <----
          content-dir: ${{ matrix.content-dir }} # <----
          target-base-url: https://example.com
          content-css-selector: main # defaults to `body`
```

## Migrating from v6

Up to and including `v6`, this action authenticated with a Zendesk API token passed as the `auth` input. Zendesk is [retiring API tokens](https://developer.zendesk.com/documentation/authentication/oauth-migration/):

| Date       | Change                                                                                                                                |
|------------|---------------------------------------------------------------------------------------------------------------------------------------|
| 2026-07-28 | Tokens unused for 30 days are deactivated automatically. Zendesk accounts created on or after this date cannot use API tokens at all. |
| 2026-10-27 | No new API tokens can be created.                                                                                                     |
| 2027-04-30 | All remaining API tokens are permanently deactivated and requests using them fail.                                                    |

`v7` replaces `auth` with `client-id` and `client-secret`. The action exchanges them for a short-lived OAuth access token on every run using the [client credentials grant](https://developer.zendesk.com/api-reference/ticketing/oauth/grant_type_tokens/), so there is no long-lived token to store or rotate. `v6` keeps working until 2027-04-30 if you are not ready to migrate.

To migrate:

1. Pick a service user. Actions taken with a client credentials token are attributed to the Zendesk user who created the OAuth client, so use a dedicated service account rather than a personal one. The user needs the Help Center manager role.

2. Create the OAuth client. Signed in as that user, go to Admin Center → Apps and integrations → APIs → OAuth clients and add a client. Leave it confidential (the default). A redirect URL is not needed for this grant. Copy the Unique Identifier and the Secret.

3. Add repository secrets `ZENDESK_CLIENT_ID` and `ZENDESK_CLIENT_SECRET`, then delete the old `ZENDESK_AUTH` secret.

4. Update the workflow:

   ```diff
      - name: Sync with the Guide Search Index
   -    uses: zendesk/index-content-in-guide-action@v6
   +    uses: zendesk/index-content-in-guide-action@v7
        with:
   -      auth: ${{ secrets.ZENDESK_AUTH }}
   +      client-id: ${{ secrets.ZENDESK_CLIENT_ID }}
   +      client-secret: ${{ secrets.ZENDESK_CLIENT_SECRET }}
          zendesk-subdomain: my-zendesk-subdomain
   ```

   All other inputs are unchanged.

If the run fails with a `403`, the OAuth client's scopes or the service user's role are too narrow. If it fails while requesting the token, check that `client-id` is the client's Unique Identifier rather than its numeric id.

## Creating a source and type for the test account

`.github/workflows/test.yml` runs the action against a test Zendesk account and hardcodes a `source-id` and `type-id`. There is no admin UI for either — they exist only over the [External Content Sources  API](https://developer.zendesk.com/api-reference/help_center/federated-search/external_content_sources/)
and the [External Content Types  API](https://developer.zendesk.com/api-reference/help_center/federated-search/external_content_types/).

Use `script/create-test-source` if you need to switch to a new: the script mints an OAuth access token, creates a source and a type, and prints the two IDs. Set the account subdomain and OAuth client at the top of the script (or pass them as environment variables), then run it:

```sh
ZENDESK_SUBDOMAIN=... ZENDESK_CLIENT_ID=... ZENDESK_CLIENT_SECRET=... script/create-test-source
```

It prints the IDs in the shape `test.yml` expects:

```
source-id: "01EV9B6T8YH7672NFGPBBYAXGT"
type-id: "01EV9B8DJ0668KRW653EFYA9NW"
```

Copy those into the `with:` block of `.github/workflows/test.yml`.
