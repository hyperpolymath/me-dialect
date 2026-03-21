// SPDX-License-Identifier: PMPL-1.0-or-later
// SPDX-FileCopyrightText: 2026 hyperpolymath
//
// Me Language Tests: Repetition (repeat with times)
// Covers repeat loops, counting within loops, nested repeats,
// and edge cases like zero iterations.

open MeTestUtils

// -- Basic repeat ----------------------------------------------------

let testRepeatThreeTimes = () => {
  let env = runProgram(program([repeat(3, [say("Go!")])]))
  assertEqual(env.output, ["Go!", "Go!", "Go!"], "repeat 3 times")
}

let testRepeatOnce = () => {
  let env = runProgram(program([repeat(1, [say("Once")])]))
  assertEqual(env.output, ["Once"], "repeat 1 time")
}

let testRepeatZeroTimes = () => {
  let env = runProgram(program([repeat(0, [say("Never")])]))
  assertEqual(env.output, [], "repeat 0 times produces nothing")
}

// -- Counting inside repeat ------------------------------------------

let testRepeatWithCounter = () => {
  let env = runProgram(
    program([
      remember("count", "0"),
      repeat(5, [add("count", "1")]),
      say("Count: {count}"),
    ]),
  )
  assertEqual(env.output, ["Count: 5"], "repeat with counter")
}

let testRepeatWithAdd = () => {
  let env = runProgram(
    program([
      remember("score", "0"),
      repeat(3, [add("score", "10")]),
    ]),
  )
  assertEqual(
    env.variables->Dict.get("score"),
    Some(MeLanguage.Number(30.0)),
    "repeat adds 10 three times = 30",
  )
}

let testRepeatWithSubtract = () => {
  let env = runProgram(
    program([
      remember("hp", "100"),
      repeat(4, [subtract("hp", "15")]),
    ]),
  )
  assertEqual(
    env.variables->Dict.get("hp"),
    Some(MeLanguage.Number(40.0)),
    "repeat subtracts 15 four times = 40",
  )
}

// -- Multiple children in repeat -------------------------------------

let testRepeatMultipleChildren = () => {
  let env = runProgram(
    program([
      remember("n", "0"),
      repeat(2, [
        add("n", "1"),
        say("Step {n}"),
      ]),
    ]),
  )
  assertEqual(env.output, ["Step 1", "Step 2"], "repeat with add and say")
}

// -- Nested repeat ---------------------------------------------------

let testNestedRepeat = () => {
  let env = runProgram(
    program([
      remember("total", "0"),
      repeat(3, [
        repeat(2, [add("total", "1")]),
      ]),
    ]),
  )
  assertEqual(
    env.variables->Dict.get("total"),
    Some(MeLanguage.Number(6.0)),
    "nested repeat 3x2 = 6",
  )
}

// -- Repeat with stop ------------------------------------------------

let testRepeatStopsEarly = () => {
  let env = runProgram(
    program([
      remember("i", "0"),
      repeat(10, [
        add("i", "1"),
        say("Iteration {i}"),
        // Stop after first iteration via a conditional
        choose([when_("i", "2", [stop()])]),
      ]),
    ]),
  )
  // Should run iterations 1 and 2, then stop
  assertEqual(
    env.output,
    ["Iteration 1", "Iteration 2"],
    "repeat stops early with stop",
  )
}

// -- Repeat with invalid times ---------------------------------------

let testRepeatNonNumericTimes = () => {
  // Non-numeric times attribute should be ignored
  let attrs = Dict.make()
  attrs->Dict.set("times", "abc")
  let node = makeNode(
    ~nodeType=MeLanguage.Repeat,
    ~attributes=Some(attrs),
    ~children=Some([say("never")]),
    (),
  )
  let env = runProgram(program([node]))
  assertEqual(env.output, [], "repeat with non-numeric times does nothing")
}

let testRepeatNoTimesAttribute = () => {
  // Repeat with no times attribute should do nothing
  let node = makeNode(
    ~nodeType=MeLanguage.Repeat,
    ~children=Some([say("never")]),
    (),
  )
  let env = runProgram(program([node]))
  assertEqual(env.output, [], "repeat without times attribute does nothing")
}

let testRepeatNoChildren = () => {
  // Repeat with times but no children should do nothing
  let env = runProgram(program([repeat(5, [])]))
  assertEqual(env.output, [], "repeat with no children does nothing")
}

// -- Large repeat ----------------------------------------------------

let testRepeatLarge = () => {
  let env = runProgram(
    program([
      remember("sum", "0"),
      repeat(100, [add("sum", "1")]),
    ]),
  )
  assertEqual(
    env.variables->Dict.get("sum"),
    Some(MeLanguage.Number(100.0)),
    "repeat 100 times counting",
  )
}

// -- Repeat with choose inside ---------------------------------------

let testRepeatWithChoose = () => {
  let env = runProgram(
    program([
      remember("n", "0"),
      repeat(4, [
        add("n", "1"),
        choose([
          when_("n", "1", [say("one")]),
          when_("n", "2", [say("two")]),
          otherwise([say("more")]),
        ]),
      ]),
    ]),
  )
  assertEqual(
    env.output,
    ["one", "two", "more", "more"],
    "repeat with choose inside",
  )
}

// -- Run all tests ---------------------------------------------------

let run = (): array<testResult> => {
  [
    runTest("Repeat: three times", testRepeatThreeTimes),
    runTest("Repeat: once", testRepeatOnce),
    runTest("Repeat: zero times", testRepeatZeroTimes),
    runTest("Repeat: with counter", testRepeatWithCounter),
    runTest("Repeat: with add", testRepeatWithAdd),
    runTest("Repeat: with subtract", testRepeatWithSubtract),
    runTest("Repeat: multiple children", testRepeatMultipleChildren),
    runTest("Repeat: nested", testNestedRepeat),
    runTest("Repeat: stops early", testRepeatStopsEarly),
    runTest("Repeat: non-numeric times", testRepeatNonNumericTimes),
    runTest("Repeat: no times attribute", testRepeatNoTimesAttribute),
    runTest("Repeat: no children", testRepeatNoChildren),
    runTest("Repeat: large (100)", testRepeatLarge),
    runTest("Repeat: with choose inside", testRepeatWithChoose),
  ]
}
