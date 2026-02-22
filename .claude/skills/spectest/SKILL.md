---
name: spectest
description: Generate and run spec compliance tests — verify zeam matches leanSpec fixtures
---

# /spectest - Spec Compliance Tests

Verify that zeam's state transition and fork choice produce identical results to leanSpec (the Python reference specification). This is the most critical test category.

## Default Usage (generate + run)

```bash
zig build spectest --summary all
```

This is equivalent to running generate then run in sequence.

## Options

- `/spectest` - Regenerate fixtures from leanSpec AND run all spec tests
- `/spectest -- generate` - Only regenerate Zig test wrappers: `zig build spectest:generate --summary all`
- `/spectest -- run` - Only run existing tests (fixtures must already be generated): `zig build spectest:run --summary all`
- `/spectest -- skip-errors` - Skip expected failures:
  ```bash
  ZEAM_SPECTEST_SKIP_EXPECTED_ERRORS=true zig build spectest:run --summary all
  ```
  Or equivalently, pass `--skip-expected-error-fixtures` after `--` to the build step.

## Full Pipeline (from scratch)

When leanSpec has been updated or fixtures don't exist yet:

```bash
# 1. Initialize/update the leanSpec submodule
git submodule update --init leanSpec

# 2. Generate JSON fixtures from the Python spec
cd leanSpec && uv run fill --fork=devnet --clean -n auto && cd ..

# 3. Generate Zig test wrappers from JSON fixtures
zig build spectest:generate --summary all

# 4. Run the generated tests against zeam's implementation
zig build spectest:run --summary all
```

## How It Works

### Fixture Generation (leanSpec side)

leanSpec's `fill` command runs Python spec tests in `tests/consensus/` which produce JSON fixture files:

- Output directory: `leanSpec/fixtures/consensus/`
- Fixture format: JSON with camelCase keys (Pydantic `CamelModel`)
- Two categories:
  - **State transition fixtures**: pre-state + blocks → expected post-state
  - **Fork choice fixtures**: steps (tick, block, attestation) → expected head/justified/finalized

### Test Generation (zeam side)

`zig build spectest:generate` runs `pkgs/spectest/src/generator.zig`, which:

1. Walks `leanSpec/fixtures/` (default, or path from `--vectors-root`)
2. Discovers fixtures by kind (`state_transition`, `fork_choice`) from `pkgs/spectest/src/fixture_kind.zig`
3. Routes fixtures via `handlerSubdir()`: `state_transition/` and `fc/`
4. Generates Zig test file at `pkgs/spectest/src/generated/index.zig`
5. Each generated test instantiates the appropriate runner with the fixture's relative path

Generator options:
```bash
zig build spectest:generate -- --vectors-root path/to/fixtures  # Alternate fixture directory
zig build spectest:generate -- --output path/to/generated       # Alternate output path
zig build spectest:generate -- --dry-run                        # List fixtures without writing
```

### Test Execution (zeam side)

`zig build spectest:run` compiles and runs the generated tests. Each test:

1. Resolves the fixture JSON directory
2. Parses JSON into Zig types (state, blocks, expected outcomes)
3. Executes zeam's state transition or fork choice logic
4. Compares zeam's output against leanSpec's expected output
5. Gracefully skips if the leanSpec checkout is missing (no hard failure)

### Runners

| Runner | File | What It Verifies |
|--------|------|-----------------|
| State Transition | `pkgs/spectest/src/runner/state_transition_runner.zig` | Pre-state + blocks → post-state matches leanSpec |
| Fork Choice | `pkgs/spectest/src/runner/fork_choice_runner.zig` | Block/attestation/tick steps → head/justified/finalized matches leanSpec |

Both runners export a `TestCase(Fork, rel_path)` type with an `execute` method. The generated harness calls this.

### Adding a New Runner

1. Create `pkgs/spectest/src/runner/<name>_runner.zig` — export `pub const name`, implement `TestCase(Fork, rel_path)` with `execute` method
2. Add enum variant in `pkgs/spectest/src/fixture_kind.zig` — implement `runnerModule()` and `handlerSubdir()`, extend the `all` constant
3. Regenerate: `zig build spectest:generate --summary all`
4. Verify: `zig build spectest:run --summary all`

## Critical Rules

- **leanSpec is authoritative.** If spec tests fail, fix zeam — never adjust expected values.
- **Always run after touching `pkgs/state-transition/`** — this is the primary spec-fidelity gate.
- **Always run after leanSpec submodule updates** — spec changes may require zeam updates.

## Mapping: leanSpec Fixtures → Zeam Code

| Fixture Area | leanSpec Source | Zeam Implementation |
|---|---|---|
| State transitions | `tests/consensus/` + `src/lean_spec/` | `pkgs/state-transition/src/transition.zig` |
| Fork choice | `tests/consensus/` + `src/lean_spec/` | `pkgs/node/src/forkchoice.zig` |
| SSZ types | `src/lean_spec/subspecs/ssz/` | `ssz.zig` (external dep) + `pkgs/types/src/` |
| Block types | `src/lean_spec/subspecs/containers/block/` | `pkgs/types/src/block.zig` |
| State types | `src/lean_spec/subspecs/containers/state/` | `pkgs/types/src/state.zig` |
| Attestations | `src/lean_spec/subspecs/containers/` | `pkgs/types/src/attestation.zig` |

## When to Use

- **MANDATORY** before pushing changes to `pkgs/state-transition/` or `pkgs/types/`
- After updating the leanSpec submodule
- After any change to forkchoice logic in `pkgs/node/src/forkchoice.zig`
- Before releases
- This is the same suite that CI runs on every PR
