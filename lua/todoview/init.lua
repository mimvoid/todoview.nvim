local M = {}

---@class todoview.Config.Completion
---@field pending_icon? string
---@field completed_icon? string
---@field overdue_icon? string

---@class todoview.Config.Date
---@field enable? boolean Enable rendering of the date
---@field format? string How to format the date, as passed to `os.date`

---@class todoview.Config
---@field default_todo_file? string
---@field enable_overdue? boolean
---@field completion? todoview.Config.Completion
---@field completion_date? todoview.Config.Date
---@field creation_date? todoview.Config.Date
---@field due_date? todoview.Config.Date

local cfg = {
  default_todo_file = "~/todo.txt",
  enable_overdue = false,

  completion = {
    pending_icon = "",
    completed_icon = "",
    overdue_icon = "",
  },

  completion_date = {
    enable = true,
    format = "%Y-%m-%d",
  },
  creation_date = {
    enable = true,
    format = "%Y-%m-%d",
  },
  due_date = {
    enable = true,
    format = "%Y-%m-%d",
  },
}

local state = {
  rendering = true,
  bo = {},
}

---@param buf? integer buffer ID, which may be 0 or nil
---@return integer
local function normalize_buf_id(buf)
  if buf == 0 or buf == nil then
    return vim.api.nvim_get_current_buf()
  end
  return buf
end

---Open the default todo file.
function M.open()
  vim.cmd.edit(cfg.default_todo_file)
end

---Toggle todoview rendering.
---@param buf? integer buffer ID
function M.toggle(buf)
  if state.rendering then
    M.clear_buf(buf)
    state.rendering = false
  else
    state.rendering = true
    M.render_buf(buf)
  end
end

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
local function render_task(buf, ns_id, row, task)
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

---Render the current buffer if rendering is enabled and the filetype is "todotxt".
---@param buf? integer buffer ID
function M.render_buf(buf)
  buf = normalize_buf_id(buf)

  if state.rendering and vim.bo[buf].filetype == "todotxt" then
    -- Get fresh namespace.
    local ns_id = vim.api.nvim_create_namespace("TodoviewExtmarks")
    vim.api.nvim_buf_clear_namespace(buf, ns_id, 0, -1)

    if vim.wo.conceallevel < 2 then
      vim.wo.conceallevel = 2
    end

    if state.bo[buf] then
      for row, task in pairs(state.bo[buf]) do
        render_task(buf, ns_id, row, task)
      end
    else
      state.bo[buf] = {}
      local parse_task = require("todoview.task").parse_task

      for i, line in ipairs(vim.api.nvim_buf_get_lines(buf, 0, -1, true)) do
        local task = parse_task(line)
        local row = i - 1
        state.bo[buf][row] = task
        render_task(buf, ns_id, row, task)
      end
    end
  end
end

---@param buf? integer buffer ID
function M.refresh_buf(buf)
  buf = normalize_buf_id(buf)
  if state.bo[buf] then
    state.bo[buf] = nil
  end
  M.render_buf(buf)
end

---Clear the current buffer's extmarks with the todoview namespace.
---@param buf? integer buffer ID
function M.clear_buf(buf)
  buf = normalize_buf_id(buf)
  if vim.bo[buf].filetype == "todotxt" then
    local ns_id = vim.api.nvim_get_namespaces().TodoviewExtmarks
    if ns_id ~= nil then
      vim.api.nvim_buf_clear_namespace(buf, ns_id, 0, -1)
    end
  end
end

---@param augroup string|integer? Group name or id to match against.
local function create_autocmds(augroup)
  vim.api.nvim_create_autocmd("BufEnter", {
    group = augroup,
    callback = function(args)
      M.render_buf(args.buf)
    end,
  })

  vim.api.nvim_create_autocmd("BufDelete", {
    group = augroup,
    callback = function(args)
      state.bo[args.buf] = nil
    end,
  })

  vim.api.nvim_create_autocmd({ "TextChanged", "InsertLeave" }, {
    group = augroup,
    callback = function(args)
      M.refresh_buf(args.buf)
    end,
  })

  vim.api.nvim_create_autocmd("InsertEnter", {
    group = augroup,
    callback = function(args)
      M.clear_buf(args.buf)
    end,
  })
end

function init_autocmds()
  local augroup = vim.api.nvim_create_augroup("todoview", { clear = true })

  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.bo[buf].filetype == "todotxt" then
      -- Called setup when a todo.txt file was opened.
      create_autocmds(augroup)

      -- Start rendering current buffer if able.
      M.render_buf()
      return
    end
  end

  -- Create autocommands when entering a todo.txt file for the first time.
  vim.api.nvim_create_autocmd("FileType", {
    group = augroup,
    callback = function(args)
      local filetype = args.match
      if filetype == "todotxt" then
        create_autocmds(augroup)
        vim.api.nvim_del_autocmd(args.id)
      end
    end,
  })
end

---@param opts? todoview.Config
function M.setup(opts)
  cfg = vim.tbl_deep_extend("keep", opts, cfg)

  vim.api.nvim_create_user_command("Todoview", function(_args)
    M.toggle()
  end, {})

  vim.api.nvim_create_user_command("TodoviewOpen", function(_args)
    M.open()
  end, {})

  -- Set highlight groups.
  require("todoview.highlight").set_hl_groups()
  init_autocmds()
end

return M
