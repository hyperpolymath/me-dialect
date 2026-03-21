// SPDX-License-Identifier: PMPL-1.0-or-later
//! me-dialect-lsp — Language Server Protocol server for Me-Dialect.
//!
//! Me is an educational programming language for children (ages 8-12) that
//! uses HTML/XML-like tag syntax: `<say>`, `<remember>`, `<choose>`, etc.
//! This LSP server provides tag completion, attribute completion, diagnostics
//! for unclosed tags, hover documentation, and document symbols.

#![forbid(unsafe_code)]
mod backend;

use tower_lsp::{LspService, Server};

#[tokio::main]
async fn main() {
    let stdin = tokio::io::stdin();
    let stdout = tokio::io::stdout();

    let (service, socket) = LspService::new(|client| backend::MeDialectBackend::new(client));
    Server::new(stdin, stdout, socket).serve(service).await;
}
