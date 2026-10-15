-- ARASAKA GRATIS / MODULO DE FONTE / PARTE 4 DE 6
return [====[                            if not s.started then
                                s.started = true
                                s.gain = 0
                                s.activeTime = 0
                            end

                            s.gain += delta
                            s.lastGainAt = now
                        end

                        -- Conta apenas o tempo em que o atributo está efetivamente progredindo.
                        if s.started and s.lastGainAt and (now - s.lastGainAt) <= TRAINING_GRACE_SECONDS then
                            s.activeTime += dt
                            table.insert(activeNames, s.name)
                            if s.activeTime > longestActive then
                                longestActive = s.activeTime
                            end
                        end

                        updateSampler(s)
                    end

                    if #activeNames > 0 then
                        info.Text = table.concat(activeNames, " + ")
                            .. " // TREINO DETECTADO // TEMPO ATIVO "
                            .. formatActiveTime(longestActive)
                    else
                        info.Text = "AGUARDANDO TREINO // SÓ CONTA ENQUANTO O STATUS ESTIVER SUBINDO"
                    end
                end)

                task.wait(POLL_SECONDS)
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
    killHeader.BackgroundColor3 = Color3.fromRGB(10, 10, 10)
    killHeader.BorderSizePixel = 0
    killHeader.Text = "  💀 CONTROLE KILL // SISTEMA DE ALVOS"
    killHeader.TextColor3 = Color3.fromRGB(244, 247, 252)
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
    killStatus.TextColor3 = Color3.fromRGB(182, 194, 209)
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
    introTop.BackgroundColor3 = Color3.fromRGB(10, 10, 10)
    introTop.BorderSizePixel = 0
    Instance.new("UICorner", introTop).CornerRadius = UDim.new(0, 4)
    local introStroke = Instance.new("UIStroke", introTop)
    introStroke.Color = Color3.fromRGB(42, 42, 42)

    local introAccent = Instance.new("Frame", introTop)
    introAccent.Size = UDim2.new(0, 3, 1, 0)
    introAccent.BackgroundColor3 = Color3.fromRGB(236, 64, 88)
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
    sessionBadge.BackgroundColor3 = Color3.fromRGB(21, 21, 21)
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
        value.TextColor3 = Color3.fromRGB(244, 247, 252)
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
    playIcon.TextColor3 = Color3.fromRGB(236, 64, 88)
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
    lblPlaytime.TextColor3 = Color3.fromRGB(244, 247, 252)
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

    local BossDamageHudState = {
        AutoBossEnabled = false,
        BossAlive = false,
    }

    local PauseFarmsForQuest = function() end
    local ResumeFarmsAfterQuest = function() end
    local RestoreFarmContext = function() return false end
    local CaptureBossReturnContext = function() return false end
    local FarmQuestPaused = false

    -- MODULE // FARMS
    function Farms:Init()
        Utils.PerfBegin("FARMS_UI")

    --==================================================
    -- ABAS SEPARADAS // FORÇA / REBIRTH / BOSS
    --==================================================
    local function CriarFarmScroll(parentTab)
        local scroll = Instance.new("ScrollingFrame", parentTab)
        scroll.Size = UDim2.new(1, -20, 1, -10)
        scroll.Position = UDim2.new(0, 10, 0, 5)
        scroll.BackgroundTransparency = 1
        scroll.BorderSizePixel = 0
        scroll.ScrollBarThickness = 4
        scroll.ScrollBarImageColor3 = Color3.fromRGB(110, 20, 20)
        scroll.CanvasSize = UDim2.new(0, 0, 0, 0)

        local layout = Instance.new("UIListLayout", scroll)
        layout.Padding = UDim.new(0, 6)
        layout.SortOrder = Enum.SortOrder.LayoutOrder
        layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
            scroll.CanvasSize = UDim2.new(0, 0, 0, layout.AbsoluteContentSize.Y + 20)
        end)

        return scroll
    end

    local farmForcaScroll = CriarFarmScroll(tabFarmForca)
    local farmRebirthScroll = CriarFarmScroll(tabFarmRebirth)
    local farmBossScroll = CriarFarmScroll(tabFarmBoss)

    -- Auto Boss normal: posição/altura e comportamento originais, sem controles novos.

    local farmScrolls = {
        farmForcaScroll,
        farmRebirthScroll,
        farmBossScroll,
    }

    -- Cria os controles diretamente, sem depender do helper global Utils.CreateTextButton.
    -- A versao anterior parava na primeira tentativa de criar botao de farm;
    -- os tres paineis ficavam incompletos (Force/Boss vazios, Rebirth so com meta).
    local function CriarBotaoFarmScroll(parent, texto, order)
        local btn = Instance.new("TextButton")
        btn.Name = "ArasakaFarmAction_" .. tostring(order)
        btn.LayoutOrder = order
        btn.Size = UDim2.new(1, -6, 0, 32)
        btn.BackgroundColor3 = Color3.fromRGB(14, 14, 14)
        btn.BorderSizePixel = 0
        btn.Text = texto .. ": OFF 🔴"
        btn.TextColor3 = Color3.fromRGB(205, 205, 205)
        btn.Font = Enum.Font.GothamBold
        btn.TextSize = 12
        btn.TextXAlignment = Enum.TextXAlignment.Left
        btn.Parent = parent

        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0, 2)
        corner.Parent = btn

        local stroke = Instance.new("UIStroke")
        stroke.Color = Color3.fromRGB(42, 42, 42)
        stroke.Thickness = 1
        stroke.Parent = btn

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

    -- Gratis: todos os tipos de boss suportados ficam habilitados.
    local function isBossAllowedBySelection(bossName)
        return bossName == "Boss1" or bossName == "Boss2"
            or bossName == "Boss3" or bossName == "Boss4"
            or bossName == "Boss5" or bossName == "BossAdmin"
            or bossName == "BossRainbow"
    end

    local overlordRebirthActive = false
    local farmOpActive = false
    local mainStrengthOpActive = false
    local farmOpControlledCycle = true
    local customRebirthActive = false

    local targetRebirthValue = 0
    local targetRebirthActive = false
    local targetRebirthButton
    local startTargetRebirthWorker
    local startCustomRebirthWorker
    local startAutoRepsWorker
    local startUnifiedFarmWorker
    local startOverlordWorker
    local startFarmOp
    local startMainStrengthOp
    local refreshTrainingWatchdog = function() end

    local function CriarSeparadorFarm(parent, texto, order)
        local sep = Instance.new("TextLabel", parent)
        sep.LayoutOrder = order
        sep.Size = UDim2.new(1, -6, 0, 24)
        sep.BackgroundTransparency = 1
        sep.Text = texto
        sep.TextColor3 = Color3.fromRGB(236, 64, 88)
        sep.Font = Enum.Font.GothamBold
        sep.TextSize = 12
        sep.TextXAlignment = Enum.TextXAlignment.Left
        return sep
    end
    local lockedCFrame, lockConnection, noclipConnection = nil, nil, nil
    local currentOffsetY = 45

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

    CriarSeparadorFarm(farmRebirthScroll, "// REBIRTH PERSONALIZADO", 1)

    local rebirthTargetBox = Instance.new("TextBox", farmRebirthScroll)
    rebirthTargetBox.LayoutOrder = 2
    rebirthTargetBox.Size = UDim2.new(1, -6, 0, 32)
    rebirthTargetBox.BackgroundColor3 = Color3.fromRGB(14, 14, 14)
    rebirthTargetBox.BorderSizePixel = 0
    rebirthTargetBox.PlaceholderText = "REBIRTH META — digite a meta"
    rebirthTargetBox.Text = ""
    rebirthTargetBox.TextColor3 = Color3.fromRGB(244, 247, 252)
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

    -- FARM REBIRTH
    targetRebirthButton = CriarBotaoFarmScroll(farmRebirthScroll, "AUTO REBIRTH TARGET", 3)
    local btnUnifiedFarm = CriarBotaoFarmScroll(farmRebirthScroll, "AUTO REPS 2X + REBIRTH 🏋️🔄", 4)
    local btnOverlordRebirth = CriarBotaoFarmScroll(farmRebirthScroll, "REBIRTH PACK OVERLORD 👑", 5)

    -- FARM FORÇA
    CriarSeparadorFarm(farmForcaScroll, "// FARM DE FORÇA", 1)
    local btnRepsOnly = CriarBotaoFarmScroll(farmForcaScroll, "AUTO REPS 2X (SO FORCA) 🏋️", 2)
    local btnFarmOp = CriarBotaoFarmScroll(farmForcaScroll, "CICLO CONTROLADOR ⚙️", 3)

    local btnFarmOpControlled = CriarBotaoFarmScroll(farmForcaScroll, "MODO CONTROLADO", 5)
    btnFarmOpControlled.Text = "MODO CONTROLADO: ON 🟢"
    btnFarmOpControlled.BackgroundColor3 = Color3.fromRGB(40, 160, 40)

    local btnMainStrengthOp = CriarBotaoFarmScroll(farmForcaScroll, "MAIN FORÇA 💪", 6)

    --==================================================
    -- SENSOR GLOBAL DE BOSS // VERSÃO GRÁTIS
    --==================================================
    do
        local FREE_BOSS_API = "https://chatprivado-cwu3.onrender.com"
        local FREE_BOSS_SCAN_INTERVAL = 0.50
        local FREE_BOSS_HEARTBEAT_INTERVAL = 60.0
        local FREE_BOSS_RETRY_INTERVAL = 10.0

        local freeBossAliases = {
            Boss1 = { logical = "boss1", send = "Boss1" },
            Boss2 = { logical = "boss2", send = "Boss2" },
            Boss3 = { logical = "boss3", send = "Boss3" },
            Boss4 = { logical = "boss4", send = "Boss4" },
            Boss5 = { logical = "boss5", send = "Boss5" },
            BossAdmin = { logical = "bossadminrainbow", send = "BossAdmin" },
            BossRainbow = { logical = "bossadminrainbow", send = "BossRainbow" },
        }

        local freeBossState = {}

        local function findFreeHttpRequest()
            return request
                or http_request
                or (syn and syn.request)
                or (http and http.request)
        end

        local function postFreeBossHeartbeat(bossName)
            local req = findFreeHttpRequest()
            local body = HttpService:JSONEncode({
                boss = bossName,
                placeId = tostring(game.PlaceId),
            })

            if req then
                local ok, response = pcall(function()
                    return req({
                        Url = FREE_BOSS_API .. "/api/free-boss-heartbeat",
                        Method = "POST",
                        Headers = {
                            ["Content-Type"] = "application/json",
                            ["Cache-Control"] = "no-cache",
                        },
                        Body = body,
                    })
                end)

                if not ok or type(response) ~= "table" then
                    return nil, "Falha de rede"
                end

                local status = tonumber(
                    response.StatusCode
                    or response.Status
                    or response.status_code
                ) or 0

                local raw = tostring(response.Body or response.body or "")
                local decoded

                if raw ~= "" then
                    pcall(function()
                        decoded = HttpService:JSONDecode(raw)
                    end)
                end

                if status ~= 0 and (status < 200 or status >= 300) then
                    return decoded, (decoded and decoded.message) or ("HTTP " .. tostring(status))
                end

                return decoded or { success = true }, nil
            end

            local ok, raw = pcall(function()
                return game:HttpPost(
                    FREE_BOSS_API .. "/api/free-boss-heartbeat",
                    body,
                    Enum.HttpContentType.ApplicationJson
                )
            end)

            if not ok then
                return nil, "Falha de rede"
            end

            local decoded
            pcall(function()
                decoded = HttpService:JSONDecode(tostring(raw or ""))
            end)

            return decoded or { success = true }, nil
        end

        local function getFreeBossArena()
            local events = workspace:FindFirstChild("Events")
            return events and events:FindFirstChild("BossArena") or nil
        end

        local function freeBossIsAlive(obj)
            if not obj or not obj.Parent then
                return false
            end

            if obj:IsA("Model") then
                local humanoid = obj:FindFirstChildOfClass("Humanoid")
                if humanoid then
                    return humanoid.Health > 0
                end

                return obj.PrimaryPart ~= nil
                    or obj:FindFirstChild("HumanoidRootPart") ~= nil
                    or obj:FindFirstChild("Head") ~= nil
                    or obj:FindFirstChildWhichIsA("BasePart") ~= nil
            end

            return obj:IsA("BasePart")
        end

        local function scanFreeBosses()
            local arena = getFreeBossArena()
            local found = {}

            if arena then
                for rawName, info in pairs(freeBossAliases) do
                    local obj = arena:FindFirstChild(rawName)
                    if obj and freeBossIsAlive(obj) and not found[info.logical] then
                        found[info.logical] = {
                            sendName = info.send,
                            object = obj,
                        }
                    end
                end
            end

            return found
        end

        local function reportFreeBoss(logicalKey, info, state)
            if state.sending then
                return
            end

            state.sending = true
            state.lastAttempt = os.clock()

            task.spawn(function()
                local response, err = postFreeBossHeartbeat(info.sendName)
                state.sending = false

                if response and response.success ~= false then
                    state.lastHeartbeat = os.clock()
                    state.lastError = nil
                else
                    state.lastError = tostring(
                        err
                        or (response and response.message)
                        or "erro desconhecido"
                    )
                    warn("[ARASAKA FREE][BOSS ALERT] falhou:", info.sendName, state.lastError)
                end
            end)
        end

        Core:StartWorker("BossSpawnAlertFree", function(isAlive)
            while isAlive() do
                local now = os.clock()
                local current = scanFreeBosses()

                for logicalKey, info in pairs(current) do
                    local state = freeBossState[logicalKey]

                    if not state then
                        state = {
                            present = true,
                            sending = false,
                            lastHeartbeat = 0,
                            lastAttempt = 0,
                            lastError = nil,
                        }
                        freeBossState[logicalKey] = state
                    elseif not state.present then
                        state.present = true
                        state.lastHeartbeat = 0
                        state.lastAttempt = 0
                    end

                    local sinceHeartbeat = now - (state.lastHeartbeat or 0)
                    local sinceAttempt = now - (state.lastAttempt or 0)

                    if not state.sending then
                        if state.lastHeartbeat <= 0 then
                            if state.lastAttempt == 0 or sinceAttempt >= FREE_BOSS_RETRY_INTERVAL then
                                reportFreeBoss(logicalKey, info, state)
                            end
                        elseif sinceHeartbeat >= FREE_BOSS_HEARTBEAT_INTERVAL then
                            reportFreeBoss(logicalKey, info, state)
                        end
                    end
                end

                for logicalKey, state in pairs(freeBossState) do
                    if state.present and not current[logicalKey] then
                        state.present = false
                        state.sending = false
                    end
                end

                task.wait(FREE_BOSS_SCAN_INTERVAL)
            end
        end)
    end


    -- FARM BOSS
    CriarSeparadorFarm(farmBossScroll, "// FARM BOSS", 1)
    local btnFarm = CriarBotaoFarmScroll(farmBossScroll, "AUTO FARM BOSS ⚔️", 2)

    -- FARM OP (11 PETS) // ciclo configurável.
    -- Baseado no modo "Strength (Slower)" do Silence:
    -- velocidade configurável + controle adaptativo por ping.
    do
        local box = Instance.new("TextBox", farmForcaScroll)
        box.Name = "ArasakaFarmOpRepsBox"
        box.LayoutOrder = 4
        box.Size = UDim2.new(1, -6, 0, 32)
        box.BackgroundColor3 = Color3.fromRGB(14, 14, 14)
        box.BorderSizePixel = 0
        box.PlaceholderText = "DIGITE A QUANTIDADE DE REPS POR CICLO"
        box.Text = ""
        box.TextColor3 = Color3.fromRGB(244, 247, 252)
        box.PlaceholderColor3 = Color3.fromRGB(110, 110, 110)
        box.Font = Enum.Font.GothamBold
        box.TextSize = 11
        box.ClearTextOnFocus = false
        box.TextXAlignment = Enum.TextXAlignment.Left
        box:SetAttribute("RepsPerCycle", 350)
        Instance.new("UICorner", box).CornerRadius = UDim.new(0, 2)
        local stroke = Instance.new("UIStroke", box)
        stroke.Color = Color3.fromRGB(42, 42, 42)
        stroke.Thickness = 1

        box.FocusLost:Connect(function()
            local value = tonumber(box.Text)
            if value and value >= 1 then
                value = math.clamp(math.floor(value), 1, 1000)
                box:SetAttribute("RepsPerCycle", value)
                box.Text = tostring(value)
            else
                box:SetAttribute("RepsPerCycle", 350)
                box.Text = ""
            end
        end)
    end

    local btnConfigRebirth = Instance.new("TextButton", farmRebirthScroll)
    btnConfigRebirth.LayoutOrder = 6
    btnConfigRebirth.Size = UDim2.new(1, -6, 0, 32)
    btnConfigRebirth.BackgroundColor3 = Color3.fromRGB(236, 64, 88)
    btnConfigRebirth.Text = "CONFIGURAR REBIRTH ⚙️"
    btnConfigRebirth.TextColor3 = Color3.fromRGB(255, 255, 255)
    btnConfigRebirth.Font = Enum.Font.GothamBold
    btnConfigRebirth.TextSize = 11
    Instance.new("UICorner", btnConfigRebirth).CornerRadius = UDim.new(0, 6)

    local btnCustomRebirthToggle = CriarBotaoFarmScroll(farmRebirthScroll, "CUSTOM REBIRTH AUTO 🔄", 7)
    local btnTravarLocal = CriarBotaoFarmScroll(farmForcaScroll, "TRAVAR LOCAL 📍", 7)

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
        mainFrame.BackgroundColor3 = Color3.fromRGB(12, 16, 24)
        mainFrame.BorderSizePixel = 0
        mainFrame.Active, mainFrame.Draggable = true, true
        Instance.new("UICorner", mainFrame).CornerRadius = UDim.new(0, 4)

        local stroke = Instance.new("UIStroke", mainFrame)
        stroke.Color = Color3.fromRGB(150, 25, 25)
        stroke.Thickness = 1

        local topLine = Instance.new("Frame", mainFrame)
        topLine.Size = UDim2.new(1, 0, 0, 3)
        topLine.BackgroundColor3 = Color3.fromRGB(236, 64, 88)
        topLine.BorderSizePixel = 0

        local header = Instance.new("Frame", mainFrame)
        header.Size = UDim2.new(1, 0, 0, 58)
        header.Position = UDim2.new(0, 0, 0, 3)
        header.BackgroundColor3 = Color3.fromRGB(10, 10, 10)
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
        titleLbl.TextColor3 = Color3.fromRGB(244, 247, 252)
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
        closeBtn.BackgroundColor3 = Color3.fromRGB(23, 31, 43)
        closeBtn.BorderSizePixel = 0
        closeBtn.Text = "×"
        closeBtn.TextColor3 = Color3.fromRGB(236, 64, 88)
        closeBtn.Font = Enum.Font.GothamBold
        closeBtn.TextSize = 16
        Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(0, 4)

        closeBtn.MouseButton1Click:Connect(function() configGui:Destroy() end)
        bgOverlay.MouseButton1Click:Connect(function() configGui:Destroy() end)

        local separator = Instance.new("Frame", mainFrame)
        separator.Size = UDim2.new(1, -24, 0, 1)
        separator.Position = UDim2.new(0, 12, 0, 65)
        separator.BackgroundColor3 = Color3.fromRGB(48, 60, 76)
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
                    if rebirthsVal.Value >= targetRebirthValue then
                        targetRebirthActive = false
                        targetRebirthButton.Text = "AUTO REBIRTH TARGET: OFF 🔴"
                        targetRebirthButton.BackgroundColor3 = Color3.fromRGB(14, 14, 14)
                        break
                    end

                    -- AUTO REBIRTH META agora também treina força.
                    -- Mantém o treino ativo enquanto tenta alcançar a meta.
                    local muscleEvent = getMuscleEvent()
                    if muscleEvent then
                        for _ = 1, 4 do
                            pcall(function()
                                muscleEvent:FireServer("rep")
                            end)
                        end
                    end

                    local rebirthRemote = getRebirthRemote()
                    if rebirthRemote then
                        pcall(function()
                            rebirthRemote:InvokeServer("rebirthRequest")
                        end)
                    end
                end

                RunService.Heartbeat:Wait()
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
                    for _ = 1, 3 do pcall(function() event:FireServer("rep") end) end
                    task.wait(0.01)
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

    local function equipOverlordHandWeight()
        local char = player.Character
        local humanoid = char and char:FindFirstChildOfClass("Humanoid")
        local backpack = player:FindFirstChild("Backpack")
        if not char or not humanoid then
            return false
        end

        -- Se já existe um Tool equipado, prioriza um peso/weight existente.
        local currentTool = char:FindFirstChildOfClass("Tool")
        if currentTool and string.find(string.lower(currentTool.Name), "weight", 1, true) then
            return true
        end

        local weight = nil

        -- Nomes mais comuns primeiro.
        local preferredNames = {
            "Weight",
            "100g Weight",
            "Hand Weight",
        }

        for _, name in ipairs(preferredNames) do
            weight = char:FindFirstChild(name) or (backpack and backpack:FindFirstChild(name))
            if weight and weight:IsA("Tool") then
                break
            end
            weight = nil
        end

        -- Fallback: qualquer Tool cujo nome contenha "weight".
        if not weight then
            for _, container in ipairs({char, backpack}) do
                if container then
                    for _, item in ipairs(container:GetChildren()) do
                        if item:IsA("Tool")
                            and string.find(string.lower(item.Name), "weight", 1, true) then
                            weight = item
                            break
                        end
                    end
                end
                if weight then break end
            end
        end

        if weight and weight:IsA("Tool") then
            if weight.Parent ~= char then
                pcall(function()
                    humanoid:EquipTool(weight)
                end)
                task.wait()
            end
            return weight.Parent == char
        end

        return false
    end

    startOverlordWorker = function()
        if not overlordRebirthActive then
            Core:StopWorker("Farms.Overlord")
            return
        end
        Core:StartWorker("Farms.Overlord", function(isAlive)
            while isAlive() and overlordRebirthActive do
                equipFarmingPetsOverlord()
                equipOverlordHandWeight()

                local leaderstats = player:FindFirstChild("leaderstats")
                local rebirthsVal = leaderstats and leaderstats:FindFirstChild("Rebirths")
                local strengthVal = leaderstats and leaderstats:FindFirstChild("Strength")

                if rebirthsVal and strengthVal then
                    local targetStr = 5000 + (rebirthsVal.Value * 2550)
                    local repsBurst = player.MembershipType == Enum.MembershipType.Premium and 6 or 12

                    local lastWeightCheck = 0
                    while isAlive() and overlordRebirthActive and strengthVal.Value < targetStr do
                        if tick() - lastWeightCheck >= 1 then
                            equipOverlordHandWeight()
                            lastWeightCheck = tick()
                        end

                        local event = getMuscleEvent()
                        if event then
                            for _ = 1, repsBurst do
                                pcall(function()
                                    event:FireServer("rep")
                                end)
                            end
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

                        if overlordRebirthActive and isAlive() then
                            task.wait(0.05)
                            equipOverlordHandWeight()
                        end
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

    --==================================================
    -- CICLO CONTROLADOR // IMPORTADO/ADAPTADO DO SILENCE
    --==================================================
    -- Dicionário usado pelo Silence para decidir quais pets priorizar.
    local SILENCE_FARM_PETS = {
        ["Omega Overlord"] = {repSpeed = 20, strength = 0, durability = 0, rebirth = 0},
        ["Swift Samurai"] = {repSpeed = 15, strength = 0, durability = 0, rebirth = 0},
        ["Powercore Hound"] = {repSpeed = 0, strength = 25, durability = 15, rebirth = 0},
        ["Titanium Hydra"] = {repSpeed = 0, strength = 0, durability = 0, rebirth = 2},
        ["Tribal Overlord"] = {repSpeed = 0, strength = 0, durability = 0, rebirth = 2},
        ["Inferno Unicorn"] = {repSpeed = 0, strength = 25, durability = 25, rebirth = 0},
        ["Common Boss Pet"] = {repSpeed = 5, strength = 0, durability = 0, rebirth = 0},
        ["Rare Boss Pet"] = {repSpeed = 7, strength = 0, durability = 0, rebirth = 0},
        ["Epic Boss Pet"] = {repSpeed = 10, strength = 0, durability = 0, rebirth = 0},
        ["Rainbow Boss Pet"] = {repSpeed = 10, strength = 7, durability = 0, rebirth = 0},
        ["Legendary Boss Pet"] = {repSpeed = 10, strength = 10, durability = 0, rebirth = 0},
        ["Mythic Boss Pet"] = {repSpeed = 10, strength = 20, durability = 0, rebirth = 0},
        ["Inferno Drake"] = {repSpeed = 40, strength = 0, durability = 0, rebirth = 0},
    }

    local FARM_OP_MAX_PETS = 11
    local FARM_OP_TARGET_REP_SPEED = 100

    local function getFarmOpEquipEvent()
        local rEvents = ReplicatedStorage:FindFirstChild("rEvents")
        return rEvents and rEvents:FindFirstChild("equipPetEvent")
    end

    local function unequipFarmOpConfiguredPets()
        local petsFolder = player:FindFirstChild("petsFolder")
        local equipEvent = getFarmOpEquipEvent()
        if not petsFolder or not equipEvent then return end

        for _, folder in ipairs(petsFolder:GetChildren()) do
            if folder:IsA("Folder") then
                for _, pet in ipairs(folder:GetChildren()) do
                    if SILENCE_FARM_PETS[pet.Name] then
                        pcall(function()
                            equipEvent:FireServer("unequipPet", pet)
                        end)
                    end
                end
            end
        end
        task.wait(0.1)
    end

    local function getOwnedSilenceFarmPets()
        local result = {}
        local petsFolder = player:FindFirstChild("petsFolder")
        if not petsFolder then return result end

        for _, folder in ipairs(petsFolder:GetChildren()) do
            if folder:IsA("Folder") then
                for _, pet in ipairs(folder:GetChildren()) do
                    local config = SILENCE_FARM_PETS[pet.Name]
                    if config then
                        table.insert(result, {
                            instance = pet,
                            name = pet.Name,
                            repSpeed = config.repSpeed or 0,
                            strength = config.strength or 0,
                            durability = config.durability or 0,
                            rebirth = config.rebirth or 0,
                        })
                    end
                end
            end
        end

        return result
    end

    local function equipBestSilenceFarmPets11()
        local equipEvent = getFarmOpEquipEvent()
        if not equipEvent then return 0, 0 end

        unequipFarmOpConfiguredPets()

        local pets = getOwnedSilenceFarmPets()
        local equipped = {}
        local equippedCount = 0
        local currentRepSpeed = 0

        -- Primeiro o Silence prioriza Rep Speed até alcançar o alvo.
        table.sort(pets, function(a, b)
            return a.repSpeed > b.repSpeed
        end)

        for _, pet in ipairs(pets) do
            if equippedCount >= FARM_OP_MAX_PETS or currentRepSpeed >= FARM_OP_TARGET_REP_SPEED then
                break
            end

            if pet.repSpeed > 0 then
                pcall(function()
                    equipEvent:FireServer("equipPet", pet.instance)
                end)
                equipped[pet.instance] = true
                equippedCount += 1
                currentRepSpeed += pet.repSpeed
                task.wait(0.02)
            end
        end

        -- Depois completa os slots com Strength + Durability.
        local remaining = {}
        for _, pet in ipairs(pets) do
            if not equipped[pet.instance] then
                table.insert(remaining, pet)
            end
        end

        table.sort(remaining, function(a, b)
            return (a.strength + a.durability) > (b.strength + b.durability)
        end)

        for _, pet in ipairs(remaining) do
            if equippedCount >= FARM_OP_MAX_PETS then
                break
            end

            if pet.strength > 0 or pet.durability > 0 then
                pcall(function()
                    equipEvent:FireServer("equipPet", pet.instance)
                end)
                equipped[pet.instance] = true
                equippedCount += 1
                task.wait(0.02)
            end
        end

        return currentRepSpeed, equippedCount
    end

    local function getCurrentPingMs()
        local ok, value = pcall(function()
            local stats = game:GetService("Stats")
            local item = stats.Network.ServerStatsItem["Data Ping"]
            return item:GetValue()
        end)
        return ok and tonumber(value) or 0
    end

    local function getSilenceControlledBatch(ping)
        if ping < 80 then
            return 500
        elseif ping < 150 then
            return 300
        elseif ping < 250 then
            return 100
        end
        return 50
    end

    local function stopFarmOp()
        farmOpActive = false
        Core:StopWorker("Farms.FarmOp")
    end

    startFarmOp = function()
        if Core:IsWorkerRunning("Farms.FarmOp") then return end

        -- Mantem os pets atualmente equipados pelo jogador.
        -- O Ciclo Controlador faz apenas os REPS e nao altera equipes.

        Core:StartWorker("Farms.FarmOp", function(isAlive)
            while isAlive() and farmOpActive do
                local event = getMuscleEvent()
                if not event then
                    RunService.Heartbeat:Wait()
                    continue
                end

                local repsBox = farmForcaScroll:FindFirstChild("ArasakaFarmOpRepsBox")
                local configuredCycle = math.clamp(
                    math.floor(tonumber(repsBox and repsBox:GetAttribute("RepsPerCycle")) or 350),
                    1,
                    1000
                )

                local ping = getCurrentPingMs()
                local repsThisCycle = configuredCycle
                local cycleDelay = 0

                if farmOpControlledCycle then
]====]
