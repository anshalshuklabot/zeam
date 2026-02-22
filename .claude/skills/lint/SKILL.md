---
name: lint
description: Run all linting and formatting checks (Zig + Rust)
---

# /lint - Run All Lint Checks

Run the complete lint and formatting check suite across both Zig and Rust codebases. This matches exactly what CI runs in the `lint` job.

## Commands

```bash
# 1. Zig formatting check
zig fmt --check .

# 2. Rust formatting check
cargo fmt --manifest-path rust/Cargo.toml --all -- --check

# 3. Rust linting (clippy with warnings-as-errors)
cargo clippy --manifest-path rust/Cargo.toml --workspace -- -D warnings
```

## What Each Check Does

### `zig fmt --check .`

Checks all `.zig` files in the repository against Zig's canonical formatting rules:
- Indentation (4 spaces)
- Brace placement
- Alignment of struct fields and function parameters
- Whitespace around operators

Covers all files in `build.zig`, `pkgs/`, and any other `.zig` source.

### `cargo fmt -- --check`

Checks all Rust source files in `rust/` against rustfmt rules:
- `rust/libp2p-glue/` - libp2p networking FFI
- `rust/hashsig-glue/` - Hash-based signature FFI
- `rust/multisig-glue/` - Multi-signature FFI
- `rust/risc0-glue/` - risc0 ZK prover FFI
- `rust/openvm-glue/` - OpenVM ZK prover FFI

### `cargo clippy -- -D warnings`

Runs Rust's linter across all workspace crates with warnings treated as errors. Catches:
- Unused variables and imports
- Inefficient patterns
- Potential bugs (unwrap on None, etc.)
- Style violations

## When to Use

Run before every commit. This is the **first** job in CI — if lint fails, nothing else runs.

## CI Context

The CI `lint` job runs on ubuntu-latest with:
- Zig 0.15.2
- Rust stable (for clippy/fmt only; build uses nightly)
- Zig dependencies fetched and cached
- Rust dependencies cached via `Swatinem/rust-cache`
