---
name: test
description: Run unit tests across all zeam packages
---

# /test - Run Unit Tests

Run Zig's built-in test blocks across all zeam packages.

## Default

```bash
zig build test --summary all
```

## Options

Pass additional arguments after `--`:

- `/test -- -Dtest-filter="block"` - Run tests matching "block"
- `/test -- -Dtest-filter="process_slots"` - Run a specific test by name

## What It Runs

The `test` build step compiles and runs tests from every package:

| Package | Source | What It Tests |
|---------|--------|---------------|
| `types` | `pkgs/types/src/lib.zig` | SSZ serialization, type construction, validators |
| `state-transition` | `pkgs/state-transition/src/lib.zig` | Slot processing, block processing, epoch transitions |
| `state-proving-manager` | `pkgs/state-proving-manager/src/manager.zig` | ZK proof orchestration |
| `node` | `pkgs/node/src/lib.zig` | Forkchoice, chain management, clock, networking |
| `cli` | `pkgs/cli/src/main.zig` | CLI argument parsing, configuration |
| `params` | `pkgs/params/src/lib.zig` | Protocol parameters, presets |
| `network` | `pkgs/network/src/lib.zig` | P2P message handling, node registry |
| `configs` | `pkgs/configs/src/lib.zig` | Configuration loading, mainnet config |
| `utils` | `pkgs/utils/src/lib.zig` | JSON, YAML, SSZ helpers, logging, casting |
| `database` | `pkgs/database/src/lib.zig` | RocksDB interface, storage operations |
| `api` | `pkgs/api/src/lib.zig` | HTTP routes, event broadcasting |
| `xmss` | `pkgs/xmss/src/lib.zig` | Hash-based signatures, aggregation |

## Testing Conventions

- Tests are co-located with source code (Zig convention) using `test "name" { ... }` blocks
- Use `std.testing.expectEqual`, `std.testing.expectError`, etc.
- Test helpers go in dedicated files like `pkgs/database/src/test_helpers.zig`
- Each test should be self-contained — set up its own state, clean up after

## Examples

```bash
# Run all tests
zig build test --summary all

# Run only state-transition tests
zig build test --summary all -Dtest-filter="process"

# Verbose output on failure
zig build test --summary all 2>&1 | less
```

## When to Use

Run after any code change. This is the baseline — if unit tests fail, nothing else matters.
CI runs this on both ubuntu-latest and macos-latest.
