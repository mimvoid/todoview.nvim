local M = {}

---@class todoview.Config.Completion
---@field open_icon? string
---@field completed_icon? string
---@field hl_group? string

---@class todoview.Config
---@field default_todo_file? string
---@field completion? todoview.Config.Completion

local cfg = {
  default_todo_file = "~/todo.txt",
  completion = {
    incomplete_icon = "",
    completed_icon = "",
  },
}

local state = {
  rendering = true,
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

---@param line string
---@param buf integer buffer ID, assumed to be normalized.
---@param ns_id integer
---@param line_nr integer
local function render_line(line, buf, ns_id, line_nr)
  local char = 0
  local completed = string.sub(line, 0, 2) == "x "

  if completed then
    local overlay = vim.fn.strcharpart(cfg.completion.completed_icon, 0, 1)
    local rest = vim.fn.strcharpart(cfg.completion.completed_icon, 1)

    -- Overlay completion indicator "x".
    vim.api.nvim_buf_set_extmark(buf, ns_id, line_nr, char, {
      virt_text = { { overlay, "TodoviewCompleted" } },
      virt_text_pos = "overlay",
    })

    -- Inline the rest of the icon string.
    if rest ~= "" then
      vim.api.nvim_buf_set_extmark(buf, ns_id, line_nr, char, {
        virt_text = { { rest, "TodoviewCompleted" } },
        virt_text_pos = "inline",
      })
    end

    char = 2
  else
    -- Completion icon.
    vim.api.nvim_buf_set_extmark(buf, ns_id, line_nr, char, {
      virt_text = {
        { cfg.completion.incomplete_icon, "TodoviewIncomplete" },
        { " ", "TodoviewIncomplete" },
      },
      virt_text_pos = "inline",
    })

    -- Highlight priority.
    local prio = string.match(line, "^%(%u%)")
    if prio ~= nil then
      local priority_hl_groups = {
        ["(A)"] = "TodoviewPrioA",
        ["(B)"] = "TodoviewPrioB",
        ["(C)"] = "TodoviewPrioC",
        ["(D)"] = "TodoviewPrioD",
      }
      vim.api.nvim_buf_set_extmark(buf, ns_id, line_nr, char, {
        end_col = 3,
        hl_group = priority_hl_groups[prio] or "TodoviewPrioDefault",
      })
    end
  end
end

---Render the current buffer if rendering is enabled and the filetype is "todotxt".
---@param buf? integer buffer ID
function M.render_buf(buf)
  buf = normalize_buf_id(buf)

  if vim.bo[buf].filetype == "todotxt" then
    local ns_id = vim.api.nvim_create_namespace("TodoviewExtmarks")

    -- Reset before rendering.
    vim.api.nvim_buf_clear_namespace(buf, ns_id, 0, -1)

    if state.rendering then
      for i, line in ipairs(vim.api.nvim_buf_get_lines(buf, 0, -1, true)) do
        render_line(line, buf, ns_id, i - 1)
      end
    end
  end
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
  vim.api.nvim_create_autocmd({ "BufEnter", "TextChanged", "InsertLeave" }, {
    group = augroup,
    callback = function(args)
      M.render_buf(args.buf)
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
  cfg = vim.tbl_deep_extend("force", opts, cfg)

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
