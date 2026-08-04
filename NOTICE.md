# NOTICE

This repository packages and redistributes upstream software published by the
[lefthook](https://github.com/evilmartians/lefthook) project. The Apache-2.0
license in [`LICENSE`](LICENSE) covers the OCX pipeline files authored here. It
does **not** cover any upstream-derived asset — the redistributed bytes carry
their own license, recorded below.

The package logo is upstream's own mark
([`logo_sign.svg`](https://github.com/evilmartians/lefthook/blob/master/logo_sign.svg)),
re-encoded to 512×512 for catalog identification only. No endorsement is
implied, and no trademark claim is made.

| Package | GHCR path | Upstream SPDX |
|---|---|---|
| `lefthook` | `ghcr.io/ocx-contrib/evilmartians/lefthook` | `MIT` |

---

## `lefthook`

Upstream: <https://github.com/evilmartians/lefthook>
Published to `ghcr.io/ocx-contrib/evilmartians/lefthook`.

| Component | SPDX | Holder |
|---|---|---|
| lefthook | **MIT** | Copyright (c) 2019 Arkweid (Evil Martians) |

Verified at the Phase 1.5 license gate:

```
$ gh api repos/evilmartians/lefthook/license --jq '{spdx: .license.spdx_id, path: .path}'
{"path":"LICENSE","spdx":"MIT"}
```

MIT is permissive and grants redistribution of the compiled binary subject to
its notice-retention condition. Upstream's release assets are **raw
uncompressed binaries** — a single file per platform with no archive around it
and therefore no `LICENSE` file travelling alongside — so the notice is
retained here instead. The canonical text is
<https://github.com/evilmartians/lefthook/blob/master/LICENSE>, and every
published manifest carries an `org.opencontainers.image.source` annotation
pointing at this repository alongside `org.opencontainers.image.licenses: MIT`.

The published binaries are statically linked Go builds that vendor third-party
modules under permissive licenses, enumerated in the `go.mod` / `go.sum` of the
tagged upstream source for each mirrored version.

No modifications are made to any upstream artifact in this repository; they are
republished byte-for-byte inside an OCX bundle. The only transformation is the
executable mode bit: GitHub serves raw release assets as `0644`, and `prepare`
chmods the declared binary to `0755` so it can be run at all.
