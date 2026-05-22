;; SPDX-License-Identifier: MPL-2.0
(bot-directive
  (bot "finishbot")
  (scope "release readiness")
  (allow ("release checklists" "docs updates" "metadata fixes"))
  (deny ("code changes without approval"))
  (notes "Focus on polish, licensing, and packaging"))
