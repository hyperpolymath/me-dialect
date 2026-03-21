// SPDX-License-Identifier: PMPL-1.0-or-later
// SPDX-FileCopyrightText: 2026 hyperpolymath
//
// Me Language Tests: AST Construction
// Validates that all node types, attribute dictionaries, and
// self-closing (childless) nodes are built correctly.

open MeTestUtils

// -- Program structure -----------------------------------------------

let testEmptyProgram = () => {
  let node = program([])
  assertEqual(node.nodeType, MeLanguage.Program, "empty program nodeType") &&
  assertEqual(node.children, Some([]), "empty program children")
}

let testProgramWithChildren = () => {
  let node = program([say("Hello"), say("World")])
  let len = switch node.children {
  | Some(c) => c->Array.length
  | None => 0
  }
  assertEqual(len, 2, "program with two children")
}

// -- Say node --------------------------------------------------------

let testSayNode = () => {
  let node = say("Hello!")
  assertEqual(node.nodeType, MeLanguage.Say, "say nodeType") &&
  assertEqual(node.content, Some("Hello!"), "say content")
}

let testSayNodeNoAttributes = () => {
  let node = say("text")
  assertEqual(node.attributes, None, "say has no attributes")
}

let testSayNodeNoChildren = () => {
  let node = say("text")
  assertEqual(node.children, None, "say has no children")
}

// -- Remember node ---------------------------------------------------

let testRememberNode = () => {
  let node = remember("color", "blue")
  assertEqual(node.nodeType, MeLanguage.Remember, "remember nodeType") &&
  assertEqual(node.content, Some("blue"), "remember content")
}

let testRememberNodeAttribute = () => {
  let node = remember("color", "blue")
  let nameAttr = switch node.attributes {
  | Some(attrs) => attrs->Dict.get("name")
  | None => None
  }
  assertEqual(nameAttr, Some("color"), "remember name attribute")
}

// -- Add node --------------------------------------------------------

let testAddNode = () => {
  let node = add("score", "10")
  assertEqual(node.nodeType, MeLanguage.Add, "add nodeType") &&
  assertEqual(node.content, Some("10"), "add content")
}

let testAddNodeAttribute = () => {
  let node = add("score", "10")
  let toAttr = switch node.attributes {
  | Some(attrs) => attrs->Dict.get("to")
  | None => None
  }
  assertEqual(toAttr, Some("score"), "add to attribute")
}

// -- Subtract node ---------------------------------------------------

let testSubtractNode = () => {
  let node = subtract("lives", "1")
  assertEqual(node.nodeType, MeLanguage.Subtract, "subtract nodeType") &&
  assertEqual(node.content, Some("1"), "subtract content")
}

let testSubtractNodeAttribute = () => {
  let node = subtract("lives", "1")
  let fromAttr = switch node.attributes {
  | Some(attrs) => attrs->Dict.get("from")
  | None => None
  }
  assertEqual(fromAttr, Some("lives"), "subtract from attribute")
}

// -- Stop node (self-closing) ----------------------------------------

let testStopNode = () => {
  let node = stop()
  assertEqual(node.nodeType, MeLanguage.Stop, "stop nodeType") &&
  assertEqual(node.children, None, "stop no children") &&
  assertEqual(node.content, None, "stop no content") &&
  assertEqual(node.attributes, None, "stop no attributes")
}

// -- Ask node --------------------------------------------------------

let testAskNode = () => {
  let node = ask("answer", "What is your name?")
  assertEqual(node.nodeType, MeLanguage.Ask, "ask nodeType") &&
  assertEqual(node.content, Some("What is your name?"), "ask prompt")
}

let testAskNodeAttribute = () => {
  let node = ask("answer", "prompt")
  let intoAttr = switch node.attributes {
  | Some(attrs) => attrs->Dict.get("into")
  | None => None
  }
  assertEqual(intoAttr, Some("answer"), "ask into attribute")
}

// -- Repeat node -----------------------------------------------------

let testRepeatNode = () => {
  let node = repeat(5, [say("hi")])
  assertEqual(node.nodeType, MeLanguage.Repeat, "repeat nodeType")
}

let testRepeatNodeTimesAttr = () => {
  let node = repeat(5, [say("hi")])
  let timesAttr = switch node.attributes {
  | Some(attrs) => attrs->Dict.get("times")
  | None => None
  }
  assertEqual(timesAttr, Some("5"), "repeat times attribute")
}

let testRepeatNodeChildren = () => {
  let node = repeat(3, [say("a"), say("b")])
  let len = switch node.children {
  | Some(c) => c->Array.length
  | None => 0
  }
  assertEqual(len, 2, "repeat children count")
}

// -- Choose / When / Otherwise ---------------------------------------

let testChooseNode = () => {
  let node = choose([when_("x", "1", [say("one")]), otherwise([say("other")])])
  assertEqual(node.nodeType, MeLanguage.Choose, "choose nodeType")
}

let testWhenNodeAttribute = () => {
  let node = when_("color", "red", [say("red!")])
  let condAttr = switch node.attributes {
  | Some(attrs) => attrs->Dict.get("color-is")
  | None => None
  }
  assertEqual(condAttr, Some("red"), "when color-is attribute")
}

let testWhenNotNodeAttribute = () => {
  let node = whenNot("color", "blue", [say("not blue")])
  let condAttr = switch node.attributes {
  | Some(attrs) => attrs->Dict.get("color-is-not")
  | None => None
  }
  assertEqual(condAttr, Some("blue"), "whenNot color-is-not attribute")
}

let testOtherwiseNode = () => {
  let node = otherwise([say("default")])
  assertEqual(node.nodeType, MeLanguage.Otherwise, "otherwise nodeType")
}

// -- Canvas / Shape --------------------------------------------------

let testCanvasNode = () => {
  let node = canvas("400", "300", [shape("circle", [("cx", "50"), ("cy", "50"), ("r", "25")])])
  assertEqual(node.nodeType, MeLanguage.Canvas, "canvas nodeType")
}

let testCanvasAttributes = () => {
  let node = canvas("400", "300", [])
  let wAttr = switch node.attributes {
  | Some(attrs) => attrs->Dict.get("width")
  | None => None
  }
  let hAttr = switch node.attributes {
  | Some(attrs) => attrs->Dict.get("height")
  | None => None
  }
  assertEqual(wAttr, Some("400"), "canvas width") &&
  assertEqual(hAttr, Some("300"), "canvas height")
}

let testShapeNode = () => {
  let node = shape("rect", [("x", "10"), ("y", "20"), ("w", "50"), ("h", "30")])
  assertEqual(node.nodeType, MeLanguage.Shape, "shape nodeType")
}

let testShapeTypeAttribute = () => {
  let node = shape("circle", [("r", "10")])
  let tAttr = switch node.attributes {
  | Some(attrs) => attrs->Dict.get("type")
  | None => None
  }
  assertEqual(tAttr, Some("circle"), "shape type attribute")
}

// -- makeNode defaults -----------------------------------------------

let testMakeNodeDefaults = () => {
  let node = makeNode(~nodeType=MeLanguage.Say, ())
  assertEqual(node.children, None, "makeNode default children") &&
  assertEqual(node.attributes, None, "makeNode default attributes") &&
  assertEqual(node.content, None, "makeNode default content")
}

// -- Run all tests ---------------------------------------------------

let run = (): array<testResult> => {
  [
    runTest("AST: empty program", testEmptyProgram),
    runTest("AST: program with children", testProgramWithChildren),
    runTest("AST: say node", testSayNode),
    runTest("AST: say no attributes", testSayNodeNoAttributes),
    runTest("AST: say no children", testSayNodeNoChildren),
    runTest("AST: remember node", testRememberNode),
    runTest("AST: remember name attribute", testRememberNodeAttribute),
    runTest("AST: add node", testAddNode),
    runTest("AST: add to attribute", testAddNodeAttribute),
    runTest("AST: subtract node", testSubtractNode),
    runTest("AST: subtract from attribute", testSubtractNodeAttribute),
    runTest("AST: stop node (self-closing)", testStopNode),
    runTest("AST: ask node", testAskNode),
    runTest("AST: ask into attribute", testAskNodeAttribute),
    runTest("AST: repeat node", testRepeatNode),
    runTest("AST: repeat times attribute", testRepeatNodeTimesAttr),
    runTest("AST: repeat children", testRepeatNodeChildren),
    runTest("AST: choose node", testChooseNode),
    runTest("AST: when attribute (var-is)", testWhenNodeAttribute),
    runTest("AST: whenNot attribute (var-is-not)", testWhenNotNodeAttribute),
    runTest("AST: otherwise node", testOtherwiseNode),
    runTest("AST: canvas node", testCanvasNode),
    runTest("AST: canvas attributes", testCanvasAttributes),
    runTest("AST: shape node", testShapeNode),
    runTest("AST: shape type attribute", testShapeTypeAttribute),
    runTest("AST: makeNode defaults", testMakeNodeDefaults),
  ]
}
