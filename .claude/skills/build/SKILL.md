---
name: build
description: Build the zeam client and its packages
---

# /build - Build Zeam

Build the zeam client. This compiles all Zig packages and links the Rust FFI glue libraries.

## Default Usage

```bash
zig build all
```

## Options

Pass build options as Zig build flags:

- `/build` - Debug build of all packages
- `/build -- -Doptimize=ReleaseFast` - Release-optimized build
- `/build -- -Dprover=risc0` - Build with risc0 ZK prover
- `/build -- -Dprover=openvm` - Build with OpenVM ZK prover
- `/build -- -Dprover=all` - Build with all ZK provers
- `/build -- -Dprover=dummy` - Build with dummy prover (default)
- `/build -- -Dlto=true` - Enable link-time optimization (slower build, smaller binary)

## What It Builds

The `all` step compiles:

1. `zig-out/bin/zeam` - Main client binary (CLI + node + API)
2. `zig-out/bin/zeam-tools` - Developer tools (ENR generation, etc.)
3. All packages in `pkgs/`: state-transition, node, network, api, cli, types, database, xmss, etc.
4. Links Rust FFI libraries from `rust/target/`:
   - `libhashsig_glue.a` - Hash-based signature FFI
   - `libmultisig_glue.a` - Multi-signature FFI
   - `liblibp2p_glue.a` - libp2p networking FFI
   - `librisc0_glue.a` / `libopenvm_glue.a` - ZK prover FFI (when selected)

## Release Build with Version

```bash
zig build -Doptimize=ReleaseFast -Dgit_version="$(git rev-parse --short HEAD)"
```

The `git_version` option embeds the commit hash into the binary for version reporting.

## Docker Build

Build requires a native binary first (Docker uses `Dockerfile.prebuilt` to avoid Zig HTTP pool bugs in Docker):

```bash
zig build -Doptimize=ReleaseFast -Dgit_version="$(git rev-parse --short HEAD)"
docker build -f Dockerfile.prebuilt -t zeam:local .
```

With OCI labels for registry publishing:

```bash
docker build -f Dockerfile.prebuilt \
  --build-arg GIT_COMMIT=$(git rev-parse HEAD) \
  --build-arg GIT_BRANCH=$(git rev-parse --abbrev-ref HEAD) \
  -t blockblaz/zeam:latest .
```

## Prerequisites

- **Zig 0.15.2** - Exact version required
- **Rust nightly** - For FFI glue compilation
- Fetch Zig dependencies first if fresh clone:
  ```bash
  zig build --fetch
  ```
- If Rust glue source changed, rebuild before Zig:
  ```bash
  cargo build --release --manifest-path rust/Cargo.toml
  ```

## Troubleshooting

- **Zig dependency fetch failures**: Retry up to 5 times (upstream HTTP flakiness):
  ```bash
  zig build --fetch || zig build --fetch || zig build --fetch
  ```
- **macOS linker errors**: Rust glue links `CoreFoundation`, `SystemConfiguration`, `Security` frameworks automatically
- **Missing Rust libraries**: Run `cargo build --release --manifest-path rust/Cargo.toml` first

## When to Use

Run after any code change to verify compilation. CI runs `zig build all` on both ubuntu-latest and macos-latest.
