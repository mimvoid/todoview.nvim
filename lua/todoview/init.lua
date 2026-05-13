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
    open_icon = "",
    completed_icon = "",
  },
}

local data = {
  rendering = true,
}

local function can_render_current_buf()
  return data.rendering and vim.bo.filetype == "todotxt"
end

---Get the namespace ID for todoview, or create one if it does not exist.
local function namespace_id()
  local existing_id = vim.api.nvim_get_namespaces().todoview
  return existing_id or vim.api.nvim_create_namespace("todoview")
end

---Open the default todo file.
function M.open()
  vim.cmd.edit(cfg.default_todo_file)
end

---Toggle todoview rendering.
function M.toggle()
  if data.rendering then
    M.clear_buf()
    data.rendering = false
  else
    data.rendering = true
    M.render_buf()
  end
end

---@param line string
---@param buf integer
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
      virt_text = { { overlay, "DiagnosticSignOk" } },
      virt_text_pos = "overlay",
    })

    -- Inline the rest of the icon string.
    if rest ~= "" then
      vim.api.nvim_buf_set_extmark(buf, ns_id, line_nr, char, {
        virt_text = { { rest, "DiagnosticSignOk" } },
        virt_text_pos = "inline",
      })
    end

    char = 2
  else
    -- Completion icon.
    vim.api.nvim_buf_set_extmark(buf, ns_id, line_nr, char, {
      virt_text = {
        { cfg.completion.incomplete_icon, "DiagnosticSignWarn" },
        { " ", "DiagnosticSignWarn" },
      },
      virt_text_pos = "inline",
    })

    -- Highlight priority.
    local prio = string.match(line, "^%(%u%)")
    if prio ~= nil then
      local priority_hl_groups = {
        ["(A)"] = "DiagnosticSignError",
        ["(B)"] = "DiagnosticSignWarn",
        ["(C)"] = "DiagnosticSignInfo",
        ["(D)"] = "DiagnosticSignHint",
      }
      vim.api.nvim_buf_set_extmark(buf, ns_id, line_nr, char, {
        end_col = 3,
        hl_group = priority_hl_groups[prio] or "DiagnosticSignOk",
      })
    end
  end
end

---Render the current buffer if rendering is enabled and the filetype is "todotxt".
function M.render_buf()
  if can_render_current_buf() then
    local buf = 0
    local ns_id = namespace_id()

    for i, line in ipairs(vim.api.nvim_buf_get_lines(buf, 0, -1, true)) do
      render_line(line, buf, ns_id, i - 1)
    end
  end
end

---Clear the current buffer's render if rendering is enabled and the filetype is "todotxt".
function M.clear_buf()
  if can_render_current_buf() then
    vim.api.nvim_buf_clear_namespace(0, namespace_id(), 0, -1)
  end
end

---Refresh the current buffer's render if rendering is enabled and the filetype is "todotxt".
function M.refresh_buf()
  if can_render_current_buf() then
    M.clear_buf()
    M.render_buf()
  end
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

  -- Setup autocommands
  local augroup = vim.api.nvim_create_augroup("todoview", { clear = true })

  vim.api.nvim_create_autocmd({ "BufEnter", "InsertLeave" }, {
    group = augroup,
    callback = M.render_buf,
  })

  vim.api.nvim_create_autocmd("InsertEnter", {
    group = augroup,
    callback = M.clear_buf,
  })

  vim.api.nvim_create_autocmd("TextChanged", {
    group = augroup,
    callback = M.refresh_buf,
  })
end

return M
