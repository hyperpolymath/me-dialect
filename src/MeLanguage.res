// SPDX-License-Identifier: PMPL-1.0-or-later
// SPDX-FileCopyrightText: 2025 hyperpolymath
//
// Me Language - Main Entry Point
// An educational programming language for children (ages 8-12)

/**
 * Me Language Interpreter
 *
 * Me is a programming language designed for young learners:
 * - HTML-like syntax that feels familiar
 * - Visual feedback and immediate results
 * - Safe sandboxed execution
 * - Progressive complexity
 */

// Me Language AST Node Types
type meNodeType =
  | Program
  | Say
  | Remember
  | Ask
  | Choose
  | When
  | Otherwise
  | Repeat
  | Canvas
  | Shape
  | Add
  | Subtract
  | Stop

// Value types in Me
type meValue = String(string) | Number(float)

// Canvas command for drawing
type meCanvasCommand = {
  shape: string,
  props: Dict.t<string>,
}

// Me AST Node
type rec meNode = {
  nodeType: meNodeType,
  children: option<array<meNode>>,
  attributes: option<Dict.t<string>>,
  content: option<string>,
}

// Runtime environment for Me programs
type meEnvironment = {
  mutable variables: Dict.t<meValue>,
  mutable output: array<string>,
  mutable canvas: array<meCanvasCommand>,
  mutable stopped: bool,
}

// Create a new environment
let createMeEnvironment = (): meEnvironment => {
  variables: Dict.make(),
  output: [],
  canvas: [],
  stopped: false,
}

// Convert meValue to string
let valueToString = (value: meValue): string => {
  switch value {
  | String(s) => s
  | Number(n) => Float.toString(n)
  }
}

// Try to parse a string as a number
let parseValue = (s: string): meValue => {
  switch Float.fromString(s) {
  | Some(n) => Number(n)
  | None => String(s)
  }
}

// Interpolate variables in a string: "Hello {name}!" -> "Hello Alex!"
let interpolate = (text: string, env: meEnvironment): string => {
  let re = %re("/\{([^}]+)\}/g")
  text->String.unsafeReplaceRegExpBy0(re, (~match, ~offset as _, ~input as _) => {
    // Extract variable name from {varName}
    let varName = match->String.slice(~start=1, ~end=-1)->String.trim
    switch env.variables->Dict.get(varName) {
    | Some(value) => valueToString(value)
    | None => match
    }
  })
}

// Execute a Me program node
let rec execute = (node: meNode, env: meEnvironment): unit => {
  if env.stopped {
    ()
  } else {
    switch node.nodeType {
    | Program =>
      node.children
      ->Option.getOr([])
      ->Array.forEach(child => {
        if !env.stopped {
          execute(child, env)
        }
      })

    | Say =>
      switch node.content {
      | Some(content) =>
        let message = interpolate(content, env)
        env.output = env.output->Array.concat([message])
        Console.log(message)
      | None => ()
      }

    | Remember =>
      let name = node.attributes->Option.flatMap(attrs => attrs->Dict.get("name"))
      let value = node.content
      switch (name, value) {
      | (Some(n), Some(v)) => env.variables->Dict.set(n, parseValue(v))
      | _ => ()
      }

    | Ask =>
      let varName = node.attributes->Option.flatMap(attrs => attrs->Dict.get("into"))
      let prompt = node.content->Option.getOr("Enter a value:")
      switch varName {
      | Some(vn) =>
        Console.log("[Ask] " ++ interpolate(prompt, env))
        env.variables->Dict.set(vn, String("user-input"))
      | None => ()
      }

    | Choose => executeChoose(node, env)

    | When | Otherwise => ()

    | Repeat =>
      let times = node.attributes->Option.flatMap(attrs => attrs->Dict.get("times"))
      switch times {
      | Some(t) =>
        switch Int.fromString(t) {
        | Some(count) =>
          for _ in 0 to count - 1 {
            if !env.stopped {
              node.children
              ->Option.getOr([])
              ->Array.forEach(child => execute(child, env))
            }
          }
        | None => ()
        }
      | None => ()
      }

    | Add =>
      let varName = node.attributes->Option.flatMap(attrs => attrs->Dict.get("to"))
      let amount = node.content
      switch (varName, amount) {
      | (Some(vn), Some(amt)) =>
        switch (env.variables->Dict.get(vn), Float.fromString(amt)) {
        | (Some(Number(current)), Some(addAmt)) =>
          env.variables->Dict.set(vn, Number(current +. addAmt))
        | _ => ()
        }
      | _ => ()
      }

    | Subtract =>
      let varName = node.attributes->Option.flatMap(attrs => attrs->Dict.get("from"))
      let amount = node.content
      switch (varName, amount) {
      | (Some(vn), Some(amt)) =>
        switch (env.variables->Dict.get(vn), Float.fromString(amt)) {
        | (Some(Number(current)), Some(subAmt)) =>
          env.variables->Dict.set(vn, Number(current -. subAmt))
        | _ => ()
        }
      | _ => ()
      }

    | Canvas =>
      let width = node.attributes->Option.flatMap(attrs => attrs->Dict.get("width"))->Option.getOr("0")
      let height = node.attributes->Option.flatMap(attrs => attrs->Dict.get("height"))->Option.getOr("0")
      Console.log("[Canvas] Creating " ++ width ++ "x" ++ height ++ " canvas")
      node.children
      ->Option.getOr([])
      ->Array.forEach(child => {
        switch child.nodeType {
        | Shape =>
          let shapeType =
            child.attributes->Option.flatMap(attrs => attrs->Dict.get("type"))->Option.getOr("unknown")
          let props = child.attributes->Option.getOr(Dict.make())
          env.canvas = env.canvas->Array.concat([{shape: shapeType, props: props}])
          Console.log("[Canvas] Drawing " ++ shapeType)
        | _ => ()
        }
      })

    | Shape => ()

    | Stop => env.stopped = true
    }
  }
}

// Handle choose block execution
and executeChoose = (node: meNode, env: meEnvironment): unit => {
  let children = node.children->Option.getOr([])
  let rec processChildren = (remaining: array<meNode>): unit => {
    switch remaining->Array.get(0) {
    | None => ()
    | Some(child) =>
      switch child.nodeType {
      | When =>
        let conditionMet = checkWhenCondition(child, env)
        if conditionMet {
          child.children
          ->Option.getOr([])
          ->Array.forEach(whenChild => execute(whenChild, env))
        } else {
          processChildren(remaining->Array.sliceToEnd(~start=1))
        }
      | Otherwise =>
        child.children
        ->Option.getOr([])
        ->Array.forEach(otherwiseChild => execute(otherwiseChild, env))
      | _ => processChildren(remaining->Array.sliceToEnd(~start=1))
      }
    }
  }
  processChildren(children)
}

// Check if a when condition is met
and checkWhenCondition = (node: meNode, env: meEnvironment): bool => {
  switch node.attributes {
  | None => false
  | Some(attrs) =>
    attrs
    ->Dict.toArray
    ->Array.some(((key, expectedValue)) => {
      if key->String.endsWith("-is") {
        let varName = key->String.slice(~start=0, ~end=-3)
        switch env.variables->Dict.get(varName) {
        | Some(actualValue) => valueToString(actualValue) == expectedValue
        | None => false
        }
      } else if key->String.endsWith("-is-not") {
        let varName = key->String.slice(~start=0, ~end=-7)
        switch env.variables->Dict.get(varName) {
        | Some(actualValue) => valueToString(actualValue) != expectedValue
        | None => true
        }
      } else {
        false
      }
    })
  }
}

// Demo: Run a simple Me program
let demonstrateMeLanguage = (): unit => {
  Console.log("=== Me Language Demo ===\n")
  Console.log("Me is a programming language for children ages 8-12.\n")

  // Example 1: Say hello
  Console.log("Example 1: Hello World")
  let helloProgram: meNode = {
    nodeType: Program,
    children: Some([{nodeType: Say, children: None, attributes: None, content: Some("Hello! I am learning to code!")}]),
    attributes: None,
    content: None,
  }
  execute(helloProgram, createMeEnvironment())
  Console.log("")

  // Example 2: Variables
  Console.log("Example 2: Remembering Things")
  let nameAttrs = Dict.make()
  nameAttrs->Dict.set("name", "my-name")
  let ageAttrs = Dict.make()
  ageAttrs->Dict.set("name", "my-age")

  let variablesProgram: meNode = {
    nodeType: Program,
    children: Some([
      {nodeType: Remember, children: None, attributes: Some(nameAttrs), content: Some("Alex")},
      {nodeType: Remember, children: None, attributes: Some(ageAttrs), content: Some("10")},
      {
        nodeType: Say,
        children: None,
        attributes: None,
        content: Some("My name is {my-name} and I am {my-age} years old!"),
      },
    ]),
    attributes: None,
    content: None,
  }
  execute(variablesProgram, createMeEnvironment())
  Console.log("")

  // Example 3: Choices
  Console.log("Example 3: Making Choices")
  let weatherAttrs = Dict.make()
  weatherAttrs->Dict.set("name", "weather")
  let sunnyAttrs = Dict.make()
  sunnyAttrs->Dict.set("weather-is", "sunny")
  let rainyAttrs = Dict.make()
  rainyAttrs->Dict.set("weather-is", "rainy")

  let choicesProgram: meNode = {
    nodeType: Program,
    children: Some([
      {nodeType: Remember, children: None, attributes: Some(weatherAttrs), content: Some("sunny")},
      {
        nodeType: Choose,
        children: Some([
          {
            nodeType: When,
            children: Some([
              {nodeType: Say, children: None, attributes: None, content: Some("Let's go outside!")},
            ]),
            attributes: Some(sunnyAttrs),
            content: None,
          },
          {
            nodeType: When,
            children: Some([
              {nodeType: Say, children: None, attributes: None, content: Some("Let's read a book!")},
            ]),
            attributes: Some(rainyAttrs),
            content: None,
          },
          {
            nodeType: Otherwise,
            children: Some([
              {nodeType: Say, children: None, attributes: None, content: Some("What's the weather like?")},
            ]),
            attributes: None,
            content: None,
          },
        ]),
        attributes: None,
        content: None,
      },
    ]),
    attributes: None,
    content: None,
  }
  execute(choicesProgram, createMeEnvironment())
  Console.log("")

  // Example 4: Repeating
  Console.log("Example 4: Repeating Things")
  let repeatAttrs = Dict.make()
  repeatAttrs->Dict.set("times", "3")

  let repeatProgram: meNode = {
    nodeType: Program,
    children: Some([
      {
        nodeType: Repeat,
        children: Some([{nodeType: Say, children: None, attributes: None, content: Some("Hip hip hooray!")}]),
        attributes: Some(repeatAttrs),
        content: None,
      },
    ]),
    attributes: None,
    content: None,
  }
  execute(repeatProgram, createMeEnvironment())
  Console.log("")

  // Example 5: Counting
  Console.log("Example 5: Counting")
  let scoreAttrs = Dict.make()
  scoreAttrs->Dict.set("name", "score")
  let addAttrs = Dict.make()
  addAttrs->Dict.set("to", "score")
  let countRepeatAttrs = Dict.make()
  countRepeatAttrs->Dict.set("times", "3")

  let countingProgram: meNode = {
    nodeType: Program,
    children: Some([
      {nodeType: Remember, children: None, attributes: Some(scoreAttrs), content: Some("0")},
      {
        nodeType: Repeat,
        children: Some([
          {nodeType: Add, children: None, attributes: Some(addAttrs), content: Some("10")},
          {nodeType: Say, children: None, attributes: None, content: Some("Score is now: {score}")},
        ]),
        attributes: Some(countRepeatAttrs),
        content: None,
      },
    ]),
    attributes: None,
    content: None,
  }
  execute(countingProgram, createMeEnvironment())
  Console.log("")

  Console.log("=== Demo Complete ===")
  Console.log("\nMe makes programming fun and approachable for kids!")
}
