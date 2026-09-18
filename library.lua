
--[[
    Nebula-UI
    Clean purple-themed Drawing UI library for Matcha
    Inspired by Wabi Sabi UI Lib – different design, main accent = purple
    
    Docs: https://doc.wabisabi.mom/matcha/
    Drawing API: https://doc.wabisabi.mom/matcha/drawing/
]]

local Library = {
    Version = "1.0.0",
    Unloaded = false,
    Loaded = false,
    Options = {},
    Windows = {},
    Theme = {
        Accent       = Color3.fromRGB(168, 85, 247),
        AccentDark   = Color3.fromRGB(126, 58, 200),
        AccentLight  = Color3.fromRGB(196, 140, 255),
        Background   = Color3.fromRGB(18, 16, 24),
        Surface      = Color3.fromRGB(28, 24, 38),
        Surface2     = Color3.fromRGB(38, 32, 52),
        Border       = Color3.fromRGB(55, 45, 75),
        Text         = Color3.fromRGB(240, 235, 255),
        TextDim      = Color3.fromRGB(160, 150, 180),
        Success      = Color3.fromRGB(80, 200, 120),
        Danger       = Color3.fromRGB(240, 80, 100),
        Warning      = Color3.fromRGB(255, 190, 70),
    },
    _drawings = {},
    _notifications = {},
    _font = Drawing.Fonts.UI,
    _fontSize = 14,
}

local function clamp(v, a, b)
    if v < a then return a end
    if v > b then return b end
    return v
end

local function lerp(a, b, t)
    return a + (b - a) * t
end

local function getMouse()
    local plr = game:GetService("Players").LocalPlayer
    if plr and plr:GetMouse() then
        return Vector2.new(plr:GetMouse().X, plr:GetMouse().Y)
    end
    return Vector2.new(0, 0)
end

local function getScreen()
    local cam = workspace.CurrentCamera
    if cam then return cam.ViewportSize end
    return Vector2.new(1920, 1080)
end

local function isMouseIn(pos, size)
    local m = getMouse()
    return m.X >= pos.X and m.X <= pos.X + size.X
       and m.Y >= pos.Y and m.Y <= pos.Y + size.Y
end

local function isKeyPressed(vk)
    return iskeypressed(vk)
end

local function newDrawing(type)
    local d = Drawing.new(type)
    table.insert(Library._drawings, d)
    return d
end

local function clearDrawings()
    for _, d in ipairs(Library._drawings) do
        pcall(function() d:Remove() end)
    end
    Library._drawings = {}
end

function Library:Notify(cfg)
    cfg = cfg or {}
    local notif = {
        Title    = cfg.Title or "Notification",
        Content  = cfg.Content or "",
        Duration = cfg.Duration or 3.5,
        Created  = tick(),
        Alpha    = 0,
        Y        = 0,
    }
    table.insert(self._notifications, notif)
end

function Library:CreateWindow(cfg)
    cfg = cfg or {}
    local Window = {
        Title      = cfg.Title or "Nebula",
        SubTitle   = cfg.SubTitle or "v" .. Library.Version,
        Size       = cfg.Size or Vector2.new(560, 420),
        Position   = cfg.Position or Vector2.new(80, 80),
        MinSize    = cfg.MinSize or Vector2.new(420, 320),
        Tabs       = {},
        CurrentTab = 1,
        Visible    = true,
        Minimized  = false,
        Dragging   = false,
        DragOffset = Vector2.new(0, 0),
        Resizing   = false,
        Elements   = {},
        _drawCache = {},
    }

    function Window:AddTab(cfg)
        cfg = cfg or {}
        local Tab = {
            Title    = cfg.Title or "Tab",
            Icon     = cfg.Icon,
            Sections = {},
            Elements = {},
            ScrollY  = 0,
        }

        function Tab:AddSection(name)
            local Section = {
                Title    = name or "Section",
                Elements = {},
            }

            local function addElement(el)
                table.insert(Section.Elements, el)
                table.insert(Tab.Elements, el)
                if el.Id then
                    Library.Options[el.Id] = el
                end
                return el
            end

            function Section:AddToggle(cfg)
                cfg = cfg or {}
                local el = {
                    Type     = "Toggle",
                    Id       = cfg.Id,
                    Title    = cfg.Title or "Toggle",
                    Value    = cfg.Default or false,
                    Callback = cfg.Callback,
                    Keybind  = cfg.Keybind,
                }
                function el:Get() return self.Value end
                function el:SetValue(v)
                    self.Value = v and true or false
                    if self.Callback then
                        pcall(self.Callback, self.Value)
                    end
                end
                function el:OnChanged(fn)
                    self.Callback = fn
                    if fn then pcall(fn, self.Value) end
                end
                return addElement(el)
            end

            function Section:AddSlider(cfg)
                cfg = cfg or {}
                local el = {
                    Type     = "Slider",
                    Id       = cfg.Id,
                    Title    = cfg.Title or "Slider",
                    Min      = cfg.Min or 0,
                    Max      = cfg.Max or 100,
                    Value    = cfg.Default or cfg.Min or 0,
                    Rounding = cfg.Rounding or 0,
                    Callback = cfg.Callback,
                    Dragging = false,
                }
                function el:Get() return self.Value end
                function el:SetValue(v)
                    self.Value = clamp(v, self.Min, self.Max)
                    if self.Rounding > 0 then
                        local mult = 10 ^ self.Rounding
                        self.Value = math.floor(self.Value * mult + 0.5) / mult
                    else
                        self.Value = math.floor(self.Value + 0.5)
                    end
                    if self.Callback then
                        pcall(self.Callback, self.Value)
                    end
                end
                function el:OnChanged(fn)
                    self.Callback = fn
                    if fn then pcall(fn, self.Value) end
                end
                return addElement(el)
            end

            function Section:AddButton(cfg)
                cfg = cfg or {}
                local el = {
                    Type     = "Button",
                    Title    = cfg.Title or "Button",
                    Callback = cfg.Callback,
                }
                return addElement(el)
            end

            function Section:AddDropdown(cfg)
                cfg = cfg or {}
                local el = {
                    Type     = "Dropdown",
                    Id       = cfg.Id,
                    Title    = cfg.Title or "Dropdown",
                    Options  = cfg.Options or cfg.Values or {"None"},
                    Value    = cfg.Default or (cfg.Options and cfg.Options[1]) or "None",
                    Open     = false,
                    Callback = cfg.Callback,
                }
                function el:Get() return self.Value end
                function el:SetValue(v)
                    self.Value = v
                    if self.Callback then
                        pcall(self.Callback, self.Value)
                    end
                end
                function el:SetValues(list)
                    self.Options = list or {}
                end
                function el:OnChanged(fn)
                    self.Callback = fn
                    if fn then pcall(fn, self.Value) end
                end
                return addElement(el)
            end

            function Section:AddKeybind(cfg)
                cfg = cfg or {}
                local el = {
                    Type     = "Keybind",
                    Id       = cfg.Id,
                    Title    = cfg.Title or "Keybind",
                    Value    = cfg.Default or "None",
                    Mode     = cfg.Mode or "Toggle",
                    Toggled  = false,
                    Callback = cfg.Callback,
                    Binding  = false,
                }
                function el:GetState()
                    if self.Mode == "Always" then return true end
                    if self.Mode == "Toggle" then return self.Toggled end
                    return self._held or false
                end
                function el:SetValue(key, mode)
                    self.Value = key or self.Value
                    if mode then self.Mode = mode end
                end
                function el:OnChanged(fn)
                    self.Callback = fn
                end
                return addElement(el)
            end

            function Section:AddInput(cfg)
                cfg = cfg or {}
                local el = {
                    Type        = "Input",
                    Id          = cfg.Id,
                    Title       = cfg.Title or "Input",
                    Value       = cfg.Default or "",
                    Placeholder = cfg.Placeholder or "",
                    Callback    = cfg.Callback,
                    Focused     = false,
                }
                function el:Get() return self.Value end
                function el:SetValue(v)
                    self.Value = tostring(v or "")
                    if self.Callback then
                        pcall(self.Callback, self.Value)
                    end
                end
                function el:OnChanged(fn)
                    self.Callback = fn
                    if fn then pcall(fn, self.Value) end
                end
                return addElement(el)
            end

            function Section:AddParagraph(cfg)
                cfg = cfg or {}
                local el = {
                    Type    = "Paragraph",
                    Title   = cfg.Title or "",
                    Content = cfg.Content or cfg.Text or "",
                }
                return addElement(el)
            end

            table.insert(Tab.Sections, Section)
            return Section
        end

        function Tab:AddToggle(cfg) return self:AddSection(""):AddToggle(cfg) end
        function Tab:AddSlider(cfg) return self:AddSection(""):AddSlider(cfg) end
        function Tab:AddButton(cfg) return self:AddSection(""):AddButton(cfg) end
        function Tab:AddDropdown(cfg) return self:AddSection(""):AddDropdown(cfg) end
        function Tab:AddKeybind(cfg) return self:AddSection(""):AddKeybind(cfg) end
        function Tab:AddInput(cfg) return self:AddSection(""):AddInput(cfg) end
        function Tab:AddParagraph(cfg) return self:AddSection(""):AddParagraph(cfg) end

        table.insert(Window.Tabs, Tab)
        if #Window.Tabs == 1 then
            Window.CurrentTab = 1
        end
        return Tab
    end

    function Window:SelectTab(index)
        if index >= 1 and index <= #self.Tabs then
            self.CurrentTab = index
        end
    end

    table.insert(Library.Windows, Window)
    Library.Loaded = true

    task.spawn(function()
        local lastClick = 0
        local mouseDown = false

        while not Library.Unloaded do
            if not Window.Visible then
                task.wait(0.05)
                continue
            end

            for _, d in ipairs(Window._drawCache) do
                pcall(function() d:Remove() end)
            end
            Window._drawCache = {}

            local function draw(type)
                local d = Drawing.new(type)
                table.insert(Window._drawCache, d)
                table.insert(Library._drawings, d)
                return d
            end

            local theme = Library.Theme
            local pos = Window.Position
            local size = Window.Size
            local titleH = 36
            local tabW = 140
            local mouse = getMouse()
            local m1 = isKeyPressed(0x01)

            if m1 and not mouseDown then
                mouseDown = true
                if isMouseIn(pos, Vector2.new(size.X - 60, titleH)) then
                    Window.Dragging = true
                    Window.DragOffset = mouse - pos
                end
            elseif not m1 then
                mouseDown = false
                Window.Dragging = false
            end

            if Window.Dragging then
                Window.Position = mouse - Window.DragOffset
                pos = Window.Position
            end

            if isKeyPressed(0x23) then
                if tick() - lastClick > 0.3 then
                    Window.Minimized = not Window.Minimized
                    lastClick = tick()
                end
            end

            if Window.Minimized then
                local bar = draw("Square")
                bar.Filled = true
                bar.Color = theme.Surface
                bar.Position = pos
                bar.Size = Vector2.new(size.X, titleH)
                bar.Visible = true
                bar.ZIndex = 50

                local border = draw("Square")
                border.Filled = false
                border.Color = theme.Border
                border.Position = pos
                border.Size = Vector2.new(size.X, titleH)
                border.Visible = true
                border.ZIndex = 51

                local title = draw("Text")
                title.Text = Window.Title
                title.Color = theme.Text
                title.Position = pos + Vector2.new(12, 10)
                title.Size = 15
                title.Font = Library._font
                title.Outline = true
                title.Visible = true
                title.ZIndex = 52

                task.wait()
                continue
            end

            local bg = draw("Square")
            bg.Filled = true
            bg.Color = theme.Background
            bg.Position = pos
            bg.Size = size
            bg.Visible = true
            bg.ZIndex = 10

            local border = draw("Square")
            border.Filled = false
            border.Color = theme.Border
            border.Position = pos
            border.Size = size
            border.Visible = true
            border.ZIndex = 11

            local accentLine = draw("Square")
            accentLine.Filled = true
            accentLine.Color = theme.Accent
            accentLine.Position = pos
            accentLine.Size = Vector2.new(size.X, 2)
            accentLine.Visible = true
            accentLine.ZIndex = 12

            local titleBar = draw("Square")
            titleBar.Filled = true
            titleBar.Color = theme.Surface
            titleBar.Position = pos + Vector2.new(0, 2)
            titleBar.Size = Vector2.new(size.X, titleH - 2)
            titleBar.Visible = true
            titleBar.ZIndex = 13

            local titleText = draw("Text")
            titleText.Text = Window.Title
            titleText.Color = theme.Text
            titleText.Position = pos + Vector2.new(14, 10)
            titleText.Size = 15
            titleText.Font = Library._font
            titleText.Outline = true
            titleText.Visible = true
            titleText.ZIndex = 14

            if Window.SubTitle and Window.SubTitle ~= "" then
                local sub = draw("Text")
                sub.Text = Window.SubTitle
                sub.Color = theme.TextDim
                sub.Position = pos + Vector2.new(14 + (#Window.Title * 8) + 10, 12)
                sub.Size = 12
                sub.Font = Library._font
                sub.Outline = false
                sub.Visible = true
                sub.ZIndex = 14
            end

            local closeX = pos + Vector2.new(size.X - 28, 10)
            local closeTxt = draw("Text")
            closeTxt.Text = "×"
            closeTxt.Color = theme.TextDim
            closeTxt.Position = closeX
            closeTxt.Size = 16
            closeTxt.Font = Library._font
            closeTxt.Visible = true
            closeTxt.ZIndex = 15

            if isMouseIn(closeX - Vector2.new(4, 4), Vector2.new(20, 20)) and m1 and tick() - lastClick > 0.25 then
                Library:Destroy()
                lastClick = tick()
            end

            local tabBg = draw("Square")
            tabBg.Filled = true
            tabBg.Color = theme.Surface
            tabBg.Position = pos + Vector2.new(0, titleH)
            tabBg.Size = Vector2.new(tabW, size.Y - titleH)
            tabBg.Visible = true
            tabBg.ZIndex = 13

            local contentX = pos.X + tabW + 12
            local contentY = pos.Y + titleH + 12
            local contentW = size.X - tabW - 24

            for i, tab in ipairs(Window.Tabs) do
                local tabY = pos.Y + titleH + 8 + (i - 1) * 36
                local tabH = 32
                local isActive = (i == Window.CurrentTab)

                local tBg = draw("Square")
                tBg.Filled = true
                tBg.Color = isActive and theme.Surface2 or theme.Surface
                tBg.Position = Vector2.new(pos.X + 6, tabY)
                tBg.Size = Vector2.new(tabW - 12, tabH)
                tBg.Visible = true
                tBg.ZIndex = 14

                if isActive then
                    local indicator = draw("Square")
                    indicator.Filled = true
                    indicator.Color = theme.Accent
                    indicator.Position = Vector2.new(pos.X + 6, tabY)
                    indicator.Size = Vector2.new(3, tabH)
                    indicator.Visible = true
                    indicator.ZIndex = 15
                end

                local tText = draw("Text")
                tText.Text = tab.Title
                tText.Color = isActive and theme.Text or theme.TextDim
                tText.Position = Vector2.new(pos.X + 18, tabY + 8)
                tText.Size = 13
                tText.Font = Library._font
                tText.Outline = false
                tText.Visible = true
                tText.ZIndex = 16

                if isMouseIn(Vector2.new(pos.X + 6, tabY), Vector2.new(tabW - 12, tabH)) and m1 and tick() - lastClick > 0.2 then
                    Window.CurrentTab = i
                    lastClick = tick()
                end
            end

            local activeTab = Window.Tabs[Window.CurrentTab]
            if activeTab then
                local cy = contentY

                for _, section in ipairs(activeTab.Sections) do
                    if section.Title and section.Title ~= "" then
                        local secTitle = draw("Text")
                        secTitle.Text = section.Title:upper()
                        secTitle.Color = theme.AccentLight
                        secTitle.Position = Vector2.new(contentX, cy)
                        secTitle.Size = 12
                        secTitle.Font = Library._font
                        secTitle.Outline = false
                        secTitle.Visible = true
                        secTitle.ZIndex = 20
                        cy = cy + 22
                    end

                    for _, el in ipairs(section.Elements) do
                        if el.Type == "Toggle" then
                            local rowH = 28
                            local boxSize = 16
                            local boxPos = Vector2.new(contentX, cy + 5)

                            local box = draw("Square")
                            box.Filled = true
                            box.Color = el.Value and theme.Accent or theme.Surface2
                            box.Position = boxPos
                            box.Size = Vector2.new(boxSize, boxSize)
                            box.Visible = true
                            box.ZIndex = 20

                            local boxBorder = draw("Square")
                            boxBorder.Filled = false
                            boxBorder.Color = el.Value and theme.AccentLight or theme.Border
                            boxBorder.Position = boxPos
                            boxBorder.Size = Vector2.new(boxSize, boxSize)
                            boxBorder.Visible = true
                            boxBorder.ZIndex = 21

                            if el.Value then
                                local check = draw("Text")
                                check.Text = "✓"
                                check.Color = theme.Text
                                check.Position = boxPos + Vector2.new(2, 0)
                                check.Size = 13
                                check.Font = Library._font
                                check.Visible = true
                                check.ZIndex = 22
                            end

                            local label = draw("Text")
                            label.Text = el.Title
                            label.Color = theme.Text
                            label.Position = Vector2.new(contentX + boxSize + 10, cy + 6)
                            label.Size = 13
                            label.Font = Library._font
                            label.Visible = true
                            label.ZIndex = 20

                            if isMouseIn(boxPos, Vector2.new(boxSize + 120, boxSize)) and m1 and tick() - lastClick > 0.25 then
                                el:SetValue(not el.Value)
                                lastClick = tick()
                            end

                            cy = cy + rowH

                        elseif el.Type == "Slider" then
                            local rowH = 42
                            local label = draw("Text")
                            label.Text = el.Title
                            label.Color = theme.Text
                            label.Position = Vector2.new(contentX, cy)
                            label.Size = 13
                            label.Font = Library._font
                            label.Visible = true
                            label.ZIndex = 20

                            local valTxt = draw("Text")
                            valTxt.Text = tostring(el.Value)
                            valTxt.Color = theme.AccentLight
                            valTxt.Position = Vector2.new(contentX + contentW - 40, cy)
                            valTxt.Size = 13
                            valTxt.Font = Library._font
                            valTxt.Visible = true
                            valTxt.ZIndex = 20

                            local trackY = cy + 22
                            local trackH = 6
                            local track = draw("Square")
                            track.Filled = true
                            track.Color = theme.Surface2
                            track.Position = Vector2.new(contentX, trackY)
                            track.Size = Vector2.new(contentW - 10, trackH)
                            track.Visible = true
                            track.ZIndex = 20

                            local pct = (el.Value - el.Min) / math.max(el.Max - el.Min, 0.001)
                            local fillW = (contentW - 10) * pct
                            local fill = draw("Square")
                            fill.Filled = true
                            fill.Color = theme.Accent
                            fill.Position = Vector2.new(contentX, trackY)
                            fill.Size = Vector2.new(math.max(fillW, 0), trackH)
                            fill.Visible = true
                            fill.ZIndex = 21

                            local knob = draw("Square")
                            knob.Filled = true
                            knob.Color = theme.Text
                            knob.Position = Vector2.new(contentX + fillW - 5, trackY - 3)
                            knob.Size = Vector2.new(10, 12)
                            knob.Visible = true
                            knob.ZIndex = 22

                            if isMouseIn(Vector2.new(contentX, trackY - 6), Vector2.new(contentW - 10, 18)) and m1 then
                                local rel = clamp((mouse.X - contentX) / (contentW - 10), 0, 1)
                                el:SetValue(el.Min + rel * (el.Max - el.Min))
                            end

                            cy = cy + rowH

                        elseif el.Type == "Button" then
                            local btnH = 30
                            local btn = draw("Square")
                            btn.Filled = true
                            btn.Color = theme.Surface2
                            btn.Position = Vector2.new(contentX, cy)
                            btn.Size = Vector2.new(contentW - 10, btnH)
                            btn.Visible = true
                            btn.ZIndex = 20

                            local btnBorder = draw("Square")
                            btnBorder.Filled = false
                            btnBorder.Color = theme.Border
                            btnBorder.Position = Vector2.new(contentX, cy)
                            btnBorder.Size = Vector2.new(contentW - 10, btnH)
                            btnBorder.Visible = true
                            btnBorder.ZIndex = 21

                            local btnTxt = draw("Text")
                            btnTxt.Text = el.Title
                            btnTxt.Color = theme.Text
                            btnTxt.Position = Vector2.new(contentX + 12, cy + 7)
                            btnTxt.Size = 13
                            btnTxt.Font = Library._font
                            btnTxt.Visible = true
                            btnTxt.ZIndex = 22

                            if isMouseIn(Vector2.new(contentX, cy), Vector2.new(contentW - 10, btnH)) and m1 and tick() - lastClick > 0.3 then
                                if el.Callback then pcall(el.Callback) end
                                lastClick = tick()
                            end

                            cy = cy + btnH + 8

                        elseif el.Type == "Dropdown" then
                            local rowH = 30
                            local label = draw("Text")
                            label.Text = el.Title
                            label.Color = theme.Text
                            label.Position = Vector2.new(contentX, cy)
                            label.Size = 13
                            label.Font = Library._font
                            label.Visible = true
                            label.ZIndex = 20
                            cy = cy + 18

                            local dd = draw("Square")
                            dd.Filled = true
                            dd.Color = theme.Surface2
                            dd.Position = Vector2.new(contentX, cy)
                            dd.Size = Vector2.new(contentW - 10, rowH)
                            dd.Visible = true
                            dd.ZIndex = 20

                            local ddBorder = draw("Square")
                            ddBorder.Filled = false
                            ddBorder.Color = theme.Border
                            ddBorder.Position = Vector2.new(contentX, cy)
                            ddBorder.Size = Vector2.new(contentW - 10, rowH)
                            ddBorder.Visible = true
                            ddBorder.ZIndex = 21

                            local ddTxt = draw("Text")
                            ddTxt.Text = tostring(el.Value)
                            ddTxt.Color = theme.Text
                            ddTxt.Position = Vector2.new(contentX + 10, cy + 7)
                            ddTxt.Size = 13
                            ddTxt.Font = Library._font
                            ddTxt.Visible = true
                            ddTxt.ZIndex = 22

                            local arrow = draw("Text")
                            arrow.Text = el.Open and "▲" or "▼"
                            arrow.Color = theme.TextDim
                            arrow.Position = Vector2.new(contentX + contentW - 28, cy + 7)
                            arrow.Size = 12
                            arrow.Font = Library._font
                            arrow.Visible = true
                            arrow.ZIndex = 22

                            if isMouseIn(Vector2.new(contentX, cy), Vector2.new(contentW - 10, rowH)) and m1 and tick() - lastClick > 0.25 then
                                el.Open = not el.Open
                                lastClick = tick()
                            end

                            if el.Open then
                                for oi, opt in ipairs(el.Options) do
                                    local oY = cy + rowH + (oi - 1) * 26
                                    local oBg = draw("Square")
                                    oBg.Filled = true
                                    oBg.Color = (tostring(opt) == tostring(el.Value)) and theme.Accent or theme.Surface
                                    oBg.Position = Vector2.new(contentX, oY)
                                    oBg.Size = Vector2.new(contentW - 10, 26)
                                    oBg.Visible = true
                                    oBg.ZIndex = 30

                                    local oTxt = draw("Text")
                                    oTxt.Text = tostring(opt)
                                    oTxt.Color = theme.Text
                                    oTxt.Position = Vector2.new(contentX + 10, oY + 5)
                                    oTxt.Size = 13
                                    oTxt.Font = Library._font
                                    oTxt.Visible = true
                                    oTxt.ZIndex = 31

                                    if isMouseIn(Vector2.new(contentX, oY), Vector2.new(contentW - 10, 26)) and m1 and tick() - lastClick > 0.25 then
                                        el:SetValue(opt)
                                        el.Open = false
                                        lastClick = tick()
                                    end
                                end
                                cy = cy + rowH + #el.Options * 26 + 6
                            else
                                cy = cy + rowH + 8
                            end

                        elseif el.Type == "Keybind" then
                            local rowH = 28
                            local label = draw("Text")
                            label.Text = el.Title
                            label.Color = theme.Text
                            label.Position = Vector2.new(contentX, cy + 5)
                            label.Size = 13
                            label.Font = Library._font
                            label.Visible = true
                            label.ZIndex = 20

                            local kbW = 70
                            local kb = draw("Square")
                            kb.Filled = true
                            kb.Color = theme.Surface2
                            kb.Position = Vector2.new(contentX + contentW - kbW - 10, cy)
                            kb.Size = Vector2.new(kbW, rowH)
                            kb.Visible = true
                            kb.ZIndex = 20

                            local kbTxt = draw("Text")
                            kbTxt.Text = el.Binding and "..." or tostring(el.Value)
                            kbTxt.Color = theme.AccentLight
                            kbTxt.Position = Vector2.new(contentX + contentW - kbW - 4, cy + 6)
                            kbTxt.Size = 12
                            kbTxt.Font = Library._font
                            kbTxt.Visible = true
                            kbTxt.ZIndex = 21

                            if isMouseIn(Vector2.new(contentX + contentW - kbW - 10, cy), Vector2.new(kbW, rowH)) and m1 and tick() - lastClick > 0.3 then
                                el.Binding = true
                                lastClick = tick()
                            end

                            cy = cy + rowH + 6

                        elseif el.Type == "Input" then
                            local rowH = 30
                            local label = draw("Text")
                            label.Text = el.Title
                            label.Color = theme.Text
                            label.Position = Vector2.new(contentX, cy)
                            label.Size = 13
                            label.Font = Library._font
                            label.Visible = true
                            label.ZIndex = 20
                            cy = cy + 18

                            local inp = draw("Square")
                            inp.Filled = true
                            inp.Color = theme.Surface2
                            inp.Position = Vector2.new(contentX, cy)
                            inp.Size = Vector2.new(contentW - 10, rowH)
                            inp.Visible = true
                            inp.ZIndex = 20

                            local inpBorder = draw("Square")
                            inpBorder.Filled = false
                            inpBorder.Color = el.Focused and theme.Accent or theme.Border
                            inpBorder.Position = Vector2.new(contentX, cy)
                            inpBorder.Size = Vector2.new(contentW - 10, rowH)
                            inpBorder.Visible = true
                            inpBorder.ZIndex = 21

                            local display = el.Value ~= "" and el.Value or el.Placeholder
                            local inpTxt = draw("Text")
                            inpTxt.Text = display
                            inpTxt.Color = el.Value ~= "" and theme.Text or theme.TextDim
                            inpTxt.Position = Vector2.new(contentX + 10, cy + 7)
                            inpTxt.Size = 13
                            inpTxt.Font = Library._font
                            inpTxt.Visible = true
                            inpTxt.ZIndex = 22

                            cy = cy + rowH + 8

                        elseif el.Type == "Paragraph" then
                            if el.Title ~= "" then
                                local t = draw("Text")
                                t.Text = el.Title
                                t.Color = theme.Text
                                t.Position = Vector2.new(contentX, cy)
                                t.Size = 13
                                t.Font = Library._font
                                t.Visible = true
                                t.ZIndex = 20
                                cy = cy + 18
                            end
                            if el.Content ~= "" then
                                local c = draw("Text")
                                c.Text = el.Content
                                c.Color = theme.TextDim
                                c.Position = Vector2.new(contentX, cy)
                                c.Size = 12
                                c.Font = Library._font
                                c.Visible = true
                                c.ZIndex = 20
                                cy = cy + 20
                            end
                            cy = cy + 6
                        end
                    end
                    cy = cy + 10
                end
            end

            local nY = 20
            for i = #Library._notifications, 1, -1 do
                local n = Library._notifications[i]
                local age = tick() - n.Created
                if age > n.Duration then
                    table.remove(Library._notifications, i)
                else
                    local alpha = 1
                    if age < 0.25 then alpha = age / 0.25 end
                    if age > n.Duration - 0.4 then alpha = (n.Duration - age) / 0.4 end

                    local nW, nH = 260, 54
                    local nX = getScreen().X - nW - 20

                    local nBg = draw("Square")
                    nBg.Filled = true
                    nBg.Color = theme.Surface
                    nBg.Position = Vector2.new(nX, nY)
                    nBg.Size = Vector2.new(nW, nH)
                    nBg.Visible = true
                    nBg.ZIndex = 100
                    nBg.Transparency = 1 - alpha

                    local nAccent = draw("Square")
                    nAccent.Filled = true
                    nAccent.Color = theme.Accent
                    nAccent.Position = Vector2.new(nX, nY)
                    nAccent.Size = Vector2.new(3, nH)
                    nAccent.Visible = true
                    nAccent.ZIndex = 101

                    local nTitle = draw("Text")
                    nTitle.Text = n.Title
                    nTitle.Color = theme.Text
                    nTitle.Position = Vector2.new(nX + 14, nY + 8)
                    nTitle.Size = 13
                    nTitle.Font = Library._font
                    nTitle.Visible = true
                    nTitle.ZIndex = 102

                    local nContent = draw("Text")
                    nContent.Text = n.Content
                    nContent.Color = theme.TextDim
                    nContent.Position = Vector2.new(nX + 14, nY + 28)
                    nContent.Size = 12
                    nContent.Font = Library._font
                    nContent.Visible = true
                    nContent.ZIndex = 102

                    nY = nY + nH + 8
                end
            end

            task.wait()
        end

        for _, d in ipairs(Window._drawCache) do
            pcall(function() d:Remove() end)
        end
        Window._drawCache = {}
    end)

    return Window
end

function Library:Destroy()
    Library.Unloaded = true
    Library.Loaded = false
    clearDrawings()
    Library.Windows = {}
    Library.Options = {}
    Library._notifications = {}
end

function Library:Get(id)
    local opt = Library.Options[id]
    if opt then return opt:Get() end
    return nil
end

function Library:Set(id, value)
    local opt = Library.Options[id]
    if opt and opt.SetValue then
        opt:SetValue(value)
    end
end

getgenv().NebulaUI = Library

return Library
