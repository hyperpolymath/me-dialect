;; SPDX-License-Identifier: MPL-2.0
(bot-directive
  (bot "robot-repo-automaton")
  (scope "automated fixes")
  (allow ("low-risk automated edits"))
  (deny ("core logic changes without approval"))
  (notes "Only apply fixes backed by explicit rule approval"))
