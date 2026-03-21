// SPDX-License-Identifier: PMPL-1.0-or-later
// SPDX-FileCopyrightText: 2026 hyperpolymath
//
// Me Language Tests: Execution
// Covers say, remember, add, subtract, ask, stop, and canvas execution.

open MeTestUtils

// -- Environment -----------------------------------------------------

let testCreateEnvironment = () => {
  let env = MeLanguage.createMeEnvironment()
  assertEqual(env.output, [], "new env output empty") &&
  assertEqual(env.canvas, [], "new env canvas empty") &&
  assertEqual(env.stopped, false, "new env not stopped")
}

// -- Say -------------------------------------------------------------

let testSaySimple = () => {
  let env = runProgram(program([say("Hello!")]))
  assertEqual(env.output, ["Hello!"], "say simple output")
}

let testSayMultiple = () => {
  let env = runProgram(program([say("Line 1"), say("Line 2"), say("Line 3")]))
  assertEqual(env.output, ["Line 1", "Line 2", "Line 3"], "say multiple lines")
}

let testSayEmpty = () => {
  let env = runProgram(program([say("")]))
  assertEqual(env.output, [""], "say empty string")
}

let testSayWithInterpolation = () => {
  let env = runProgram(program([remember("pet", "cat"), say("My pet is a {pet}!")]))
  assertEqual(env.output, ["My pet is a cat!"], "say with variable interpolation")
}

let testSayNoContent = () => {
  // Say node with no content should produce no output
  let node = makeNode(~nodeType=MeLanguage.Say, ())
  let env = runProgram(program([node]))
  assertEqual(env.output, [], "say with no content produces nothing")
}

// -- Remember --------------------------------------------------------

let testRememberString = () => {
  let env = runProgram(program([remember("color", "blue")]))
  let v = env.variables->Dict.get("color")
  assertEqual(v, Some(MeLanguage.String("blue")), "remember stores string")
}

let testRememberNumber = () => {
  let env = runProgram(program([remember("age", "10")]))
  let v = env.variables->Dict.get("age")
  assertEqual(v, Some(MeLanguage.Number(10.0)), "remember stores number")
}

let testRememberOverwrite = () => {
  let env = runProgram(program([remember("x", "first"), remember("x", "second")]))
  let v = env.variables->Dict.get("x")
  assertEqual(v, Some(MeLanguage.String("second")), "remember overwrites previous")
}

let testRememberNoName = () => {
  // Remember with no name attribute should do nothing
  let node = makeNode(~nodeType=MeLanguage.Remember, ~content=Some("orphan"), ())
  let env = runProgram(program([node]))
  assertEqual(env.variables->Dict.toArray->Array.length, 0, "remember without name does nothing")
}

let testRememberNoContent = () => {
  // Remember with name but no content should do nothing
  let attrs = Dict.make()
  attrs->Dict.set("name", "x")
  let node = makeNode(~nodeType=MeLanguage.Remember, ~attributes=Some(attrs), ())
  let env = runProgram(program([node]))
  assertEqual(env.variables->Dict.get("x"), None, "remember without content does nothing")
}

// -- Add -------------------------------------------------------------

let testAddBasic = () => {
  let env = runProgram(program([remember("score", "0"), add("score", "10")]))
  assertEqual(env.variables->Dict.get("score"), Some(MeLanguage.Number(10.0)), "add basic")
}

let testAddMultiple = () => {
  let env = runProgram(
    program([remember("n", "5"), add("n", "3"), add("n", "2")]),
  )
  assertEqual(env.variables->Dict.get("n"), Some(MeLanguage.Number(10.0)), "add multiple times")
}

let testAddToNonexistent = () => {
  // Adding to a variable that doesn't exist should do nothing
  let env = runProgram(program([add("missing", "5")]))
  assertEqual(env.variables->Dict.get("missing"), None, "add to nonexistent var")
}

let testAddToString = () => {
  // Adding to a string variable should do nothing
  let env = runProgram(program([remember("name", "Alex"), add("name", "5")]))
  assertEqual(
    env.variables->Dict.get("name"),
    Some(MeLanguage.String("Alex")),
    "add to string var unchanged",
  )
}

let testAddNoAttributes = () => {
  // Add node with no attributes should do nothing (no crash)
  let node = makeNode(~nodeType=MeLanguage.Add, ~content=Some("5"), ())
  let env = runProgram(program([node]))
  assertEqual(env.output, [], "add with no attrs no crash")
}

// -- Subtract --------------------------------------------------------

let testSubtractBasic = () => {
  let env = runProgram(program([remember("lives", "3"), subtract("lives", "1")]))
  assertEqual(
    env.variables->Dict.get("lives"),
    Some(MeLanguage.Number(2.0)),
    "subtract basic",
  )
}

let testSubtractToNegative = () => {
  let env = runProgram(program([remember("x", "2"), subtract("x", "5")]))
  assertEqual(
    env.variables->Dict.get("x"),
    Some(MeLanguage.Number(-3.0)),
    "subtract to negative",
  )
}

let testSubtractFromNonexistent = () => {
  let env = runProgram(program([subtract("missing", "1")]))
  assertEqual(env.variables->Dict.get("missing"), None, "subtract from nonexistent")
}

// -- Ask -------------------------------------------------------------

let testAskStoresPlaceholder = () => {
  let env = runProgram(program([ask("answer", "What is your name?")]))
  assertEqual(
    env.variables->Dict.get("answer"),
    Some(MeLanguage.String("user-input")),
    "ask stores placeholder",
  )
}

let testAskNoInto = () => {
  // Ask with no into attribute should do nothing
  let node = makeNode(~nodeType=MeLanguage.Ask, ~content=Some("question?"), ())
  let env = runProgram(program([node]))
  assertEqual(env.variables->Dict.toArray->Array.length, 0, "ask without into does nothing")
}

// -- Stop ------------------------------------------------------------

let testStopHalts = () => {
  let env = runProgram(program([say("before"), stop(), say("after")]))
  assertEqual(env.output, ["before"], "stop halts - only before") &&
  assertEqual(env.stopped, true, "env marked stopped")
}

let testStopInRepeat = () => {
  let env = runProgram(
    program([repeat(100, [say("tick"), stop()])]),
  )
  assertEqual(env.output, ["tick"], "stop inside repeat halts loop")
}

// -- Canvas ----------------------------------------------------------

let testCanvasExecution = () => {
  let env = runProgram(
    program([
      canvas("200", "100", [
        shape("circle", [("cx", "50"), ("cy", "50"), ("r", "20")]),
        shape("rect", [("x", "10"), ("y", "10"), ("w", "30"), ("h", "30")]),
      ]),
    ]),
  )
  assertEqual(env.canvas->Array.length, 2, "canvas produces two commands")
}

let testCanvasShapeType = () => {
  let env = runProgram(
    program([canvas("100", "100", [shape("circle", [("r", "10")])])]),
  )
  let first = env.canvas->Array.get(0)
  switch first {
  | Some(cmd) => assertEqual(cmd.shape, "circle", "canvas shape type")
  | None => assertEqual(true, false, "canvas should have one command")
  }
}

let testCanvasEmpty = () => {
  let env = runProgram(program([canvas("100", "100", [])]))
  assertEqual(env.canvas->Array.length, 0, "empty canvas no commands")
}

// -- Empty program ---------------------------------------------------

let testEmptyProgramExecution = () => {
  let env = runProgram(program([]))
  assertEqual(env.output, [], "empty program no output") &&
  assertEqual(env.stopped, false, "empty program not stopped")
}

// -- Run all tests ---------------------------------------------------

let run = (): array<testResult> => {
  [
    runTest("Exec: create environment", testCreateEnvironment),
    runTest("Exec: say simple", testSaySimple),
    runTest("Exec: say multiple", testSayMultiple),
    runTest("Exec: say empty string", testSayEmpty),
    runTest("Exec: say with interpolation", testSayWithInterpolation),
    runTest("Exec: say no content", testSayNoContent),
    runTest("Exec: remember string", testRememberString),
    runTest("Exec: remember number", testRememberNumber),
    runTest("Exec: remember overwrite", testRememberOverwrite),
    runTest("Exec: remember no name", testRememberNoName),
    runTest("Exec: remember no content", testRememberNoContent),
    runTest("Exec: add basic", testAddBasic),
    runTest("Exec: add multiple", testAddMultiple),
    runTest("Exec: add to nonexistent", testAddToNonexistent),
    runTest("Exec: add to string var", testAddToString),
    runTest("Exec: add no attributes", testAddNoAttributes),
    runTest("Exec: subtract basic", testSubtractBasic),
    runTest("Exec: subtract to negative", testSubtractToNegative),
    runTest("Exec: subtract from nonexistent", testSubtractFromNonexistent),
    runTest("Exec: ask stores placeholder", testAskStoresPlaceholder),
    runTest("Exec: ask without into", testAskNoInto),
    runTest("Exec: stop halts", testStopHalts),
    runTest("Exec: stop in repeat", testStopInRepeat),
    runTest("Exec: canvas execution", testCanvasExecution),
    runTest("Exec: canvas shape type", testCanvasShapeType),
    runTest("Exec: canvas empty", testCanvasEmpty),
    runTest("Exec: empty program", testEmptyProgramExecution),
  ]
}
