local M = {}

---@class todoview.RenderArgs
---@field buf integer
---@field ns_id integer
---@field row integer

---@param args todoview.RenderArgs
---@param fmt todoview.Format?
---@return table?, integer?
local function set_extmark(args, node, fmt)
  if not fmt then
    return nil
  end

  local opts = { end_col = node.end_col }
  if type(fmt) == "string" then
    opts.hl_group = fmt
  else
    opts.virt_text = fmt
    opts.virt_text_pos = "inline"
    opts.conceal = ""
  end

  vim.api.nvim_buf_set_extmark(args.buf, args.ns_id, args.row, node.start_col, opts)
end

---@param args todoview.RenderArgs
---@param config todoview.Config.Completion
---@param task todoview.Task
---@return nil
local function rend_completion(args, config, task)
  if not config.enable or not config.format then
    return
  end

  local virt_text = config.format(task)
  if virt_text then
    local opts = {
      virt_text = virt_text,
      virt_text_pos = "inline"
    }

    if task.completed then
      opts.end_col = 2
      opts.conceal = ""
    end

    vim.api.nvim_buf_set_extmark(args.buf, args.ns_id, args.row, 0, opts)
  end
end

---@param args todoview.RenderArgs
---@param config todoview.Config.Priority
---@param task todoview.Task
---@return nil
local function rend_priority(args, config, task)
  if not task.priority or not config.enable or not config.format then
    return
  end
  set_extmark(args, task.priority, config.format(task))
end

---@param args todoview.RenderArgs
---@param config todoview.Config.Date
---@param task todoview.Task
---@param date? todoview.TaskNode
---@return nil
local function rend_date(args, config, task, date)
  if not config.enable or not config.format or date == nil then
    return
  end

  local time = require("todoview.task").parse_time(date.text)
  if time then
    set_extmark(args, date, config.format(task, time))
  end
end

---@param args todoview.RenderArgs
---@param config todoview.Config.KeyValue
---@param task todoview.Task
local function rend_key_values(args, config, task)
  if not config.enable or not config.format then
    return
  end

  for key, value_node in pairs(task.key_values) do
    set_extmark(args, value_node, config.format(task, key))
  end
end

---@param cfg todoview.FullConfig
---@param buf integer buffer ID, assumed to be normalized.
---@param ns_id integer
---@param row integer
---@param task todoview.Task
function M.render_task(cfg, buf, ns_id, row, task)
  local args = { buf = buf, ns_id = ns_id, row = row }

  rend_priority(args, cfg.priority, task) -- Call first so it's to the right of completion virt text.
  rend_completion(args, cfg.completion, task)
  rend_date(args, cfg.completion_date, task, task.completion_date)
  rend_date(args, cfg.creation_date, task, task.creation_date)
  rend_key_values(args, cfg.key_value, task)
end

return M
