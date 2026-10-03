-- ARASAKA HUB V3 - MODULAR SINGLE-FILE BUILD
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local Debris = game:GetService("Debris")
local VirtualUser = game:GetService("VirtualUser")
local TeleportService = game:GetService("TeleportService")

local player = Players.LocalPlayer

--==================================================
-- ARASAKA HUB V3 // SINGLE-FILE MODULAR ARCHITECTURE
-- Um único .lua, porém cada domínio vive em seu próprio módulo/tabela.
--==================================================
local Utils = { Name = "Utils", PerfMarks = {} }
local Core = {
    Name = "Core",
    Modules = {},
    States = {},
    Connections = {},
    Cleanups = {},
    Workers = {},
    WorkerGeneration = {},
    Config = { notifications = true, compactStatus = false },
    Version = "V3-MODULAR-2.0",
    StartedAt = os.clock(),
}
local UI = { Name = "UI" }
local Farms = { Name = "Farms" }
local Pets = { Name = "Pets" }
local Kill = { Name = "Kill", State = { mode = nil, excludeFriends = false, selectedTarget = nil, excludedUserIds = {} } }
local Visual = { Name = "Visual" }
local Chat = { Name = "Chat", Initialized = false, Loading = false }
local Teleports = { Name = "Teleports" }
local Calculator = { Name = "Calculator" }
local System = { Name = "System" }
local ProcessControlModule

-- ÚNICA PONTE GLOBAL: serve apenas para invalidar/limpar uma execução anterior.
-- Todo o estado funcional continua local em Core/módulos.
local Bridge = rawget(_G, "ArasakaBridge")
if type(Bridge) ~= "table" then
    Bridge = { generation = 0 }
    rawset(_G, "ArasakaBridge", Bridge)
end
if type(Bridge.cleanup) == "function" then
    pcall(Bridge.cleanup)
end
Bridge.generation = (Bridge.generation or 0) + 1
local RUN_GENERATION = Bridge.generation
local Runtime = { Running = true }

-- Compatibilidade: encerra versões antigas que ainda usavam vários _G.Arasaka*.
if rawget(_G, "ArasakaScriptRunning") ~= nil then
    rawset(_G, "ArasakaScriptRunning", false)
end
if rawget(_G, "ArasakaKillWorkerToken") ~= nil then
    rawset(_G, "ArasakaKillWorkerToken", (rawget(_G, "ArasakaKillWorkerToken") or 0) + 1)
end
task.wait(0.01)
rawset(_G, "ArasakaScriptRunning", nil)
rawset(_G, "ArasakaKeyWatcherRunning", nil)
rawset(_G, "ArasakaKillState", nil)
rawset(_G, "ArasakaKillWorkerToken", nil)
rawset(_G, "ArasakaCore", nil)
rawset(_G, "ArasakaProcessControl", nil)
rawset(_G, "ArasakaPerf", nil)
rawset(_G, "ArasakaPerfBegin", nil)
rawset(_G, "ArasakaPerfEnd", nil)

function Core:IsAlive()
    return Runtime.Running == true and Bridge.generation == RUN_GENERATION
end

function Core:SetRunning(value)
    Runtime.Running = value == true
    if not Runtime.Running then
        self:StopAllWorkers()
    end
end

function Core:NextWorkerGeneration(name)
    local generation = (self.WorkerGeneration[name] or 0) + 1
    self.WorkerGeneration[name] = generation
    return generation
end

function Core:IsWorkerCurrent(name, generation)
    return self.WorkerGeneration[name] == generation
end

function Core:StartWorker(name, callback)
    if not self:IsAlive() then
        return false, "Execucao invalidada"
    end
    if type(name) ~= "string" or type(callback) ~= "function" then
        return false, "Processo invalido"
    end

    local generation = self:NextWorkerGeneration(name)
    self.Workers[name] = { generation = generation, running = true, startedAt = os.clock() }

    task.spawn(function()
        local ok, err = pcall(function()
            callback(function()
                local worker = self.Workers[name]
                return self:IsAlive()
                    and worker ~= nil
                    and worker.running == true
                    and self:IsWorkerCurrent(name, generation)
            end, generation)
        end)

        local worker = self.Workers[name]
        if worker and worker.generation == generation then
            worker.running = false
            self.Workers[name] = nil
        end

        if not ok then
            warn("[ARASAKA][WORKER:" .. name .. "] Erro:", err)
        end
    end)

    return true, generation
end

function Core:StopWorker(name)
    local worker = self.Workers[name]
    self:NextWorkerGeneration(name)
    if worker then worker.running = false end
    self.Workers[name] = nil
    return true
end

function Core:IsWorkerRunning(name)
    local worker = self.Workers[name]
    return worker ~= nil and worker.running == true
end

function Core:StopAllWorkers()
    local names = {}
    for name in pairs(self.Workers) do
        table.insert(names, name)
    end
    for _, name in ipairs(names) do
        self:StopWorker(name)
    end
end

function Core:RegisterModule(name, module)
    if type(name) ~= "string" or name == "" or type(module) ~= "table" then
        return false
    end
    self.Modules[name] = module
    if self.States[name] == nil then self.States[name] = false end
    return true
end

function Core:IsRunning(name)
    return self.States[name] == true
end

function Core:TrackConnection(owner, connection)
    if not connection then return connection end
    self.Connections[owner] = self.Connections[owner] or {}
    table.insert(self.Connections[owner], connection)
    return connection
end

function Core:AddCleanup(owner, callback)
    if type(callback) ~= "function" then return false end
    self.Cleanups[owner] = self.Cleanups[owner] or {}
    table.insert(self.Cleanups[owner], callback)
    return true
end

function Core:CleanupOwner(owner)
    local connections = self.Connections[owner]
    if connections then
        for _, connection in ipairs(connections) do
            pcall(function() connection:Disconnect() end)
        end
        self.Connections[owner] = nil
    end
    local cleanups = self.Cleanups[owner]
    if cleanups then
        for _, callback in ipairs(cleanups) do pcall(callback) end
        self.Cleanups[owner] = nil
    end
end

function Core:StartModule(name)
    if not self:IsAlive() then return false, "Execucao invalidada" end
    local module = self.Modules[name]
    if not module then return false, "Modulo nao registrado" end
    if self.States[name] then return true end

    local ok, err = pcall(function()
        if module.Init and not module.__initialized then
            module:Init()
            module.__initialized = true
        end
        if module.Start then module:Start() end
    end)
    if ok then self.States[name] = true end
    return ok, err
end

function Core:StopModule(name)
    local module = self.Modules[name]
    if not module then return false, "Modulo nao registrado" end
    local ok, err = pcall(function()
        if module.Stop then module:Stop() end
    end)
    self.States[name] = false
    self:CleanupOwner(name)
    return ok, err
end

function Core:StopAll()
    self:StopAllWorkers()
    for name in pairs(self.Modules) do
        if self.States[name] then self:StopModule(name) end
    end
end

function Core:ResetModules(names)
    for _, name in ipairs(names or {}) do
        local module = self.Modules[name]
        if module and self.States[name] and module.Stop then
            pcall(function() module:Stop() end)
        end
        self:CleanupOwner(name)
        self.States[name] = false
        if module then
            module.__initialized = nil
            if name == "Chat" then
                module.Initialized = false
                module.Loading = false
            end
        end
    end
end

function Core:GetWorkerSnapshot()
    local snapshot = {}
    for name, worker in pairs(self.Workers) do
        snapshot[name] = {
            running = worker.running == true,
            generation = worker.generation,
            uptime = os.clock() - (worker.startedAt or os.clock())
        }
    end
    return snapshot
end

function Core:GetRunningWorkerNames()
    local names = {}
    for name, worker in pairs(self.Workers) do
        if worker.running then table.insert(names, name) end
    end
    table.sort(names)
    return names
end

function Core:GetConnectionCount()
    local count = 0
    for _, connections in pairs(self.Connections) do count += #connections end
    return count
end

function Core:GetSystemSnapshot()
    local workerCount = 0
    for _, worker in pairs(self.Workers) do
        if worker.running then workerCount += 1 end
    end
    return {
        workers = workerCount,
        connections = self:GetConnectionCount(),
        modules = self.Modules,
        manifest = self.Manifest,
    }
end

function Core:SetConfig(key, value)
    self.Config[key] = value
end

function Core:GetConfig(key, fallback)
    local value = self.Config[key]
    if value == nil then return fallback end
    return value
end

function Core:Notify(title, message, duracao)
    if self:GetConfig("notifications", true) ~= true then return end
    pcall(function()
        local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
        local gui = playerGui:FindFirstChild("ArasakaNotificationGui")
        if not gui then
            gui = Instance.new("ScreenGui")
            gui.Name = "ArasakaNotificationGui"
            gui.ResetOnSpawn = false
            gui.DisplayOrder = 2500
            gui.IgnoreGuiInset = true
            gui.Parent = playerGui

            local holder = Instance.new("Frame")
            holder.Name = "Holder"
            holder.AnchorPoint = Vector2.new(1, 1)
            holder.Position = UDim2.new(1, -18, 1, -18)
            holder.Size = UDim2.new(0, 330, 0, 300)
            holder.BackgroundTransparency = 1
            holder.Parent = gui

            local layout = Instance.new("UIListLayout")
            layout.Parent = holder
            layout.FillDirection = Enum.FillDirection.Vertical
            layout.VerticalAlignment = Enum.VerticalAlignment.Bottom
            layout.HorizontalAlignment = Enum.HorizontalAlignment.Right
            layout.Padding = UDim.new(0, 8)
        end

        local holder = gui:FindFirstChild("Holder")
        if not holder then return end
        local notices = {}
        for _, item in ipairs(holder:GetChildren()) do
            if item:IsA("Frame") and item.Name == "Notificacao" then table.insert(notices, item) end
        end
        while #notices >= 3 do
            local old = table.remove(notices, 1)
            if old then old:Destroy() end
        end

        local card = Instance.new("Frame", holder)
        card.Name = "Notificacao"
        card.Size = UDim2.new(0, 320, 0, 72)
        card.BackgroundColor3 = Color3.fromRGB(8, 8, 8)
        card.BorderSizePixel = 0
        card.ClipsDescendants = true
        Instance.new("UICorner", card).CornerRadius = UDim.new(0, 5)
        local stroke = Instance.new("UIStroke", card)
        stroke.Color = Color3.fromRGB(185, 25, 35)
        stroke.Thickness = 1
        local accent = Instance.new("Frame", card)
        accent.Size = UDim2.new(0, 4, 1, 0)
        accent.BackgroundColor3 = Color3.fromRGB(235, 35, 45)
        accent.BorderSizePixel = 0

        local titleLabel = Instance.new("TextLabel", card)
        titleLabel.BackgroundTransparency = 1
        titleLabel.Position = UDim2.new(0, 16, 0, 9)
        titleLabel.Size = UDim2.new(1, -28, 0, 20)
        titleLabel.Font = Enum.Font.GothamBold
        titleLabel.TextSize = 13
        titleLabel.TextColor3 = Color3.fromRGB(245, 245, 245)
        titleLabel.TextXAlignment = Enum.TextXAlignment.Left
        titleLabel.Text = tostring(title or "ARASAKA")

        local body = Instance.new("TextLabel", card)
        body.BackgroundTransparency = 1
        body.Position = UDim2.new(0, 16, 0, 31)
        body.Size = UDim2.new(1, -28, 0, 30)
        body.Font = Enum.Font.Gotham
        body.TextSize = 11
        body.TextWrapped = true
        body.TextColor3 = Color3.fromRGB(175, 175, 175)
        body.TextXAlignment = Enum.TextXAlignment.Left
        body.TextYAlignment = Enum.TextYAlignment.Top
        body.Text = tostring(message or "")

        card.Position = UDim2.new(1, 350, 0, 0)
        TweenService:Create(card, TweenInfo.new(0.22, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
            Position = UDim2.new(0, 0, 0, 0)
        }):Play()

        task.delay(tonumber(duracao) or 3.2, function()
            if not card.Parent then return end
            local tween = TweenService:Create(card, TweenInfo.new(0.2, Enum.EasingStyle.Quart, Enum.EasingDirection.In), {
                BackgroundTransparency = 1
            })
            tween:Play()
            tween.Completed:Wait()
            if card then card:Destroy() end
        end)
    end)
end

function Core:NotificarToggle(nome, ativo)
    self:Notify(tostring(nome or "FUNÇÃO"), ativo and "Função ativada 🟢" or "Função desativada 🔴", 2)
end

Bridge.cleanup = function()
    Runtime.Running = false
    pcall(function() Core:StopAll() end)

    local owners = {}
    for owner in pairs(Core.Connections) do table.insert(owners, owner) end
    for owner in pairs(Core.Cleanups) do
        if not table.find(owners, owner) then table.insert(owners, owner) end
    end
    for _, owner in ipairs(owners) do
        pcall(function() Core:CleanupOwner(owner) end)
    end
end

Core.Manifest = {
    Core = { ModuleManager = true, WorkerManager = true, ConnectionManager = true, ProcessControl = true },
    Modules = { UI = true, Farms = true, Pets = true, Kill = true, Visual = true, Chat = true, Utils = true }
}

function Utils.PerfBegin(name)
    Utils.PerfMarks[name] = os.clock()
end

function Utils.PerfEnd(name)
    local started = Utils.PerfMarks[name]
    if not started then return 0 end
    local elapsed = os.clock() - started
    Utils.PerfMarks[name] = nil
    print(string.format("[ARASAKA][PERF] %s = %.3fs", name, elapsed))
    return elapsed
end

function Utils.FormatNumber(n, kDecimals)
    n = tonumber(n) or 0
    local absN = math.abs(n)
    if absN >= 1e24 then return string.format("%.2fSep", n / 1e24)
    elseif absN >= 1e21 then return string.format("%.2fSx", n / 1e21)
    elseif absN >= 1e18 then return string.format("%.2fQi", n / 1e18)
    elseif absN >= 1e15 then return string.format("%.2fQa", n / 1e15)
    elseif absN >= 1e12 then return string.format("%.2fT", n / 1e12)
    elseif absN >= 1e9 then return string.format("%.2fB", n / 1e9)
    elseif absN >= 1e6 then return string.format("%.2fM", n / 1e6)
    elseif absN >= 1e3 then
        return string.format(kDecimals == 2 and "%.2fK" or "%.1fK", n / 1e3)
    else
        return tostring(math.floor(n + 0.5))
    end
end

function Utils.ReadStat(targetPlayer, primary, secondary)
    local leader = targetPlayer and targetPlayer:FindFirstChild("leaderstats")
    local stats = targetPlayer and (targetPlayer:FindFirstChild("stats") or targetPlayer:FindFirstChild("privateStats"))
    local function read(parent, name)
        local value = parent and name and parent:FindFirstChild(name)
        return value and tonumber(value.Value) or nil
    end
    return read(leader, primary) or read(leader, secondary)
        or read(stats, primary) or read(stats, secondary)
        or read(targetPlayer, primary) or read(targetPlayer, secondary) or 0
end

function Utils.GetMuscleEvent(targetPlayer)
    return targetPlayer:FindFirstChild("muscleEvent") or targetPlayer:WaitForChild("muscleEvent", 5)
end

function Utils.GetRebirthRemote(storage)
    local events = storage:FindFirstChild("rEvents")
    return events and events:FindFirstChild("rebirthRemote")
end

function Utils.CreateTextButton(parent, properties)
    local button = Instance.new("TextButton")
    button.Parent = parent
    for key, value in pairs(properties or {}) do
        if key ~= "CornerRadius" then
            button[key] = value
        end
    end
    if properties and properties.CornerRadius then
        Instance.new("UICorner", button).CornerRadius = properties.CornerRadius
    end
    return button
end

-- COREMEMORY
-- Migrado para o WorkerManager na FASE 10.
-- A rotina será iniciada depois que o Core estiver disponível.

-- ANTI-AFK FÍSICO
Core:TrackConnection("Core", player.Idled:Connect(function()
    if not Core:IsAlive() then return end
    VirtualUser:CaptureController()
    VirtualUser:ClickButton2(Vector2.new())
end))


local targetGui = player:WaitForChild("PlayerGui")
--==================================================
-- ARASAKA LOADING SCREEN V2
-- CLIENT / PLAYERGUI / SEM COREGUI
--==================================================
local function ArasakaLoadingScreen()
    local PlayerGui = player:WaitForChild("PlayerGui")
    local old = PlayerGui:FindFirstChild("ArasakaLoadingScreen")
    if old then old:Destroy() end

    local Gui = Instance.new("ScreenGui")
    Gui.Name = "ArasakaLoadingScreen"
    Gui.IgnoreGuiInset = true
    Gui.ResetOnSpawn = false
    Gui.DisplayOrder = 999999
    Gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    Gui.Parent = PlayerGui

    -- Escala automatica para celular/tablet. Desktop permanece em tamanho normal.
    local loadingScale = Instance.new("UIScale")
    local camera = workspace.CurrentCamera
    local viewportX = camera and camera.ViewportSize.X or 1920
    local viewportY = camera and camera.ViewportSize.Y or 1080
    if UserInputService.TouchEnabled then
        loadingScale.Scale = math.clamp(math.min(viewportX / 1000, viewportY / 700) * 0.94, 0.55, 0.82)
    else
        loadingScale.Scale = 1
    end
    loadingScale.Parent = Gui

    local RED = Color3.fromRGB(215, 50, 50)
    local DARK_RED = Color3.fromRGB(100, 15, 15)
    local BLACK = Color3.fromRGB(3, 3, 3)
    local PANEL = Color3.fromRGB(9, 9, 9)
    local WHITE = Color3.fromRGB(235, 235, 235)
    local GREY = Color3.fromRGB(105, 105, 105)
    local LOGO_ID = "rbxassetid://132397224962668"

    local Background = Instance.new("Frame")
    Background.Size = UDim2.fromScale(1, 1)
    Background.BackgroundColor3 = BLACK
    Background.BorderSizePixel = 0
    Background.Parent = Gui

    local TopLine = Instance.new("Frame")
    TopLine.Size = UDim2.new(1, 0, 0, 2)
    TopLine.BackgroundColor3 = RED
    TopLine.BorderSizePixel = 0
    TopLine.Parent = Background

    local Line1 = Instance.new("Frame")
    Line1.Size = UDim2.new(0, 100, 0, 1)
    Line1.Position = UDim2.new(0, 35, 0.5, -95)
    Line1.BackgroundColor3 = DARK_RED
    Line1.BorderSizePixel = 0
    Line1.Parent = Background

    local Line2 = Instance.new("Frame")
    Line2.Size = UDim2.new(0, 100, 0, 1)
    Line2.Position = UDim2.new(1, -135, 0.5, 95)
    Line2.BackgroundColor3 = DARK_RED
    Line2.BorderSizePixel = 0
    Line2.Parent = Background

    local Main = Instance.new("Frame")
    Main.AnchorPoint = Vector2.new(0.5, 0.5)
    Main.Position = UDim2.fromScale(0.5, 0.5)
    Main.Size = UDim2.new(0, 650, 0, 280)
    Main.BackgroundColor3 = PANEL
    Main.BackgroundTransparency = 0.05
    Main.BorderSizePixel = 0
    Main.Parent = Background

    local MainStroke = Instance.new("UIStroke")
    MainStroke.Color = Color3.fromRGB(45, 45, 45)
    MainStroke.Thickness = 1
    MainStroke.Parent = Main

    local SideBar = Instance.new("Frame")
    SideBar.Size = UDim2.new(0, 3, 1, 0)
    SideBar.BackgroundColor3 = RED
    SideBar.BorderSizePixel = 0
    SideBar.Parent = Main

    local Logo = Instance.new("ImageLabel")
    Logo.AnchorPoint = Vector2.new(0.5, 0.5)
    Logo.Position = UDim2.new(0, 105, 0.5, -10)
    Logo.Size = UDim2.new(0, 125, 0, 125)
    Logo.BackgroundTransparency = 1
    Logo.Image = LOGO_ID
    Logo.ImageTransparency = 1
    Logo.ScaleType = Enum.ScaleType.Fit
    Logo.Parent = Main

    local LogoStroke = Instance.new("UIStroke")
    LogoStroke.Color = RED
    LogoStroke.Thickness = 1
    LogoStroke.Transparency = 1
    LogoStroke.Parent = Logo

    local Title = Instance.new("TextLabel")
    Title.Size = UDim2.new(0, 400, 0, 45)
    Title.Position = UDim2.new(0, 185, 0, 48)
    Title.BackgroundTransparency = 1
    Title.Text = "ARASAKA"
    Title.TextColor3 = WHITE
    Title.TextSize = 36
    Title.Font = Enum.Font.GothamBlack
    Title.TextXAlignment = Enum.TextXAlignment.Left
    Title.TextTransparency = 1
    Title.Parent = Main

    local Corporation = Instance.new("TextLabel")
    Corporation.Size = UDim2.new(0, 400, 0, 20)
    Corporation.Position = UDim2.new(0, 187, 0, 88)
    Corporation.BackgroundTransparency = 1
    Corporation.Text = "CORPORATION // SISTEMA DE CLIENTE"
    Corporation.TextColor3 = RED
    Corporation.TextSize = 12
    Corporation.Font = Enum.Font.GothamBold
    Corporation.TextXAlignment = Enum.TextXAlignment.Left
    Corporation.TextTransparency = 1
    Corporation.Parent = Main

    local Accent = Instance.new("Frame")
    Accent.Size = UDim2.new(0, 0, 0, 2)
    Accent.Position = UDim2.new(0, 187, 0, 113)
    Accent.BackgroundColor3 = RED
    Accent.BorderSizePixel = 0
    Accent.Parent = Main

    local Status = Instance.new("TextLabel")
    Status.Size = UDim2.new(0, 420, 0, 25)
    Status.Position = UDim2.new(0, 187, 0, 130)
    Status.BackgroundTransparency = 1
    Status.Text = "INITIALIZING SYSTEM..."
    Status.TextColor3 = GREY
    Status.TextSize = 11
    Status.Font = Enum.Font.Gotham
    Status.TextXAlignment = Enum.TextXAlignment.Left
    Status.TextTransparency = 1
    Status.Parent = Main

    local BarBackground = Instance.new("Frame")
    BarBackground.Size = UDim2.new(0, 420, 0, 5)
    BarBackground.Position = UDim2.new(0, 187, 0, 165)
    BarBackground.BackgroundColor3 = Color3.fromRGB(28, 28, 28)
    BarBackground.BorderSizePixel = 0
    BarBackground.Parent = Main

    local Bar = Instance.new("Frame")
    Bar.Size = UDim2.new(0, 0, 1, 0)
    Bar.BackgroundColor3 = RED
    Bar.BorderSizePixel = 0
    Bar.Parent = BarBackground

    local Percent = Instance.new("TextLabel")
    Percent.Size = UDim2.new(0, 60, 0, 20)
    Percent.Position = UDim2.new(1, -67, 0, 180)
    Percent.BackgroundTransparency = 1
    Percent.Text = "0%"
    Percent.TextColor3 = RED
    Percent.TextSize = 11
    Percent.Font = Enum.Font.GothamBold
    Percent.TextXAlignment = Enum.TextXAlignment.Right
    Percent.TextTransparency = 1
    Percent.Parent = Main

    local SystemCode = Instance.new("TextLabel")
    SystemCode.Size = UDim2.new(0, 400, 0, 20)
    SystemCode.Position = UDim2.new(0, 187, 0, 202)
    SystemCode.BackgroundTransparency = 1
    SystemCode.Text = "SYS://ARASAKA/CLIENTE"
    SystemCode.TextColor3 = Color3.fromRGB(55, 55, 55)
    SystemCode.TextSize = 12
    SystemCode.Font = Enum.Font.Code
    SystemCode.TextXAlignment = Enum.TextXAlignment.Left
    SystemCode.Parent = Main

    local Footer = Instance.new("TextLabel")
    Footer.Size = UDim2.new(1, -50, 0, 20)
    Footer.Position = UDim2.new(0, 25, 1, -35)
    Footer.BackgroundTransparency = 1
    Footer.Text = "ARASAKA CORPORATION  //  SECURE CONNECTION"
    Footer.TextColor3 = Color3.fromRGB(50, 50, 50)
    Footer.TextSize = 12
    Footer.Font = Enum.Font.GothamBold
    Footer.TextXAlignment = Enum.TextXAlignment.Right
    Footer.Parent = Background

    local Messages = {
        "INITIALIZING SYSTEM...",
        "CONNECTING TO ARASAKA NETWORK...",
        "VERIFYING USER DATA...",
        "LOADING CORE MODULES...",
        "CALIBRATING INTERFACE...",
        "ESTABLISHING SECURE CONNECTION...",
        "LOADING ARASAKA INTERFACE...",
        "SYSTEM READY."
    }

    local Entrance = TweenInfo.new(0.7, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
    TweenService:Create(Logo, Entrance, {ImageTransparency = 0}):Play()
    TweenService:Create(LogoStroke, Entrance, {Transparency = 0.25}):Play()
    TweenService:Create(Title, Entrance, {TextTransparency = 0}):Play()
    TweenService:Create(Corporation, Entrance, {TextTransparency = 0}):Play()
    TweenService:Create(Status, Entrance, {TextTransparency = 0}):Play()
    TweenService:Create(Percent, Entrance, {TextTransparency = 0}):Play()
    TweenService:Create(Accent, TweenInfo.new(0.6, Enum.EasingStyle.Quint), {Size = UDim2.new(0, 420, 0, 2)}):Play()

    local Glitch = true
    task.spawn(function()
        while Glitch and Gui.Parent do
            task.wait(math.random(25, 70) / 100)
            if math.random(1, 4) == 1 then
                local oldPosition = Title.Position
                local oldColor = Title.TextColor3
                Title.Position = oldPosition + UDim2.new(0, math.random(-3, 3), 0, math.random(-1, 1))
                Title.TextColor3 = RED
                task.wait(0.025)
                if Title.Parent then
                    Title.Position = oldPosition
                    Title.TextColor3 = oldColor
                end
            end
        end
    end)

    for i = 1, 100 do
        local progress = i / 100
        TweenService:Create(Bar, TweenInfo.new(0.035, Enum.EasingStyle.Linear), {Size = UDim2.new(progress, 0, 1, 0)}):Play()
        Percent.Text = tostring(i) .. "%"
        local messageIndex = math.clamp(math.ceil(progress * #Messages), 1, #Messages)
        Status.Text = Messages[messageIndex]
        if i < 20 then task.wait(0.035) elseif i < 75 then task.wait(0.025) else task.wait(0.045) end
    end

    Status.Text = "SYSTEM READY."
    Percent.Text = "100%"
    task.wait(0.6)
    Glitch = false

    local Fade = TweenInfo.new(0.7, Enum.EasingStyle.Quint, Enum.EasingDirection.In)
    for _, obj in ipairs({Logo, Title, Corporation, Status, Percent}) do
        local prop = obj:IsA("ImageLabel") and "ImageTransparency" or "TextTransparency"
        TweenService:Create(obj, Fade, {[prop] = 1}):Play()
    end
    TweenService:Create(LogoStroke, Fade, {Transparency = 1}):Play()
    TweenService:Create(Accent, Fade, {BackgroundTransparency = 1}):Play()
    TweenService:Create(BarBackground, Fade, {BackgroundTransparency = 1}):Play()
    TweenService:Create(Bar, Fade, {BackgroundTransparency = 1}):Play()
    TweenService:Create(Background, Fade, {BackgroundTransparency = 1}):Play()
    task.wait(0.8)
    if Gui then Gui:Destroy() end
end

ArasakaLoadingScreen()

local uiName = "ArasakaChat_Gui"

for _, oldGui in ipairs(targetGui:GetChildren()) do
    if oldGui.Name == uiName or oldGui.Name == "ArasakaLoading_Gui" or oldGui.Name == "ArasakaAntiLag_Gui" or oldGui.Name == "ArasakaDropdown_Gui" or oldGui.Name == "ArasakaConfigRebirth_Gui" or oldGui.Name == "ArasakaBlackScreen_Gui" then
        oldGui:Destroy()
    end
end

-- MÓDULO INTERNO DE CHAT PRIVADO
function Chat:Build(tabChat, playClickSound)
    local WebSocket = WebSocket or syn and syn.websocket or Krnl and Krnl.WebSocket
    local ws
    if WebSocket then 
        pcall(function() ws = WebSocket.connect("wss://chatprivado-cwu3.onrender.com") end)
    end
    self.Socket = ws

    local avatarCache = {}
    local function getAvatarUrl(uId)
        if avatarCache[uId] then return avatarCache[uId] end
        local success, url = pcall(function()
            return game:GetService("Players"):GetUserThumbnailAsync(uId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size420x420)
        end)
        avatarCache[uId] = success and url or ""
        return avatarCache[uId]
    end

    local myThumbUrl = getAvatarUrl(player.UserId)

    local scrollingFrame = Instance.new("ScrollingFrame", tabChat)
    scrollingFrame.Name = "ChatMessages"
    scrollingFrame.BackgroundColor3 = Color3.fromRGB(8, 8, 8)
    scrollingFrame.BackgroundTransparency = 0
    scrollingFrame.BorderSizePixel = 0
    scrollingFrame.Position = UDim2.new(0, 10, 0, 35)
    scrollingFrame.Size = UDim2.new(1, -20, 1, -83)
    scrollingFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
    scrollingFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
    scrollingFrame.ScrollBarThickness = 3
    scrollingFrame.ScrollBarImageColor3 = Color3.fromRGB(110, 20, 20)
    scrollingFrame.ClipsDescendants = true
    Instance.new("UICorner", scrollingFrame).CornerRadius = UDim.new(0, 3)
    local chatStroke = Instance.new("UIStroke", scrollingFrame)
    chatStroke.Color = Color3.fromRGB(35, 35, 35)
    chatStroke.Thickness = 1

    local chatTopLine = Instance.new("Frame", tabChat)
    chatTopLine.Size = UDim2.new(1, -20, 0, 1)
    chatTopLine.Position = UDim2.new(0, 10, 0, 10)
    chatTopLine.BackgroundColor3 = Color3.fromRGB(215, 50, 50)
    chatTopLine.BorderSizePixel = 0
    chatTopLine.ZIndex = 2

    local uiListLayout = Instance.new("UIListLayout", scrollingFrame)
    uiListLayout.SortOrder = Enum.SortOrder.LayoutOrder
    uiListLayout.Padding = UDim.new(0, 6)

    local chatHeader = Instance.new("TextLabel", tabChat)
    chatHeader.Size = UDim2.new(1, -30, 0, 18)
    chatHeader.Position = UDim2.new(0, 18, 0, 16)
    chatHeader.BackgroundTransparency = 1
    chatHeader.Text = "// SECURE CHANNEL"
    chatHeader.TextColor3 = Color3.fromRGB(90, 90, 90)
    chatHeader.Font = Enum.Font.Code
    chatHeader.TextSize = 8
    chatHeader.TextXAlignment = Enum.TextXAlignment.Left
    chatHeader.ZIndex = 3

    local textBox = Instance.new("TextBox", tabChat)
    textBox.BackgroundColor3 = Color3.fromRGB(14, 14, 14)
    textBox.BorderSizePixel = 0
    textBox.Position = UDim2.new(0, 10, 1, -42)
    textBox.Size = UDim2.new(1, -90, 0, 32)
    textBox.ClearTextOnFocus = false
    textBox.Font = Enum.Font.Gotham
    textBox.PlaceholderText = "Sua mensagem..."
    textBox.Text = ""
    textBox.TextColor3 = Color3.fromRGB(255, 255, 255)
    textBox.TextSize = 12
    Instance.new("UICorner", textBox).CornerRadius = UDim.new(0, 4)

    local textButton = Instance.new("TextButton", tabChat)
    textButton.BackgroundColor3 = Color3.fromRGB(170, 32, 32)
    textButton.BorderSizePixel = 0
    textButton.Position = UDim2.new(1, -75, 1, -42)
    textButton.Size = UDim2.new(0, 65, 0, 32)
    textButton.Font = Enum.Font.GothamBold
    textButton.Text = "ENVIAR 💬"
    textButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    textButton.TextSize = 11
    textButton.BorderSizePixel = 0
    Instance.new("UICorner", textButton).CornerRadius = UDim.new(0, 4)

    local function adicionarMensagem(autor, texto, avatar)
        local msgContainer = Instance.new("Frame", scrollingFrame)
        msgContainer.BackgroundTransparency = 1
        msgContainer.Size = UDim2.new(1, 0, 0, 28)

        local imageIcon = Instance.new("ImageLabel", msgContainer)
        imageIcon.BackgroundTransparency = 1
        imageIcon.Size = UDim2.new(0, 24, 0, 24)
        imageIcon.Image = avatar or ""
        Instance.new("UICorner", imageIcon).CornerRadius = UDim.new(1, 0)

        local msgLabel = Instance.new("TextLabel", msgContainer)
        msgLabel.BackgroundTransparency = 1
        msgLabel.Position = UDim2.new(0, 30, 0, 0)
        msgLabel.Size = UDim2.new(1, -30, 1, 0)
        msgLabel.Font = Enum.Font.Gotham
        msgLabel.Text = '<font color="#d73232"><b>@' .. autor .. ':</b></font> ' .. texto
        msgLabel.RichText = true
        msgLabel.TextColor3 = Color3.fromRGB(220, 220, 220)
        msgLabel.TextSize = 11
        msgLabel.TextXAlignment = Enum.TextXAlignment.Left
        msgLabel.TextYAlignment = Enum.TextYAlignment.Center

        scrollingFrame.CanvasSize = UDim2.new(0, 0, 0, uiListLayout.AbsoluteContentSize.Y + 20)
    end

    if ws then
        local messageConnection = ws.OnMessage:Connect(function(rawMsg)
            pcall(function()
                local split = string.split(rawMsg, "||")
                if #split >= 3 then
                    local autor = split[1]
                    local avatar = split[2]
                    local texto = split[3]
                    if not string.find(autor, "PING") and not string.find(texto, "PING") and autor ~= "ONLINE_COUNT" and autor ~= "[SISTEMA]" then
                        adicionarMensagem(autor, texto, avatar)
                    end
                end
            end)
        end)
        Core:TrackConnection("Chat", messageConnection)
    end

    local function enviar()
        if textBox.Text ~= "" and ws then
            if playClickSound then playClickSound() end
            ws:Send(player.Name .. "||" .. myThumbUrl .. "||" .. textBox.Text)
            textBox.Text = ""
        end
    end

    Core:TrackConnection("Chat", textButton.MouseButton1Click:Connect(enviar))
    Core:TrackConnection("Chat", textBox.FocusLost:Connect(function(enterPressed)
        if enterPressed then enviar() end
    end))
end

-- DROPDOWN SELECTOR
local function AbrirMenuSelecao(titulo, listaOpcoes, callback)
    local oldDrop = targetGui:FindFirstChild("ArasakaDropdown_Gui")
    if oldDrop then oldDrop:Destroy() end

    local dropGui = Instance.new("ScreenGui", targetGui)
    dropGui.Name = "ArasakaDropdown_Gui"
    dropGui.IgnoreGuiInset = true
    dropGui.ResetOnSpawn = false
    dropGui.DisplayOrder = 5000
    dropGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

    local bgOverlay = Instance.new("TextButton", dropGui)
    bgOverlay.Size = UDim2.new(1, 0, 1, 0)
    bgOverlay.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    bgOverlay.BackgroundTransparency = 0.30
    bgOverlay.BorderSizePixel = 0
    bgOverlay.Text = ""
    bgOverlay.AutoButtonColor = false

    local mainFrame = Instance.new("Frame", dropGui)
    mainFrame.Size = UDim2.new(0, 430, 0, 390)
    mainFrame.Position = UDim2.new(0.5, -215, 0.5, -195)
    mainFrame.BackgroundColor3 = Color3.fromRGB(6, 6, 6)
    mainFrame.BorderSizePixel = 0
    mainFrame.Active = true
    mainFrame.Draggable = true
    Instance.new("UICorner", mainFrame).CornerRadius = UDim.new(0, 4)

    local stroke = Instance.new("UIStroke", mainFrame)
    stroke.Color = Color3.fromRGB(150, 25, 25)
    stroke.Thickness = 1

    local topLine = Instance.new("Frame", mainFrame)
    topLine.Size = UDim2.new(1, 0, 0, 3)
    topLine.BackgroundColor3 = Color3.fromRGB(215, 50, 50)
    topLine.BorderSizePixel = 0

    local header = Instance.new("Frame", mainFrame)
    header.Size = UDim2.new(1, 0, 0, 58)
    header.Position = UDim2.new(0, 0, 0, 3)
    header.BackgroundColor3 = Color3.fromRGB(9, 9, 9)
    header.BorderSizePixel = 0

    local logo = Instance.new("ImageLabel", header)
    logo.Size = UDim2.new(0, 30, 0, 30)
    logo.Position = UDim2.new(0, 14, 0.5, -15)
    logo.BackgroundTransparency = 1
    logo.Image = "rbxassetid://132397224962668"
    logo.ScaleType = Enum.ScaleType.Fit

    local titleLbl = Instance.new("TextLabel", header)
    titleLbl.Size = UDim2.new(1, -90, 0, 22)
    titleLbl.Position = UDim2.new(0, 52, 0, 9)
    titleLbl.BackgroundTransparency = 1
    titleLbl.Text = "ARASAKA // " .. string.upper(titulo)
    titleLbl.TextColor3 = Color3.fromRGB(235, 235, 235)
    titleLbl.Font = Enum.Font.GothamBlack
    titleLbl.TextSize = 13
    titleLbl.TextXAlignment = Enum.TextXAlignment.Left

    local subLbl = Instance.new("TextLabel", header)
    subLbl.Size = UDim2.new(1, -90, 0, 14)
    subLbl.Position = UDim2.new(0, 52, 0, 31)
    subLbl.BackgroundTransparency = 1
    subLbl.Text = "CORPORATION // SELECT MODULE"
    subLbl.TextColor3 = Color3.fromRGB(155, 35, 35)
    subLbl.Font = Enum.Font.Code
    subLbl.TextSize = 8
    subLbl.TextXAlignment = Enum.TextXAlignment.Left

    local closeBtn = Instance.new("TextButton", header)
    closeBtn.Size = UDim2.new(0, 28, 0, 28)
    closeBtn.Position = UDim2.new(1, -39, 0.5, -14)
    closeBtn.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
    closeBtn.BorderSizePixel = 0
    closeBtn.Text = "×"
    closeBtn.TextColor3 = Color3.fromRGB(215, 50, 50)
    closeBtn.Font = Enum.Font.GothamBold
    closeBtn.TextSize = 16
    Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(0, 3)
    local closeStroke = Instance.new("UIStroke", closeBtn)
    closeStroke.Color = Color3.fromRGB(45, 45, 45)

    local separator = Instance.new("Frame", mainFrame)
    separator.Size = UDim2.new(1, -24, 0, 1)
    separator.Position = UDim2.new(0, 12, 0, 65)
    separator.BackgroundColor3 = Color3.fromRGB(38, 38, 38)
    separator.BorderSizePixel = 0

    local scroll = Instance.new("ScrollingFrame", mainFrame)
    scroll.Size = UDim2.new(1, -24, 1, -91)
    scroll.Position = UDim2.new(0, 12, 0, 76)
    scroll.BackgroundTransparency = 1
    scroll.BorderSizePixel = 0
    scroll.ScrollBarThickness = 3
    scroll.ScrollBarImageColor3 = Color3.fromRGB(110, 20, 20)
    scroll.CanvasSize = UDim2.new(0, 0, 0, 0)

    local layout = Instance.new("UIListLayout", scroll)
    layout.Padding = UDim.new(0, 5)
    layout.SortOrder = Enum.SortOrder.LayoutOrder

    local padding = Instance.new("UIPadding", scroll)
    padding.PaddingBottom = UDim.new(0, 8)

    layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        scroll.CanvasSize = UDim2.new(0, 0, 0, layout.AbsoluteContentSize.Y + 12)
    end)

    local dropConnections = {}
    local function fecharDropdown()
        for _, conn in ipairs(dropConnections) do conn:Disconnect() end
        dropConnections = {}
        if dropGui then dropGui:Destroy() end
    end

    table.insert(dropConnections, closeBtn.MouseButton1Click:Connect(fecharDropdown))
    table.insert(dropConnections, bgOverlay.MouseButton1Click:Connect(fecharDropdown))

    for index, itemData in ipairs(listaOpcoes) do
        local nameText = typeof(itemData) == "table" and itemData.Text or tostring(itemData)
        local valueData = typeof(itemData) == "table" and itemData.Value or itemData

        local itemBtn = Instance.new("TextButton", scroll)
        itemBtn.LayoutOrder = index
        itemBtn.Size = UDim2.new(1, -6, 0, 36)
        itemBtn.BackgroundColor3 = Color3.fromRGB(13, 13, 13)
        itemBtn.BorderSizePixel = 0
        itemBtn.Text = ""
        itemBtn.AutoButtonColor = false
        Instance.new("UICorner", itemBtn).CornerRadius = UDim.new(0, 2)

        local itemLine = Instance.new("Frame", itemBtn)
        itemLine.Size = UDim2.new(0, 2, 1, 0)
        itemLine.BackgroundColor3 = Color3.fromRGB(120, 22, 22)
        itemLine.BorderSizePixel = 0

        local indexLbl = Instance.new("TextLabel", itemBtn)
        indexLbl.Size = UDim2.new(0, 28, 1, 0)
        indexLbl.Position = UDim2.new(0, 7, 0, 0)
        indexLbl.BackgroundTransparency = 1
        indexLbl.Text = string.format("%02d", index)
        indexLbl.TextColor3 = Color3.fromRGB(75, 75, 75)
        indexLbl.Font = Enum.Font.Code
        indexLbl.TextSize = 12

        local itemLbl = Instance.new("TextLabel", itemBtn)
        itemLbl.Size = UDim2.new(1, -45, 1, 0)
        itemLbl.Position = UDim2.new(0, 36, 0, 0)
        itemLbl.BackgroundTransparency = 1
        itemLbl.Text = nameText
        itemLbl.TextColor3 = Color3.fromRGB(210, 210, 210)
        itemLbl.Font = Enum.Font.GothamMedium
        itemLbl.TextSize = 12
        itemLbl.TextXAlignment = Enum.TextXAlignment.Left
        itemLbl.TextTruncate = Enum.TextTruncate.AtEnd

        table.insert(dropConnections, itemBtn.MouseEnter:Connect(function()
            itemBtn.BackgroundColor3 = Color3.fromRGB(34, 9, 9)
            itemLine.BackgroundColor3 = Color3.fromRGB(215, 50, 50)
            itemLbl.TextColor3 = Color3.fromRGB(255, 255, 255)
        end))
        table.insert(dropConnections, itemBtn.MouseLeave:Connect(function()
            itemBtn.BackgroundColor3 = Color3.fromRGB(13, 13, 13)
            itemLine.BackgroundColor3 = Color3.fromRGB(120, 22, 22)
            itemLbl.TextColor3 = Color3.fromRGB(210, 210, 210)
        end))
        table.insert(dropConnections, itemBtn.MouseButton1Click:Connect(function()
            callback(valueData, nameText)
            fecharDropdown()
        end))
    end
end

-- HUB EXECUTION PRINCIPAL
function UI:Start()
    local startTime = os.time()
    local FormatNumber = Utils.FormatNumber
    local function getMuscleEvent() return Utils.GetMuscleEvent(player) end
    local function getRebirthRemote() return Utils.GetRebirthRemote(ReplicatedStorage) end

    local clickSound = Instance.new("Sound", SoundService)
    clickSound.SoundId = "rbxassetid://4499400560"
    clickSound.Volume = 1
    local function playClickSound() pcall(function() clickSound:Play() end) end

    local screenGui = Instance.new("ScreenGui", targetGui)
    screenGui.Name = uiName
    screenGui.DisplayOrder = 1000
    screenGui.ResetOnSpawn = false
    self.ScreenGui = screenGui

    local uiScale = Instance.new("UIScale")
    local camera = workspace.CurrentCamera
    local viewportX = camera and camera.ViewportSize.X or 1920
    local viewportY = camera and camera.ViewportSize.Y or 1080
    if UserInputService.TouchEnabled then
        uiScale.Scale = math.clamp(math.min(viewportX / 820, viewportY / 520) * 0.94, 0.42, 0.82)
    else
        uiScale.Scale = 1
    end
    uiScale.Parent = screenGui

    -- INTERFACE PRINCIPAL V3
    local frame = Instance.new("Frame", screenGui)
    frame.AnchorPoint = Vector2.new(0.5, 0.5)
    frame.Size = UDim2.new(0, 820, 0, 520)
    frame.Position = UDim2.new(0.5, 0, 0.5, 0)
    frame.BackgroundColor3 = Color3.fromRGB(5, 5, 5)
    frame.BorderSizePixel = 0
    frame.Active, frame.Draggable = true, true
    frame.ClipsDescendants = true
    Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 4)

    local uiStrokeMain = Instance.new("UIStroke", frame)
    uiStrokeMain.Color = Color3.fromRGB(55, 55, 55)
    uiStrokeMain.Thickness = 1

    local topRed = Instance.new("Frame", frame)
    topRed.Size = UDim2.new(1, 0, 0, 3)
    topRed.BackgroundColor3 = Color3.fromRGB(215, 50, 50)
    topRed.BorderSizePixel = 0
    topRed.ZIndex = 10

    local techLeft = Instance.new("Frame", frame)
    techLeft.Size = UDim2.new(0, 55, 0, 1)
    techLeft.Position = UDim2.new(0, 18, 0, 15)
    techLeft.BackgroundColor3 = Color3.fromRGB(100, 15, 15)
    techLeft.BorderSizePixel = 0

    local techRight = Instance.new("Frame", frame)
    techRight.Size = UDim2.new(0, 55, 0, 1)
    techRight.Position = UDim2.new(1, -73, 0, 15)
    techRight.BackgroundColor3 = Color3.fromRGB(100, 15, 15)
    techRight.BorderSizePixel = 0

    local titleBar = Instance.new("Frame", frame)
    titleBar.Size = UDim2.new(1, 0, 0, 52)
    titleBar.Position = UDim2.new(0, 0, 0, 3)
    titleBar.BackgroundColor3 = Color3.fromRGB(9, 9, 9)
    titleBar.BorderSizePixel = 0

    local decalImage = Instance.new("ImageLabel", titleBar)
    decalImage.Size = UDim2.new(0, 30, 0, 30)
    decalImage.Position = UDim2.new(0, 17, 0.5, -15)
    decalImage.BackgroundTransparency = 1
    decalImage.Image = "rbxassetid://132397224962668"
    decalImage.ScaleType = Enum.ScaleType.Fit

    local titleText = Instance.new("TextLabel", titleBar)
    titleText.Size = UDim2.new(0, 300, 0, 23)
    titleText.Position = UDim2.new(0, 57, 0, 8)
    titleText.BackgroundTransparency = 1
    titleText.Text = "ARASAKA"
    titleText.TextColor3 = Color3.fromRGB(235, 235, 235)
    titleText.Font = Enum.Font.GothamBlack
    titleText.TextSize = 18
    titleText.TextXAlignment = Enum.TextXAlignment.Left

    local subtitleText = Instance.new("TextLabel", titleBar)
    subtitleText.Size = UDim2.new(0, 360, 0, 16)
    subtitleText.Position = UDim2.new(0, 58, 0, 30)
    subtitleText.BackgroundTransparency = 1
    subtitleText.Text = "CORPORATION // SISTEMA DE CLIENTE"
    subtitleText.TextColor3 = Color3.fromRGB(215, 50, 50)
    subtitleText.Font = Enum.Font.Code
    subtitleText.TextSize = 12
    subtitleText.TextXAlignment = Enum.TextXAlignment.Left

    local onlineText = Instance.new("TextLabel", titleBar)
    onlineText.Size = UDim2.new(0, 190, 0, 20)
    onlineText.Position = UDim2.new(1, -250, 0, 7)
    onlineText.BackgroundTransparency = 1
    onlineText.Text = "● SISTEMA ONLINE"
    onlineText.TextColor3 = Color3.fromRGB(215, 50, 50)
    onlineText.Font = Enum.Font.Code
    onlineText.TextSize = 11
    onlineText.TextXAlignment = Enum.TextXAlignment.Right

    local userText = Instance.new("TextLabel", titleBar)
    userText.Size = UDim2.new(0, 235, 0, 18)
    userText.Position = UDim2.new(1, -295, 0, 29)
    userText.BackgroundTransparency = 1
    userText.Text = "ID DO USUARIO: " .. tostring(player.UserId)
    userText.TextColor3 = Color3.fromRGB(190, 190, 190)
    userText.Font = Enum.Font.Code
    userText.TextSize = 10
    userText.TextXAlignment = Enum.TextXAlignment.Right

    local btnMinimizar = Instance.new("TextButton", titleBar)
    btnMinimizar.Size = UDim2.new(0, 30, 0, 30)
    btnMinimizar.Position = UDim2.new(1, -38, 0.5, -15)
    btnMinimizar.BackgroundColor3 = Color3.fromRGB(18, 18, 18)
    btnMinimizar.BorderSizePixel = 0
    btnMinimizar.Text = "—"
    btnMinimizar.TextColor3 = Color3.fromRGB(215, 50, 50)
    btnMinimizar.Font = Enum.Font.GothamBold
    btnMinimizar.TextSize = 16
    Instance.new("UICorner", btnMinimizar).CornerRadius = UDim.new(0, 3)
    local minStroke = Instance.new("UIStroke", btnMinimizar)
    minStroke.Color = Color3.fromRGB(55, 55, 55)
    minStroke.Thickness = 1

    local separator = Instance.new("Frame", frame)
    separator.Size = UDim2.new(1, -32, 0, 1)
    separator.Position = UDim2.new(0, 16, 0, 55)
    separator.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
    separator.BorderSizePixel = 0

    local sidebar = Instance.new("Frame", frame)
    sidebar.Size = UDim2.new(0, 155, 1, -57)
    sidebar.Position = UDim2.new(0, 0, 0, 57)
    sidebar.BackgroundColor3 = Color3.fromRGB(8, 8, 8)
    sidebar.BorderSizePixel = 0

    local sideAccent = Instance.new("Frame", sidebar)
    sideAccent.Size = UDim2.new(0, 2, 1, 0)
    sideAccent.Position = UDim2.new(1, -2, 0, 0)
    sideAccent.BackgroundColor3 = Color3.fromRGB(70, 10, 10)
    sideAccent.BorderSizePixel = 0

    local sideHeader = Instance.new("TextLabel", sidebar)
    sideHeader.Size = UDim2.new(1, -24, 0, 28)
    sideHeader.Position = UDim2.new(0, 12, 0, 12)
    sideHeader.BackgroundTransparency = 1
    sideHeader.Text = "// MODULOS"
    sideHeader.TextColor3 = Color3.fromRGB(95, 95, 95)
    sideHeader.Font = Enum.Font.Code
    sideHeader.TextSize = 12
    sideHeader.TextXAlignment = Enum.TextXAlignment.Left

    local sideLine = Instance.new("Frame", sidebar)
    sideLine.Size = UDim2.new(1, -24, 0, 1)
    sideLine.Position = UDim2.new(0, 12, 0, 38)
    sideLine.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
    sideLine.BorderSizePixel = 0

    local nextTabY = 48

    local contentArea = Instance.new("Frame", frame)
    contentArea.Size = UDim2.new(1, -155, 1, -57)
    contentArea.Position = UDim2.new(0, 155, 0, 57)
    contentArea.BackgroundColor3 = Color3.fromRGB(5, 5, 5)
    contentArea.BorderSizePixel = 0

    local contentGlow = Instance.new("Frame", contentArea)
    contentGlow.Size = UDim2.new(1, 0, 0, 1)
    contentGlow.Position = UDim2.new(0, 0, 0, 0)
    contentGlow.BackgroundColor3 = Color3.fromRGB(215, 50, 50)
    contentGlow.BackgroundTransparency = 0.35
    contentGlow.BorderSizePixel = 0

    local contentCode = Instance.new("TextLabel", contentArea)
    contentCode.Size = UDim2.new(1, -24, 0, 16)
    contentCode.Position = UDim2.new(0, 12, 1, -22)
    contentCode.BackgroundTransparency = 1
    contentCode.Text = "SYS://ARASAKA/CLIENTE    //    INSERT PARA MOSTRAR/OCULTAR"
    contentCode.TextColor3 = Color3.fromRGB(45, 45, 45)
    contentCode.Font = Enum.Font.Code
    contentCode.TextSize = 8
    contentCode.TextXAlignment = Enum.TextXAlignment.Left

    local abas = {}
    local function CriarAba(nome, textoExibido)
        local tabBtn = Instance.new("TextButton", sidebar)
        tabBtn.Size = UDim2.new(0, 133, 0, 34)
        tabBtn.Position = UDim2.new(0, 11, 0, nextTabY)
        nextTabY = nextTabY + 39
        tabBtn.BackgroundColor3 = Color3.fromRGB(13, 13, 13)
        tabBtn.BorderSizePixel = 0
        tabBtn.Text = "  " .. (textoExibido or string.upper(nome))
        tabBtn.TextColor3 = Color3.fromRGB(125, 125, 125)
        tabBtn.Font = Enum.Font.GothamBold
        tabBtn.TextSize = 11
        tabBtn.TextXAlignment = Enum.TextXAlignment.Left
        Instance.new("UICorner", tabBtn).CornerRadius = UDim.new(0, 2)

        local tabLine = Instance.new("Frame", tabBtn)
        tabLine.Name = "ActiveLine"
        tabLine.Size = UDim2.new(0, 2, 0.65, 0)
        tabLine.Position = UDim2.new(0, 0, 0.175, 0)
        tabLine.BackgroundColor3 = Color3.fromRGB(215, 50, 50)
        tabLine.BorderSizePixel = 0
        tabLine.Visible = false

        local tabContent = Instance.new("Frame", contentArea)
        tabContent.Size = UDim2.new(1, 0, 1, 0)
        tabContent.BackgroundTransparency = 1
        tabContent.Visible = false

        abas[nome] = {btn = tabBtn, container = tabContent, line = tabLine}

        tabBtn.MouseEnter:Connect(function()
            if not tabContent.Visible then
                TweenService:Create(tabBtn, TweenInfo.new(0.12), {BackgroundColor3 = Color3.fromRGB(20, 20, 20)}):Play()
            end
        end)
        tabBtn.MouseLeave:Connect(function()
            if not tabContent.Visible then
                TweenService:Create(tabBtn, TweenInfo.new(0.12), {BackgroundColor3 = Color3.fromRGB(13, 13, 13)}):Play()
            end
        end)

        tabBtn.MouseButton1Click:Connect(function()
            playClickSound()
            for _, tab in pairs(abas) do
                tab.container.Visible = false
                tab.btn.BackgroundColor3 = Color3.fromRGB(13, 13, 13)
                tab.btn.TextColor3 = Color3.fromRGB(125, 125, 125)
                if tab.line then tab.line.Visible = false end
            end
            tabContent.Visible = true
            tabBtn.BackgroundColor3 = Color3.fromRGB(45, 12, 12)
            tabBtn.TextColor3 = Color3.fromRGB(245, 245, 245)
            tabLine.Visible = true
        end)
        return tabContent
    end

    local tabInicio = CriarAba("Início", "🏠  INÍCIO")
    local tabFarms = CriarAba("Farms", "⛏️  FARMS")
    local tabTeleports = CriarAba("Teleportes", "📍  TELEPORTES")
    local tabPets = CriarAba("Pets", "🐾  PETS")
    local tabVisual = CriarAba("Visual", "👁️  VISUAL")
    local tabOutros = CriarAba("Outros", "⚙️  OUTROS")
    local tabKill = CriarAba("Kill", "💀  KILL")
    local tabChat = CriarAba("Chat", "💬  CHAT")
    CriarAba("Calculadora", "📊  CALCULADORA")

    abas["Início"].container.Visible = true
    abas["Início"].btn.BackgroundColor3 = Color3.fromRGB(45, 12, 12)
    abas["Início"].btn.TextColor3 = Color3.fromRGB(245, 245, 245)
    abas["Início"].line.Visible = true

    -- ATALHO DE TECLADO: TECLA INSERT (INS) PARA ESCONDER/MOSTRAR HUB
    Core:TrackConnection("UI", UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if not gameProcessed and input.KeyCode == Enum.KeyCode.Insert and screenGui.Parent then
            screenGui.Enabled = not screenGui.Enabled
        end
    end))

    --==================================================
    -- MODULE // CALCULATOR
    --==================================================
    function Calculator:Init()
        local tab = abas["Calculadora"] and abas["Calculadora"].container
        if not tab then return end

        local scroll = Instance.new("ScrollingFrame", tab)
        scroll.Size = UDim2.new(1, -20, 1, -10)
        scroll.Position = UDim2.new(0, 10, 0, 5)
        scroll.BackgroundTransparency = 1
        scroll.BorderSizePixel = 0
        scroll.ScrollBarThickness = 4
        scroll.ScrollBarImageColor3 = Color3.fromRGB(110, 20, 20)
        scroll.CanvasSize = UDim2.new(0, 0, 0, 0)

        local layout = Instance.new("UIListLayout", scroll)
        layout.Padding = UDim.new(0, 7)
        layout.SortOrder = Enum.SortOrder.LayoutOrder
        layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
            scroll.CanvasSize = UDim2.new(0, 0, 0, layout.AbsoluteContentSize.Y + 18)
        end)

        local header = Instance.new("TextLabel", scroll)
        header.LayoutOrder = 1
        header.Size = UDim2.new(1, -6, 0, 42)
        header.BackgroundColor3 = Color3.fromRGB(9, 9, 9)
        header.BorderSizePixel = 0
        header.Text = "  📊 CALCULADORA // MEDIA DE GANHOS"
        header.TextColor3 = Color3.fromRGB(235, 235, 235)
        header.Font = Enum.Font.GothamBlack
        header.TextSize = 12
        header.TextXAlignment = Enum.TextXAlignment.Left
        Instance.new("UICorner", header).CornerRadius = UDim.new(0, 4)
        local hs = Instance.new("UIStroke", header)
        hs.Color = Color3.fromRGB(55, 55, 55)

        local info = Instance.new("TextLabel", scroll)
        info.LayoutOrder = 2
        info.Size = UDim2.new(1, -6, 0, 34)
        info.BackgroundColor3 = Color3.fromRGB(10, 10, 12)
        info.BorderSizePixel = 0
        info.Text = "ANALISANDO... // A MEDIA FICA MAIS PRECISA COM O TEMPO"
        info.TextColor3 = Color3.fromRGB(135, 135, 135)
        info.Font = Enum.Font.Gotham
        info.TextSize = 12
        Instance.new("UICorner", info).CornerRadius = UDim.new(0, 4)

        local function rawStat(a, b)
            return Utils.ReadStat(player, a, b)
        end

        local function nice(n)
            return Utils.FormatNumber(n, 2)
        end

        local function makeCard(title, order)
            local card = Instance.new("Frame", scroll)
            card.LayoutOrder = order
            card.Size = UDim2.new(1, -6, 0, 88)
            card.BackgroundColor3 = Color3.fromRGB(10, 10, 12)
            card.BorderSizePixel = 0
            Instance.new("UICorner", card).CornerRadius = UDim.new(0, 4)

            local stroke = Instance.new("UIStroke", card)
            stroke.Color = Color3.fromRGB(42, 42, 42)
            stroke.Thickness = 1

            local line = Instance.new("Frame", card)
            line.Size = UDim2.new(0, 3, 1, 0)
            line.BackgroundColor3 = Color3.fromRGB(190, 30, 30)
            line.BorderSizePixel = 0

            local name = Instance.new("TextLabel", card)
            name.Size = UDim2.new(1, -24, 0, 25)
            name.Position = UDim2.new(0, 14, 0, 7)
            name.BackgroundTransparency = 1
            name.Text = title
            name.TextColor3 = Color3.fromRGB(235, 235, 235)
            name.Font = Enum.Font.GothamBold
            name.TextSize = 14
            name.TextXAlignment = Enum.TextXAlignment.Left

            local values = Instance.new("TextLabel", card)
            values.Size = UDim2.new(1, -28, 0, 48)
            values.Position = UDim2.new(0, 14, 0, 31)
            values.BackgroundTransparency = 1
            values.Text = "MINUTO  0\nHORA  0    |    DIA  0    |    SEMANA  0"
            values.TextColor3 = Color3.fromRGB(165, 165, 165)
            values.Font = Enum.Font.GothamBold
            values.TextSize = 14
            values.TextXAlignment = Enum.TextXAlignment.Left
            values.TextYAlignment = Enum.TextYAlignment.Top
            return values
        end

        local labels = {
            Forca = makeCard("💪 FORÇA", 3),
            Dura = makeCard("🛡️ DURABILIDADE", 4),
            Agil = makeCard("⚡ AGILIDADE", 5),
            Rebirths = makeCard("🔄 RENASCIMENTOS", 6)
        }

        -- ACUMULADOR REAL DE GANHOS
        -- Soma apenas aumentos positivos entre cada leitura. Assim, quando um
        -- rebirth/reset derruba um atributo, a queda não apaga o que já foi ganho.
        local previous = {
            Forca = rawStat("Muscle", "Strength"),
            Dura = rawStat("Durability"),
            Agil = rawStat("Agility", "Speed"),
            Rebirths = rawStat("Rebirths", "Rebirth")
        }
        local accumulated = {
            Forca = 0,
            Dura = 0,
            Agil = 0,
            Rebirths = 0
        }
        local started = os.clock()

        local function elapsedText(sec)
            sec = math.max(0, math.floor(sec))
            local h = math.floor(sec / 3600)
            local m = math.floor((sec % 3600) / 60)
            local s = sec % 60
            return string.format("%02dh %02dm %02ds", h, m, s)
        end

        local function update(label, gain, elapsed)
            local perSecond = elapsed > 0 and (gain / elapsed) or 0
            label.Text = string.format(
                "MINUTO  %s\nHORA  %s    |    DIA  %s    |    SEMANA  %s",
                nice(perSecond * 60),
                nice(perSecond * 3600),
                nice(perSecond * 86400),
                nice(perSecond * 604800)
            )
        end

        task.spawn(function()
            while Core:IsAlive() and tab.Parent do
                local elapsed = math.max(0.001, os.clock() - started)
                pcall(function()
                    local current = {
                        Forca = rawStat("Muscle", "Strength"),
                        Dura = rawStat("Durability"),
                        Agil = rawStat("Agility", "Speed"),
                        Rebirths = rawStat("Rebirths", "Rebirth")
                    }

                    -- Só soma crescimento. Qualquer queda é tratada como reset/rebirth.
                    for key, value in pairs(current) do
                        local delta = value - (previous[key] or value)
                        if delta > 0 then
                            accumulated[key] = (accumulated[key] or 0) + delta
                        end
                        previous[key] = value
                    end

                    update(labels.Forca, accumulated.Forca, elapsed)
                    update(labels.Dura, accumulated.Dura, elapsed)
                    update(labels.Agil, accumulated.Agil, elapsed)
                    update(labels.Rebirths, accumulated.Rebirths, elapsed)
                    info.Text = "TEMPO ANALISADO // " .. elapsedText(elapsed) .. "    //    MEDIA REAL DA SESSAO"
                end)
                task.wait(1)
            end
        end)
    end

    Core:RegisterModule("Calculator", Calculator)
    local calcOk, calcErr = Core:StartModule("Calculator")
    if not calcOk then warn("[ARASAKA][MODULE:Calculator] Falha:", calcErr) end

    --==================================================
    -- MODULE // CHAT // LAZY LOADING
    -- O chat só é inicializado quando a aba CHAT é aberta pela primeira vez.
    --==================================================
    Chat.Initialized = false
    Chat.Loading = false

    function Chat:Init()
        if self.Initialized or self.Loading then
            return
        end

        self.Loading = true
        Utils.PerfBegin("CHAT_LAZY_INIT")

        local ok, err = pcall(function()
            Chat:Build(tabChat, playClickSound)
        end)

        Utils.PerfEnd("CHAT_LAZY_INIT")
        self.Loading = false

        if ok then
            self.Initialized = true
            print("[ARASAKA][MODULE] Chat = CARREGADO")
        else
            warn("[ARASAKA][MODULE:Chat] Falha:", err)
        end
    end

    if Core then
        Core:RegisterModule("Chat", Chat)
    end

    local function EnsureChatLoaded()
        if Chat.Initialized or Chat.Loading then
            return
        end

        if Core then
            local okChat, errChat = Core:StartModule("Chat")
            if not okChat then
                warn("[ARASAKA][MODULE:Chat] Falha ao iniciar:", errChat)
            end
        else
            Chat:Init()
        end
    end

    -- Detecta a primeira abertura da página do chat sem alterar os botões existentes.
    -- Assim preservamos a navegação original do Hub.
    local chatVisibilityConnection
    chatVisibilityConnection = tabChat:GetPropertyChangedSignal("Visible"):Connect(function()
        if tabChat.Visible then
            EnsureChatLoaded()
            if chatVisibilityConnection then
                chatVisibilityConnection:Disconnect()
                chatVisibilityConnection = nil
            end
        end
    end)

    if Core then
        Core:TrackConnection("ChatLoader", chatVisibilityConnection)
    end

    function Chat:Stop()
        Core:CleanupOwner("ChatLoader")
        Core:CleanupOwner("Chat")
        if self.Socket then
            pcall(function()
                if self.Socket.Close then self.Socket:Close() end
            end)
            self.Socket = nil
        end
        self.Loading = false
        self.Initialized = false
    end

    -- Caso CHAT já esteja visível por alguma configuração futura.
    if tabChat.Visible then
        task.defer(EnsureChatLoaded)
    end

    --==================================================
    -- MODULE // KILL
    --==================================================
    function Kill:Init()
        Utils.PerfBegin("KILL_UI")
        self.State = self.State or {
            mode = nil,
            excludeFriends = false,
            selectedTarget = nil,
            excludedUserIds = {}
        }

    -- CACHE LOCAL DE AMIGOS
    local friendsCache = {}

    local function updateFriendsCache()
        friendsCache = {}
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= player then
                task.spawn(function()
                    local isFriend = false
                    pcall(function()
                        isFriend = player:IsFriendsWith(p.UserId)
                    end)
                    friendsCache[p.UserId] = isFriend
                end)
            end
        end
    end

    updateFriendsCache()
    Core:TrackConnection("Kill", Players.PlayerAdded:Connect(function(p)
        task.wait(1)
        pcall(function()
            friendsCache[p.UserId] = player:IsFriendsWith(p.UserId)
        end)
    end))

    Core:TrackConnection("Kill", Players.PlayerRemoving:Connect(function(p)
        friendsCache[p.UserId] = nil
    end))

    local killScroll = Instance.new("ScrollingFrame", tabKill)
    killScroll.Size = UDim2.new(1, -20, 1, -10)
    killScroll.Position = UDim2.new(0, 10, 0, 5)
    killScroll.BackgroundTransparency = 1
    killScroll.BorderSizePixel = 0
    killScroll.ScrollBarThickness = 4
    killScroll.ScrollBarImageColor3 = Color3.fromRGB(110, 20, 20)
    killScroll.CanvasSize = UDim2.new(0, 0, 0, 0)

    local killLayout = Instance.new("UIListLayout", killScroll)
    killLayout.Padding = UDim.new(0, 7)
    killLayout.SortOrder = Enum.SortOrder.LayoutOrder
    killLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        killScroll.CanvasSize = UDim2.new(0, 0, 0, killLayout.AbsoluteContentSize.Y + 18)
    end)

    local killHeader = Instance.new("TextLabel", killScroll)
    killHeader.LayoutOrder = 1
    killHeader.Size = UDim2.new(1, -6, 0, 38)
    killHeader.BackgroundColor3 = Color3.fromRGB(9, 9, 9)
    killHeader.BorderSizePixel = 0
    killHeader.Text = "  💀 CONTROLE KILL // SISTEMA DE ALVOS"
    killHeader.TextColor3 = Color3.fromRGB(235, 235, 235)
    killHeader.Font = Enum.Font.GothamBlack
    killHeader.TextSize = 12
    killHeader.TextXAlignment = Enum.TextXAlignment.Left
    Instance.new("UICorner", killHeader).CornerRadius = UDim.new(0, 4)
    local khs = Instance.new("UIStroke", killHeader)
    khs.Color = Color3.fromRGB(55, 55, 55)

    local function makeKillButton(text, order)
        return Utils.CreateTextButton(killScroll, {
            LayoutOrder = order,
            Size = UDim2.new(1, -6, 0, 36),
            BackgroundColor3 = Color3.fromRGB(180, 30, 30),
            BorderSizePixel = 0,
            Text = text,
            TextColor3 = Color3.fromRGB(255, 255, 255),
            Font = Enum.Font.GothamBold,
            TextSize = 11,
            CornerRadius = UDim.new(0, 5),
        })
    end

    local btnKillAll = makeKillButton("KILL TODOS: OFF 🔴", 2)
    local btnSelectKill = makeKillButton("PLAYER ESPECÍFICO: SELECIONAR 🎯", 3)
    local btnKillSpecific = makeKillButton("KILL JOGADOR ESPECÍFICO: OFF 🔴", 4)
    local btnEditExclusions = makeKillButton("EDITAR EXCLUSÕES 🛡️", 5)
    local btnKillExclude = makeKillButton("KILL COM EXCLUSÃO: OFF 🔴", 6)
    local btnKillFriends = makeKillButton("EXCLUIR AMIGOS: OFF 🔴", 7)

    local killStatus = Instance.new("TextLabel", killScroll)
    killStatus.LayoutOrder = 8
    killStatus.Size = UDim2.new(1, -6, 0, 44)
    killStatus.BackgroundColor3 = Color3.fromRGB(10, 10, 12)
    killStatus.BorderSizePixel = 0
    killStatus.Text = "STATUS // AGUARDANDO"
    killStatus.TextColor3 = Color3.fromRGB(145, 145, 145)
    killStatus.Font = Enum.Font.Code
    killStatus.TextSize = 12
    killStatus.TextWrapped = true
    Instance.new("UICorner", killStatus).CornerRadius = UDim.new(0, 4)

    local startKillWorker

    local function refreshKillButtons()
        local st = Kill.State
        btnKillAll.Text = "KILL TODOS: " .. (st.mode == "all" and "ON 🟢" or "OFF 🔴")
        btnKillSpecific.Text = "KILL JOGADOR ESPECÍFICO: " .. (st.mode == "specific" and "ON 🟢" or "OFF 🔴")
        btnKillExclude.Text = "KILL COM EXCLUSÃO: " .. (st.mode == "exclude" and "ON 🟢" or "OFF 🔴")
        btnKillFriends.Text = "EXCLUIR AMIGOS: " .. (st.excludeFriends and "ON 🟢" or "OFF 🔴")
        btnSelectKill.Text = st.selectedTarget and ("ALVO: " .. st.selectedTarget .. " 🎯") or "PLAYER ESPECÍFICO: SELECIONAR 🎯"
    end

    local function setKillMode(mode)
        if Kill.State.mode == mode then
            Kill.State.mode = nil
            killStatus.Text = "STATUS // AGUARDANDO"
            Core:StopWorker("Kill.Main")
        else
            Kill.State.mode = mode
            if startKillWorker then startKillWorker() end
        end
        refreshKillButtons()
    end

    local function shouldKillTarget(target)
        local st = Kill.State
        if not st.mode or not target or target == player then return false end

        if st.excludeFriends and friendsCache[target.UserId] == true then
            return false
        end

        if st.mode == "specific" then
            return target.Name == st.selectedTarget
        elseif st.mode == "exclude" then
            return not st.excludedUserIds[target.UserId]
        elseif st.mode == "all" then
            return true
        end
        return false
    end

    local function getPunchToolForKill()
        local char = player.Character
        if not char then return nil end
        local humanoid = char:FindFirstChildOfClass("Humanoid")
        if not humanoid then return nil end
        local tool = char:FindFirstChild("Punch")
        if not tool then
            local backpack = player:FindFirstChildOfClass("Backpack") or player:FindFirstChild("Backpack")
            tool = backpack and backpack:FindFirstChild("Punch")
            if tool then pcall(function() humanoid:EquipTool(tool) end) end
        end
        return tool
    end

    local function attackKillTarget(target)
        if not Kill.State.mode or not Core:IsAlive() then return end

        local myChar = player.Character
        local targetChar = target and target.Character
        if not myChar or not targetChar then return end
        local myHum = myChar:FindFirstChildOfClass("Humanoid")
        local targetHum = targetChar:FindFirstChildOfClass("Humanoid")
        local myRoot = myChar:FindFirstChild("HumanoidRootPart")
        local targetRoot = targetChar:FindFirstChild("HumanoidRootPart")
        if not myHum or myHum.Health <= 0 or not targetHum or targetHum.Health <= 0 or not myRoot or not targetRoot then return end

        pcall(function()
            myRoot.CFrame = targetRoot.CFrame * CFrame.new(0, 0, 1)
        end)

        local tool = getPunchToolForKill()
        if tool then pcall(function() tool:Activate() end) end
        local event = getMuscleEvent()
        if event then
            pcall(function()
                event:FireServer("punch", "leftHand")
                event:FireServer("punch", "rightHand")
            end)
        end
    end

    btnKillAll.MouseButton1Click:Connect(function()
        playClickSound()
        setKillMode("all")
    end)

    btnKillSpecific.MouseButton1Click:Connect(function()
        playClickSound()
        if not Kill.State.selectedTarget then
            killStatus.Text = "STATUS // SELECIONE UM PLAYER PRIMEIRO"
            return
        end
        setKillMode("specific")
    end)

    btnKillExclude.MouseButton1Click:Connect(function()
        playClickSound()
        setKillMode("exclude")
    end)

    btnKillFriends.MouseButton1Click:Connect(function()
        playClickSound()
        Kill.State.excludeFriends = not Kill.State.excludeFriends
        updateFriendsCache()
        refreshKillButtons()
    end)

    btnSelectKill.MouseButton1Click:Connect(function()
        playClickSound()
        local opts = {}
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= player then
                table.insert(opts, {Text = p.DisplayName .. " (@" .. p.Name .. ")", Value = p.Name})
            end
        end
        table.sort(opts, function(a,b) return string.lower(a.Text) < string.lower(b.Text) end)
        if #opts == 0 then
            killStatus.Text = "STATUS // NENHUM PLAYER DISPONÍVEL"
            return
        end
        AbrirMenuSelecao("Selecionar alvo", opts, function(value)
            Kill.State.selectedTarget = value
            refreshKillButtons()
            killStatus.Text = "ALVO // @" .. tostring(value)
        end)
    end)

    local function openKillExclusionMenu()
        local old = targetGui:FindFirstChild("ArasakaKillExclusion_Gui")
        if old then old:Destroy() end

        local gui = Instance.new("ScreenGui", targetGui)
        gui.Name = "ArasakaKillExclusion_Gui"
        gui.IgnoreGuiInset = true
        gui.ResetOnSpawn = false
        gui.DisplayOrder = 7000

        local shade = Instance.new("TextButton", gui)
        shade.Size = UDim2.fromScale(1,1)
        shade.BackgroundColor3 = Color3.new(0,0,0)
        shade.BackgroundTransparency = 0.3
        shade.Text = ""
        shade.AutoButtonColor = false

        local panel = Instance.new("Frame", gui)
        panel.AnchorPoint = Vector2.new(0.5,0.5)
        panel.Position = UDim2.fromScale(0.5,0.5)
        panel.Size = UDim2.new(0,430,0,390)
        panel.BackgroundColor3 = Color3.fromRGB(7,7,7)
        panel.BorderSizePixel = 0
        Instance.new("UICorner", panel).CornerRadius = UDim.new(0,5)
        local ps = Instance.new("UIStroke", panel)
        ps.Color = Color3.fromRGB(150,25,25)

        local title = Instance.new("TextLabel", panel)
        title.Size = UDim2.new(1,-55,0,48)
        title.Position = UDim2.new(0,16,0,5)
        title.BackgroundTransparency = 1
        title.Text = "🛡️ EXCLUSÕES // NÃO ATACAR"
        title.TextColor3 = Color3.fromRGB(235,235,235)
        title.Font = Enum.Font.GothamBlack
        title.TextSize = 14
        title.TextXAlignment = Enum.TextXAlignment.Left

        local close = Instance.new("TextButton", panel)
        close.Size = UDim2.new(0,30,0,30)
        close.Position = UDim2.new(1,-40,0,12)
        close.BackgroundColor3 = Color3.fromRGB(25,12,12)
        close.Text = "×"
        close.TextColor3 = Color3.fromRGB(220,60,60)
        close.Font = Enum.Font.GothamBold
        close.TextSize = 18
        Instance.new("UICorner", close).CornerRadius = UDim.new(0,4)

        local list = Instance.new("ScrollingFrame", panel)
        list.Position = UDim2.new(0,14,0,58)
        list.Size = UDim2.new(1,-28,1,-72)
        list.BackgroundTransparency = 1
        list.BorderSizePixel = 0
        list.ScrollBarThickness = 3
        list.CanvasSize = UDim2.new()
        local ll = Instance.new("UIListLayout", list)
        ll.Padding = UDim.new(0,5)
        ll:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
            list.CanvasSize = UDim2.new(0,0,0,ll.AbsoluteContentSize.Y+10)
        end)

        local function closeMenu() if gui then gui:Destroy() end end
        close.MouseButton1Click:Connect(closeMenu)
        shade.MouseButton1Click:Connect(closeMenu)

        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= player then
                local row = Instance.new("TextButton", list)
                row.Size = UDim2.new(1,-5,0,38)
                row.BackgroundColor3 = Color3.fromRGB(13,13,13)
                row.BorderSizePixel = 0
                row.Font = Enum.Font.GothamBold
                row.TextSize = 12
                row.TextColor3 = Color3.fromRGB(220,220,220)
                row.TextXAlignment = Enum.TextXAlignment.Left
                Instance.new("UICorner", row).CornerRadius = UDim.new(0,4)

                local function updateRow()
                    local excluded = Kill.State.excludedUserIds[p.UserId] == true
                    row.Text = "   " .. (excluded and "☑ " or "☐ ") .. p.DisplayName .. " (@" .. p.Name .. ")"
                    row.BackgroundColor3 = excluded and Color3.fromRGB(48,14,14) or Color3.fromRGB(13,13,13)
                end
                updateRow()
                row.MouseButton1Click:Connect(function()
                    playClickSound()
                    Kill.State.excludedUserIds[p.UserId] = not Kill.State.excludedUserIds[p.UserId]
                    updateRow()
                end)
            end
        end
    end

    btnEditExclusions.MouseButton1Click:Connect(function()
        playClickSound()
        openKillExclusionMenu()
    end)

    startKillWorker = function()
        if not Kill.State.mode then
            Core:StopWorker("Kill.Main")
            return
        end

        Core:StartWorker("Kill.Main", function(isAlive)
            while isAlive() and Kill.State.mode do
                local found = false
                for _, target in ipairs(Players:GetPlayers()) do
                    if not isAlive() or not Kill.State.mode then break end
                    if shouldKillTarget(target) then
                        found = true
                        killStatus.Text = "ATACANDO // @" .. target.Name
                        attackKillTarget(target)
                        task.wait(0.08)
                        if not Kill.State.mode then break end
                    end
                end

                if not Kill.State.mode then
                    killStatus.Text = "STATUS // AGUARDANDO"
                elseif not found then
                    killStatus.Text = "STATUS // NENHUM ALVO VÁLIDO"
                    task.wait(0.25)
                else
                    -- Evita giro quente quando há muitos alvos e mantém resposta rápida.
                    task.wait(0.03)
                end
            end
            if killStatus and killStatus.Parent then
                killStatus.Text = "STATUS // AGUARDANDO"
            end
        end)
    end

    refreshKillButtons()
        Utils.PerfEnd("KILL_UI")
    end

    function Kill:Stop()
        self.State.mode = nil
        Core:StopWorker("Kill.Main")
        Core:CleanupOwner("Kill")
    end

    Core:RegisterModule("Kill", Kill)
    local killOk, killErr = Core:StartModule("Kill")
    if not killOk then warn("[ARASAKA][MODULE:Kill] Falha:", killErr) end

    -- ABA INÍCIO // DASHBOARD ARASAKA
    local introTop = Instance.new("Frame", tabInicio)
    introTop.Size = UDim2.new(1, -20, 0, 70)
    introTop.Position = UDim2.new(0, 10, 0, 8)
    introTop.BackgroundColor3 = Color3.fromRGB(9, 9, 9)
    introTop.BorderSizePixel = 0
    Instance.new("UICorner", introTop).CornerRadius = UDim.new(0, 4)
    local introStroke = Instance.new("UIStroke", introTop)
    introStroke.Color = Color3.fromRGB(42, 42, 42)

    local introAccent = Instance.new("Frame", introTop)
    introAccent.Size = UDim2.new(0, 3, 1, 0)
    introAccent.BackgroundColor3 = Color3.fromRGB(215, 50, 50)
    introAccent.BorderSizePixel = 0

    local introLabel = Instance.new("TextLabel", introTop)
    introLabel.Size = UDim2.new(1, -32, 0, 25)
    introLabel.Position = UDim2.new(0, 17, 0, 11)
    introLabel.BackgroundTransparency = 1
    introLabel.Text = "BEM-VINDO DE VOLTA // @" .. player.Name
    introLabel.TextColor3 = Color3.fromRGB(245, 245, 245)
    introLabel.Font = Enum.Font.GothamBlack
    introLabel.TextSize = 15
    introLabel.TextXAlignment = Enum.TextXAlignment.Left

    local introSub = Instance.new("TextLabel", introTop)
    introSub.Size = UDim2.new(1, -32, 0, 16)
    introSub.Position = UDim2.new(0, 17, 0, 39)
    introSub.BackgroundTransparency = 1
    introSub.Text = "REDE ARASAKA // STATUS DO CLIENTE: ONLINE"
    introSub.TextColor3 = Color3.fromRGB(145, 35, 35)
    introSub.Font = Enum.Font.Code
    introSub.TextSize = 12
    introSub.TextXAlignment = Enum.TextXAlignment.Left

    local sessionBadge = Instance.new("TextLabel", introTop)
    sessionBadge.Size = UDim2.new(0, 145, 0, 28)
    sessionBadge.Position = UDim2.new(1, -160, 0.5, -14)
    sessionBadge.BackgroundColor3 = Color3.fromRGB(18, 18, 18)
    sessionBadge.BorderSizePixel = 0
    sessionBadge.Text = "●  SESSÃO ATIVA"
    sessionBadge.TextColor3 = Color3.fromRGB(70, 210, 90)
    sessionBadge.Font = Enum.Font.Code
    sessionBadge.TextSize = 11
    Instance.new("UICorner", sessionBadge).CornerRadius = UDim.new(0, 3)

    local statsGrid = Instance.new("Frame", tabInicio)
    statsGrid.Size = UDim2.new(1, -20, 0, 205)
    statsGrid.Position = UDim2.new(0, 10, 0, 88)
    statsGrid.BackgroundTransparency = 1

    local grid = Instance.new("UIGridLayout", statsGrid)
    grid.CellSize = UDim2.new(0.5, -6, 0, 96)
    grid.CellPadding = UDim2.new(0, 8, 0, 8)
    grid.SortOrder = Enum.SortOrder.LayoutOrder

    local function CriarStatCard(titulo, icone, order)
        local card = Instance.new("Frame", statsGrid)
        card.LayoutOrder = order
        card.BackgroundColor3 = Color3.fromRGB(10, 10, 10)
        card.BorderSizePixel = 0
        Instance.new("UICorner", card).CornerRadius = UDim.new(0, 4)
        local stroke = Instance.new("UIStroke", card)
        stroke.Color = Color3.fromRGB(35, 35, 35)

        local accent = Instance.new("Frame", card)
        accent.Size = UDim2.new(0, 2, 0, 52)
        accent.Position = UDim2.new(0, 0, 0.5, -26)
        accent.BackgroundColor3 = Color3.fromRGB(150, 28, 28)
        accent.BorderSizePixel = 0

        local icon = Instance.new("TextLabel", card)
        icon.Size = UDim2.new(0, 30, 0, 30)
        icon.Position = UDim2.new(0, 12, 0, 13)
        icon.BackgroundColor3 = Color3.fromRGB(22, 10, 10)
        icon.BorderSizePixel = 0
        icon.Text = icone
        icon.TextSize = 15
        Instance.new("UICorner", icon).CornerRadius = UDim.new(0, 3)

        local title = Instance.new("TextLabel", card)
        title.Size = UDim2.new(1, -56, 0, 16)
        title.Position = UDim2.new(0, 50, 0, 14)
        title.BackgroundTransparency = 1
        title.Text = string.upper(titulo)
        title.TextColor3 = Color3.fromRGB(105, 105, 105)
        title.Font = Enum.Font.Code
        title.TextSize = 12
        title.TextXAlignment = Enum.TextXAlignment.Left

        local value = Instance.new("TextLabel", card)
        value.Size = UDim2.new(1, -56, 0, 27)
        value.Position = UDim2.new(0, 50, 0, 32)
        value.BackgroundTransparency = 1
        value.Text = "CARREGANDO..."
        value.TextColor3 = Color3.fromRGB(235, 235, 235)
        value.Font = Enum.Font.GothamBold
        value.TextSize = 16
        value.TextXAlignment = Enum.TextXAlignment.Left
        value.RichText = true
        return value
    end

    local lblForca = CriarStatCard("Forca", "💪", 1)
    local lblDura = CriarStatCard("Durabilidade", "🛡", 2)
    local lblAgil = CriarStatCard("Agilidade", "⚡", 3)
    local lblRebirths = CriarStatCard("Rebirths", "🔄️", 4)

    local sessionPanel = Instance.new("Frame", tabInicio)
    sessionPanel.Size = UDim2.new(1, -20, 0, 67)
    sessionPanel.Position = UDim2.new(0, 10, 0, 304)
    sessionPanel.BackgroundColor3 = Color3.fromRGB(8, 8, 8)
    sessionPanel.BorderSizePixel = 0
    Instance.new("UICorner", sessionPanel).CornerRadius = UDim.new(0, 4)
    local sessionStroke = Instance.new("UIStroke", sessionPanel)
    sessionStroke.Color = Color3.fromRGB(35, 35, 35)

    local playIcon = Instance.new("TextLabel", sessionPanel)
    playIcon.Size = UDim2.new(0, 35, 0, 35)
    playIcon.Position = UDim2.new(0, 12, 0.5, -17)
    playIcon.BackgroundColor3 = Color3.fromRGB(22, 10, 10)
    playIcon.BorderSizePixel = 0
    playIcon.Text = "◷"
    playIcon.TextColor3 = Color3.fromRGB(215, 50, 50)
    playIcon.TextSize = 17
    Instance.new("UICorner", playIcon).CornerRadius = UDim.new(0, 3)

    local playTitle = Instance.new("TextLabel", sessionPanel)
    playTitle.Size = UDim2.new(0.5, 0, 0, 15)
    playTitle.Position = UDim2.new(0, 58, 0, 12)
    playTitle.BackgroundTransparency = 1
    playTitle.Text = "TEMPO DE SESSAO"
    playTitle.TextColor3 = Color3.fromRGB(105, 105, 105)
    playTitle.Font = Enum.Font.Code
    playTitle.TextSize = 8
    playTitle.TextXAlignment = Enum.TextXAlignment.Left

    local lblPlaytime = Instance.new("TextLabel", sessionPanel)
    lblPlaytime.Size = UDim2.new(0.6, 0, 0, 24)
    lblPlaytime.Position = UDim2.new(0, 58, 0, 29)
    lblPlaytime.BackgroundTransparency = 1
    lblPlaytime.Text = "00h 00m 00s"
    lblPlaytime.TextColor3 = Color3.fromRGB(235, 235, 235)
    lblPlaytime.Font = Enum.Font.GothamBold
    lblPlaytime.TextSize = 13
    lblPlaytime.TextXAlignment = Enum.TextXAlignment.Left

    local sessionCode = Instance.new("TextLabel", sessionPanel)
    sessionCode.Size = UDim2.new(0, 190, 0, 18)
    sessionCode.Position = UDim2.new(1, -202, 0.5, -9)
    sessionCode.BackgroundTransparency = 1
    sessionCode.Text = "SYS://ARASAKA/CLIENTE\nID://" .. tostring(player.UserId)
    sessionCode.TextColor3 = Color3.fromRGB(70, 70, 70)
    sessionCode.Font = Enum.Font.Code
    sessionCode.TextSize = 7
    sessionCode.TextXAlignment = Enum.TextXAlignment.Right

    local initialStats = { Forca = nil, Dura = nil, Agil = nil, Rebirths = nil }

    local function getRawStat(nome1, nome2)
        return Utils.ReadStat(player, nome1, nome2)
    end

    initialStats.Forca = getRawStat("Muscle", "Strength")
    initialStats.Dura = getRawStat("Durability")
    initialStats.Agil = getRawStat("Agility", "Speed")
    initialStats.Rebirths = getRawStat("Rebirths", "Rebirth")

    Core:StartWorker("UI.DashboardStats", function(isAlive)
        while isAlive() do
            if abas["Início"] and abas["Início"].container.Visible then
                pcall(function()
                    local curForca = getRawStat("Muscle", "Strength")
                    local curDura = getRawStat("Durability")
                    local curAgil = getRawStat("Agility", "Speed")
                    local curRebirths = getRawStat("Rebirths", "Rebirth")

                    local gainForca = curForca - (initialStats.Forca or curForca)
                    local gainDura = curDura - (initialStats.Dura or curDura)
                    local gainAgil = curAgil - (initialStats.Agil or curAgil)
                    local gainRebirths = curRebirths - (initialStats.Rebirths or curRebirths)

                    lblForca.Text = string.format("%s <font color='#50ff50'>(+%s)</font>", FormatNumber(curForca), FormatNumber(gainForca))
                    lblDura.Text = string.format("%s <font color='#50ff50'>(+%s)</font>", FormatNumber(curDura), FormatNumber(gainDura))
                    lblAgil.Text = string.format("%s <font color='#50ff50'>(+%s)</font>", FormatNumber(curAgil), FormatNumber(gainAgil))
                    lblRebirths.Text = string.format("%s <font color='#50ff50'>(+%s)</font>", FormatNumber(curRebirths), FormatNumber(gainRebirths))

                    local elapsed = os.time() - startTime
                    local hours = math.floor(elapsed / 3600)
                    local mins = math.floor((elapsed % 3600) / 60)
                    local secs = elapsed % 60
                    lblPlaytime.Text = string.format("%02dh %02dm %02ds", hours, mins, secs)
                end)
            end
            task.wait(1)
        end
    end)

    -- MODULE // FARMS
    function Farms:Init()
        Utils.PerfBegin("FARMS_UI")
    -- ABA FARMS
    local farmScroll = Instance.new("ScrollingFrame", tabFarms)
    farmScroll.Size = UDim2.new(1, -20, 1, -10)
    farmScroll.Position = UDim2.new(0, 10, 0, 5)
    farmScroll.BackgroundTransparency = 1
    farmScroll.ScrollBarThickness = 4

    local farmLayout = Instance.new("UIListLayout", farmScroll)
    farmLayout.Padding = UDim.new(0, 6)
    farmLayout.SortOrder = Enum.SortOrder.LayoutOrder

    farmLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        farmScroll.CanvasSize = UDim2.new(0, 0, 0, farmLayout.AbsoluteContentSize.Y + 20)
    end)

    local function CriarBotaoFarmScroll(texto, order)
        local btn = Utils.CreateTextButton(farmScroll, {
            LayoutOrder = order,
            Size = UDim2.new(1, -6, 0, 32),
            BackgroundColor3 = Color3.fromRGB(14, 14, 14),
            BorderSizePixel = 0,
            Text = texto .. ": OFF 🔴",
            TextColor3 = Color3.fromRGB(205, 205, 205),
            Font = Enum.Font.GothamBold,
            TextSize = 12,
            TextXAlignment = Enum.TextXAlignment.Left,
            CornerRadius = UDim.new(0, 2),
        })
        local stroke = Instance.new("UIStroke", btn)
        stroke.Color = Color3.fromRGB(42, 42, 42)
        stroke.Thickness = 1
        btn.MouseEnter:Connect(function()
            TweenService:Create(btn, TweenInfo.new(0.12), {BackgroundColor3 = Color3.fromRGB(35, 10, 10)}):Play()
            TweenService:Create(stroke, TweenInfo.new(0.12), {Color = Color3.fromRGB(215, 50, 50)}):Play()
        end)
        btn.MouseLeave:Connect(function()
            TweenService:Create(btn, TweenInfo.new(0.12), {BackgroundColor3 = Color3.fromRGB(14, 14, 14)}):Play()
            TweenService:Create(stroke, TweenInfo.new(0.12), {Color = Color3.fromRGB(42, 42, 42)}):Play()
        end)
        return btn
    end

    local autoFarmActive, autoRepsActive, autoUnifiedFarmActive, travarLocalActive = false, false, false, false
    local overlordRebirthActive = false
    local farmOpActive = false
    local customRebirthActive = false

    local targetRebirthValue = 0
    local targetRebirthActive = false
    local targetRebirthButton
    local startTargetRebirthWorker
    local startCustomRebirthWorker
    local startAutoRepsWorker
    local startUnifiedFarmWorker
    local startOverlordWorker
    local refreshTrainingWatchdog = function() end

    local function CriarSeparadorFarm(texto, order)
        local sep = Instance.new("TextLabel", farmScroll)
        sep.LayoutOrder = order
        sep.Size = UDim2.new(1, -6, 0, 24)
        sep.BackgroundTransparency = 1
        sep.Text = texto
        sep.TextColor3 = Color3.fromRGB(215, 50, 50)
        sep.Font = Enum.Font.GothamBold
        sep.TextSize = 12
        sep.TextXAlignment = Enum.TextXAlignment.Left
        return sep
    end
    local lockedCFrame, lockConnection, noclipConnection = nil, nil, nil
    local currentOffsetY = 60

    local customFarmingSlots = {}
    local customRebirthSlots = {}
    local saveFileName = "ArasakaHub_PetsConfig_" .. player.UserId .. ".json"

    local function SalvarConfiguracaoPets()
        if writefile then
            pcall(function()
                local data = {
                    farming = customFarmingSlots,
                    rebirth = customRebirthSlots
                }
                writefile(saveFileName, HttpService:JSONEncode(data))
            end)
        end
    end

    local function CarregarConfiguracaoPets()
        if readfile and isfile and isfile(saveFileName) then
            pcall(function()
                local raw = readfile(saveFileName)
                local data = HttpService:JSONDecode(raw)
                if data then
                    if data.farming then customFarmingSlots = data.farming end
                    if data.rebirth then customRebirthSlots = data.rebirth end
                end
            end)
        end
    end

    CarregarConfiguracaoPets()

    Core:StartWorker("Farms.ConfigAutosave", function(isAlive)
        while isAlive() do
            task.wait(60)
            if isAlive() then SalvarConfiguracaoPets() end
        end
    end)

    local function GetUserPetsCounts()
        local petsFolder = player:FindFirstChild("petsFolder")
        local petCounts = {}

        if petsFolder then
            for _, folder in ipairs(petsFolder:GetChildren()) do
                if folder:IsA("Folder") then
                    for _, pet in ipairs(folder:GetChildren()) do
                        local pName = pet.Name
                        petCounts[pName] = (petCounts[pName] or 0) + 1
                    end
                end
            end
        end
        return petCounts
    end

    local function GetUserPetsList()
        local counts = GetUserPetsCounts()
        local petNames = {}
        for name, _ in pairs(counts) do
            table.insert(petNames, name)
        end
        table.sort(petNames)
        return petNames
    end

    local function unequipAllPetsGeneral()
        local petsFolder = player:FindFirstChild("petsFolder")
        if not petsFolder then return end
        for _, folder in pairs(petsFolder:GetChildren()) do
            if folder:IsA("Folder") then
                for _, pet in pairs(folder:GetChildren()) do
                    pcall(function() ReplicatedStorage.rEvents.equipPetEvent:FireServer("unequipPet", pet) end)
                end
            end
        end
        task.wait(0.01)
    end

    local function equipCustomSlotsTeam(slotsTable)
        unequipAllPetsGeneral()
        local petsFolder = player:FindFirstChild("petsFolder")
        if not petsFolder then return end

        local requiredCounts = {}
        for slotIndex = 1, 9 do
            local petName = slotsTable[slotIndex]
            if petName and petName ~= "Nenhum" then
                requiredCounts[petName] = (requiredCounts[petName] or 0) + 1
            end
        end

        local equippedCounts = {}
        for petName, reqAmount in pairs(requiredCounts) do
            equippedCounts[petName] = 0
            for _, folder in ipairs(petsFolder:GetChildren()) do
                if folder:IsA("Folder") then
                    for _, petObj in ipairs(folder:GetChildren()) do
                        if petObj.Name == petName and equippedCounts[petName] < reqAmount then
                            pcall(function() ReplicatedStorage.rEvents.equipPetEvent:FireServer("equipPet", petObj) end)
                            equippedCounts[petName] = equippedCounts[petName] + 1
                            task.wait(0.03)
                        end
                        if equippedCounts[petName] >= reqAmount then break end
                    end
                end
                if equippedCounts[petName] >= reqAmount then break end
            end
        end
    end

    CriarSeparadorFarm("// REBIRTH PERSONALIZADO", 1)

    local rebirthTargetBox = Instance.new("TextBox", farmScroll)
    rebirthTargetBox.LayoutOrder = 2
    rebirthTargetBox.Size = UDim2.new(1, -6, 0, 32)
    rebirthTargetBox.BackgroundColor3 = Color3.fromRGB(14, 14, 14)
    rebirthTargetBox.BorderSizePixel = 0
    rebirthTargetBox.PlaceholderText = "REBIRTH META — digite a meta"
    rebirthTargetBox.Text = ""
    rebirthTargetBox.TextColor3 = Color3.fromRGB(235, 235, 235)
    rebirthTargetBox.PlaceholderColor3 = Color3.fromRGB(110, 110, 110)
    rebirthTargetBox.Font = Enum.Font.GothamBold
    rebirthTargetBox.TextSize = 12
    rebirthTargetBox.ClearTextOnFocus = false
    rebirthTargetBox.TextXAlignment = Enum.TextXAlignment.Left
    Instance.new("UICorner", rebirthTargetBox).CornerRadius = UDim.new(0, 2)
    local rebirthTargetStroke = Instance.new("UIStroke", rebirthTargetBox)
    rebirthTargetStroke.Color = Color3.fromRGB(42, 42, 42)
    rebirthTargetStroke.Thickness = 1

    rebirthTargetBox.FocusLost:Connect(function()
        local newValue = tonumber(rebirthTargetBox.Text)
        if newValue and newValue > 0 then
            targetRebirthValue = math.floor(newValue)
            rebirthTargetBox.Text = tostring(targetRebirthValue)
        else
            rebirthTargetBox.Text = ""
        end
    end)

    targetRebirthButton = CriarBotaoFarmScroll("AUTO REBIRTH TARGET", 3)
    local btnFarm = CriarBotaoFarmScroll("AUTO FARM BOSS ⚔️", 4)
    local btnRepsOnly = CriarBotaoFarmScroll("AUTO REPS 2X (SO FORCA) 🏋️", 5)
    local btnUnifiedFarm = CriarBotaoFarmScroll("AUTO REPS 2X + REBIRTH 🏋️🔄", 6)
    local btnOverlordRebirth = CriarBotaoFarmScroll("REBIRTH PACK OVERLORD 👑", 7)
    local btnFarmOp = CriarBotaoFarmScroll("FARM OP (11 PETS) 💎", 8)

    -- Quantidade de REPS do FARM OP. Este bloco fecha os temporários aqui
    -- para não aumentar os registradores locais do chunk principal.
    do
        local box = Instance.new("TextBox", farmScroll)
        box.Name = "ArasakaFarmOpRepsBox"
        box.LayoutOrder = 9
        box.Size = UDim2.new(1, -6, 0, 32)
        box.BackgroundColor3 = Color3.fromRGB(14, 14, 14)
        box.BorderSizePixel = 0
        box.PlaceholderText = "FARM OP — REPS POR CICLO (PADRAO: 1)"
        box.Text = ""
        box.TextColor3 = Color3.fromRGB(235, 235, 235)
        box.PlaceholderColor3 = Color3.fromRGB(110, 110, 110)
        box.Font = Enum.Font.GothamBold
        box.TextSize = 11
        box.ClearTextOnFocus = false
        box.TextXAlignment = Enum.TextXAlignment.Left
        box:SetAttribute("RepsPerCycle", 1)
        Instance.new("UICorner", box).CornerRadius = UDim.new(0, 2)
        local stroke = Instance.new("UIStroke", box)
        stroke.Color = Color3.fromRGB(42, 42, 42)
        stroke.Thickness = 1

        box.FocusLost:Connect(function()
            local value = tonumber(box.Text)
            if value and value >= 1 then
                value = math.max(1, math.floor(value))
                box:SetAttribute("RepsPerCycle", value)
                box.Text = tostring(value)
            else
                box:SetAttribute("RepsPerCycle", 1)
                box.Text = ""
            end
        end)
    end

    local btnConfigRebirth = Instance.new("TextButton", farmScroll)
    btnConfigRebirth.LayoutOrder = 10
    btnConfigRebirth.Size = UDim2.new(1, -6, 0, 32)
    btnConfigRebirth.BackgroundColor3 = Color3.fromRGB(215, 50, 50)
    btnConfigRebirth.Text = "CONFIGURAR REBIRTH ⚙️"
    btnConfigRebirth.TextColor3 = Color3.fromRGB(255, 255, 255)
    btnConfigRebirth.Font = Enum.Font.GothamBold
    btnConfigRebirth.TextSize = 11
    Instance.new("UICorner", btnConfigRebirth).CornerRadius = UDim.new(0, 6)

    local btnCustomRebirthToggle = CriarBotaoFarmScroll("CUSTOM REBIRTH AUTO 🔄", 11)
    local btnTravarLocal = CriarBotaoFarmScroll("TRAVAR LOCAL 📍", 12)

    local function AbrirJanelaConfigRebirth()
        local oldGui = targetGui:FindFirstChild("ArasakaConfigRebirth_Gui")
        if oldGui then oldGui:Destroy() end

        local configGui = Instance.new("ScreenGui", targetGui)
        configGui.Name = "ArasakaConfigRebirth_Gui"
        configGui.IgnoreGuiInset = true
        configGui.ResetOnSpawn = false
        configGui.DisplayOrder = 5000
        configGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

        local bgOverlay = Instance.new("TextButton", configGui)
        bgOverlay.Size = UDim2.new(1, 0, 1, 0)
        bgOverlay.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
        bgOverlay.BackgroundTransparency = 0.28
        bgOverlay.BorderSizePixel = 0
        bgOverlay.Text = ""
        bgOverlay.AutoButtonColor = false

        local mainFrame = Instance.new("Frame", configGui)
        mainFrame.Size = UDim2.new(0, 500, 0, 440)
        mainFrame.Position = UDim2.new(0.5, -250, 0.5, -220)
        mainFrame.BackgroundColor3 = Color3.fromRGB(6, 6, 6)
        mainFrame.BorderSizePixel = 0
        mainFrame.Active, mainFrame.Draggable = true, true
        Instance.new("UICorner", mainFrame).CornerRadius = UDim.new(0, 4)

        local stroke = Instance.new("UIStroke", mainFrame)
        stroke.Color = Color3.fromRGB(150, 25, 25)
        stroke.Thickness = 1

        local topLine = Instance.new("Frame", mainFrame)
        topLine.Size = UDim2.new(1, 0, 0, 3)
        topLine.BackgroundColor3 = Color3.fromRGB(215, 50, 50)
        topLine.BorderSizePixel = 0

        local header = Instance.new("Frame", mainFrame)
        header.Size = UDim2.new(1, 0, 0, 58)
        header.Position = UDim2.new(0, 0, 0, 3)
        header.BackgroundColor3 = Color3.fromRGB(9, 9, 9)
        header.BorderSizePixel = 0

        local logo = Instance.new("ImageLabel", header)
        logo.Size = UDim2.new(0, 30, 0, 30)
        logo.Position = UDim2.new(0, 14, 0.5, -15)
        logo.BackgroundTransparency = 1
        logo.Image = "rbxassetid://132397224962668"
        logo.ScaleType = Enum.ScaleType.Fit

        local titleLbl = Instance.new("TextLabel", header)
        titleLbl.Size = UDim2.new(1, -90, 0, 22)
        titleLbl.Position = UDim2.new(0, 52, 0, 8)
        titleLbl.BackgroundTransparency = 1
        titleLbl.Text = "ARASAKA // REBIRTH CONFIG"
        titleLbl.TextColor3 = Color3.fromRGB(235, 235, 235)
        titleLbl.Font = Enum.Font.GothamBlack
        titleLbl.TextSize = 13
        titleLbl.TextXAlignment = Enum.TextXAlignment.Left

        local subLbl = Instance.new("TextLabel", header)
        subLbl.Size = UDim2.new(1, -90, 0, 14)
        subLbl.Position = UDim2.new(0, 52, 0, 31)
        subLbl.BackgroundTransparency = 1
        subLbl.Text = "CORPORATION // PET LOADOUT MATRIX"
        subLbl.TextColor3 = Color3.fromRGB(155, 35, 35)
        subLbl.Font = Enum.Font.Code
        subLbl.TextSize = 8
        subLbl.TextXAlignment = Enum.TextXAlignment.Left

        local closeBtn = Instance.new("TextButton", mainFrame)
        closeBtn.Size = UDim2.new(0, 28, 0, 28)
        closeBtn.Position = UDim2.new(1, -39, 0.5, -14)
        closeBtn.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
        closeBtn.BorderSizePixel = 0
        closeBtn.Text = "×"
        closeBtn.TextColor3 = Color3.fromRGB(215, 50, 50)
        closeBtn.Font = Enum.Font.GothamBold
        closeBtn.TextSize = 16
        Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(0, 4)

        closeBtn.MouseButton1Click:Connect(function() configGui:Destroy() end)
        bgOverlay.MouseButton1Click:Connect(function() configGui:Destroy() end)

        local separator = Instance.new("Frame", mainFrame)
        separator.Size = UDim2.new(1, -24, 0, 1)
        separator.Position = UDim2.new(0, 12, 0, 65)
        separator.BackgroundColor3 = Color3.fromRGB(38, 38, 38)
        separator.BorderSizePixel = 0

        local matrixLabel = Instance.new("TextLabel", mainFrame)
        matrixLabel.Size = UDim2.new(1, -24, 0, 18)
        matrixLabel.Position = UDim2.new(0, 12, 0, 72)
        matrixLabel.BackgroundTransparency = 1
        matrixLabel.Text = "// SLOT MATRIX    TRAINING / REBIRTH"
        matrixLabel.TextColor3 = Color3.fromRGB(90, 90, 90)
        matrixLabel.Font = Enum.Font.Code
        matrixLabel.TextSize = 8
        matrixLabel.TextXAlignment = Enum.TextXAlignment.Left

        local scrollSlots = Instance.new("ScrollingFrame", mainFrame)
        scrollSlots.Size = UDim2.new(1, -24, 1, -125)
        scrollSlots.Position = UDim2.new(0, 12, 0, 94)
        scrollSlots.BackgroundTransparency = 1
        scrollSlots.ScrollBarThickness = 4

        local layoutSlots = Instance.new("UIListLayout", scrollSlots)
        layoutSlots.Padding = UDim.new(0, 6)

        layoutSlots:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
            scrollSlots.CanvasSize = UDim2.new(0, 0, 0, layoutSlots.AbsoluteContentSize.Y + 10)
        end)

        local function GetAvailablePetsForSlot(targetSlotsTable, currentSlotIndex)
            local userCounts = GetUserPetsCounts()
            local selectedCounts = {}

            for idx, name in pairs(targetSlotsTable) do
                if idx ~= currentSlotIndex and name and name ~= "Nenhum" then
                    selectedCounts[name] = (selectedCounts[name] or 0) + 1
                end
            end

            local availableList = {"Nenhum"}
            for name, maxCount in pairs(userCounts) do
                local used = selectedCounts[name] or 0
                if used < maxCount then
                    table.insert(availableList, name)
                end
            end
            table.sort(availableList, function(a, b)
                if a == "Nenhum" then return true end
                if b == "Nenhum" then return false end
                return a < b
            end)
            return availableList
        end

        for i = 1, 9 do
            local slotFrame = Instance.new("Frame", scrollSlots)
            slotFrame.Size = UDim2.new(1, -6, 0, 30)
            slotFrame.BackgroundColor3 = Color3.fromRGB(10, 10, 10)
            slotFrame.BorderSizePixel = 0
            local slotStroke = Instance.new("UIStroke", slotFrame)
            slotStroke.Color = Color3.fromRGB(28, 28, 28)
            slotStroke.Thickness = 1
            Instance.new("UICorner", slotFrame).CornerRadius = UDim.new(0, 4)

            local btnSlotTrain = Instance.new("TextButton", slotFrame)
            btnSlotTrain.Size = UDim2.new(0.48, 0, 1, 0)
            btnSlotTrain.BackgroundColor3 = Color3.fromRGB(14, 14, 14)
            btnSlotTrain.BorderSizePixel = 0
            btnSlotTrain.Text = "Tr. S" .. i .. ": " .. (customFarmingSlots[i] or "Nenhum")
            btnSlotTrain.TextColor3 = Color3.fromRGB(220, 220, 220)
            btnSlotTrain.Font = Enum.Font.GothamBold
            btnSlotTrain.TextSize = 12
            Instance.new("UICorner", btnSlotTrain).CornerRadius = UDim.new(0, 4)

            btnSlotTrain.MouseEnter:Connect(function()
                btnSlotTrain.BackgroundColor3 = Color3.fromRGB(34, 9, 9)
            end)
            btnSlotTrain.MouseLeave:Connect(function()
                btnSlotTrain.BackgroundColor3 = Color3.fromRGB(14, 14, 14)
            end)

            btnSlotTrain.MouseButton1Click:Connect(function()
                playClickSound()
                local options = GetAvailablePetsForSlot(customFarmingSlots, i)
                AbrirMenuSelecao("Slot " .. i .. " - Time Treino", options, function(val)
                    customFarmingSlots[i] = val
                    btnSlotTrain.Text = "Tr. S" .. i .. ": " .. val
                end)
            end)

            local btnSlotRebirth = Instance.new("TextButton", slotFrame)
            btnSlotRebirth.Size = UDim2.new(0.48, 0, 1, 0)
            btnSlotRebirth.Position = UDim2.new(0.52, 0, 0, 0)
            btnSlotRebirth.BackgroundColor3 = Color3.fromRGB(14, 14, 14)
            btnSlotRebirth.BorderSizePixel = 0
            btnSlotRebirth.Text = "Rb. S" .. i .. ": " .. (customRebirthSlots[i] or "Nenhum")
            btnSlotRebirth.TextColor3 = Color3.fromRGB(220, 220, 220)
            btnSlotRebirth.Font = Enum.Font.GothamBold
            btnSlotRebirth.TextSize = 12
            Instance.new("UICorner", btnSlotRebirth).CornerRadius = UDim.new(0, 4)

            btnSlotRebirth.MouseEnter:Connect(function()
                btnSlotRebirth.BackgroundColor3 = Color3.fromRGB(34, 9, 9)
            end)
            btnSlotRebirth.MouseLeave:Connect(function()
                btnSlotRebirth.BackgroundColor3 = Color3.fromRGB(14, 14, 14)
            end)

            btnSlotRebirth.MouseButton1Click:Connect(function()
                playClickSound()
                local options = GetAvailablePetsForSlot(customRebirthSlots, i)
                AbrirMenuSelecao("Slot " .. i .. " - Time Rebirth", options, function(val)
                    customRebirthSlots[i] = val
                    btnSlotRebirth.Text = "Rb. S" .. i .. ": " .. val
                end)
            end)
        end

        local btnSaveAndStart = Instance.new("TextButton", mainFrame)
        btnSaveAndStart.Size = UDim2.new(1, -24, 0, 34)
        btnSaveAndStart.Position = UDim2.new(0, 12, 1, -46)
        btnSaveAndStart.BackgroundColor3 = Color3.fromRGB(150, 28, 28)
        btnSaveAndStart.BorderSizePixel = 0
        btnSaveAndStart.Text = "SALVAR & INICIAR FARM 💾"
        btnSaveAndStart.TextColor3 = Color3.fromRGB(255, 255, 255)
        btnSaveAndStart.Font = Enum.Font.GothamBold
        btnSaveAndStart.TextSize = 11
        Instance.new("UICorner", btnSaveAndStart).CornerRadius = UDim.new(0, 6)

        btnSaveAndStart.MouseButton1Click:Connect(function()
            playClickSound()
            SalvarConfiguracaoPets()
            configGui:Destroy()
            customRebirthActive = true
            btnCustomRebirthToggle.Text = "CUSTOM REBIRTH AUTO: ON 🟢"
            btnCustomRebirthToggle.BackgroundColor3 = Color3.fromRGB(40, 160, 40)
            if startCustomRebirthWorker then startCustomRebirthWorker() end
            refreshTrainingWatchdog()
        end)
    end

    startTargetRebirthWorker = function()
        if not targetRebirthActive or targetRebirthValue <= 0 then
            Core:StopWorker("Farms.TargetRebirth")
            return
        end
        Core:StartWorker("Farms.TargetRebirth", function(isAlive)
            while isAlive() and targetRebirthActive and targetRebirthValue > 0 do
                local leaderstats = player:FindFirstChild("leaderstats")
                local rebirthsVal = leaderstats and leaderstats:FindFirstChild("Rebirths")
                if rebirthsVal then
                    local rebirthRemote = getRebirthRemote()
                    if rebirthsVal.Value >= targetRebirthValue then
                        targetRebirthActive = false
                        targetRebirthButton.Text = "AUTO REBIRTH TARGET: OFF 🔴"
                        targetRebirthButton.BackgroundColor3 = Color3.fromRGB(14, 14, 14)
                        break
                    elseif rebirthRemote then
                        pcall(function() rebirthRemote:InvokeServer("rebirthRequest") end)
                    end
                end
                task.wait(0.1)
            end
        end)
    end

    targetRebirthButton.MouseButton1Click:Connect(function()
        playClickSound()
        if targetRebirthValue <= 0 then return end
        targetRebirthActive = not targetRebirthActive
        targetRebirthButton.Text = "AUTO REBIRTH TARGET: " .. (targetRebirthActive and "ON 🟢" or "OFF 🔴")
        targetRebirthButton.BackgroundColor3 = targetRebirthActive and Color3.fromRGB(40, 120, 40) or Color3.fromRGB(14, 14, 14)
        if targetRebirthActive then startTargetRebirthWorker() else Core:StopWorker("Farms.TargetRebirth") end
    end)

    btnConfigRebirth.MouseButton1Click:Connect(function()
        playClickSound()
        AbrirJanelaConfigRebirth()
    end)

    startCustomRebirthWorker = function()
        if not customRebirthActive then
            Core:StopWorker("Farms.CustomRebirth")
            return
        end
        Core:StartWorker("Farms.CustomRebirth", function(isAlive)
            local lastEquippedState = ""
            while isAlive() and customRebirthActive do
                local leaderstats = player:FindFirstChild("leaderstats")
                local rebirthsVal = leaderstats and leaderstats:FindFirstChild("Rebirths")
                local strengthVal = leaderstats and leaderstats:FindFirstChild("Strength")

                if rebirthsVal and strengthVal then
                    local targetStr = 5000 + (rebirthsVal.Value * 2550)
                    local repsBurst = player.MembershipType == Enum.MembershipType.Premium and 6 or 12

                    if lastEquippedState ~= "train" then
                        equipCustomSlotsTeam(customFarmingSlots)
                        lastEquippedState = "train"
                    end

                    while isAlive() and customRebirthActive and strengthVal.Value < targetStr do
                        local event = getMuscleEvent()
                        if event then
                            for _ = 1, repsBurst do event:FireServer("rep") end
                        end
                        task.wait(0.01)
                    end

                    if isAlive() and customRebirthActive and strengthVal.Value >= targetStr then
                        if lastEquippedState ~= "rebirth" then
                            equipCustomSlotsTeam(customRebirthSlots)
                            lastEquippedState = "rebirth"
                        end
                        task.wait(0.05)
                        local startR = rebirthsVal.Value
                        local rebirthRemote = getRebirthRemote()
                        repeat
                            if rebirthRemote then pcall(function() rebirthRemote:InvokeServer("rebirthRequest") end) end
                            task.wait(0.1)
                        until rebirthsVal.Value > startR or not customRebirthActive or not isAlive()
                    end
                end
                task.wait(0.5)
            end
        end)
    end

    btnCustomRebirthToggle.MouseButton1Click:Connect(function()
        playClickSound()
        customRebirthActive = not customRebirthActive
        btnCustomRebirthToggle.Text = "CUSTOM REBIRTH AUTO: " .. (customRebirthActive and "ON 🟢" or "OFF 🔴")
        btnCustomRebirthToggle.BackgroundColor3 = customRebirthActive and Color3.fromRGB(40, 160, 40) or Color3.fromRGB(180, 30, 30)
        if customRebirthActive then startCustomRebirthWorker() else Core:StopWorker("Farms.CustomRebirth") end
        refreshTrainingWatchdog()
    end)

    startAutoRepsWorker = function()
        if not autoRepsActive then
            Core:StopWorker("Farms.AutoReps")
            return
        end
        Core:StartWorker("Farms.AutoReps", function(isAlive)
            while isAlive() and autoRepsActive do
                local event = getMuscleEvent()
                if event then
                    for _ = 1, 4 do pcall(function() event:FireServer("rep") end) end
                    RunService.Heartbeat:Wait()
                else
                    task.wait(0.05)
                end
            end
        end)
    end

    btnRepsOnly.MouseButton1Click:Connect(function()
        playClickSound()
        autoRepsActive = not autoRepsActive
        btnRepsOnly.Text = "AUTO REPS 2X (SO FORCA): " .. (autoRepsActive and "ON 🟢" or "OFF 🔴")
        btnRepsOnly.BackgroundColor3 = autoRepsActive and Color3.fromRGB(40, 160, 40) or Color3.fromRGB(180, 30, 30)
        if autoRepsActive then startAutoRepsWorker() else Core:StopWorker("Farms.AutoReps") end
        refreshTrainingWatchdog()
    end)

    startUnifiedFarmWorker = function()
        if not autoUnifiedFarmActive then
            Core:StopWorker("Farms.AutoUnified")
            return
        end
        Core:StartWorker("Farms.AutoUnified", function(isAlive)
            local lastRebirthTime = 0
            while isAlive() and autoUnifiedFarmActive do
                local event = getMuscleEvent()
                local rebirthRemote = getRebirthRemote()
                if event then
                    for _ = 1, 4 do pcall(function() event:FireServer("rep") end) end
                    if rebirthRemote and (tick() - lastRebirthTime >= 1) then
                        pcall(function() rebirthRemote:InvokeServer("rebirthRequest") end)
                        lastRebirthTime = tick()
                    end
                    RunService.Heartbeat:Wait()
                else
                    task.wait(0.05)
                end
            end
        end)
    end

    btnUnifiedFarm.MouseButton1Click:Connect(function()
        playClickSound()
        autoUnifiedFarmActive = not autoUnifiedFarmActive
        btnUnifiedFarm.Text = "AUTO REPS 2X + REBIRTH: " .. (autoUnifiedFarmActive and "ON 🟢" or "OFF 🔴")
        btnUnifiedFarm.BackgroundColor3 = autoUnifiedFarmActive and Color3.fromRGB(40, 160, 40) or Color3.fromRGB(180, 30, 30)
        if autoUnifiedFarmActive then startUnifiedFarmWorker() else Core:StopWorker("Farms.AutoUnified") end
        refreshTrainingWatchdog()
    end)

    -- WATCHDOG DE TREINO // 5 SEGUNDOS
    -- Aplica-se aos treinos comuns desta aba. OVERLORD e FARM OP (11 PETS)
    -- ficam fora para preservar exatamente as versões ajustadas recentemente.
    ;(function()
        local function getStrength()
            local ls = player:FindFirstChild("leaderstats")
            local v = ls and (ls:FindFirstChild("Strength") or ls:FindFirstChild("Muscle"))
            return v and tonumber(v.Value) or 0
        end

        local function equipWeightAndTrain()
            local char = player.Character
            local humanoid = char and char:FindFirstChildOfClass("Humanoid")
            local backpack = player:FindFirstChild("Backpack")
            if not char or not humanoid then return end

            local weight = char:FindFirstChild("Weight")
            if not weight and backpack then
                weight = backpack:FindFirstChild("Weight")
            end

            -- Compatibilidade caso o peso tenha variação no nome.
            if not weight then
                for _, container in ipairs({char, backpack}) do
                    if container then
                        for _, item in ipairs(container:GetChildren()) do
                            if item:IsA("Tool") and string.find(string.lower(item.Name), "weight", 1, true) then
                                weight = item
                                break
                            end
                        end
                    end
                    if weight then break end
                end
            end

            if weight and weight:IsA("Tool") and weight.Parent ~= char then
                pcall(function() humanoid:EquipTool(weight) end)
                task.wait()
            end

            local event = getMuscleEvent()
            if event then
                for _ = 1, 8 do
                    pcall(function() event:FireServer("rep") end)
                end
            end
        end

        refreshTrainingWatchdog = function()
            local active = autoRepsActive or autoUnifiedFarmActive or customRebirthActive
            if not active then
                Core:StopWorker("Farms.TrainingWatchdog")
                return
            end
            if Core:IsWorkerRunning("Farms.TrainingWatchdog") then return end

            Core:StartWorker("Farms.TrainingWatchdog", function(isAlive)
                local previous = getStrength()
                while isAlive() and (autoRepsActive or autoUnifiedFarmActive or customRebirthActive) do
                    local elapsed = 0
                    while elapsed < 5 and isAlive() and (autoRepsActive or autoUnifiedFarmActive or customRebirthActive) do
                        task.wait(0.25)
                        elapsed += 0.25
                    end
                    if not isAlive() then break end
                    local current = getStrength()
                    if current <= previous then equipWeightAndTrain() end
                    previous = getStrength()
                end
            end)
        end
    end)()

    local function unequipAllPetsOverlord()
        local petsFolder = player:FindFirstChild("petsFolder")
        if not petsFolder then return end
        for _, folder in pairs(petsFolder:GetChildren()) do
            if folder:IsA("Folder") then
                for _, pet in pairs(folder:GetChildren()) do
                    pcall(function() ReplicatedStorage.rEvents.equipPetEvent:FireServer("unequipPet", pet) end)
                end
            end
        end
        task.wait(0.01)
    end

    local function equipFarmingPetsOverlord()
        unequipAllPetsOverlord()
        local uniqueFolder = player:FindFirstChild("petsFolder") and player.petsFolder:FindFirstChild("Unique")
        if not uniqueFolder then return end

        local omegas, swifts, hounds = {}, {}, {}
        for _, pet in ipairs(uniqueFolder:GetChildren()) do
            if pet.Name == "Omega Overlord" then table.insert(omegas, pet)
            elseif pet.Name == "Swift Samurai" then table.insert(swifts, pet)
            elseif pet.Name == "Powercore Hound" then table.insert(hounds, pet) end
        end

        local equippedCount, currentPercent, maxSlots = 0, 0, 9
        for i = #omegas, 1, -1 do
            if equippedCount < maxSlots and currentPercent < 100 then
                pcall(function() ReplicatedStorage.rEvents.equipPetEvent:FireServer("equipPet", table.remove(omegas, i)) end)
                currentPercent += 20; equippedCount += 1
            end
        end
        for i = #swifts, 1, -1 do
            if equippedCount < maxSlots and currentPercent < 100 then
                pcall(function() ReplicatedStorage.rEvents.equipPetEvent:FireServer("equipPet", table.remove(swifts, i)) end)
                currentPercent += 15; equippedCount += 1
            end
        end
        if currentPercent >= 100 then
            for i = #hounds, 1, -1 do
                if equippedCount < maxSlots then
                    pcall(function() ReplicatedStorage.rEvents.equipPetEvent:FireServer("equipPet", table.remove(hounds, i)) end)
                    equippedCount += 1
                end
            end
        end
    end

    local function equipRebirthPetsOverlord()
        unequipAllPetsOverlord()
        local uniqueFolder = player:FindFirstChild("petsFolder") and player.petsFolder:FindFirstChild("Unique")
        if not uniqueFolder then return end

        local hydras, tribals = {}, {}
        for _, pet in ipairs(uniqueFolder:GetChildren()) do
            if pet.Name == "Titanium Hydra" then table.insert(hydras, pet)
            elseif pet.Name == "Tribal Overlord" then table.insert(tribals, pet) end
        end

        local equippedCount, maxSlots = 0, 9
        for _, pet in ipairs(hydras) do
            if equippedCount < maxSlots then
                pcall(function() ReplicatedStorage.rEvents.equipPetEvent:FireServer("equipPet", pet) end)
                equippedCount += 1
            end
        end
        for _, pet in ipairs(tribals) do
            if equippedCount < maxSlots then
                pcall(function() ReplicatedStorage.rEvents.equipPetEvent:FireServer("equipPet", pet) end)
                equippedCount += 1
            end
        end
    end

    startOverlordWorker = function()
        if not overlordRebirthActive then
            Core:StopWorker("Farms.Overlord")
            return
        end
        Core:StartWorker("Farms.Overlord", function(isAlive)
            while isAlive() and overlordRebirthActive do
                equipFarmingPetsOverlord()
                local leaderstats = player:FindFirstChild("leaderstats")
                local rebirthsVal = leaderstats and leaderstats:FindFirstChild("Rebirths")
                local strengthVal = leaderstats and leaderstats:FindFirstChild("Strength")

                if rebirthsVal and strengthVal then
                    local targetStr = 5000 + (rebirthsVal.Value * 2550)
                    local repsBurst = player.MembershipType == Enum.MembershipType.Premium and 6 or 12

                    while isAlive() and overlordRebirthActive and strengthVal.Value < targetStr do
                        local event = getMuscleEvent()
                        if event then
                            for _ = 1, repsBurst do event:FireServer("rep") end
                        end
                        task.wait(0.01)
                    end

                    if isAlive() and overlordRebirthActive and strengthVal.Value >= targetStr then
                        equipRebirthPetsOverlord()
                        task.wait(0.01)
                        local startR = rebirthsVal.Value
                        local rebirthRemote = getRebirthRemote()
                        repeat
                            if rebirthRemote then pcall(function() rebirthRemote:InvokeServer("rebirthRequest") end) end
                            task.wait(0.01)
                        until rebirthsVal.Value > startR or not overlordRebirthActive or not isAlive()
                    end
                end
                task.wait(0.01)
            end
        end)
    end

    btnOverlordRebirth.MouseButton1Click:Connect(function()
        playClickSound()
        overlordRebirthActive = not overlordRebirthActive
        btnOverlordRebirth.Text = "REBIRTH PACK OVERLORD: " .. (overlordRebirthActive and "ON 🟢" or "OFF 🔴")
        btnOverlordRebirth.BackgroundColor3 = overlordRebirthActive and Color3.fromRGB(40, 160, 40) or Color3.fromRGB(180, 30, 30)
        if overlordRebirthActive then startOverlordWorker() else Core:StopWorker("Farms.Overlord") end
    end)

    local farmOpActive = false

    local function equipRareBossPetsFarmOp()
        local petsFolder = player:FindFirstChild("petsFolder")
        local rareFolder = petsFolder and petsFolder:FindFirstChild("Rare")
        local rEvents = ReplicatedStorage:FindFirstChild("rEvents")
        local equipEvent = rEvents and rEvents:FindFirstChild("equipPetEvent")
        if not rareFolder or not equipEvent then return 0 end

        local rareBossPets = {}
        for _, pet in ipairs(rareFolder:GetChildren()) do
            if pet.Name == "Rare Boss Pet" then
                table.insert(rareBossPets, pet)
            end
        end

        local equippedCount = 0
        for i = #rareBossPets, 1, -1 do
            if equippedCount >= 11 or not farmOpActive or not Core:IsAlive() then
                break
            end

            local pet = rareBossPets[i]
            pcall(function()
                equipEvent:FireServer("equipPet", pet)
            end)
            equippedCount += 1
            task.wait(0.03)
        end

        return equippedCount
    end

    local function stopFarmOp()
        farmOpActive = false
        farmOpPetsEquipped = false
        Core:StopWorker("Farms.FarmOp")
    end

    local function startFarmOp()
        if Core:IsWorkerRunning("Farms.FarmOp") then return end
        Core:StartWorker("Farms.FarmOp", function(isAlive)
            while isAlive() and farmOpActive do
                local event = getMuscleEvent()

                if event then
                    -- Sem atraso artificial de treino: envia a quantidade escolhida
                    -- e apenas devolve o controle ao scheduler no próximo frame.
                    local repsBox = farmScroll:FindFirstChild("ArasakaFarmOpRepsBox")
                    local repsNow = math.max(1, math.floor(tonumber(repsBox and repsBox:GetAttribute("RepsPerCycle")) or 1))
                    for _ = 1, repsNow do
                        if not isAlive() or not farmOpActive then break end
                        pcall(function() event:FireServer("rep") end)
                    end
                    RunService.Heartbeat:Wait()
                else
                    RunService.Heartbeat:Wait()
                end
            end
        end)
    end

    btnFarmOp.MouseButton1Click:Connect(function()
        playClickSound()

        if farmOpActive then
            stopFarmOp()
            btnFarmOp.Text = "FARM OP (11 PETS): OFF 🔴"
            btnFarmOp.BackgroundColor3 = Color3.fromRGB(14, 14, 14)
        else
            farmOpActive = true
            farmOpPetsEquipped = false
            btnFarmOp.Text = "FARM OP (11 PETS): ON 🟢"
            btnFarmOp.BackgroundColor3 = Color3.fromRGB(40, 160, 40)
            startFarmOp()
        end
    end)

    local function equipPunch()
        local character = player.Character
        if not character then return nil end
        local humanoid = character:FindFirstChildOfClass("Humanoid")
        if humanoid and humanoid.Health > 0 then
            local currentTool = character:FindFirstChild("Punch")
            if not currentTool then
                local backpackPunch = player.Backpack:FindFirstChild("Punch")
                if backpackPunch then humanoid:EquipTool(backpackPunch); return backpackPunch end
            else return currentTool end
        end
        return nil
    end

    local function collectBossChest()
        local chest = workspace:FindFirstChild("BossChest")
        if not chest then return false end

        local prompt = chest:FindFirstChildWhichIsA("ProximityPrompt", true)
        if prompt and fireproximityprompt then
            pcall(function()
                fireproximityprompt(prompt)
            end)
            return true
        end

        return false
    end

    local function getBossTargetPosition()
        local events = workspace:FindFirstChild("Events")
        if not events then return nil end
        local bossArena = events:FindFirstChild("BossArena")
        if not bossArena then return nil end
        local targetBosses = {"Boss1", "Boss2", "Boss3", "Boss4", "Boss5", "Boss6", "BossRainbow"}
        for _, bossName in ipairs(targetBosses) do
            local bossObj = bossArena:FindFirstChild(bossName)
            if bossObj then
                if bossObj:IsA("Model") then
                    local humanoid = bossObj:FindFirstChildOfClass("Humanoid")
                    if not humanoid or humanoid.Health > 0 then
                        local part = bossObj.PrimaryPart or bossObj:FindFirstChild("HumanoidRootPart") or bossObj:FindFirstChild("Head") or bossObj:FindFirstChildOfClass("BasePart")
                        if part then
                            return part.Position
                        end
                    end
                elseif bossObj:IsA("BasePart") then
                    return bossObj.Position
                end
            end
        end
        local spawnPart = bossArena:FindFirstChild("BossSpawn") or bossArena:FindFirstChild("Part") or bossArena:FindFirstChildOfClass("BasePart")
        return spawnPart and spawnPart.Position or nil
    end

    local function setNoclip(enabled)
        if enabled then
            if not noclipConnection then
                noclipConnection = RunService.Stepped:Connect(function()
                    if player.Character then
                        for _, part in pairs(player.Character:GetDescendants()) do
                            if part:IsA("BasePart") and part.CanCollide then part.CanCollide = false end
                        end
                    end
                end)
            end
        elseif noclipConnection then
            noclipConnection:Disconnect()
            noclipConnection = nil
        end
    end

    local damageCharacterConnection = nil
    local damageCount = 0

    local function disconnectBossDamageChecks()
        Core:StopWorker("Farms.BossDamage")
        if damageCharacterConnection then
            damageCharacterConnection:Disconnect()
            damageCharacterConnection = nil
        end
    end

    local function bindBossDamageCheck()
        local character = player.Character
        local humanoid = character and character:FindFirstChildOfClass("Humanoid")
        if not humanoid then return end

        local lastHealth = humanoid.Health
        Core:StartWorker("Farms.BossDamage", function(isAlive)
            while isAlive() and autoFarmActive and humanoid.Parent do
                task.wait(5)
                if not isAlive() or not autoFarmActive or not humanoid.Parent then break end

                local currentHealth = humanoid.Health
                if currentHealth < lastHealth then
                    damageCount += 1
                    currentOffsetY = 45 + (damageCount * 2.5)
                end
                lastHealth = currentHealth
            end
        end)
    end

    btnFarm.MouseButton1Click:Connect(function()
        playClickSound()
        autoFarmActive = not autoFarmActive
        if autoFarmActive then
            currentOffsetY = 45
            damageCount = 0
            disconnectBossDamageChecks()
            bindBossDamageCheck()
            damageCharacterConnection = player.CharacterAdded:Connect(function()
                if autoFarmActive then
                    task.wait(0.5)
                    bindBossDamageCheck()
                end
            end)
            btnFarm.Text = "AUTO FARM BOSS: ON 🟢"
            btnFarm.BackgroundColor3 = Color3.fromRGB(40, 160, 40)

            Core:StartWorker("Farms.BossPosition", function(isAlive)
                setNoclip(true)
                while isAlive() and autoFarmActive do
                    collectBossChest()
                    local character = player.Character
                    local hrp = character and character:FindFirstChild("HumanoidRootPart")
                    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
                    local targetPos = getBossTargetPosition()
                    if hrp and humanoid and humanoid.Health > 0 and targetPos then
                        hrp.CFrame = CFrame.new(targetPos + Vector3.new(0, currentOffsetY, 0))
                        hrp.Velocity = Vector3.new(0, 0, 0)
                    end
                    RunService.Heartbeat:Wait()
                end
                setNoclip(false)
            end)

            Core:StartWorker("Farms.BossAttack", function(isAlive)
                while isAlive() and autoFarmActive do
                    local character = player.Character
                    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
                    if humanoid and humanoid.Health > 0 then
                        local punchTool = equipPunch()
                        if punchTool then pcall(function() punchTool:Activate() end) end
                        local event = getMuscleEvent()
                        if event then
                            event:FireServer("punch", "leftHand")
                            event:FireServer("punch", "rightHand")
                        end
                    end
                    RunService.Heartbeat:Wait()
                end
            end)
        else
            disconnectBossDamageChecks()
            Core:StopWorker("Farms.BossPosition")
            Core:StopWorker("Farms.BossAttack")
            setNoclip(false)
            damageCount = 0
            currentOffsetY = 45
            btnFarm.Text = "AUTO FARM BOSS: OFF 🔴"
            btnFarm.BackgroundColor3 = Color3.fromRGB(180, 30, 30)
        end
    end)

    btnTravarLocal.MouseButton1Click:Connect(function()
        playClickSound()
        travarLocalActive = not travarLocalActive
        if travarLocalActive then
            local character = player.Character
            local hrp = character and character:FindFirstChild("HumanoidRootPart")
            if hrp then
                lockedCFrame = hrp.CFrame
                btnTravarLocal.Text = "TRAVAR LOCAL: ON 🟢"
                btnTravarLocal.BackgroundColor3 = Color3.fromRGB(40, 160, 40)
                if lockConnection then lockConnection:Disconnect() end
                lockConnection = RunService.RenderStepped:Connect(function()
                    if not travarLocalActive or not Core:IsAlive() then
                        if lockConnection then lockConnection:Disconnect(); lockConnection = nil end
                        return
                    end
                    local char = player.Character
                    local root = char and char:FindFirstChild("HumanoidRootPart")
                    if root and lockedCFrame then
                        root.CFrame = lockedCFrame
                        root.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
                        root.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
                    end
                end)
            else
                travarLocalActive = false
            end
        else
            if lockConnection then lockConnection:Disconnect(); lockConnection = nil end
            lockedCFrame = nil
            btnTravarLocal.Text = "TRAVAR LOCAL: OFF 🔴"
            btnTravarLocal.BackgroundColor3 = Color3.fromRGB(180, 30, 30)
        end
    end)

        Utils.PerfEnd("FARMS_UI")
    end

    function Farms:Stop()
        for _, workerName in ipairs({
            "Farms.ConfigAutosave", "Farms.TargetRebirth", "Farms.CustomRebirth",
            "Farms.AutoReps", "Farms.AutoUnified", "Farms.TrainingWatchdog", "Farms.Overlord",
            "Farms.FarmOp", "Farms.BossDamage", "Farms.BossPosition", "Farms.BossAttack"
        }) do
            Core:StopWorker(workerName)
        end
    end

    Core:RegisterModule("Farms", Farms)
    local farmsOk, farmsErr = Core:StartModule("Farms")
    if not farmsOk then warn("[ARASAKA][MODULE:Farms] Falha:", farmsErr) end

    -- MODULE // TELEPORTS
    function Teleports:Init()
        Utils.PerfBegin("TELEPORTES_UI")
    -- ABA TELEPORTES
    local teleScroll = Instance.new("ScrollingFrame", tabTeleports)
    teleScroll.Size = UDim2.new(1, -20, 1, -10)
    teleScroll.Position = UDim2.new(0, 10, 0, 5)
    teleScroll.BackgroundTransparency = 1
    teleScroll.ScrollBarThickness = 4

    local teleLayout = Instance.new("UIListLayout", teleScroll)
    teleLayout.Padding = UDim.new(0, 6)
    teleLayout.SortOrder = Enum.SortOrder.LayoutOrder

    teleLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        teleScroll.CanvasSize = UDim2.new(0, 0, 0, teleLayout.AbsoluteContentSize.Y + 20)
    end)

    local locations = {
        {"Ilha Principal", CFrame.new(16, 9, 133)},
        {"Muscle King Academia", CFrame.new(-8665, 17, -5792)},
        {"Legends Academia", CFrame.new(4516, 991, -3856)},
        {"Jungle Academia", CFrame.new(-8543, 6, 2400)},
        {"Infernal Academia", CFrame.new(-6759, 7, -1284)},
        {"Mythical Academia", CFrame.new(2250, 7, 1073)},
        {"Frost Academia", CFrame.new(-2623, 7, -409)},
        {"Industrial Academia", CFrame.new(-5414.23, 89.76, 4941.73)}
    }

    for idx, loc in ipairs(locations) do
        local tpBtn = Instance.new("TextButton", teleScroll)
        tpBtn.LayoutOrder = idx
        tpBtn.Size = UDim2.new(1, -6, 0, 34)
        tpBtn.BackgroundColor3 = Color3.fromRGB(28, 28, 28)
        tpBtn.Text = "📌 " .. loc[1]
        tpBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
        tpBtn.Font = Enum.Font.GothamBold
        tpBtn.TextSize = 13
        Instance.new("UICorner", tpBtn).CornerRadius = UDim.new(0, 6)

        tpBtn.MouseButton1Click:Connect(function()
            playClickSound()
            if player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
                player.Character.HumanoidRootPart.CFrame = loc[2]
            end
        end)
    end

        Utils.PerfEnd("TELEPORTES_UI")
    end
    Core:RegisterModule("Teleports", Teleports)
    local teleOk, teleErr = Core:StartModule("Teleports")
    if not teleOk then warn("[ARASAKA][MODULE:Teleports] Falha:", teleErr) end

    -- MODULE // PETS
    function Pets:Init()
        Utils.PerfBegin("PETS_UI")
    -- ABA PETS
    local petScroll = Instance.new("ScrollingFrame", tabPets)
    petScroll.Size = UDim2.new(1, -20, 1, -10)
    petScroll.Position = UDim2.new(0, 10, 0, 5)
    petScroll.BackgroundTransparency = 1
    petScroll.ScrollBarThickness = 4

    local petLayout = Instance.new("UIListLayout", petScroll)
    petLayout.Padding = UDim.new(0, 5)
    petLayout.SortOrder = Enum.SortOrder.LayoutOrder

    petLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        petScroll.CanvasSize = UDim2.new(0, 0, 0, petLayout.AbsoluteContentSize.Y + 20)
    end)

    local function CriarSecaoTitulo(txt, order)
        local lbl = Instance.new("TextLabel", petScroll)
        lbl.LayoutOrder = order
        lbl.Size = UDim2.new(1, 0, 0, 20)
        lbl.BackgroundTransparency = 1
        lbl.Text = txt
        lbl.TextColor3 = Color3.fromRGB(215, 50, 50)
        lbl.Font = Enum.Font.GothamBold
        lbl.TextSize = 13
        lbl.TextXAlignment = Enum.TextXAlignment.Left
    end

    local PetShopRuntime = ReplicatedStorage:WaitForChild("shared", 5) and ReplicatedStorage.shared:WaitForChild("runtime", 5)
    local PetShopFolder = PetShopRuntime and PetShopRuntime:WaitForChild("cPetShopFolder", 5)
    local PetShopRemote = ReplicatedStorage:FindFirstChild("rEvents") and ReplicatedStorage.rEvents:FindFirstChild("cPetShopRemote")

    local PetShopData = { SelectedPet = nil, PetList = {} }
    local AuraData = { SelectedAura = nil, AuraList = {} }
    local TradeData = { SelectedPlayer = nil }

    if PetShopFolder then
        for _, item in ipairs(PetShopFolder:GetChildren()) do
            if item:GetAttribute("IsPowerUp") == true then table.insert(AuraData.AuraList, item.Name)
            else table.insert(PetShopData.PetList, item.Name) end
        end

        table.sort(PetShopData.PetList)
        table.sort(AuraData.AuraList)
    end

    CriarSecaoTitulo("🛒 Pet Shop:", 1)

    local btnSelectPetShop = Instance.new("TextButton", petScroll)
    btnSelectPetShop.LayoutOrder = 2
    btnSelectPetShop.Size = UDim2.new(1, -6, 0, 28)
    btnSelectPetShop.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
    btnSelectPetShop.Text = "Escolher Pet / Aura: Nenhum"
    btnSelectPetShop.TextColor3 = Color3.fromRGB(220, 220, 220)
    btnSelectPetShop.Font = Enum.Font.GothamBold
    btnSelectPetShop.TextSize = 11
    Instance.new("UICorner", btnSelectPetShop).CornerRadius = UDim.new(0, 4)

    btnSelectPetShop.MouseButton1Click:Connect(function()
        playClickSound()
        local combinedList = {}
        for _, p in ipairs(PetShopData.PetList) do table.insert(combinedList, p) end
        for _, a in ipairs(AuraData.AuraList) do table.insert(combinedList, "[Aura] " .. a) end

        AbrirMenuSelecao("Selecione um Pet ou Aura", combinedList, function(val, text)
            local cleanName = text:gsub("%[Aura%] ", "")
            PetShopData.SelectedPet = cleanName
            btnSelectPetShop.Text = "Pet/Aura: " .. cleanName
        end)
    end)

    local autoHatchActive = false
    local btnBuyPet = Instance.new("TextButton", petScroll)
    btnBuyPet.LayoutOrder = 3
    btnBuyPet.Size = UDim2.new(1, -6, 0, 28)
    btnBuyPet.BackgroundColor3 = Color3.fromRGB(180, 30, 30)
    btnBuyPet.Text = "Comprar Pet (Auto Hatch): OFF 🔴"
    btnBuyPet.TextColor3 = Color3.fromRGB(255, 255, 255)
    btnBuyPet.Font = Enum.Font.GothamBold
    btnBuyPet.TextSize = 11
    Instance.new("UICorner", btnBuyPet).CornerRadius = UDim.new(0, 4)

    btnBuyPet.MouseButton1Click:Connect(function()
        playClickSound()
        autoHatchActive = not autoHatchActive
        btnBuyPet.Text = "Comprar Pet (Auto Hatch): " .. (autoHatchActive and "ON 🟢" or "OFF 🔴")
        btnBuyPet.BackgroundColor3 = autoHatchActive and Color3.fromRGB(40, 160, 40) or Color3.fromRGB(180, 30, 30)
        
        if autoHatchActive then
            task.spawn(function()
                while autoHatchActive and Core:IsAlive() do
                    if PetShopData.SelectedPet and PetShopFolder and PetShopRemote then
                        local selectedObj = PetShopFolder:FindFirstChild(PetShopData.SelectedPet)
                        if selectedObj then pcall(function() PetShopRemote:InvokeServer(selectedObj) end) end
                    end
                    task.wait(0.01)
                end
            end)
        end
    end)

    ;(function()
        --==================================================
        -- OVERCHARGED CRYSTAL // AUTO OPEN + AUTO SELL
        -- Pets marcados abaixo são vendidos automaticamente.
        -- Qualquer pet removido/desmarcado da lista será mantido.
        -- O pet raro de 1% não entra na lista e, portanto, nunca é auto-vendido.
        --==================================================
        local CrystalRemote = ReplicatedStorage:FindFirstChild("rEvents") and ReplicatedStorage.rEvents:FindFirstChild("openCrystalRemote")
        local overchargedAutoOpen = false
        local overchargedCrystalName = "Overcharged Crystal"
        local overchargedBulkAmount = 10
    
        local overchargedAutoSellPets = {
            ["Volt Wolf"] = true,
            ["Shard Dragon"] = true,
            ["Surge Tiger"] = true,
            ["Core Golem"] = true,
            ["Plasma Jelly"] = true,
        }
    
        local function SaveOverchargedAutoSell()
            if not CrystalRemote then return false end
            local petsToSell = {}
            for petName, enabled in pairs(overchargedAutoSellPets) do
                if enabled then
                    petsToSell[petName] = true
                end
            end
    
            return pcall(function()
                CrystalRemote:InvokeServer(
                    "saveAutoSell",
                    overchargedCrystalName,
                    {
                        Pets = petsToSell,
                        Enabled = true,
                        Auras = {}
                    }
                )
            end)
        end
    
        CriarSecaoTitulo("⚡ Overcharged Crystal:", 11)
    
        local overchargedInfo = Instance.new("TextLabel", petScroll)
        overchargedInfo.LayoutOrder = 12
        overchargedInfo.Size = UDim2.new(1, -6, 0, 32)
        overchargedInfo.BackgroundColor3 = Color3.fromRGB(16, 16, 18)
        overchargedInfo.Text = "AUTO SELL // marque apenas os pets que deseja excluir"
        overchargedInfo.TextColor3 = Color3.fromRGB(180, 180, 185)
        overchargedInfo.Font = Enum.Font.Gotham
        overchargedInfo.TextSize = 10
        Instance.new("UICorner", overchargedInfo).CornerRadius = UDim.new(0, 4)
    
        local autoSellButtons = {}
        local autoSellNames = {"Volt Wolf", "Shard Dragon", "Surge Tiger", "Core Golem", "Plasma Jelly"}
    
        local function UpdateAutoSellButton(petName)
            local btn = autoSellButtons[petName]
            if not btn then return end
            local enabled = overchargedAutoSellPets[petName] == true
            btn.Text = petName .. " // AUTO EXCLUIR: " .. (enabled and "ON 🟢" or "OFF 🔴")
            btn.BackgroundColor3 = enabled and Color3.fromRGB(35, 115, 55) or Color3.fromRGB(95, 25, 30)
        end
    
        for index, petName in ipairs(autoSellNames) do
            local btn = Instance.new("TextButton", petScroll)
            btn.LayoutOrder = 12 + index
            btn.Size = UDim2.new(1, -6, 0, 27)
            btn.TextColor3 = Color3.fromRGB(245, 245, 245)
            btn.Font = Enum.Font.GothamBold
            btn.TextSize = 10
            Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 4)
            autoSellButtons[petName] = btn
            UpdateAutoSellButton(petName)
    
            btn.MouseButton1Click:Connect(function()
                playClickSound()
                overchargedAutoSellPets[petName] = not overchargedAutoSellPets[petName]
                UpdateAutoSellButton(petName)
                SaveOverchargedAutoSell()
            end)
        end
    
        local btnOverchargedOpen = Instance.new("TextButton", petScroll)
        btnOverchargedOpen.LayoutOrder = 17.5
        btnOverchargedOpen.Size = UDim2.new(1, -6, 0, 30)
        btnOverchargedOpen.BackgroundColor3 = Color3.fromRGB(180, 30, 30)
        btnOverchargedOpen.Text = "AUTO ABRIR OVERCHARGED x10: OFF 🔴"
        btnOverchargedOpen.TextColor3 = Color3.fromRGB(255, 255, 255)
        btnOverchargedOpen.Font = Enum.Font.GothamBold
        btnOverchargedOpen.TextSize = 11
        Instance.new("UICorner", btnOverchargedOpen).CornerRadius = UDim.new(0, 4)
    
        btnOverchargedOpen.MouseButton1Click:Connect(function()
            playClickSound()
            overchargedAutoOpen = not overchargedAutoOpen
            btnOverchargedOpen.Text = "AUTO ABRIR OVERCHARGED x10: " .. (overchargedAutoOpen and "ON 🟢" or "OFF 🔴")
            btnOverchargedOpen.BackgroundColor3 = overchargedAutoOpen and Color3.fromRGB(40, 160, 40) or Color3.fromRGB(180, 30, 30)
    
            if overchargedAutoOpen then
                SaveOverchargedAutoSell()
                task.spawn(function()
                    while overchargedAutoOpen and Core:IsAlive() do
                        if CrystalRemote then
                            pcall(function()
                                CrystalRemote:InvokeServer("openCrystalBulk", overchargedCrystalName, overchargedBulkAmount)
                            end)
                        end
                        task.wait(0.01)
                    end
                end)
            end
        end)
    
    end)()

    CriarSecaoTitulo("🧬 Evolução Automática:", 18)

    local btnSelectEvolve = Instance.new("TextButton", petScroll)
    btnSelectEvolve.LayoutOrder = 19
    btnSelectEvolve.Size = UDim2.new(1, -6, 0, 28)
    btnSelectEvolve.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
    btnSelectEvolve.Text = "Escolher Pet p/ Evoluir: Nenhum"
    btnSelectEvolve.TextColor3 = Color3.fromRGB(220, 220, 220)
    btnSelectEvolve.Font = Enum.Font.GothamBold
    btnSelectEvolve.TextSize = 11
    Instance.new("UICorner", btnSelectEvolve).CornerRadius = UDim.new(0, 4)

    btnSelectEvolve.MouseButton1Click:Connect(function()
        playClickSound()
        local userPets = GetUserPetsList()
        if #userPets > 0 then
            AbrirMenuSelecao("Selecione o Pet para Evoluir", userPets, function(val, text)
                PetShopData.SelectedPet = val
                btnSelectEvolve.Text = "Pet p/ Evoluir: " .. val
            end)
        else
            btnSelectEvolve.Text = "Nenhum Pet encontrado no inventário!"
        end
    end)

    local autoEvolveActive = false
    local btnEvolvePet = Instance.new("TextButton", petScroll)
    btnEvolvePet.LayoutOrder = 20
    btnEvolvePet.Size = UDim2.new(1, -6, 0, 28)
    btnEvolvePet.BackgroundColor3 = Color3.fromRGB(180, 30, 30)
    btnEvolvePet.Text = "Auto Evoluir: OFF 🔴"
    btnEvolvePet.TextColor3 = Color3.fromRGB(255, 255, 255)
    btnEvolvePet.Font = Enum.Font.GothamBold
    btnEvolvePet.TextSize = 11
    Instance.new("UICorner", btnEvolvePet).CornerRadius = UDim.new(0, 4)

    btnEvolvePet.MouseButton1Click:Connect(function()
        playClickSound()
        autoEvolveActive = not autoEvolveActive
        btnEvolvePet.Text = "Auto Evoluir: " .. (autoEvolveActive and "ON 🟢" or "OFF 🔴")
        btnEvolvePet.BackgroundColor3 = autoEvolveActive and Color3.fromRGB(40, 160, 40) or Color3.fromRGB(180, 30, 30)

        if autoEvolveActive then
            task.spawn(function()
                while autoEvolveActive and Core:IsAlive() do
                    if PetShopData.SelectedPet and ReplicatedStorage:FindFirstChild("rEvents") and ReplicatedStorage.rEvents:FindFirstChild("petEvolveEvent") then
                        pcall(function() ReplicatedStorage.rEvents.petEvolveEvent:FireServer("evolvePet", PetShopData.SelectedPet) end)
                    end
                    task.wait(0.01)
                end
            end)
        end
    end)

    CriarSecaoTitulo("🤝 Trocas Automáticas:", 21)

    local btnSelectPlayer = Instance.new("TextButton", petScroll)
    btnSelectPlayer.LayoutOrder = 22
    btnSelectPlayer.Size = UDim2.new(1, -6, 0, 28)
    btnSelectPlayer.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
    btnSelectPlayer.Text = "Escolher Jogador: Nenhum"
    btnSelectPlayer.TextColor3 = Color3.fromRGB(220, 220, 220)
    btnSelectPlayer.Font = Enum.Font.GothamBold
    btnSelectPlayer.TextSize = 11
    Instance.new("UICorner", btnSelectPlayer).CornerRadius = UDim.new(0, 4)

    btnSelectPlayer.MouseButton1Click:Connect(function()
        playClickSound()
        local plist = {}
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= player then table.insert(plist, {Text = p.DisplayName .. " (@" .. p.Name .. ")", Value = p}) end
        end

        if #plist > 0 then
            AbrirMenuSelecao("Selecione o Jogador", plist, function(val, text)
                TradeData.SelectedPlayer = val
                btnSelectPlayer.Text = "Jogador: " .. text
            end)
        else
            btnSelectPlayer.Text = "Sem jogadores disponíveis!"
        end
    end)

    local btnSelectTradePet = Instance.new("TextButton", petScroll)
    btnSelectTradePet.LayoutOrder = 23
    btnSelectTradePet.Size = UDim2.new(1, -6, 0, 28)
    btnSelectTradePet.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
    btnSelectTradePet.Text = "Escolher Pet p/ Troca: Nenhum"
    btnSelectTradePet.TextColor3 = Color3.fromRGB(220, 220, 220)
    btnSelectTradePet.Font = Enum.Font.GothamBold
    btnSelectTradePet.TextSize = 11
    Instance.new("UICorner", btnSelectTradePet).CornerRadius = UDim.new(0, 4)

    btnSelectTradePet.MouseButton1Click:Connect(function()
        playClickSound()
        local userPets = GetUserPetsList()
        if #userPets > 0 then
            AbrirMenuSelecao("Selecione o Pet para Troca", userPets, function(val, text)
                PetShopData.SelectedPet = val
                btnSelectTradePet.Text = "Pet p/ Troca: " .. val
            end)
        else
            btnSelectTradePet.Text = "Nenhum Pet encontrado!"
        end
    end)

    local autoTradeActive = false
    local btnTradePet = Instance.new("TextButton", petScroll)
    btnTradePet.LayoutOrder = 24
    btnTradePet.Size = UDim2.new(1, -6, 0, 28)
    btnTradePet.BackgroundColor3 = Color3.fromRGB(180, 30, 30)
    btnTradePet.Text = "Auto Troca: OFF 🔴"
    btnTradePet.TextColor3 = Color3.fromRGB(255, 255, 255)
    btnTradePet.Font = Enum.Font.GothamBold
    btnTradePet.TextSize = 11
    Instance.new("UICorner", btnTradePet).CornerRadius = UDim.new(0, 4)

    btnTradePet.MouseButton1Click:Connect(function()
        playClickSound()
        autoTradeActive = not autoTradeActive
        btnTradePet.Text = "Auto Troca: " .. (autoTradeActive and "ON 🟢" or "OFF 🔴")
        btnTradePet.BackgroundColor3 = autoTradeActive and Color3.fromRGB(40, 160, 40) or Color3.fromRGB(180, 30, 30)

        if autoTradeActive then
            task.spawn(function()
                while autoTradeActive and Core:IsAlive() do
                    if TradeData.SelectedPlayer and PetShopData.SelectedPet then
                        local tradingEvent = ReplicatedStorage:FindFirstChild("rEvents") and ReplicatedStorage.rEvents:FindFirstChild("tradingEvent")
                        local petsFolder = player:FindFirstChild("petsFolder")

                        if tradingEvent and petsFolder then
                            pcall(function() tradingEvent:FireServer("sendTradeRequest", TradeData.SelectedPlayer) end)
                            task.wait(0.01)
                            local offered = 0
                            
                            for _, folder in ipairs(petsFolder:GetChildren()) do
                                if folder:IsA("Folder") then
                                    for _, petObj in ipairs(folder:GetChildren()) do
                                        if not autoTradeActive then break end
                                        if petObj.Name == PetShopData.SelectedPet then
                                            pcall(function() tradingEvent:FireServer("offerItem", petObj) end)
                                            offered += 1
                                            task.wait(0.01)
                                            if offered >= 10 then break end
                                        end
                                    end
                                end
                                if offered >= 10 then break end
                            end
                            task.wait(0.01)
                            if autoTradeActive then pcall(function() tradingEvent:FireServer("acceptTrade") end) end
                        end
                    end
                    task.wait(1)
                end
            end)
        end
    end)

        Utils.PerfEnd("PETS_UI")
    end
    Core:RegisterModule("Pets", Pets)
    local petsOk, petsErr = Core:StartModule("Pets")
    if not petsOk then warn("[ARASAKA][MODULE:Pets] Falha:", petsErr) end

    -- MODULE // VISUAL
    function Visual:Init()
        Utils.PerfBegin("VISUAL_UI")
    -- ABA VISUAL
    local rtxActive, vibeActive, antiLagActive, terrorActive, fotorealistaActive, blackScreenActive = false, false, false, false, false, false

    local defaultLighting = {
        Ambient = Lighting.Ambient, OutdoorAmbient = Lighting.OutdoorAmbient, Brightness = Lighting.Brightness,
        FogEnd = Lighting.FogEnd, FogColor = Lighting.FogColor, ClockTime = Lighting.ClockTime, GlobalShadows = Lighting.GlobalShadows,
        GeographicLatitude = Lighting.GeographicLatitude, ShadowSoftness = Lighting.ShadowSoftness
    }

    local function CriarBotaoVisual(parent, texto, posY)
        local btn = Instance.new("TextButton", parent)
        btn.Size = UDim2.new(1, -20, 0, 30)
        btn.Position = UDim2.new(0, 10, 0, posY)
        btn.BackgroundColor3 = Color3.fromRGB(180, 30, 30)
        btn.Text = texto .. ": OFF 🔴"
        btn.TextColor3 = Color3.fromRGB(255, 255, 255)
        btn.Font = Enum.Font.GothamBold
        btn.TextSize = 11
        Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)
        return btn
    end

    local btnRTX = CriarBotaoVisual(tabVisual, "MODO RTX 🌟", 10)
    local btnVibe = CriarBotaoVisual(tabVisual, "VIBE AMBIENTE + METEORES 🌌", 45)
    local btnAntiLag = CriarBotaoVisual(tabVisual, "MODO ANTI-LAG ⚡", 80)
    local btnTerror = CriarBotaoVisual(tabVisual, "MODO TERROR 🩸", 115)
    local btnFotorealista = CriarBotaoVisual(tabVisual, "MODO FOTORREALISTA ULTRA 📸", 150)
    local btnBlackScreen = CriarBotaoVisual(tabVisual, "MODO TELA PRETA 🖤", 185)

    btnRTX.MouseButton1Click:Connect(function()
        playClickSound()
        rtxActive = not rtxActive
        btnRTX.Text = "MODO RTX: " .. (rtxActive and "ON 🟢" or "OFF 🔴")
        btnRTX.BackgroundColor3 = rtxActive and Color3.fromRGB(40, 160, 40) or Color3.fromRGB(180, 30, 30)
        if rtxActive then
            Lighting.GlobalShadows = true; Lighting.ShadowSoftness = 0.2
            Lighting.Brightness = 3; Lighting.ClockTime = 14; Lighting.GeographicLatitude = 41.5
            Lighting.Ambient = Color3.fromRGB(150, 150, 150); Lighting.OutdoorAmbient = Color3.fromRGB(120, 120, 120)

            local sunRays = Lighting:FindFirstChildOfClass("SunRaysEffect") or Instance.new("SunRaysEffect", Lighting)
            sunRays.Intensity = 0.25; sunRays.Spread = 1

            local bloom = Lighting:FindFirstChildOfClass("BloomEffect") or Instance.new("BloomEffect", Lighting)
            bloom.Intensity = 1.2; bloom.Size = 24; bloom.Threshold = 0.8

            local blur = Lighting:FindFirstChildOfClass("BlurEffect") or Instance.new("BlurEffect", Lighting)
            blur.Size = 4
        else
            Lighting.GlobalShadows = defaultLighting.GlobalShadows; Lighting.ShadowSoftness = defaultLighting.ShadowSoftness
            Lighting.Brightness = defaultLighting.Brightness; Lighting.ClockTime = defaultLighting.ClockTime
            Lighting.GeographicLatitude = defaultLighting.GeographicLatitude; Lighting.Ambient = defaultLighting.Ambient; Lighting.OutdoorAmbient = defaultLighting.OutdoorAmbient
            for _, v in ipairs(Lighting:GetChildren()) do
                if v:IsA("SunRaysEffect") or v:IsA("BloomEffect") or v:IsA("BlurEffect") then v:Destroy() end
            end
        end
    end)

    btnVibe.MouseButton1Click:Connect(function()
        playClickSound()
        vibeActive = not vibeActive
        btnVibe.Text = "VIBE AMBIENTE: " .. (vibeActive and "ON 🟢" or "OFF 🔴")
        btnVibe.BackgroundColor3 = vibeActive and Color3.fromRGB(40, 160, 40) or Color3.fromRGB(180, 30, 30)
        if vibeActive then
            Lighting.Ambient = Color3.fromRGB(80, 0, 120); Lighting.OutdoorAmbient = Color3.fromRGB(40, 0, 80); Lighting.ClockTime = 0
            task.spawn(function()
                while vibeActive and Core:IsAlive() do
                    local m = Instance.new("Part", workspace)
                    m.Size = Vector3.new(2, 2, 2); m.Position = player.Character and player.Character.HumanoidRootPart.Position + Vector3.new(math.random(-100, 100), 100, math.random(-100, 100)) or Vector3.new(0, 100, 0)
                    m.Color = Color3.fromRGB(255, 0, 150); m.Material = Enum.Material.Neon; m.Velocity = Vector3.new(math.random(-20, 20), -50, math.random(-20, 20))
                    Debris:AddItem(m, 3)
                    task.wait(1)
                end
            end)
        else
            Lighting.Ambient = defaultLighting.Ambient; Lighting.OutdoorAmbient = defaultLighting.OutdoorAmbient; Lighting.ClockTime = defaultLighting.ClockTime
        end
    end)

    btnAntiLag.MouseButton1Click:Connect(function()
        playClickSound()
        antiLagActive = not antiLagActive
        btnAntiLag.Text = "MODO ANTI-LAG: " .. (antiLagActive and "ON 🟢" or "OFF 🔴")
        btnAntiLag.BackgroundColor3 = antiLagActive and Color3.fromRGB(40, 160, 40) or Color3.fromRGB(180, 30, 30)
        if antiLagActive then
            for _, v in pairs(workspace:GetDescendants()) do
                if v:IsA("BasePart") then v.Material = Enum.Material.SmoothPlastic
                elseif v:IsA("Decal") or v:IsA("Texture") then v:Destroy() end
            end
            Lighting.GlobalShadows = false
        else
            Lighting.GlobalShadows = defaultLighting.GlobalShadows
        end
    end)

    local terrorConn = nil
    local terrorChildConn = nil
    local originalGuiStates = {}
    local originalBillboardStates = {}
    local originalSoundVolumes = {}
    local terrorAudio = nil
    local terrorAudioList = {"rbxassetid://130233633203928", "rbxassetid://134959834418523"}

    local function EsconderBillboardObjeto(obj)
        if obj:IsA("BillboardGui") or obj:IsA("SurfaceGui") then
            local isNextBoss = obj.Name:lower():find("boss") or (obj:FindFirstChildOfClass("TextLabel") and obj:FindFirstChildOfClass("TextLabel").Text:lower():find("boss"))
            if not isNextBoss then
                if originalBillboardStates[obj] == nil then
                    originalBillboardStates[obj] = obj.Enabled
                end
                obj.Enabled = false
            end
        end
    end

    local function OcultarGuisTerror()
        originalGuiStates = {}
        originalBillboardStates = {}
        originalSoundVolumes = {}

        for _, gui in ipairs(player.PlayerGui:GetChildren()) do
            if gui:IsA("ScreenGui") and gui.Name ~= uiName and gui.Name ~= "ArasakaDropdown_Gui" and gui.Name ~= "ArasakaConfigRebirth_Gui" and gui.Name ~= "ArasakaBlackScreen_Gui" and gui.Name ~= "ArasakaKeyTimer_Gui" then
                originalGuiStates[gui] = gui.Enabled
                gui.Enabled = false
            end
        end

        for _, obj in ipairs(workspace:GetDescendants()) do
            EsconderBillboardObjeto(obj)
        end

        for _, snd in ipairs(game:GetDescendants()) do
            if snd:IsA("Sound") and snd ~= terrorAudio and snd ~= clickSound then
                originalSoundVolumes[snd] = snd.Volume
                snd.Volume = 0
            end
        end
    end

    local function RestaurarGuisTerror()
        for gui, wasEnabled in pairs(originalGuiStates) do
            if gui and gui.Parent then
                gui.Enabled = wasEnabled
            end
        end
        originalGuiStates = {}

        for obj, wasEnabled in pairs(originalBillboardStates) do
            if obj and obj.Parent then
                obj.Enabled = wasEnabled
            end
        end
        originalBillboardStates = {}

        for snd, vol in pairs(originalSoundVolumes) do
            if snd and snd.Parent then
                snd.Volume = vol
            end
        end
        originalSoundVolumes = {}
    end

    btnTerror.MouseButton1Click:Connect(function()
        playClickSound()
        terrorActive = not terrorActive
        btnTerror.Text = "MODO TERROR: " .. (terrorActive and "ON 🟢" or "OFF 🔴")
        btnTerror.BackgroundColor3 = terrorActive and Color3.fromRGB(40, 160, 40) or Color3.fromRGB(180, 30, 30)
        if terrorActive then
            OcultarGuisTerror()
            
            if terrorConn then terrorConn:Disconnect() end
            if terrorChildConn then terrorChildConn:Disconnect() end

            terrorConn = RunService.RenderStepped:Connect(function()
                if not terrorActive then return end
                Lighting.Ambient = Color3.fromRGB(100, 0, 0)
                Lighting.OutdoorAmbient = Color3.fromRGB(80, 0, 0)
                Lighting.FogColor = Color3.fromRGB(15, 0, 0)
                Lighting.FogEnd = 120
                Lighting.ClockTime = 0
            end)

            terrorChildConn = workspace.DescendantAdded:Connect(function(descendant)
                if terrorActive then
                    EsconderBillboardObjeto(descendant)
                end
            end)

            task.spawn(function()
                task.wait(5)
                if terrorActive and Core:IsAlive() then
                    if terrorAudio then terrorAudio:Destroy() end
                    terrorAudio = Instance.new("Sound", SoundService)
                    terrorAudio.SoundId = terrorAudioList[math.random(1, #terrorAudioList)]
                    terrorAudio.Volume = 1
                    terrorAudio.Looped = true
                    terrorAudio:Play()
                end
            end)
        else
            RestaurarGuisTerror()
            if terrorConn then terrorConn:Disconnect(); terrorConn = nil end
            if terrorChildConn then terrorChildConn:Disconnect(); terrorChildConn = nil end
            
            if terrorAudio then
                terrorAudio:Stop()
                terrorAudio:Destroy()
                terrorAudio = nil
            end
            
            Lighting.Ambient = defaultLighting.Ambient
            Lighting.OutdoorAmbient = defaultLighting.OutdoorAmbient
            Lighting.FogColor = defaultLighting.FogColor
            Lighting.FogEnd = defaultLighting.FogEnd
            Lighting.ClockTime = defaultLighting.ClockTime
        end
    end)

    local fotoEffects = {}
    local blurConn = nil
    local originalMaterials = {}

    local function VarreduraLeveMateriais()
        local allDescendants = workspace:GetDescendants()
        local batchSize = 100
        local count = 0

        for i = 1, #allDescendants do
            if not fotorealistaActive or not Core:IsAlive() then break end
            local part = allDescendants[i]
            if part:IsA("BasePart") and part.Size.Magnitude > 4 then
                if not part:IsDescendantOf(player.Character) and not part.Parent:FindFirstChildOfClass("Humanoid") then
                    if not originalMaterials[part] then
                        originalMaterials[part] = {Mat = part.Material, Ref = part.Reflectance}
                        if part.Material == Enum.Material.Concrete or part.Material == Enum.Material.Pavement then
                            part.Material = Enum.Material.Slate
                        elseif part.Material == Enum.Material.Grass then
                            part.Material = Enum.Material.Grass
                        elseif part.Material == Enum.Material.SmoothPlastic or part.Material == Enum.Material.Plastic then
                            part.Material = Enum.Material.SmoothPlastic
                        end
                        part.Reflectance = math.clamp(part.Reflectance + 0.05, 0, 0.3)
                    end
                end
            end

            count += 1
            if count >= batchSize then
                count = 0
                task.wait(0.01)
            end
        end
    end

    btnFotorealista.MouseButton1Click:Connect(function()
        playClickSound()
        fotorealistaActive = not fotorealistaActive
        btnFotorealista.Text = "MODO FOTORREALISTA ULTRA: " .. (fotorealistaActive and "ON 🟢" or "OFF 🔴")
        btnFotorealista.BackgroundColor3 = fotorealistaActive and Color3.fromRGB(40, 160, 40) or Color3.fromRGB(180, 30, 30)
        if fotorealistaActive then
            Lighting.Technology = Enum.Technology.Future
            Lighting.GlobalShadows = true
            Lighting.ShadowSoftness = 0.1
            Lighting.Brightness = 2.2
            Lighting.ColorShift_Top = Color3.fromRGB(255, 245, 225)
            Lighting.ColorShift_Bottom = Color3.fromRGB(180, 200, 220)
            Lighting.OutdoorAmbient = Color3.fromRGB(110, 120, 130)
            Lighting.Ambient = Color3.fromRGB(90, 95, 100)
            Lighting.ClockTime = 14.5
            Lighting.GeographicLatitude = 35

            local cc = Instance.new("ColorCorrectionEffect", Lighting)
            cc.Name = "Arasaka_CC"
            cc.Brightness = 0.03
            cc.Contrast = 0.18
            cc.Saturation = 0.15
            cc.TintColor = Color3.fromRGB(255, 252, 245)
            table.insert(fotoEffects, cc)

            local bloom = Instance.new("BloomEffect", Lighting)
            bloom.Name = "Arasaka_Bloom"
            bloom.Intensity = 0.35
            bloom.Size = 18
            bloom.Threshold = 0.85
            table.insert(fotoEffects, bloom)

            local sunRays = Instance.new("SunRaysEffect", Lighting)
            sunRays.Name = "Arasaka_SunRays"
            sunRays.Intensity = 0.12
            sunRays.Spread = 0.8
            table.insert(fotoEffects, sunRays)

            local dof = Instance.new("DepthOfFieldEffect", Lighting)
            dof.Name = "Arasaka_DoF"
            dof.FarIntensity = 0.15
            dof.FocusDistance = 25
            dof.InFocusRadius = 30
            dof.NearIntensity = 0
            table.insert(fotoEffects, dof)

            local blur = Instance.new("BlurEffect", Lighting)
            blur.Name = "Arasaka_MotionBlur"
            blur.Size = 0
            table.insert(fotoEffects, blur)

            blurConn = RunService.RenderStepped:Connect(function()
                if not fotorealistaActive then return end
                local char = player.Character
                local hrp = char and char:FindFirstChild("HumanoidRootPart")
                if hrp then
                    local speed = hrp.AssemblyLinearVelocity.Magnitude
                    blur.Size = math.clamp((speed - 15) * 0.15, 0, 6)
                end
            end)

            task.spawn(function()
                while fotorealistaActive and Core:IsAlive() do
                    VarreduraLeveMateriais()
                    task.wait(60)
                end
            end)
        else
            if blurConn then blurConn:Disconnect(); blurConn = nil end

            for _, eff in ipairs(fotoEffects) do
                if eff and eff.Parent then eff:Destroy() end
            end
            fotoEffects = {}

            for part, original in pairs(originalMaterials) do
                if part and part.Parent then
                    part.Material = original.Mat
                    part.Reflectance = original.Ref
                end
            end
            originalMaterials = {}

            Lighting.GlobalShadows = defaultLighting.GlobalShadows
            Lighting.ShadowSoftness = defaultLighting.ShadowSoftness
            Lighting.Brightness = defaultLighting.Brightness
            Lighting.OutdoorAmbient = defaultLighting.OutdoorAmbient
            Lighting.Ambient = defaultLighting.Ambient
            Lighting.ClockTime = defaultLighting.ClockTime
            Lighting.GeographicLatitude = defaultLighting.GeographicLatitude
        end
    end)

    local blackScreenGui = nil
    btnBlackScreen.MouseButton1Click:Connect(function()
        playClickSound()
        blackScreenActive = not blackScreenActive
        btnBlackScreen.Text = "MODO TELA PRETA: " .. (blackScreenActive and "ON 🟢" or "OFF 🔴")
        btnBlackScreen.BackgroundColor3 = blackScreenActive and Color3.fromRGB(40, 160, 40) or Color3.fromRGB(180, 30, 30)
        if blackScreenActive then
            if not blackScreenGui then
                blackScreenGui = Instance.new("ScreenGui", targetGui)
                blackScreenGui.Name = "ArasakaBlackScreen_Gui"
                blackScreenGui.IgnoreGuiInset = true
                blackScreenGui.DisplayOrder = 100

                local bg = Instance.new("Frame", blackScreenGui)
                bg.Size = UDim2.new(1, 0, 1, 0)
                bg.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
                bg.BorderSizePixel = 0

                local label = Instance.new("TextLabel", bg)
                label.Size = UDim2.new(1, 0, 0, 40)
                label.Position = UDim2.new(0, 0, 0.02, 0)
                label.BackgroundTransparency = 1
                label.Text = "ARASAKA HUB - MODO TELA PRETA ATIVO 🖤"
                label.TextColor3 = Color3.fromRGB(215, 50, 50)
                label.Font = Enum.Font.GothamBold
                label.TextSize = 14
            end
            blackScreenGui.Enabled = true
        else
            if blackScreenGui then
                blackScreenGui.Enabled = false
            end
        end
    end)

        Utils.PerfEnd("VISUAL_UI")
    end
    Core:RegisterModule("Visual", Visual)
    local visualOk, visualErr = Core:StartModule("Visual")
    if not visualOk then warn("[ARASAKA][MODULE:Visual] Falha:", visualErr) end

    -- MODULE // SYSTEM / OUTROS
    function System:Init()
        Utils.PerfBegin("OUTROS_UI")
    -- ABA OUTROS
    local outrosScroll = Instance.new("ScrollingFrame", tabOutros)
    outrosScroll.Size = UDim2.new(1, -20, 1, -10)
    outrosScroll.Position = UDim2.new(0, 10, 0, 5)
    outrosScroll.BackgroundTransparency = 1
    outrosScroll.ScrollBarThickness = 4

    local outrosLayout = Instance.new("UIListLayout", outrosScroll)
    outrosLayout.Padding = UDim.new(0, 6)
    outrosLayout.SortOrder = Enum.SortOrder.LayoutOrder

    outrosLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        outrosScroll.CanvasSize = UDim2.new(0, 0, 0, outrosLayout.AbsoluteContentSize.Y + 20)
    end)

    local function CriarBotaoOutros(texto, order)
        local btn = Instance.new("TextButton", outrosScroll)
        btn.LayoutOrder = order
        btn.Size = UDim2.new(1, -6, 0, 32)
        btn.BackgroundColor3 = Color3.fromRGB(180, 30, 30)
        btn.Text = texto .. ": OFF 🔴"
        btn.TextColor3 = Color3.fromRGB(255, 255, 255)
        btn.Font = Enum.Font.GothamBold
        btn.TextSize = 11
        Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)
        return btn
    end

    local autoSpinWheelActive, eatAllBoostsActive = false, false

    local btnSpinWheel = CriarBotaoOutros("GIRAR ROLETA 🎰", 1)
    local btnEatAllBoosts = CriarBotaoOutros("USAR TODOS OS BOOSTS 💊", 2)
    local btnServerHop = CriarBotaoOutros("SERVIDOR COM MENOS PESSOAS 🌐", 3)
    local btnRejoin = CriarBotaoOutros("REJOIN 🔄", 4)
    local btnMelhorPing = CriarBotaoOutros("PROCURAR MELHOR PING 📡", 5)

    btnServerHop.Text = "SERVIDOR COM MENOS PESSOAS 🌐"
    btnRejoin.Text = "REJOIN 🔄"
    btnMelhorPing.Text = "PROCURAR MELHOR PING 📡"

    local serverHopBusy = false
    local function IrServidorMenosCheio()
        if serverHopBusy then return end
        serverHopBusy = true

        local textoOriginal = btnServerHop.Text
        btnServerHop.Text = "PROCURANDO SERVIDOR..."
        btnServerHop.BackgroundColor3 = Color3.fromRGB(125, 25, 25)

        task.spawn(function()
            local melhorServidor = nil
            local menorQuantidade = math.huge
            local cursor = nil

            for _ = 1, 5 do
                local url = "https://games.roblox.com/v1/games/" .. tostring(game.PlaceId)
                    .. "/servers/Public?sortOrder=Asc&limit=100"

                if cursor and cursor ~= "" then
                    url = url .. "&cursor=" .. HttpService:UrlEncode(cursor)
                end

                local ok, resposta = pcall(function()
                    return HttpService:JSONDecode(game:HttpGet(url))
                end)

                if not ok or type(resposta) ~= "table" then
                    break
                end

                for _, servidor in ipairs(resposta.data or {}) do
                    local playing = tonumber(servidor.playing) or math.huge
                    local maxPlayers = tonumber(servidor.maxPlayers) or 0

                    if servidor.id
                        and servidor.id ~= game.JobId
                        and playing < maxPlayers
                        and playing < menorQuantidade then

                        melhorServidor = servidor.id
                        menorQuantidade = playing
                    end
                end

                cursor = resposta.nextPageCursor
                if not cursor or cursor == "" or menorQuantidade == 0 then
                    break
                end
            end

            if melhorServidor then
                btnServerHop.Text = "ENTRANDO // " .. tostring(menorQuantidade) .. " PLAYER(S)"
                task.wait(0.25)
                local ok = pcall(function()
                    TeleportService:TeleportToPlaceInstance(game.PlaceId, melhorServidor, player)
                end)

                if not ok then
                    btnServerHop.Text = "FALHA AO TROCAR SERVIDOR"
                    task.wait(1.5)
                end
            else
                btnServerHop.Text = "NENHUM SERVIDOR ENCONTRADO"
                task.wait(1.5)
            end

            if btnServerHop and btnServerHop.Parent then
                btnServerHop.Text = textoOriginal
                btnServerHop.BackgroundColor3 = Color3.fromRGB(180, 30, 30)
            end
            serverHopBusy = false
        end)
    end

    btnServerHop.MouseButton1Click:Connect(function()
        playClickSound()
        IrServidorMenosCheio()
    end)

    local melhorPingBusy = false

    local function ProcurarServidorMelhorPing()
        if melhorPingBusy then
            return
        end

        melhorPingBusy = true
        btnMelhorPing.Text = "PROCURANDO MELHOR CONEXAO..."
        btnMelhorPing.BackgroundColor3 = Color3.fromRGB(125, 25, 25)

        task.wait(0.25)

        local sucesso, erroTeleport = pcall(function()
            TeleportService:Teleport(game.PlaceId, player)
        end)

        if not sucesso then
            warn("[ARASAKA] Falha no matchmaking:", erroTeleport)
            btnMelhorPing.Text = "FALHA // TENTE NOVAMENTE"
            btnMelhorPing.BackgroundColor3 = Color3.fromRGB(180, 30, 30)
            melhorPingBusy = false
        end
    end

    btnMelhorPing.MouseButton1Click:Connect(function()
        playClickSound()
        ProcurarServidorMelhorPing()
    end)

    btnRejoin.MouseButton1Click:Connect(function()
        playClickSound()
        if btnRejoin.Text == "REENTRANDO..." then return end

        btnRejoin.Text = "REENTRANDO..."
        btnRejoin.BackgroundColor3 = Color3.fromRGB(125, 25, 25)

        task.delay(0.15, function()
            local ok = pcall(function()
                TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, player)
            end)

            if not ok and btnRejoin and btnRejoin.Parent then
                btnRejoin.Text = "FALHA NO REJOIN"
                task.wait(1.5)
                if btnRejoin and btnRejoin.Parent then
                    btnRejoin.Text = "REJOIN 🔄"
                    btnRejoin.BackgroundColor3 = Color3.fromRGB(180, 30, 30)
                end
            end
        end)
    end)

    task.spawn(function()
        while Core:IsAlive() do
            if autoSpinWheelActive then
                local rEvents = ReplicatedStorage:FindFirstChild("rEvents")
                local rspin = rEvents and rEvents:FindFirstChild("openFortuneWheelRemote")
                local chances = ReplicatedStorage:FindFirstChild("shared") and ReplicatedStorage.shared:FindFirstChild("catalogs") and ReplicatedStorage.shared.catalogs:FindFirstChild("fortuneWheelChances") and ReplicatedStorage.shared.catalogs.fortuneWheelChances:FindFirstChild("Fortune Wheel")
                if rspin and chances then
                    pcall(function() rspin:InvokeServer("openFortuneWheel", chances) end)
                end
                
                for i = 1, 10 do
                    if not autoSpinWheelActive or not Core:IsAlive() then break end
                    task.wait(0.1)
                end
            else
                task.wait(0.1)
            end
        end
    end)

    btnSpinWheel.MouseButton1Click:Connect(function()
        playClickSound()
        autoSpinWheelActive = not autoSpinWheelActive
        btnSpinWheel.Text = "GIRAR ROLETA: " .. (autoSpinWheelActive and "ON 🟢" or "OFF 🔴")
        btnSpinWheel.BackgroundColor3 = autoSpinWheelActive and Color3.fromRGB(40, 160, 40) or Color3.fromRGB(180, 30, 30)
    end)

    local boostItemList = { "Tropical Shake", "Energy Shake", "Protein Bar", "TOUGH Bar", "Protein Shake", "ULTRA Shake", "Energy Bar" }
    local boostActions = { ["Tropical Shake"] = "tropicalShake", ["Energy Shake"] = "energyShake", ["Protein Bar"] = "proteinBar", ["TOUGH Bar"] = "toughBar", ["Protein Shake"] = "proteinShake", ["ULTRA Shake"] = "ultraShake", ["Energy Bar"] = "energyBar" }

    task.spawn(function()
        while Core:IsAlive() do
            if eatAllBoostsActive then
                local char = player.Character
                local backpack = player:FindFirstChild("Backpack")
                local event = getMuscleEvent()

                for _, boostName in ipairs(boostItemList) do
                    if not eatAllBoostsActive or not Core:IsAlive() then break end
                    local tool = (char and char:FindFirstChild(boostName)) or (backpack and backpack:FindFirstChild(boostName))
                    if tool and event and boostActions[boostName] then
                        pcall(function() event:FireServer(boostActions[boostName], tool) end)
                    end
                end
                task.wait(0.05)
            else
                task.wait(0.1)
            end
        end
    end)

    btnEatAllBoosts.MouseButton1Click:Connect(function()
        playClickSound()
        eatAllBoostsActive = not eatAllBoostsActive
        btnEatAllBoosts.Text = "USAR TODOS OS BOOSTS: " .. (eatAllBoostsActive and "ON 🟢" or "OFF 🔴")
        btnEatAllBoosts.BackgroundColor3 = eatAllBoostsActive and Color3.fromRGB(40, 160, 40) or Color3.fromRGB(180, 30, 30)
    end)


    --==================================================
    -- NOTIFICAÇÕES UNIVERSAIS // TODAS AS FUNÇÕES DA UI
    -- Observa mudanças ON/OFF sem alterar a lógica das funções.
    --==================================================
    local function limparNomeFuncao(texto)
        texto = tostring(texto or "")
        texto = texto:gsub("%s*:%s*ON%s*🟢", "")
        texto = texto:gsub("%s*:%s*OFF%s*🔴", "")
        texto = texto:gsub("%s*ON%s*🟢", "")
        texto = texto:gsub("%s*OFF%s*🔴", "")
        texto = texto:gsub("^%s+", ""):gsub("%s+$", "")
        return texto ~= "" and texto or "FUNÇÃO"
    end

    local function estadoDoTexto(texto)
        texto = tostring(texto or "")
        if texto:find("ON 🟢", 1, true) then return true end
        if texto:find("OFF 🔴", 1, true) then return false end
        return nil
    end

    local botoesNotificacaoConectados = setmetatable({}, {__mode = "k"})

    local function conectarNotificacaoBotao(botao)
        if not botao:IsA("TextButton") or botoesNotificacaoConectados[botao] then return end
        botoesNotificacaoConectados[botao] = true

        local conexao = botao.MouseButton1Click:Connect(function()
            local textoAntes = botao.Text
            local estadoAntes = estadoDoTexto(textoAntes)

            task.defer(function()
                if not botao or not botao.Parent or not Core then return end

                local textoDepois = botao.Text
                local estadoDepois = estadoDoTexto(textoDepois)

                -- Toggle real: notifica somente quando o estado mudou.
                if estadoDepois ~= nil and estadoDepois ~= estadoAntes then
                    Core:NotificarToggle(limparNomeFuncao(textoDepois), estadoDepois)
                    return
                end

                -- Ações instantâneas importantes que não possuem ON/OFF.
                local upper = string.upper(textoAntes or "")
                local ehAcao =
                    upper:find("TELEPORT", 1, true)
                    or upper:find("REJOIN", 1, true)
                    or upper:find("SERVIDOR", 1, true)
                    or upper:find("MELHOR PING", 1, true)

                if ehAcao then
                    Core:Notify(
                        limparNomeFuncao(textoAntes),
                        "Ação iniciada.",
                        2
                    )
                end
            end)
        end)

        if Core then
            Core:TrackConnection("NotificacoesUniversais", conexao)
        end
    end

    local function iniciarNotificacoesUniversais()
        for _, objeto in ipairs(screenGui:GetDescendants()) do
            conectarNotificacaoBotao(objeto)
        end

        local conexaoNovoBotao = screenGui.DescendantAdded:Connect(function(objeto)
            if objeto:IsA("TextButton") then
                task.defer(function()
                    conectarNotificacaoBotao(objeto)
                end)
            end
        end)

        if Core then
            Core:TrackConnection("NotificacoesUniversais", conexaoNovoBotao)
        end

        print("[ARASAKA][NOTIFICAÇÕES] Todas as funções ON/OFF = MONITORADAS")
    end

    iniciarNotificacoesUniversais()

    --==================================================
    -- MODULE // DASHBOARD // COMPLETE UPGRADE
    -- Observabilidade local: uptime, FPS, jogadores, workers e conexões.
    --==================================================
    local DashboardModule = {
        Name = "Dashboard",
        Connections = {},
        Initialized = false
    }

    function DashboardModule:Init()
        if self.Initialized then return end
        self.Initialized = true

        local card = Instance.new("Frame")
        card.Name = "ArasakaDashboard"
        card.Parent = tabInicio
        card.BackgroundColor3 = Color3.fromRGB(7, 7, 7)
        card.BorderSizePixel = 0
        card.Position = UDim2.new(0, 14, 0, 310)
        card.Size = UDim2.new(1, -28, 0, 128)

        local stroke = Instance.new("UIStroke")
        stroke.Parent = card
        stroke.Color = Color3.fromRGB(70, 18, 18)
        stroke.Thickness = 1

        local title = Instance.new("TextLabel")
        title.Parent = card
        title.BackgroundTransparency = 1
        title.Position = UDim2.new(0, 14, 0, 5)
        title.Size = UDim2.new(1, -28, 0, 20)
        title.Font = Enum.Font.GothamBold
        title.TextSize = 13
        title.TextXAlignment = Enum.TextXAlignment.Left
        title.TextColor3 = Color3.fromRGB(235, 235, 235)
        title.Text = "ARASAKA // PAINEL DO SISTEMA"

        local info = Instance.new("TextLabel")
        info.Parent = card
        info.BackgroundTransparency = 1
        info.Position = UDim2.new(0, 16, 0, 34)
        info.Size = UDim2.new(1, -32, 0, 86)
        info.Font = Enum.Font.Code
        info.TextSize = 11
        info.TextXAlignment = Enum.TextXAlignment.Left
        info.TextYAlignment = Enum.TextYAlignment.Top
        info.TextColor3 = Color3.fromRGB(155, 155, 155)
        info.TextWrapped = true

        local fpsFrames, fpsElapsed, fpsValue = 0, 0, 0

        local function formatUptime(seconds)
            seconds = math.max(0, math.floor(seconds))
            local h = math.floor(seconds / 3600)
            local m = math.floor((seconds % 3600) / 60)
            local s = seconds % 60
            return string.format("%02d:%02d:%02d", h, m, s)
        end

        local function refresh()
            if not Core then return end
            local workers = Core:GetRunningWorkerNames()
            local nomesProcessos = {}
            for _, nome in ipairs(workers) do
                local traduzido = ({
                    CoreMemory = "Memória do Sistema",
                    HubLifecycle = "Ciclo do Hub",
                    LifecycleTest = "Teste de Ciclo"
                })[nome] or nome
                table.insert(nomesProcessos, traduzido)
            end
            local workerText = #nomesProcessos > 0 and table.concat(nomesProcessos, ", ") or "NENHUM"
            local playersNow = #Players:GetPlayers()
            local maxPlayers = Players.MaxPlayers
            info.Text = string.format(
                "VERSAO       // %s\nTEMPO ATIVO  // %s\nFPS          // %d\nJOGADORES    // %d / %d\nPROCESSOS    // %d [%s]\nCONEXOES     // %d\nCHAT         // %s",
                tostring(Core.Version),
                formatUptime(os.clock() - Core.StartedAt),
                fpsValue,
                playersNow,
                maxPlayers,
                #workers,
                workerText,
                Core:GetConnectionCount(),
                (Core.Modules.Chat and Core.States.Chat) and "CARREGADO" or "EM ESPERA"
            )
        end

        local conn = RunService.RenderStepped:Connect(function(dt)
            fpsFrames += 1
            fpsElapsed += dt
            if fpsElapsed >= 0.5 then
                fpsValue = math.floor((fpsFrames / fpsElapsed) + 0.5)
                fpsFrames = 0
                fpsElapsed = 0
                refresh()
            end
        end)

        if Core then
            Core:TrackConnection("Dashboard", conn)
        else
            table.insert(self.Connections, conn)
        end

        refresh()
        print("[ARASAKA][MODULE] Dashboard = MIGRADO")
    end

    function DashboardModule:Stop()
        if Core then
            Core:CleanupOwner("Dashboard")
        end
        for _, connection in ipairs(self.Connections) do
            pcall(function() connection:Disconnect() end)
        end
        table.clear(self.Connections)
    end

    if Core then
        Core:RegisterModule("Dashboard", DashboardModule)
        local okDash, errDash = Core:StartModule("Dashboard")
        if not okDash then
            warn("[ARASAKA][MODULE:Dashboard] Falha:", errDash)
        end
    else
        DashboardModule:Init()
    end

    --==================================================
    --==================================================
    -- MODULE // PROCESS PANEL // FASE 7
    -- Painel visual para workers gerenciados pelo Core.
    --==================================================
    local ProcessPanelModule = {
        Name = "ProcessPanel",
        Connections = {}
    }

    function ProcessPanelModule:Init()
        if self.Initialized then return end
        self.Initialized = true

        local title = Instance.new("TextLabel")
        title.Name = "ProcessManagerTitle"
        title.Parent = tabOutros
        title.BackgroundTransparency = 1
        title.Size = UDim2.new(1, -24, 0, 24)
        title.Position = UDim2.new(0, 12, 0, 238)
        title.Font = Enum.Font.GothamBold
        title.TextSize = 14
        title.TextXAlignment = Enum.TextXAlignment.Left
        title.TextColor3 = Color3.fromRGB(210, 210, 210)
        title.Text = "SISTEMA // GERENCIADOR DE PROCESSOS"

        local status = Instance.new("TextLabel")
        status.Name = "ProcessManagerStatus"
        status.Parent = tabOutros
        status.BackgroundTransparency = 1
        status.Size = UDim2.new(1, -24, 0, 34)
        status.Position = UDim2.new(0, 12, 0, 262)
        status.Font = Enum.Font.Code
        status.TextSize = 11
        status.TextWrapped = true
        status.TextXAlignment = Enum.TextXAlignment.Left
        status.TextYAlignment = Enum.TextYAlignment.Top
        status.TextColor3 = Color3.fromRGB(145, 145, 145)
        status.Text = "PROCESSOS // NENHUM ATIVO"

        local stopButton = Instance.new("TextButton")
        stopButton.Name = "MasterStopButton"
        stopButton.Parent = tabOutros
        stopButton.Size = UDim2.new(1, -24, 0, 34)
        stopButton.Position = UDim2.new(0, 12, 0, 298)
        stopButton.BackgroundColor3 = Color3.fromRGB(45, 8, 8)
        stopButton.BorderSizePixel = 0
        stopButton.Font = Enum.Font.GothamBold
        stopButton.TextSize = 13
        stopButton.TextColor3 = Color3.fromRGB(255, 90, 90)
        stopButton.Text = "PARAR TODOS OS PROCESSOS"

        local stroke = Instance.new("UIStroke")
        stroke.Parent = stopButton
        stroke.Color = Color3.fromRGB(120, 25, 25)
        stroke.Thickness = 1

        local notifyButton = Instance.new("TextButton")
        notifyButton.Name = "NotificationToggle"
        notifyButton.Parent = tabOutros
        notifyButton.Size = UDim2.new(1, -24, 0, 32)
        notifyButton.Position = UDim2.new(0, 12, 0, 338)
        notifyButton.BackgroundColor3 = Color3.fromRGB(12, 12, 12)
        notifyButton.BorderSizePixel = 0
        notifyButton.Font = Enum.Font.GothamBold
        notifyButton.TextSize = 13
        notifyButton.TextColor3 = Color3.fromRGB(185, 185, 185)

        local function refreshNotifyButton()
            local enabled = Core and Core:GetConfig("notifications", true)
            notifyButton.Text = "NOTIFICAÇÕES ARASAKA // " .. (enabled and "ON" or "OFF")
        end

        local notifyConnection = notifyButton.MouseButton1Click:Connect(function()
            if not Core then return end
            local nextValue = not Core:GetConfig("notifications", true)
            Core:SetConfig("notifications", nextValue)
            refreshNotifyButton()
        end)

        if Core then
            Core:TrackConnection("ProcessPanel", notifyConnection)
        end
        refreshNotifyButton()

        local compactButton = Instance.new("TextButton")
        compactButton.Name = "CompactStatusToggle"
        compactButton.Parent = tabOutros
        compactButton.Size = UDim2.new(1, -24, 0, 32)
        compactButton.Position = UDim2.new(0, 12, 0, 376)
        compactButton.BackgroundColor3 = Color3.fromRGB(12, 12, 12)
        compactButton.BorderSizePixel = 0
        compactButton.Font = Enum.Font.GothamBold
        compactButton.TextSize = 12
        compactButton.TextColor3 = Color3.fromRGB(185, 185, 185)

        local function atualizarBotaoCompacto()
            local ativo = Core and Core:GetConfig("compactStatus", false)
            compactButton.Text = "STATUS COMPACTO // " .. (ativo and "ON" or "OFF")
        end

        local compactConnection = compactButton.MouseButton1Click:Connect(function()
            if not Core then return end
            local novoValor = not Core:GetConfig("compactStatus", false)
            Core:SetConfig("compactStatus", novoValor)
            atualizarBotaoCompacto()
        end)

        if Core then
            Core:TrackConnection("ProcessPanel", compactConnection)
        end
        atualizarBotaoCompacto()

        local function refresh()
            if not ProcessControlModule then
                status.Text = "PROCESSOS // CONTROLE OFFLINE"
                return
            end

            local snapshot = ProcessControlModule:GetSnapshot()
            local running = {}
            for name, info in pairs(snapshot) do
                if info.running then
                    table.insert(running, name)
                end
            end
            table.sort(running)

            local connectionCount = 0
            if Core then
                for _, connections in pairs(Core.Connections) do
                    connectionCount += #connections
                end
            end

            local compacto = Core and Core:GetConfig("compactStatus", false)

            if compacto then
                status.Text = "PROCESSOS // " .. tostring(#running)
                    .. "   |   CONEXÕES // " .. tostring(connectionCount)
            elseif #running == 0 then
                status.Text = "PROCESSOS // 0   |   CONEXÕES // " .. tostring(connectionCount)
            else
                status.Text = "ATIVOS // " .. table.concat(running, " | ")
                    .. "   // CONEXÕES " .. tostring(connectionCount)
            end
        end

        local masterStopConnection = stopButton.MouseButton1Click:Connect(function()
            if playClickSound then
                pcall(playClickSound)
            end
            if ProcessControlModule then
                ProcessControlModule:StopAllManagedWorkers()
            end
            refresh()
        end)

        if Core then
            Core:TrackConnection("ProcessPanel", masterStopConnection)
        else
            table.insert(self.Connections, masterStopConnection)
        end

        -- Atualiza ~2x por segundo, sem interferir no gameplay.
        local elapsed = 0
        local refreshConnection = RunService.Heartbeat:Connect(function(dt)
            elapsed += dt
            if elapsed >= 0.5 then
                elapsed = 0
                refresh()
            end
        end)

        if Core then
            Core:TrackConnection("ProcessPanel", refreshConnection)
        else
            table.insert(self.Connections, refreshConnection)
        end

        refresh()
        print("[ARASAKA][MODULE] ProcessPanel = MIGRADO")
    end

    function ProcessPanelModule:Stop()
        if Core then
            Core:CleanupOwner("ProcessPanel")
        end

        for _, connection in ipairs(self.Connections) do
            pcall(function()
                connection:Disconnect()
            end)
        end
        table.clear(self.Connections)
    end

    if Core then
        Core:RegisterModule("ProcessPanel", ProcessPanelModule)
        local okPanel, errPanel = Core:StartModule("ProcessPanel")
        if not okPanel then
            warn("[ARASAKA][MODULE:ProcessPanel] Falha:", errPanel)
        end
    else
        ProcessPanelModule:Init()
    end

    --==================================================
        Utils.PerfEnd("OUTROS_UI")
    end
    Core:RegisterModule("System", System)
    local systemOk, systemErr = Core:StartModule("System")
    if not systemOk then warn("[ARASAKA][MODULE:System] Falha:", systemErr) end

    --==================================================
        -- MODULE // SYSTEM UI
    -- Primeira migração real para a arquitetura modular.
    --==================================================
    local SystemUIModule = { Name = "SystemUI" }

    function SystemUIModule:Init()
        local minimizado = false
        local TAMANHO_NORMAL = UDim2.new(0, 820, 0, 520)
        local TAMANHO_MINIMIZADO = UDim2.new(0, 420, 0, 52)
        local ALTURA_BARRA_NORMAL = 52
        local ALTURA_BARRA_MIN = 49
        local minimizeTween = nil
        local minimizeGeneration = 0

        local function AplicarEstadoMinimizado(isMin)
            if isMin then
                sidebar.Visible = false
                contentArea.Visible = false
                separator.Visible = false
                techLeft.Visible = false
                techRight.Visible = false
                subtitleText.Visible = false
                userText.Visible = false
                contentGlow.Visible = false
                contentCode.Visible = false

                titleBar.Size = UDim2.new(1, 0, 0, ALTURA_BARRA_MIN)
                titleBar.Position = UDim2.new(0, 0, 0, 3)
                decalImage.Size = UDim2.new(0, 26, 0, 26)
                decalImage.Position = UDim2.new(0, 16, 0.5, -13)
                titleText.Position = UDim2.new(0, 51, 0, 5)
                titleText.Size = UDim2.new(0, 180, 0, 24)
                titleText.TextSize = 17
                onlineText.Size = UDim2.new(0, 130, 0, 7)
                onlineText.Position = UDim2.new(1, -175, 0, 7)
                onlineText.TextSize = 12
                btnMinimizar.Size = UDim2.new(0, 28, 0, 28)
                btnMinimizar.Position = UDim2.new(1, -36, 0.5, -14)
            else
                titleBar.Size = UDim2.new(1, 0, 0, ALTURA_BARRA_NORMAL)
                titleBar.Position = UDim2.new(0, 0, 0, 3)
                decalImage.Size = UDim2.new(0, 30, 0, 30)
                decalImage.Position = UDim2.new(0, 17, 0.5, -15)
                titleText.Position = UDim2.new(0, 57, 0, 8)
                titleText.Size = UDim2.new(0, 300, 0, 23)
                titleText.TextSize = 18
                onlineText.Size = UDim2.new(0, 150, 0, 20)
                onlineText.Position = UDim2.new(1, -205, 0, 9)
                onlineText.TextSize = 12
                btnMinimizar.Size = UDim2.new(0, 30, 0, 30)
                btnMinimizar.Position = UDim2.new(1, -38, 0.5, -15)

                sidebar.Visible = true
                contentArea.Visible = true
                separator.Visible = true
                techLeft.Visible = true
                techRight.Visible = true
                subtitleText.Visible = true
                userText.Visible = true
                contentGlow.Visible = true
                contentCode.Visible = true
            end
        end

        btnMinimizar.MouseButton1Click:Connect(function()
            playClickSound()
            minimizado = not minimizado
            minimizeGeneration = minimizeGeneration + 1
            local thisGen = minimizeGeneration

            if minimizeTween then
                pcall(function() minimizeTween:Cancel() end)
                minimizeTween = nil
            end

            if minimizado then
                AplicarEstadoMinimizado(true)
            end

            local novoTamanho = minimizado and TAMANHO_MINIMIZADO or TAMANHO_NORMAL
            minimizeTween = TweenService:Create(
                frame,
                TweenInfo.new(0.3, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
                {Size = novoTamanho}
            )
            minimizeTween:Play()

            if not minimizado then
                minimizeTween.Completed:Once(function()
                    if thisGen == minimizeGeneration and not minimizado then
                        AplicarEstadoMinimizado(false)
                    end
                end)
            end

            btnMinimizar.Text = minimizado and "+" or "—"
        end)
    end

    if Core then
        Core:RegisterModule("SystemUI", SystemUIModule)
        local okSystem, errSystem = Core:StartModule("SystemUI")
        if not okSystem then
            warn("[ARASAKA][MODULE:SystemUI] Falha:", errSystem)
        end
    else
        SystemUIModule:Init()
    end

end

function UI:Stop()
    Core:StopWorker("UI.DashboardStats")
    Core:CleanupOwner("ChatLoader")
    Core:CleanupOwner("UI")
    if self.ScreenGui then
        pcall(function() self.ScreenGui:Destroy() end)
        self.ScreenGui = nil
    end
end

--==================================================
-- CORE já foi declarado no topo para que todos os módulos compartilhem
-- o mesmo gerenciador local sem depender de _G.
--==================================================

--==================================================
-- MODULE // PROCESS CONTROL
-- MASTER STOP para todos os workers que forem migrados
-- para o WorkerManager. Não encerra o Hub/UI.
--==================================================
ProcessControlModule = {
    Name = "ProcessControl"
}

function ProcessControlModule:StopAllManagedWorkers()
    Core:StopAllWorkers()
    print("[ARASAKA][MASTER STOP] Todos os processos gerenciados foram encerrados.")
end

function ProcessControlModule:GetSnapshot()
    return Core:GetWorkerSnapshot()
end

Core:RegisterModule("ProcessControl", ProcessControlModule)
-- ProcessControlModule já é local

--==================================================
-- MODULE // CORE MEMORY // FASE 10
-- Primeira rotina real migrada para o WorkerManager.
-- Mantém exatamente a operação antiga: consulta periódica
-- ao contador de memória do coletor Lua.
--==================================================
local CoreMemoryModule = {
    Name = "CoreMemory"
}

function CoreMemoryModule:Start()
    if Core:IsWorkerRunning("CoreMemory") then
        return true
    end

    return Core:StartWorker("CoreMemory", function(isAlive)
        while isAlive() do
            -- Espera fracionada para que STOP não precise aguardar 30s.
            local elapsed = 0
            while elapsed < 30 and isAlive() do
                task.wait(0.25)
                elapsed += 0.25
            end

            if not isAlive() then
                break
            end

            pcall(function()
                collectgarbage("count")
            end)
        end
    end)
end

function CoreMemoryModule:Stop()
    return Core:StopWorker("CoreMemory")
end

Core:RegisterModule("CoreMemory", CoreMemoryModule)

local coreMemoryOk, coreMemoryErr = Core:StartModule("CoreMemory")
if not coreMemoryOk then
    warn("[ARASAKA][MODULE:CoreMemory] Falha:", coreMemoryErr)
else
    print("[ARASAKA][MODULE] CoreMemory = MIGRADO")
end

--==================================================
-- MODULE // HUB LIFECYCLE WATCHER // FASE 11
-- Stops managed workers if the hub itself is invalidated/re-executed.
-- Does not control gameplay actions; only lifecycle cleanup.
--==================================================
local HubLifecycleModule = {
    Name = "HubLifecycle"
}

function HubLifecycleModule:Start()
    if Core:IsWorkerRunning("HubLifecycle") then
        return true
    end

    return Core:StartWorker("HubLifecycle", function(isAlive)
        while isAlive() do
            task.wait(0.25)

            if not Core:IsAlive() then
                -- Snapshot names first so the manager can safely mutate Workers.
                local names = {}
                for workerName in pairs(Core.Workers) do
                    if workerName ~= "HubLifecycle" then
                        table.insert(names, workerName)
                    end
                end

                for _, workerName in ipairs(names) do
                    Core:StopWorker(workerName)
                end
                break
            end
        end
    end)
end

function HubLifecycleModule:Stop()
    return Core:StopWorker("HubLifecycle")
end

Core:RegisterModule("HubLifecycle", HubLifecycleModule)

local lifecycleOk, lifecycleErr = Core:StartModule("HubLifecycle")
if not lifecycleOk then
    warn("[ARASAKA][MODULE:HubLifecycle] Falha:", lifecycleErr)
else
    print("[ARASAKA][MODULE] HubLifecycle = MIGRADO")
end



-- Worker de diagnóstico local (inativo por padrão).
local WorkerDiagnosticModule = {
    Name = "WorkerDiagnostic"
}

function WorkerDiagnosticModule:Start()
    return Core:StartWorker("DiagnosticHeartbeat", function(isAlive)
        while isAlive() do
            task.wait(0.25)
        end
    end)
end

function WorkerDiagnosticModule:Stop()
    return Core:StopWorker("DiagnosticHeartbeat")
end

Core:RegisterModule("WorkerDiagnostic", WorkerDiagnosticModule)

-- Módulos reais do arquivo único. O Chat é registrado de forma lazy dentro da UI.
Core:RegisterModule("Utils", Utils)
Core:RegisterModule("UI", UI)
Core:RegisterModule("Farms", Farms)
Core:RegisterModule("Teleports", Teleports)
Core:RegisterModule("Pets", Pets)
Core:RegisterModule("Visual", Visual)
Core:RegisterModule("Kill", Kill)
Core:RegisterModule("Calculator", Calculator)
Core:RegisterModule("System", System)

--==================================================

-- INICIAR HUB DIRETAMENTE // SEM SISTEMA DE KEY
local __arasakaBootStart = os.clock()
print("[ARASAKA][BOOT] Iniciando Hub sem sistema de key...")

Core:SetRunning(true)

local uiStart = os.clock()
local uiOk, uiErr = Core:StartModule("UI")
if not uiOk then
    warn("[ARASAKA][MODULE:UI] Falha:", uiErr)
    return
end

local uiElapsed = os.clock() - uiStart
local totalElapsed = os.clock() - __arasakaBootStart

print(string.format("[ARASAKA][BOOT] UI criada em %.3fs", uiElapsed))
print(string.format("[ARASAKA][BOOT] TOTAL %.3fs", totalElapsed))
Core:Notify("ARASAKA", "Sistema carregado e pronto para uso.")
