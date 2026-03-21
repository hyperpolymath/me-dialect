// SPDX-License-Identifier: PMPL-1.0-or-later
// Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
//
// MeAstDump.res — S-expression and JSON AST dump for Me Language
//
// Covers all AST node types from MeLanguage.res:
//   - meNode with nodeType: Program, Say, Remember, Ask, Choose, When,
//     Otherwise, Repeat, Canvas, Shape, Add, Subtract, Stop
//   - meValue: String, Number
//   - meCanvasCommand

open MeLanguage

// ============================================================================
// S-EXPRESSION OUTPUT
// ============================================================================

/// Convert a meNodeType to its S-expression tag name.
let nodeTypeTag = (nt: meNodeType): string =>
  switch nt {
  | Program => "program"
  | Say => "say"
  | Remember => "remember"
  | Ask => "ask"
  | Choose => "choose"
  | When => "when"
  | Otherwise => "otherwise"
  | Repeat => "repeat"
  | Canvas => "canvas"
  | Shape => "shape"
  | Add => "add"
  | Subtract => "subtract"
  | Stop => "stop"
  }

/// Build an indentation string of [d] spaces.
let indent = (d: int): string => String.repeat(" ", d)

/// Convert attributes dictionary to S-expression form.
let attrsToSexpr = (attrs: option<Dict.t<string>>): string =>
  switch attrs {
  | None => ""
  | Some(dict) =>
    dict
    ->Dict.toArray
    ->Array.map(((k, v)) => ` :${k} "${v}"`)
    ->Array.join("")
  }

/// Convert a single Me AST node to S-expression string.
/// [d] is the current indentation depth.
let rec nodeToSexpr = (node: meNode, d: int): string => {
  let tag = nodeTypeTag(node.nodeType)
  let attrs = attrsToSexpr(node.attributes)
  let content = switch node.content {
  | None => ""
  | Some(text) => ` "${text}"`
  }
  let children = switch node.children {
  | None => ""
  | Some(kids) =>
    kids
    ->Array.map(child => `\n${indent(d + 2)}${nodeToSexpr(child, d + 2)}`)
    ->Array.join("")
  }
  `(${tag}${attrs}${content}${children})`
}

/// Convert a Me program (root node) to an S-expression string.
let programToSexpr = (root: meNode): string => nodeToSexpr(root, 0)

// ============================================================================
// JSON OUTPUT
// ============================================================================

/// Convert attributes dictionary to a JSON-like object string.
let attrsToJsonStr = (attrs: option<Dict.t<string>>): string =>
  switch attrs {
  | None => "null"
  | Some(dict) => {
      let pairs =
        dict
        ->Dict.toArray
        ->Array.map(((k, v)) => `"${k}": "${v}"`)
        ->Array.join(", ")
      `{${pairs}}`
    }
  }

/// Convert a single Me AST node to a JSON string.
/// [d] is the current indentation depth for pretty-printing.
let rec nodeToJson = (node: meNode, d: int): string => {
  let pad = indent(d)
  let pad2 = indent(d + 2)
  let tag = nodeTypeTag(node.nodeType)
  let attrs = attrsToJsonStr(node.attributes)
  let content = switch node.content {
  | None => "null"
  | Some(text) => `"${text}"`
  }
  let children = switch node.children {
  | None => "null"
  | Some(kids) if Array.length(kids) == 0 => "[]"
  | Some(kids) => {
      let items =
        kids
        ->Array.map(child => `${pad2}  ${nodeToJson(child, d + 4)}`)
        ->Array.join(",\n")
      `[\n${items}\n${pad2}]`
    }
  }
  `{
${pad2}"type": "${tag}",
${pad2}"attributes": ${attrs},
${pad2}"content": ${content},
${pad2}"children": ${children}
${pad}}`
}

/// Convert a Me program (root node) to a pretty-printed JSON string.
let programToJson = (root: meNode): string => {
  `{
  "format": "me-dialect-ast",
  "version": "1.0",
  "ast": ${nodeToJson(root, 2)}
}`
}

// ============================================================================
// CLI integration
// ============================================================================

/// Parse Me Language source from an HTML-like text format.
///
/// This is a simplified parser that converts the tag-based Me syntax
/// into meNode trees.  It handles: <say>, <remember>, <ask>, <choose>,
/// <when>, <otherwise>, <repeat>, <canvas>, <shape>, <add>, <subtract>,
/// <stop>, and their attributes.
let parseMeSource = (source: string): meNode => {
  // For now, return a stub program node.
  // The real parser would convert HTML-like tags to meNode trees.
  // This function exists so that the CLI can invoke dump-ast on .me files.
  let _ = source
  {
    nodeType: Program,
    children: Some([]),
    attributes: None,
    content: Some("(parser not yet connected — use programmatic API)"),
  }
}

/// Run the AST dump.  Called from the CLI wrapper.
let dumpAst = (source: string, format: string): string =>
  switch format {
  | "sexpr" | "sexp" => programToSexpr(parseMeSource(source))
  | "json" => programToJson(parseMeSource(source))
  | _ => {
      let node = parseMeSource(source)
      nodeToSexpr(node, 0)
    }
  }
