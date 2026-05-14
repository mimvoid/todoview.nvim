local M = {}

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

---Gets whether the time stored in the `task_node`, if any, is before the time given by `os.time()`.
---@param task_node todoview.TaskNode?
---@return boolean `true` if `task_node.time` exists and is less than `os.time()`.
function M.is_before_now(task_node)
  return task_node ~= nil and task_node.time ~= nil and task_node.time < os.time()
end

return M
