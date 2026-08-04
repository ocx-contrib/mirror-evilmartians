---
title: lefthook
description: Fast, parallel git hooks manager for any language — one lefthook.yml drives every hook in the repository
keywords: lefthook,git,git-hooks,pre-commit,pre-push,hooks,linter,formatter,monorepo,go,cli
---

# lefthook

[lefthook](https://github.com/evilmartians/lefthook) is a git hooks manager
from [Evil Martians](https://evilmartians.com). A single `lefthook.yml` at the
repository root describes every hook — `pre-commit`, `pre-push`, `commit-msg`
and the rest — and `lefthook install` wires them into `.git/hooks/` for the
whole team. Jobs run **in parallel** by default, receive only the files that
actually changed (`{staged_files}`, `{push_files}`, glob and regexp filters),
and are a single self-contained binary with no runtime to install: no Ruby, no
Node, no Python.

## What's included

- **lefthook** — the binary. `lefthook install` writes the hook scripts,
  `lefthook run <hook>` executes a hook group by hand, `lefthook validate`
  checks the config against the schema, `lefthook dump` prints the config
  merged across `extends:`/`remotes:`, and `lefthook uninstall` removes it all
  again.

## Quick start

```yaml
# lefthook.yml
pre-commit:
  parallel: true
  jobs:
    - name: lint
      glob: "*.{js,ts}"
      run: npx eslint {staged_files}
    - name: format
      glob: "*.go"
      run: gofmt -l {staged_files}
      stage_fixed: true

pre-push:
  jobs:
    - name: tests
      run: go test ./...
```

```sh
lefthook install     # wire the hooks into .git/hooks
lefthook run pre-commit --force   # run a hook group without committing
```

`git` must be on `PATH` — lefthook resolves the repository with
`git rev-parse` before doing anything else.

## Links

- [lefthook on GitHub](https://github.com/evilmartians/lefthook)
- [Documentation](https://lefthook.dev/)
- [Configuration reference](https://lefthook.dev/configuration/)
