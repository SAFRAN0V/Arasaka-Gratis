-- ARASAKA GRATIS / MODULO DE FONTE / PARTE 6 DE 6
return [====[    local btnSalvarTeste = CriarBotaoOutros("SAVE CONFIG V7", 6)
    local btnRejoinTeste = CriarBotaoOutros("AUTO REJOIN V7", 7)

    local function arsRefreshButtons()
        btnSalvarTeste.Text = "SAVE CONFIG: " .. (ARS_PREF.saveEnabled and "ON 🟢" or "OFF 🔴")
        btnRejoinTeste.Text = "AUTO REJOIN: " .. (ARS_PREF.autoRejoin and "ON 🟢" or "OFF 🔴")
    end
    arsRefreshButtons()
    Core:TrackConnection("UI", btnSalvarTeste.MouseButton1Click:Connect(function()
        ARS_PREF.saveEnabled = not ARS_PREF.saveEnabled
        if ARS_PREF.saveEnabled then arsSavePrefs() end
        arsRefreshButtons()
    end))
    Core:TrackConnection("UI", btnRejoinTeste.MouseButton1Click:Connect(function()
        ARS_PREF.autoRejoin = not ARS_PREF.autoRejoin
        arsSavePrefs()
        arsRefreshButtons()
    end))
    Core:StartWorker("GratisV7.ConfigAutosave", function(alive)
        while alive() do
            task.wait(20)
            arsSavePrefs()
        end
    end)
    -- Auto Rejoin: apenas quando o Roblox ainda permite executar Lua.
    -- A reconexao apos fechar o app ou perder totalmente a conexao nao e garantida.
    local arsRejoining = false
    local function arsTryRejoin(reason)
        if not ARS_PREF.autoRejoin or arsRejoining or not Core:IsAlive() then return end
        arsRejoining = true
        arsSavePrefs()
        arsQueueAfterTeleport()
        warn("[ARASAKA][REJOIN] Tentando retornar ao jogo: " .. tostring(reason))
        local ok, err = pcall(function() TeleportService:Teleport(game.PlaceId, player) end)
        if not ok then
            warn("[ARASAKA][REJOIN] Falha: " .. tostring(err))
            task.delay(12, function() arsRejoining = false end)
        end
    end
    local okGui, guiSvc = pcall(function() return game:GetService("GuiService") end)
    if okGui and guiSvc then
        pcall(function()
            Core:TrackConnection("UI", guiSvc.ErrorMessageChanged:Connect(function(message)
                local m = tostring(message):lower()
                if m:find("disconnected", 1, true) or m:find("connection", 1, true)
                  or m:find("desconect", 1, true) or m:find("conexão", 1, true) then
                    task.defer(arsTryRejoin, "conexao")
                end
            end))
        end)
    end
    pcall(function()
        Core:TrackConnection("UI", TeleportService.TeleportInitFailed:Connect(function()
            arsRejoining = false
        end))
    end)

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
        if (ArasakaI18n.Sources[btnRejoin] or btnRejoin.Text) == "REENTRANDO..." then return end

        btnRejoin.Text = "REENTRANDO..."
        btnRejoin.BackgroundColor3 = Color3.fromRGB(125, 25, 25)

        arsSavePrefs()
        arsQueueAfterTeleport()
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
        texto = string.upper(tostring(texto or ""))
        if texto:find("%f[%a]ON%f[%A]") then return true end
        if texto:find("%f[%a]OFF%f[%A]") then return false end
        return nil
    end

    local botoesNotificacaoConectados = setmetatable({}, {__mode = "k"})

    local function conectarNotificacaoBotao(botao)
        if not botao:IsA("TextButton") or botoesNotificacaoConectados[botao] then return end
        botoesNotificacaoConectados[botao] = true
        -- Cache independente da ordem dos callbacks de clique.
        local ultimoEstado = estadoDoTexto(botao.Text)
        local textoConn = botao:GetPropertyChangedSignal("Text"):Connect(function()
            if not botao.Parent or not Core:IsAlive() then return end
            local atual = estadoDoTexto(botao.Text)
            if atual == nil then return end
            local anterior = ultimoEstado
            ultimoEstado = atual
            if anterior ~= nil and anterior ~= atual then
                Core:NotificarToggle(limparNomeFuncao(botao.Text), atual)
            end
        end)
        Core:TrackConnection("NotificacoesUniversais", textoConn)

        local cliqueConn = botao.MouseButton1Click:Connect(function()
            if not Core:IsAlive() or not botao.Parent then return end
            -- Abas de navegacao nao executam teleporte.
            if botao:FindFirstChild("ActiveLine") then return end
            if estadoDoTexto(botao.Text) ~= nil then return end
            local texto = botao.Text
            local upper = string.upper(texto or "")
            local ehAcao = upper:find("TELEPORT", 1, true)
                or upper:find("REJOIN", 1, true)
                or upper:find("SERVIDOR", 1, true)
                or upper:find("MELHOR PING", 1, true)
            if ehAcao then Core:Notify(limparNomeFuncao(texto), "Ação iniciada.", 2) end
        end)
        Core:TrackConnection("NotificacoesUniversais", cliqueConn)
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
        card.Size = UDim2.new(1, -28, 0, 145)

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
        title.TextColor3 = Color3.fromRGB(244, 247, 252)
        title.Text = "ARASAKA // PAINEL DO SISTEMA"

        local info = Instance.new("TextLabel")
        info.Parent = card
        info.BackgroundTransparency = 1
        info.Position = UDim2.new(0, 16, 0, 34)
        info.Size = UDim2.new(1, -32, 0, 105)
        info.Font = Enum.Font.GothamMedium
        info.TextSize = 13
        info.TextXAlignment = Enum.TextXAlignment.Left
        info.TextYAlignment = Enum.TextYAlignment.Top
        info.TextColor3 = Color3.fromRGB(222, 222, 222)
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
            local playersNow = #Players:GetPlayers()
            local maxPlayers = Players.MaxPlayers
            info.Text = string.format(
                "VERSAO  // %s\nTEMPO ATIVO  // %s\nFPS  // %d    JOGADORES  // %d/%d\nPROCESSOS  // %d em execucao\nCONEXOES  // %d\nCHAT  // %s",
                tostring(Core.Version),
                formatUptime(os.clock() - Core.StartedAt),
                fpsValue,
                playersNow,
                maxPlayers,
                #workers,
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
        title.TextColor3 = Color3.fromRGB(228, 234, 243)
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
        status.TextColor3 = Color3.fromRGB(182, 194, 209)
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
        notifyButton.BackgroundColor3 = Color3.fromRGB(20, 27, 39)
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
        compactButton.BackgroundColor3 = Color3.fromRGB(20, 27, 39)
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
        local TAMANHO_MINIMIZADO = UDim2.fromOffset(48, 48)
        local minimizeTween = nil
        local minimizeGeneration = 0

        -- Quando minimizado, o painel vira apenas o icone Arasaka.
        local botaoIcone = Instance.new("ImageButton")
        botaoIcone.Name = "ArasakaIconeMinimizado"
        botaoIcone.Parent = frame
        botaoIcone.Size = UDim2.new(1, -8, 1, -8)
        botaoIcone.Position = UDim2.fromOffset(4, 4)
        botaoIcone.BackgroundTransparency = 1
        botaoIcone.Image = "rbxassetid://132397224962668"
        botaoIcone.ScaleType = Enum.ScaleType.Fit
        botaoIcone.ZIndex = 25
        botaoIcone.Visible = false
        botaoIcone.AutoButtonColor = true

        local function AplicarEstadoMinimizado(isMin)
            botaoIcone.Visible = isMin
            titleBar.Visible = not isMin
            topRed.Visible = not isMin
            sidebar.Visible = not isMin
            contentArea.Visible = not isMin
            separator.Visible = not isMin
            techLeft.Visible = not isMin
            techRight.Visible = not isMin
            subtitleText.Visible = not isMin
            userText.Visible = not isMin
            contentGlow.Visible = not isMin
            contentCode.Visible = not isMin
            if not isMin then
                btnMinimizar.Text = "—"
            end
        end

        local function AlternarMinimizacao()
            playClickSound()
            minimizado = not minimizado
            minimizeGeneration += 1
            local thisGen = minimizeGeneration
            if minimizeTween then
                pcall(function() minimizeTween:Cancel() end)
                minimizeTween = nil
            end

            if minimizado then
                AplicarEstadoMinimizado(true)
            else
                -- Oculta o icone antes da expansao e restaura os controles apos a animacao.
                botaoIcone.Visible = false
            end

            minimizeTween = TweenService:Create(
                frame,
                TweenInfo.new(0.3, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
                {Size = minimizado and TAMANHO_MINIMIZADO or TAMANHO_NORMAL}
            )
            minimizeTween:Play()
            if not minimizado then
                minimizeTween.Completed:Once(function()
                    if thisGen == minimizeGeneration and not minimizado then
                        AplicarEstadoMinimizado(false)
                    end
                end)
            end
        end

        btnMinimizar.MouseButton1Click:Connect(AlternarMinimizacao)
        botaoIcone.MouseButton1Click:Connect(AlternarMinimizacao)
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
]====]
