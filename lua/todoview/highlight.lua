local M = {}

function M.set_hl_groups()
  local ns_id = vim.api.nvim_create_namespace("TodoviewHighlight")

  -- Completion icons
  vim.api.nvim_set_hl(ns_id, "TodoviewCompleted", { link = "DiagnosticFloatingOk" })
  vim.api.nvim_set_hl(ns_id, "TodoviewPending", { link = "DiagnosticFloatingWarn" })
  vim.api.nvim_set_hl(ns_id, "TodoviewOverdue", { link = "DiagnosticFloatingError" })

  -- Priority
  vim.api.nvim_set_hl(ns_id, "TodoviewPrioA", { link = "DiagnosticFloatingError" })
  vim.api.nvim_set_hl(ns_id, "TodoviewPrioB", { link = "DiagnosticFloatingWarn" })
  vim.api.nvim_set_hl(ns_id, "TodoviewPrioC", { link = "DiagnosticFloatingInfo" })
  vim.api.nvim_set_hl(ns_id, "TodoviewPrioD", { link = "DiagnosticFloatingHint" })
  vim.api.nvim_set_hl(ns_id, "TodoviewPrioDefault", { link = "DiagnosticFloatingOk" })

  -- Activate highlight groups.
  vim.api.nvim_set_hl_ns(ns_id)
end

return M
