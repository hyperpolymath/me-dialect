// SPDX-License-Identifier: PMPL-1.0-or-later
//! Backend implementation for the Me-Dialect LSP server.
//!
//! Me-Dialect uses an XML/HTML-like syntax with tags such as `<say>`,
//! `<remember name="x">`, `<choose>`, `<when>`, `<otherwise>`, `<repeat>`,
//! `<canvas>`, `<shape>`, `<add>`, `<subtract>`, and `<stop>`.
//!
//! The LSP provides:
//! - Diagnostics for unclosed tags, unknown tags, and missing attributes
//! - Tag and attribute completion
//! - Hover documentation for all Me tags
//! - Go-to-definition for remembered variables
//! - Document symbols listing all tag blocks

use dashmap::DashMap;
use std::sync::Arc;
use tower_lsp::jsonrpc::Result;
use tower_lsp::lsp_types::*;
use tower_lsp::{Client, LanguageServer};

// ---------------------------------------------------------------------------
// Me-Dialect tag definitions
// ---------------------------------------------------------------------------

/// All known Me-Dialect tag names.
const ME_TAGS: &[&str] = &[
    "say", "remember", "ask", "choose", "when", "otherwise",
    "repeat", "canvas", "shape", "add", "subtract", "stop",
];

/// Self-closing tags (no closing tag needed).
const SELF_CLOSING_TAGS: &[&str] = &[
    "say", "remember", "ask", "add", "subtract", "stop", "shape",
];

/// Tags that require a closing tag.
const BLOCK_TAGS: &[&str] = &[
    "choose", "when", "otherwise", "repeat", "canvas",
];

/// Known attributes per tag: (tag, &[attribute]).
const TAG_ATTRIBUTES: &[(&str, &[&str])] = &[
    ("remember", &["name"]),
    ("ask", &["into"]),
    ("when", &["*-is", "*-is-not"]),
    ("repeat", &["times"]),
    ("canvas", &["width", "height"]),
    ("shape", &["type", "x", "y", "width", "height", "color", "radius"]),
    ("add", &["to"]),
    ("subtract", &["from"]),
];

/// Hover documentation for each tag.
fn tag_doc(tag: &str) -> Option<&'static str> {
    match tag {
        "say" => Some("**<say>** message **</say>**\n\nDisplay a message to the user.\nSupports variable interpolation: `{variable-name}`\n\n```html\n<say>Hello, {my-name}!</say>\n```"),
        "remember" => Some("**<remember name=\"var\">** value **</remember>**\n\nStore a value in a named variable.\n\n```html\n<remember name=\"my-age\">10</remember>\n```"),
        "ask" => Some("**<ask into=\"var\">** prompt **</ask>**\n\nAsk the user for input and store it.\n\n```html\n<ask into=\"answer\">What is your name?</ask>\n```"),
        "choose" => Some("**<choose>** ... **</choose>**\n\nConditional block containing `<when>` and `<otherwise>` branches.\n\n```html\n<choose>\n  <when weather-is=\"sunny\"><say>Go outside!</say></when>\n  <otherwise><say>Stay in!</say></otherwise>\n</choose>\n```"),
        "when" => Some("**<when** condition **>** ... **</when>**\n\nConditional branch inside `<choose>`.\nAttributes use `variable-is` or `variable-is-not` patterns.\n\n```html\n<when score-is=\"100\"><say>Perfect!</say></when>\n```"),
        "otherwise" => Some("**<otherwise>** ... **</otherwise>**\n\nDefault branch inside `<choose>` (runs if no `<when>` matches)."),
        "repeat" => Some("**<repeat times=\"n\">** ... **</repeat>**\n\nRepeat the body `n` times.\n\n```html\n<repeat times=\"3\">\n  <say>Hip hip hooray!</say>\n</repeat>\n```"),
        "canvas" => Some("**<canvas width=\"w\" height=\"h\">** ... **</canvas>**\n\nCreate a drawing canvas.\n\n```html\n<canvas width=\"400\" height=\"300\">\n  <shape type=\"circle\" x=\"200\" y=\"150\" radius=\"50\" color=\"blue\" />\n</canvas>\n```"),
        "shape" => Some("**<shape type=\"...\" ... />**\n\nDraw a shape on a canvas.\n\nAttributes: `type`, `x`, `y`, `width`, `height`, `radius`, `color`"),
        "add" => Some("**<add to=\"var\">** amount **</add>**\n\nAdd a number to a variable.\n\n```html\n<add to=\"score\">10</add>\n```"),
        "subtract" => Some("**<subtract from=\"var\">** amount **</subtract>**\n\nSubtract a number from a variable.\n\n```html\n<subtract from=\"lives\">1</subtract>\n```"),
        "stop" => Some("**<stop/>**\n\nStop program execution immediately."),
        _ => None,
    }
}

// ---------------------------------------------------------------------------
// Document state
// ---------------------------------------------------------------------------

struct DocumentState {
    source: String,
    /// Definitions: (name, line, col, kind_label).
    definitions: Vec<(String, u32, u32, &'static str)>,
    /// Diagnostics from analysis.
    diagnostics: Vec<Diagnostic>,
}

impl DocumentState {
    fn new(source: String) -> Self {
        let mut state = Self {
            source,
            definitions: Vec::new(),
            diagnostics: Vec::new(),
        };
        state.analyze();
        state
    }

    fn word_at(&self, line: u32, col: u32) -> Option<String> {
        let line_str = self.source.lines().nth(line as usize)?;
        let c = col as usize;
        if c > line_str.len() {
            return None;
        }

        // For XML, include hyphens and angle brackets context
        let start = line_str[..c]
            .rfind(|ch: char| !ch.is_alphanumeric() && ch != '_' && ch != '-')
            .map(|i| i + 1)
            .unwrap_or(0);
        let end = line_str[c..]
            .find(|ch: char| !ch.is_alphanumeric() && ch != '_' && ch != '-')
            .map(|i| c + i)
            .unwrap_or(line_str.len());

        if start < end {
            Some(line_str[start..end].to_string())
        } else {
            None
        }
    }

    /// Check if cursor is inside a tag opening (after `<`).
    fn is_inside_tag_open(&self, line: u32, col: u32) -> bool {
        if let Some(line_str) = self.source.lines().nth(line as usize) {
            let prefix = &line_str[..col.min(line_str.len() as u32) as usize];
            // Check if there's an unclosed `<` before cursor
            let last_open = prefix.rfind('<');
            let last_close = prefix.rfind('>');
            match (last_open, last_close) {
                (Some(o), Some(c)) => o > c,
                (Some(_), None) => true,
                _ => false,
            }
        } else {
            false
        }
    }

    /// Check if cursor is inside a tag's attribute area.
    fn is_inside_attributes(&self, line: u32, col: u32) -> Option<String> {
        if let Some(line_str) = self.source.lines().nth(line as usize) {
            let prefix = &line_str[..col.min(line_str.len() as u32) as usize];
            if let Some(open_pos) = prefix.rfind('<') {
                let after_open = &prefix[open_pos + 1..];
                // Skip closing tags
                if after_open.starts_with('/') {
                    return None;
                }
                // Extract tag name
                let tag_name = after_open
                    .split(|c: char| !c.is_alphanumeric() && c != '-')
                    .next()
                    .unwrap_or("");
                if !tag_name.is_empty() && after_open.len() > tag_name.len() {
                    return Some(tag_name.to_string());
                }
            }
        }
        None
    }

    // -----------------------------------------------------------------------
    // Analysis
    // -----------------------------------------------------------------------

    fn analyze(&mut self) {
        self.definitions.clear();
        self.diagnostics.clear();

        let mut tag_stack: Vec<(String, u32)> = Vec::new(); // (tag_name, line)

        for (line_idx, line) in self.source.lines().enumerate() {
            let ln = line_idx as u32;
            let trimmed = line.trim();

            // Find opening tags: <tagname ...>
            let mut search = trimmed;
            while let Some(open_pos) = search.find('<') {
                let after = &search[open_pos + 1..];

                // Skip closing tags
                if after.starts_with('/') {
                    // Closing tag: </tagname>
                    let close_name = after[1..]
                        .split(|c: char| !c.is_alphanumeric() && c != '-')
                        .next()
                        .unwrap_or("");
                    if !close_name.is_empty() {
                        // Pop from stack
                        if let Some(pos) = tag_stack.iter().rposition(|(n, _)| n == close_name) {
                            tag_stack.remove(pos);
                        } else {
                            self.diagnostics.push(Diagnostic {
                                range: Range {
                                    start: Position::new(ln, 0),
                                    end: Position::new(ln, line.len() as u32),
                                },
                                severity: Some(DiagnosticSeverity::ERROR),
                                source: Some("me-dialect-lsp".into()),
                                message: format!("Closing tag `</{}>` without matching opening tag", close_name),
                                ..Default::default()
                            });
                        }
                    }
                    search = if let Some(end) = after.find('>') {
                        &after[end + 1..]
                    } else {
                        ""
                    };
                    continue;
                }

                // Opening tag
                let tag_name = after
                    .split(|c: char| !c.is_alphanumeric() && c != '-')
                    .next()
                    .unwrap_or("");

                if tag_name.is_empty() {
                    search = &after[1..];
                    continue;
                }

                // Check if self-closing (ends with />)
                let tag_end = after.find('>');
                let is_self_closing = tag_end
                    .map(|end| after[..end].ends_with('/'))
                    .unwrap_or(false);

                // Check for unknown tags
                if !ME_TAGS.contains(&tag_name) {
                    self.diagnostics.push(Diagnostic {
                        range: Range {
                            start: Position::new(ln, 0),
                            end: Position::new(ln, line.len() as u32),
                        },
                        severity: Some(DiagnosticSeverity::WARNING),
                        source: Some("me-dialect-lsp".into()),
                        message: format!("Unknown Me tag: `<{}>`", tag_name),
                        ..Default::default()
                    });
                }

                // Record definitions
                let col = line.find(tag_name).unwrap_or(0) as u32;
                match tag_name {
                    "remember" => {
                        // Extract name attribute for variable definition
                        if let Some(name_val) = extract_attribute(after, "name") {
                            self.definitions.push((name_val, ln, col, "Variable"));
                        } else {
                            self.diagnostics.push(Diagnostic {
                                range: Range {
                                    start: Position::new(ln, 0),
                                    end: Position::new(ln, line.len() as u32),
                                },
                                severity: Some(DiagnosticSeverity::WARNING),
                                source: Some("me-dialect-lsp".into()),
                                message: "`<remember>` requires a `name` attribute".into(),
                                ..Default::default()
                            });
                        }
                    }
                    "ask" => {
                        if let Some(name_val) = extract_attribute(after, "into") {
                            self.definitions.push((name_val, ln, col, "Variable"));
                        } else {
                            self.diagnostics.push(Diagnostic {
                                range: Range {
                                    start: Position::new(ln, 0),
                                    end: Position::new(ln, line.len() as u32),
                                },
                                severity: Some(DiagnosticSeverity::WARNING),
                                source: Some("me-dialect-lsp".into()),
                                message: "`<ask>` requires an `into` attribute".into(),
                                ..Default::default()
                            });
                        }
                    }
                    "canvas" | "choose" | "repeat" => {
                        self.definitions.push((format!("<{}>", tag_name), ln, col, "Struct"));
                    }
                    _ => {}
                }

                // Check required attributes
                if tag_name == "repeat" && extract_attribute(after, "times").is_none() {
                    self.diagnostics.push(Diagnostic {
                        range: Range {
                            start: Position::new(ln, 0),
                            end: Position::new(ln, line.len() as u32),
                        },
                        severity: Some(DiagnosticSeverity::WARNING),
                        source: Some("me-dialect-lsp".into()),
                        message: "`<repeat>` requires a `times` attribute".into(),
                        ..Default::default()
                    });
                }

                // Push to stack if block tag and not self-closing
                if !is_self_closing && BLOCK_TAGS.contains(&tag_name) {
                    tag_stack.push((tag_name.to_string(), ln));
                }

                search = tag_end.map(|e| &after[e + 1..]).unwrap_or("");
            }
        }

        // Report unclosed tags
        for (tag_name, open_line) in &tag_stack {
            self.diagnostics.push(Diagnostic {
                range: Range {
                    start: Position::new(*open_line, 0),
                    end: Position::new(
                        *open_line,
                        self.source
                            .lines()
                            .nth(*open_line as usize)
                            .map(|l| l.len() as u32)
                            .unwrap_or(1),
                    ),
                },
                severity: Some(DiagnosticSeverity::ERROR),
                source: Some("me-dialect-lsp".into()),
                message: format!("Unclosed tag `<{}>` — expected `</{}>`", tag_name, tag_name),
                ..Default::default()
            });
        }
    }
}

/// Extract the value of an attribute from a tag's attribute string.
/// e.g., extract_attribute("remember name=\"score\">10", "name") => Some("score")
fn extract_attribute(tag_content: &str, attr_name: &str) -> Option<String> {
    let search = format!("{}=\"", attr_name);
    if let Some(start) = tag_content.find(&search) {
        let value_start = start + search.len();
        if let Some(end) = tag_content[value_start..].find('"') {
            return Some(tag_content[value_start..value_start + end].to_string());
        }
    }
    // Also try single quotes
    let search_sq = format!("{}='", attr_name);
    if let Some(start) = tag_content.find(&search_sq) {
        let value_start = start + search_sq.len();
        if let Some(end) = tag_content[value_start..].find('\'') {
            return Some(tag_content[value_start..value_start + end].to_string());
        }
    }
    None
}

// ---------------------------------------------------------------------------
// Backend
// ---------------------------------------------------------------------------

/// Me-Dialect LSP backend.
pub struct MeDialectBackend {
    client: Client,
    documents: Arc<DashMap<Url, DocumentState>>,
}

impl MeDialectBackend {
    pub fn new(client: Client) -> Self {
        Self {
            client,
            documents: Arc::new(DashMap::new()),
        }
    }

    async fn publish_diagnostics(&self, uri: &Url) {
        if let Some(doc) = self.documents.get(uri) {
            self.client
                .publish_diagnostics(uri.clone(), doc.diagnostics.clone(), None)
                .await;
        }
    }
}

#[tower_lsp::async_trait]
impl LanguageServer for MeDialectBackend {
    async fn initialize(&self, _params: InitializeParams) -> Result<InitializeResult> {
        Ok(InitializeResult {
            capabilities: ServerCapabilities {
                text_document_sync: Some(TextDocumentSyncCapability::Kind(
                    TextDocumentSyncKind::FULL,
                )),
                completion_provider: Some(CompletionOptions {
                    trigger_characters: Some(vec!["<".into(), " ".into(), "\"".into()]),
                    resolve_provider: Some(false),
                    ..Default::default()
                }),
                hover_provider: Some(HoverProviderCapability::Simple(true)),
                definition_provider: Some(OneOf::Left(true)),
                document_symbol_provider: Some(OneOf::Left(true)),
                ..Default::default()
            },
            server_info: Some(ServerInfo {
                name: "me-dialect-lsp".into(),
                version: Some("0.1.0".into()),
            }),
        })
    }

    async fn initialized(&self, _: InitializedParams) {
        self.client
            .log_message(MessageType::INFO, "Me-Dialect LSP server initialized")
            .await;
    }

    async fn shutdown(&self) -> Result<()> {
        Ok(())
    }

    // -----------------------------------------------------------------------
    // Document sync
    // -----------------------------------------------------------------------

    async fn did_open(&self, params: DidOpenTextDocumentParams) {
        let uri = params.text_document.uri;
        let doc = DocumentState::new(params.text_document.text);
        self.documents.insert(uri.clone(), doc);
        self.publish_diagnostics(&uri).await;
    }

    async fn did_change(&self, params: DidChangeTextDocumentParams) {
        let uri = params.text_document.uri;
        if let Some(change) = params.content_changes.first() {
            let doc = DocumentState::new(change.text.clone());
            self.documents.insert(uri.clone(), doc);
            self.publish_diagnostics(&uri).await;
        }
    }

    async fn did_close(&self, params: DidCloseTextDocumentParams) {
        self.documents.remove(&params.text_document.uri);
    }

    // -----------------------------------------------------------------------
    // Hover
    // -----------------------------------------------------------------------

    async fn hover(&self, params: HoverParams) -> Result<Option<Hover>> {
        let uri = &params.text_document_position_params.text_document.uri;
        let pos = params.text_document_position_params.position;

        let doc = match self.documents.get(uri) {
            Some(d) => d,
            None => return Ok(None),
        };

        let word = match doc.word_at(pos.line, pos.character) {
            Some(w) => w,
            None => return Ok(None),
        };

        // Check tag documentation
        if let Some(doc_text) = tag_doc(&word) {
            return Ok(Some(Hover {
                contents: HoverContents::Markup(MarkupContent {
                    kind: MarkupKind::Markdown,
                    value: doc_text.to_string(),
                }),
                range: None,
            }));
        }

        // Check user-defined variables
        for (name, _ln, _col, kind) in &doc.definitions {
            if name == &word {
                return Ok(Some(Hover {
                    contents: HoverContents::Markup(MarkupContent {
                        kind: MarkupKind::Markdown,
                        value: format!(
                            "**{}** `{}`\n\nDefined in this file.\nUse in text: `{{{}}}`",
                            kind, name, name
                        ),
                    }),
                    range: None,
                }));
            }
        }

        Ok(None)
    }

    // -----------------------------------------------------------------------
    // Completion
    // -----------------------------------------------------------------------

    async fn completion(&self, params: CompletionParams) -> Result<Option<CompletionResponse>> {
        let uri = &params.text_document_position.text_document.uri;
        let pos = params.text_document_position.position;

        let doc = match self.documents.get(uri) {
            Some(d) => d,
            None => return Ok(None),
        };

        let mut items = Vec::new();

        // If inside a tag opening, offer attribute completions
        if let Some(tag_name) = doc.is_inside_attributes(pos.line, pos.character) {
            for (tag, attrs) in TAG_ATTRIBUTES {
                if *tag == tag_name {
                    for attr in *attrs {
                        items.push(CompletionItem {
                            label: format!("{}=\"\"", attr),
                            kind: Some(CompletionItemKind::PROPERTY),
                            detail: Some(format!("Attribute for <{}>", tag_name)),
                            insert_text: Some(format!("{}=\"$1\"", attr)),
                            insert_text_format: Some(InsertTextFormat::SNIPPET),
                            sort_text: Some(format!("0_{}", attr)),
                            ..Default::default()
                        });
                    }
                }
            }
            return Ok(Some(CompletionResponse::Array(items)));
        }

        // If after `<`, offer tag completions
        if doc.is_inside_tag_open(pos.line, pos.character) {
            for tag in ME_TAGS {
                let is_self_close = SELF_CLOSING_TAGS.contains(tag);
                let snippet = if is_self_close {
                    format!("{}>$1</{}>", tag, tag)
                } else {
                    format!("{}>\n  $1\n</{}>", tag, tag)
                };

                items.push(CompletionItem {
                    label: tag.to_string(),
                    kind: Some(CompletionItemKind::SNIPPET),
                    detail: Some(format!("Me tag: <{}>", tag)),
                    insert_text: Some(snippet),
                    insert_text_format: Some(InsertTextFormat::SNIPPET),
                    documentation: tag_doc(tag).map(|d| {
                        Documentation::MarkupContent(MarkupContent {
                            kind: MarkupKind::Markdown,
                            value: d.to_string(),
                        })
                    }),
                    sort_text: Some(format!("0_{}", tag)),
                    ..Default::default()
                });
            }

            // Closing tags for open blocks
            // (This would need tag stack context for full accuracy)
            for tag in BLOCK_TAGS {
                items.push(CompletionItem {
                    label: format!("/{}", tag),
                    kind: Some(CompletionItemKind::SNIPPET),
                    detail: Some(format!("Close </{}>", tag)),
                    insert_text: Some(format!("/{}>", tag)),
                    sort_text: Some(format!("1_{}", tag)),
                    ..Default::default()
                });
            }

            return Ok(Some(CompletionResponse::Array(items)));
        }

        // General completion: offer opening tags
        for tag in ME_TAGS {
            items.push(CompletionItem {
                label: format!("<{}>", tag),
                kind: Some(CompletionItemKind::SNIPPET),
                detail: Some(format!("Me tag: <{}>", tag)),
                insert_text: Some(format!("<{}>$1</{}>", tag, tag)),
                insert_text_format: Some(InsertTextFormat::SNIPPET),
                sort_text: Some(format!("0_{}", tag)),
                ..Default::default()
            });
        }

        // Variable interpolation completions
        for (name, _ln, _col, _kind) in &doc.definitions {
            if !name.starts_with('<') {
                items.push(CompletionItem {
                    label: format!("{{{}}}", name),
                    kind: Some(CompletionItemKind::VARIABLE),
                    detail: Some("Variable interpolation".into()),
                    insert_text: Some(format!("{{{}}}", name)),
                    sort_text: Some(format!("2_{}", name)),
                    ..Default::default()
                });
            }
        }

        Ok(Some(CompletionResponse::Array(items)))
    }

    // -----------------------------------------------------------------------
    // Go to definition
    // -----------------------------------------------------------------------

    async fn goto_definition(
        &self,
        params: GotoDefinitionParams,
    ) -> Result<Option<GotoDefinitionResponse>> {
        let uri = &params.text_document_position_params.text_document.uri;
        let pos = params.text_document_position_params.position;

        let doc = match self.documents.get(uri) {
            Some(d) => d,
            None => return Ok(None),
        };

        let word = match doc.word_at(pos.line, pos.character) {
            Some(w) => w,
            None => return Ok(None),
        };

        for (name, ln, col, _kind) in &doc.definitions {
            if name == &word {
                return Ok(Some(GotoDefinitionResponse::Scalar(Location {
                    uri: uri.clone(),
                    range: Range {
                        start: Position::new(*ln, *col),
                        end: Position::new(*ln, *col + name.len() as u32),
                    },
                })));
            }
        }

        Ok(None)
    }

    // -----------------------------------------------------------------------
    // Document symbols
    // -----------------------------------------------------------------------

    async fn document_symbol(
        &self,
        params: DocumentSymbolParams,
    ) -> Result<Option<DocumentSymbolResponse>> {
        let uri = &params.text_document.uri;

        let doc = match self.documents.get(uri) {
            Some(d) => d,
            None => return Ok(None),
        };

        #[allow(deprecated)]
        let symbols: Vec<SymbolInformation> = doc
            .definitions
            .iter()
            .map(|(name, ln, col, kind)| SymbolInformation {
                name: name.clone(),
                kind: match *kind {
                    "Function" => SymbolKind::FUNCTION,
                    "Variable" => SymbolKind::VARIABLE,
                    "Struct" => SymbolKind::STRUCT,
                    _ => SymbolKind::KEY,
                },
                tags: None,
                deprecated: None,
                location: Location {
                    uri: uri.clone(),
                    range: Range {
                        start: Position::new(*ln, *col),
                        end: Position::new(*ln, *col + name.len() as u32),
                    },
                },
                container_name: None,
            })
            .collect();

        Ok(Some(DocumentSymbolResponse::Flat(symbols)))
    }
}
