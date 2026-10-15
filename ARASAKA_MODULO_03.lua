-- ARASAKA GRATIS / MODULO DE FONTE / PARTE 3 DE 6
return [====[    local function getAvatarUrl(uId)
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

    local function escapeRichText(texto)
        texto = tostring(texto or "")
        texto = texto:gsub("&", "&amp;")
        texto = texto:gsub("<", "&lt;")
        texto = texto:gsub(">", "&gt;")
        return texto
    end

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
        msgLabel.Text = '<font color="#d73232"><b>@' .. escapeRichText(autor) .. ':</b></font> ' .. escapeRichText(texto)
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
                local first = string.find(rawMsg, "||", 1, true)
                local second = first and string.find(rawMsg, "||", first + 2, true) or nil
                if first and second then
                    local autor = string.sub(rawMsg, 1, first - 1)
                    local avatar = string.sub(rawMsg, first + 2, second - 1)
                    local texto = string.sub(rawMsg, second + 2)
                    if not string.find(autor, "PING", 1, true)
                        and not string.find(texto, "PING", 1, true)
                        and autor ~= "ONLINE_COUNT"
                        and autor ~= "[SISTEMA]" then
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
            local textoOriginal = tostring(textBox.Text)
            if #textoOriginal > 1000 then
                textoOriginal = string.sub(textoOriginal, 1, 1000)
            end
            ws:Send(player.Name .. "||" .. myThumbUrl .. "||" .. textoOriginal)
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
-- BEGIN ARASAKA VISUAL STYLES (isolated UI module)
function UI:BuildArasakaStyles(tab)
    local world=game:GetService("Workspace")
    local owner="UI.ArasakaStyles"
    local savedMaterials=setmetatable({}, {__mode="k"})
    local savedLighting=nil
    local mutedEffects={}
    local ownedEffects={}
    local generation=0
    local activeMaterial=nil
    local activeIndex=nil
    local destroyed=false
    local buttons={}
    local properties={"Ambient","OutdoorAmbient","Brightness","GlobalShadows","ClockTime"}
    local function eligible(part)
        if not part:IsA("BasePart") or part.Transparency>=1 then return false end
        local ancestor=part.Parent
        while ancestor and ancestor~=world do
            if ancestor:IsA("Tool") or (ancestor:IsA("Model") and ancestor:FindFirstChildOfClass("Humanoid")) then return false end
            ancestor=ancestor.Parent
        end
        return ancestor==world
    end
    local function restoreMaterials()
        for part,data in pairs(savedMaterials) do
            if part.Parent then pcall(function()
                part.Material=data.material
                part.MaterialVariant=data.variant
                part.CustomPhysicalProperties=data.physics
            end) end
        end
        table.clear(savedMaterials)
    end
    local function clearOwned()
        for _,effect in ipairs(ownedEffects) do effect:Destroy() end
        table.clear(ownedEffects)
    end
    local function restore()
        generation=generation+1
        activeIndex=nil; activeMaterial=nil
        clearOwned()
        restoreMaterials()
        if savedLighting then
            for property,value in pairs(savedLighting) do pcall(function() Lighting[property]=value end) end
            savedLighting=nil
        end
        for effect,enabled in pairs(mutedEffects) do
            if effect.Parent then pcall(function() effect.Enabled=enabled end) end
        end
        table.clear(mutedEffects)
    end
    local function effect(class,values)
        local obj=Instance.new(class)
        obj.Name="ArasakaStyle_"..class
        for property,value in pairs(values) do obj[property]=value end
        obj.Parent=Lighting
        table.insert(ownedEffects,obj)
    end
    local function paint(part)
        if not activeMaterial or not eligible(part) then return end
        pcall(function()
            if not savedMaterials[part] then
                savedMaterials[part]={material=part.Material,variant=part.MaterialVariant,physics=part.CustomPhysicalProperties}
            end
            -- Mantem atrito/densidade enquanto altera o acabamento visual.
            local physics=part.CurrentPhysicalProperties
            part.CustomPhysicalProperties=physics
            part.Material=activeMaterial
            part.MaterialVariant=""
        end)
    end
    local styles={
        {name="Realista / PBR",description="Luz de tarde, raios de sol e foco suave. Mantem os materiais.",color=Color3.fromRGB(218,223,235),time=15,brightness=3,
         effects={{"SunRaysEffect",{Intensity=.15,Spread=.6}},{"DepthOfFieldEffect",{FocusDistance=50,InFocusRadius=30,NearIntensity=.1,FarIntensity=.15}},{"Atmosphere",{Density=.25,Color=Color3.fromRGB(200,200,210)}}}},
        {name="Inverno Rigoroso",description="Gelo, tons frios e neblina azul.",color=Color3.fromRGB(150,200,255),material=Enum.Material.Ice,time=8,ambient=Color3.fromRGB(150,200,255),
         effects={{"ColorCorrectionEffect",{TintColor=Color3.fromRGB(200,230,255),Saturation=-.4}},{"Atmosphere",{Density=.6,Color=Color3.fromRGB(200,230,255),Haze=3}}}},
        {name="Dark Fantasy",description="Pedra escura, noite e atmosfera sombria.",color=Color3.fromRGB(159,188,158),material=Enum.Material.Slate,time=0,ambient=Color3.fromRGB(20,30,25),outdoor=Color3.fromRGB(10,15,12),
         effects={{"ColorCorrectionEffect",{Saturation=-.6,Contrast=.3,TintColor=Color3.fromRGB(150,170,150)}},{"Atmosphere",{Density=.8,Color=Color3.fromRGB(20,30,25)}}}},
        {name="Velho Oeste (Sepia)",description="Areia, por do sol e cores quentes.",color=Color3.fromRGB(230,175,117),material=Enum.Material.Sand,time=17,ambient=Color3.fromRGB(150,100,50),
         effects={{"ColorCorrectionEffect",{TintColor=Color3.fromRGB(255,200,150),Saturation=-.2,Contrast=.2}},{"SunRaysEffect",{Intensity=.3,Spread=.8}}}},
        {name="Apocalipse Toxico",description="Metal oxidado, contraste forte e neblina verde.",color=Color3.fromRGB(153,235,104),material=Enum.Material.CorrodedMetal,time=12,ambient=Color3.fromRGB(30,80,30),
         effects={{"ColorCorrectionEffect",{TintColor=Color3.fromRGB(180,255,180),Contrast=.4,Saturation=.5}},{"Atmosphere",{Density=.65,Color=Color3.fromRGB(50,150,50),Haze=5}}}},
        {name="Dreamcore (Surreal)",description="Acabamento de brinquedo, tons rosa e brilho intenso.",color=Color3.fromRGB(255,161,221),material=Enum.Material.SmoothPlastic,time=14,
         effects={{"ColorCorrectionEffect",{TintColor=Color3.fromRGB(255,210,255),Saturation=1,Contrast=-.1}},{"BloomEffect",{Intensity=1.5,Size=40}}}},
    }
    local scroll=Instance.new("ScrollingFrame")
    scroll.Name="ArasakaVisualStyles"; scroll.Size=UDim2.new(1,-24,1,-12); scroll.Position=UDim2.fromOffset(12,6)
    scroll.BackgroundTransparency=1; scroll.BorderSizePixel=0; scroll.ScrollBarThickness=4
    scroll.ScrollBarImageColor3=Color3.fromRGB(236,64,88); scroll.CanvasSize=UDim2.new(); scroll.AutomaticCanvasSize=Enum.AutomaticSize.Y
    scroll.Parent=tab
    local list=Instance.new("UIListLayout",scroll);list.Padding=UDim.new(0,8);list.SortOrder=Enum.SortOrder.LayoutOrder
    local function label(parent,text,size,pos,font,color)
        local obj=Instance.new("TextLabel");obj.BackgroundTransparency=1;obj.Text=text;obj.Size=size;obj.Position=pos
        obj.Font=font;obj.TextColor3=color;obj.TextSize=13;obj.TextXAlignment=Enum.TextXAlignment.Left;obj.Parent=parent
        return obj
    end
    -- Os controles visuais existentes compartilham a mesma rolagem dos presets.
    local legacy=Instance.new("Frame",scroll)
    legacy.Name="ExistingVisualControls"
    legacy.LayoutOrder=0
    legacy.Size=UDim2.new(1,-8,0,522)
    legacy.BackgroundTransparency=1
    self.VisualControlsContainer=legacy
    local effectsTitle=Instance.new("TextLabel",legacy)
    effectsTitle.BackgroundTransparency=1;effectsTitle.Size=UDim2.new(1,0,0,24)
    effectsTitle.Text="EFEITOS VISUAIS";effectsTitle.TextColor3=Color3.fromRGB(242,245,251)
    effectsTitle.Font=Enum.Font.GothamBold;effectsTitle.TextSize=17;effectsTitle.TextXAlignment=Enum.TextXAlignment.Left
    local effectsHint=Instance.new("TextLabel",legacy)
    effectsHint.BackgroundTransparency=1;effectsHint.Position=UDim2.fromOffset(0,25);effectsHint.Size=UDim2.new(1,0,0,22)
    effectsHint.Text="Clique no cartao para ligar ou desligar o efeito."
    effectsHint.TextColor3=Color3.fromRGB(205,205,205);effectsHint.Font=Enum.Font.Gotham;effectsHint.TextSize=13
    effectsHint.TextXAlignment=Enum.TextXAlignment.Left
    local header=Instance.new("Frame",tab);header.Visible=false;header.LayoutOrder=1;header.Size=UDim2.new(1,-8,0,74);header.BackgroundTransparency=1
    local heading=label(header,"ESTILOS VISUAIS",UDim2.new(1,0,0,24),UDim2.fromOffset(0,0),Enum.Font.GothamBold,Color3.fromRGB(242,245,251));heading.TextSize=17
    local hint=label(header,"Escolha um estilo. Clique no ativo para voltar ao original.",UDim2.new(1,0,0,32),UDim2.fromOffset(0,25),Enum.Font.Gotham,Color3.fromRGB(205,205,205));hint.TextWrapped=true
    local status=label(header,"Original ativo",UDim2.new(1,0,0,16),UDim2.fromOffset(0,58),Enum.Font.GothamMedium,Color3.fromRGB(99,216,178));status.TextSize=11
    local function refresh()
        for index,data in ipairs(buttons) do
            local selected=activeIndex==index
            data.card.BackgroundColor3=selected and Color3.fromRGB(42,20,23) or Color3.fromRGB(16,16,16)
            data.indicator.Text=selected and "ATIVO" or "APLICAR"
            data.indicator.TextColor3=selected and Color3.fromRGB(99,216,178) or Color3.fromRGB(230,230,230)
            data.stroke.Color=selected and styles[index].color or Color3.fromRGB(55,45,46)
        end
    end
    local function apply(index)
        if destroyed then return end
        if activeIndex==index then restore();status.Text="Original restaurado";refresh();Core:Notify("VISUAL", "Visual original restaurado.", 2);return end
        restore()
        local preset=styles[index]
        savedLighting={}
        for _,property in ipairs(properties) do savedLighting[property]=Lighting[property] end
        for _,existing in ipairs(Lighting:GetChildren()) do
            if existing:IsA("PostEffect") then mutedEffects[existing]=existing.Enabled;existing.Enabled=false end
        end
        local ok,err=pcall(function()
            Lighting.Ambient=preset.ambient or Color3.fromRGB(128,128,128)
            Lighting.OutdoorAmbient=preset.outdoor or Color3.fromRGB(128,128,128)
            Lighting.Brightness=preset.brightness or 2;Lighting.GlobalShadows=true;Lighting.ClockTime=preset.time
            for _,entry in ipairs(preset.effects) do
                if entry[1]=="Atmosphere" then
                    -- Uma Atmosphere existente pode prevalecer; use a mesma instancia e restaure seus valores.
                    local existing=Lighting:FindFirstChildOfClass("Atmosphere")
                    if existing then
                        local backup={}
                        for property,value in pairs(entry[2]) do backup[property]=existing[property];existing[property]=value end
                        Core:AddCleanup(owner.."Atmosphere",function()
                            if existing.Parent then for property,value in pairs(backup) do existing[property]=value end end
                        end)
                    else effect(entry[1],entry[2]) end
                else effect(entry[1],entry[2]) end
            end
        end)
        if not ok then restore();Core:CleanupOwner(owner.."Atmosphere");status.Text="Nao foi possivel aplicar. Visual restaurado.";warn(err);refresh();return end
        activeIndex=index;activeMaterial=preset.material
        Core:Notify("VISUAL", preset.name.." ativado.", 2)
        status.Text="Ativo: "..preset.name
        refresh()
        if not activeMaterial then return end
        local token=generation
        task.spawn(function()
            for i,part in ipairs(world:GetDescendants()) do
                if destroyed or token~=generation then return end
                paint(part)
                if i%180==0 then task.wait() end
            end
        end)
    end
    -- Restaura a atmosfera junto de qualquer troca/desativacao.
    local restoreBase=restore
    restore=function() restoreBase();Core:CleanupOwner(owner.."Atmosphere") end
    for index,preset in ipairs(styles) do
        local card=Instance.new("TextButton",scroll);card.Name="Style_"..index;card.LayoutOrder=index+1;card.Size=UDim2.new(1,-8,0,84)
        card.Text="";card.AutoButtonColor=false;card.BorderSizePixel=0;card.BackgroundColor3=Color3.fromRGB(16,16,16)
        Instance.new("UICorner",card).CornerRadius=UDim.new(0,8)
        local stroke=Instance.new("UIStroke",card);stroke.Color=Color3.fromRGB(55,45,46)
        local accent=Instance.new("Frame",card);accent.Size=UDim2.new(0,3,1,-20);accent.Position=UDim2.fromOffset(0,10);accent.BorderSizePixel=0;accent.BackgroundColor3=preset.color
        local name=label(card,preset.name,UDim2.new(1,-125,0,24),UDim2.fromOffset(14,9),Enum.Font.GothamBold,preset.color);name.TextSize=15
        local desc=label(card,preset.description,UDim2.new(1,-125,0,43),UDim2.fromOffset(14,33),Enum.Font.GothamMedium,Color3.fromRGB(220,220,220));desc.TextSize=13;desc.TextWrapped=true
        local indicator=label(card,"APLICAR",UDim2.fromOffset(78,24),UDim2.new(1,-92,.5,-12),Enum.Font.GothamBold,Color3.fromRGB(230,230,230));indicator.TextSize=13;indicator.TextXAlignment=Enum.TextXAlignment.Right
        buttons[index]={card=card,stroke=stroke,indicator=indicator}
        Core:TrackConnection(owner,card.Activated:Connect(function() apply(index) end))
    end
    local reset=Instance.new("TextButton",scroll);reset.LayoutOrder=9;reset.Size=UDim2.new(1,-8,0,38);reset.Text="RESTAURAR VISUAL ORIGINAL";reset.Font=Enum.Font.GothamBold;reset.TextSize=13;reset.TextColor3=Color3.fromRGB(240,243,248);reset.BackgroundColor3=Color3.fromRGB(24,24,24);reset.BorderSizePixel=0
    Instance.new("UICorner",reset).CornerRadius=UDim.new(0,7)
    Core:TrackConnection(owner,reset.Activated:Connect(function() restore();status.Text="Original restaurado";refresh();Core:Notify("VISUAL", "Visual original restaurado.", 2) end))
    Core:TrackConnection(owner,world.DescendantAdded:Connect(function(obj)
        if activeMaterial then task.defer(function() if not destroyed and activeMaterial and obj.Parent then paint(obj) end end) end
    end))
    Core:AddCleanup(owner,function() destroyed=true;restore() end)
    Core:TrackConnection("UI",tab.Destroying:Connect(function() Core:CleanupOwner(owner) end))
end
-- END ARASAKA VISUAL STYLES

function UI:Start()
    Core:AddCleanup("UI", function() ArasakaI18n:Stop() end)
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

    -- INTERFACE PRINCIPAL V4 / CLAREZA E CONTRASTE
    local frame = Instance.new("Frame", screenGui)
    frame.AnchorPoint = Vector2.new(0.5, 0.5)
    frame.Size = UDim2.new(0, 820, 0, 520)
    frame.Position = UDim2.new(0.5, 0, 0.5, 0)
    frame.BackgroundColor3 = Color3.fromRGB(6, 6, 6)
    frame.BorderSizePixel = 0
    frame.Active, frame.Draggable = true, true
    frame.ClipsDescendants = true
    Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 10)

    local uiStrokeMain = Instance.new("UIStroke", frame)
    uiStrokeMain.Color = Color3.fromRGB(66, 36, 39)
    uiStrokeMain.Thickness = 1

    local topRed = Instance.new("Frame", frame)
    topRed.Size = UDim2.new(1, 0, 0, 3)
    topRed.BackgroundColor3 = Color3.fromRGB(236, 64, 88)
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
    titleBar.BackgroundColor3 = Color3.fromRGB(10, 10, 10)
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
    titleText.TextColor3 = Color3.fromRGB(244, 247, 252)
    titleText.Font = Enum.Font.GothamBlack
    titleText.TextSize = 18
    titleText.TextXAlignment = Enum.TextXAlignment.Left

    local subtitleText = Instance.new("TextLabel", titleBar)
    subtitleText.Size = UDim2.new(0, 360, 0, 16)
    subtitleText.Position = UDim2.new(0, 58, 0, 30)
    subtitleText.BackgroundTransparency = 1
    subtitleText.Text = "GRATIS  /  PAINEL DE CONTROLE"
    subtitleText.TextColor3 = Color3.fromRGB(236, 64, 88)
    subtitleText.Font = Enum.Font.GothamMedium
    subtitleText.TextSize = 13
    subtitleText.TextXAlignment = Enum.TextXAlignment.Left

    local onlineText = Instance.new("TextLabel", titleBar)
    onlineText.Size = UDim2.new(0, 190, 0, 20)
    onlineText.Position = UDim2.new(1, -250, 0, 7)
    onlineText.BackgroundTransparency = 1
    onlineText.Text = "● ONLINE"
    onlineText.TextColor3 = Color3.fromRGB(236, 64, 88)
    onlineText.Font = Enum.Font.GothamBold
    onlineText.TextSize = 12
    onlineText.TextXAlignment = Enum.TextXAlignment.Right

    local userText = Instance.new("TextLabel", titleBar)
    userText.Size = UDim2.new(0, 235, 0, 18)
    userText.Position = UDim2.new(1, -295, 0, 29)
    userText.BackgroundTransparency = 1
    userText.Text = "UID: " .. tostring(player.UserId)
    userText.TextColor3 = Color3.fromRGB(230, 230, 230)
    userText.Font = Enum.Font.GothamMedium
    userText.TextSize = 12
    userText.TextXAlignment = Enum.TextXAlignment.Right

    local btnMinimizar = Instance.new("TextButton", titleBar)
    btnMinimizar.Size = UDim2.new(0, 30, 0, 30)
    btnMinimizar.Position = UDim2.new(1, -38, 0.5, -15)
    btnMinimizar.BackgroundColor3 = Color3.fromRGB(21, 21, 21)
    btnMinimizar.BorderSizePixel = 0
    btnMinimizar.Text = "—"
    btnMinimizar.TextColor3 = Color3.fromRGB(236, 64, 88)
    btnMinimizar.Font = Enum.Font.GothamBold
    btnMinimizar.TextSize = 16
    Instance.new("UICorner", btnMinimizar).CornerRadius = UDim.new(0, 3)
    local minStroke = Instance.new("UIStroke", btnMinimizar)
    minStroke.Color = Color3.fromRGB(55, 55, 55)
    minStroke.Thickness = 1

    local separator = Instance.new("Frame", frame)
    separator.Size = UDim2.new(1, -32, 0, 1)
    separator.Position = UDim2.new(0, 16, 0, 55)
    separator.BackgroundColor3 = Color3.fromRGB(48, 40, 40)
    separator.BorderSizePixel = 0

    local sidebar = Instance.new("ScrollingFrame", frame)
    sidebar.Size = UDim2.new(0, 155, 1, -57)
    sidebar.Position = UDim2.new(0, 0, 0, 57)
    sidebar.BackgroundColor3 = Color3.fromRGB(8, 8, 8)
    sidebar.BorderSizePixel = 0
    sidebar.CanvasSize = UDim2.new(0, 0, 0, 0)
    sidebar.ScrollingDirection = Enum.ScrollingDirection.Y
    sidebar.ScrollBarThickness = 4
    sidebar.ScrollBarImageColor3 = Color3.fromRGB(115, 25, 25)
    sidebar.ScrollBarImageTransparency = 0.15
    sidebar.ElasticBehavior = Enum.ElasticBehavior.WhenScrollable
    sidebar.ScrollingEnabled = true
    sidebar.Active = true

    local sideAccent = Instance.new("Frame", sidebar)
    sideAccent.Size = UDim2.new(0, 2, 1, 0)
    sideAccent.Position = UDim2.new(1, -2, 0, 0)
    sideAccent.BackgroundColor3 = Color3.fromRGB(70, 10, 10)
    sideAccent.BorderSizePixel = 0

    local sideHeader = Instance.new("TextLabel", sidebar)
    sideHeader.Size = UDim2.new(1, -24, 0, 28)
    sideHeader.Position = UDim2.new(0, 12, 0, 12)
    sideHeader.BackgroundTransparency = 1
    sideHeader.Text = "NAVEGACAO"
    -- LANGUAGE SWITCHER: tap/click to cycle PT > EN > ES > FR > DE > RU > JA.
    -- Preserves ON/OFF markers used by the existing toggle controller.
    sideHeader.Size = UDim2.new(1, -78, 0, 28)
    sideHeader.TextScaled = true
    local langButton = Instance.new("TextButton", sidebar)
    langButton.Name = "ArasakaLanguageButton"
    langButton.Size = UDim2.new(0, 56, 0, 25)
    langButton.Position = UDim2.new(1, -60, 0, 12)
    langButton.BackgroundColor3 = Color3.fromRGB(30, 10, 16)
    langButton.BorderSizePixel = 0
    langButton.TextColor3 = Color3.fromRGB(240, 96, 109)
    langButton.TextSize = 11
    langButton.Font = Enum.Font.GothamBold
    langButton.Text = "🌐 " .. string.upper(ArasakaI18n.Language)
    langButton.AutoButtonColor = true
    Instance.new("UICorner", langButton).CornerRadius = UDim.new(0, 6)
    langButton.MouseButton1Click:Connect(function()
        local chosen = ArasakaI18n:NextLanguage()
        langButton.Text = "🌐 " .. string.upper(chosen)
        Core:Notify("ARASAKA", "Language / Idioma: " .. string.upper(chosen), 2)
    end)

    sideHeader.TextColor3 = Color3.fromRGB(190, 190, 190)
    sideHeader.Font = Enum.Font.Code
    sideHeader.TextSize = 12
    sideHeader.TextXAlignment = Enum.TextXAlignment.Left

    local sideLine = Instance.new("Frame", sidebar)
    sideLine.Size = UDim2.new(1, -24, 0, 1)
    sideLine.Position = UDim2.new(0, 12, 0, 38)
    sideLine.BackgroundColor3 = Color3.fromRGB(48, 40, 40)
    sideLine.BorderSizePixel = 0

    local nextTabY = 48

    local contentArea = Instance.new("Frame", frame)
    contentArea.Size = UDim2.new(1, -155, 1, -57)
    contentArea.Position = UDim2.new(0, 155, 0, 57)
    contentArea.BackgroundColor3 = Color3.fromRGB(6, 6, 6)
    contentArea.BorderSizePixel = 0

    local contentGlow = Instance.new("Frame", contentArea)
    contentGlow.Size = UDim2.new(1, 0, 0, 1)
    contentGlow.Position = UDim2.new(0, 0, 0, 0)
    contentGlow.BackgroundColor3 = Color3.fromRGB(236, 64, 88)
    contentGlow.BackgroundTransparency = 0.35
    contentGlow.BorderSizePixel = 0

    local contentCode = Instance.new("TextLabel", contentArea)
    contentCode.Size = UDim2.new(1, -24, 0, 16)
    contentCode.Position = UDim2.new(0, 12, 1, -22)
    contentCode.BackgroundTransparency = 1
    contentCode.Text = "INSERT  /  MOSTRAR OU OCULTAR PAINEL"
    contentCode.TextColor3 = Color3.fromRGB(165, 165, 165)
    contentCode.Font = Enum.Font.Code
    contentCode.TextSize = 10
    contentCode.TextXAlignment = Enum.TextXAlignment.Left

    -- Icones separados dos titulos: mantem os emojis visiveis ao usar Gotham nos textos.
    local tabIcons = {
        ["Início"] = "🏠", ["Farm Força"] = "💪", ["Farm Rebirth"] = "🔄",
        ["Farm Boss"] = "👑", ["Halloween"] = "🎃", ["Encantamentos"] = "📖", ["Teleportes"] = "📍",
        ["Pets"] = "🐾", ["Visual"] = "🎨", ["Outros"] = "⚙️",
        ["Kill"] = "⚔️", ["Chat"] = "💬", ["Calculadora"] = "🧮",
        ["Avisos"] = "📢", ["Teste Boss"] = "🧪",
    }

    local abas = {}
    local function CriarAba(nome, textoExibido)
        local tabBtn = Instance.new("TextButton", sidebar)
        tabBtn.Size = UDim2.new(0, 133, 0, 34)
        tabBtn.AutoButtonColor = false
        tabBtn.Position = UDim2.new(0, 11, 0, nextTabY)
        nextTabY = nextTabY + 40
        sidebar.CanvasSize = UDim2.new(0, 0, 0, nextTabY + 12)
        tabBtn.BackgroundColor3 = Color3.fromRGB(17, 17, 17)
        tabBtn.BorderSizePixel = 0
        tabBtn.Text = ""
        tabBtn.TextColor3 = Color3.fromRGB(212, 212, 212)
        tabBtn.Font = Enum.Font.GothamBold
        tabBtn.TextSize = 12
        tabBtn.TextXAlignment = Enum.TextXAlignment.Left
        Instance.new("UICorner", tabBtn).CornerRadius = UDim.new(0, 7)

        -- O icone tem seu proprio TextLabel e fonte: evita sumir/trocar de fonte
        -- quando um botao muda de estado. O nome continua no Gotham do Arasaka.
        local iconLabel = Instance.new("TextLabel", tabBtn)
        iconLabel.Name = "ArasakaTabIcon"
        iconLabel.BackgroundTransparency = 1
        iconLabel.Position = UDim2.fromOffset(7, 0)
        iconLabel.Size = UDim2.new(0, 24, 1, 0)
        iconLabel.Font = Enum.Font.SourceSans
        iconLabel.Text = tabIcons[nome] or "✦"
        iconLabel.TextSize = 20
        iconLabel.TextColor3 = Color3.fromRGB(236, 64, 88)
        iconLabel.TextXAlignment = Enum.TextXAlignment.Center
        iconLabel.ZIndex = tabBtn.ZIndex + 1

        local titleLabel = Instance.new("TextLabel", tabBtn)
        titleLabel.Name = "ArasakaTabTitle"
        titleLabel.BackgroundTransparency = 1
        titleLabel.Position = UDim2.fromOffset(34, 0)
        titleLabel.Size = UDim2.new(1, -37, 1, 0)
        titleLabel.Text = textoExibido or string.upper(nome)
        titleLabel.TextColor3 = Color3.fromRGB(212, 212, 212)
        titleLabel.Font = Enum.Font.GothamBold
        titleLabel.TextSize = #titleLabel.Text >= 12 and 11 or 12
        titleLabel.TextXAlignment = Enum.TextXAlignment.Left
        titleLabel.TextTruncate = Enum.TextTruncate.AtEnd
        titleLabel.ZIndex = tabBtn.ZIndex + 1


        local tabLine = Instance.new("Frame", tabBtn)
        tabLine.Name = "ActiveLine"
        tabLine.Size = UDim2.new(0, 2, 0.65, 0)
        tabLine.Position = UDim2.new(0, 0, 0.175, 0)
        tabLine.BackgroundColor3 = Color3.fromRGB(236, 64, 88)
        tabLine.BorderSizePixel = 0
        tabLine.Visible = false

        local tabContent = Instance.new("Frame", contentArea)
        tabContent.Size = UDim2.new(1, 0, 1, 0)
        tabContent.BackgroundTransparency = 1
        tabContent.Visible = false

        abas[nome] = {btn = tabBtn, container = tabContent, line = tabLine, title = titleLabel}

        tabBtn.MouseEnter:Connect(function()
            if not tabContent.Visible then
                TweenService:Create(tabBtn, TweenInfo.new(0.12), {BackgroundColor3 = Color3.fromRGB(29, 19, 21)}):Play()
            end
        end)
        tabBtn.MouseLeave:Connect(function()
            if not tabContent.Visible then
                TweenService:Create(tabBtn, TweenInfo.new(0.12), {BackgroundColor3 = Color3.fromRGB(17, 17, 17)}):Play()
            end
        end)

        tabBtn.MouseButton1Click:Connect(function()
            playClickSound()
            for _, tab in pairs(abas) do
                tab.container.Visible = false
                tab.btn.BackgroundColor3 = Color3.fromRGB(17, 17, 17)
                tab.btn.TextColor3 = Color3.fromRGB(212, 212, 212)
                tab.title.TextColor3 = Color3.fromRGB(212, 212, 212)
                if tab.line then tab.line.Visible = false end
            end
            tabContent.Visible = true
            tabBtn.BackgroundColor3 = Color3.fromRGB(45, 15, 18)
            tabBtn.TextColor3 = Color3.fromRGB(245, 245, 245)
            titleLabel.TextColor3 = Color3.fromRGB(245, 245, 245)
            tabLine.Visible = true
        end)
        return tabContent
    end

    -- Abas removidas do menu gratis. Containers ocultos preservam referencias
    -- internas usadas pelos modulos existentes, sem criar botoes de navegacao.
    local function CriarContainerOculto(nome)
        local container = Instance.new("Frame")
        container.Name = "RemovedTab_" .. nome
        container.BackgroundTransparency = 1
        container.Size = UDim2.fromScale(1, 1)
        container.Visible = false
        container.Parent = contentArea
        return container
    end

    local tabInicio = CriarAba("Início", "INICIO")
    local tabFarmForca = CriarAba("Farm Força", "FARM FORCA")
    local tabFarmRebirth = CriarAba("Farm Rebirth", "FARM REBIRTH")
    local tabFarmBoss = CriarAba("Farm Boss", "FARM BOSS")
    local tabHalloween = CriarAba("Halloween", "HALLOWEEN")
    local tabTeleports = CriarAba("Teleportes", "TELEPORTES")
    local tabPets = CriarContainerOculto("Pets")
    local tabVisual = CriarAba("Visual", "VISUAL")
    UI:BuildArasakaStyles(tabVisual)
    local tabOutros = CriarAba("Outros", "OUTROS")

    --==================================================
    -- ARASAKA HALLOWEEN 2026 // EVENT BOSSES, PREMIUM + FREE
    -- Isolado da BossArena; nenhum sistema de crystal/pets.
    -- Worker criado somente no ON; OFF invalida geracao e libera estado.
    --==================================================
    do
        local HWINames = {"Frankenbrute", "Pumpkin Titan", "Grim Reaper", "Scarecrow Colossus"}
        -- Perfis fixos do evento, sem edicao por UI ou preferencias antigas.
        local HWProfiles = {
            ["Frankenbrute"] = {height=75},
            ["Pumpkin Titan"] = {height=75},
            ["Grim Reaper"] = {height=75},
            ["Scarecrow Colossus"] = {height=75},
        }
        -- Gratuito permanente: sem prazo de 24 horas nem exigencia de key/UID.
        -- Nenhum servidor externo libera ou bloqueia o evento.
        -- Protecao do premium V7 permanece exclusivamente no backend Premium.
        local function hwEventIsActive()
            return true -- disponibilidade depende apenas do evento existir no jogo
        end

        local HWState = {
            enabled = false, selected = {}, origin = nil, savedTool = nil,
            target = nil, returning = false, generation = 0,
        }
        for _, name in ipairs(HWINames) do
            local chosen = ARS_PREF.halloweenSelected[name]
            HWState.selected[name] = type(chosen) == "boolean" and chosen or true
        end

        local HWWrap = Instance.new("ScrollingFrame", tabHalloween)
        HWWrap.Name = "HalloweenBossList"
        HWWrap.Position = UDim2.fromOffset(10, 10)
        HWWrap.Size = UDim2.new(1, -20, 1, -20)
        HWWrap.BackgroundTransparency = 1
        HWWrap.BorderSizePixel = 0
        HWWrap.ScrollBarThickness = 4
        HWWrap.ScrollingDirection = Enum.ScrollingDirection.Y
        HWWrap.Active = true
        local HWLayout = Instance.new("UIListLayout", HWWrap)
        HWLayout.Padding = UDim.new(0, 9)
        HWLayout.SortOrder = Enum.SortOrder.LayoutOrder
        Core:TrackConnection("UI", HWLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
            HWWrap.CanvasSize = UDim2.fromOffset(0, HWLayout.AbsoluteContentSize.Y + 24)
        end))

        local function hwText(str, size, height, color)
            local label = Instance.new("TextLabel", HWWrap)
            label.Size = UDim2.new(1, -8, 0, height)
            label.BackgroundTransparency = 1
            label.Text = str
            label.TextSize = size
            label.Font = Enum.Font.GothamBold
            label.TextColor3 = color or Color3.fromRGB(245, 235, 235)
            label.TextWrapped = true
            label.TextXAlignment = Enum.TextXAlignment.Left
            return label
        end
        local function hwButton(str)
            local button = Instance.new("TextButton", HWWrap)
            button.Size = UDim2.new(1, -8, 0, 48)
            button.BackgroundColor3 = Color3.fromRGB(28, 18, 20)
            button.BorderSizePixel = 0
            button.TextColor3 = Color3.fromRGB(242, 242, 242)
            button.Text = str
            button.TextSize = 14
            button.Font = Enum.Font.GothamBold
            button.TextWrapped = true
            Instance.new("UICorner", button).CornerRadius = UDim.new(0, 7)
            return button
        end
        hwText("🎃 HALLOWEEN // EVENTO", 17, 36, Color3.fromRGB(255, 126, 63))
        hwText("4 BOSSES • PERFIS FIXOS • HALLOWED x10", 11, 42, Color3.fromRGB(194, 178, 172))
        hwText("LATERAL FIXO • DISTÂNCIA E ALTURA DEFINIDAS POR BOSS • +2,5 POR DANO", 11, 58, Color3.fromRGB(194,178,172))
        -- Hallowed Crystal: abrir x10, sem Pet Shop ou selecao de pets no Gratis.
        local hwEggActive, hwEggSerial = false, 0
        local hwEggStatus = hwText("Hallowed Crystal x10 pronto.", 11, 40, Color3.fromRGB(224,182,182))
        local hwEggOnce = hwButton("ABRIR HALLOWED CRYSTAL x10 // UMA VEZ")
        local hwEggAuto = hwButton("AUTO ABRIR HALLOWED x10: OFF")
        local function hwOpenEgg()
            local events = ReplicatedStorage:FindFirstChild("rEvents")
            local remote = events and events:FindFirstChild("openCrystalRemote")
            if not remote or not remote:IsA("RemoteFunction") then return false,"openCrystalRemote indisponível" end
            local ok, response = pcall(function()
                return remote:InvokeServer("openCrystalBulk", "Hallowed Crystal", 10)
            end)
            if not ok then return false, "Erro: "..tostring(response) end
            if response==false or (type(response)=="table" and (response.Ok==false or response.Success==false)) then
                return false,"Servidor recusou abertura x10"
            end
            return true,"Abertura x10 solicitada"
        end
        hwEggOnce.MouseButton1Click:Connect(function()
            local _,msg=hwOpenEgg(); hwEggStatus.Text=msg
        end)
        hwEggAuto.MouseButton1Click:Connect(function()
            hwEggActive=not hwEggActive
            hwEggSerial+=1
            local serial=hwEggSerial
            hwEggAuto.Text="AUTO ABRIR HALLOWED x10: "..(hwEggActive and "ON" or "OFF")
            if hwEggActive then
                task.spawn(function()
                    while hwEggActive and hwEggSerial==serial and Core:IsAlive() do
                        local ok,msg=hwOpenEgg()
                        hwEggStatus.Text=msg
                        if not ok then
                            hwEggActive=false
                            hwEggAuto.Text="AUTO ABRIR HALLOWED x10: OFF"
                            break
                        end
                        task.wait(1)
                    end
                end)
            end
        end)
        Core:AddCleanup("UI", function() hwEggActive=false;hwEggSerial+=1 end)

        local HWMainButton = hwButton("AUTO HALLOWEEN: OFF 🔴")
        local HWStatus = hwText("Status: aguardando ativação", 12, 48, Color3.fromRGB(193, 192, 192))
        hwText("SELECIONE OS BOSSES", 13, 30, Color3.fromRGB(245, 139, 87))

        local function hwStatus(msg)
            if HWStatus.Parent then HWStatus.Text = "Status: " .. tostring(msg) end
        end
        local function hwUpdateMain()
            HWMainButton.Text = HWState.enabled and "AUTO HALLOWEEN: ON 🟢" or "AUTO HALLOWEEN: OFF 🔴"
            HWMainButton.BackgroundColor3 = HWState.enabled and Color3.fromRGB(35, 93, 56) or Color3.fromRGB(64, 26, 31)
        end
        hwUpdateMain()
        for _, bossName in ipairs(HWINames) do
            local row = hwButton("")
            local function update()
                row.Text = (HWState.selected[bossName] and "✅ " or "⬜ ") .. bossName
                row.BackgroundColor3 = HWState.selected[bossName] and Color3.fromRGB(42, 31, 30) or Color3.fromRGB(20, 20, 20)
            end
            update()
            Core:TrackConnection("UI", row.MouseButton1Click:Connect(function()
                HWState.selected[bossName] = not HWState.selected[bossName]
                ARS_PREF.halloweenSelected[bossName] = HWState.selected[bossName]
                arsSavePrefs()
                update()
            end))
        end
        hwText("Mantenha Auto Boss normal e Auto Quest desligados ao usar esta aba. Se ambos forem ativados, Halloween para para evitar conflito de teleporte.", 11, 75, Color3.fromRGB(156, 152, 152))

        hwText("🎁 PASSE DE HALLOWEEN", 15, 34, Color3.fromRGB(255, 160, 90))
    -- ARASAKA GRATIS V23 // AUTO PASSE DE HALLOWEEN
    -- Baseado no HalloweenPassController: resposta.Ok, resposta.State,
    -- TierUnlocked/IsTierClaimed, ClaimTier, ClaimQuest e ClaimFinal.
    local PASS_WORKER = "GratisV24.AutoHalloweenPass"
    local passEnabled = false
    local btnHalloweenPass = hwButton("AUTO COLETAR PASSE 🎃: OFF 🔴")
    local function refreshPassButton()
        btnHalloweenPass.Text = "AUTO COLETAR PASSE 🎃: " .. (passEnabled and "ON 🟢" or "OFF 🔴")
        btnHalloweenPass.BackgroundColor3 = passEnabled and Color3.fromRGB(35, 93, 56) or Color3.fromRGB(64, 26, 31)
    end
    refreshPassButton()

    local function getPassRemote()
        local events = ReplicatedStorage:FindFirstChild("rEvents")
        local remote = events and events:FindFirstChild("halloweenPassRemote")
        return remote and remote:IsA("RemoteFunction") and remote or nil
    end

    local passModule
    local function getPassModule()
        if passModule then return passModule end
        local shared = ReplicatedStorage:FindFirstChild("shared")
        local modules = shared and shared:FindFirstChild("modules")
        local candidate = modules and modules:FindFirstChild("HalloweenPass")
        if candidate and candidate:IsA("ModuleScript") then
            local ok, result = pcall(require, candidate)
            if ok and type(result) == "table" then
                passModule = result
                return result
            end
        end
        return nil
    end

    local function passInvoke(remote, action, payload)
        local ok, response = pcall(function()
            return remote:InvokeServer(action, payload or {})
        end)
        if not ok then
            warn("[ARASAKA][PASS] " .. action .. " erro: " .. tostring(response))
            return nil
        end
        if type(response) ~= "table" then
            warn("[ARASAKA][PASS] " .. action .. " retornou resposta invalida")
            return nil
        end
        if response.Ok ~= true and response.Reason ~= "claimed" then
            warn("[ARASAKA][PASS] " .. action .. " recusado: " .. tostring(response.Reason))
        end
        return response
    end

    local function getPassState(remote)
        local response = passInvoke(remote, "GetState", {})
        if not response or response.Ok ~= true or type(response.State) ~= "table" then
            warn("[ARASAKA][PASS] GetState nao retornou State valido")
            return nil
        end
        return response.State
    end

    local function collectHalloweenPass(alive)
        local remote = getPassRemote()
        if not remote then
            warn("[ARASAKA][PASS] halloweenPassRemote nao encontrado")
            return
        end
        local state = getPassState(remote)
        if not state then return end
        if state.Active == false then
            print("[ARASAKA][PASS] Passe nao esta ativo")
            return
        end
        local module = getPassModule()
        local successes = 0
        local attempted = 0
        local function canContinue()
            return alive() and passEnabled
        end
        local function claim(action, data, description)
            if not canContinue() then return false end
            local response = passInvoke(remote, action, data)
            attempted += 1
            if response and response.Ok == true then
                successes += 1
                print("[ARASAKA][PASS] Coletado: " .. description)
                -- Atualizar estado apos cada sucesso para nao enviar premios repetidos.
                local updated = response.State
                if type(updated) ~= "table" then
                    updated = getPassState(remote)
                end
                if type(updated) == "table" then state = updated end
            end
            task.wait(0.65)
            return response and response.Ok == true
        end

        -- Recompensas do passe: consultar a mesma regra do cliente oficial.
        if module and type(module.TierUnlocked) == "function" and type(module.IsTierClaimed) == "function" then
            local maxTier = math.clamp(math.floor(tonumber(state.MaxTier) or 0), 0, 200)
            for tier = 1, maxTier do
                if not canContinue() then break end
                local ok, unlocked, claimed = pcall(function()
                    return module.TierUnlocked(state.Exp, tier), module.IsTierClaimed(state.Claimed, tier)
                end)
                if ok and unlocked and not claimed then
                    claim("ClaimTier", {Tier = tier}, "Tier " .. tier)
                end
            end
        else
            warn("[ARASAKA][PASS] Modulo HalloweenPass indisponivel; nao tentarei tiers bloqueados")
        end

        -- Missões do proprio Halloween Pass, diferentes das Quests normais do jogador.
        for _, group in ipairs({"Daily", "Season"}) do
            local quests = state[group]
            if type(quests) == "table" then
                for _, quest in pairs(quests) do
                    if not canContinue() then break end
                    if type(quest) == "table"
                        and not quest.Claimed
                        and type(quest.Progress) == "number"
                        and type(quest.Count) == "number"
                        and quest.Progress >= quest.Count
                        and quest.Category ~= nil
                        and quest.Key ~= nil then
                        claim("ClaimQuest", {Category = quest.Category, Key = quest.Key},
                            group .. " " .. tostring(quest.Key))
                    end
                end
            end
        end

        if canContinue() and state.FinalUnlocked == true and state.FinalClaimed ~= true then
            claim("ClaimFinal", {}, "Premio Final")
        end
        print(string.format("[ARASAKA][PASS] Finalizado: %d sucesso(s) em %d tentativa(s)", successes, attempted))
    end

    Core:TrackConnection("UI", btnHalloweenPass.MouseButton1Click:Connect(function()
        playClickSound()
        passEnabled = not passEnabled
        refreshPassButton()
        if not passEnabled then
            Core:StopWorker(PASS_WORKER)
            return
        end
        Core:StartWorker(PASS_WORKER, function(alive)
            while alive() and passEnabled do
                collectHalloweenPass(alive)
                for _ = 1, 60 do
                    if not alive() or not passEnabled then break end
                    task.wait(1)
                end
            end
        end)
    end))


    -- ARASAKA GRATIS V24 // AUTO PRESTIGE DO PASSE
    local PRESTIGE_WORKER = "GratisV24.AutoHalloweenPrestige"
    local prestigeEnabled = false
    local btnPassPrestige = hwButton("AUTO PRESTIGE 🎃: OFF 🔴")
    local function refreshPrestigeButton()
        btnPassPrestige.Text = "AUTO PRESTIGE 🎃: " .. (prestigeEnabled and "ON 🟢" or "OFF 🔴")
        btnPassPrestige.BackgroundColor3 = prestigeEnabled and Color3.fromRGB(35, 93, 56) or Color3.fromRGB(64, 26, 31)
    end
    refreshPrestigeButton()

    local function attemptPrestige()
        local remote = getPassRemote()
        if not remote then
            warn("[ARASAKA][PRESTIGE] halloweenPassRemote nao encontrado")
            return
        end
        local state = getPassState(remote)
        if not state or state.Active == false then return end
        local tier = tonumber(state.Tier)
        local maximum = tonumber(state.MaxTier)
        if not tier or not maximum or maximum <= 0 or tier < maximum then return end
        -- A mesma condicao do botao PrestigeTab oficial.
        local before = tonumber(state.Prestige)
        local response = passInvoke(remote, "Prestige", {})
        if not response or response.Ok ~= true then return end
        local afterState = type(response.State) == "table" and response.State or getPassState(remote)
        local after = afterState and tonumber(afterState.Prestige)
        if before and after then
            print(string.format("[ARASAKA][PRESTIGE] %d -> %d", before, after))
        else
            print("[ARASAKA][PRESTIGE] Servidor aceitou a solicitacao")
        end
    end

    Core:TrackConnection("UI", btnPassPrestige.MouseButton1Click:Connect(function()
        playClickSound()
        prestigeEnabled = not prestigeEnabled
        refreshPrestigeButton()
        if not prestigeEnabled then
            Core:StopWorker(PRESTIGE_WORKER)
            return
        end
        Core:StartWorker(PRESTIGE_WORKER, function(alive)
            while alive() and prestigeEnabled do
                attemptPrestige()
                for _ = 1, 30 do
                    if not alive() or not prestigeEnabled then break end
                    task.wait(1)
                end
            end
        end)
    end))

    Core:AddCleanup("UI", function()
        passEnabled = false
        prestigeEnabled = false
        Core:StopWorker(PASS_WORKER)
        Core:StopWorker(PRESTIGE_WORKER)
    end)


        local function hwCharacter()
            local ch = player.Character
            if not ch then return nil, nil, nil end
            return ch, ch:FindFirstChildOfClass("Humanoid"), ch:FindFirstChild("HumanoidRootPart")
        end
        local function hwJump()
            local _, hum, root = hwCharacter()
            if not hum or hum.Health <= 0 or not root then return end
            pcall(function()
                hum.Sit = false
                hum.Jump = true
                hum:ChangeState(Enum.HumanoidStateType.Jumping)
                local v = root.AssemblyLinearVelocity
                root.AssemblyLinearVelocity = Vector3.new(v.X, math.max(v.Y, 28), v.Z)
            end)
        end
        local function hwFind()
            for _, name in ipairs(HWINames) do
                if HWState.selected[name] then
                    local obj = workspace:FindFirstChild(name)
                    if obj then
                        if obj:IsA("BasePart") then return name, obj end
                        if obj:IsA("Model") then
                            local hum = obj:FindFirstChildOfClass("Humanoid")
                            if not hum or hum.Health > 0 then
                                local part = obj.PrimaryPart or obj:FindFirstChild("HumanoidRootPart") or obj:FindFirstChildWhichIsA("BasePart", true)
                                if part then return name, part end
                            end
                        end
                    end
                end
            end
            return nil, nil
        end
        local function hwBusy()
            return Core:IsWorkerRunning("Farms.BossPosition")
                or Core:IsWorkerRunning("Farms.BossAttack")
                or Core:IsWorkerRunning("Enchantments.AutoQuest")
        end
        local function hwEquipPunch(ch, hum)
            local equipped = ch:FindFirstChild("Punch")
            if equipped and equipped:IsA("Tool") then return equipped end
            local backpack = player:FindFirstChild("Backpack")
            local tool = backpack and backpack:FindFirstChild("Punch")
            if tool and tool:IsA("Tool") then
                pcall(function() hum:EquipTool(tool) end)
                return tool
            end
            return nil
        end
        local hwOrbitPosition = nil
        local hwOrbitGyro = nil
        local function hwReleaseHold()
            if hwOrbitPosition then pcall(function() hwOrbitPosition:Destroy() end) end
            if hwOrbitGyro then pcall(function() hwOrbitGyro:Destroy() end) end
            hwOrbitPosition, hwOrbitGyro = nil, nil
            local _, _, root = hwCharacter()
            if root then
                pcall(function()
                    root.Anchored = false
                    root.AssemblyLinearVelocity = Vector3.zero
                    root.AssemblyAngularVelocity = Vector3.zero
                end)
            end
        end
        local function hwPrepareOrbit(root)
            if hwOrbitPosition and hwOrbitPosition.Parent ~= root then hwReleaseHold() end
            if not hwOrbitPosition then
                local bp = Instance.new("BodyPosition")
                bp.Name = "ArasakaHalloweenOrbitPosition"
                bp.MaxForce = Vector3.new(1e8, 1e8, 1e8)
                bp.P = 25000
                bp.D = 1800
                bp.Position = root.Position
                bp.Parent = root
                hwOrbitPosition = bp
            end
            if not hwOrbitGyro then
                local bg = Instance.new("BodyGyro")
                bg.Name = "ArasakaHalloweenOrbitFacing"
                bg.MaxTorque = Vector3.new(1e8, 1e8, 1e8)
                bg.P = 15000
                bg.D = 1100
                bg.CFrame = root.CFrame
                bg.Parent = root
                hwOrbitGyro = bg
            end
        end
        -- Trava temporária contra queda no limbo ao matar/trocar de boss.
        -- Não é uma âncora permanente; sai ao chegar no próximo alvo/farm.
        local function hwFreezeTransition()
            local _, hum, root = hwCharacter()
            if not root or not hum or hum.Health <= 0 then return false end
            root.AssemblyLinearVelocity = Vector3.zero
            root.AssemblyAngularVelocity = Vector3.zero
            root.Anchored = true
            return true
        end
        local function hwReturn()
            if HWState.returning or not HWState.origin then return end
            -- Não libera a posição antes do teleporte: isso causava queda no limbo.
            hwFreezeTransition()
            HWState.returning = true
            local origin = HWState.origin
            local oldTool = HWState.savedTool
            HWState.origin = nil
            HWState.savedTool = nil
            HWState.target = nil
            hwStatus("retornando ao farm sem cair")
            task.wait(0.15)
            local ch, hum, root = hwCharacter()
            if ch and hum and hum.Health > 0 and root then
                pcall(function()
                    root.CFrame = origin
                    root.AssemblyLinearVelocity = Vector3.zero
                    root.AssemblyAngularVelocity = Vector3.zero
                end)
                if oldTool then
                    local backpack = player:FindFirstChild("Backpack")
                    local tool = ch:FindFirstChild(oldTool) or (backpack and backpack:FindFirstChild(oldTool))
                    if tool and tool:IsA("Tool") then pcall(function() hum:EquipTool(tool) end) end
                end
            end
            hwReleaseHold()
            HWState.returning = false
            hwStatus("aguardando")
        end
        local function hwStop(reason)
            if not HWState.enabled then return end
            HWState.enabled = false
            ARS_PREF.bossHalloween = false
            arsSavePrefs()
            HWState.generation += 1
            Core:StopWorker("Halloween.BossFarm")
            hwFreezeTransition()
            hwUpdateMain()
            hwStatus(reason or "desligado")
            if HWState.origin then
                task.spawn(hwReturn)
            end
        end
        local function arsToggleHalloween()
            if HWState.enabled then
                hwStop("desligado manualmente")
                return
            end
            if HWState.returning or HWState.origin then
                hwStatus("aguarde o retorno à máquina anterior")
                return
            end
            if hwBusy() then
                hwStatus("desligue Auto Boss e Auto Quest antes de ativar Halloween")
                return
            end
            local any = false
            for _, name in ipairs(HWINames) do
                if HWState.selected[name] then any = true break end
            end
            if not any then hwStatus("selecione pelo menos um boss") return end
            if not hwEventIsActive() then
                hwStatus("gratis temporariamente indisponivel; confira o Render")
                return
            end
            HWState.enabled = true
            ARS_PREF.bossHalloween = true
            ARS_PREF.bossNormal = false
            arsSavePrefs()
            HWState.generation += 1
            local generation = HWState.generation
            hwUpdateMain()
            hwStatus("procurando bosses do evento")
            Core:StartWorker("Halloween.BossFarm", function(isAlive)
                local alternating = false
                local lastName = nil
                local hwOrbitAngle = 0
                local hwOrbitLastTick = os.clock()
                local hwLastServerCheck = os.clock()
                local eventExtraHeight = 0
                local eventLastHealth = nil
                local eventHealthHumanoid = nil
                local activeBossPart = nil
                local activeOffsetY = nil
                local movementConnection = RunService.Heartbeat:Connect(function()
                    if not isAlive() or not HWState.enabled or generation ~= HWState.generation then return end
                    local targetPart = activeBossPart
                    if not targetPart or not targetPart.Parent or not activeOffsetY then return end
                    local _, hum, root = hwCharacter()
                    if not hum or hum.Health <= 0 or not root then return end
                    -- Mesmo modo 3 do teste V6, sem BodyPosition/BodyGyro.
                    local profile = HWProfiles[lastName]
                    if not profile then return end
                    local desired = targetPart.Position + Vector3.new(0, activeOffsetY, 0)
                    local look = root.CFrame.LookVector
                    local horizontal = Vector3.new(look.X, 0, look.Z)
                    if horizontal.Magnitude < 0.1 then horizontal = Vector3.new(0,0,-1) end
                    if (root.Position - desired).Magnitude > 0.35 then
                        root.CFrame = CFrame.lookAt(desired, desired + horizontal.Unit)
                    end
                    root.AssemblyLinearVelocity = Vector3.zero
                    if root.Anchored then root.Anchored = false end
                end)
                while isAlive() and HWState.enabled and generation == HWState.generation do
                    if os.clock() - hwLastServerCheck >= 60 then
                        hwLastServerCheck = os.clock()
                        if not hwEventIsActive() then
                            hwStop("gratis temporariamente indisponivel; confira o Render")
                            break
                        end
                    end
                    if hwBusy() then
                        hwStop("Auto Boss/Quest detectado: Halloween pausado")
                        break
                    end
                    local name, part = hwFind()
                    if not name or not part then
                        activeBossPart = nil
                        if lastName ~= nil then hwFreezeTransition() end
                        if HWState.origin then
                            hwReturn()
                        else
                            hwStatus("aguardando spawn dos bosses selecionados")
                        end
                        lastName = nil
                        eventExtraHeight = 0
                        eventLastHealth = nil
                        hwOrbitAngle = 0
                        hwOrbitLastTick = os.clock()
                        task.wait(0.8)
                    else
                        if HWState.origin == nil then
                            local ch, _, root = hwCharacter()
                            if root then
                                HWState.origin = root.CFrame
                                local tool = ch:FindFirstChildWhichIsA("Tool")
                                HWState.savedTool = tool and tool.Name or nil
                            end
                        end
                        if name ~= lastName then
                            activeBossPart = nil
                            hwStatus(name .. " detectado: transição segura")
                            if lastName ~= nil then
                                hwFreezeTransition()
                                task.wait(0.15)
                            else
                                hwJump()
                                task.wait(2)
                            end
                            if not isAlive() or not HWState.enabled or generation ~= HWState.generation then break end
                            name, part = hwFind()
                            if not part then
                                lastName = nil
                                task.wait(0.3)
                                continue
                            end
                            lastName = name
                            eventExtraHeight = 0
                            eventLastHealth = nil
                            hwOrbitAngle = 0
                            hwOrbitLastTick = os.clock()
                            hwStatus("Acima do boss: " .. name .. " // altura " .. HWProfiles[name].height)
                        end
                        local ch, hum, root = hwCharacter()
                        if hum and hum.Health > 0 and root and part and part.Parent then
                            -- Subida progressiva: +5 studs ao receber dano, como no Auto Boss normal.
                            if hum ~= eventHealthHumanoid then
                                eventHealthHumanoid = hum
                                eventLastHealth = hum.Health
                                eventExtraHeight = 0
                            elseif eventLastHealth and hum.Health < eventLastHealth then
                                eventExtraHeight = math.min(eventExtraHeight + 5, 250)
                            end
                            eventLastHealth = hum.Health
                            local profile = HWProfiles[name]
                            activeOffsetY = profile.height + eventExtraHeight
                            activeBossPart = part
                            local tool = hwEquipPunch(ch, hum)
                            if tool then pcall(function() tool:Activate() end) end
                            local ev = player:FindFirstChild("muscleEvent") or ch:FindFirstChild("muscleEvent")
                            if not ev then
                                local rsEvents = game:GetService("ReplicatedStorage"):FindFirstChild("rEvents")
                                ev = rsEvents and rsEvents:FindFirstChild("muscleEvent")
                            end
                            if ev and ev:IsA("RemoteEvent") then
                                alternating = not alternating
                                pcall(function() ev:FireServer("punch", alternating and "leftHand" or "rightHand") end)
                            else
                                hwStatus("muscleEvent não encontrado")
                            end
                        end
                        task.wait(0.1) -- Soco a cada 0.1s; orbita recalculada a cada ciclo
                    end
                end
                activeBossPart = nil
                movementConnection:Disconnect()
                hwReleaseHold()
                -- Um STOP interrompe a iteração; o retorno é assíncrono e tem trava.
            end)
        end
        Core:TrackConnection("UI", HWMainButton.MouseButton1Click:Connect(arsToggleHalloween))
        task.delay(3, function()
            if not Core:IsAlive() then return end
            if ARS_PREF.bossHalloween and not ARS_PREF.bossNormal then
                arsToggleHalloween()
            end
        end)
        Core:AddCleanup("UI", function()
            HWState.enabled = false
            HWState.generation += 1
            Core:StopWorker("Halloween.BossFarm")
            hwReleaseHold()
            -- Se a janela for destruída durante a sessão, não deixar movimento automático.
        end)
    end
    -- FIM / ARASAKA HALLOWEEN

    -- ARASAKA V3 / MOBILE OPTION ACCESSIBILITY
    -- Aumenta os CONTROLES do conteudo, nunca o tamanho/UIScale do hub.
    -- Somente aumenta a altura de botoes em listas com UIListLayout, para nao
    -- sobrepor botoes de janelas que usam posicionamento absoluto.
    local ArasakaOptionSizing = {
        Root = contentArea,
        Mode = UserInputService.TouchEnabled and 2 or 1,
        Originals = setmetatable({}, {__mode = "k"}),
        Connected = false,
    }

    function ArasakaOptionSizing:Apply(obj)
        if not obj or not obj.Parent or not obj:IsDescendantOf(self.Root) then return end
        if not (obj:IsA("TextButton") or obj:IsA("TextLabel") or obj:IsA("TextBox")) then return end
        local original = self.Originals[obj]
        if not original then
            original = { textSize = obj.TextSize, size = obj.Size, wrapped = obj.TextWrapped }
            self.Originals[obj] = original
        end
        local mode = self.Mode
        if mode == 1 then
            if obj.TextSize ~= original.textSize then obj.TextSize = original.textSize end
            if obj.Size ~= original.size then obj.Size = original.size end
            if obj.TextWrapped ~= original.wrapped then obj.TextWrapped = original.wrapped end
            return
        end

        local factor = mode == 2 and 1.48 or 1.75
        local minFont = mode == 2 and 16 or 19
        local targetFont = math.max(original.textSize, math.clamp(math.floor(original.textSize * factor + 0.5), minFont, 28))

        local baseHeight = original.size.Y.Offset
        local parent = obj.Parent
        local inVerticalList = parent:IsA("ScrollingFrame")
            and parent:FindFirstChildOfClass("UIListLayout") ~= nil
            and original.size.Y.Scale == 0
            and baseHeight >= 24 and baseHeight <= 66
        -- Aumentar a area de toque, mantendo o CanvasSize sob controle do layout.
        if inVerticalList and (obj:IsA("TextButton") or obj:IsA("TextBox")) then
            local minHeight = mode == 2 and 52 or 62
            local height = math.min(98, math.max(minHeight, math.floor(baseHeight * factor + 0.5)))
            obj.Size = UDim2.new(original.size.X.Scale, original.size.X.Offset, 0, height)
            obj.TextWrapped = true
        else
            -- Elementos posicionados manualmente nao mudam de tamanho: evita sobreposicao.
            obj.Size = original.size
            obj.TextWrapped = original.wrapped
            if original.size.Y.Scale == 0 and baseHeight > 0 then
                targetFont = math.min(targetFont, math.max(original.textSize, baseHeight - 4))
            end
        end
        if obj.TextScaled then
            -- TextScaled ja usa toda a area disponivel; seu limite fica intocado.
            return
        end
        if obj.TextSize ~= targetFont then obj.TextSize = targetFont end
    end

    function ArasakaOptionSizing:SetMode(mode)
        self.Mode = math.clamp(tonumber(mode) or 1, 1, 3)
        for _, obj in ipairs(self.Root:GetDescendants()) do
            self:Apply(obj)
        end
    end

    function ArasakaOptionSizing:Start()
        if self.Connected then return end
        self.Connected = true
        -- Nenhuma varredura periodica. Apenas novos elementos e cliques do usuario.
        Core:TrackConnection("UI", self.Root.DescendantAdded:Connect(function(obj)
            if obj:IsA("TextButton") or obj:IsA("TextLabel") or obj:IsA("TextBox") then
                task.defer(function()
                    if obj.Parent and ArasakaOptionSizing.Connected then
                        ArasakaOptionSizing:Apply(obj)
                    end
                end)
            end
        end))
        self:SetMode(self.Mode)
    end

    local tabKill = CriarContainerOculto("Kill")
    local tabChat = CriarContainerOculto("Chat")
    CriarAba("Calculadora", "CALCULADORA")

    abas["Início"].container.Visible = true
    abas["Início"].btn.BackgroundColor3 = Color3.fromRGB(45, 15, 18)
    abas["Início"].btn.TextColor3 = Color3.fromRGB(245, 245, 245)
    abas["Início"].title.TextColor3 = Color3.fromRGB(245, 245, 245)
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
        header.BackgroundColor3 = Color3.fromRGB(10, 10, 10)
        header.BorderSizePixel = 0
        header.Text = "  📊 CALCULADORA // AMOSTRA REAL DE 1 MINUTO"
        header.TextColor3 = Color3.fromRGB(244, 247, 252)
        header.Font = Enum.Font.GothamBlack
        header.TextSize = 12
        header.TextXAlignment = Enum.TextXAlignment.Left
        Instance.new("UICorner", header).CornerRadius = UDim.new(0, 4)
        local hs = Instance.new("UIStroke", header)
        hs.Color = Color3.fromRGB(55, 55, 55)

        local info = Instance.new("TextLabel", scroll)
        info.LayoutOrder = 2
        info.Size = UDim2.new(1, -6, 0, 46)
        info.BackgroundColor3 = Color3.fromRGB(10, 10, 12)
        info.BorderSizePixel = 0
        info.Text = "AGUARDANDO TREINO // SÓ CONTA ENQUANTO O STATUS ESTIVER SUBINDO"
        info.TextColor3 = Color3.fromRGB(232, 232, 232)
        info.Font = Enum.Font.GothamMedium
        info.TextSize = 13
        info.TextXAlignment = Enum.TextXAlignment.Left
        info.TextWrapped = true
        local infoPadding = Instance.new("UIPadding", info)
        infoPadding.PaddingLeft = UDim.new(0, 12)
        infoPadding.PaddingRight = UDim.new(0, 10)
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
            name.TextColor3 = Color3.fromRGB(244, 247, 252)
            name.Font = Enum.Font.GothamBold
            name.TextSize = 14
            name.TextXAlignment = Enum.TextXAlignment.Left

            local values = Instance.new("TextLabel", card)
            values.Size = UDim2.new(1, -28, 0, 48)
            values.Position = UDim2.new(0, 14, 0, 31)
            values.BackgroundTransparency = 1
            values.Text = "AGUARDANDO 1 MINUTO DE TREINO..."
            values.TextColor3 = Color3.fromRGB(195, 204, 218)
            values.Font = Enum.Font.GothamBold
            values.TextSize = 13
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

        -- A UI acima foi mantida intacta.
        -- Apenas a lógica de cálculo foi substituída:
        -- agora mede ganho REAL enquanto cada atributo está subindo e atualiza
        -- continuamente, sem precisar esperar fechar uma amostra de 1 minuto.
        local TRAINING_GRACE_SECONDS = 5
        local POLL_SECONDS = 0.25

        local samplers = {
            Forca = {
                read = function() return rawStat("Muscle", "Strength") end,
                label = labels.Forca,
                name = "FORÇA"
            },
            Dura = {
                read = function() return rawStat("Durability") end,
                label = labels.Dura,
                name = "DURABILIDADE"
            },
            Agil = {
                read = function() return rawStat("Agility", "Speed") end,
                label = labels.Agil,
                name = "AGILIDADE"
            },
            Rebirths = {
                read = function() return rawStat("Rebirths", "Rebirth") end,
                label = labels.Rebirths,
                name = "RENASCIMENTOS"
            }
        }

        for _, s in pairs(samplers) do
            s.previous = s.read()
            s.gain = 0
            s.activeTime = 0
            s.started = false
            s.lastGainAt = nil
            s.lastLoopAt = os.clock()
        end

        local function formatActiveTime(sec)
            sec = math.max(0, math.floor(sec or 0))
            local h = math.floor(sec / 3600)
            local m = math.floor((sec % 3600) / 60)
            local ss = sec % 60
            return string.format("%02dh %02dm %02ds", h, m, ss)
        end

        local function updateSampler(s)
            if not s.started or s.gain <= 0 or s.activeTime <= 0 then
                return
            end

            local perSecond = s.gain / math.max(0.001, s.activeTime)

            s.label.Text = string.format(
                "MINUTO  %s\nHORA  %s    |    DIA  %s    |    SEMANA  %s",
                nice(perSecond * 60),
                nice(perSecond * 3600),
                nice(perSecond * 86400),
                nice(perSecond * 604800)
            )
        end

        task.spawn(function()
            while Core:IsAlive() and tab.Parent do
                local now = os.clock()

                pcall(function()
                    local activeNames = {}
                    local longestActive = 0

                    for _, s in pairs(samplers) do
                        local dt = math.max(0, now - (s.lastLoopAt or now))
                        s.lastLoopAt = now

                        local current = s.read()
                        local delta = current - (s.previous or current)
                        s.previous = current

                        -- Só soma crescimento positivo. Reset/rebirth não reduz o acumulado.
                        if delta > 0 then
]====]
