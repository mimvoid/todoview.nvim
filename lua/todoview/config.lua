---@alias todoview.VirtText { [1]: string, [2]: string }[]
---@alias todoview.Format todoview.VirtText|string

---@class todoview.Config.Completion
---@field enable? boolean
---@field format? fun(task: todoview.Task): todoview.VirtText?

---@class todoview.Config.Priority
---@field enable? boolean Enable priority rendering
---@field format? fun(task: todoview.Task): todoview.Format?

---@class todoview.Config.Date
---@field enable? boolean Enable rendering of the date
---@field format? string|fun(task: todoview.Task, time: integer): todoview.Format?

---@class todoview.Config.Tag
---@field enable? boolean
---@field format? fun(task: todoview.Task, name: string): todoview.Format?

---@class todoview.Config
---@field default_todo_file? string
---@field set_conceallevel? boolean
---@field completion? todoview.Config.Completion
---@field priority? todoview.Config.Priority
---@field completion_date? todoview.Config.Date
---@field creation_date? todoview.Config.Date
---@field projects? todoview.Config.Tag
---@field contexts? todoview.Config.Tag
---@field key_value? todoview.Config.Tag

local M = {}

---@return todoview.Config.Completion
function M.default_completion()
  return {
    enable = true,
    format = function(task)
      if task.completed then
        return { { " ", "TodoviewCompleted" } }
      end
      if require("todoview.task").is_overdue(task) then
        return { { " ", "TodoviewOverdue" } }
      end
      return { { " ", "TodoviewPending" } }
    end
  }
end

---@return todoview.Config.Priority
function M.default_priority()
  return {
    enable = true,
    format = function(task)
      if task.completed then
        return nil
      end
      local hl_groups = {
        A = "TodoviewPrioA",
        B = "TodoviewPrioB",
        C = "TodoviewPrioC",
        D = "TodoviewPrioD",
      }
      return hl_groups[task.priority.letter] or "TodoviewPrioDefault"
    end
  }
end

function M.default_completion_date()
  return {
    enable = false,
    format = function(_task, _time)
      return "TodoviewCompletionDate"
    end
  }
end

function M.default_creation_date()
  return {
    enable = false,
    format = function(_task, _time)
      return "TodoviewCreationDate"
    end
  }
end

---@return todoview.Config.Tag
function M.default_projects()
  return {
    enable = false,
    format = function(_task, _project)
      return "TodoviewProject"
    end
  }
end

---@return todoview.Config.Tag
function M.default_contexts()
  return {
    enable = false,
    format = function(_task, _context)
      return "TodoviewContext"
    end
  }
end

---@return todoview.Config.Tag
function M.default_key_value()
  return {
    enable = false,
    format = function(task, key)
      local value_node = task.key_values.key
      return {
        { key, "TodoviewKey" },
        { ":", "TodoviewKey" },
        { value_node.text, "TodoviewValue" }
      }
    end
  }
end

---@return todoview.FullConfig
function M.default_config()
  return {
    default_todo_file = "~/todo.txt",
    set_conceallevel = true,
    completion = M.default_completion(),
    priority = M.default_priority(),
    completion_date = M.default_completion_date(),
    creation_date = M.default_creation_date(),
    projects = M.default_projects(),
    contexts = M.default_contexts(),
    key_value = M.default_key_value(),
  }
end

return M
