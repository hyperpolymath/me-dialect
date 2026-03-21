// SPDX-License-Identifier: PMPL-1.0-or-later
// SPDX-FileCopyrightText: 2026 hyperpolymath
//
// Me Language Tests: Edge Cases and Error Handling
// Covers missing attributes, unknown node types handled gracefully,
// program-level stopped state, and unusual but valid inputs.

open MeTestUtils

// -- Missing attributes ----------------------------------------------

let testRememberMissingName = () => {
  // Remember with content but no name attribute: should silently skip
  let attrs = Dict.make()
  // Deliberately not setting "name"
  let node = makeNode(
    ~nodeType=MeLanguage.Remember,
    ~attributes=Some(attrs),
    ~content=Some("orphan"),
    (),
  )
  let env = runProgram(program([node]))
  assertEqual(env.variables->Dict.toArray->Array.length, 0, "remember missing name attr")
}

let testAddMissingTo = () => {
  // Add with no "to" attribute: should silently skip
  let attrs = Dict.make()
  let node = makeNode(
    ~nodeType=MeLanguage.Add,
    ~attributes=Some(attrs),
    ~content=Some("5"),
    (),
  )
  let env = runProgram(program([remember("x", "10"), node]))
  assertEqual(
    env.variables->Dict.get("x"),
    Some(MeLanguage.Number(10.0)),
    "add missing to attr leaves vars unchanged",
  )
}

let testSubtractMissingFrom = () => {
  let attrs = Dict.make()
  let node = makeNode(
    ~nodeType=MeLanguage.Subtract,
    ~attributes=Some(attrs),
    ~content=Some("5"),
    (),
  )
  let env = runProgram(program([remember("x", "10"), node]))
  assertEqual(
    env.variables->Dict.get("x"),
    Some(MeLanguage.Number(10.0)),
    "subtract missing from attr leaves vars unchanged",
  )
}

let testAddNonNumericAmount = () => {
  // Add with non-numeric content: should silently skip
  let env = runProgram(program([remember("x", "10"), add("x", "abc")]))
  assertEqual(
    env.variables->Dict.get("x"),
    Some(MeLanguage.Number(10.0)),
    "add non-numeric amount unchanged",
  )
}

let testSubtractNonNumericAmount = () => {
  let env = runProgram(program([remember("x", "10"), subtract("x", "abc")]))
  assertEqual(
    env.variables->Dict.get("x"),
    Some(MeLanguage.Number(10.0)),
    "subtract non-numeric amount unchanged",
  )
}

// -- When/Otherwise executed standalone (outside choose) -------------

let testWhenStandalone = () => {
  // When node executed directly at program level does nothing
  let env = runProgram(
    program([when_("x", "1", [say("should not appear")])]),
  )
  assertEqual(env.output, [], "when standalone does nothing")
}

let testOtherwiseStandalone = () => {
  // Otherwise node executed directly at program level does nothing
  let env = runProgram(
    program([otherwise([say("should not appear")])]),
  )
  assertEqual(env.output, [], "otherwise standalone does nothing")
}

// -- Shape standalone (outside canvas) -------------------------------

let testShapeStandalone = () => {
  // Shape node executed directly at program level does nothing
  let node = shape("circle", [("r", "10")])
  let env = runProgram(program([node]))
  assertEqual(env.canvas, [], "shape standalone does nothing")
}

// -- Stopped state propagation ---------------------------------------

let testStoppedStatePropagates = () => {
  // After stop, even a new program-level node should not execute
  let env = runProgram(
    program([
      say("A"),
      stop(),
      say("B"),
      remember("x", "should-not-set"),
      repeat(5, [say("nope")]),
    ]),
  )
  assertEqual(env.output, ["A"], "stopped: only A appears") &&
  assertEqual(env.variables->Dict.get("x"), None, "stopped: var not set") &&
  assertEqual(env.stopped, true, "stopped: flag true")
}

let testStoppedBeforeProgram = () => {
  // If environment is already stopped, nothing executes
  let env = MeLanguage.createMeEnvironment()
  env.stopped = true
  MeLanguage.execute(program([say("invisible")]), env)
  assertEqual(env.output, [], "pre-stopped env produces no output")
}

// -- Variable interpolation edge cases -------------------------------

let testInterpolateSpecialChars = () => {
  let env = MeLanguage.createMeEnvironment()
  env.variables->Dict.set("greeting", MeLanguage.String("Hello <world> & \"friends\""))
  let result = MeLanguage.interpolate("{greeting}", env)
  assertEqual(
    result,
    "Hello <world> & \"friends\"",
    "interpolate preserves special chars",
  )
}

let testInterpolateNumberFormatting = () => {
  let env = MeLanguage.createMeEnvironment()
  env.variables->Dict.set("pi", MeLanguage.Number(3.14))
  let result = MeLanguage.interpolate("Pi is {pi}", env)
  // Float.toString may produce "3.14"
  assertEqual(
    result->String.startsWith("Pi is 3.14"),
    true,
    "interpolate number formatting",
  )
}

let testInterpolateHyphenatedVar = () => {
  let env = runProgram(
    program([
      remember("my-name", "Alex"),
      say("Hello {my-name}!"),
    ]),
  )
  assertEqual(env.output, ["Hello Alex!"], "interpolate hyphenated variable name")
}

// -- Canvas with non-shape children ----------------------------------

let testCanvasIgnoresNonShapeChildren = () => {
  // Canvas should only process Shape children
  let sayNode = say("not a shape")
  let canvasNode = canvas("100", "100", [sayNode])
  let env = runProgram(program([canvasNode]))
  assertEqual(env.canvas, [], "canvas ignores non-shape children")
}

// -- Complex combined program ----------------------------------------

let testComplexProgram = () => {
  let env = runProgram(
    program([
      remember("name", "Me"),
      remember("hp", "100"),
      remember("potions", "3"),
      say("Welcome, {name}!"),
      say("HP: {hp}, Potions: {potions}"),
      // Take damage
      subtract("hp", "30"),
      say("Ouch! HP now: {hp}"),
      // Use a potion
      choose([
        when_("potions", "0", [say("No potions left!")]),
        otherwise([
          add("hp", "20"),
          subtract("potions", "1"),
          say("Used potion! HP: {hp}, Potions: {potions}"),
        ]),
      ]),
    ]),
  )
  assertEqual(
    env.output,
    [
      "Welcome, Me!",
      "HP: 100, Potions: 3",
      "Ouch! HP now: 70",
      "Used potion! HP: 90, Potions: 2",
    ],
    "complex combined program",
  )
}

// -- Program node with no children -----------------------------------

let testProgramNullChildren = () => {
  let node = makeNode(~nodeType=MeLanguage.Program, ())
  let env = runProgram(node)
  assertEqual(env.output, [], "program with None children")
}

// -- Run all tests ---------------------------------------------------

let run = (): array<testResult> => {
  [
    runTest("Edge: remember missing name attr", testRememberMissingName),
    runTest("Edge: add missing to attr", testAddMissingTo),
    runTest("Edge: subtract missing from attr", testSubtractMissingFrom),
    runTest("Edge: add non-numeric amount", testAddNonNumericAmount),
    runTest("Edge: subtract non-numeric amount", testSubtractNonNumericAmount),
    runTest("Edge: when standalone (no-op)", testWhenStandalone),
    runTest("Edge: otherwise standalone (no-op)", testOtherwiseStandalone),
    runTest("Edge: shape standalone (no-op)", testShapeStandalone),
    runTest("Edge: stopped propagates", testStoppedStatePropagates),
    runTest("Edge: pre-stopped env", testStoppedBeforeProgram),
    runTest("Edge: interpolate special chars", testInterpolateSpecialChars),
    runTest("Edge: interpolate number format", testInterpolateNumberFormatting),
    runTest("Edge: interpolate hyphenated var", testInterpolateHyphenatedVar),
    runTest("Edge: canvas ignores non-shapes", testCanvasIgnoresNonShapeChildren),
    runTest("Edge: complex combined program", testComplexProgram),
    runTest("Edge: program with None children", testProgramNullChildren),
  ]
}
