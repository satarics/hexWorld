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

        run = true,
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

    rl.SetConfigFlags(rl.FLAG_VSYNC_HINT)
    rl.InitWindow(state.screenWidth, state.screenHeight, "Hex World")
    rl.SetTargetFPS(120)

    -- Фаблица функций поддреживающих буффер
    local function bufferFabricDraw(drawFunc, Factor, Clarity)
        local bufferCamera = rl.new("Camera2D", {
            offset = rl.new("Vector2", 0, 0),
            target = rl.new("Vector2", 0, 0),
            rotation = 0,
            zoom = 1
        })

        local reRender = true -- Требуется ли перерисовка буффера
        local reSizeBuffer = true -- Требуется ли обновить буффер
        local wasWindowResized = false -- Был ли изменён размер окна в прошлом кадре

        local bufferFactor = Factor or 3 -- Размер буффура экрана
        local bufferClarity = Clarity or 3 -- Множитель разрешения буффера экрана

        local buffer = rl.LoadRenderTexture(0, 0)

        return function (state)   
            -- Проверка на изменение размера экрана 
            if rl.IsWindowResized() and not wasWindowResized then -- Изменяется ли сеё час экран
                wasWindowResized = true
            elseif not rl.IsWindowResized() and wasWindowResized then -- Закончл ли он изменение
                reSizeBuffer = true
                wasWindowResized = false
                reRender = true

                state.screenWidth, state.screenHeight = rl.GetScreenWidth(), rl.GetScreenHeight()
            end

            -- Обноаляем размер буффера
            if reSizeBuffer then
                rl.UnloadRenderTexture(buffer)
                buffer = rl.LoadRenderTexture(state.screenWidth * bufferFactor * bufferClarity, state.screenHeight * bufferFactor * bufferClarity)

                reSizeBuffer = false
            end

            -- Проверка на обновление буффера
            local worldMin = rl.GetScreenToWorld2D(rl.new("Vector2", 0, 0), state.camera)
            local worldMax = rl.GetScreenToWorld2D(rl.new("Vector2", state.screenWidth, state.screenHeight), state.camera)

            local bufferMin = rl.GetScreenToWorld2D(rl.new("Vector2", 0, 0), bufferCamera)
            local bufferMax = rl.GetScreenToWorld2D(rl.new("Vector2", state.screenWidth * bufferFactor * bufferClarity, state.screenHeight * bufferFactor * bufferClarity), bufferCamera)
            local bufferSize = rl.Vector2Subtract(bufferMax, bufferMin)
            local bufferPos = bufferMin

            if worldMin.x < bufferMin.x or worldMin.y < bufferMin.y or 
            worldMax.x > bufferMax.x or worldMax.y > bufferMax.y or
            state.camera.zoom > bufferCamera.zoom
            then
                reRender = true

                bufferCamera.offset = rl.Vector2Scale(state.camera.offset, bufferFactor * bufferClarity)
                bufferCamera.target = rl.Vector2Scale(state.camera.target, 1)
                bufferCamera.zoom = state.camera.zoom * bufferClarity
            end

            print(reRender, reSizeBuffer, wasWindowResized)

            -- РИСОВАНИЕ 

            if reRender then
                rl.BeginTextureMode(buffer)
                    rl.ClearBackground(rl.WHITE)
                    rl.BeginMode2D(bufferCamera)
                        drawFunc(state.map)
                    rl.EndMode2D()
                rl.EndTextureMode()
        
                reRender = false
            end
        
            rl.BeginDrawing()
                rl.ClearBackground(rl.WHITE)
        
                rl.BeginMode2D(state.camera)
                    local source = rl.new("Rectangle", 0, 0, buffer.texture.width, -buffer.texture.height)
                    local dest = rl.new("Rectangle", bufferPos.x, bufferPos.y, bufferSize.x, bufferSize.y)
                    rl.DrawTexturePro(buffer.texture, source, dest, rl.Vector2Zero(), 0, rl.WHITE)
                rl.EndMode2D()
        
                rl.DrawFPS(0, 0)
            rl.EndDrawing()
            
        end
    end

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

    state.drawFunc = bufferFabricDraw(drawColoredMap, 2, 2)

    return state
end

function window.cycle(state)
    state.screenWidth, state.screenHeight = rl.GetScreenWidth(), rl.GetScreenHeight()

    -- Закрвтие окна
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

    state.drawFunc(state)

end


function window.deinit(state)
    rl.CloseWindow()
end

return window