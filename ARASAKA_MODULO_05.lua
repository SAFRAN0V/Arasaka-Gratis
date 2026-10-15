-- ARASAKA GRATIS / MODULO DE FONTE / PARTE 5 DE 6
return [====[                    repsThisCycle = math.min(configuredCycle, getSilenceControlledBatch(ping))
                    cycleDelay = math.clamp(ping / 2500, 0.001, 0.1)
                end

                for i = 1, repsThisCycle do
                    if not isAlive() or not farmOpActive then break end
                    pcall(function()
                        event:FireServer("rep")
                    end)

                    -- Mesmo princípio do Silence: cede o scheduler em lotes muito grandes.
                    if i % 500 == 0 then
                        task.wait()
                    end
                end

                if cycleDelay > 0 then
                    task.wait(cycleDelay)
                else
                    RunService.Heartbeat:Wait()
                end
            end
        end)
    end

    btnFarmOpControlled.MouseButton1Click:Connect(function()
        playClickSound()
        farmOpControlledCycle = not farmOpControlledCycle
        btnFarmOpControlled.Text = "MODO CONTROLADO: "
            .. (farmOpControlledCycle and "ON 🟢" or "OFF 🔴")
        btnFarmOpControlled.BackgroundColor3 = farmOpControlledCycle
            and Color3.fromRGB(40, 160, 40)
            or Color3.fromRGB(14, 14, 14)
    end)

    btnFarmOp.MouseButton1Click:Connect(function()
        playClickSound()

        if farmOpActive then
            stopFarmOp()
            btnFarmOp.Text = "CICLO CONTROLADOR: OFF 🔴"
            btnFarmOp.BackgroundColor3 = Color3.fromRGB(14, 14, 14)
        else
            -- Evita dois farms de Strength disparando juntos.
            if mainStrengthOpActive then
                mainStrengthOpActive = false
                Core:StopWorker("Farms.MainStrengthOp")
                btnMainStrengthOp.Text = "MAIN FORÇA: OFF 🔴"
                btnMainStrengthOp.BackgroundColor3 = Color3.fromRGB(14, 14, 14)
            end

            farmOpActive = true
            btnFarmOp.Text = "CICLO CONTROLADOR: ON 🟢"
            btnFarmOp.BackgroundColor3 = Color3.fromRGB(40, 160, 40)
            startFarmOp()
        end
    end)

    --==================================================
    -- MAIN FORÇA — controlador do Silence original.
    -- Ajusta a taxa a cada 0,5 s; reduz após dois intervalos sem progresso.
    --==================================================
    local mainStrengthState = {
        initialSendRate = 200,
        maxRate = 659,
        sendRate = 200,
        sendTokens = 0,
        maxBurst = 24,
        lastLoopAt = os.clock(),
        controlInterval = 0.5,
        lastControlAt = tick(),
        lastStrength = 0,
        lastDurability = 0,
        stalledIntervals = 0,
    }

    local function readMainStrengthStats()
        local leaderstats = player:FindFirstChild("leaderstats")
        local strength = leaderstats and (leaderstats:FindFirstChild("Strength") or leaderstats:FindFirstChild("Muscle"))
        local durability = player:FindFirstChild("Durability")
            or (leaderstats and leaderstats:FindFirstChild("Durability"))

        return strength and tonumber(strength.Value) or 0,
            durability and tonumber(durability.Value) or 0
    end

    local function resetMainStrengthController()
        local strength, durability = readMainStrengthStats()
        mainStrengthState.sendRate = mainStrengthState.initialSendRate
        mainStrengthState.sendTokens = 0
        mainStrengthState.lastLoopAt = os.clock()
        mainStrengthState.lastControlAt = tick()
        mainStrengthState.lastStrength = strength
        mainStrengthState.lastDurability = durability
        mainStrengthState.stalledIntervals = 0
    end

    local function updateMainStrengthAdaptiveRate()
        local now = tick()
        if now - mainStrengthState.lastControlAt < mainStrengthState.controlInterval then
            return
        end

        local strength, durability = readMainStrengthStats()
        local serverProgress = strength > mainStrengthState.lastStrength
            or durability > mainStrengthState.lastDurability

        if serverProgress then
            mainStrengthState.stalledIntervals = 0
            mainStrengthState.sendRate = math.min(
                mainStrengthState.maxRate,
                mainStrengthState.sendRate * 1.12
            )
        else
            mainStrengthState.stalledIntervals = mainStrengthState.stalledIntervals + 1
        end

        if mainStrengthState.stalledIntervals >= 2 then
            mainStrengthState.sendRate = math.max(
                mainStrengthState.initialSendRate,
                mainStrengthState.sendRate * 0.65
            )
            mainStrengthState.sendTokens = 0
        end

        mainStrengthState.lastControlAt = now
        mainStrengthState.lastStrength = strength
        mainStrengthState.lastDurability = durability
    end

    startMainStrengthOp = function()
        if Core:IsWorkerRunning("Farms.MainStrengthOp") then return end

        resetMainStrengthController()

        Core:StartWorker("Farms.MainStrengthOp", function(isAlive)
            while isAlive() and mainStrengthOpActive do
                local event = getMuscleEvent()

                if not event then
                    RunService.Heartbeat:Wait()
                    continue
                end

                local loopNow = os.clock()
                local loopElapsed = math.min(0.1, loopNow - mainStrengthState.lastLoopAt)
                mainStrengthState.lastLoopAt = loopNow

                updateMainStrengthAdaptiveRate()

                mainStrengthState.sendTokens = math.min(
                    mainStrengthState.maxBurst,
                    mainStrengthState.sendTokens + mainStrengthState.sendRate * loopElapsed
                )

                local burstLimit = math.max(
                    1,
                    math.min(
                        mainStrengthState.maxBurst,
                        math.ceil(mainStrengthState.sendRate * 0.05)
                    )
                )

                local sendCount = math.min(
                    math.floor(mainStrengthState.sendTokens),
                    burstLimit
                )

                for _ = 1, sendCount do
                    if not isAlive() or not mainStrengthOpActive then
                        break
                    end

                    pcall(function()
                        event:FireServer("rep")
                    end)

                end

                mainStrengthState.sendTokens = math.max(
                    0,
                    mainStrengthState.sendTokens - sendCount
                )

                RunService.Heartbeat:Wait()
            end
        end)
    end

    btnMainStrengthOp.MouseButton1Click:Connect(function()
        playClickSound()
        mainStrengthOpActive = not mainStrengthOpActive

        if mainStrengthOpActive then
            -- Não deixa o Ciclo Controlador disputar o mesmo muscleEvent.
            if farmOpActive then
                stopFarmOp()
                btnFarmOp.Text = "CICLO CONTROLADOR: OFF 🔴"
                btnFarmOp.BackgroundColor3 = Color3.fromRGB(14, 14, 14)
            end

            btnMainStrengthOp.Text = "MAIN FORÇA: ON 🟢"
            btnMainStrengthOp.BackgroundColor3 = Color3.fromRGB(40, 160, 40)
            startMainStrengthOp()
        else
            Core:StopWorker("Farms.MainStrengthOp")
            btnMainStrengthOp.Text = "MAIN FORÇA: OFF 🔴"
            btnMainStrengthOp.BackgroundColor3 = Color3.fromRGB(14, 14, 14)
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

    --==================================================
    -- BOSS CHEST // workspace.BossChest
    --==================================================
    -- Todos os baus de boss ficam dentro de workspace.BossChest.
    -- Nao varremos mais o Workspace inteiro: usamos somente esse container.
    local function findBossChestPrompt()
        local chest = workspace:FindFirstChild("BossChest")
        if not chest then
            return nil
        end

        return chest:FindFirstChildWhichIsA("ProximityPrompt", true)
    end

    local function getPromptPosition(prompt)
        if not prompt or not prompt.Parent then return nil end

        local parent = prompt.Parent
        if parent:IsA("Attachment") then
            local bp = parent.Parent
            if bp and bp:IsA("BasePart") then
                return bp.Position
            end
        elseif parent:IsA("BasePart") then
            return parent.Position
        end

        local model = parent:FindFirstAncestorOfClass("Model")
        if model then
            local part = model.PrimaryPart
                or model:FindFirstChild("HumanoidRootPart")
                or model:FindFirstChildWhichIsA("BasePart", true)
            if part then return part.Position end
        end

        return nil
    end

    local function pressEChest(holdTime)
        local ok, vim = pcall(function()
            return game:GetService("VirtualInputManager")
        end)
        if not ok or not vim then return false end

        holdTime = math.max(tonumber(holdTime) or 0.08, 0.08)
        return pcall(function()
            vim:SendKeyEvent(true, Enum.KeyCode.E, false, game)
            task.wait(holdTime)
            vim:SendKeyEvent(false, Enum.KeyCode.E, false, game)
        end)
    end

    local function collectBossChest()
        -- Sistema antigo que funcionava:
        -- procura qualquer ProximityPrompt dentro de workspace.BossChest.
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

    -- Mantém o personagem suspenso durante a troca de alvo/espera de baú.
    -- Só trava a raiz enquanto o Auto Boss está realmente em transição.
    local function holdBossTransition()
        local char = player.Character
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        local root = char and char:FindFirstChild("HumanoidRootPart")
        if not root or not hum or hum.Health <= 0 then return false end
        root.AssemblyLinearVelocity = Vector3.zero
        root.AssemblyAngularVelocity = Vector3.zero
        root.Anchored = true
        return true
    end

    local function holdNearBossChest()
        local chest = workspace:FindFirstChild("BossChest")
        if not chest then return holdBossTransition() end

        local prompt = chest:FindFirstChildWhichIsA("ProximityPrompt", true)
        if not prompt then return holdBossTransition() end

        local pos = getPromptWorldPosition(prompt)
        if not pos then return holdBossTransition() end

        local char = player.Character
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        local root = char and char:FindFirstChild("HumanoidRootPart")
        if not root or not hum or hum.Health <= 0 then return false end

        -- Mantém o personagem perto do prompt e impede que ele atravesse o chão
        -- enquanto o baú está sendo coletado.
        root.Anchored = true
        root.CFrame = CFrame.new(pos + Vector3.new(0, 2.5, 0))
        root.AssemblyLinearVelocity = Vector3.zero
        root.AssemblyAngularVelocity = Vector3.zero
        return true
    end

    local function releaseBossChestHold()
        local char = player.Character
        local root = char and char:FindFirstChild("HumanoidRootPart")
        if root then
            root.Anchored = false
        end
    end

    local function getBossTargetPosition()
        local events = workspace:FindFirstChild("Events")
        if not events then return nil end
        local bossArena = events:FindFirstChild("BossArena")
        if not bossArena then return nil end

        -- Mantem a lista antiga e adiciona BossAdmin sem remover Boss6/BossRainbow.
        local targetBosses = {"Boss1", "Boss2", "Boss3", "Boss4", "Boss5", "Boss6", "BossAdmin", "BossRainbow"}
        local sawNamedBoss = false

        for _, bossName in ipairs(targetBosses) do
            local bossObj = bossArena:FindFirstChild(bossName)
            if bossObj then
                sawNamedBoss = true

                -- Boss existe, mas o usuario nao marcou esse tipo: ignora e continua farmando.
                if isBossAllowedBySelection(bossName) then
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
        end

        -- Nunca usa BossSpawn/Part da arena como alvo.
        -- Se nenhum objeto real de boss permitido estiver presente, não farma.
        return nil
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
                task.wait(0.2)
                if not isAlive() or not autoFarmActive or not humanoid.Parent then break end

                local currentHealth = humanoid.Health
                if currentHealth < lastHealth then
                    damageCount += 1
                    currentOffsetY = 45 + (damageCount * 5)
                end
                lastHealth = currentHealth
            end
        end)
    end

    local function jumpBeforeFarmReturn()
        local char = player.Character
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        local root = char and char:FindFirstChild("HumanoidRootPart")
        if not hum or not root or hum.Health <= 0 then return false end

        hum.Sit = false
        hum.Jump = true
        pcall(function()
            hum:ChangeState(Enum.HumanoidStateType.Jumping)
        end)

        local v = root.AssemblyLinearVelocity
        root.AssemblyLinearVelocity = Vector3.new(v.X, math.max(v.Y, 28), v.Z)
        task.wait(0.18)
        return true
    end

    --==================================================
    -- AUTO BOSS // RETORNO AO LOCAL ORIGINAL + BAÚ
    --==================================================
    local bossCycleInArena = false
    local bossReturnDeadline = nil
    local bossChestCollected = false
    local bossFarmPauseSnapshot = nil

    local function getBossTargetForFarm()
        -- Usa a MESMA detecção que o Auto Boss antigo já usava.
        -- A versão anterior exigia Humanoid e alguns bosses deste jogo não
        -- expõem Humanoid do jeito esperado, então o target ficava nil.
        return getBossTargetPosition()
    end

    local function resetBossCycleState()
        bossCycleInArena = false
        bossReturnDeadline = nil
        bossChestCollected = false
        releaseBossChestHold()
    end

    local function pauseAllFarmsForBoss()
        if bossFarmPauseSnapshot then return end

        -- AUTO BOSS: salva o ponto REAL onde o player está farmando agora,
        -- imediatamente antes de sair para o boss. Isso evita voltar para
        -- a posição antiga onde o botão do farm foi ligado.
        pcall(CaptureBossReturnContext)

        bossFarmPauseSnapshot = {
            target = targetRebirthActive,
            custom = customRebirthActive,
            autoReps = autoRepsActive,
            unified = autoUnifiedFarmActive,
            overlord = overlordRebirthActive,
            farmOp = farmOpActive,
            mainStrengthOp = mainStrengthOpActive,
            travar = travarLocalActive,
        }

        -- Para TODOS os workers de farm que podem competir com o Auto Boss.
        -- O Auto Boss em si e o Auto Quest NÃO são desligados aqui.
        for _, workerName in ipairs({
            "Farms.TargetRebirth",
            "Farms.CustomRebirth",
            "Farms.AutoReps",
            "Farms.AutoUnified",
            "Farms.TrainingWatchdog",
            "Farms.Overlord",
            "Farms.FarmOp",
            "Farms.MainStrengthOp",
        }) do
            Core:StopWorker(workerName)
        end

        -- Travar Local também interfere com o teleporte até o boss.
        if lockConnection then
            lockConnection:Disconnect()
            lockConnection = nil
        end

        print("[ARASAKA][AUTO BOSS] Boss detectado // farms pausadas temporariamente.")
    end

    local function resumeAllFarmsAfterBoss()
        local snapshot = bossFarmPauseSnapshot
        bossFarmPauseSnapshot = nil
        if not snapshot or FarmQuestPaused then return end

        if snapshot.target and targetRebirthActive and startTargetRebirthWorker then
            startTargetRebirthWorker()
        end
        if snapshot.custom and customRebirthActive and startCustomRebirthWorker then
            startCustomRebirthWorker()
        end
        if snapshot.autoReps and autoRepsActive and startAutoRepsWorker then
            startAutoRepsWorker()
        end
        if snapshot.unified and autoUnifiedFarmActive and startUnifiedFarmWorker then
            startUnifiedFarmWorker()
        end
        if snapshot.overlord and overlordRebirthActive and startOverlordWorker then
            startOverlordWorker()
        end
        if snapshot.farmOp and farmOpActive and startFarmOp then
            startFarmOp()
        end
        if snapshot.mainStrengthOp and mainStrengthOpActive and startMainStrengthOp then
            startMainStrengthOp()
        end

        if snapshot.travar and travarLocalActive then
            local char = player.Character
            local root = char and char:FindFirstChild("HumanoidRootPart")
            lockedCFrame = root and root.CFrame or lockedCFrame

            if lockConnection then
                lockConnection:Disconnect()
            end

            lockConnection = RunService.RenderStepped:Connect(function()
                if not travarLocalActive or not Core:IsAlive() then
                    if lockConnection then
                        lockConnection:Disconnect()
                        lockConnection = nil
                    end
                    return
                end

                local c = player.Character
                local r = c and c:FindFirstChild("HumanoidRootPart")
                if r and lockedCFrame then
                    r.CFrame = lockedCFrame
                    r.AssemblyLinearVelocity = Vector3.zero
                    r.AssemblyAngularVelocity = Vector3.zero
                end
            end)
        end

        refreshTrainingWatchdog()
        print("[ARASAKA][AUTO BOSS] Farms anteriores retomadas.")
    end

    -- Mesmo sistema de sustentacao fisica usado no evento Halloween.
    local normalBossPosition, normalBossGyro = nil, nil
    local normalBossAngle, normalBossTick = 0, os.clock()
    local function releaseNormalBossHold()
        if normalBossPosition then pcall(function() normalBossPosition:Destroy() end) end
        if normalBossGyro then pcall(function() normalBossGyro:Destroy() end) end
        normalBossPosition, normalBossGyro = nil, nil
    end
    local function prepareNormalBossHold(root)
        if normalBossPosition and normalBossPosition.Parent ~= root then releaseNormalBossHold() end
        if not normalBossPosition then
            local bp = Instance.new("BodyPosition")
            bp.Name = "ArasakaNormalBossPosition"
            bp.MaxForce = Vector3.new(1e8, 1e8, 1e8)
            bp.P, bp.D = 25000, 1800
            bp.Parent = root
            normalBossPosition = bp
        end
        if not normalBossGyro then
            local bg = Instance.new("BodyGyro")
            bg.Name = "ArasakaNormalBossGyro"
            bg.MaxTorque = Vector3.new(1e8, 1e8, 1e8)
            bg.P, bg.D = 20000, 1200
            bg.Parent = root
            normalBossGyro = bg
        end
    end

    local function startBossFarmRuntime()
        Core:StopWorker("Farms.BossPosition")
        Core:StopWorker("Farms.BossAttack")
        resetBossCycleState()
        releaseNormalBossHold()
        normalBossAngle, normalBossTick = 0, os.clock()

        Core:StartWorker("Farms.BossPosition", function(isAlive)
            local lastBossSeen = false
            while isAlive() and autoFarmActive and not FarmQuestPaused do
                -- Comportamento antigo completo: tenta coletar o BossChest
                -- em TODO Heartbeat enquanto o Auto Boss estiver ativo.
                -- Assim, no instante em que o baú/prompt aparece, ele já tenta usar.
                if collectBossChest() then
                    bossChestCollected = true
                end

                local character = player.Character
                local hrp = character and character:FindFirstChild("HumanoidRootPart")
                local humanoid = character and character:FindFirstChildOfClass("Humanoid")

                if hrp and humanoid and humanoid.Health > 0 then
                    -- Depois que o boss morreu, tenta coletar o baú por no máximo 5s.
                    -- Durante essa janela o player fica preso perto do prompt para não
                    -- atravessar o chão/morrer antes da coleta.
                    if bossReturnDeadline then
                        releaseNormalBossHold()
                        BossDamageHudState.BossAlive = false

                        holdNearBossChest()

                        if collectBossChest() then
                            bossChestCollected = true
                        end

                        -- Coletou: encerra a espera imediatamente.
                        -- Se o baú não responder, encerra após no máximo 5s.
                        if bossChestCollected or os.clock() >= bossReturnDeadline then
                            if not bossChestCollected then
                                holdNearBossChest()
                                if collectBossChest() then
                                    bossChestCollected = true
                                end
                            end

                            -- Não solta antes do retorno: manter seguro contra limbo.
                            holdBossTransition()
                            setNoclip(false)
                            RestoreFarmContext()
                            releaseBossChestHold()
                            resumeAllFarmsAfterBoss()
                            resetBossCycleState()
                        end
                    else
                        local targetPos = getBossTargetForFarm()
                        BossDamageHudState.BossAlive = targetPos ~= nil

                        if targetPos then
                            if not lastBossSeen then
                                print("[ARASAKA][AUTO BOSS] Boss detectado. Pausando rebirth e soltando a maquina.")
                                lastBossSeen = true
                            end
                            if not bossCycleInArena then
                                bossCycleInArena = true
                                bossChestCollected = false

                                -- Evita delay/conflito: pausa todos os farms antes do Auto Boss.
                                -- Auto Quest permanece ativo; se a quest atual for de boss,
                                -- ela pode continuar trabalhando no mesmo boss.
                                pauseAllFarmsForBoss()

                                -- Mesmo pulo usado no fluxo do Auto Quest/retorno da farm.
                                jumpBeforeFarmReturn()
                            end

                            releaseBossChestHold()
                            setNoclip(true)
                            -- Sustentacao igual ao boss do evento; altura reage ao dano.
                            -- Orbita opcional (normalOrbit); quando desligada, fica a 25 studs.
                            local desired = targetPos + Vector3.new(0, currentOffsetY, 0)
                            if hrp.Anchored then
                                hrp.CFrame = CFrame.new(desired)
                                hrp.AssemblyLinearVelocity = Vector3.zero
                                hrp.Anchored = false
                            end
                            prepareNormalBossHold(hrp)
                            normalBossPosition.Position = desired
                            if (hrp.Position - desired).Magnitude > 75 then
                                hrp.CFrame = CFrame.lookAt(desired, targetPos)
                            end
                            if (targetPos - hrp.Position).Magnitude > 0.01 then
                                normalBossGyro.CFrame = CFrame.lookAt(hrp.Position, targetPos)
                            end
                        elseif bossCycleInArena then
                            releaseNormalBossHold()
                            if lastBossSeen then
                                print("[ARASAKA][AUTO BOSS] Boss morto. Tentando coletar o baú por até 5s.")
                                lastBossSeen = false
                            end
                            -- Transição boss vivo -> boss morto.
                            -- Janela curta: fica perto do baú por até 5s e tenta coletar.
                            bossReturnDeadline = os.clock() + 5
                            holdNearBossChest()
                            if collectBossChest() then
                                bossChestCollected = true
                            end
                        else
                            BossDamageHudState.BossAlive = false
                            releaseNormalBossHold()
                            -- Sem boss ativo: permanece onde estiver aguardando o próximo.
                            setNoclip(false)
                        end
                    end
                end

                RunService.Heartbeat:Wait()
            end

            BossDamageHudState.BossAlive = false
            releaseNormalBossHold()
            releaseBossChestHold()
            setNoclip(false)
        end)

        Core:StartWorker("Farms.BossAttack", function(isAlive)
            local useLeftHand = true

            while isAlive() and autoFarmActive and not FarmQuestPaused do
                -- 1 soco a cada 0.1s.
                if bossCycleInArena and not bossReturnDeadline then
                    local targetPos = getBossTargetForFarm()
                    if targetPos then
                        local character = player.Character
                        local humanoid = character and character:FindFirstChildOfClass("Humanoid")

                        if humanoid and humanoid.Health > 0 then
                            local punchTool = equipPunch()
                            if punchTool then
                                pcall(function() punchTool:Activate() end)
                            end

                            local event = getMuscleEvent()
                            if event then
                                local hand = useLeftHand and "leftHand" or "rightHand"
                                pcall(function()
                                    event:FireServer("punch", hand)
                                end)
                                useLeftHand = not useLeftHand
                            end
                        end
                    end
                end

                task.wait(0.1)
            end
        end)
    end

    local function arsToggleBossNormal()
        playClickSound()
        autoFarmActive = not autoFarmActive
        ARS_PREF.bossNormal = autoFarmActive
        if autoFarmActive then ARS_PREF.bossHalloween = false end
        arsSavePrefs()
        BossDamageHudState.AutoBossEnabled = autoFarmActive
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

            startBossFarmRuntime()
        else
            BossDamageHudState.BossAlive = false
            disconnectBossDamageChecks()
            Core:StopWorker("Farms.BossPosition")
            Core:StopWorker("Farms.BossAttack")
            releaseNormalBossHold()
            setNoclip(false)

            -- Ao desligar manualmente, permanece onde estiver.
            -- Não executa jump nem RestoreFarmContext.
            resetBossCycleState()

            damageCount = 0
            currentOffsetY = 45
            btnFarm.Text = "AUTO FARM BOSS: OFF 🔴"
            btnFarm.BackgroundColor3 = Color3.fromRGB(180, 30, 30)
        end
    end
    btnFarm.MouseButton1Click:Connect(arsToggleBossNormal)
    task.delay(4, function()
        if Core:IsAlive() and ARS_PREF.bossNormal and not autoFarmActive then
            arsToggleBossNormal()
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


    --==================================================
    -- V6.0.0 // FARM CONTEXT + PAUSA/RETORNO DO AUTO QUEST
    --==================================================
    local function getPromptWorldPosition(prompt)
        if not prompt or not prompt.Parent then return nil end
        local parent = prompt.Parent
        if parent:IsA("Attachment") then
            local bp = parent.Parent
            return (bp and bp:IsA("BasePart")) and bp.Position or nil
        end
        return parent:IsA("BasePart") and parent.Position or nil
    end

    local function findNearestFarmPrompt(position, radius)
        radius = radius or 22
        local nearest, best = nil, math.huge
        for _, obj in ipairs(workspace:GetDescendants()) do
            if obj:IsA("ProximityPrompt") then
                local pos = getPromptWorldPosition(obj)
                if pos then
                    local dist = (pos - position).Magnitude
                    if dist <= radius and dist < best then
                        nearest, best = obj, dist
                    end
                end
            end
        end
        return nearest
    end

    CaptureBossReturnContext = function()
        local char = player.Character
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        local root = char and char:FindFirstChild("HumanoidRootPart")
        if not root or not hum or hum.Health <= 0 then
            return false
        end

        local tool = char:FindFirstChildOfClass("Tool")
        local nearestPrompt = findNearestFarmPrompt(root.Position, 30)

        -- O ponto de retorno do Auto Boss deve ser o local ATUAL da máquina,
        -- não o CFrame salvo quando o botão do farm foi clicado.
        FarmResumeContext.Saved = true
        FarmResumeContext.FarmName = FarmResumeContext.FarmName or "FARM ATUAL"
        FarmResumeContext.CFrame = root.CFrame
        FarmResumeContext.ToolName = tool and tool.Name or FarmResumeContext.ToolName
        FarmResumeContext.Prompt = nearestPrompt
        FarmResumeContext.SavedAt = os.clock()

        print(
            "[ARASAKA][AUTO BOSS] retorno atualizado para a maquina/local atual:",
            FarmResumeContext.FarmName,
            "| prompt:",
            nearestPrompt and nearestPrompt:GetFullName() or "nao encontrado"
        )

        return true
    end

    local function captureFarmContext(farmName)
        local char = player.Character
        local root = char and char:FindFirstChild("HumanoidRootPart")
        if not root then return end

        local tool = char:FindFirstChildOfClass("Tool")
        FarmResumeContext.Saved = true
        FarmResumeContext.FarmName = tostring(farmName or "FARM")
        FarmResumeContext.CFrame = root.CFrame
        FarmResumeContext.ToolName = tool and tool.Name or nil
        FarmResumeContext.Prompt = findNearestFarmPrompt(root.Position, 22)
        FarmResumeContext.SavedAt = os.clock()

        print(
            "[ARASAKA][FARM CONTEXT] salvo:",
            FarmResumeContext.FarmName,
            "| tool:",
            FarmResumeContext.ToolName or "nenhuma"
        )
    end

    local function pressEForFarm()
        local ok, vim = pcall(function()
            return game:GetService("VirtualInputManager")
        end)
        if not ok or not vim then return false end

        return pcall(function()
            vim:SendKeyEvent(true, Enum.KeyCode.E, false, game)
            task.wait(0.08)
            vim:SendKeyEvent(false, Enum.KeyCode.E, false, game)
        end)
    end

    local function reactivateFarmInteraction()
        local prompt = FarmResumeContext.Prompt

        if (not prompt or not prompt.Parent) and FarmResumeContext.CFrame then
            prompt = findNearestFarmPrompt(FarmResumeContext.CFrame.Position, 22)
            FarmResumeContext.Prompt = prompt
        end

        if prompt and prompt.Parent and fireproximityprompt then
            local ok = pcall(function()
                fireproximityprompt(prompt)
            end)
            if ok then return true end
        end

        return pressEForFarm()
    end

    RestoreFarmContext = function()
        if not FarmResumeContext.Saved or not FarmResumeContext.CFrame then
            return false
        end

        local char = player.Character or player.CharacterAdded:Wait()
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        local root = char and char:FindFirstChild("HumanoidRootPart")
        if not root or not hum or hum.Health <= 0 then return false end

        root.CFrame = FarmResumeContext.CFrame
        root.AssemblyLinearVelocity = Vector3.zero
        root.AssemblyAngularVelocity = Vector3.zero

        -- IMPORTANTE: após Auto Quest/Auto Boss, dá tempo para o jogo
        -- limpar o estado anterior antes de tentar subir novamente na máquina.
        print("[ARASAKA][FARM CONTEXT] aguardando 4s antes de reativar máquina...")
        task.wait(4)

        -- Garante novamente a posição exata após a espera.
        char = player.Character or char
        hum = char and char:FindFirstChildOfClass("Humanoid")
        root = char and char:FindFirstChild("HumanoidRootPart")
        if not root or not hum or hum.Health <= 0 then return false end

        root.CFrame = FarmResumeContext.CFrame
        root.AssemblyLinearVelocity = Vector3.zero
        root.AssemblyAngularVelocity = Vector3.zero

        if FarmResumeContext.ToolName then
            local backpack = player:FindFirstChild("Backpack")
            local tool = char:FindFirstChild(FarmResumeContext.ToolName)
                or (backpack and backpack:FindFirstChild(FarmResumeContext.ToolName))
            if tool and tool:IsA("Tool") and tool.Parent ~= char then
                pcall(function()
                    hum:EquipTool(tool)
                end)
            end
        end

        -- Rebusca o prompt porque algumas máquinas recriam o prompt/attachment.
        FarmResumeContext.Prompt = findNearestFarmPrompt(FarmResumeContext.CFrame.Position, 28)

        -- Igual ao início da farm: não depende de uma única tentativa.
        local activated = false
        for attempt = 1, 4 do
            if reactivateFarmInteraction() then
                activated = true
            end

            if attempt < 4 then
                task.wait(0.6)

                -- Mantém o player em cima da máquina entre as tentativas.
                local currentChar = player.Character
                local currentRoot = currentChar and currentChar:FindFirstChild("HumanoidRootPart")
                if currentRoot then
                    currentRoot.CFrame = FarmResumeContext.CFrame
                    currentRoot.AssemblyLinearVelocity = Vector3.zero
                    currentRoot.AssemblyAngularVelocity = Vector3.zero
                end
            end
        end

        print(
            "[ARASAKA][FARM CONTEXT] restaurado:",
            FarmResumeContext.FarmName or "FARM",
            "| maquina:",
            activated and "reativada" or "tentativa concluida"
        )
        return true
    end

    -- Salva o ponto ANTES do clique ligar uma farm.
    -- MouseButton1Down acontece antes do MouseButton1Click que muda OFF -> ON.
    local farmCaptureConnections = setmetatable({}, {__mode = "k"})
    local function attachFarmContextCapture(obj)
        if not obj:IsA("TextButton") or farmCaptureConnections[obj] then return end
        farmCaptureConnections[obj] = true

        local conn = obj.MouseButton1Down:Connect(function()
            local txt = tostring(obj.Text or "")
            if txt:find("OFF", 1, true) then
                captureFarmContext(txt:gsub("%s*:%s*OFF.*$", ""))
            end
        end)
        Core:TrackConnection("Farms.ContextCapture", conn)
    end

    for _, scroll in ipairs(farmScrolls) do
        for _, obj in ipairs(scroll:GetDescendants()) do
            attachFarmContextCapture(obj)
        end

        Core:TrackConnection("Farms.ContextCapture", scroll.DescendantAdded:Connect(function(obj)
            if obj:IsA("TextButton") then
                task.defer(function()
                    attachFarmContextCapture(obj)
                end)
            end
        end))
    end

    local farmPauseSnapshot = nil

    local function stopBossRuntimeForQuest()
        disconnectBossDamageChecks()
        Core:StopWorker("Farms.BossPosition")
        Core:StopWorker("Farms.BossAttack")
        setNoclip(false)
    end

    local function startBossRuntimeAfterQuest()
        if not autoFarmActive then return end

        currentOffsetY = 45
        damageCount = 0
        disconnectBossDamageChecks()
        bindBossDamageCheck()

        if damageCharacterConnection then
            damageCharacterConnection:Disconnect()
        end
        damageCharacterConnection = player.CharacterAdded:Connect(function()
            if autoFarmActive and not FarmQuestPaused then
                task.wait(0.5)
                bindBossDamageCheck()
            end
        end)

        -- Usa exatamente a mesma lógica do Auto Boss normal:
        -- mata -> coleta baú por até 15s -> volta ao local anterior.
        startBossFarmRuntime()
    end

    PauseFarmsForQuest = function()
        if FarmQuestPaused then return end
        FarmQuestPaused = true

        farmPauseSnapshot = {
            autoFarm = autoFarmActive,
            autoReps = autoRepsActive,
            unified = autoUnifiedFarmActive,
            target = targetRebirthActive,
            custom = customRebirthActive,
            overlord = overlordRebirthActive,
            farmOp = farmOpActive,
            mainStrengthOp = mainStrengthOpActive,
            travar = travarLocalActive,
        }

        for _, workerName in ipairs({
            "Farms.TargetRebirth",
            "Farms.CustomRebirth",
            "Farms.AutoReps",
            "Farms.AutoUnified",
            "Farms.TrainingWatchdog",
            "Farms.Overlord",
            "Farms.FarmOp",
            "Farms.MainStrengthOp",
        }) do
            Core:StopWorker(workerName)
        end

        if autoFarmActive then
            stopBossRuntimeForQuest()
        end

        if lockConnection then
            lockConnection:Disconnect()
            lockConnection = nil
        end

        print("[ARASAKA][AUTO QUEST] farms pausadas temporariamente.")
    end

    ResumeFarmsAfterQuest = function()
        local snapshot = farmPauseSnapshot
        FarmQuestPaused = false
        farmPauseSnapshot = nil

        if not snapshot then return end

        if snapshot.target and targetRebirthActive and startTargetRebirthWorker then
            startTargetRebirthWorker()
        end
        if snapshot.custom and customRebirthActive and startCustomRebirthWorker then
            startCustomRebirthWorker()
        end
        if snapshot.autoReps and autoRepsActive and startAutoRepsWorker then
            startAutoRepsWorker()
        end
        if snapshot.unified and autoUnifiedFarmActive and startUnifiedFarmWorker then
            startUnifiedFarmWorker()
        end
        if snapshot.overlord and overlordRebirthActive and startOverlordWorker then
            startOverlordWorker()
        end
        if snapshot.farmOp and farmOpActive and startFarmOp then
            startFarmOp()
        end
        if snapshot.mainStrengthOp and mainStrengthOpActive and startMainStrengthOp then
            startMainStrengthOp()
        end
        if snapshot.autoFarm and autoFarmActive then
            startBossRuntimeAfterQuest()
        end

        if snapshot.travar and travarLocalActive then
            local char = player.Character
            local root = char and char:FindFirstChild("HumanoidRootPart")
            lockedCFrame = root and root.CFrame or lockedCFrame
            if lockConnection then lockConnection:Disconnect() end
            lockConnection = RunService.RenderStepped:Connect(function()
                if not travarLocalActive or not Core:IsAlive() then
                    if lockConnection then lockConnection:Disconnect(); lockConnection = nil end
                    return
                end
                local c = player.Character
                local r = c and c:FindFirstChild("HumanoidRootPart")
                if r and lockedCFrame then
                    r.CFrame = lockedCFrame
                    r.AssemblyLinearVelocity = Vector3.zero
                    r.AssemblyAngularVelocity = Vector3.zero
                end
            end)
        end

        refreshTrainingWatchdog()
        print("[ARASAKA][AUTO QUEST] farms retomadas.")
    end

        Utils.PerfEnd("FARMS_UI")
    end

    function Farms:Stop()
        for _, workerName in ipairs({
            "Farms.ConfigAutosave", "Farms.TargetRebirth", "Farms.CustomRebirth",
            "Farms.AutoReps", "Farms.AutoUnified", "Farms.TrainingWatchdog", "Farms.Overlord",
            "Farms.FarmOp", "Farms.MainStrengthOp", "Farms.BossDamage", "Farms.BossPosition", "Farms.BossAttack"
        }) do
            Core:StopWorker(workerName)
        end
    end

    Core:RegisterModule("Farms", Farms)
    local farmsOk, farmsErr = Core:StartModule("Farms")
    if not farmsOk then
        warn("[ARASAKA][MODULE:Farms] Falha:", farmsErr)
        -- Erros na montagem nao devem deixar as abas silenciosamente vazias.
        for _, tab in ipairs({tabFarmForca, tabFarmRebirth, tabFarmBoss}) do
            local errLabel = Instance.new("TextLabel")
            errLabel.Name = "ArasakaFarmsError"
            errLabel.Size = UDim2.new(1, -30, 0, 72)
            errLabel.Position = UDim2.new(0, 15, 0.5, -36)
            errLabel.BackgroundColor3 = Color3.fromRGB(24, 8, 8)
            errLabel.BorderSizePixel = 0
            errLabel.TextColor3 = Color3.fromRGB(255, 120, 120)
            errLabel.TextWrapped = true
            errLabel.Font = Enum.Font.Code
            errLabel.TextSize = 12
            errLabel.Text = "ERRO NO FARM: " .. tostring(farmsErr)
            errLabel.ZIndex = 50
            errLabel.Parent = tab
        end
    end

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
        lbl.TextColor3 = Color3.fromRGB(236, 64, 88)
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
    btnSelectPetShop.BackgroundColor3 = Color3.fromRGB(33, 44, 59)
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

    CriarSecaoTitulo("🧬 Evolução Automática:", 18)

    local btnSelectEvolve = Instance.new("TextButton", petScroll)
    btnSelectEvolve.LayoutOrder = 19
    btnSelectEvolve.Size = UDim2.new(1, -6, 0, 28)
    btnSelectEvolve.BackgroundColor3 = Color3.fromRGB(33, 44, 59)
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
    btnSelectPlayer.BackgroundColor3 = Color3.fromRGB(33, 44, 59)
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
    btnSelectTradePet.BackgroundColor3 = Color3.fromRGB(33, 44, 59)
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
        local index=math.floor((posY-10)/35)+1
        local descriptions={
            {"Modo RTX", "Realca a iluminacao com brilho, raios de sol e desfoque.", Color3.fromRGB(243,211,132)},
            {"Vibe ambiente + meteoros", "Noite em tons roxos com meteoros animados no cenario.", Color3.fromRGB(191,159,255)},
            {"Modo anti-lag", "Remove texturas e sombras. Reentre no jogo para recuperar as texturas.", Color3.fromRGB(127,219,187)},
            {"Modo terror", "Atmosfera escura, tons vermelhos e audio de terror.", Color3.fromRGB(244,117,133)},
            {"Fotorrealista ultra", "Ajusta luz, sombras e efeitos para uma cena mais detalhada.", Color3.fromRGB(155,199,244)},
            {"Modo tela preta", "Cobre o jogo com fundo preto e mantem o painel acessivel.", Color3.fromRGB(187,197,215)},
        }
        local info=descriptions[index]
        local btn=Instance.new("TextButton",parent)
        btn.Size=UDim2.new(1,0,0,74)
        btn.Position=UDim2.fromOffset(0,54+(index-1)*78)
        btn.BackgroundTransparency=1
        btn.BorderSizePixel=0
        btn.AutoButtonColor=false
        -- Mantem o texto original para callbacks e notificacoes existentes.
        btn.Text=texto..": OFF 🔴"
        btn.TextTransparency=1
        local surface=Instance.new("Frame",btn)
        surface.Name="VisualCardSurface"
        surface.Size=UDim2.fromScale(1,1)
        surface.BorderSizePixel=0
        surface.BackgroundColor3=Color3.fromRGB(16,16,16)
        Instance.new("UICorner",surface).CornerRadius=UDim.new(0,8)
        local stroke=Instance.new("UIStroke",surface)
        stroke.Color=Color3.fromRGB(55,45,46)
        local accent=Instance.new("Frame",surface)
        accent.Size=UDim2.new(0,3,1,-20);accent.Position=UDim2.fromOffset(0,10)
        accent.BorderSizePixel=0;accent.BackgroundColor3=info[3]
        local name=Instance.new("TextLabel",surface)
        name.BackgroundTransparency=1;name.Position=UDim2.fromOffset(14,9);name.Size=UDim2.new(1,-125,0,24)
        name.Text=info[1];name.TextColor3=info[3];name.Font=Enum.Font.GothamBold;name.TextSize=15;name.TextXAlignment=Enum.TextXAlignment.Left
        local description=Instance.new("TextLabel",surface)
        description.BackgroundTransparency=1;description.Position=UDim2.fromOffset(14,31);description.Size=UDim2.new(1,-125,0,38)
        description.Text=info[2];description.TextColor3=Color3.fromRGB(220,220,220);description.Font=Enum.Font.GothamMedium;description.TextSize=13
        description.TextXAlignment=Enum.TextXAlignment.Left;description.TextWrapped=true
        local state=Instance.new("TextLabel",surface)
        state.Name="VisualCardState"
        state.BackgroundTransparency=1;state.Size=UDim2.fromOffset(86,24);state.Position=UDim2.new(1,-100,.5,-12)
        state.Font=Enum.Font.GothamBold;state.TextSize=13;state.TextXAlignment=Enum.TextXAlignment.Right
        local function updateCard()
            local enabled=btn.Text:find("%f[%a]ON%f[%A]")~=nil
            surface.BackgroundColor3=enabled and Color3.fromRGB(39,21,24) or Color3.fromRGB(16,16,16)
            stroke.Color=enabled and info[3] or Color3.fromRGB(55,45,46)
            state.Text=enabled and "LIGADO" or "DESLIGADO"
            state.TextColor3=enabled and Color3.fromRGB(99,216,178) or Color3.fromRGB(230,230,230)
        end
        Core:TrackConnection("UI",btn:GetPropertyChangedSignal("Text"):Connect(updateCard))
        updateCard()
        return btn
    end

    local btnRTX = CriarBotaoVisual(UI.VisualControlsContainer or tabVisual, "MODO RTX 🌟", 10)
    local btnVibe = CriarBotaoVisual(UI.VisualControlsContainer or tabVisual, "VIBE AMBIENTE + METEORES 🌌", 45)
    local btnAntiLag = CriarBotaoVisual(UI.VisualControlsContainer or tabVisual, "MODO ANTI-LAG ⚡", 80)
    local btnTerror = CriarBotaoVisual(UI.VisualControlsContainer or tabVisual, "MODO TERROR 🩸", 115)
    local btnFotorealista = CriarBotaoVisual(UI.VisualControlsContainer or tabVisual, "MODO FOTORREALISTA ULTRA 📸", 150)
    local btnBlackScreen = CriarBotaoVisual(UI.VisualControlsContainer or tabVisual, "MODO TELA PRETA 🖤", 185)

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
                label.TextColor3 = Color3.fromRGB(236, 64, 88)
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
    outrosScroll.Size = UDim2.new(1, -20, 0, 215)
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


    -- Preferencia local: mobile inicia em GRANDE, desktop permanece NORMAL.
    -- Nao modifica frame.Size, uiScale nem as velocidades dos farms.
    local sizeButton = Instance.new("TextButton", outrosScroll)
    sizeButton.Name = "ArasakaOptionSizeButton"
    sizeButton.LayoutOrder = 0
    sizeButton.Size = UDim2.new(1, -6, 0, 36)
    sizeButton.BackgroundColor3 = Color3.fromRGB(35, 25, 38)
    sizeButton.BorderSizePixel = 0
    sizeButton.TextColor3 = Color3.fromRGB(245, 225, 225)
    sizeButton.Font = Enum.Font.GothamBold
    sizeButton.TextSize = 13
    Instance.new("UICorner", sizeButton).CornerRadius = UDim.new(0, 6)
    local sizeNames = {"NORMAL", "GRANDE", "EXTRA GRANDE"}
    local function refreshSizeButton()
        sizeButton.Text = "TAMANHO DAS OPÇÕES: " .. sizeNames[ArasakaOptionSizing.Mode]
    end
    Core:TrackConnection("UI", sizeButton.MouseButton1Click:Connect(function()
        playClickSound()
        ArasakaOptionSizing:SetMode(ArasakaOptionSizing.Mode % 3 + 1)
        refreshSizeButton()
    end))
    refreshSizeButton()
    ArasakaOptionSizing:Start()

    local btnSpinWheel = CriarBotaoOutros("GIRAR ROLETA 🎰", 1)
    local btnEatAllBoosts = CriarBotaoOutros("USAR TODOS OS BOOSTS 💊", 2)
    local btnServerHop = CriarBotaoOutros("SERVIDOR COM MENOS PESSOAS 🌐", 3)
    local btnRejoin = CriarBotaoOutros("REJOIN 🔄", 4)
    local btnMelhorPing = CriarBotaoOutros("PROCURAR MELHOR PING 📡", 5)

]====]
