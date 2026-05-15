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

---@class todoview.InternalConfig
---@field default_todo_file string
---@field enable_overdue boolean
---@field completion todoview.Config.Completion
---@field completion_date todoview.Config.Date
---@field creation_date todoview.Config.Date
---@field due_date todoview.Config.Date
local cfg = {}

local state = {
  rendering = true,
  bo = {},
}

---@param buf? integer buffer ID, which may be 0 or nil
---@return integer
local function normalize_buf_id(buf)
  if buf == nil or buf == 0 then
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

---Render the current buffer if rendering is enabled and the filetype is "todotxt".
---@param buf? integer buffer ID
---@param startrow? integer
---@param endrow? integer
function M.render_buf(buf, startrow, endrow)
  if not state.rendering or not state.bo[buf] then
    return
  end

  buf = normalize_buf_id(buf)
  startrow = startrow or 0
  endrow = endrow or -1

  if vim.wo.conceallevel < 2 then
    vim.wo.conceallevel = 2
  end

  -- Get namespaces.
  local anchor_ns = vim.api.nvim_create_namespace("TodoviewAnchors")
  local ns_id = vim.api.nvim_create_namespace("TodoviewExtmarks")
  vim.api.nvim_buf_clear_namespace(buf, ns_id, startrow, endrow)

  local render_task = require("todoview.render").render_task
  local parse_task = require("todoview.task").parse_task

  for i, line in ipairs(vim.api.nvim_buf_get_lines(buf, startrow, endrow, false)) do
    local row = startrow + i - 1
    local anchor = vim.api.nvim_buf_get_extmarks(buf, anchor_ns, { row, 0 }, { row, 0 }, {})[1]
    local anchor_id = (anchor ~= nil) and anchor[1] or nil

    if not anchor_id then
      -- Reanchor and reparse.
      anchor_id = vim.api.nvim_buf_set_extmark(buf, anchor_ns, row, 0, {})
      state.bo[buf][anchor_id] = parse_task(line)
    end

    local task = state.bo[buf][anchor_id]
    render_task(cfg, buf, ns_id, row, task)
  end
end

---Clear the current buffer's extmarks with the todoview namespace.
---@param buf? integer buffer ID
---@param startrow? integer
---@param endrow? integer
function M.clear_buf(buf, startrow, endrow)
  if not state.bo[buf] then
    return
  end

  buf = normalize_buf_id(buf)
  startrow = startrow or 0
  endrow = endrow or -1

  local ns_id = vim.api.nvim_get_namespaces().TodoviewExtmarks
  if ns_id then
    vim.api.nvim_buf_clear_namespace(buf, ns_id, startrow, endrow)
  end

  ns_id = vim.api.nvim_get_namespaces().TodoviewAnchors
  if ns_id then
    local anchors = vim.api.nvim_buf_get_extmarks(buf, ns_id, { startrow, 0 }, { endrow, 0 }, {})
    for _, anchor in ipairs(anchors) do
      state.bo[buf][anchor[1]] = nil
    end
    vim.api.nvim_buf_clear_namespace(buf, ns_id, startrow, endrow)
  else
    state.bo[buf] = {}
  end
end

---@param buf? integer buffer ID
---@param startrow? integer
---@param endrow? integer
function M.refresh_buf(buf, startrow, endrow)
  M.clear_buf(buf, startrow, endrow)
  M.render_buf(buf, startrow, endrow)
end

---@param buf? integer
local function init_buf(buf)
  buf = normalize_buf_id(buf)
  state.bo[buf] = {}

  vim.api.nvim_buf_attach(buf, false, {
    on_lines = function(_, buf_id, _, startrow, _endrow, new_endrow)
      if vim.api.nvim_get_mode().mode ~= "i" then
        -- Refresh only once the change is reflected in the buffer lines.
        vim.api.nvim_create_autocmd("TextChanged", {
          group = "todoview",
          once = true,
          callback = function()
            M.refresh_buf(buf_id, startrow, new_endrow + 1)
          end,
        })
      end
    end,
    on_reload = function(_, buf_id)
      M.refresh_buf(buf_id, 0, -1)
    end,
    on_detach = function(buf_id)
      state.bo[buf_id] = nil
    end,
  })

  M.render_buf(buf)
end

---@param augroup string|integer? Group name or id to match against.
local function create_autocmds(augroup)
  vim.api.nvim_create_autocmd("BufEnter", {
    group = augroup,
    callback = function(args)
      if vim.bo[args.buf].filetype == "todotxt" and not state.bo[args.buf] then
        init_buf(args.buf)
      end
    end,
  })

  vim.api.nvim_create_autocmd("InsertEnter", {
    group = augroup,
    callback = function(args)
      M.clear_buf(args.buf)
    end,
  })

  vim.api.nvim_create_autocmd("InsertLeave", {
    group = augroup,
    callback = function(args)
      M.render_buf(args.buf)
    end,
  })
end

---@param opts? todoview.Config
function M.setup(opts)
  cfg = vim.tbl_deep_extend("keep", opts, {
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
  })

  vim.api.nvim_create_user_command("Todoview", function(_args)
    M.toggle()
  end, {})

  vim.api.nvim_create_user_command("TodoviewOpen", function(_args)
    M.open()
  end, {})

  -- Set highlight groups.
  require("todoview.highlight").set_hl_groups()

  local augroup = vim.api.nvim_create_augroup("todoview", { clear = true })
  local init_with_current_buf = function()
    create_autocmds(augroup)
    if vim.bo.filetype == "todotxt" then
      init_buf() -- Start rendering current buffer.
    end
  end

  -- Initialize if a todo.txt buffer is currently open.
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.bo[buf].filetype == "todotxt" then
      init_with_current_buf()
      return
    end
  end

  -- No todo.txt buffers open. Initialize when the first todo.txt file is opened.
  vim.api.nvim_create_autocmd("FileType", {
    group = augroup,
    callback = function(args)
      local filetype = args.match
      if filetype == "todotxt" then
        init_with_current_buf()
        vim.api.nvim_del_autocmd(args.id)
      end
    end,
  })
end

return M
