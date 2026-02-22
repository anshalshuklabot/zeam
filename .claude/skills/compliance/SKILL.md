---
name: compliance
description: Full leanSpec compliance verification — end-to-end check that zeam matches the reference spec
---

# /compliance - Full Spec Compliance Verification

Run the complete verification pipeline to ensure zeam's deterministic logic produces identical results to leanSpec. This is the nuclear option — syncs leanSpec to latest, regenerates everything, and runs the full suite.

## Command

```bash
# 1. Sync leanSpec to latest main
git submodule update --init leanSpec
cd leanSpec && git fetch origin && git checkout main && git pull origin main && cd ..

# 2. Install Python dependencies and generate fixtures
cd leanSpec && uv sync && uv run fill --fork=devnet --clean -n auto && cd ..

# 3. Generate Zig test wrappers
zig build spectest:generate --summary all

# 4. Run spec tests
zig build spectest:run --summary all

# 5. Run zeam unit tests (catches regressions in supporting code)
zig build test --summary all

# 6. Run simulation tests (catches integration regressions)
zig build simtest --summary all
```

## What It Verifies

### Deterministic Invariants (MUST match exactly)

| Invariant | leanSpec (Python) | Zeam (Zig) |
|---|---|---|
| SSZ hash tree roots | `hash_tree_root()` via Pydantic | `hashTreeRoot()` via ssz.zig |
| State transitions | `process_slots()`, `process_block()` | `pkgs/state-transition/src/transition.zig` |
| Fork choice head | Fork choice store logic | `pkgs/node/src/forkchoice.zig` |
| Justification/Finalization | Epoch processing | `pkgs/state-transition/` + `pkgs/node/` |
| Validator shuffling | Committee computation | `pkgs/types/src/validator.zig` |

### Cross-Reference Map

| leanSpec Python Module | Zeam Zig Module |
|---|---|
| `src/lean_spec/` | `pkgs/state-transition/src/transition.zig` |
| `src/lean_spec/subspecs/ssz/` | `ssz.zig` (external dep via build.zig.zon) |
| `src/lean_spec/subspecs/containers/state/` | `pkgs/types/src/state.zig` |
| `src/lean_spec/subspecs/containers/block/` | `pkgs/types/src/block.zig` |
| `src/lean_spec/subspecs/containers/` (attestation) | `pkgs/types/src/attestation.zig` |
| `tests/consensus/` (state transition fillers) | `pkgs/spectest/src/runner/state_transition_runner.zig` |
| `tests/consensus/` (fork choice fillers) | `pkgs/spectest/src/runner/fork_choice_runner.zig` |

### How Fixtures Flow

```
leanSpec (Python)                          Zeam (Zig)
─────────────────                          ──────────
tests/consensus/test_*.py                  
    │                                      
    ▼ (uv run fill)                        
fixtures/consensus/json/                   
    │                                      
    ▼ (zig build spectest:generate)        
                                           pkgs/spectest/src/generated/index.zig
    │                                      
    ▼ (zig build spectest:run)             
                                           state_transition_runner.zig
                                           fork_choice_runner.zig
                                               │
                                               ▼
                                           PASS / FAIL
```

## When to Use

- Before any release
- After major leanSpec updates (new fork, new types, spec changes)
- After large refactors to `pkgs/state-transition/` or `pkgs/types/`
- When Anshal asks for a compliance report
- Periodically (weekly) to catch drift between leanSpec and zeam

## If Tests Fail

1. **Identify what changed**: `cd leanSpec && git log --oneline -10` — was the spec updated?
2. **Trace the divergence**: Which fixture failed? What's the expected vs actual output?
3. **leanSpec is authoritative**: Fix zeam's implementation to match, not the other way around
4. **Ping Anshal** if:
   - The spec change seems incorrect or ambiguous
   - A fundamental data structure mismatch exists
   - A new leanSpec feature has no zeam counterpart yet
   - You're unsure whether the spec or implementation is correct
