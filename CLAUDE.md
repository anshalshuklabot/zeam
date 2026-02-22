# Working with Zeam

## Repository Overview

Zeam is a production-grade Zig implementation of the Lean Consensus — a ZK-based Ethereum consensus protocol. It is the high-performance counterpart to [leanSpec](https://github.com/leanEthereum/leanSpec), which provides the minimal Python reference specification.

**Key principle:** leanSpec defines *what* is correct. Zeam implements *how* to do it fast. Deterministic state transition logic in Zeam **must** match leanSpec output exactly.

## Key Directories

- `pkgs/state-transition/` - Core state transition logic (MUST match leanSpec)
- `pkgs/types/` - Shared Beam/Zeam data types, SSZ containers
- `pkgs/node/` - Node lifecycle, forkchoice, chain management, validator client
- `pkgs/network/` - libp2p P2P networking (Zig ↔ Rust FFI)
- `pkgs/spectest/` - Spec test framework (consumes leanSpec fixtures)
- `pkgs/api/` - HTTP API (Beacon API compatible)
- `pkgs/cli/` - Command-line interface
- `pkgs/database/` - RocksDB persistent storage
- `pkgs/xmss/` - Hash-based signature scheme (quantum-resistant)
- `pkgs/state-transition-runtime/` - RISC-V binary for ZK-VM execution
- `pkgs/state-proving-manager/` - ZK proving orchestration
- `rust/` - Rust FFI glue (libp2p, hashsig, multisig, ZK provers)
- `leanSpec/` - Git submodule pointing to the Python reference specification

## Development Workflow

### Building

```bash
zig build all                              # Debug build of everything
zig build -Doptimize=ReleaseFast           # Release build
zig build -Dprover=all                     # Build with all ZK provers
zig build -Doptimize=ReleaseFast -Dgit_version="$(git rev-parse --short HEAD)"  # Versioned release
```

### Testing

```bash
zig build test --summary all               # Unit tests (all packages)
zig build simtest --summary all            # Simulation tests (multi-node devnet)
zig build spectest --summary all           # Generate + run spec tests
zig build spectest:generate --summary all  # Only regenerate Zig test wrappers
zig build spectest:run --summary all       # Only run (fixtures must exist)
```

### Code Quality

```bash
zig fmt .                                  # Format Zig code
zig fmt --check .                          # Check Zig formatting
cargo fmt --manifest-path rust/Cargo.toml --all               # Format Rust code
cargo fmt --manifest-path rust/Cargo.toml --all -- --check    # Check Rust formatting
cargo clippy --manifest-path rust/Cargo.toml --workspace -- -D warnings  # Rust linting
```

### Common Tasks

- **State transition**: `pkgs/state-transition/src/transition.zig` — `apply_raw_block`, `process_slots`, `process_block`
- **Types**: `pkgs/types/src/` — `state.zig`, `block.zig`, `attestation.zig`, `validator.zig`
- **Forkchoice**: `pkgs/node/src/forkchoice.zig` — `ProtoNode`, head selection, justification
- **Spec tests**: `pkgs/spectest/` — auto-generated from `leanSpec/fixtures/`
- **ZK runtime**: `pkgs/state-transition-runtime/src/` — RISC-V targets for risc0, OpenVM, sp1, zisk, powdr

## Code Style

### Zig Formatting

Format with `zig fmt` — no exceptions. The canonical Zig style is the only accepted style.

### Import Organization

Group imports in this order, separated by blank lines:

```zig
const std = @import("std");                    // 1. Standard library
const ssz = @import("ssz");                    // 2. External dependencies
const types = @import("@zeam/types");          // 3. Internal packages
const zeam_utils = @import("@zeam/utils");
```

### Error Handling (CRITICAL)

**Never use `unreachable` or `@panic` in production code.** These cause the node to crash. Always return errors.

```zig
// NEVER in production code
unreachable;
@panic("this shouldn't happen");
const value = slice[index]; // can panic on out-of-bounds

// ALWAYS
return error.InvalidState;
const value = if (index < slice.len) slice[index] else return error.IndexOutOfBounds;
```

Panics are acceptable only in:
- Tests (`test "..." { ... }`)
- Compile-time assertions (`comptime { ... }`)
- Truly unreachable branches after exhaustive switches

### Safe Arithmetic (CRITICAL for state-transition)

In `pkgs/state-transition/` and any code that affects consensus state, use checked or saturating arithmetic:

```zig
// NEVER in state-transition code
const result = a + b;                          // Can overflow silently

// ALWAYS
const result = std.math.add(u64, a, b) catch return error.Overflow;  // Checked
const result = a +| b;                         // Saturating (when overflow is safe to cap)
```

### Documentation

Every public function and type must have a doc comment (`///`):

```zig
/// Process all slots from the current state slot up to (but not including) the target slot.
/// Returns an error if the target slot is not greater than the current slot.
pub fn process_slots(self: *BeamState, allocator: Allocator, target_slot: Slot, logger: ModuleLogger) !void {
```

**Write short, scannable doc comments.** One idea per line. Avoid long compound sentences.

**Never reference function names in documentation.** Names change. Use plain language:

```zig
// Bad: "Call process_slots() before process_block()"
// Good: "Advance the state to the block's slot before processing the block."
```

### Naming

- **Descriptive names** — no single-letter variables outside loop indices (`i`, `j`)
- **camelCase** for functions and variables (Zig convention)
- **PascalCase** for types and structs
- **SCREAMING_SNAKE** for compile-time constants and protocol parameters

### Testing Style

**Prefer full equality assertions** over checking individual fields:

```zig
// Bad
try std.testing.expectEqual(result.slot, 42);
try std.testing.expectEqual(result.parent_root, expected_root);

// Good
try std.testing.expectEqual(result, ExpectedType{
    .slot = 42,
    .parent_root = expected_root,
    .state_root = expected_state_root,
});
```

### No Backward Compatibility

**CRITICAL**: Never add backward compatibility shims, wrapper functions, or re-exports of deprecated APIs. When refactoring:
- Delete old code entirely
- Update all call sites to use the new API
- Old patterns must be removed, not preserved

## Package Architecture

### Dependency Graph (simplified)

```
cli → node → state-transition → types → params
              │                          ↑
              ├→ network ────────────────┘
              ├→ database
              ├→ api
              └→ state-proving-manager → state-transition-runtime
```

### Package Boundaries (CRITICAL)

- **`types/`** — Shared types only. No business logic. No I/O.
- **`params/`** — Protocol parameters and presets. Constants only.
- **`state-transition/`** — Pure state transition. No I/O, no networking, no database. Must compile to RISC-V for ZK-VMs.
- **`node/`** — Orchestration layer. Can depend on everything. Manages forkchoice, chain, clock, validators.
- **`network/`** — P2P only. Talks to node via interface. Uses Rust libp2p FFI.
- **`database/`** — Storage only. Exposes clean interface (`interface.zig`).
- **`spectest/`** — Test infrastructure only. Never imported by production code.
- **`utils/`** — Shared utilities. No business logic. JSON, YAML, SSZ helpers, logging.

### Rust FFI Glue

Rust code in `rust/` provides FFI for libraries without Zig equivalents:

| Crate | Purpose | Zig Consumer |
|-------|---------|--------------|
| `libp2p-glue` | libp2p networking | `pkgs/network/src/ethlibp2p.zig` |
| `hashsig-glue` | Hash-based signatures | `pkgs/xmss/src/hashsig.zig` |
| `multisig-glue` | Multi-signatures | `pkgs/xmss/src/aggregation.zig` |
| `risc0-glue` | risc0 ZK prover | `pkgs/state-proving-manager/` |
| `openvm-glue` | OpenVM ZK prover | `pkgs/state-proving-manager/` |

Build Rust before Zig if glue source changed:
```bash
cargo build --release --manifest-path rust/Cargo.toml
```

## Spec Test Framework

Zeam consumes test fixtures generated by leanSpec. This is the primary mechanism for ensuring spec compliance.

### Pipeline

1. **leanSpec** generates JSON fixtures: `cd leanSpec && uv run fill --fork=devnet --clean -n auto`
2. **Generator** creates Zig tests: `zig build spectest:generate` reads `leanSpec/fixtures/` and writes `pkgs/spectest/src/generated/index.zig`
3. **Runners** execute tests: `zig build spectest:run` runs each generated test against zeam's implementation

### Runners

- `pkgs/spectest/src/runner/state_transition_runner.zig` — parses pre-state + blocks, runs `apply_raw_block`, compares post-state
- `pkgs/spectest/src/runner/fork_choice_runner.zig` — parses fork choice steps, runs forkchoice logic, compares head/justified/finalized

### Fixture Kinds

Defined in `pkgs/spectest/src/fixture_kind.zig`:
- `state_transition` — handler subdir: `state_transition/`
- `fork_choice` — handler subdir: `fc/`

See `resources/spec-test-framework.md` for adding new runners.

## Important Notes

- **Zig 0.15.2** required — exact version
- **Rust nightly** required for FFI glue builds
- **Python 3.12+** required for leanSpec fixture generation
- **uv** required for leanSpec dependency management
- **Always run lint checks before finishing**: `zig fmt --check . && cargo fmt --manifest-path rust/Cargo.toml --all -- --check && cargo clippy --manifest-path rust/Cargo.toml --workspace -- -D warnings`
- **Always run tests before pushing**: `zig build test --summary all && zig build simtest --summary all`
- **leanSpec is authoritative**: If spec tests fail, fix zeam — never adjust expected values
- Repository is `zeam` not `z-eam`
- CI runs on ubuntu-latest + macos-latest
- Branch from `main`
