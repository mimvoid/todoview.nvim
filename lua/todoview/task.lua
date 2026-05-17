local M = {}

---@class todoview.Column
---@field start_col integer 0-based start column index, inclusive
---@field end_col integer 0-based end column index, inclusive

---@class todoview.TaskNode
---@field text string The original text, or the value if a key-value pair
---@field start_col integer 0-based start column index, inclusive
---@field end_col integer 0-based end column index, inclusive

---@class todoview.Priority
---@field letter string Letter of the priority
---@field start_col integer 0-based start column index, inclusive
---@field end_col integer 0-based end column index, inclusive

---@class todoview.Task
---@field completed boolean
---@field priority? todoview.Priority
---@field completion_date? todoview.TaskNode
---@field creation_date? todoview.TaskNode
---@field projects table<string, todoview.Column>
---@field contexts table<string, todoview.Column>
---@field key_values table<string, todoview.TaskNode>
---@field is_overdue fun(self: todoview.Task, time: integer?): boolean

---Length of a date string in YYYY-MM-DD (%Y-%m-%d) format.
DATE_LEN = 10

---Try to parse a string in YYYY-MM-DD format and get its time.
---@param str string The string to parse.
---@return integer? time Result of `os.time` for the string, or `nil` on failure.
function M.parse_time(str)
  if str:sub(5, 5) == "-" and str:sub(8, 8) == "-" then
    local param = {
      year = str:sub(1, 4),
      month = str:sub(6, 7),
      day = str:sub(9),
    }

    local success, time = pcall(os.time, param)
    if success then
      return time
    end
  end
end

---@param str string
---@return todoview.Task
function M.parse_task(str)
  local col = 0
  local task = {
    completed = false,
    projects = {},
    contexts = {},
    key_values = {},
    is_overdue = M.is_overdue,
  }

  if str:sub(1, 2) == "x " then
    task.completed = true
    col = col + 2
  end

  local priority = str:sub(col + 1, col + 4):match("^%(%u%) $")
  if priority then
    task.priority = {
      letter = str:sub(col + 2, col + 2),
      start_col = col,
      end_col = col + 3,
    }
    col = col + 4
  end

  local date_pattern = "^%d%d%d%d%-%d%d%-%d%d% $"
  local date = str:sub(col + 1, col + 1 + DATE_LEN):match(date_pattern)

  if date then
    local date_node = {
      text = date:sub(1, -2),
      start_col = col,
      end_col = col + DATE_LEN,
    }
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
        col = col + 1 + DATE_LEN
      end
    else
      -- Found creation date
      task.creation_date = date_node
    end
  end

  -- Find projects, contexts, and key-value pairs.
  for word in str:sub(col + 1):gmatch("([^ ]+)") do
    local len = vim.fn.strchars(word)
    local first_char = word:sub(1, 1)

    if first_char == "+" then
      task.projects[word:sub(2)] = { start_col = col, end_col = col + len }
    elseif first_char == "@" then
      task.contexts[word:sub(2)] = { start_col = col, end_col = col + len }
    else
      local key, value = word:match("([^:]+):([^:]+)")
      if key and value then
        task.key_values[key] = {
          text = value,
          start_col = col,
          end_col = col + len,
          time = M.parse_time(value),
        }
      end
    end

    col = col + len + 1
  end

  return task
end

---Gets whether the time stored in the `task_node`, if any, is before the time given by `os.time()`.
---@param task_node todoview.TaskNode?
---@param time integer?  The current time, or `os.time()` by default.
---@return boolean `true` if `task_node.time` exists and is less than `time`.
function M.is_before(task_node, time)
  time = time or os.time()
  if task_node then
    local node_time = M.parse_time(task_node.text)
    if node_time then
      return node_time < time
    end
  end
  return false
end

---@param task todoview.Task
---@param time integer? The current time, or `os.time()` by default.
function M.is_overdue(task, time)
  return not task.completed and M.is_before(task.key_values.due, time)
end

return M
