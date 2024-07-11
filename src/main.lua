local window = require("window")

local state = window.init()
while state.run do
    window.update(state)
    window.draw(state)
end
window.deinit(state)
