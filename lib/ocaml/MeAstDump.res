// SPDX-License-Identifier: PMPL-1.0-or-later
// SPDX-FileCopyrightText: 2026 Jonathan D.A. Jewell <j.d.a.jewell@open.ac.uk>
//
// Me Language - AST Dump Module
//
// Serialises a Me-Dialect AST to JSON or S-expression format.
// Used for debugging, tooling integration, and compiler pipeline inspection.
//
// ## Supported output formats
//
// - **JSON**: Standard JSON representation using Deno's built-in JSON.stringify,
//   suitable for machine consumption and piping to jq.
// - **S-expr**: Lisp-style S-expressions for human-readable inspection and
//   integration with Scheme/Guile tooling (e.g. STATE.scm pipelines).

/// Convert a meNodeType variant to its canonical string tag.
///
/// These tags match the HTML-like syntax used in .me.js example files
/// (e.g. "Program", "Say", "Remember").
let nodeTypeToString = (nt: MeLanguage.meNodeType): string => {
  switch nt {
  | Program => "Program"
  | Say => "Say"
  | Remember => "Remember"
  | Ask => "Ask"
  | Choose => "Choose"
  | When => "When"
  | Otherwise => "Otherwise"
  | Repeat => "Repeat"
  | Canvas => "Canvas"
  | Shape => "Shape"
  | Add => "Add"
  | Subtract => "Subtract"
  | Stop => "Stop"
  }
}

// ---------------------------------------------------------------------------
// JSON output
// ---------------------------------------------------------------------------

/// Convert a single meNode to a plain JS object suitable for JSON.stringify.
///
/// Recursively converts children. Attributes are emitted as a plain object
/// (or null). Content and children use null when absent.
let rec nodeToJsonObj = (node: MeLanguage.meNode): Dict.t<JSON.t> => {
  let obj = Dict.make()

  // nodeType -- always present
  obj->Dict.set("nodeType", JSON.Encode.string(nodeTypeToString(node.nodeType)))

  // content -- string or null
  switch node.content {
  | Some(c) => obj->Dict.set("content", JSON.Encode.string(c))
  | None => obj->Dict.set("content", JSON.Encode.null)
  }

  // attributes -- object or null
  switch node.attributes {
  | Some(attrs) => {
      let attrObj = Dict.make()
      attrs->Dict.toArray->Array.forEach(((k, v)) => {
        attrObj->Dict.set(k, JSON.Encode.string(v))
      })
      obj->Dict.set("attributes", JSON.Encode.object(attrObj))
    }
  | None => obj->Dict.set("attributes", JSON.Encode.null)
  }

  // children -- array or null
  switch node.children {
  | Some(kids) => {
      let childArr = kids->Array.map(child => JSON.Encode.object(nodeToJsonObj(child)))
      obj->Dict.set("children", JSON.Encode.array(childArr))
    }
  | None => obj->Dict.set("children", JSON.Encode.null)
  }

  obj
}

/// Serialise a Me AST node to a JSON string.
///
/// Uses 2-space indentation for readability.
let toJson = (node: MeLanguage.meNode): string => {
  let obj = nodeToJsonObj(node)
  JSON.stringifyAny(JSON.Encode.object(obj), ~space=2)->Option.getOr("{}")
}

// ---------------------------------------------------------------------------
// S-expression output
// ---------------------------------------------------------------------------

/// Escape a string value for S-expression output.
///
/// Wraps the string in double quotes and escapes internal quotes and
/// backslashes to produce valid S-expr string literals.
let escapeString = (s: string): string => {
  let escaped =
    s
    ->String.replaceAll("\\", "\\\\")
    ->String.replaceAll("\"", "\\\"")
    ->String.replaceAll("\n", "\\n")
    ->String.replaceAll("\r", "\\r")
    ->String.replaceAll("\t", "\\t")
  `"${escaped}"`
}

/// Produce an indentation string (2 spaces per level).
let indent = (depth: int): string => {
  let buf = ref("")
  for _ in 0 to depth - 1 {
    buf := buf.contents ++ "  "
  }
  buf.contents
}

/// Convert a single meNode to an S-expression string.
///
/// The output looks like:
/// ```scheme
/// (Program
///   (Say :content "Hello!")
///   (Remember :name "x" :content "42"))
/// ```
///
/// Attributes are emitted as keyword-value pairs (:key "value").
/// Children are nested sub-expressions.
let rec nodeToSexpr = (node: MeLanguage.meNode, depth: int): string => {
  let pad = indent(depth)
  let tag = nodeTypeToString(node.nodeType)

  // Collect attribute fragments
  let attrFragments = switch node.attributes {
  | Some(attrs) =>
    attrs
    ->Dict.toArray
    ->Array.map(((k, v)) => `:${k} ${escapeString(v)}`)
  | None => []
  }

  // Content as attribute-style fragment
  let contentFragment = switch node.content {
  | Some(c) => [`:content ${escapeString(c)}`]
  | None => []
  }

  let allFragments = Array.concat(attrFragments, contentFragment)

  // Children
  switch node.children {
  | Some(kids) if kids->Array.length > 0 => {
      let fragStr = if allFragments->Array.length > 0 {
        " " ++ allFragments->Array.join(" ")
      } else {
        ""
      }
      let childLines =
        kids->Array.map(child => nodeToSexpr(child, depth + 1))->Array.join("\n")
      `${pad}(${tag}${fragStr}\n${childLines})`
    }
  | _ => {
      let fragStr = if allFragments->Array.length > 0 {
        " " ++ allFragments->Array.join(" ")
      } else {
        ""
      }
      `${pad}(${tag}${fragStr})`
    }
  }
}

/// Serialise a Me AST node to an S-expression string.
///
/// Top-level call with depth 0.
let toSexpr = (node: MeLanguage.meNode): string => {
  nodeToSexpr(node, 0)
}

// ---------------------------------------------------------------------------
// Unified dump entry point
// ---------------------------------------------------------------------------

/// Supported output formats for AST dumps.
type dumpFormat =
  | Json
  | Sexpr

/// Parse a format string ("json" or "sexpr") into a dumpFormat.
///
/// Returns None for unrecognised format strings.
let parseFormat = (s: string): option<dumpFormat> => {
  switch s->String.toLowerCase {
  | "json" => Some(Json)
  | "sexpr" | "s-expr" | "sexp" => Some(Sexpr)
  | _ => None
  }
}

/// Dump a Me AST node in the specified format.
///
/// This is the main entry point called by the CLI tool (tools/ast_dump.js).
let dump = (node: MeLanguage.meNode, format: dumpFormat): string => {
  switch format {
  | Json => toJson(node)
  | Sexpr => toSexpr(node)
  }
}
