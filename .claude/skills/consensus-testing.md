---
name: consensus-testing
description: "Specialized patterns for testing Beam Chain consensus and fork choice code with multiple validators. Use when writing tests involving validators, attestations, justification, finalization, or ZK proof verification."
---

# Consensus & Fork Choice Testing Patterns for Zeam

Testing consensus logic requires understanding how Beam Chain validators interact. Single-validator tests miss critical dynamics.

## Multi-Validator Test Design

**Minimum validator counts by scenario:**
- Basic consensus: 4 validators (allows 1 byzantine, maintains 2/3 honest)
- Justification threshold: 8+ validators (clean 2/3 math)
- ZK proof scenarios: 2+ validators (one proves, one verifies)

**Always vary the validator set composition:**
- All validators honest and online
- Supermajority honest (exactly 2/3 + 1)
- At justification threshold (exactly 2/3)
- Below threshold (2/3 - 1, should fail to justify)
- Mixed online/offline validators
- Validators with exhausted XMSS keys

## Beam Chain-Specific Scenarios

### XMSS Signature Testing
Unlike BLS (Beacon Chain), XMSS signatures are stateful — keys get exhausted:
- Validator signs with valid XMSS key state
- Validator attempts to sign after key exhaustion
- Aggregated XMSS signatures from multiple validators
- Mixed valid/invalid signatures in aggregation

```zig
test "aggregated XMSS verification rejects one invalid signature" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    // Create validators with XMSS key pairs
    var validators = try createTestValidators(allocator, 4);

    // Sign with 3 valid + 1 invalid
    var signatures = try createAggregatedSignatures(allocator, validators[0..3], block);
    signatures[3] = invalid_signature;

    try std.testing.expectError(
        error.InvalidBlockSignatures,
        stf.verifySignatures(allocator, &state, &signed_block, null),
    );
}
```

### ZK Proof Scenarios
- Valid state transition produces verifiable proof
- Invalid state transition proof is rejected
- Proof with wrong pre-state root
- Proof with tampered post-state root
- Dummy prover vs real prover behavior differences

## Fork Choice Scenarios

Zeam's forkchoice uses proto-array (`pkgs/node/src/forkchoice.zig`):

**Branch competition:**
```
         +-- B2a <- B3a (3 attestations)
genesis <- B1 -+
         +-- B2b <- B3b (4 attestations)  <- winner
```

**Critical scenarios:**
1. **Weight transitions**: Head changes as attestations arrive
2. **Deep re-orgs**: New branch overtakes after multiple slots
3. **Equivocation handling**: Same validator attests to conflicting heads
4. **Checkpoint boundaries**: Behavior at epoch transitions
5. **Finalization effects**: Finalized blocks cannot be re-orged
6. **Proto-array pruning**: Nodes below finalized checkpoint are removed

**Proto-array specific tests:**
- `bestChild` and `bestDescendant` update correctly
- `nextSibling` traversal works for multiple children
- Depth tracking from anchor root
- Weight propagation up the tree
- Confirmed/timeliness flags affect head selection

## Justification & Finalization

**Justification tests:**
- Exactly 2/3 participation → should justify
- One less than 2/3 → should NOT justify
- Validators with different effective balances (weighted voting)
- Justification with gaps (skip epochs)

**Finalization tests:**
- Two consecutive justified epochs → finalization
- Justified but not finalized (gap in justification)
- Cannot finalize without prior justification
- Finalized root propagation through proto-array

## Timing & Ordering

**Test event orderings:**
- Attestation before vs after block arrival
- Multiple attestations in same slot vs spread across slots
- Block arrives late (after attestation deadline)
- Out-of-order block delivery (child before parent — see `resources/parent-sync.md`)

**Slot boundary behavior:**
- Actions at slot start vs end (clock module: `pkgs/node/src/clock.zig`)
- Crossing epoch boundaries
- Genesis slot special cases

## Spec Test Fillers (leanSpec side)

If you need to create new test scenarios, the filler goes in leanSpec:

```python
# In leanSpec: tests/consensus/test_fork_choice.py
def test_competing_branches(fork_choice_test: ForkChoiceTestFiller) -> None:
    """Fork choice selects branch with higher attestation weight."""
    fork_choice_test(
        anchor_state=genesis_state,
        anchor_block=genesis_block,
        steps=[
            OnBlock(block=block_2a),
            OnBlock(block=block_2b),
            OnAttestation(attestation=att_for_2b_validator_0),
            OnAttestation(attestation=att_for_2b_validator_1),
            Checks(head=block_2b.hash_tree_root()),
        ],
    )
```

Then regenerate: `cd leanSpec && uv run fill --fork=devnet --clean -n auto`
Then verify zeam: `zig build spectest --summary all`

## Common Pitfalls

1. **Single validator tests** — Miss consensus dynamics entirely
2. **Always-honest scenarios** — Never test byzantine behavior
3. **Ignoring weights** — Validators may have different effective balances
4. **Fixed ordering** — Real networks have non-deterministic message arrival
5. **Skipping threshold edges** — The 2/3 boundary is where bugs hide
6. **Forgetting XMSS statefulness** — Unlike BLS, XMSS keys get consumed
7. **Ignoring ZK constraints** — State transition tests should verify RISC-V compatibility
8. **Testing implementation** — Test spec behavior, not internal proto-array state
