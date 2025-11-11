local input = {}
---@type table<string, boolean>
local keysdown = {}

function love.keypressed(key)
  keysdown[key] = true
end

function love.keyreleased(key)
  keysdown[key] = false
end

function input.isdown(key)
  return keysdown[key] and keysdown[key] == true
end

function input.isup(key)
  return not keysdown[key] or keysdown[key] == false
end

return input
