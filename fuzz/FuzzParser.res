// SPDX-License-Identifier: PMPL-1.0-or-later
// Fuzz target for the Me-Dialect string-processing functions.
//
// Me-Dialect uses an AST-based interpreter (no separate lexer/parser
// for source text). The fuzzable surface is:
//   - parseValue: converts strings to meValue (String or Number)
//   - interpolate: replaces {varName} placeholders in strings
//   - execute: runs meNode programs
//
// Invariant: these functions must NEVER crash on ANY input.
//
// Run with:
//   deno task res:build && node fuzz/FuzzParser.res.js

open MeLanguage

// Simple pseudo-random number generator (LCG)
let seed = ref(Date.now()->Float.toInt->Int.mod(2147483647))
let nextRand = () => {
  seed := Int.mod(seed.contents * 1103515245 + 12345, 2147483647)
  abs(seed.contents)
}

// Generate a random string of up to maxLen characters
let randomString = (maxLen: int): string => {
  let len = Int.mod(nextRand(), maxLen + 1)
  let buf = ref("")
  for _ in 0 to len - 1 {
    let byte = Int.mod(nextRand(), 128) // ASCII range
    buf := buf.contents ++ String.fromCharCode(byte)
  }
  buf.contents
}

// Interesting test strings for parseValue
let valueStrings = [
  "0", "42", "-1", "3.14", "-0.5", "1e10", "NaN", "Infinity",
  "-Infinity", "", " ", "hello", "true", "false", "nil",
  "999999999999999999999", "0xFF", "0b1010",
  "\x00", "\n", "\t", "\"quoted\"", "{braces}",
]

// Interesting test strings for interpolate
let interpolateStrings = [
  "Hello {name}!", "{}", "{x}", "{{escaped}}", "{a}{b}{c}",
  "no vars here", "{missing_var}", "{}", "{ spaced }",
  "nested {a{b}c}", "{", "}", "{{", "}}", "{{}",
  "", " ", "\n{x}\n", "{0}", "{_}", "{a-b}",
]

let iterations = 100_000

let () = {
  Console.log(`Me-Dialect fuzzer: running ${Int.toString(iterations)} iterations`)

  // --- Fuzz parseValue ---
  Console.log("  Phase 1: fuzzing parseValue...")
  for i in 1 to div(iterations, 3) {
    // Mix fixed interesting strings with random ones
    let input = if Int.mod(nextRand(), 2) == 0 {
      let idx = Int.mod(nextRand(), Array.length(valueStrings))
      switch valueStrings->Array.get(idx) {
      | Some(s) => s
      | None => ""
      }
    } else {
      randomString(256)
    }

    // parseValue must never throw
    let value = parseValue(input)
    let _ = valueToString(value)

    if Int.mod(i, 10_000) == 0 {
      Console.log(`    ... ${Int.toString(i)} parseValue iterations`)
    }
  }

  // --- Fuzz interpolate ---
  Console.log("  Phase 2: fuzzing interpolate...")
  for i in 1 to div(iterations, 3) {
    let input = if Int.mod(nextRand(), 2) == 0 {
      let idx = Int.mod(nextRand(), Array.length(interpolateStrings))
      switch interpolateStrings->Array.get(idx) {
      | Some(s) => s
      | None => ""
      }
    } else {
      randomString(256)
    }

    // Create an environment with some variables set
    let env = createMeEnvironment()
    env.variables->Dict.set("name", String("Alice"))
    env.variables->Dict.set("x", Number(42.0))
    env.variables->Dict.set("a", String("A"))
    env.variables->Dict.set("b", String("B"))
    env.variables->Dict.set("c", String("C"))

    // interpolate must never throw
    let _ = interpolate(input, env)

    if Int.mod(i, 10_000) == 0 {
      Console.log(`    ... ${Int.toString(i)} interpolate iterations`)
    }
  }

  // --- Fuzz execute with random content ---
  Console.log("  Phase 3: fuzzing execute with random Say content...")
  for i in 1 to div(iterations, 3) {
    let content = randomString(256)
    let env = createMeEnvironment()
    env.variables->Dict.set("x", String("test"))

    // Build a simple program with random content
    let program: meNode = {
      nodeType: Program,
      children: Some([
        {nodeType: Say, children: None, attributes: None, content: Some(content)},
      ]),
      attributes: None,
      content: None,
    }

    // execute must never throw
    execute(program, env)

    if Int.mod(i, 10_000) == 0 {
      Console.log(`    ... ${Int.toString(i)} execute iterations`)
    }
  }

  Console.log(`Me-Dialect fuzzer: ${Int.toString(iterations)} iterations passed with no crashes`)
}
