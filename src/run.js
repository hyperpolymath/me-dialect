// SPDX-License-Identifier: MPL-2.0
// Copyright (c) Jonathan D.A. Jewell <j.d.a.jewell@open.ac.uk>
// SPDX-FileCopyrightText: 2025 hyperpolymath
//
// Deno entry point for Me Language
// This file imports the compiled ReScript and runs the demo

import { demonstrateMeLanguage } from './Main.res.js';

// Run the demo when executed directly
if (import.meta.main) {
  demonstrateMeLanguage();
}
