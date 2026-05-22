;; SPDX-License-Identifier: MPL-2.0
(bot-directive
  (bot "seambot")
  (scope "integration health")
  (allow ("analysis" "contract checks" "docs updates"))
  (deny ("code changes without approval"))
  (notes "May add integration test suggestions"))
