// SPDX-License-Identifier: PMPL-1.0-or-later
// SPDX-FileCopyrightText: 2025 hyperpolymath
//
// Deno entry point for Me Language
// This file imports the compiled ReScript and runs the demo

import { demonstrateMeLanguage } from './Main.res.js';

// Run the demo when executed directly
if (import.meta.main) {
  demonstrateMeLanguage();
}
