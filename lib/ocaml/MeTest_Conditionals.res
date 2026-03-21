// SPDX-License-Identifier: PMPL-1.0-or-later
// SPDX-FileCopyrightText: 2026 hyperpolymath
//
// Me Language Tests: Conditional Logic (choose / when / otherwise)
// Covers choose blocks, when conditions with -is and -is-not,
// otherwise fallback, and edge cases.

open MeTestUtils

// -- Basic choose/when -----------------------------------------------

let testWhenMatchesFirst = () => {
  let env = runProgram(
    program([
      remember("animal", "dog"),
      choose([
        when_("animal", "dog", [say("Woof!")]),
        when_("animal", "cat", [say("Meow!")]),
      ]),
    ]),
  )
  assertEqual(env.output, ["Woof!"], "when matches first branch")
}

let testWhenMatchesSecond = () => {
  let env = runProgram(
    program([
      remember("animal", "cat"),
      choose([
        when_("animal", "dog", [say("Woof!")]),
        when_("animal", "cat", [say("Meow!")]),
      ]),
    ]),
  )
  assertEqual(env.output, ["Meow!"], "when matches second branch")
}

let testWhenNoMatch = () => {
  let env = runProgram(
    program([
      remember("animal", "fish"),
      choose([
        when_("animal", "dog", [say("Woof!")]),
        when_("animal", "cat", [say("Meow!")]),
      ]),
    ]),
  )
  assertEqual(env.output, [], "when no match produces no output")
}

// -- Otherwise fallback ----------------------------------------------

let testOtherwiseFallback = () => {
  let env = runProgram(
    program([
      remember("color", "green"),
      choose([
        when_("color", "red", [say("Red!")]),
        when_("color", "blue", [say("Blue!")]),
        otherwise([say("Something else!")]),
      ]),
    ]),
  )
  assertEqual(env.output, ["Something else!"], "otherwise fallback")
}

let testOtherwiseNotReachedWhenMatched = () => {
  let env = runProgram(
    program([
      remember("color", "red"),
      choose([
        when_("color", "red", [say("Red!")]),
        otherwise([say("Fallback")]),
      ]),
    ]),
  )
  assertEqual(env.output, ["Red!"], "otherwise not reached when matched")
}

// -- when with -is-not -----------------------------------------------

let testWhenIsNot = () => {
  let env = runProgram(
    program([
      remember("mood", "happy"),
      choose([
        whenNot("mood", "sad", [say("Not sad!")]),
        otherwise([say("Fallback")]),
      ]),
    ]),
  )
  assertEqual(env.output, ["Not sad!"], "when-is-not condition true")
}

let testWhenIsNotFalse = () => {
  let env = runProgram(
    program([
      remember("mood", "sad"),
      choose([
        whenNot("mood", "sad", [say("Not sad!")]),
        otherwise([say("Sad indeed")]),
      ]),
    ]),
  )
  assertEqual(env.output, ["Sad indeed"], "when-is-not condition false, falls to otherwise")
}

let testWhenIsNotUndefinedVar = () => {
  // Variable not set -- -is-not should return true (None != value)
  let env = runProgram(
    program([
      choose([
        whenNot("missing", "anything", [say("Missing is not anything!")]),
        otherwise([say("Fallback")]),
      ]),
    ]),
  )
  assertEqual(env.output, ["Missing is not anything!"], "when-is-not with undefined var")
}

// -- Multiple children in when ---------------------------------------

let testWhenMultipleChildren = () => {
  let env = runProgram(
    program([
      remember("weather", "sunny"),
      choose([
        when_("weather", "sunny", [
          say("It's sunny!"),
          say("Wear sunscreen!"),
          say("Have fun outside!"),
        ]),
      ]),
    ]),
  )
  assertEqual(
    env.output,
    ["It's sunny!", "Wear sunscreen!", "Have fun outside!"],
    "when executes all children",
  )
}

// -- Choose with numeric values --------------------------------------

let testWhenNumericValue = () => {
  let env = runProgram(
    program([
      remember("score", "100"),
      choose([
        when_("score", "100", [say("Perfect!")]),
        otherwise([say("Try again")]),
      ]),
    ]),
  )
  assertEqual(env.output, ["Perfect!"], "when with numeric value")
}

// -- Nested choose ---------------------------------------------------

let testNestedChoose = () => {
  let env = runProgram(
    program([
      remember("day", "saturday"),
      remember("weather", "sunny"),
      choose([
        when_("day", "saturday", [
          say("It's Saturday!"),
          choose([
            when_("weather", "sunny", [say("Go to the park!")]),
            otherwise([say("Stay home")]),
          ]),
        ]),
        otherwise([say("Workday")]),
      ]),
    ]),
  )
  assertEqual(
    env.output,
    ["It's Saturday!", "Go to the park!"],
    "nested choose both levels match",
  )
}

// -- Choose with no children -----------------------------------------

let testChooseEmpty = () => {
  let env = runProgram(program([choose([])]))
  assertEqual(env.output, [], "empty choose no output")
}

// -- When with no attributes -----------------------------------------

let testWhenNoAttributes = () => {
  let node = makeNode(
    ~nodeType=MeLanguage.When,
    ~children=Some([say("should not appear")]),
    (),
  )
  let env = runProgram(
    program([
      choose([node, otherwise([say("fallback")])]),
    ]),
  )
  assertEqual(env.output, ["fallback"], "when with no attributes falls through")
}

// -- First match wins ------------------------------------------------

let testFirstMatchWins = () => {
  let env = runProgram(
    program([
      remember("x", "a"),
      choose([
        when_("x", "a", [say("first")]),
        when_("x", "a", [say("second")]),
        otherwise([say("third")]),
      ]),
    ]),
  )
  assertEqual(env.output, ["first"], "first matching when wins")
}

// -- Run all tests ---------------------------------------------------

let run = (): array<testResult> => {
  [
    runTest("Cond: when matches first", testWhenMatchesFirst),
    runTest("Cond: when matches second", testWhenMatchesSecond),
    runTest("Cond: when no match", testWhenNoMatch),
    runTest("Cond: otherwise fallback", testOtherwiseFallback),
    runTest("Cond: otherwise not reached", testOtherwiseNotReachedWhenMatched),
    runTest("Cond: when-is-not true", testWhenIsNot),
    runTest("Cond: when-is-not false", testWhenIsNotFalse),
    runTest("Cond: when-is-not undefined var", testWhenIsNotUndefinedVar),
    runTest("Cond: when multiple children", testWhenMultipleChildren),
    runTest("Cond: when numeric value", testWhenNumericValue),
    runTest("Cond: nested choose", testNestedChoose),
    runTest("Cond: empty choose", testChooseEmpty),
    runTest("Cond: when no attributes", testWhenNoAttributes),
    runTest("Cond: first match wins", testFirstMatchWins),
  ]
}
