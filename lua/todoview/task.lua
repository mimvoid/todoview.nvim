local M = {}

---@class todoview.TaskNode
---@field text string
---@field start_col integer 0-based start column index, inclusive
---@field end_col integer 0-based end column index, exclusive
---@field time? integer the text parsed into a timestamp, if successful

---@class todoview.Task
---@field completed boolean
---@field priority? todoview.TaskNode
---@field completion_date? todoview.TaskNode
---@field creation_date? todoview.TaskNode
---@field projects todoview.TaskNode[]
---@field contexts todoview.TaskNode[]
---@field key_values table<string, todoview.TaskNode>

---Length of a date string in YYYY-MM-DD (%Y-%m-%d) format.
DATE_LEN = 10

---@param str string
---@return todoview.Task
function M.parse_task(str)
  local col = 0
  local task = {
    completed = false,
    projects = {},
    contexts = {},
    key_values = {},
  }

  if string.sub(str, 1, 2) == "x " then
    task.completed = true
    col = col + 2
  end

  local priority = string.match(string.sub(str, col + 1, col + 4), "^%(%u%) $")
  if priority ~= nil then
    task.priority = {
      text = string.sub(priority, 1, -2),
      start_col = col,
      end_col = col + 3,
    }
    col = col + 4
  end

  local date_pattern = "^%d%d%d%d%-%d%d%-%d%d% $"
  local date = str:sub(col + 1, col + 1 + DATE_LEN):match(date_pattern)
  local parse_time = require("todoview.time").parse_time

  if date then
    local date_node = {
      text = date:sub(1, -2),
      start_col = col,
      end_col = col + DATE_LEN,
    }
    date_node.time = parse_time(date_node.text)
    col = col + 1 + DATE_LEN

    if task.completed then
      -- Found completion date
      task.completion_date = date_node

      local creation_date = str:sub(col + 1, col + 1 + DATE_LEN):match(date_pattern)
      if creation_date then
        task.creation_date = {
          text = creation_date:sub(1, -2),
          start_col = col,
          end_col = col + DATE_LEN,
        }
        task.creation_date.time = parse_time(task.creation_date.text)
        col = col + 1 + DATE_LEN
      end
    else
      -- Found creation date
      task.creation_date = date_node
    end
  end

  -- Find projects, contexts, and key-value pairs.
  for word in string.gmatch(string.sub(str, col + 1), "([^ ]+)") do
    local len = vim.fn.strchars(word)

    local first_char = string.sub(word, 1, 1)
    if first_char == "+" then
      table.insert(task.projects, {
        text = word,
        start_col = col,
        end_col = col + len,
      })
    elseif first_char == "@" then
      table.insert(task.contexts, {
        text = word,
        start_col = col,
        end_col = col + len,
      })
    else
      local key, value = string.match(word, "([^:]+):([^:]+)")
      if key and value then
        task.key_values[key] = {
          text = value,
          start_col = col,
          end_col = col + len,
          time = parse_time(value),
        }
      end
    end

    col = col + len + 1
  end

  return task
end

return M
