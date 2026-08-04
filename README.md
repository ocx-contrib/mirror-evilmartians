# mirror-evilmartians

OCX mirror for [lefthook](https://github.com/evilmartians/lefthook), the git
hooks manager published by [Evil Martians](https://evilmartians.com). One
repository, one spec directory per package.

| Package | Spec | Publishes to | Announced as | Upstream SPDX |
|---|---|---|---|---|
| [lefthook](https://github.com/evilmartians/lefthook) | [`lefthook/mirror.yml`](lefthook/mirror.yml) | `ghcr.io/ocx-contrib/evilmartians/lefthook` | [`ocx.sh/evilmartians/lefthook`](https://index.ocx.sh/evilmartians/lefthook) | `MIT` |

Each upstream release is discovered, re-bundled, smoke-tested per
`(version, platform)` and only then pushed with cascade tags, after which the
result is announced into the OCX index.

`evilmartians` is the project's own brand rather than a maintainer's personal
handle, so the org names the namespace: the package is `evilmartians/lefthook`.

## Layout

```
mirror-base.yml         repo-wide policy every spec inherits via `extends:`
lefthook/
├── mirror.yml          the spec — never at the repo root
├── metadata.json       bundle interface
├── CATALOG.md          → ocx package describe
├── logo.svg / logo.png describe assets, 512px PNG
└── tests/smoke.star    Starlark smoke test
```

`LICENSE` and `NOTICE.md` are shared at the root. Logos are **not** — each
package carries its own, because a repo-root `logo.*` sits in no workflow's
`paths:` filter, so replacing it would publish nothing until some unrelated
edit happened to fire.

⚠️ `extends:` is a **shallow** merge of top-level keys. A spec that restates
`platforms:` to change one runner drops every `containers:` entry with it, and
nothing reds — the legs simply stop existing, and every `os.features` claim
goes back to being asserted rather than verified. Restate a block in full or
not at all. `lefthook/mirror.yml` does not restate it at all, which removes the
trap structurally.

## Platforms

`lefthook` publishes six platform entries: both Linux arches, both macOS arches
and both Windows arches. Upstream ships one Go binary per platform with no
musl/gnu split, and all four declared Linux artifacts were byte-measured at
**both ends** of the mirrored range, 2.1.8 and 2.1.10: no `PT_INTERP`, no
`DT_NEEDED`, no UPX stub (`strings -a | grep -c '^UPX'` → 0, 16 section headers
present). `os.features` states what an artifact requires *of the host*, so both
Linux keys are **bare** — `+libc.glibc` would hide the package from Alpine and
`+libc.musl` would hide it from every glibc host it in fact runs on. The
`alpine:3.20` container leg on both arches in `mirror-base.yml` is what turns
that claim into evidence; the measurement transcript is recorded above the
`assets:` block in `lefthook/mirror.yml`.

Upstream also publishes a `Windows_i386` build, FreeBSD and OpenBSD binaries,
and `.apk`/`.deb`/`.rpm` distro sidecars. None maps to an OCX platform key —
ocx's architecture enum is `amd64` and `arm64` only, FreeBSD and OpenBSD are
not OCX operating systems, and the package-manager assets carry no OS token at
all — so none is mirrored.

### The raw-binary assets and their `.gz` twins

Every platform ships **twice**: a raw uncompressed binary and a bare `.gz` of
it. A bare single-file `.gz` is not a supported archive format, and
`asset_type: binary` does not red on one — it *false-greens*, publishing
still-compressed bytes at mode 0755. Verified these are bare gz rather than
tarballs (`gzip -dc … | tar tf -` → "This does not look like a tar archive";
payload magic `7f 45 4c 46`), so every asset pattern takes the **raw** file and
is **end-anchored**: `lefthook_2.1.10_Linux_x86_64` is a strict prefix of
`lefthook_2.1.10_Linux_x86_64.gz`, and an unanchored pattern would match both.

`linux/arm64` has a second trap: `lefthook_<V>_Linux_arm64` and
`lefthook_<V>_Linux_aarch64` both ship on every release (four candidates with
the `.gz` twins). `lefthook_checksums.txt` shows an identical sha256 for the
pair, so they are one file under two names; `_arm64` is taken for consistency
with the arch token every other OS uses, and the `$` anchor is what keeps
`_aarch64` from turning the match into an ambiguous-`>1` error.

Resolution was verified **both ways on every in-range release** (2.1.8, 2.1.9,
2.1.10): each of the six patterns matches exactly one asset out of 31, every
time. A pattern matching zero would be silently skipped rather than reported,
so this check is not optional.

## Editing

| File | Edit | Regenerate after |
|------|------|------------------|
| `mirror-base.yml`, `lefthook/mirror.yml` | hand | yes — see below |
| `lefthook/{metadata.json,CATALOG.md,logo.*}` | hand | — |
| `lefthook/tests/smoke.star` | hand | — |
| `.github/workflows/*.yml` | **generated — never hand-edit** | re-run when a spec changes |

```bash
ocx-mirror package pipeline generate ci --spec lefthook/mirror.yml
```

**Name every spec.** `--spec` *appends* rather than replaces, so a command
naming a subset silently stops rendering the rest while staying green — and the
drift guard reds on a generated workflow the current spec set no longer
produces.

`verify-generated.yml` exits 65 on drift. If a generated workflow is wrong, the
spec or the renderer template is wrong — fix it there and regenerate.

Run `direnv allow` once to put the pinned toolchain on `PATH`, and invoke
`ocx-mirror` directly — never `ocx run -- ocx-mirror`, which pins
`OCX_BINARY_PIN` to the bootstrap `ocx` and false-reds the nested push.

## The binaries claim

`lefthook/metadata.json` declares `binaries: ["lefthook"]` by hand, and
`mirror-base.yml` sets `bin_scan: "off"` — forced, not preferred. Every asset
is a raw binary, so it lands at the bundle content root and `PATH` is a bare
`${installPath}`; the scan only inspects an interface-visible
`${installPath}/<dir>` entry, so with no subdirectory to point at, `auto` and
`verify` both fail spec load at exit 65 rather than offer a hollow check.

The hand list is **load-bearing beyond documentation** here: GitHub serves raw
release assets with mode `0644` (measured on every downloaded asset), and
`prepare` chmods `0755` exactly the names `metadata.json` declares. An
undeclared binary would ship non-executable, and `bin_scan: auto` could not
rescue it — the scan only reports candidates it finds *already* executable.

## Container legs install git

`containers[].setup` adds `git` to each Linux leg. That is not a test
convenience: lefthook is a git hooks manager and hard-requires git at runtime —
its first act on `validate`, `install` and `run` alike is
`git rev-parse --path-format=absolute --show-toplevel …`, and outside a
repository it dies with `exit status 128`. None of `ubuntu:24.04`,
`alpine:3.20` or `fedora:40` ships git. Zero `DT_NEEDED` means no *shared
library* needs provisioning; git is the one runtime dependency this package
genuinely has, and `os.features` has no way to express it. Every GitHub-hosted
macOS and Windows runner already ships git, so those legs provision nothing.

## The smoke test

`lefthook/tests/smoke.star` creates a throwaway git repository in the test
scratch sandbox and asserts what lefthook *did*, never what it printed:

- `lefthook version` matches a version **shape** regex — the digits are the
  contract, the banner is not.
- `lefthook install` writes `.git/hooks/pre-commit`. A fresh repository has a
  dozen `*.sample` hooks and no active `pre-commit`, so its existence is
  lefthook's doing and the body must name the tool that generated it.
- `lefthook run pre-commit --force` executes a job whose only effect is a
  `git config --local` write, and the test asserts the token turns up in
  `.git/config`. `--force` matters: a hook with no staged files is *skipped*,
  and a skipped job still exits 0 — the exit code alone would green a run that
  executed nothing.
- Two negative controls. A structurally valid config whose `parallel` node is a
  string where the schema wants a boolean must exit 1 from `lefthook validate`
  (only the schema layer can fault it — it is not a YAML syntax error), and a
  hook group whose job exits non-zero must make `lefthook run` exit 1. Without
  the second, a runner that never spawned anything would pass.

Nothing asserts on `lefthook run` output: lefthook paints its report with
per-character 24-bit SGR gradients that `--colors off` does not fully strip, so
every assertion is an exit code lefthook computed or a file it wrote.

## Required secrets

| Secret | Use |
|--------|-----|
| `OCX_ANNOUNCE_TOKEN` | opens the index pull request from the `ocx-contrib/index` fork |
| `OCX_MIRROR_DISCORD_HOOK` | notify-stage Discord webhook URL |

(Inherited from the `ocx-contrib` org with visibility ALL. GHCR pushes use the
run's own `GITHUB_TOKEN` — no registry secret needed.)

## License

Apache-2.0 — see [`LICENSE`](LICENSE). Upstream assets are out of scope; the
package's redistribution license is recorded in [`NOTICE.md`](NOTICE.md). The
logo is upstream's own mark, re-encoded for catalog identification only.
