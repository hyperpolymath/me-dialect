// SPDX-License-Identifier: PMPL-1.0-or-later
// SPDX-FileCopyrightText: 2026 Jonathan D.A. Jewell <j.d.a.jewell@open.ac.uk>
//
// Me Language - AST Dump CLI
//
// Reads a .me.js file, extracts the exported AST node, and prints it
// in either JSON or S-expression format.
//
// Usage:
//   deno run --allow-read tools/ast_dump.js [--format json|sexpr] <file.me.js>
//   deno task dump [--format json|sexpr] <file.me.js>
//
// The target file must export a default or named `ast` / `program` constant
// that is a valid meNode object (with nodeType, children, attributes, content).
//
// If no --format is specified, defaults to JSON.

import { toJson, toSexpr, parseFormat } from '../src/MeAstDump.res.js';

// ---------------------------------------------------------------------------
// Argument parsing
// ---------------------------------------------------------------------------

/** Print usage instructions to stderr and exit with code 1. */
function usage() {
  console.error(`Me Language AST Dump

Usage:
  deno run --allow-read tools/ast_dump.js [OPTIONS] <file>

Options:
  --format <json|sexpr>   Output format (default: json)
  --help                  Show this help message

Formats:
  json    Standard JSON with 2-space indentation
  sexpr   S-expression (Lisp-style) with keyword attributes

Examples:
  deno task dump examples/level1/hello.me.js
  deno task dump --format sexpr examples/level2/choices.me.js
`);
  Deno.exit(1);
}

// Parse CLI arguments
let format = 'json';
let filePath = null;

const args = Deno.args;
for (let i = 0; i < args.length; i++) {
  const arg = args[i];
  if (arg === '--help' || arg === '-h') {
    usage();
  } else if (arg === '--format' || arg === '-f') {
    i++;
    if (i >= args.length) {
      console.error('Error: --format requires a value (json or sexpr)');
      Deno.exit(1);
    }
    format = args[i];
  } else if (arg.startsWith('--format=')) {
    format = arg.split('=')[1];
  } else if (arg.startsWith('-')) {
    console.error(`Error: unknown option '${arg}'`);
    Deno.exit(1);
  } else {
    filePath = arg;
  }
}

if (!filePath) {
  console.error('Error: no input file specified\n');
  usage();
}

// ---------------------------------------------------------------------------
// Validate format
// ---------------------------------------------------------------------------

const parsedFormat = parseFormat(format);
if (parsedFormat === undefined) {
  console.error(`Error: unknown format '${format}' (use 'json' or 'sexpr')`);
  Deno.exit(1);
}

// ---------------------------------------------------------------------------
// Load the .me.js file and extract the AST
// ---------------------------------------------------------------------------

/** Resolve the file path relative to CWD. */
const resolvedPath = new URL(filePath, `file://${Deno.cwd()}/`).href;

let mod;
try {
  mod = await import(resolvedPath);
} catch (err) {
  console.error(`Error: could not load '${filePath}': ${err.message}`);
  Deno.exit(1);
}

// Look for the AST node in common export names.
// .me.js files typically use unnamed const assignments, so we also
// scan all exports for anything that looks like an meNode (has nodeType).
function findAstNode(exports) {
  // Priority 1: explicit named exports
  for (const name of ['ast', 'program', 'default', 'tree', 'root']) {
    if (exports[name] && typeof exports[name] === 'object' && exports[name].nodeType) {
      return exports[name];
    }
  }
  // Priority 2: any export with a nodeType field
  for (const [_key, value] of Object.entries(exports)) {
    if (value && typeof value === 'object' && value.nodeType) {
      return value;
    }
  }
  return null;
}

const astNode = findAstNode(mod);

if (!astNode) {
  console.error(
    `Error: no AST node found in '${filePath}'\n` +
      'The file must export an object with a nodeType field.\n' +
      'Tip: add "export default <your-program-node>;" or "export const ast = ...;"',
  );
  Deno.exit(1);
}

// ---------------------------------------------------------------------------
// Dump
// ---------------------------------------------------------------------------

if (format.toLowerCase() === 'json' || format.toLowerCase() === 'sexpr' ||
    format.toLowerCase() === 's-expr' || format.toLowerCase() === 'sexp') {
  // Use the ReScript dump functions directly based on format
  const output = format.toLowerCase() === 'json' ? toJson(astNode) : toSexpr(astNode);
  console.log(output);
} else {
  console.error(`Error: unknown format '${format}'`);
  Deno.exit(1);
}
