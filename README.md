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

The ID of the External Content Source in Zendesk Guide. See the [Zendesk API docs](https://developer.zendesk.com/rest_api/docs/help_center/federated_search_-_external_content_source_api#creates-an-external-content-source) for how to create an External Content Source.

Required: yes

### `type-id`

The ID of the External Content Type in Zendesk Guide. See the [Zendesk API docs](https://developer.zendesk.com/rest_api/docs/help_center/federated_search_-_external_content_type_api#creates-an-external-content-type) for how to create an External Content Type.

Required: yes

### `auth`

Authentication Credentials, e.g. `my@email.com:password`. See the [Zendesk API docs](https://developer.zendesk.com/rest_api/docs/support/introduction#security-and-authentication) for more information. The value provided will be used in the `Authorization` header using the `Basic` method, i.e. `Authorization: Basic <auth>`.

Required: yes

### `zendesk-subdomain`

The subdomain of your Zendesk account.

Required: yes

### `working-dir`

Working directory. See `target-base-url` for when to use this.

Required: yes \
Default: `.`

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
        uses: actions/checkout@v2

      - name: Build Hugo site
        uses: klakegg/actions-hugo@1.0.0

      - name: Sync with the Guide Search Index
        uses: zendesk/index-content-in-guide-action@v3
        with:
          auth: ${{ secrets.ZENDESK_AUTH }}
          zendesk-subdomain: my-zendesk-subdomain
          source-id: some-source-id
          type-id: some-type-id
          content-dir: public # defaults to `.`
          target-base-url: https://example.com
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
        uses: actions/checkout@v2

      - name: Build Hugo site
        uses: klakegg/actions-hugo@1.0.0

      - name: Sync with the Guide Search Index
        uses: zendesk/index-content-in-guide-action@v3
        with:
          auth: ${{ secrets.ZENDESK_AUTH }}
          zendesk-subdomain: my-zendesk-subdomain
          source-id: some-source-id
          type-id: ${{ matrix.type-id }}         # <----
          content-dir: ${{ matrix.content-dir }} # <----
          target-base-url: https://example.com
```
