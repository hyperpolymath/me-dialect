// SPDX-License-Identifier: PMPL-1.0-or-later
// SPDX-FileCopyrightText: 2026 hyperpolymath
//
// Me Language Tests: Value Parsing and String Interpolation
// Covers parseValue, valueToString, and interpolate functions.

open MeTestUtils

// -- parseValue ------------------------------------------------------

let testParseValueInteger = () => {
  let v = MeLanguage.parseValue("42")
  assertEqual(v, MeLanguage.Number(42.0), "parseValue integer")
}

let testParseValueFloat = () => {
  let v = MeLanguage.parseValue("3.14")
  assertEqual(v, MeLanguage.Number(3.14), "parseValue float")
}

let testParseValueNegative = () => {
  let v = MeLanguage.parseValue("-7")
  assertEqual(v, MeLanguage.Number(-7.0), "parseValue negative")
}

let testParseValueZero = () => {
  let v = MeLanguage.parseValue("0")
  assertEqual(v, MeLanguage.Number(0.0), "parseValue zero")
}

let testParseValueString = () => {
  let v = MeLanguage.parseValue("hello")
  assertEqual(v, MeLanguage.String("hello"), "parseValue non-numeric string")
}

let testParseValueEmptyString = () => {
  let v = MeLanguage.parseValue("")
  assertEqual(v, MeLanguage.String(""), "parseValue empty string")
}

let testParseValueMixedText = () => {
  let v = MeLanguage.parseValue("abc123")
  assertEqual(v, MeLanguage.String("abc123"), "parseValue mixed text")
}

// -- valueToString ---------------------------------------------------

let testValueToStringStr = () => {
  let s = MeLanguage.valueToString(MeLanguage.String("hi"))
  assertEqual(s, "hi", "valueToString String")
}

let testValueToStringNum = () => {
  let s = MeLanguage.valueToString(MeLanguage.Number(5.0))
  assertEqual(s, "5", "valueToString Number(5)")
}

// -- interpolate -----------------------------------------------------

let testInterpolateSingleVar = () => {
  let env = MeLanguage.createMeEnvironment()
  env.variables->Dict.set("name", MeLanguage.String("Alex"))
  let result = MeLanguage.interpolate("Hello {name}!", env)
  assertEqual(result, "Hello Alex!", "interpolate single variable")
}

let testInterpolateMultipleVars = () => {
  let env = MeLanguage.createMeEnvironment()
  env.variables->Dict.set("name", MeLanguage.String("Alex"))
  env.variables->Dict.set("age", MeLanguage.Number(10.0))
  let result = MeLanguage.interpolate("I am {name}, age {age}.", env)
  assertEqual(result, "I am Alex, age 10.", "interpolate multiple variables")
}

let testInterpolateNoVars = () => {
  let env = MeLanguage.createMeEnvironment()
  let result = MeLanguage.interpolate("No variables here.", env)
  assertEqual(result, "No variables here.", "interpolate no variables")
}

let testInterpolateUnknownVar = () => {
  let env = MeLanguage.createMeEnvironment()
  let result = MeLanguage.interpolate("Hello {unknown}!", env)
  assertEqual(result, "Hello {unknown}!", "interpolate unknown variable kept")
}

let testInterpolateAdjacentVars = () => {
  let env = MeLanguage.createMeEnvironment()
  env.variables->Dict.set("a", MeLanguage.String("X"))
  env.variables->Dict.set("b", MeLanguage.String("Y"))
  let result = MeLanguage.interpolate("{a}{b}", env)
  assertEqual(result, "XY", "interpolate adjacent variables")
}

let testInterpolateEmptyString = () => {
  let env = MeLanguage.createMeEnvironment()
  let result = MeLanguage.interpolate("", env)
  assertEqual(result, "", "interpolate empty string")
}

let testInterpolateBracesNoVar = () => {
  let env = MeLanguage.createMeEnvironment()
  let result = MeLanguage.interpolate("Use {} for fun", env)
  // {} contains empty name which won't match any variable
  assertEqual(result == "Use {} for fun" || result == "Use  for fun", true, "interpolate empty braces")
}

// -- Run all tests ---------------------------------------------------

let run = (): array<testResult> => {
  [
    runTest("parseValue: integer", testParseValueInteger),
    runTest("parseValue: float", testParseValueFloat),
    runTest("parseValue: negative", testParseValueNegative),
    runTest("parseValue: zero", testParseValueZero),
    runTest("parseValue: string", testParseValueString),
    runTest("parseValue: empty string", testParseValueEmptyString),
    runTest("parseValue: mixed text", testParseValueMixedText),
    runTest("valueToString: String", testValueToStringStr),
    runTest("valueToString: Number", testValueToStringNum),
    runTest("interpolate: single var", testInterpolateSingleVar),
    runTest("interpolate: multiple vars", testInterpolateMultipleVars),
    runTest("interpolate: no vars", testInterpolateNoVars),
    runTest("interpolate: unknown var", testInterpolateUnknownVar),
    runTest("interpolate: adjacent vars", testInterpolateAdjacentVars),
    runTest("interpolate: empty string", testInterpolateEmptyString),
    runTest("interpolate: empty braces", testInterpolateBracesNoVar),
  ]
}
