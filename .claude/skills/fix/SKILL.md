---
name: fix
description: Auto-fix Zig and Rust formatting issues
---

# /fix - Auto-Fix Formatting

Automatically fix all formatting issues across Zig and Rust source files.

## Commands

```bash
# 1. Fix Zig formatting
zig fmt .

# 2. Fix Rust formatting
cargo fmt --manifest-path rust/Cargo.toml --all
```

## What It Fixes

### `zig fmt .`

Reformats all `.zig` files in the repository to Zig's canonical style:
- Indentation, brace placement, alignment
- Covers `build.zig`, all files in `pkgs/`, and any other `.zig` source
- Safe to run repeatedly — idempotent

### `cargo fmt --all`

Reformats all Rust source files in the `rust/` workspace:
- All FFI glue crates: libp2p-glue, hashsig-glue, multisig-glue, risc0-glue, openvm-glue
- Applies rustfmt rules from the workspace configuration

## What It Does NOT Fix

- Rust clippy warnings — those require manual code changes
- Logic errors or test failures
- Zig compile errors

## When to Use

Run after making code changes, before committing. Then run `/lint` to verify everything passes (clippy issues will still need manual fixing).
