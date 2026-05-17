local M = {}

function M.set_hl_groups()
  local ns_id = vim.api.nvim_create_namespace("TodoviewHighlight")

  for group, link in pairs({
    -- Completion icons
    Completed = "DiagnosticFloatingOk",
    Pending = "DiagnosticFloatingWarn",
    Overdue = "DiagnosticFloatingError",

    -- Priority
    PrioA = "DiagnosticFloatingError",
    PrioB = "DiagnosticFloatingWarn",
    PrioC = "DiagnosticFloatingInfo",
    PrioD = "DiagnosticFloatingHint",
    PrioDefault = "DiagnosticFloatingOk",

    -- Dates
    CompletionDate = "Comment",
    CreationDate = "Comment",

    -- Tags, enumlating tree-sitter-todotxt
    Project = "String",
    Context = "Type",
    Key = "Comment",
    Value = "Comment",
  }) do
    vim.api.nvim_set_hl(ns_id, "Todoview" .. group, { link = link })
  end

  -- Activate highlight groups.
  vim.api.nvim_set_hl_ns(ns_id)
end

return M
