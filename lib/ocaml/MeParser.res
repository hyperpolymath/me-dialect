// SPDX-License-Identifier: PMPL-1.0-or-later
// SPDX-FileCopyrightText: 2026 Jonathan D.A. Jewell <j.d.a.jewell@open.ac.uk>
//
// Me Language - Parser Module
//
// Parses Me-Dialect source code (XML/HTML-like tags) into the meNode AST.
// Designed for children ages 8-12, so error messages are friendly and
// the parser is intentionally lenient where possible.
//
// ## Supported tags
//
// - <say>text</say>              -- Print text (with {var} interpolation)
// - <remember name="x">val</remember>  -- Store a value
// - <ask into="x">prompt</ask>   -- Ask the user for input
// - <choose>...</choose>         -- Conditional branching
// - <when var-is="val">...</when>       -- Branch condition
// - <otherwise>...</otherwise>   -- Default branch
// - <repeat times="n">...</repeat>      -- Loop n times
// - <canvas width="w" height="h">...</canvas> -- Drawing surface
// - <shape type="t" .../>        -- Draw a shape (self-closing)
// - <add to="var">amount</add>   -- Add to a variable
// - <subtract from="var">amount</subtract> -- Subtract from a variable
// - <stop/>                      -- Stop execution
//
// ## Error handling
//
// Returns Result<meNode, string> with friendly error messages that tell
// the child what went wrong and how to fix it.

// ---------------------------------------------------------------------------
// Parser position tracking
// ---------------------------------------------------------------------------

/// Tracks where we are in the source string during parsing.
type parserState = {
  source: string,
  mutable pos: int,
}

/// Create a new parser state from source code.
let makeState = (source: string): parserState => {
  source,
  pos: 0,
}

/// Check whether we have reached the end of the source.
let isAtEnd = (state: parserState): bool => {
  state.pos >= state.source->String.length
}

/// Peek at the current character without advancing.
let peek = (state: parserState): option<string> => {
  if isAtEnd(state) {
    None
  } else {
    Some(state.source->String.charAt(state.pos))
  }
}

/// Advance the position by n characters.
let advance = (state: parserState, n: int): unit => {
  state.pos = state.pos + n
}

/// Check whether the source at the current position starts with a prefix.
let startsWith = (state: parserState, prefix: string): bool => {
  let remaining = state.source->String.sliceToEnd(~start=state.pos)
  remaining->String.startsWith(prefix)
}

/// Skip whitespace characters (spaces, tabs, newlines, carriage returns).
let skipWhitespace = (state: parserState): unit => {
  let len = state.source->String.length
  let continue = ref(true)
  while continue.contents && state.pos < len {
    let ch = state.source->String.charAt(state.pos)
    if ch == " " || ch == "\t" || ch == "\n" || ch == "\r" {
      state.pos = state.pos + 1
    } else {
      continue := false
    }
  }
}

/// Skip an HTML/XML comment: <!-- ... -->
let skipComment = (state: parserState): unit => {
  if startsWith(state, "<!--") {
    advance(state, 4)
    let len = state.source->String.length
    let found = ref(false)
    while !found.contents && state.pos < len - 2 {
      if (
        state.source->String.charAt(state.pos) == "-" &&
        state.source->String.charAt(state.pos + 1) == "-" &&
        state.source->String.charAt(state.pos + 2) == ">"
      ) {
        advance(state, 3)
        found := true
      } else {
        advance(state, 1)
      }
    }
    // If we never found -->, just skip to end
    if !found.contents {
      state.pos = len
    }
  }
}

/// Skip all whitespace and comments.
let skipWhitespaceAndComments = (state: parserState): unit => {
  let changed = ref(true)
  while changed.contents {
    let before = state.pos
    skipWhitespace(state)
    if startsWith(state, "<!--") {
      skipComment(state)
    }
    changed := state.pos != before
  }
}

// ---------------------------------------------------------------------------
// Tag name to node type mapping
// ---------------------------------------------------------------------------

/// Map a tag name (lowercase) to its AST node type.
/// Returns None for unrecognised tags, with a friendly hint.
let tagNameToNodeType = (tagName: string): option<MeLanguage.meNodeType> => {
  switch tagName->String.toLowerCase {
  | "say" => Some(Say)
  | "remember" => Some(Remember)
  | "ask" => Some(Ask)
  | "choose" => Some(Choose)
  | "when" => Some(When)
  | "otherwise" => Some(Otherwise)
  | "repeat" => Some(Repeat)
  | "canvas" => Some(Canvas)
  | "shape" => Some(Shape)
  | "add" => Some(Add)
  | "subtract" => Some(Subtract)
  | "stop" => Some(Stop)
  | _ => None
  }
}

/// Tags that are always self-closing (no children, no content).
let isSelfClosingTag = (tagName: string): bool => {
  switch tagName->String.toLowerCase {
  | "stop" | "shape" => true
  | _ => false
  }
}

/// Tags that can contain children (other tags inside them).
let isContainerTag = (tagName: string): bool => {
  switch tagName->String.toLowerCase {
  | "choose" | "when" | "otherwise" | "repeat" | "canvas" => true
  | _ => false
  }
}

// ---------------------------------------------------------------------------
// Attribute parsing
// ---------------------------------------------------------------------------

/// Parse a single attribute value: the part inside quotes.
/// Expects the current position to be just past the opening quote.
/// Handles both single and double quotes.
let parseQuotedValue = (state: parserState, quoteChar: string): result<string, string> => {
  let buf = ref("")
  let len = state.source->String.length
  let found = ref(false)
  while !found.contents && state.pos < len {
    let ch = state.source->String.charAt(state.pos)
    if ch == quoteChar {
      advance(state, 1)
      found := true
    } else {
      buf := buf.contents ++ ch
      advance(state, 1)
    }
  }
  if found.contents {
    Ok(buf.contents)
  } else {
    Error(
      `Oops! I found an attribute value that starts with ${quoteChar} but never ends. ` ++
      `Make sure to close it with another ${quoteChar}.`,
    )
  }
}

/// Parse a single attribute name (letters, digits, hyphens).
let parseAttrName = (state: parserState): string => {
  let buf = ref("")
  let len = state.source->String.length
  let continue = ref(true)
  while continue.contents && state.pos < len {
    let ch = state.source->String.charAt(state.pos)
    let code = state.source->String.charCodeAt(state.pos)
    // Allow: a-z, A-Z, 0-9, hyphen, underscore
    if (
      (code >= 97.0 && code <= 122.0) ||
      (code >= 65.0 && code <= 90.0) ||
      (code >= 48.0 && code <= 57.0) ||
      ch == "-" ||
      ch == "_"
    ) {
      buf := buf.contents ++ ch
      advance(state, 1)
    } else {
      continue := false
    }
  }
  buf.contents
}

/// Parse all attributes inside a tag's opening angle bracket.
/// Stops when it hits > or />.
/// Returns a Dict of name-value pairs, or an error.
let parseAttributes = (state: parserState): result<Dict.t<string>, string> => {
  let attrs = Dict.make()
  let error = ref(None)
  let done = ref(false)

  while !done.contents && error.contents == None {
    skipWhitespace(state)
    if isAtEnd(state) {
      done := true
    } else {
      let ch = peek(state)->Option.getOr("")
      if ch == ">" || ch == "/" {
        done := true
      } else {
        // Parse attribute name
        let name = parseAttrName(state)
        if name == "" {
          // Unexpected character in tag
          let badChar = peek(state)->Option.getOr("end of file")
          error :=
            Some(
              `Hmm, I found something unexpected (${badChar}) inside a tag. ` ++
              `Attribute names should use letters, numbers, and hyphens.`,
            )
        } else {
          skipWhitespace(state)
          // Expect =
          if peek(state) == Some("=") {
            advance(state, 1) // skip =
            skipWhitespace(state)
            // Expect quote
            let quoteChar = peek(state)->Option.getOr("")
            if quoteChar == "\"" || quoteChar == "'" {
              advance(state, 1) // skip opening quote
              switch parseQuotedValue(state, quoteChar) {
              | Ok(value) => attrs->Dict.set(name, value)
              | Error(e) => error := Some(e)
              }
            } else {
              error :=
                Some(
                  `The attribute "${name}" needs its value in quotes. ` ++
                  `Try: ${name}="value"`,
                )
            }
          } else {
            // Boolean attribute (no value) — treat as empty string
            attrs->Dict.set(name, "")
          }
        }
      }
    }
  }

  switch error.contents {
  | Some(e) => Error(e)
  | None => Ok(attrs)
  }
}

// ---------------------------------------------------------------------------
// Text content parsing
// ---------------------------------------------------------------------------

/// Parse text content between tags.
/// Stops when it hits a < character (start of another tag).
/// Trims leading/trailing whitespace from single-line content.
let parseTextContent = (state: parserState): string => {
  let buf = ref("")
  let len = state.source->String.length
  while state.pos < len && state.source->String.charAt(state.pos) != "<" {
    buf := buf.contents ++ state.source->String.charAt(state.pos)
    advance(state, 1)
  }
  // Trim whitespace but preserve content structure
  buf.contents->String.trim
}

// ---------------------------------------------------------------------------
// Tag parsing
// ---------------------------------------------------------------------------

/// Parse an opening tag: <tagName attr="value" ...> or <tagName .../>
/// Returns (tagName, attributes, isSelfClosing) or an error.
let parseOpenTag = (
  state: parserState,
): result<(string, Dict.t<string>, bool), string> => {
  // Expect <
  if peek(state) != Some("<") {
    Error(
      `I expected a tag to start with < but found something else. ` ++
      `All Me commands start with < like <say> or <remember>.`,
    )
  } else {
    advance(state, 1) // skip <

    // Check for closing tag (shouldn't happen here)
    if peek(state) == Some("/") {
      Error(`I found a closing tag where I expected an opening tag.`)
    } else {
      // Parse tag name
      let tagName = parseAttrName(state)
      if tagName == "" {
        Error(
          `I found a < but no tag name after it. ` ++
          `Did you mean to write a tag like <say> or <remember>?`,
        )
      } else {
        // Parse attributes
        switch parseAttributes(state) {
        | Error(e) => Error(e)
        | Ok(attrs) =>
          skipWhitespace(state)
          // Check for self-closing />
          if startsWith(state, "/>") {
            advance(state, 2)
            Ok((tagName, attrs, true))
          } else if peek(state) == Some(">") {
            advance(state, 1) // skip >
            Ok((tagName, attrs, false))
          } else {
            Error(
              `The <${tagName}> tag doesn't end properly. ` ++
              `It should end with > or /> (for self-closing tags like <stop/>).`,
            )
          }
        }
      }
    }
  }
}

/// Parse a closing tag: </tagName>
/// Returns the tag name or an error.
let parseCloseTag = (state: parserState): result<string, string> => {
  if !startsWith(state, "</") {
    Error(
      `I expected a closing tag (like </say>) but didn't find one. ` ++
      `Every opening tag needs a matching closing tag!`,
    )
  } else {
    advance(state, 2) // skip </
    let tagName = parseAttrName(state)
    if tagName == "" {
      Error(`I found </ but no tag name after it. Closing tags look like </say>.`)
    } else {
      skipWhitespace(state)
      if peek(state) == Some(">") {
        advance(state, 1) // skip >
        Ok(tagName)
      } else {
        Error(`The closing tag </${tagName}> is missing its >. It should be </${tagName}>.`)
      }
    }
  }
}

// ---------------------------------------------------------------------------
// Node parsing (recursive descent)
// ---------------------------------------------------------------------------

/// Parse a single Me node (tag with optional content/children).
/// This is the heart of the recursive descent parser.
let rec parseNode = (state: parserState): result<MeLanguage.meNode, string> => {
  skipWhitespaceAndComments(state)

  // Parse the opening tag
  switch parseOpenTag(state) {
  | Error(e) => Error(e)
  | Ok((tagName, attrs, selfClosing)) =>
    switch tagNameToNodeType(tagName) {
    | None =>
      // Build a list of known tags for the hint
      let knownTags = "say, remember, ask, choose, when, otherwise, repeat, canvas, shape, add, subtract, stop"
      Error(
        `I don't know the tag <${tagName}>. ` ++
        `The tags I understand are: ${knownTags}. ` ++
        `Check your spelling!`,
      )
    | Some(nodeType) =>
      if selfClosing || isSelfClosingTag(tagName) {
        // Self-closing tag: no content or children
        let attrDict = if attrs->Dict.toArray->Array.length > 0 {
          Some(attrs)
        } else {
          None
        }
        Ok({
          nodeType,
          children: None,
          attributes: attrDict,
          content: None,
        })
      } else if isContainerTag(tagName) {
        // Container tag: parse children until closing tag
        switch parseChildren(state, tagName) {
        | Error(e) => Error(e)
        | Ok(children) =>
          let attrDict = if attrs->Dict.toArray->Array.length > 0 {
            Some(attrs)
          } else {
            None
          }
          Ok({
            nodeType,
            children: Some(children),
            attributes: attrDict,
            content: None,
          })
        }
      } else {
        // Content tag: parse text content, then closing tag
        let textContent = parseTextContent(state)
        skipWhitespaceAndComments(state)
        switch parseCloseTag(state) {
        | Error(e) => Error(e)
        | Ok(closeName) =>
          if closeName->String.toLowerCase != tagName->String.toLowerCase {
            Error(
              `Oops! I found </${closeName}> but I was expecting </${tagName}>. ` ++
              `Make sure every tag is closed with the right name!`,
            )
          } else {
            let attrDict = if attrs->Dict.toArray->Array.length > 0 {
              Some(attrs)
            } else {
              None
            }
            let content = if textContent == "" {
              // For tags like <say></say>, give Some("") to match
              // what the interpreter expects for empty content
              Some("")
            } else {
              Some(textContent)
            }
            Ok({
              nodeType,
              children: None,
              attributes: attrDict,
              content,
            })
          }
        }
      }
    }
  }
}

/// Parse child nodes inside a container tag until we hit the closing tag.
and parseChildren = (
  state: parserState,
  parentTagName: string,
): result<array<MeLanguage.meNode>, string> => {
  let children = ref([])
  let error = ref(None)
  let done = ref(false)

  while !done.contents && error.contents == None {
    skipWhitespaceAndComments(state)

    if isAtEnd(state) {
      error :=
        Some(
          `I reached the end of the file but <${parentTagName}> was never closed! ` ++
          `Add </${parentTagName}> to close it.`,
        )
    } else if startsWith(state, "</") {
      // We found a closing tag -- parse it and check it matches
      switch parseCloseTag(state) {
      | Error(e) => error := Some(e)
      | Ok(closeName) =>
        if closeName->String.toLowerCase != parentTagName->String.toLowerCase {
          error :=
            Some(
              `I found </${closeName}> but I was expecting </${parentTagName}>. ` ++
              `Tags need to be closed in order!`,
            )
        } else {
          done := true
        }
      }
    } else if startsWith(state, "<") {
      // Another child tag
      switch parseNode(state) {
      | Error(e) => error := Some(e)
      | Ok(child) => children := children.contents->Array.concat([child])
      }
    } else {
      // Unexpected text content inside a container tag.
      // For containers like <choose>, text content doesn't make sense,
      // but we can skip whitespace and try again.
      let text = parseTextContent(state)
      if text != "" {
        error :=
          Some(
            `I found text "${text}" directly inside <${parentTagName}>, ` ++
            `but <${parentTagName}> should only contain other tags, not plain text.`,
          )
      }
    }
  }

  switch error.contents {
  | Some(e) => Error(e)
  | None => Ok(children.contents)
  }
}

// ---------------------------------------------------------------------------
// Public API
// ---------------------------------------------------------------------------

/// Parse a Me-Dialect source string into an AST.
///
/// The source should contain one or more top-level tags.
/// They are wrapped in a Program node automatically.
///
/// ## Example
///
/// ```rescript
/// let result = MeParser.parse("<say>Hello!</say>")
/// // Ok({ nodeType: Program, children: Some([...]), ... })
/// ```
///
/// ## Error handling
///
/// Returns Error(message) with a friendly description of what went wrong.
/// Error messages are written for children ages 8-12.
let parse = (source: string): result<MeLanguage.meNode, string> => {
  let state = makeState(source)
  let children = ref([])
  let error = ref(None)

  // Parse all top-level nodes
  while !isAtEnd(state) && error.contents == None {
    skipWhitespaceAndComments(state)

    if !isAtEnd(state) {
      if startsWith(state, "<") {
        switch parseNode(state) {
        | Error(e) => error := Some(e)
        | Ok(node) => children := children.contents->Array.concat([node])
        }
      } else {
        // Text at the top level -- skip whitespace, error on real text
        let text = parseTextContent(state)
        if text != "" {
          error :=
            Some(
              `I found text "${text}" outside of any tag. ` ++
              `All text needs to be inside a tag like <say>${text}</say>.`,
            )
        }
      }
    }
  }

  switch error.contents {
  | Some(e) => Error(e)
  | None =>
    Ok({
      nodeType: Program,
      children: Some(children.contents),
      attributes: None,
      content: None,
    })
  }
}

/// Parse a Me-Dialect source string, raising an exception on failure.
///
/// This is a convenience wrapper around `parse` for use in scripts and
/// the REPL where you want to fail fast on bad input.
let parseExn = (source: string): MeLanguage.meNode => {
  switch parse(source) {
  | Ok(node) => node
  | Error(msg) => panic(`Parse error: ${msg}`)
  }
}

/// Parse a Me-Dialect source string and return the result as a string.
///
/// On success, returns "Ok" (the AST can be retrieved via parse()).
/// On failure, returns the error message. Useful for validation tools.
let validate = (source: string): string => {
  switch parse(source) {
  | Ok(_) => "Ok"
  | Error(msg) => msg
  }
}
