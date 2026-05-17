local M = {}

---@class todoview.RenderArgs
---@field buf integer
---@field ns_id integer
---@field row integer

---@param args todoview.RenderArgs
---@param cfg todoview.InternalConfig
---@param task todoview.Task
---@return nil
local function rend_completion(args, cfg, task)
  local opts = { virt_text_pos = "inline" }

  if task.completed then
    opts.virt_text = { { cfg.completion.completed_icon, "TodoviewCompleted" } }
    opts.end_col = 1
    opts.conceal = ""
  else
    -- Pending icon.
    local icon_hl = { cfg.completion.pending_icon, "TodoviewPending" }

    if cfg.enable_overdue and require("todoview.time").is_before_now(task.key_values.due) then
      -- Change to overdue icon.
      icon_hl = { cfg.completion.overdue_icon, "TodoviewOverdue" }
    end

    opts.virt_text = { icon_hl, { " ", icon_hl[2] } }
  end

  vim.api.nvim_buf_set_extmark(args.buf, args.ns_id, args.row, 0, opts)
end

---@param args todoview.RenderArgs
---@param config todoview.Config.Priority
---@param task todoview.Task
---@return nil
local function rend_priority(args, config, task)
  if not task.priority or not config.enable or (task.completed and not config.enable_completed) then
    return
  end

  local opts = { end_col = task.priority.end_col }
  if type(config.hl_group) == "function" then
    opts.hl_group = config.hl_group(task.priority.letter)
  else
    opts.hl_group = config.hl_group
  end

  if opts.hl_group then
    vim.api.nvim_buf_set_extmark(args.buf, args.ns_id, args.row, task.priority.start_col, opts)
  end
end

---@param args todoview.RenderArgs
---@param config todoview.Config.Date
---@param date_node? todoview.TaskNode
---@param hl_group string
---@param due? boolean
---@return nil
local function rend_date(args, config, date_node, hl_group, due)
  if not config.enable or date_node == nil then
    return
  end

  if config.format and date_node.time then
    local start_col = date_node.start_col
    if due then
      start_col = start_col + 4
    end

    vim.api.nvim_buf_set_extmark(args.buf, args.ns_id, args.row, start_col, {
      virt_text = { { os.date(config.format, date_node.time), hl_group } },
      virt_text_pos = "inline",
      conceal = "",
      end_col = date_node.end_col,
    })
  end
end

---@param cfg todoview.InternalConfig
---@param buf integer buffer ID, assumed to be normalized.
---@param ns_id integer
---@param row integer
---@param task todoview.Task
function M.render_task(cfg, buf, ns_id, row, task)
  local args = { buf = buf, ns_id = ns_id, row = row }

  rend_completion(args, cfg, task)
  rend_priority(args, cfg.priority, task)
  rend_date(args, cfg.completion_date, task.completion_date, "TodoviewCompletionDate")
  rend_date(args, cfg.creation_date, task.creation_date, "TodoviewCreationDate")
  rend_date(args, cfg.due_date, task.key_values.due, "TodoviewDueDate", true)
end

return M
