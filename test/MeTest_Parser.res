// SPDX-License-Identifier: PMPL-1.0-or-later
// SPDX-FileCopyrightText: 2026 Jonathan D.A. Jewell <j.d.a.jewell@open.ac.uk>
//
// Me Language Tests: Parser
// Validates that the MeParser correctly transforms Me-Dialect source
// strings into the expected meNode AST.

open MeTestUtils

// ---------------------------------------------------------------------------
// Helper: parse and check Ok
// ---------------------------------------------------------------------------

/// Parse source and return Ok result, or fail the test.
let parseOk = (source: string): option<MeLanguage.meNode> => {
  switch MeParser.parse(source) {
  | Ok(node) => Some(node)
  | Error(_) => None
  }
}

/// Parse source and expect an Error result.
let parseErr = (source: string): bool => {
  switch MeParser.parse(source) {
  | Ok(_) => false
  | Error(_) => true
  }
}

// ---------------------------------------------------------------------------
// Empty / whitespace programs
// ---------------------------------------------------------------------------

let testEmptyString = () => {
  switch parseOk("") {
  | Some(node) =>
    assertEqual(node.nodeType, MeLanguage.Program, "empty string -> Program") &&
    assertEqual(node.children, Some([]), "empty string -> no children")
  | None => false
  }
}

let testWhitespaceOnly = () => {
  switch parseOk("   \n\t  ") {
  | Some(node) => assertEqual(node.children, Some([]), "whitespace -> no children")
  | None => false
  }
}

// ---------------------------------------------------------------------------
// <say> tag
// ---------------------------------------------------------------------------

let testParseSay = () => {
  switch parseOk("<say>Hello, world!</say>") {
  | Some(prog) =>
    let kids = prog.children->Option.getOr([])
    assertEqual(kids->Array.length, 1, "say: one child") && {
      let child = kids->Array.getUnsafe(0)
      assertEqual(child.nodeType, MeLanguage.Say, "say: nodeType") &&
      assertEqual(child.content, Some("Hello, world!"), "say: content")
    }
  | None => false
  }
}

let testParseSayInterpolation = () => {
  switch parseOk("<say>Hello {name}!</say>") {
  | Some(prog) =>
    let kids = prog.children->Option.getOr([])
    let child = kids->Array.getUnsafe(0)
    assertEqual(child.content, Some("Hello {name}!"), "say: preserves interpolation")
  | None => false
  }
}

let testParseSayEmpty = () => {
  switch parseOk("<say></say>") {
  | Some(prog) =>
    let kids = prog.children->Option.getOr([])
    let child = kids->Array.getUnsafe(0)
    assertEqual(child.content, Some(""), "say: empty content")
  | None => false
  }
}

// ---------------------------------------------------------------------------
// <remember> tag
// ---------------------------------------------------------------------------

let testParseRemember = () => {
  switch parseOk(`<remember name="color">blue</remember>`) {
  | Some(prog) =>
    let kids = prog.children->Option.getOr([])
    let child = kids->Array.getUnsafe(0)
    assertEqual(child.nodeType, MeLanguage.Remember, "remember: nodeType") &&
    assertEqual(child.content, Some("blue"), "remember: content") && {
      let nameAttr = switch child.attributes {
      | Some(attrs) => attrs->Dict.get("name")
      | None => None
      }
      assertEqual(nameAttr, Some("color"), "remember: name attribute")
    }
  | None => false
  }
}

// ---------------------------------------------------------------------------
// <ask> tag
// ---------------------------------------------------------------------------

let testParseAsk = () => {
  switch parseOk(`<ask into="answer">What is your name?</ask>`) {
  | Some(prog) =>
    let kids = prog.children->Option.getOr([])
    let child = kids->Array.getUnsafe(0)
    assertEqual(child.nodeType, MeLanguage.Ask, "ask: nodeType") &&
    assertEqual(child.content, Some("What is your name?"), "ask: prompt") && {
      let intoAttr = switch child.attributes {
      | Some(attrs) => attrs->Dict.get("into")
      | None => None
      }
      assertEqual(intoAttr, Some("answer"), "ask: into attribute")
    }
  | None => false
  }
}

// ---------------------------------------------------------------------------
// <add> and <subtract> tags
// ---------------------------------------------------------------------------

let testParseAdd = () => {
  switch parseOk(`<add to="score">10</add>`) {
  | Some(prog) =>
    let kids = prog.children->Option.getOr([])
    let child = kids->Array.getUnsafe(0)
    assertEqual(child.nodeType, MeLanguage.Add, "add: nodeType") &&
    assertEqual(child.content, Some("10"), "add: amount") && {
      let toAttr = switch child.attributes {
      | Some(attrs) => attrs->Dict.get("to")
      | None => None
      }
      assertEqual(toAttr, Some("score"), "add: to attribute")
    }
  | None => false
  }
}

let testParseSubtract = () => {
  switch parseOk(`<subtract from="lives">1</subtract>`) {
  | Some(prog) =>
    let kids = prog.children->Option.getOr([])
    let child = kids->Array.getUnsafe(0)
    assertEqual(child.nodeType, MeLanguage.Subtract, "subtract: nodeType") &&
    assertEqual(child.content, Some("1"), "subtract: amount") && {
      let fromAttr = switch child.attributes {
      | Some(attrs) => attrs->Dict.get("from")
      | None => None
      }
      assertEqual(fromAttr, Some("lives"), "subtract: from attribute")
    }
  | None => false
  }
}

// ---------------------------------------------------------------------------
// <stop/> self-closing tag
// ---------------------------------------------------------------------------

let testParseStop = () => {
  switch parseOk("<stop/>") {
  | Some(prog) =>
    let kids = prog.children->Option.getOr([])
    let child = kids->Array.getUnsafe(0)
    assertEqual(child.nodeType, MeLanguage.Stop, "stop: nodeType") &&
    assertEqual(child.children, None, "stop: no children") &&
    assertEqual(child.content, None, "stop: no content")
  | None => false
  }
}

let testParseStopWithSpaces = () => {
  switch parseOk("<stop />") {
  | Some(prog) =>
    let kids = prog.children->Option.getOr([])
    let child = kids->Array.getUnsafe(0)
    assertEqual(child.nodeType, MeLanguage.Stop, "stop with space: nodeType")
  | None => false
  }
}

// ---------------------------------------------------------------------------
// <repeat> container tag
// ---------------------------------------------------------------------------

let testParseRepeat = () => {
  switch parseOk(`<repeat times="3"><say>Hip hip hooray!</say></repeat>`) {
  | Some(prog) =>
    let kids = prog.children->Option.getOr([])
    let rep = kids->Array.getUnsafe(0)
    assertEqual(rep.nodeType, MeLanguage.Repeat, "repeat: nodeType") && {
      let timesAttr = switch rep.attributes {
      | Some(attrs) => attrs->Dict.get("times")
      | None => None
      }
      assertEqual(timesAttr, Some("3"), "repeat: times attribute") && {
        let repKids = rep.children->Option.getOr([])
        assertEqual(repKids->Array.length, 1, "repeat: one child") && {
          let child = repKids->Array.getUnsafe(0)
          assertEqual(child.nodeType, MeLanguage.Say, "repeat child: Say") &&
          assertEqual(child.content, Some("Hip hip hooray!"), "repeat child: content")
        }
      }
    }
  | None => false
  }
}

// ---------------------------------------------------------------------------
// <choose> / <when> / <otherwise>
// ---------------------------------------------------------------------------

let testParseChoose = () => {
  let source = `
    <choose>
      <when weather-is="sunny">
        <say>Go outside!</say>
      </when>
      <when weather-is="rainy">
        <say>Stay inside!</say>
      </when>
      <otherwise>
        <say>Check the weather!</say>
      </otherwise>
    </choose>
  `
  switch parseOk(source) {
  | Some(prog) =>
    let kids = prog.children->Option.getOr([])
    let choose = kids->Array.getUnsafe(0)
    assertEqual(choose.nodeType, MeLanguage.Choose, "choose: nodeType") && {
      let chooseKids = choose.children->Option.getOr([])
      assertEqual(chooseKids->Array.length, 3, "choose: 3 branches") && {
        let when1 = chooseKids->Array.getUnsafe(0)
        assertEqual(when1.nodeType, MeLanguage.When, "when1: nodeType") && {
          let condAttr = switch when1.attributes {
          | Some(attrs) => attrs->Dict.get("weather-is")
          | None => None
          }
          assertEqual(condAttr, Some("sunny"), "when1: weather-is attribute")
        } && {
          let otherwise = chooseKids->Array.getUnsafe(2)
          assertEqual(otherwise.nodeType, MeLanguage.Otherwise, "otherwise: nodeType")
        }
      }
    }
  | None => false
  }
}

// ---------------------------------------------------------------------------
// <canvas> / <shape>
// ---------------------------------------------------------------------------

let testParseCanvas = () => {
  let source = `
    <canvas width="400" height="300">
      <shape type="circle" cx="50" cy="50" r="25" />
      <shape type="rect" x="100" y="100" w="50" h="30"/>
    </canvas>
  `
  switch parseOk(source) {
  | Some(prog) =>
    let kids = prog.children->Option.getOr([])
    let canvas = kids->Array.getUnsafe(0)
    assertEqual(canvas.nodeType, MeLanguage.Canvas, "canvas: nodeType") && {
      let wAttr = switch canvas.attributes {
      | Some(attrs) => attrs->Dict.get("width")
      | None => None
      }
      assertEqual(wAttr, Some("400"), "canvas: width") && {
        let canvasKids = canvas.children->Option.getOr([])
        assertEqual(canvasKids->Array.length, 2, "canvas: 2 shapes") && {
          let shape1 = canvasKids->Array.getUnsafe(0)
          assertEqual(shape1.nodeType, MeLanguage.Shape, "shape1: nodeType") && {
            let typeAttr = switch shape1.attributes {
            | Some(attrs) => attrs->Dict.get("type")
            | None => None
            }
            assertEqual(typeAttr, Some("circle"), "shape1: type")
          }
        }
      }
    }
  | None => false
  }
}

// ---------------------------------------------------------------------------
// Multi-node programs
// ---------------------------------------------------------------------------

let testParseMultiNode = () => {
  let source = `
    <remember name="name">Alex</remember>
    <remember name="age">10</remember>
    <say>My name is {name} and I am {age} years old!</say>
  `
  switch parseOk(source) {
  | Some(prog) =>
    let kids = prog.children->Option.getOr([])
    assertEqual(kids->Array.length, 3, "multi: 3 children") && {
      let r1 = kids->Array.getUnsafe(0)
      let r2 = kids->Array.getUnsafe(1)
      let s = kids->Array.getUnsafe(2)
      assertEqual(r1.nodeType, MeLanguage.Remember, "multi child 0: Remember") &&
      assertEqual(r2.nodeType, MeLanguage.Remember, "multi child 1: Remember") &&
      assertEqual(s.nodeType, MeLanguage.Say, "multi child 2: Say")
    }
  | None => false
  }
}

// ---------------------------------------------------------------------------
// Full counting program (matches level 3 example)
// ---------------------------------------------------------------------------

let testParseCountingProgram = () => {
  let source = `
    <say>Let's count some sheep!</say>
    <remember name="sheep">0</remember>
    <repeat times="5">
      <add to="sheep">1</add>
      <say>{sheep} sheep jumping over the fence!</say>
    </repeat>
    <say>I counted {sheep} sheep! Time for sleep!</say>
  `
  switch parseOk(source) {
  | Some(prog) =>
    let kids = prog.children->Option.getOr([])
    assertEqual(kids->Array.length, 4, "counting: 4 top-level nodes") && {
      let rep = kids->Array.getUnsafe(2)
      assertEqual(rep.nodeType, MeLanguage.Repeat, "counting: repeat node") && {
        let repKids = rep.children->Option.getOr([])
        assertEqual(repKids->Array.length, 2, "counting: 2 children in repeat")
      }
    }
  | None => false
  }
}

// ---------------------------------------------------------------------------
// Comments
// ---------------------------------------------------------------------------

let testParseComments = () => {
  let source = `
    <!-- This is a comment -->
    <say>Hello!</say>
    <!-- Another comment -->
  `
  switch parseOk(source) {
  | Some(prog) =>
    let kids = prog.children->Option.getOr([])
    assertEqual(kids->Array.length, 1, "comments: only 1 real node") && {
      let child = kids->Array.getUnsafe(0)
      assertEqual(child.content, Some("Hello!"), "comments: correct content")
    }
  | None => false
  }
}

// ---------------------------------------------------------------------------
// Single-quoted attributes
// ---------------------------------------------------------------------------

let testParseSingleQuotedAttr = () => {
  switch parseOk("<remember name='color'>blue</remember>") {
  | Some(prog) =>
    let kids = prog.children->Option.getOr([])
    let child = kids->Array.getUnsafe(0)
    let nameAttr = switch child.attributes {
    | Some(attrs) => attrs->Dict.get("name")
    | None => None
    }
    assertEqual(nameAttr, Some("color"), "single-quoted attribute")
  | None => false
  }
}

// ---------------------------------------------------------------------------
// Error cases
// ---------------------------------------------------------------------------

let testErrorUnknownTag = () => {
  parseErr("<shout>Hello!</shout>")
}

let testErrorUnclosedTag = () => {
  parseErr("<say>Hello!")
}

let testErrorMismatchedClose = () => {
  parseErr("<say>Hello!</remember>")
}

let testErrorTextOutsideTag = () => {
  parseErr("Hello world")
}

let testErrorUnclosedAttribute = () => {
  parseErr(`<remember name="color>blue</remember>`)
}

// ---------------------------------------------------------------------------
// Parse and execute round-trip
// ---------------------------------------------------------------------------

let testParseAndExecuteSay = () => {
  switch MeParser.parse("<say>Round trip works!</say>") {
  | Ok(prog) =>
    let env = runProgram(prog)
    assertEqual(env.output, ["Round trip works!"], "parse+execute: say output")
  | Error(_) => false
  }
}

let testParseAndExecuteRememberSay = () => {
  let source = `
    <remember name="pet">cat</remember>
    <say>I have a {pet}!</say>
  `
  switch MeParser.parse(source) {
  | Ok(prog) =>
    let env = runProgram(prog)
    assertEqual(env.output, ["I have a cat!"], "parse+execute: interpolation")
  | Error(_) => false
  }
}

let testParseAndExecuteRepeat = () => {
  let source = `
    <repeat times="3">
      <say>Go!</say>
    </repeat>
  `
  switch MeParser.parse(source) {
  | Ok(prog) =>
    let env = runProgram(prog)
    assertEqual(env.output, ["Go!", "Go!", "Go!"], "parse+execute: repeat 3x")
  | Error(_) => false
  }
}

// ---------------------------------------------------------------------------
// Run all tests
// ---------------------------------------------------------------------------

let run = (): array<testResult> => {
  [
    runTest("Parser: empty string", testEmptyString),
    runTest("Parser: whitespace only", testWhitespaceOnly),
    runTest("Parser: <say> basic", testParseSay),
    runTest("Parser: <say> with interpolation", testParseSayInterpolation),
    runTest("Parser: <say> empty content", testParseSayEmpty),
    runTest("Parser: <remember>", testParseRemember),
    runTest("Parser: <ask>", testParseAsk),
    runTest("Parser: <add>", testParseAdd),
    runTest("Parser: <subtract>", testParseSubtract),
    runTest("Parser: <stop/>", testParseStop),
    runTest("Parser: <stop /> with space", testParseStopWithSpaces),
    runTest("Parser: <repeat>", testParseRepeat),
    runTest("Parser: <choose>/<when>/<otherwise>", testParseChoose),
    runTest("Parser: <canvas>/<shape>", testParseCanvas),
    runTest("Parser: multiple top-level nodes", testParseMultiNode),
    runTest("Parser: full counting program", testParseCountingProgram),
    runTest("Parser: comments are skipped", testParseComments),
    runTest("Parser: single-quoted attributes", testParseSingleQuotedAttr),
    runTest("Parser: error on unknown tag", testErrorUnknownTag),
    runTest("Parser: error on unclosed tag", testErrorUnclosedTag),
    runTest("Parser: error on mismatched close", testErrorMismatchedClose),
    runTest("Parser: error on text outside tag", testErrorTextOutsideTag),
    runTest("Parser: error on unclosed attribute", testErrorUnclosedAttribute),
    runTest("Parser: parse+execute <say>", testParseAndExecuteSay),
    runTest("Parser: parse+execute remember+say", testParseAndExecuteRememberSay),
    runTest("Parser: parse+execute <repeat>", testParseAndExecuteRepeat),
  ]
}
