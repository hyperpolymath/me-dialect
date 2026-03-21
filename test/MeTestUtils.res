// SPDX-License-Identifier: PMPL-1.0-or-later
// SPDX-FileCopyrightText: 2026 hyperpolymath
//
// Me Language Test Utilities
// Helper functions for building AST nodes and asserting test results.

/// Build a minimal meNode with defaults for optional fields.
let makeNode = (
  ~nodeType: MeLanguage.meNodeType,
  ~children: option<array<MeLanguage.meNode>>=None,
  ~attributes: option<Dict.t<string>>=None,
  ~content: option<string>=None,
  (),
): MeLanguage.meNode => {
  nodeType,
  children,
  attributes,
  content,
}

/// Shorthand: wrap children in a Program node.
let program = (children: array<MeLanguage.meNode>): MeLanguage.meNode =>
  makeNode(~nodeType=Program, ~children=Some(children), ())

/// Shorthand: <say>text</say>
let say = (text: string): MeLanguage.meNode =>
  makeNode(~nodeType=Say, ~content=Some(text), ())

/// Shorthand: <remember name="n">value</remember>
let remember = (name: string, value: string): MeLanguage.meNode => {
  let attrs = Dict.make()
  attrs->Dict.set("name", name)
  makeNode(~nodeType=Remember, ~attributes=Some(attrs), ~content=Some(value), ())
}

/// Shorthand: <add to="var">amount</add>
let add = (varName: string, amount: string): MeLanguage.meNode => {
  let attrs = Dict.make()
  attrs->Dict.set("to", varName)
  makeNode(~nodeType=Add, ~attributes=Some(attrs), ~content=Some(amount), ())
}

/// Shorthand: <subtract from="var">amount</subtract>
let subtract = (varName: string, amount: string): MeLanguage.meNode => {
  let attrs = Dict.make()
  attrs->Dict.set("from", varName)
  makeNode(~nodeType=Subtract, ~attributes=Some(attrs), ~content=Some(amount), ())
}

/// Shorthand: <repeat times="n">children</repeat>
let repeat = (times: int, children: array<MeLanguage.meNode>): MeLanguage.meNode => {
  let attrs = Dict.make()
  attrs->Dict.set("times", Int.toString(times))
  makeNode(~nodeType=Repeat, ~attributes=Some(attrs), ~children=Some(children), ())
}

/// Shorthand: <stop/>
let stop = (): MeLanguage.meNode => makeNode(~nodeType=Stop, ())

/// Shorthand: <ask into="var">prompt</ask>
let ask = (varName: string, prompt: string): MeLanguage.meNode => {
  let attrs = Dict.make()
  attrs->Dict.set("into", varName)
  makeNode(~nodeType=Ask, ~attributes=Some(attrs), ~content=Some(prompt), ())
}

/// Shorthand: <when attr-is="val">children</when>
let when_ = (
  varName: string,
  expectedValue: string,
  children: array<MeLanguage.meNode>,
): MeLanguage.meNode => {
  let attrs = Dict.make()
  attrs->Dict.set(varName ++ "-is", expectedValue)
  makeNode(~nodeType=When, ~attributes=Some(attrs), ~children=Some(children), ())
}

/// Shorthand: <when attr-is-not="val">children</when>
let whenNot = (
  varName: string,
  notValue: string,
  children: array<MeLanguage.meNode>,
): MeLanguage.meNode => {
  let attrs = Dict.make()
  attrs->Dict.set(varName ++ "-is-not", notValue)
  makeNode(~nodeType=When, ~attributes=Some(attrs), ~children=Some(children), ())
}

/// Shorthand: <otherwise>children</otherwise>
let otherwise = (children: array<MeLanguage.meNode>): MeLanguage.meNode =>
  makeNode(~nodeType=Otherwise, ~children=Some(children), ())

/// Shorthand: <choose>children</choose>
let choose = (children: array<MeLanguage.meNode>): MeLanguage.meNode =>
  makeNode(~nodeType=Choose, ~children=Some(children), ())

/// Shorthand: <canvas width="w" height="h">children</canvas>
let canvas = (
  width: string,
  height: string,
  children: array<MeLanguage.meNode>,
): MeLanguage.meNode => {
  let attrs = Dict.make()
  attrs->Dict.set("width", width)
  attrs->Dict.set("height", height)
  makeNode(~nodeType=Canvas, ~attributes=Some(attrs), ~children=Some(children), ())
}

/// Shorthand: <shape type="t" ...props/>
let shape = (shapeType: string, props: array<(string, string)>): MeLanguage.meNode => {
  let attrs = Dict.make()
  attrs->Dict.set("type", shapeType)
  props->Array.forEach(((k, v)) => attrs->Dict.set(k, v))
  makeNode(~nodeType=Shape, ~attributes=Some(attrs), ())
}

/// Run a program and return the environment for inspection.
let runProgram = (prog: MeLanguage.meNode): MeLanguage.meEnvironment => {
  let env = MeLanguage.createMeEnvironment()
  MeLanguage.execute(prog, env)
  env
}

/// Assert that two values are equal; log a failure message if not.
let assertEqual = (actual: 'a, expected: 'a, label: string): bool => {
  if actual == expected {
    true
  } else {
    Console.error(`FAIL: ${label}`)
    false
  }
}

/// Simple test runner: name + function that returns pass/fail.
type testResult = {name: string, passed: bool}

let runTest = (name: string, fn: unit => bool): testResult => {
  let passed = try {
    fn()
  } catch {
  | _ => false
  }
  {name, passed}
}

/// Print a summary of test results and return exit code.
let summarise = (results: array<testResult>): int => {
  let total = results->Array.length
  let passed = results->Array.filter(r => r.passed)->Array.length
  let failed = total - passed

  Console.log("")
  Console.log(`--- Me Language Test Results ---`)
  results->Array.forEach(r => {
    let icon = if r.passed { "  PASS" } else { "  FAIL" }
    Console.log(`${icon}: ${r.name}`)
  })
  Console.log("")
  Console.log(`Total: ${Int.toString(total)}  Passed: ${Int.toString(passed)}  Failed: ${Int.toString(failed)}`)

  if failed > 0 {
    1
  } else {
    0
  }
}
