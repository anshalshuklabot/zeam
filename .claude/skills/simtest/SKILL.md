---
name: simtest
description: Run simulation tests — multi-node devnet integration scenarios
---

# /simtest - Run Simulation Tests

Run end-to-end integration tests that spin up real zeam node processes, form a mock network, and verify chain behavior.

## Default

```bash
zig build simtest --summary all
```

## What It Runs

The `simtest` build step runs `pkgs/cli/test/integration.zig`, which:

1. Locates the compiled `zeam` executable from `zig-out/bin/`
2. Spawns zeam node processes with `--mockNetwork true`
3. Waits for nodes to become ready (listening on expected ports)
4. Verifies nodes communicate, produce blocks, attest, and finalize

## Test Scenarios

The integration test exercises:

- **Node startup** - Verifies the executable exists and starts cleanly
- **Mock networking** - Nodes discover each other via mock P2P layer
- **Block production** - Validators produce and propagate blocks
- **Attestation** - Validators attest to blocks they've seen
- **Finalization** - Chain reaches finality through justification + finalization

## Local Devnet (Manual)

For manual multi-node testing beyond simtests, see `pkgs/cli/test/fixtures/README.md`:

```bash
# Build
zig build -Doptimize=ReleaseFast
zig build tools -Doptimize=ReleaseFast

# Generate keys, ENRs, config, then run two nodes
# Full guide: pkgs/cli/test/fixtures/README.md
```

Key configuration files for manual devnet:
- `genesis/config.yaml` - Genesis time, validator count, parameters
- `genesis/nodes.yaml` - Node ENRs for discovery
- `genesis/validators.yaml` - Validator-to-node assignment
- `genesis/validator-config.yaml` - Node configs with private keys

## Prerequisites

- The `zeam` binary must be built first: `zig build all` or `zig build -Doptimize=ReleaseFast`
- Rust FFI glue must be compiled (simtests exercise the full node including networking)

## When to Use

- After changes to `pkgs/node/`, `pkgs/network/`, `pkgs/cli/`
- After changes to forkchoice (`pkgs/node/src/forkchoice.zig`)
- After changes to chain management (`pkgs/node/src/chain.zig`)
- Before any PR that touches node lifecycle or consensus logic

## Troubleshooting

- **Executable not found**: Run `zig build all` first
- **Timeout waiting for node**: Check if ports 9000/9001 are already in use
- **Finalization not reached**: Increase slot duration or check validator config
- **Process cleanup**: Simtests should clean up child processes; if orphaned, `pkill zeam`
