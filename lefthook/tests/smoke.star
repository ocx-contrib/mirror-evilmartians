# lefthook/tests/smoke.star — stable across upstream lefthook releases.
#
# Asserts the contract (exit codes, version SHAPE, a hook file lefthook WROTE,
# a git-config value a lefthook job actually EXECUTED, and lefthook's own
# aggregation of a child process's exit code), never help/version prose.
#
# WHY NOTHING ASSERTS ON `lefthook run` OUTPUT: lefthook decorates its run
# report with per-CHARACTER 24-bit SGR gradients, and `--colors off` does not
# strip all of it (the hook name stays bold, the summary rule stays coloured).
# Any plain multi-word substring check against that output is a coin flip. So
# every Tier 3 assertion below is either an exit code lefthook COMPUTED or a
# FILE it wrote — both immune to how it paints the terminal.
#
# HERMETIC BY CONSTRUCTION. lefthook's headline feature is installing git hooks
# into a repository, so the test makes its own throwaway repository in the
# scratch sandbox and works only inside it. Nothing is cloned, nothing is
# fetched, no user config is read or written.
#
# WHY `git` IS AVAILABLE: lefthook is a git hooks manager and hard-requires git
# — its first act on `validate`, `install` and `run` alike is
# `git rev-parse --path-format=absolute --show-toplevel …`, and outside a
# repository it dies with `exit status 128`. Using git in the fixtures adds no
# dependency this package does not already have. The Linux container legs
# install it via `containers[].setup` (see ../../mirror-base.yml); every
# GitHub-hosted macOS and Windows runner ships it.

LEFTHOOK = "lefthook.exe" if ocx.target_platform.os == ocx.os.Windows else "lefthook"

# The token a lefthook JOB must write into the repository's git config. It
# appears nowhere lefthook could echo it back from — only running the job puts
# it there.
TOKEN = "OCX_LEFTHOOK_JOB_RAN_9F3A"

# ─── Tier 1 + 2: liveness on the composed PATH + version SHAPE ──────────────
#
# The digits are the contract; any banner around them is not. `lefthook version`
# prints a bare `2.1.10` today — the regex survives a decorated reprint, an
# `expect.eq(stdout, "2.1.10")` would not, and an
# `expect.contains(stdout, "lefthook")` would break on a rebrand.
r_version = ocx.run(LEFTHOOK, "version")
expect.ok(r_version)
expect.matches(r_version.stdout, r"\d+\.\d+\.\d+")

# ─── A throwaway git repository, created in scratch ─────────────────────────
#
# `cwd` defaults to the scratch root, so the repository, the config and every
# path below are siblings and stay relative — correct on Windows too, with no
# separator juggling. `-b main` avoids git's default-branch advice on stderr.
expect.ok(ocx.run("git", "init", "-q", "-b", "main", "."))

# ─── Hermetic fixtures ──────────────────────────────────────────────────────
#
# `pre-commit` holds one job whose only effect is a WRITE into `.git/config`.
# `ocx-smoke-fail` is a custom (non-git-hook) group holding one job that exits
# non-zero in any repository: `git rev-parse --verify --quiet` answers 1 for a
# ref that does not exist. Between them they pin both directions of lefthook's
# exit-code aggregation.
ocx.write_file("lefthook.yml", """pre-commit:
  jobs:
    - name: ocx-smoke-write
      run: git config --local ocx.smoke.token """ + TOKEN + """
ocx-smoke-fail:
  jobs:
    - name: absent-ref
      run: git rev-parse --verify --quiet refs/heads/ocx-smoke-absent
""")

# The NEGATIVE CONTROL's fixture: structurally valid YAML whose `parallel` node
# is a string where the schema demands a boolean. It cannot be rejected on a
# YAML syntax error — only lefthook's own schema validation can fault it.
ocx.write_file("malformed.yml", """pre-commit:
  parallel: "not-a-bool"
  jobs:
    - name: x
      run: git rev-parse --git-dir
""")

# ─── Tier 3a: config validation, the positive case ──────────────────────────
r_ok = ocx.run(LEFTHOOK, "validate")
expect.ok(r_ok)

# ─── Tier 3b: THE NEGATIVE CONTROL ──────────────────────────────────────────
#
# A validator that rubber-stamped its input — or one whose schema layer never
# ran — would exit 0 here. Exit 1 alone is not the whole assertion: `parallel`
# is the field lefthook WORKED OUT was at fault by walking the document, and it
# reports the name on stdout while the bare failure line goes to stderr
# (measured: stdout `pre-commit: \n  parallel: Value is string but should be
# boolean`, stderr `Error: validation failed for main config`). Neither stream
# is colourised here, unlike `run`.
r_bad = ocx.run(LEFTHOOK, "validate", env = {"LEFTHOOK_CONFIG": "malformed.yml"})
expect.eq(r_bad.exit_code, 1)
expect.contains(r_bad.stdout, "parallel")

# ─── Tier 3c: `install` — a hook file lefthook WROTE ────────────────────────
#
# The product of this tool is a file in `.git/hooks/`. git ships a dozen
# `*.sample` hooks in a fresh repository but no active `pre-commit`, so its
# existence here is lefthook's doing and nothing else's, and the body must name
# the tool that generated it.
r_install = ocx.run(LEFTHOOK, "install")
expect.ok(r_install)
expect.true(ocx.exists(".git/hooks/pre-commit"))
expect.contains(ocx.read_file(".git/hooks/pre-commit"), "lefthook")

# ─── Tier 3d: `run` — a job that actually EXECUTED ──────────────────────────
#
# `--force` because a hook with no staged files is skipped ("no matching staged
# files") and a skipped job still exits 0 — asserting the exit code alone would
# green a run that executed nothing. `--no-tty` keeps the spinner off. The
# assertion is on `.git/config`, which only the job's own `git config --local`
# could have written: the token is not in any argument lefthook is handed.
r_run = ocx.run(LEFTHOOK, "run", "pre-commit", "--force", "--no-tty")
expect.ok(r_run)
expect.contains(ocx.read_file(".git/config"), TOKEN)

# ─── Tier 3e: exit-code aggregation, the failing direction ──────────────────
#
# lefthook reports 1 because its child did. This is the half that distinguishes
# "ran the jobs" from "printed a plan": a runner that never spawned anything
# would report success here, and Tier 3d alone cannot tell those apart.
r_fail = ocx.run(LEFTHOOK, "run", "ocx-smoke-fail", "--force", "--no-tty")
expect.eq(r_fail.exit_code, 1)

# No Tier 4: metadata.json declares PATH only (proven by the Tier 1 liveness
# call resolving `lefthook` off the composed PATH).
