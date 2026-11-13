# Shared dprint schema

Use this schema with any combination of the shared dprint configs. It includes
the core configuration and every plugin in `configs/dprint.*.json`.

For `dprint.toml`:

```toml
#:schema https://raw.githubusercontent.com/kjanat/kjanat/master/schemas/dprint.schema.json

extends = ["https://raw.githubusercontent.com/kjanat/kjanat/master/configs/dprint.remote.json"]
```

For `dprint.json` or `dprint.jsonc`:

```json
{
  "$schema": "https://raw.githubusercontent.com/kjanat/kjanat/master/schemas/dprint.schema.json",
  "extends": ["https://raw.githubusercontent.com/kjanat/kjanat/master/configs/dprint.remote.json"]
}
```

The schema is JSON even when the configuration is TOML. Editors use the schema
for validation and completion; kprint loads the formatting rules through
`extends`. Add the schema reference to each project's config so its editor can
discover it.

Renovate continues to update the plugin versions in `configs/`. Pull requests
check that all of those plugins have retrievable schemas. After a merge to
`master`, and daily, the autofix workflow regenerates the schema and includes any
changes in its existing `autofix/dprint` pull request. Merge that PR to publish
the refreshed schema at the same URL. The add-plugin workflow also includes the
regenerated schema in its PR.

To regenerate locally with kprint:

```sh
DPRINT=kprint bash .github/scripts/dprint-schema.sh
```

Generation reads plugin pins from the checkout, fails if any plugin schema is
unavailable, and replaces the published file only after generation succeeds.
If a project adds plugins outside the shared configs, generate a project-specific
schema to get their configuration completions too.
