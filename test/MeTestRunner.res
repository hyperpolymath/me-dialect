// SPDX-License-Identifier: PMPL-1.0-or-later
// SPDX-FileCopyrightText: 2026 hyperpolymath
//
// Me Language Test Runner
// Aggregates all test suites and prints results.

let () = {
  Console.log("=== Me Language Test Suite ===\n")

  let allResults =
    MeTest_ValueAndInterpolation.run()
    ->Array.concat(MeTest_ASTConstruction.run())
    ->Array.concat(MeTest_Execution.run())
    ->Array.concat(MeTest_Conditionals.run())
    ->Array.concat(MeTest_Repetition.run())
    ->Array.concat(MeTest_EdgeCases.run())
    ->Array.concat(MeTest_Parser.run())

  let exitCode = MeTestUtils.summarise(allResults)

  if exitCode != 0 {
    Console.error("\nSome tests failed.")
  } else {
    Console.log("\nAll tests passed.")
  }
}
