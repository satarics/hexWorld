-- worldgen.lua
local simplex = require("lib.simplex")

local worldgen = {}

function worldgen.generateWorld(settings)

    -- Создание сетки
    local function initGrid(mapData, settings)
        local gridSize = settings.gridSize
        if gridSize % 2 ~= 1 then gridSize = gridSize + 1 end
    
        local gridHalf = math.floor(gridSize / 2)
        local gridSizeMin = gridSize - gridHalf
        local gridSizeMax = gridSize + gridHalf + 2
        local squareGrid = gridSize * gridSize - gridHalf * (gridHalf + 1)
        
        mapData.grid = {}
        mapData.gridData = {
            gridSize = gridSize,
            gridHalf = gridHalf,
            gridSizeMin = gridSizeMin,
            gridSizeMax = gridSizeMax,
            squareGrid = squareGrid
        }
    
        for i = 1, gridSize do
            for j = 1, gridSize do
                if i + j > gridSizeMin and i + j < gridSizeMax then
                    mapData.grid[i + j * gridSize] = true
                end
            end
        end
    end
    
    -- Размещение центров плит
    local function placePlateCenters(mapData, settings)
        mapData.plats = {}
        mapData.filledCells = {}
    
        local grid = mapData.grid
    
        local count = settings.platsNum
        local gridSize = settings.gridSize

        local ivec = settings.ivec
        local jvec = settings.jvec
    
        local cycle = 1
        while cycle <= count do
            local rand = math.random(1 + gridSize, gridSize * gridSize)
            if grid[rand] and not mapData.filledCells[rand] then
                mapData.plats[cycle] = {}
                mapData.plats[cycle][rand] = true
                mapData.filledCells[rand] = cycle
                cycle = cycle + 1
            end
        end
    end
    
    -- Расширение плит
    local function growPlates(mapData, settings)
        local grid, plats, filledCells = mapData.grid, mapData.plats, mapData.filledCells

        local gridSize = settings.gridSize
        local getNeighbors = settings.getNeighbors

        local pool = {}

        for index, _ in pairs(filledCells) do
            table.insert(pool, index)
        end

        while 0 < #pool do
            local index = math.random(1, #pool)
            local cellIndex = pool[index]

            local i = cellIndex % gridSize
            local j = (cellIndex - i) / gridSize

            local neighbors = getNeighbors(i, j)

            while 0 < #neighbors do
                local rand = math.random(1, #neighbors)
                local neighbor = neighbors[rand]
                local ni, nj = neighbor[1], neighbor[2]
                local neighborIndex = ni + nj * gridSize

                if grid[neighborIndex] and not filledCells[neighborIndex] and not (ni < 1 or gridSize < ni or nj < 1 or gridSize < nj) then
                    plats[filledCells[cellIndex]][neighborIndex] = true
                    filledCells[neighborIndex] = filledCells[cellIndex]

                    table.insert(pool, neighborIndex)
                else
                    table.remove(neighbors, rand)
                end
            end
            if #neighbors == 0 then
                table.remove(pool, index)
            end
        end
    end
    
    -- Определение высоты и угла плит
    local function calculatePlateData(mapData, settings)
        mapData.platsData = {}
    
        local plats = mapData.plats
    
        local gridSize = settings.gridSize
        local scale = settings.heightScale
        local seed = settings.seedNum
    
        local ivec = settings.ivec
        local jvec = settings.jvec

        for i = 1, #plats do
            local plat = plats[i]

            -- Находим центр плиты
            local platCenterX, platCenterY = 0, 0
            local platSize = 0
            for cellIndex, _ in pairs(plat) do
                local cellX = cellIndex % gridSize
                local cellY = (cellIndex - cellX) / gridSize
                platCenterX = platCenterX + cellX
                platCenterY = platCenterY + cellY
                platSize = platSize + 1
            end

            mapData.platsData[i] = {} 
            mapData.platsData[i].centerX = platCenterX / platSize
            mapData.platsData[i].centerY = platCenterY / platSize

            mapData.platsData[i].centerX = (ivec.x * mapData.platsData[i].centerX + jvec.x * mapData.platsData[i].centerY)
            mapData.platsData[i].centerY = (ivec.y * mapData.platsData[i].centerX + jvec.y * mapData.platsData[i].centerY)
    
            local noiseValue = (simplex.Noise3D(mapData.platsData[i].centerX * scale, mapData.platsData[i].centerY * scale, seed) + 1) / 2
         
            mapData.platsData[i].height = noiseValue
            mapData.platsData[i].angle = math.random(1, 6)
        end
    end
    
    -- Определение суши
    local function defineLand(mapData, settings)
        mapData.land = {}
    
        local plats = mapData.plats

        local heightLevel = settings.heightLevel
    
        for i = 1, #plats do
            local plat = plats[i]

            local isLand = mapData.platsData[i].height <= heightLevel

    
            for cellIndex, _ in pairs(plat) do
                mapData.land[cellIndex] = isLand
            end
        end
    end
    
    -- Генерация гор
    local function generateMountains(mapData, settings)
        mapData.mountains = {}
    
        local plats, land = mapData.plats, mapData.land
        local platsData = mapData.platsData
    
        local gridSize = settings.gridSize
        local getNeighbors = settings.getNeighbors
    
        for i = 1, #plats do
            local plat = plats[i]
            local platData = platsData[i]
            for cellIndex, _ in pairs(plat) do
                local count = 0
                local i = cellIndex % gridSize
                local j = (cellIndex - i) / gridSize
    
                for num, neighbor in ipairs(getNeighbors(i, j)) do
                    local ni, nj = neighbor[1], neighbor[2]
                    local neighborIndex = ni + nj * gridSize
    
                    if not plat[neighborIndex] and land[neighborIndex] and (num == platData.angle or num == (platData.angle % 6 + 1)) then
                        count = count + 1
                    end
                end
    
                if land[cellIndex] and count >= 1 then
                    mapData.mountains[cellIndex] = 2
                else
                    mapData.mountains[cellIndex] = false
                end
            end
        end
    end
    
    -- Генерация холмов
    local function generateHills(mapData, settings)
        local grid = mapData.grid
        local mountains = mapData.mountains
        local land = mapData.land
        
        local gridSize = settings.gridSize
        local haloHillSize = settings.haloHillSize
        local hillScale = settings.hillScale
        local hillLevel = settings.hillLevel
        local seed = settings.seedNum
    
        local ivec = settings.ivec
        local jvec = settings.jvec
    
        local getNeighbors = settings.getNeighbors
    
    
        local queue = {}
        local visited = {}
    
        -- Добавляем все клетки с горами в очередь и помечаем их как посещенные
        for index, _ in pairs(mountains) do
            if mountains[index] and mountains[index] > 1 then 
                table.insert(queue, index)
                visited[index] = true
            end
        end
    
        local distance = 0
        while #queue > 0 and distance < haloHillSize do
            local levelSize = #queue  -- Количество клеток на текущем уровне
    
            for i = 1, levelSize do
                local currentCell = table.remove(queue, 1)
                local cellX = currentCell % gridSize
                local cellY = (currentCell - cellX) / gridSize

                for _, neighbor in ipairs(getNeighbors(cellX, cellY)) do
                    local ni, nj = neighbor[1], neighbor[2]
                    local neighborIndex = ni + nj * gridSize

                    if grid[neighborIndex] and not visited[neighborIndex] and not mountains[neighborIndex] and land[neighborIndex] then 
                        table.insert(queue, neighborIndex)
                        visited[neighborIndex] = true

                        mountains[neighborIndex] = 1
                    end
                end
            end
    
            distance = distance + 1
        end
    
        for cellIndex, _ in pairs(land) do
            local i = cellIndex % gridSize
            local j = (cellIndex - i) / gridSize
            local centerX = (ivec.x * i + jvec.x * j)
            local centerY = (ivec.y * i + jvec.y * j)
    
            local height = (simplex.Noise3D(centerX * hillScale * 4, centerY * hillScale * 4, seed) + 1) / 2
            if height > hillLevel and mountains[cellIndex] == false and land[cellIndex] then mountains[cellIndex] = 1 end
        end
    end

    -- Генерация карты высоты
    local function heightMapGen(mapData, settings)
        mapData.height = {}

        local grid = mapData.grid
        local mountains = mapData.mountains

        local gridSize = settings.gridSize

        local getNeighbors = settings.getNeighbors

        local queue = {}
        local visited = {}
    
        -- Добавляем все клетки с горами в очередь и помечаем их как посещенные
        for index, _ in pairs(mountains) do
            if mountains[index] and mountains[index] == 2 then 
                table.insert(queue, index)
                visited[index] = true
                mapData.height[index] = 0
            end
        end

        local distance = 1
        while #queue > 0 do
            local levelSize = #queue
    
            for i = 1, levelSize do
                local currentCell = table.remove(queue, 1)
                local cellX = currentCell % gridSize
                local cellY = (currentCell - cellX) / gridSize
    
                for _, neighbor in ipairs(getNeighbors(cellX, cellY)) do
                    local ni, nj = neighbor[1], neighbor[2]
                    local neighborIndex = ni + nj * gridSize
    
                    if grid[neighborIndex] and not visited[neighborIndex] then 
                        table.insert(queue, neighborIndex)
                        visited[neighborIndex] = true
        
                        mapData.height[neighborIndex] = distance
                    end
                end
            end
    
            distance = distance + 1
        end
    end

    -- Генерация рек и озёр
    local function riversGen(mapData, settings)
        mapData.rivers = {}
        mapData.lake = {}

        local mountains = mapData.mountains
        local land = mapData.land
        local height = mapData.height
        local grid = mapData.grid

        local gridSize = settings.gridSize
        local riverStartProbability = settings.riverStartProbability

        local getNeighbors = settings.getNeighbors

        for startIndex, mountain in pairs(mountains) do
            if mountain == 2 and math.random() < riverStartProbability then
                local index = startIndex -- Индекс фронта реки 
                local thisRiver = {} -- Клетки с текущей рекой
                
                local undo = false -- Переменная указывеющая на то требуется ли удалить текущау реку

                -- Шагаем пока не достигаем воды или не выподаем в озеро
                while land[index] and not mapData.lake[index] do
                    thisRiver[index] = true
                    local cellX = index % gridSize
                    local cellY = (index - cellX) / gridSize

                    -- Осматриваем соседей фронта реки и выбераем наиболее верятные
                    local variants = {}
                    local neighbors = getNeighbors(cellX, cellY)
                    for trajectory, neighbor in ipairs(neighbors) do
                        local ni, nj = neighbor[1], neighbor[2]
                        local neighborIndex = ni + nj * gridSize
                        if not thisRiver[neighborIndex] and grid[neighborIndex]  then
                            if height[neighborIndex] == height[index] then
                                table.insert(variants, trajectory)
                            elseif height[neighborIndex] > height[index] then
                                table.insert(variants, trajectory)
                                table.insert(variants, trajectory)
                                table.insert(variants, trajectory)
                            end
                        end
                    end

                    if #variants == 0 then
                        local targetLevel = height[index]
                        
                        local queue = {}; table.insert(queue, index)
                        local visited = {}

                        while #queue > 0 do
                            local currentCell = table.remove(queue, 1)
                            local cellX = currentCell % gridSize
                            local cellY = (currentCell - cellX) / gridSize
                
                            for _, neighbor in ipairs(getNeighbors(cellX, cellY)) do
                                local ni, nj = neighbor[1], neighbor[2]
                                local neighborIndex = ni + nj * gridSize
                
                                if grid[neighborIndex] and height[neighborIndex] >= targetLevel and not visited[neighborIndex] and land[neighborIndex]  then 
                                    table.insert(queue, neighborIndex)
                                    visited[neighborIndex] = true
                                elseif not land[neighborIndex] then
                                    undo = true
                                end
                            end
                        end

                        if not undo then
                            for lakeIndex, _ in pairs(visited) do 
                                mapData.lake[lakeIndex] = true
                                mapData.rivers[lakeIndex] = nil
                            end                            
                        end

                        break
                    end

                    local variant = variants[math.random(#variants)]
                    local ni, nj = neighbors[variant][1], neighbors[variant][2]
                    local neighborIndex = ni + nj * gridSize

                    if mapData.rivers[index] or not grid[index] then break end

                    mapData.rivers[index] = variant
                    index = neighborIndex
                end

                if undo then
                    for riverIndex, __ in pairs(thisRiver) do
                        mapData.rivers[riverIndex] = nil
                    end
                end
            end
        end
    end
        
    -- Генерация ландшафта (биомов)
    local function generateBiomes(mapData, settings)

        mapData.biome = {}
        mapData.features = {}

        local grid = mapData.grid
        local land = mapData.land
        local rivers = mapData.rivers
        local lake = mapData.lake

        local gridSize = settings.gridSize
        local scale = settings.heightScale
        local seed = settings.seedNum
        local ivec = settings.ivec
        local jvec = settings.jvec

        local getNeighbors = settings.getNeighbors

        -- Функция для определения базового биома по температуре
        local function getBiomeByTemperature(temperature, humidity)
            local baseBiomes = {-math.huge, 0.38, 0.45, 0.53, 0.60} -- Снег -> Пустыня 1-5
            local baseHumidity = {-math.huge, 0.25, 0.50, 0.75} -- Сухо -> Влажно 1-4
            local outBiome, outHumidity = 1, 1 -- начинаем с индекса 1, чтобы избежать выхода за пределы массива
        
            -- Итерируемся по таблице температур
            for i = #baseBiomes, 1, -1 do
                if temperature >= baseBiomes[i] then
                    outBiome = i
                    break
                end
            end
        
            -- Итерируемся по таблице влажности
            for i = #baseHumidity, 1, -1 do
                if humidity >= baseHumidity[i] then
                    outHumidity = i
                    break
                end
            end
        
            return outBiome, outHumidity
        end

        for cellIndex, _ in pairs(grid) do
            local i = cellIndex % gridSize
            local j = (cellIndex - i) / gridSize

            local centerX = (ivec.x * i + jvec.x * j) 
            local centerY = (ivec.y * i + jvec.y * j) 

            local temperature = ((simplex.Noise3D(centerX * scale * 0.75, centerY * scale * 0.75, seed + 8) * 2 + simplex.Noise3D(centerX * scale * 0.1, centerY * scale * 0.1, seed + 16)) / 3 + 1) / 2
            local humidity = (simplex.Noise3D(centerX * scale * 0.5, centerY * scale * 0.5, seed + 24) + 1) / 2
            local isForest = (simplex.Noise3D(centerX * scale * 0.5, centerY * scale * 0.5, seed + 32) + 1) / 2

            local biome, humid = getBiomeByTemperature(temperature, humidity)

            if (rivers[cellIndex] or lake[cellIndex]) and biome == 5 then
                biome = 4
            end

            if land[cellIndex] then
                mapData.biome[cellIndex] = biome
            else
                local isCoast = false
                local cellX = cellIndex % gridSize
                local cellY = (cellIndex - cellX) / gridSize
                for _, neighbor in ipairs(getNeighbors(cellX, cellY)) do
                    local ni, nj = neighbor[1], neighbor[2]
                    local neighborIndex = ni + nj * gridSize

                    if grid[neighborIndex] and land[neighborIndex] then isCoast = true end
                end
                if isCoast then
                    mapData.biome[cellIndex] = -1 -- Побережье(Море)
                else
                    mapData.biome[cellIndex] = -2 -- Океан
                end
            end

            --[[
            1 - Сухой лес (Саванна)
            2 - Лиственный лес
            3 - Смешаный лес
            4 - Хвойный лес
            5 - Болото
            ]]

            if isForest > 0.55 and land[cellIndex] then
                if biome == 4 and humid <= 2 then
                    mapData.features[cellIndex] = 1
                elseif biome == 4 and humid > 2 then
                    mapData.features[cellIndex] = 2
                elseif biome == 3 and humid == 1 then
                    mapData.features[cellIndex] = 2
                elseif biome == 3 and humid == 2 then
                    mapData.features[cellIndex] = 3
                elseif biome == 3 and humid == 3 then
                    mapData.features[cellIndex] = 4
                elseif biome == 3 and humid == 4 then
                    mapData.features[cellIndex] = 5
                elseif biome == 2 and humid <= 2 then
                    mapData.features[cellIndex] = 4
                elseif biome == 2 and humid > 2 then
                    mapData.features[cellIndex] = 5
                else 
                    mapData.features[cellIndex] = false
                end
            else
                mapData.features[cellIndex] = false
            end
        end
    end

    math.randomseed(settings.seedNum)

    local mapData = {}
    
    print("initGrid")
    initGrid(mapData, settings)
    print("placePlateCenters")
    placePlateCenters(mapData, settings)
    print("growPlates")
    growPlates(mapData, settings)
    print("calculatePlateData")
    calculatePlateData(mapData, settings)
    print("defineLand")
    defineLand(mapData, settings)
    print("generateMountains")
    generateMountains(mapData, settings)
    print("generateHills")
    generateHills(mapData, settings)
    print("heightMapGen")
    heightMapGen(mapData, settings)
    print("riversGen")
    riversGen(mapData, settings)
    print("generateBiomes")
    generateBiomes(mapData, settings)

    return mapData
end

-- Настройки по умолчанию
worldgen.defaultSettings = {
    getNeighbors = function(i, j)
        return {
            {i + 1, j}, {i, j + 1}, {i - 1, j + 1},
            {i - 1, j}, {i, j - 1}, {i + 1, j - 1}
        }
    end,

    ivec = {x = math.sqrt(3)/2, y = 1/2},
    jvec = {x = 0, y = 1},

    gridSize = 63,

    platsNum = nil, -- Рассчитывается автоматически, если не указано
    seed = "QWERTY",

    heightScale = 0.1,
    heightLevel = 0.5,
    hillScale = 3,
    hillLevel = 0.55,
    haloHillSize = 2, 
    riverStartProbability = 0.35

}

-- Функция для применения настроек
function worldgen.applySettings(settings)
    settings = settings or {}
    for k, v in pairs(worldgen.defaultSettings) do
        if settings[k] == nil then 
            settings[k] = v 
        end
    end

    -- Автоматический расчет platsNum 
    if settings.platsNum == nil then
        settings.platsNum = math.ceil(settings.gridSize / math.sqrt(3) * 2)
    end

    -- Хэширование seed
    settings.seedNum = worldgen.hash(settings.seed)
    return settings
end

-- Функция хэширования
function worldgen.hash(str)
    local hash = 0
    for i = 1, #str do
        hash = (hash * 31 + string.byte(str, i)) % 2^32
    end
    return hash
end

return worldgen