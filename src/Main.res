// SPDX-License-Identifier: PMPL-1.0-or-later
// SPDX-FileCopyrightText: 2025 hyperpolymath
//
// Me Language - Main Entry Point

// Re-export all types and functions from MeLanguage
include MeLanguage

// Run demo when executed directly
let main = () => {
  demonstrateMeLanguage()
}

// Check if running as main module
// Note: This is handled by the Deno wrapper
