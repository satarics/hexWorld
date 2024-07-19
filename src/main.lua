local window = require("window")

local state = window.init()
while state.run do
    window.cycle(state)
end
window.deinit(state)
