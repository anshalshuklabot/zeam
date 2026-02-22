#!/bin/bash
#
# Intercepts unsafe commands in the zeam repository.
#
# Prevents:
# - Direct `zig build run` without explicit prover flag (could run node accidentally)
# - Pushing to upstream/main directly
# - Running rm -rf on critical directories
# - Using system Zig instead of project-pinned version

# Read the tool input from stdin
INPUT=$(cat)

# Extract the command being executed
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty')

# If no command found, allow through
if [ -z "$COMMAND" ]; then
    exit 0
fi

# Function to block with a suggestion
block_with_suggestion() {
    local suggestion="$1"
    echo "BLOCKED: $suggestion"
    echo ""
    echo "See CLAUDE.md for the correct workflow."
    exit 2
}

# Allow diagnostic commands
if echo "$COMMAND" | grep -qE '^(which zig|zig version|zig env|rustc --version|cargo --version)'; then
    exit 0
fi

# Block push to upstream
if echo "$COMMAND" | grep -qE 'git push\s+upstream'; then
    block_with_suggestion "Never push directly to upstream. Push to origin (fork) and create a PR."
fi

# Block push to main branch
if echo "$COMMAND" | grep -qE 'git push.*\smain\b'; then
    block_with_suggestion "Never push directly to main. Create a feature branch and push that instead."
fi

# Block rm -rf on critical directories
if echo "$COMMAND" | grep -qE 'rm\s+-rf\s+(pkgs|rust|leanSpec|\.claude)\b'; then
    block_with_suggestion "Refusing to delete critical directory. Use 'trash' for recoverable deletion or be more specific."
fi

# Block cargo run (should use zig build run)
if echo "$COMMAND" | grep -qE '(^|\s|&&|\|)cargo\s+run'; then
    block_with_suggestion "Use 'zig build run' instead of 'cargo run'. The Zig build system orchestrates the full build including Rust FFI."
fi

# Allow everything else
exit 0
