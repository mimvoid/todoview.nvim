local M = {}

---@param buf integer
---@param ns_id integer
---@param row integer
---@param config todoview.Config.Date
---@param date_node? todoview.TaskNode
---@param hl_group string
---@param due? boolean
---@return nil
local function render_date(buf, ns_id, row, config, date_node, hl_group, due)
  if not config.enable or date_node == nil then
    return
  end

  if config.format and date_node.time then
    local start_col = date_node.start_col
    if due then
      start_col = start_col + 4
    end

    local virt_text = os.date(config.format, date_node.time)
    local overlay = virt_text:sub(1, 10)
    local rest = virt_text:sub(11)

    vim.api.nvim_buf_set_extmark(buf, ns_id, row, start_col, {
      virt_text = { { overlay, hl_group } },
      virt_text_pos = "overlay",
    })
    vim.api.nvim_buf_set_extmark(buf, ns_id, row, start_col + 10, {
      virt_text = { { rest, hl_group } },
      virt_text_pos = "inline",
    })
  end
end

---@param buf integer buffer ID, assumed to be normalized.
---@param ns_id integer
---@param row integer
---@param task todoview.Task
function M.render_task(cfg, buf, ns_id, row, task)
  if task.completed then
    vim.api.nvim_buf_set_extmark(buf, ns_id, row, 0, {
      virt_text = { { cfg.completion.completed_icon, "TodoviewCompleted" } },
      virt_text_pos = "inline",
      end_col = 1,
      conceal = "",
    })
  else
    -- Pending icon.
    local icon_hl = { cfg.completion.pending_icon, "TodoviewPending" }
    if cfg.enable_overdue and require("todoview.time").is_before_now(task.key_values.due) then
      -- Change to overdue icon.
      icon_hl = { cfg.completion.overdue_icon, "TodoviewOverdue" }
    end

    -- Add completion icon.
    vim.api.nvim_buf_set_extmark(buf, ns_id, row, 0, {
      virt_text = { icon_hl, { " ", icon_hl[2] } },
      virt_text_pos = "inline",
    })

    if task.priority then
      local priority_hl_groups = {
        ["(A)"] = "TodoviewPrioA",
        ["(B)"] = "TodoviewPrioB",
        ["(C)"] = "TodoviewPrioC",
        ["(D)"] = "TodoviewPrioD",
      }
      vim.api.nvim_buf_set_extmark(buf, ns_id, row, task.priority.start_col, {
        end_col = task.priority.end_col,
        hl_group = priority_hl_groups[task.priority.text] or "TodoviewPrioDefault",
      })
    end
  end

  render_date(buf, ns_id, row, cfg.completion_date, task.completion_date, "TodoviewCompletionDate")
  render_date(buf, ns_id, row, cfg.creation_date, task.creation_date, "TodoviewCreationDate")
  render_date(buf, ns_id, row, cfg.due_date, task.key_values.due, "TodoviewDueDate", true)
end

return M
