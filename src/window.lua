local worldgen = require("worldGen")

local window = {}

window.biomeColor = {
    [-2] = rl.new("Color", 53, 62, 103, 255), -- Океан
    [-1] = rl.new("Color", 25, 98, 143, 255), -- Побережье
    [1] = rl.new("Color", 211, 232, 249, 255), -- Снег
    [2] = rl.new("Color", 168, 152, 101, 255), -- Тундра
    [3] = rl.new("Color", 125, 157, 52, 255), -- Равнина
    [4] = rl.new("Color", 164, 170, 60, 255), -- Луг
    [5] = rl.new("Color", 239, 204, 113, 255)  -- Пустыня
}

window.mountainColor = {
    [false] = rl.new("Color", 0, 0, 0, 0), -- Не горы
    [1] = rl.new("Color", 139, 69, 19, 45), -- Холмы
    [2] = rl.new("Color", 75, 75, 75, 255)  -- Горы
}

window.featureColor = {
    [false] = rl.new("Color", 0, 0, 0, 0),
    [1] = rl.new("Color", 218, 153, 53, 255), -- Сухой лес (саванна)
    [2] = rl.new("Color", 109, 137, 33, 255), -- Лиственный лес
    [3] = rl.new("Color", 111, 161, 30, 255), -- Смешанный лес
    [4] = rl.new("Color", 60, 111, 60, 255), -- Хвойный лес
    [5] = rl.new("Color", 178, 198, 109, 255), -- Болото
}

function window.init()
    local state = {
        screenWidth = 800,
        screenHeight = 600,
    
        sizeGrid = 100, -- Расстояние между ячейками
    
        ivec = {x = math.sqrt(3)/2, y = 1/2}, -- Вектор направления вправо-вверх
        jvec = {x = 0, y = 1}, -- Вектор направления вниз
    
        gridSize = 267, -- Размер сетки

        bufferFactor = 2, -- Размер буффура экрана
        bufferClarity = 2, -- Множитель разрешения буффера экрана

        run = true,

        reRender = true -- Требуется ли перерисовка буффера
    }
    state.drawSizeGrid = (state.sizeGrid / math.sqrt(3)) -- Размер ячеек

    state.genConfig = {gridSize = state.gridSize}

    -- Генерируем мир с использованием настроек по умолчанию или пользовательских настроек
    state.map = worldgen.generateWorld(worldgen.applySettings(state.genConfig)) 

    -- Инициализация камеры
    state.camera = rl.new("Camera2D", {
        offset = rl.new("Vector2", state.screenWidth / 2, state.screenHeight / 2),
        target = rl.new("Vector2", 0, 0),
        rotation = 0,
        zoom = 1
    })
    
    state.bufferCamera = rl.new("Camera2D", {
        offset = rl.new("Vector2", 0, 0),
        target = rl.new("Vector2", 0, 0),
        rotation = 0,
        zoom = 1
    })

    rl.SetConfigFlags(rl.FLAG_VSYNC_HINT)
    rl.InitWindow(state.screenWidth, state.screenHeight, "Hex World")
    rl.SetTargetFPS(120)

    state.buffer = rl.LoadRenderTexture(state.screenWidth * state.bufferFactor * state.bufferClarity, state.screenHeight * state.bufferFactor * state.bufferClarity)

    return state
end

function window.update(state)

    if rl.WindowShouldClose() then
        state.run = false
    end
    
    -- Управление камерой
    if rl.IsMouseButtonDown(rl.MOUSE_BUTTON_LEFT) then
        local delta = rl.GetMouseDelta()
        delta = rl.Vector2Scale(delta, -1 / state.camera.zoom)
        state.camera.target = rl.Vector2Add(state.camera.target, delta)
    end

    -- Приближение отдалене
    local wheel = rl.GetMouseWheelMove()
    if wheel ~= 0 then
        local mousePos = rl.GetMousePosition()
        local mouseWorldPos = rl.GetScreenToWorld2D(mousePos, state.camera)
        state.camera.offset = mousePos
        state.camera.target = mouseWorldPos
        local scaleFactor = 1 + (0.1 * math.abs(wheel))
        if wheel < 0 then
            scaleFactor = 1 / scaleFactor
        end
        state.camera.zoom = rl.Clamp(state.camera.zoom * scaleFactor, 0.001, 100)
    end

    -- Проверка на обновление буффера
    local worldMin = rl.GetScreenToWorld2D(rl.new("Vector2", 0, 0), state.camera)
    local worldMax = rl.GetScreenToWorld2D(rl.new("Vector2", state.screenWidth, state.screenHeight), state.camera)

    local bufferMin = rl.GetScreenToWorld2D(rl.new("Vector2", 0, 0), state.bufferCamera)
    local bufferMax = rl.GetScreenToWorld2D(rl.new("Vector2", state.screenWidth * state.bufferFactor * state.bufferClarity, state.screenHeight * state.bufferFactor * state.bufferClarity), state.bufferCamera)
    state.bufferSize = rl.Vector2Subtract(bufferMax, bufferMin)
    state.bufferPos = bufferMin

    if worldMin.x < bufferMin.x or worldMin.y < bufferMin.y or 
       worldMax.x > bufferMax.x or worldMax.y > bufferMax.y or
       state.camera.zoom > state.bufferCamera.zoom
    then
        state.reRender = true

        state.bufferCamera.offset = rl.Vector2Scale(state.camera.offset, state.bufferFactor * state.bufferClarity)
        state.bufferCamera.target = rl.Vector2Scale(state.camera.target, 1)
        state.bufferCamera.zoom = state.camera.zoom * state.bufferClarity
    end

end

function window.draw(state)

    -- Функция для рисования шестиугольника
    local function drawHexagon(centerX, centerY, biomeColor, mountainColor, featureColor)
        rl.DrawPoly(rl.new("Vector2", centerX, centerY), 6, state.drawSizeGrid, 0, biomeColor)
        rl.DrawCircle(centerX, centerY, state.drawSizeGrid*0.80, featureColor)
        rl.DrawCircle(centerX, centerY, state.drawSizeGrid*0.70, mountainColor) 
    end

    -- Функция для рисования цветных плит на основе биомов
    local function drawColoredMap(mapData)
        local grid = mapData.grid

        local biome = mapData.biome
        local mountains = mapData.mountains
        local features = mapData.features

        local rivers = mapData.rivers
        local lake = mapData.lake

        local getNeighbors = {
            {1, 0}, {0, 1}, {-1, 1},
            {-1, 0}, {0, -1}, {1, -1}
        }

        rl.DrawCircle(0, 0, state.drawSizeGrid*2, rl.RED)

        -- Сетка
        for cellIndex, _ in pairs(grid) do
            local colorA, colorB, colorC = window.biomeColor[biome[cellIndex]], window.mountainColor[mountains[cellIndex]], window.featureColor[features[cellIndex]]

            local i = (cellIndex - 1) % state.gridSize
            local j = math.floor((cellIndex - 1) / state.gridSize)

            local centerX = state.sizeGrid * (state.ivec.x * i + state.jvec.x * j)
            local centerY = state.sizeGrid * (state.ivec.y * i + state.jvec.y * j)
            
            drawHexagon(centerX, centerY, colorA, colorB, colorC)

            if lake[cellIndex] then
                rl.DrawCircle(centerX, centerY, state.drawSizeGrid*0.7, rl.SKYBLUE); 
            end
        end

        -- Реки
        for cellIndex, _ in pairs(grid) do
            local i = (cellIndex - 1) % state.gridSize
            local j = math.floor((cellIndex - 1) / state.gridSize)

            local centerX = state.sizeGrid * (state.ivec.x * i + state.jvec.x * j)
            local centerY = state.sizeGrid * (state.ivec.y * i + state.jvec.y * j)

            if rivers[cellIndex] then
                local neighbor = getNeighbors[rivers[cellIndex]]
                local ni, nj = neighbor[1], neighbor[2]

                local endX = centerX + state.sizeGrid * (state.ivec.x * ni + state.jvec.x * nj)
                local endY = centerY + state.sizeGrid * (state.ivec.y * ni + state.jvec.y * nj)
                rl.DrawLineEx(rl.new("Vector2", centerX, centerY), rl.new("Vector2", endX, endY), 30, rl.DARKBLUE);
            end
        end
    end

    if state.reRender then
        rl.BeginTextureMode(state.buffer)
            rl.ClearBackground(rl.WHITE)
            rl.BeginMode2D(state.bufferCamera)
                drawColoredMap(state.map)
            rl.EndMode2D()
        rl.EndTextureMode()

        state.reRender = false
    end

    rl.BeginDrawing()
        rl.ClearBackground(rl.WHITE)

        rl.BeginMode2D(state.camera)
            local source = rl.new("Rectangle", 0, 0, state.buffer.texture.width, -state.buffer.texture.height)
            local dest = rl.new("Rectangle", state.bufferPos.x, state.bufferPos.y, state.bufferSize.x, state.bufferSize.y)
            rl.DrawTexturePro(state.buffer.texture, source, dest, rl.Vector2Zero(), 0, rl.WHITE)
        rl.EndMode2D()

        rl.DrawFPS(0, 0)
    rl.EndDrawing()

end


function window.deinit(state)
    rl.CloseWindow()
end

return window