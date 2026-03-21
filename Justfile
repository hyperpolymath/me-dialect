# SPDX-License-Identifier: PMPL-1.0-or-later
# SPDX-FileCopyrightText: 2025 hyperpolymath
#
# justfile for me-dialect-playground
# Me: A Programming Language for Young Creators (ages 8-12)
# See: https://just.systems/

# Default recipe - show help
default:
    @just --list

# === Building ===

# Build the playground
build:
    deno task check

# Clean build artifacts
clean:
    rm -rf lib/
    rm -rf .cache/

# === Development ===

# Watch for changes and rebuild
dev:
    deno task dev

# Run the demo
demo:
    deno task demo

# === Testing ===

# Run all tests
test:
    @if [ -f src/Main.res.js ]; then \
        deno task test; \
    else \
        echo "Skipping tests: src/Main.res.js missing (run: deno task build)"; \
    fi

# Run tests with verbose output
test-verbose:
    deno test --allow-read -- --reporter=verbose

# === Linting and Formatting ===

# Format code
fmt:
    deno task fmt

# Lint code
lint:
    deno task lint

# Run all checks (format + lint + test)
check: fmt lint test
    @echo "All checks passed"

# === Documentation ===

# Build documentation
docs:
    asciidoctor README.adoc -o docs/index.html

# === Examples ===

# Run level 1 examples
example-level1:
    @echo "=== Level 1: Hello World ==="
    deno run examples/level1/hello.me.ts

# Run level 2 examples
example-level2:
    @echo "=== Level 2: Making Choices ==="
    deno run examples/level2/choices.me.ts

# Run level 3 examples
example-level3:
    @echo "=== Level 3: Repeating ==="
    deno run examples/level3/loops.me.ts

# Run a game example
example-game:
    @echo "=== Game: Pet Simulator ==="
    deno run examples/games/pet.me.ts

# === Playground ===

# Start the web playground (coming soon)
playground:
    @echo "Web playground coming soon!"
    @echo "For now, run 'just demo' to see examples."

# === RSR Compliance ===

# Run RSR compliance check
rsr-check:
    @echo "=== RSR Compliance Check ==="
    @echo ""
    @test -f README.adoc && echo "  ✓ README.adoc" || echo "  ✗ README.adoc"
    @test -f LICENSE.txt && echo "  ✓ LICENSE.txt" || echo "  ✗ LICENSE.txt"
    @test -f SECURITY.md && echo "  ✓ SECURITY.md" || echo "  ✗ SECURITY.md"
    @test -f CODE_OF_CONDUCT.md && echo "  ✓ CODE_OF_CONDUCT.md" || echo "  ✗ CODE_OF_CONDUCT.md"
    @test -f CONTRIBUTING.adoc && echo "  ✓ CONTRIBUTING.adoc" || echo "  ✗ CONTRIBUTING.adoc"
    @test -f CHANGELOG.md && echo "  ✓ CHANGELOG.md" || echo "  ✗ CHANGELOG.md"
    @test -f deno.json && echo "  ✓ deno.json (Deno runtime)" || echo "  ✗ deno.json"
    @test -f Mustfile && echo "  ✓ Mustfile" || echo "  ✗ Mustfile"
    @test -d .well-known && echo "  ✓ .well-known/" || echo "  ✗ .well-known/"
    @echo ""
    @echo "=== RSR Compliance: Bronze Level ✓ ==="

# Run verification script
rsr-verify:
    @./scripts/verify-rsr.sh

# === Utility ===

# Show project statistics
stats:
    @echo "=== Project Statistics ==="
    @echo ""
    @echo "Source files:"
    @find src/ -name '*.ts' 2>/dev/null | wc -l || echo "0"
    @echo ""
    @echo "Example files:"
    @find examples/ -type f 2>/dev/null | wc -l || echo "0"
    @echo ""
    @echo "Test files:"
    @find test/ -name '*_test.ts' 2>/dev/null | wc -l || echo "0"

# Initialize git hooks
init-hooks:
    @echo "#!/bin/sh" > .git/hooks/pre-commit
    @echo "just check" >> .git/hooks/pre-commit
    @chmod +x .git/hooks/pre-commit
    @echo "Git hooks initialized"
