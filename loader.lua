-- // 1. БЕЗОПАСНАЯ ОЧИСТКА //
local CoreGui = game:GetService("CoreGui")
if CoreGui:FindFirstChild("SexyMenu") then pcall(function() CoreGui:FindFirstChild("SexyMenu"):Destroy() end) end

-- // 2. СЕРВИСЫ //
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")
local Camera = Workspace.CurrentCamera
local LocalPlayer = Players.LocalPlayer

-- // 3. БЫСТРЫЕ ФУНКЦИИ //
local V2 = Vector2.new
local V3 = Vector3.new
local C3R = Color3.fromRGB
local C3 = Color3.new
local mfloor = math.floor
local mtan = math.tan
local mrad = math.rad
local msin = math.sin
local mcos = math.cos
local matan2 = math.atan2
local mclamp = math.clamp
local sfmt = string.format

-- // 4. ТЕМА //
local Theme = {
	TextLight = C3R(220, 220, 220),
	TextDark = C3R(120, 120, 120),
	Background = C3R(12, 12, 12),
	SectionBack = C3R(18, 18, 18),
	Border = C3R(40, 40, 40),
	Accent = C3R(215, 80, 175),
	Font = Enum.Font.Code
}

-- // 5. ГЛОБАЛЬНЫЕ НАСТРОЙКИ //
local GlobalState = {
	MenuKey = Enum.KeyCode.RightShift,
	MenuOpen = true,
	IsAnimating = false,
	AutoBhop = false,
	SpeedEnabled = false,
	SpeedValue = 16,
	PixelSurf = { IsActive = false },
	EdgeBug = { IsActive = false },
	Aimbot = {
		IsActive = false, TeamCheck = true, WallCheck = true,
		ShowFOV = false, FOV = 100, Smoothness = 3, BodyPart = "Head"
	},
	Triggerbot = {
		IsActive = false, TeamCheck = true, Delay = 0, MaxDistance = 500
	},
	KeybindListVisible = false,
	WatermarkVisible = true,
	FPSBoost = false,
	ESP = {
		Enabled = false, Boxes = false, Names = false, Health = false,
		Distance = false, Weapon = false, Chams = false, Arrows = false, TeamCheck = false
	}
}

-- Registry for UI updates on config load
local UI_Registry = {} -- { type="Toggle", obj=..., stateTable=..., stateKey=... }

-- // RAYCAST PARAMS (Cached) //
local MovementParams = RaycastParams.new()
MovementParams.FilterType = Enum.RaycastFilterType.Exclude
MovementParams.IgnoreWater = true

local WallCheckParams = RaycastParams.new()
WallCheckParams.FilterType = Enum.RaycastFilterType.Exclude
WallCheckParams.IgnoreWater = true

local TriggerParams = RaycastParams.new()
TriggerParams.FilterType = Enum.RaycastFilterType.Exclude
TriggerParams.IgnoreWater = true

-- // CONFIG FOLDER //
local CONFIG_FOLDER = "sexymenu"
if isfolder and not isfolder(CONFIG_FOLDER) then makefolder(CONFIG_FOLDER) end

-- // KEYBIND TRACKER //
local ActiveKeybinds = {}

local function GetShortKeyName(key)
	if not key then return "?" end
	if key == Enum.UserInputType.MouseButton1 then return "LMB" end
	if key == Enum.UserInputType.MouseButton2 then return "RMB" end
	if key == Enum.UserInputType.MouseButton3 then return "MMB" end
	return key.Name
end

-- // FOV CIRCLE //
local FOVCircle = Drawing.new("Circle")
FOVCircle.Thickness = 1; FOVCircle.NumSides = 60; FOVCircle.Radius = 100
FOVCircle.Filled = false; FOVCircle.Visible = false; FOVCircle.Color = Theme.Accent; FOVCircle.Transparency = 1

-- // ESP //
local ESP_Cache = {}
local function CreateDrawing(t, p) local d = Drawing.new(t); for k, v in pairs(p) do d[k] = v end; return d end
local function CreateHighlight() local h = Instance.new("Highlight"); h.Name = "SexyChams"; h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop; h.Enabled = false; return h end

local function GetWeaponName(player, character)
	local e = player:FindFirstChild("EquippedTool"); if e then return tostring(e.Value) end
	if character then e = character:FindFirstChild("EquippedTool"); if e then return tostring(e.Value) end; local tool = character:FindFirstChildOfClass("Tool"); if tool then return tool.Name end end
	return "None"
end

local function AddESP(player)
	if ESP_Cache[player] then return end
	ESP_Cache[player] = {
		BoxOutline = CreateDrawing("Square", {Visible=false, Thickness=3, Filled=false, Color=C3(0,0,0), Transparency=1}),
		Box = CreateDrawing("Square", {Visible=false, Thickness=1, Filled=false, Color=Theme.Accent, Transparency=1}),
		Name = CreateDrawing("Text", {Visible=false, Size=13, Center=true, Outline=true, Font=2, Color=C3(1,1,1)}),
		HealthBarOutline = CreateDrawing("Square", {Visible=false, Thickness=1, Filled=true, Color=C3(0,0,0)}),
		HealthBar = CreateDrawing("Square", {Visible=false, Thickness=1, Filled=true}),
		Distance = CreateDrawing("Text", {Visible=false, Size=13, Center=true, Outline=true, Font=2, Color=C3(1,1,1)}),
		Weapon = CreateDrawing("Text", {Visible=false, Size=13, Center=true, Outline=true, Font=2, Color=C3(1,1,1)}),
		Arrow = CreateDrawing("Triangle", {Visible=false, Thickness=1, Filled=true, Color=Theme.Accent}),
		Highlight = CreateHighlight()
	}
end

local function RemoveESP(player)
	if ESP_Cache[player] then for k, obj in pairs(ESP_Cache[player]) do if k == "Highlight" then if obj then obj:Destroy() end else obj:Remove() end end; ESP_Cache[player] = nil end
end

local function HideESP(d)
	d.Box.Visible = false; d.BoxOutline.Visible = false; d.Name.Visible = false
	d.HealthBar.Visible = false; d.HealthBarOutline.Visible = false
	d.Distance.Visible = false; d.Weapon.Visible = false; d.Arrow.Visible = false
	if d.Highlight then d.Highlight.Enabled = false end
end

for _, p in ipairs(Players:GetPlayers()) do if p ~= LocalPlayer then AddESP(p) end end
Players.PlayerAdded:Connect(function(p) if p ~= LocalPlayer then AddESP(p) end end)
Players.PlayerRemoving:Connect(RemoveESP)

local function IsTeammate(player)
	if not player or not LocalPlayer then return false end
	if player.Team ~= nil and LocalPlayer.Team ~= nil then if player.Team == LocalPlayer.Team then return true end end
	if player.TeamColor == LocalPlayer.TeamColor then return true end
	return false
end

local function IsVisible(targetPart, ignoreList)
	WallCheckParams.FilterDescendantsInstances = ignoreList
	local result = Workspace:Raycast(Camera.CFrame.Position, targetPart.Position - Camera.CFrame.Position, WallCheckParams)
	return result and result.Instance:IsDescendantOf(targetPart.Parent)
end

-- // AIMBOT //
local function GetClosestPlayerToCursor()
	local closest, shortest = nil, GlobalState.Aimbot.FOV
	local mousePos = UserInputService:GetMouseLocation()
	for _, player in ipairs(Players:GetPlayers()) do
		if player == LocalPlayer then continue end
		if GlobalState.Aimbot.TeamCheck and IsTeammate(player) then continue end
		local char = player.Character; if not char then continue end
		local hum = char:FindFirstChild("Humanoid"); local tp = char:FindFirstChild(GlobalState.Aimbot.BodyPart)
		if not hum or hum.Health <= 0 or not tp then continue end
		local pos, onScreen = Camera:WorldToViewportPoint(tp.Position); if not onScreen then continue end
		local dist = (V2(pos.X, pos.Y) - mousePos).Magnitude
		if dist < shortest then
			if GlobalState.Aimbot.WallCheck then
				if IsVisible(tp, {LocalPlayer.Character, Camera}) then shortest = dist; closest = tp end
			else shortest = dist; closest = tp end
		end
	end
	return closest
end

-- // MAIN RENDER LOOP //
RunService.RenderStepped:Connect(function()
	if GlobalState.Aimbot.ShowFOV then
		FOVCircle.Visible = true; FOVCircle.Radius = GlobalState.Aimbot.FOV; FOVCircle.Position = UserInputService:GetMouseLocation()
	else FOVCircle.Visible = false end

	if GlobalState.Aimbot.IsActive then
		local target = GetClosestPlayerToCursor()
		if target then
			local ml = UserInputService:GetMouseLocation()
			local pos, onScreen = Camera:WorldToViewportPoint(target.Position)
			if onScreen then
				local smooth = GlobalState.Aimbot.Smoothness; if smooth < 1 then smooth = 1 end
				if mousemoverel then mousemoverel((pos.X - ml.X) / smooth, (pos.Y - ml.Y) / smooth)
				else Camera.CFrame = Camera.CFrame:Lerp(CFrame.new(Camera.CFrame.Position, target.Position), 1 / (smooth * 2)) end
			end
		end
	end

	if not GlobalState.ESP.Enabled then
		for _, d in pairs(ESP_Cache) do HideESP(d) end
	else
		local cs = Camera.ViewportSize / 2
		local cc = Camera.CFrame; local cp = cc.Position
		local ff = 1 / (mtan(mrad(Camera.FieldOfView * 0.5)) * 2) * 1000
		for player, d in pairs(ESP_Cache) do
			local char = player.Character
			if not char or not char.Parent then HideESP(d); continue end
			local root = char:FindFirstChild("HumanoidRootPart"); local hum = char:FindFirstChild("Humanoid")
			if not root or not hum or hum.Health <= 0 then HideESP(d); continue end
			if GlobalState.ESP.TeamCheck and IsTeammate(player) then HideESP(d); continue end
			local rp = root.Position; local pos, onScreen = Camera:WorldToViewportPoint(rp)
			if GlobalState.ESP.Arrows and not onScreen then
				local rel = cc:PointToObjectSpace(rp); local ang = matan2(-rel.Y, rel.X)
				local ap = cs + V2(mcos(ang)*200, msin(ang)*200)
				local s, c = msin(ang), mcos(ang)
				d.Arrow.PointA = V2(15*c + ap.X, 15*s + ap.Y)
				d.Arrow.PointB = V2(-7.5*c - (-7.5)*s + ap.X, -7.5*s + (-7.5)*c + ap.Y)
				d.Arrow.PointC = V2(-7.5*c - 7.5*s + ap.X, -7.5*s + 7.5*c + ap.Y)
				d.Arrow.Visible = true
			else d.Arrow.Visible = false end
			if GlobalState.ESP.Chams then
				if not d.Highlight then d.Highlight = CreateHighlight() end
				if d.Highlight.Parent ~= char then d.Highlight.Parent = char end
				d.Highlight.FillColor = Theme.Accent; d.Highlight.OutlineColor = C3(1,1,1)
				d.Highlight.FillTransparency = 0.5; d.Highlight.OutlineTransparency = 0; d.Highlight.Enabled = true
			else if d.Highlight then d.Highlight.Enabled = false end end
			if onScreen then
				local dist = (cp - rp).Magnitude; local sc = ff / dist; local w, h = 4*sc, 6*sc
				local bp = V2(pos.X - w/2, pos.Y - h/2)
				if GlobalState.ESP.Boxes then d.BoxOutline.Size = V2(w,h); d.BoxOutline.Position = bp; d.BoxOutline.Visible = true; d.Box.Size = V2(w,h); d.Box.Position = bp; d.Box.Visible = true else d.Box.Visible = false; d.BoxOutline.Visible = false end
				if GlobalState.ESP.Names then d.Name.Text = player.Name; d.Name.Position = V2(pos.X, bp.Y - 16); d.Name.Visible = true else d.Name.Visible = false end
				if GlobalState.ESP.Health then
					local hp = mclamp(hum.Health/hum.MaxHealth, 0, 1); local bh = h*hp
					d.HealthBarOutline.Size = V2(4,h); d.HealthBarOutline.Position = V2(bp.X-6, bp.Y); d.HealthBarOutline.Visible = true
					d.HealthBar.Size = V2(2,bh); d.HealthBar.Position = V2(bp.X-5, bp.Y+(h-bh)); d.HealthBar.Color = C3R(255-(255*hp), 255*hp, 0); d.HealthBar.Visible = true
				else d.HealthBar.Visible = false; d.HealthBarOutline.Visible = false end
				local bo = bp.Y + h + 2
				if GlobalState.ESP.Weapon then d.Weapon.Text = GetWeaponName(player, char); d.Weapon.Position = V2(pos.X, bo); d.Weapon.Visible = true; bo = bo + 14 else d.Weapon.Visible = false end
				if GlobalState.ESP.Distance then d.Distance.Text = sfmt("[%d m]", mfloor(dist)); d.Distance.Position = V2(pos.X, bo); d.Distance.Visible = true else d.Distance.Visible = false end
			else d.Box.Visible = false; d.BoxOutline.Visible = false; d.Name.Visible = false; d.HealthBar.Visible = false; d.HealthBarOutline.Visible = false; d.Weapon.Visible = false; d.Distance.Visible = false end
		end
	end
end)

local function ApplyFPSBoost()
	for _, obj in pairs(Workspace:GetDescendants()) do if obj:IsA("BasePart") or obj:IsA("Texture") or obj:IsA("Decal") then obj.Material = Enum.Material.SmoothPlastic; if obj:IsA("Texture") or obj:IsA("Decal") then obj.Transparency = 1 end end end
	pcall(function() settings().Rendering.QualityLevel = Enum.QualityLevel.Level01 end)
end
local function RevertFPSBoost() pcall(function() settings().Rendering.QualityLevel = Enum.QualityLevel.Automatic end) end

-- // GUI //
local ScreenGui = Instance.new("ScreenGui"); ScreenGui.Name = "SexyMenu"; ScreenGui.ResetOnSpawn = false
if syn and syn.protect_gui then syn.protect_gui(ScreenGui) ScreenGui.Parent = CoreGui elseif gethui then ScreenGui.Parent = gethui() else ScreenGui.Parent = CoreGui end

local WatermarkFrame = Instance.new("Frame"); WatermarkFrame.Name = "Watermark"; WatermarkFrame.Size = UDim2.new(0, 200, 0, 32); WatermarkFrame.Position = UDim2.new(0, 15, 0, 15); WatermarkFrame.BackgroundColor3 = Theme.Background; WatermarkFrame.BorderSizePixel = 0; WatermarkFrame.Visible = true; WatermarkFrame.Parent = ScreenGui
Instance.new("UIStroke", WatermarkFrame).Color = Theme.Border
local WMLine = Instance.new("Frame", WatermarkFrame); WMLine.Size = UDim2.new(1, 0, 0, 1); WMLine.BackgroundColor3 = Theme.Accent; WMLine.BorderSizePixel = 0
local WMLabel = Instance.new("TextLabel", WatermarkFrame); WMLabel.Size = UDim2.new(1, 0, 1, 0); WMLabel.BackgroundTransparency = 1; WMLabel.Font = Theme.Font; WMLabel.TextSize = 16; WMLabel.TextColor3 = Theme.TextLight
local lastWMUpdate = 0
RunService.RenderStepped:Connect(function(dt)
	if GlobalState.WatermarkVisible then WatermarkFrame.Visible = true
		if tick() - lastWMUpdate > 0.25 then
			WMLabel.Text = sfmt("minkhack.eu | %s | fps: %d", LocalPlayer.DisplayName, mfloor(1/dt))
			WatermarkFrame.Size = UDim2.new(0, WMLabel.TextBounds.X + 48, 0, 32); lastWMUpdate = tick()
		end
	else WatermarkFrame.Visible = false end
end)

local MainFrame = Instance.new("Frame"); MainFrame.Name = "MainFrame"; MainFrame.Size = UDim2.new(0, 500, 0, 350); MainFrame.Position = UDim2.new(0.5, -250, 0.5, -175); MainFrame.BackgroundColor3 = Theme.Background; MainFrame.BorderSizePixel = 0; MainFrame.ClipsDescendants = true; MainFrame.Parent = ScreenGui
local UIStroke = Instance.new("UIStroke"); UIStroke.Color = Theme.Border; UIStroke.Thickness = 1; UIStroke.Parent = MainFrame; Instance.new("UICorner", MainFrame).CornerRadius = UDim.new(0, 4)
local dragging, dragInput, dragStart, startPos
MainFrame.InputBegan:Connect(function(input) if input.UserInputType == Enum.UserInputType.MouseButton1 then dragging = true; dragStart = input.Position; startPos = MainFrame.Position; input.Changed:Connect(function() if input.UserInputState == Enum.UserInputState.End then dragging = false end end) end end)
MainFrame.InputChanged:Connect(function(input) if input.UserInputType == Enum.UserInputType.MouseMovement then dragInput = input end end)
UserInputService.InputChanged:Connect(function(input) if input == dragInput and dragging then local d = input.Position - dragStart; MainFrame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y) end end)

local KeybindPanel = Instance.new("Frame"); KeybindPanel.Name = "KeybindPanel"; KeybindPanel.Size = UDim2.new(0, 180, 0, 30); KeybindPanel.Position = UDim2.new(0, 10, 0.5, -100); KeybindPanel.BackgroundColor3 = Theme.Background; KeybindPanel.Visible = false; KeybindPanel.Parent = ScreenGui
local KPStroke = Instance.new("UIStroke", KeybindPanel); KPStroke.Color = Theme.Border; KPStroke.Thickness = 1; Instance.new("UICorner", KeybindPanel).CornerRadius = UDim.new(0, 4)
local KPHeader = Instance.new("Frame", KeybindPanel); KPHeader.Size = UDim2.new(1, 0, 0, 28); KPHeader.BackgroundTransparency = 1
local KPTitle = Instance.new("TextLabel", KPHeader); KPTitle.Text = "keybinds"; KPTitle.Font = Theme.Font; KPTitle.TextSize = 13; KPTitle.TextColor3 = Theme.Accent; KPTitle.Size = UDim2.new(1, -10, 1, 0); KPTitle.Position = UDim2.new(0, 8, 0, 0); KPTitle.BackgroundTransparency = 1; KPTitle.TextXAlignment = Enum.TextXAlignment.Left
local KPContent = Instance.new("Frame", KeybindPanel); KPContent.Size = UDim2.new(1, 0, 1, -30); KPContent.Position = UDim2.new(0, 0, 0, 30); KPContent.BackgroundTransparency = 1; KPContent.ClipsDescendants = true
Instance.new("UIListLayout", KPContent).SortOrder = Enum.SortOrder.LayoutOrder

local function UpdateKeybindPanel()
	for _, child in pairs(KPContent:GetChildren()) do if child:IsA("Frame") then local data = ActiveKeybinds[child.Name]; if not data or not data.active then child:Destroy() end end end
	local cnt = 0
	for name, data in pairs(ActiveKeybinds) do
		if data.active then cnt = cnt + 1
			local entry = KPContent:FindFirstChild(name)
			local ft = "[" .. GetShortKeyName(data.key) .. "] " .. (data.mode or "Toggle")
			if not entry then
				entry = Instance.new("Frame", KPContent); entry.Name = name; entry.Size = UDim2.new(1, 0, 0, 22); entry.BackgroundTransparency = 1
				local nL = Instance.new("TextLabel", entry); nL.Name = "NameLabel"; nL.Text = name; nL.Font = Theme.Font; nL.TextSize = 12; nL.TextColor3 = Theme.TextLight; nL.Size = UDim2.new(0.6, -5, 1, 0); nL.Position = UDim2.new(0, 8, 0, 0); nL.BackgroundTransparency = 1; nL.TextXAlignment = Enum.TextXAlignment.Left; nL.TextTransparency = 1
				local mL = Instance.new("TextLabel", entry); mL.Name = "ModeLabel"; mL.Font = Theme.Font; mL.TextSize = 11; mL.Size = UDim2.new(0.4, -5, 1, 0); mL.Position = UDim2.new(0.6, 0, 0, 0); mL.BackgroundTransparency = 1; mL.TextXAlignment = Enum.TextXAlignment.Right; mL.Text = ft; mL.TextColor3 = Theme.Accent; mL.TextTransparency = 1
				local i = TweenInfo.new(0.3, Enum.EasingStyle.Quad); TweenService:Create(nL, i, {TextTransparency = 0}):Play(); TweenService:Create(mL, i, {TextTransparency = 0}):Play()
			else local ml = entry:FindFirstChild("ModeLabel"); if ml then ml.Text = ft end end
		end
	end
	KeybindPanel.Size = UDim2.new(0, 180, 0, math.max(30, 30 + (cnt * 24)))
end

local function SetKeybindActive(n, a, k, m) if not ActiveKeybinds[n] then ActiveKeybinds[n] = {active=false, key=nil, mode="Toggle"} end; ActiveKeybinds[n].active = a; if k then ActiveKeybinds[n].key = k end; if m then ActiveKeybinds[n].mode = m end; UpdateKeybindPanel() end

local kpAnimating = false
local function AnimateKeybindPanel(show)
	if kpAnimating then return end; kpAnimating = true
	local info = TweenInfo.new(0.12, Enum.EasingStyle.Sine)
	if show then KeybindPanel.Visible = true end
	TweenService:Create(KeybindPanel, info, {BackgroundTransparency = show and 0 or 1}):Play()
	TweenService:Create(KPStroke, info, {Transparency = show and 0 or 1}):Play()
	for _, o in pairs(KeybindPanel:GetDescendants()) do if o:IsA("TextLabel") then TweenService:Create(o, info, {TextTransparency = show and 0 or 1}):Play() end end
	task.delay(0.12, function() if not show then KeybindPanel.Visible = false end; kpAnimating = false end)
end

-- TABS
local TopBar = Instance.new("Frame", MainFrame); TopBar.Size = UDim2.new(1, 0, 0, 35); TopBar.BackgroundTransparency = 1
local Logo = Instance.new("TextLabel", TopBar); Logo.Text = "minkhack.eu"; Logo.Font = Theme.Font; Logo.TextSize = 16; Logo.TextColor3 = Theme.Accent; Logo.Size = UDim2.new(0, 100, 1, 0); Logo.Position = UDim2.new(0, 10, 0, 0); Logo.BackgroundTransparency = 1; Logo.TextXAlignment = Enum.TextXAlignment.Left
local TabContainer = Instance.new("Frame", TopBar); TabContainer.Size = UDim2.new(0, 340, 1, 0); TabContainer.Position = UDim2.new(0, 120, 0, 0); TabContainer.BackgroundTransparency = 1
Instance.new("UIListLayout", TabContainer).FillDirection = Enum.FillDirection.Horizontal
local ContentArea = Instance.new("Frame", MainFrame); ContentArea.Size = UDim2.new(1, -20, 1, -65); ContentArea.Position = UDim2.new(0, 10, 0, 45); ContentArea.BackgroundTransparency = 1

local Pages = {}
local AnimCache = {}

local function CreateTab(name)
	local TabBtn = Instance.new("TextButton", TabContainer); TabBtn.Text = name; TabBtn.Size = UDim2.new(0, 65, 1, 0); TabBtn.BackgroundTransparency = 1; TabBtn.Font = Theme.Font; TabBtn.TextSize = 13; TabBtn.TextColor3 = Theme.TextDark
	local PageFrame = Instance.new("ScrollingFrame", ContentArea); PageFrame.Name = name .. "_Page"; PageFrame.Size = UDim2.new(1, 0, 1, 0); PageFrame.BackgroundTransparency = 1; PageFrame.ScrollBarThickness = 2; PageFrame.ScrollBarImageColor3 = Theme.Accent; PageFrame.Visible = false; PageFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
	Instance.new("UIListLayout", PageFrame).Padding = UDim.new(0, 8)
	Pages[name] = {Button = TabBtn, Frame = PageFrame}
	TabBtn.MouseButton1Click:Connect(function() for n, data in pairs(Pages) do data.Frame.Visible = (n == name); data.Button.TextColor3 = (n == name) and Theme.Accent or Theme.TextDark end end)
end
CreateTab("Aimbot"); CreateTab("Movement"); CreateTab("Visuals"); CreateTab("Misc"); CreateTab("Config")
Pages["Aimbot"].Frame.Visible = true; Pages["Aimbot"].Button.TextColor3 = Theme.Accent

-- // UI HELPERS //
local function RegisterAnim(obj) table.insert(AnimCache, obj) end

-- Обновление UI элементов при загрузке конфига
local function UpdateUIElement(type, obj, val)
	if type == "Toggle" then
		obj.Indicator.BackgroundColor3 = val and Theme.Accent or Theme.TextDark
		obj.Btn.BackgroundColor3 = val and Theme.Accent or Theme.Background
	elseif type == "Feature" then -- Для фич с режимами
		obj.Indicator.BackgroundColor3 = val and Theme.Accent or Theme.TextDark
	elseif type == "Slider" then
		local min, max = obj.Min, obj.Max
		local p = mclamp((val - min) / (max - min), 0, 1)
		obj.Fill.Size = UDim2.new(p, 0, 1, 0)
		obj.Label.Text = "[ " .. tostring(val) .. " ]"
	elseif type == "Dropdown" then
		obj.Button.Text = val
	end
end

local function CreateFeature(tabName, featName, targetTable, callback)
	local PF = Pages[tabName].Frame; local F = Instance.new("Frame", PF); F.Name = "FeatureFrame"; F.Size = UDim2.new(1, -5, 0, 40); F.BackgroundColor3 = Theme.SectionBack; F.BorderSizePixel = 0; Instance.new("UIStroke", F).Color = Theme.Border; RegisterAnim(F)
	local Ind = Instance.new("Frame", F); Ind.Name = "DecoLine"; Ind.Size = UDim2.new(0, 3, 1, 0); Ind.BackgroundColor3 = Theme.TextDark; Ind.BorderSizePixel = 0; RegisterAnim(Ind)
	local L = Instance.new("TextLabel", F); L.Text = featName; L.Font = Theme.Font; L.TextSize = 14; L.TextColor3 = Theme.TextLight; L.Size = UDim2.new(0, 150, 1, 0); L.Position = UDim2.new(0, 15, 0, 0); L.BackgroundTransparency = 1; L.TextXAlignment = Enum.TextXAlignment.Left; RegisterAnim(L)
	local cKey, cMode, isB = nil, "Hold", false
	local MB = Instance.new("TextButton", F); MB.Name = "SmallBtn"; MB.Text = "Hold"; MB.Size = UDim2.new(0, 60, 0, 20); MB.Position = UDim2.new(1, -70, 0.5, -10); MB.BackgroundColor3 = Theme.Background; MB.TextColor3 = Theme.Accent; MB.Font = Theme.Font; MB.TextSize = 11; RegisterAnim(MB)
	local KB = Instance.new("TextButton", F); KB.Name = "SmallBtn"; KB.Text = "[ None ]"; KB.Size = UDim2.new(0, 80, 0, 20); KB.Position = UDim2.new(1, -160, 0.5, -10); KB.BackgroundColor3 = Theme.Background; KB.TextColor3 = Theme.TextDark; KB.Font = Theme.Font; KB.TextSize = 11; RegisterAnim(KB)
	local function US(s) targetTable.IsActive = s; Ind.BackgroundColor3 = s and Theme.Accent or Theme.TextDark; if callback then callback(s) end; SetKeybindActive(featName, s, cKey, cMode) end
	MB.MouseButton1Click:Connect(function() if cMode == "Toggle" then cMode = "Hold" elseif cMode == "Hold" then cMode = "Always" else cMode = "Toggle" end; MB.Text = cMode; if cMode == "Always" then US(true); KB.Visible = false else US(false); KB.Visible = true end end)
	KB.MouseButton1Click:Connect(function() isB = true; KB.Text = "..."; KB.TextColor3 = Theme.Accent end)
	UserInputService.InputBegan:Connect(function(input, gpe) if isB then if input.UserInputType == Enum.UserInputType.Keyboard or input.UserInputType == Enum.UserInputType.MouseButton2 or input.UserInputType == Enum.UserInputType.MouseButton3 then cKey = input.KeyCode ~= Enum.KeyCode.Unknown and input.KeyCode or input.UserInputType; KB.Text = "[ " .. GetShortKeyName(cKey) .. " ]"; KB.TextColor3 = Theme.TextLight; isB = false; SetKeybindActive(featName, targetTable.IsActive, cKey, cMode) end return end; if not gpe and cKey then local p = (input.KeyCode == cKey) or (input.UserInputType == cKey); if p then if cMode == "Toggle" then US(not targetTable.IsActive) elseif cMode == "Hold" then US(true) end end end end)
	UserInputService.InputEnded:Connect(function(input, gpe) if not gpe and cKey and cMode == "Hold" then local r = (input.KeyCode == cKey) or (input.UserInputType == cKey); if r then US(false) end end end)
	
	-- Register for Config Update
	table.insert(UI_Registry, {type="Feature", obj={Indicator=Ind}, target=targetTable, key="IsActive"})
end

local function CreateSimpleToggle(tabName, featName, callback, stateTable, stateKey)
	local PF = Pages[tabName].Frame; local F = Instance.new("Frame", PF); F.Name = "FeatureFrame"; F.Size = UDim2.new(1, -5, 0, 40); F.BackgroundColor3 = Theme.SectionBack; F.BorderSizePixel = 0; Instance.new("UIStroke", F).Color = Theme.Border; RegisterAnim(F)
	local Ind = Instance.new("Frame", F); Ind.Name = "DecoLine"; Ind.Size = UDim2.new(0, 3, 1, 0); Ind.BackgroundColor3 = Theme.TextDark; Ind.BorderSizePixel = 0; RegisterAnim(Ind)
	local L = Instance.new("TextLabel", F); L.Text = featName; L.Font = Theme.Font; L.TextSize = 14; L.TextColor3 = Theme.TextLight; L.Size = UDim2.new(0, 150, 1, 0); L.Position = UDim2.new(0, 15, 0, 0); L.BackgroundTransparency = 1; L.TextXAlignment = Enum.TextXAlignment.Left; RegisterAnim(L)
	local TB = Instance.new("TextButton", F); TB.Name = "SmallBtn"; TB.Size = UDim2.new(0, 20, 0, 20); TB.Position = UDim2.new(1, -30, 0.5, -10); TB.BackgroundColor3 = Theme.Background; TB.Text = ""; Instance.new("UIStroke", TB).Color = Theme.Border; RegisterAnim(TB)
	TB.MouseButton1Click:Connect(function() 
		local s = not stateTable[stateKey]; stateTable[stateKey] = s
		Ind.BackgroundColor3 = s and Theme.Accent or Theme.TextDark; TB.BackgroundColor3 = s and Theme.Accent or Theme.Background
		if callback then pcall(function() callback(s) end) end 
	end)
	table.insert(UI_Registry, {type="Toggle", obj={Indicator=Ind, Btn=TB}, target=stateTable, key=stateKey})
end

local function CreateSlider(tabName, featName, min, max, default, callback, stateTable, stateKey)
	local PF = Pages[tabName].Frame; local F = Instance.new("Frame", PF); F.Name = "FeatureFrame"; F.Size = UDim2.new(1, -5, 0, 45); F.BackgroundColor3 = Theme.SectionBack; F.BorderSizePixel = 0; Instance.new("UIStroke", F).Color = Theme.Border; RegisterAnim(F)
	local L = Instance.new("TextLabel", F); L.Text = featName; L.Font = Theme.Font; L.TextSize = 14; L.TextColor3 = Theme.TextLight; L.Size = UDim2.new(0, 150, 0, 25); L.Position = UDim2.new(0, 15, 0, 0); L.BackgroundTransparency = 1; L.TextXAlignment = Enum.TextXAlignment.Left; RegisterAnim(L)
	local VL = Instance.new("TextLabel", F); VL.Text = "[ " .. tostring(default) .. " ]"; VL.Font = Theme.Font; VL.TextSize = 13; VL.TextColor3 = Theme.Accent; VL.Size = UDim2.new(0, 50, 0, 25); VL.Position = UDim2.new(1, -60, 0, 0); VL.BackgroundTransparency = 1; VL.TextXAlignment = Enum.TextXAlignment.Right; RegisterAnim(VL)
	local SB = Instance.new("Frame", F); SB.Name = "SliderBack"; SB.Size = UDim2.new(1, -30, 0, 4); SB.Position = UDim2.new(0, 15, 0, 32); SB.BackgroundColor3 = Theme.Background; SB.BorderSizePixel = 0; Instance.new("UICorner", SB).CornerRadius = UDim.new(0, 2); RegisterAnim(SB)
	local SF = Instance.new("Frame", SB); SF.Name = "SliderFill"; SF.Size = UDim2.new((default-min)/(max-min), 0, 1, 0); SF.BackgroundColor3 = Theme.Accent; SF.BorderSizePixel = 0; Instance.new("UICorner", SF).CornerRadius = UDim.new(0, 2); RegisterAnim(SF)
	local T = Instance.new("TextButton", F); T.Size = UDim2.new(1, -30, 0, 15); T.Position = UDim2.new(0, 15, 0, 25); T.BackgroundTransparency = 1; T.Text = ""
	local isDragging = false
	local function us(input) 
		local p = mclamp((input.Position.X - SB.AbsolutePosition.X) / SB.AbsoluteSize.X, 0, 1)
		local v = mfloor(min + ((max-min)*p))
		SF.Size = UDim2.new(p, 0, 1, 0); VL.Text = "[ " .. tostring(v) .. " ]"
		if stateTable and stateKey then stateTable[stateKey] = v end
		if callback then callback(v) end 
	end
	T.InputBegan:Connect(function(input) if input.UserInputType == Enum.UserInputType.MouseButton1 then isDragging = true; us(input) end end)
	UserInputService.InputEnded:Connect(function(input) if input.UserInputType == Enum.UserInputType.MouseButton1 then isDragging = false end end)
	UserInputService.InputChanged:Connect(function(input) if isDragging and input.UserInputType == Enum.UserInputType.MouseMovement then us(input) end end)
	table.insert(UI_Registry, {type="Slider", obj={Fill=SF, Label=VL, Min=min, Max=max}, target=stateTable, key=stateKey})
end

local function CreateDropdown(tabName, featName, options, default, callback, stateTable, stateKey)
	local PF = Pages[tabName].Frame; local F = Instance.new("Frame", PF); F.Name = "FeatureFrame"; F.Size = UDim2.new(1, -5, 0, 40); F.BackgroundColor3 = Theme.SectionBack; F.BorderSizePixel = 0; F.ClipsDescendants = true; Instance.new("UIStroke", F).Color = Theme.Border; RegisterAnim(F)
	local L = Instance.new("TextLabel", F); L.Text = featName; L.Font = Theme.Font; L.TextSize = 14; L.TextColor3 = Theme.TextLight; L.Size = UDim2.new(0, 150, 0, 40); L.Position = UDim2.new(0, 15, 0, 0); L.BackgroundTransparency = 1; L.TextXAlignment = Enum.TextXAlignment.Left; RegisterAnim(L)
	local B = Instance.new("TextButton", F); B.Size = UDim2.new(0, 120, 0, 24); B.Position = UDim2.new(1, -130, 0, 8); B.BackgroundColor3 = Theme.Background; B.Text = default; B.TextColor3 = Theme.Accent; B.Font = Theme.Font; B.TextSize = 12; Instance.new("UIStroke", B).Color = Theme.Border; RegisterAnim(B)
	local LC = Instance.new("Frame", F); LC.Size = UDim2.new(1, 0, 0, #options*25); LC.Position = UDim2.new(0, 0, 0, 40); LC.BackgroundTransparency = 1; Instance.new("UIListLayout", LC)
	local exp = false; local bs = UDim2.new(1,-5,0,40); local es = UDim2.new(1,-5,0,40+(#options*25))
	for _, o in ipairs(options) do
		local OB = Instance.new("TextButton", LC); OB.Size = UDim2.new(1, 0, 0, 25); OB.BackgroundColor3 = Theme.SectionBack; OB.Text = o; OB.TextColor3 = Theme.TextDark; OB.Font = Theme.Font; OB.TextSize = 12; OB.BorderSizePixel = 0; RegisterAnim(OB)
		OB.MouseButton1Click:Connect(function() 
			B.Text = o; exp = false; F.Size = bs 
			if stateTable and stateKey then stateTable[stateKey] = o end
			if callback then callback(o) end 
		end)
	end
	B.MouseButton1Click:Connect(function() exp = not exp; F.Size = exp and es or bs end)
	table.insert(UI_Registry, {type="Dropdown", obj={Button=B}, target=stateTable, key=stateKey})
end

local function CreateButton(tabName, text, color, callback)
	local PF = Pages[tabName].Frame
	local Btn = Instance.new("TextButton", PF); Btn.Name = "SmallBtn"; Btn.Size = UDim2.new(1, -5, 0, 30)
	Btn.BackgroundColor3 = color or Theme.SectionBack; Btn.Text = text; Btn.TextColor3 = Theme.TextLight; Btn.Font = Theme.Font; Btn.TextSize = 14; Btn.BorderSizePixel = 0
	Instance.new("UIStroke", Btn).Color = Theme.Border; RegisterAnim(Btn)
	Btn.MouseButton1Click:Connect(function() if callback then callback() end end)
end

-- // CONFIG SYSTEM //
local ConfigInput -- forward declaration
local SelectedConfig = nil

local function GetConfigList()
	if not isfolder or not listfiles then return {} end
	local files = listfiles(CONFIG_FOLDER)
	local names = {}
	for _, f in ipairs(files) do
		local name = f:match("([^/\\]+)%.json$")
		if name then table.insert(names, name) end
	end
	return names
end

local function SaveConfig(name)
	if not writefile then return end
	local data = {
		Aimbot = GlobalState.Aimbot,
		Triggerbot = GlobalState.Triggerbot,
		Movement = { AutoBhop = GlobalState.AutoBhop, SpeedEnabled = GlobalState.SpeedEnabled, SpeedValue = GlobalState.SpeedValue },
		ESP = GlobalState.ESP,
		Misc = { WatermarkVisible = GlobalState.WatermarkVisible, FPSBoost = GlobalState.FPSBoost }
	}
	writefile(CONFIG_FOLDER .. "/" .. name .. ".json", HttpService:JSONEncode(data))
end

local function LoadConfig(name)
	if not readfile or not isfile then return end
	local path = CONFIG_FOLDER .. "/" .. name .. ".json"
	if not isfile(path) then return end
	local ok, data = pcall(function() return HttpService:JSONDecode(readfile(path)) end)
	if not ok or not data then return end
	
	-- Recursively merge
	local function Merge(target, source)
		for k, v in pairs(source) do
			if type(v) == "table" and type(target[k]) == "table" then Merge(target[k], v)
			elseif target[k] ~= nil then target[k] = v end
		end
	end
	Merge(GlobalState, data)
	
	-- Update UI
	for _, entry in ipairs(UI_Registry) do
		local val = entry.target[entry.key]
		UpdateUIElement(entry.type, entry.obj, val)
	end
	
	-- Apply instant effects
	if GlobalState.FPSBoost then ApplyFPSBoost() else RevertFPSBoost() end
end

local function DeleteConfig(name)
	if not delfile then return end
	local path = CONFIG_FOLDER .. "/" .. name .. ".json"
	if isfile and isfile(path) then delfile(path) end
end

-- // INITIALIZATION //

-- AIMBOT
CreateFeature("Aimbot", "Aimbot Enabled", GlobalState.Aimbot, function() end) 
CreateDropdown("Aimbot", "Target Bone", {"Head", "UpperTorso", "HumanoidRootPart", "LowerTorso"}, "Head", nil, GlobalState.Aimbot, "BodyPart")
CreateSimpleToggle("Aimbot", "Show FOV", nil, GlobalState.Aimbot, "ShowFOV")
CreateSimpleToggle("Aimbot", "Wall Check", nil, GlobalState.Aimbot, "WallCheck")
CreateSimpleToggle("Aimbot", "Team Check", nil, GlobalState.Aimbot, "TeamCheck")
CreateSlider("Aimbot", "FOV Radius", 10, 500, 100, nil, GlobalState.Aimbot, "FOV")
CreateSlider("Aimbot", "Smoothness", 1, 20, 3, nil, GlobalState.Aimbot, "Smoothness")
CreateFeature("Aimbot", "Triggerbot", GlobalState.Triggerbot, function() end)
CreateSimpleToggle("Aimbot", "Trigger TeamCheck", nil, GlobalState.Triggerbot, "TeamCheck")
CreateSlider("Aimbot", "Trigger Delay", 0, 200, 0, nil, GlobalState.Triggerbot, "Delay")

-- MOVEMENT
CreateSimpleToggle("Movement", "Auto Bhop", nil, GlobalState, "AutoBhop")
CreateFeature("Movement", "Edge Bug", GlobalState.EdgeBug, function() end)
CreateFeature("Movement", "Pixel Surf", GlobalState.PixelSurf, function() end)
CreateSimpleToggle("Movement", "Speed Hack", function(v) if not v and LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Humanoid") then LocalPlayer.Character.Humanoid.WalkSpeed = 16 end end, GlobalState, "SpeedEnabled")
CreateSlider("Movement", "WalkSpeed", 16, 200, 16, nil, GlobalState, "SpeedValue")

-- VISUALS
CreateSimpleToggle("Visuals", "ESP Enabled", nil, GlobalState.ESP, "Enabled")
CreateSimpleToggle("Visuals", "Boxes", nil, GlobalState.ESP, "Boxes")
CreateSimpleToggle("Visuals", "Names", nil, GlobalState.ESP, "Names")
CreateSimpleToggle("Visuals", "Health", nil, GlobalState.ESP, "Health")
CreateSimpleToggle("Visuals", "Distance", nil, GlobalState.ESP, "Distance")
CreateSimpleToggle("Visuals", "Weapon", nil, GlobalState.ESP, "Weapon")
CreateSimpleToggle("Visuals", "Chams", nil, GlobalState.ESP, "Chams")
CreateSimpleToggle("Visuals", "Arrows", nil, GlobalState.ESP, "Arrows")
CreateSimpleToggle("Visuals", "Team Check", nil, GlobalState.ESP, "TeamCheck")

-- MISC
CreateSimpleToggle("Misc", "Watermark", nil, GlobalState, "WatermarkVisible")
CreateSimpleToggle("Misc", "Keybind List", function(v) if v then UpdateKeybindPanel(); AnimateKeybindPanel(true) else AnimateKeybindPanel(false) end end, GlobalState, "KeybindListVisible")
CreateSimpleToggle("Misc", "FPS Boost", function(v) if v then ApplyFPSBoost() else RevertFPSBoost() end end, GlobalState, "FPSBoost")

-- Menu Bind in Misc
do
	local PF = Pages["Misc"].Frame; local F = Instance.new("Frame", PF); F.Name = "FeatureFrame"; F.Size = UDim2.new(1, -5, 0, 40); F.BackgroundColor3 = Theme.SectionBack; Instance.new("UIStroke", F).Color = Theme.Border; RegisterAnim(F)
	local L = Instance.new("TextLabel", F); L.Text = "Menu Toggle Key"; L.Font = Theme.Font; L.TextSize = 14; L.TextColor3 = Theme.TextLight; L.Size = UDim2.new(0, 150, 1, 0); L.Position = UDim2.new(0, 15, 0, 0); L.BackgroundTransparency = 1; L.TextXAlignment = Enum.TextXAlignment.Left; RegisterAnim(L)
	local KB = Instance.new("TextButton", F); KB.Name = "SmallBtn"; KB.Text = "[ RightShift ]"; KB.Size = UDim2.new(0, 100, 0, 20); KB.Position = UDim2.new(1, -110, 0.5, -10); KB.BackgroundColor3 = Theme.Background; KB.TextColor3 = Theme.TextLight; KB.Font = Theme.Font; KB.TextSize = 11; RegisterAnim(KB)
	local isB = false
	KB.MouseButton1Click:Connect(function() isB = true; KB.Text = "..."; KB.TextColor3 = Theme.Accent end)
	UserInputService.InputBegan:Connect(function(input) if isB and input.UserInputType == Enum.UserInputType.Keyboard then GlobalState.MenuKey = input.KeyCode; KB.Text = "[ " .. input.KeyCode.Name .. " ]"; KB.TextColor3 = Theme.TextLight; isB = false end end)
end

-- CONFIG TAB (Updated)
do
	local PF = Pages["Config"].Frame
	
	-- Config Name Input
	local InputFrame = Instance.new("Frame", PF); InputFrame.Name = "FeatureFrame"; InputFrame.Size = UDim2.new(1, -5, 0, 40); InputFrame.BackgroundColor3 = Theme.SectionBack; InputFrame.BorderSizePixel = 0; Instance.new("UIStroke", InputFrame).Color = Theme.Border; RegisterAnim(InputFrame)
	local InputLabel = Instance.new("TextLabel", InputFrame); InputLabel.Text = "Config Name"; InputLabel.Font = Theme.Font; InputLabel.TextSize = 14; InputLabel.TextColor3 = Theme.TextLight; InputLabel.Size = UDim2.new(0, 100, 1, 0); InputLabel.Position = UDim2.new(0, 15, 0, 0); InputLabel.BackgroundTransparency = 1; InputLabel.TextXAlignment = Enum.TextXAlignment.Left; RegisterAnim(InputLabel)
	ConfigInput = Instance.new("TextBox", InputFrame); ConfigInput.Size = UDim2.new(0, 150, 0, 24); ConfigInput.Position = UDim2.new(1, -160, 0.5, -12); ConfigInput.BackgroundColor3 = Theme.Background; ConfigInput.TextColor3 = Theme.TextLight; ConfigInput.PlaceholderText = "create new..."; ConfigInput.PlaceholderColor3 = Theme.TextDark; ConfigInput.Font = Theme.Font; ConfigInput.TextSize = 12; ConfigInput.Text = ""; ConfigInput.ClearTextOnFocus = false; Instance.new("UIStroke", ConfigInput).Color = Theme.Border; RegisterAnim(ConfigInput)

	-- Config List Scroll
	local ListContainer = Instance.new("Frame", PF); ListContainer.Name = "FeatureFrame"; ListContainer.Size = UDim2.new(1, -5, 0, 120); ListContainer.BackgroundColor3 = Theme.SectionBack; ListContainer.BorderSizePixel = 0; Instance.new("UIStroke", ListContainer).Color = Theme.Border; RegisterAnim(ListContainer)
	local ListScroll = Instance.new("ScrollingFrame", ListContainer); ListScroll.Size = UDim2.new(1, -10, 1, -10); ListScroll.Position = UDim2.new(0, 5, 0, 5); ListScroll.BackgroundTransparency = 1; ListScroll.ScrollBarThickness = 2; ListScroll.ScrollBarImageColor3 = Theme.Accent
	local ListLayout = Instance.new("UIListLayout", ListScroll); ListLayout.SortOrder = Enum.SortOrder.LayoutOrder; ListLayout.Padding = UDim.new(0, 2)

	local function RefreshList()
		for _, c in pairs(ListScroll:GetChildren()) do if c:IsA("TextButton") then c:Destroy() end end
		local configs = GetConfigList()
		for _, name in ipairs(configs) do
			local Btn = Instance.new("TextButton", ListScroll); Btn.Size = UDim2.new(1, 0, 0, 20); Btn.BackgroundColor3 = Theme.Background; Btn.Text = name; Btn.TextColor3 = (SelectedConfig == name) and Theme.Accent or Theme.TextDark; Btn.Font = Theme.Font; Btn.TextSize = 12; Btn.BorderSizePixel = 0
			Btn.MouseButton1Click:Connect(function()
				SelectedConfig = name
				ConfigInput.Text = name
				RefreshList() -- update colors
			end)
		end
		ListScroll.CanvasSize = UDim2.new(0, 0, 0, #configs * 22)
	end

	CreateButton("Config", "SAVE", Theme.SectionBack, function()
		local name = ConfigInput.Text; if name == "" then return end
		SaveConfig(name); RefreshList()
	end)

	CreateButton("Config", "LOAD", Theme.SectionBack, function()
		if SelectedConfig then LoadConfig(SelectedConfig) end
	end)

	CreateButton("Config", "DELETE", C3R(30, 10, 10), function()
		if SelectedConfig then DeleteConfig(SelectedConfig); SelectedConfig = nil; ConfigInput.Text = ""; RefreshList() end
	end)

	CreateButton("Config", "REFRESH LIST", Theme.SectionBack, function() RefreshList() end)
	
	CreateButton("Config", "UNLOAD SCRIPT", C3R(30, 10, 10), function()
		GlobalState.ESP.Enabled = false; GlobalState.Aimbot.IsActive = false; GlobalState.Triggerbot.IsActive = false; GlobalState.WatermarkVisible = false
		FOVCircle:Remove()
		if GlobalState.SpeedEnabled and LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Humanoid") then LocalPlayer.Character.Humanoid.WalkSpeed = 16 end
		if GlobalState.FPSBoost then RevertFPSBoost() end
		for _, p in pairs(Players:GetPlayers()) do RemoveESP(p) end
		KeybindPanel:Destroy(); WatermarkFrame:Destroy(); ScreenGui:Destroy()
	end)

	task.defer(RefreshList)
end

-- // OPTIMIZED MENU ANIMATION //
local function AnimateMenu()
	if GlobalState.IsAnimating then return end; GlobalState.IsAnimating = true
	local dur = 0.12; local info = TweenInfo.new(dur, Enum.EasingStyle.Sine)
	GlobalState.MenuOpen = not GlobalState.MenuOpen
	local opening = GlobalState.MenuOpen
	if opening then MainFrame.Visible = true end
	TweenService:Create(MainFrame, info, {BackgroundTransparency = opening and 0 or 1}):Play()
	TweenService:Create(UIStroke, info, {Transparency = opening and 0 or 1}):Play()
	
	for _, obj in pairs(MainFrame:GetDescendants()) do
		if obj:IsA("TextLabel") or obj:IsA("TextButton") or obj:IsA("TextBox") then
			TweenService:Create(obj, info, {TextTransparency = opening and 0 or 1}):Play()
		end
		-- Fix slider background animation by checking specific names
		if obj.Name == "FeatureFrame" or obj.Name == "SmallBtn" or obj.Name == "DecoLine" or obj.Name == "SliderBack" or obj.Name == "SliderFill" then
			TweenService:Create(obj, info, {BackgroundTransparency = opening and 0 or 1}):Play()
		end
	end
	task.delay(dur, function() if not GlobalState.MenuOpen then MainFrame.Visible = false end; GlobalState.IsAnimating = false end)
end
UserInputService.InputBegan:Connect(function(input, gpe) if not gpe and input.KeyCode == GlobalState.MenuKey then AnimateMenu() end end)

-- KEYBIND + PHYSICS LOOP
RunService.Heartbeat:Connect(function(dt)
	if GlobalState.KeybindListVisible then
		local hasActive = false; for _, data in pairs(ActiveKeybinds) do if data.active then hasActive = true; break end end
		if hasActive then if not KeybindPanel.Visible and not kpAnimating then UpdateKeybindPanel(); AnimateKeybindPanel(true) end else if KeybindPanel.Visible and not kpAnimating then AnimateKeybindPanel(false) end end
	end

	local Char = LocalPlayer.Character; if not Char or not Char.Parent then return end
	local Root = Char:FindFirstChild("HumanoidRootPart"); local Hum = Char:FindFirstChild("Humanoid")
	if not Root or not Hum or Hum.Health <= 0 then return end
	local vel = Root.AssemblyLinearVelocity

	if GlobalState.SpeedEnabled then Hum.WalkSpeed = GlobalState.SpeedValue end
	if GlobalState.AutoBhop and UserInputService:IsKeyDown(Enum.KeyCode.Space) and Hum.FloorMaterial ~= Enum.Material.Air then Hum:ChangeState(Enum.HumanoidStateType.Jumping) end

	if GlobalState.PixelSurf.IsActive and Hum.FloorMaterial == Enum.Material.Air and vel.Y < 2 then
		MovementParams.FilterDescendantsInstances = {Char}
		local cf = Root.CFrame; local lv, rv = cf.LookVector, cf.RightVector
		for _, dir in ipairs({lv, -lv, rv, -rv, (lv+rv).Unit, (lv-rv).Unit}) do
			local ray = Workspace:Raycast(Root.Position, dir * 3, MovementParams)
			if ray then local sv = vel - ray.Normal * vel:Dot(ray.Normal); Root.AssemblyLinearVelocity = V3(sv.X, 0, sv.Z); break end
		end
	end

	if GlobalState.EdgeBug.IsActive and vel.Y < -15 then
		MovementParams.FilterDescendantsInstances = {Char}
		if not Workspace:Raycast(Root.Position, V3(0,-4,0), MovementParams) then
			for _, off in ipairs({V3(1.5,-3,0), V3(-1.5,-3,0), V3(0,-3,1.5), V3(0,-3,-1.5)}) do
				if Workspace:Raycast(Root.Position, off, MovementParams) then Root.AssemblyLinearVelocity = V3(vel.X, -2, vel.Z); break end
			end
		end
	end
end)

-- TRIGGERBOT
local triggerDebounce = false
RunService.RenderStepped:Connect(function()
	if not GlobalState.Triggerbot.IsActive then return end
	TriggerParams.FilterDescendantsInstances = {LocalPlayer.Character, Camera}
	local ray = Workspace:Raycast(Camera.CFrame.Position, Camera.CFrame.LookVector * GlobalState.Triggerbot.MaxDistance, TriggerParams)
	if ray and ray.Instance then
		local hp = ray.Instance.Parent; local hum = hp:FindFirstChild("Humanoid")
		if hum and hum.Health > 0 then
			local plr = Players:GetPlayerFromCharacter(hp)
			if plr and (not GlobalState.Triggerbot.TeamCheck or not IsTeammate(plr)) and not triggerDebounce then
				triggerDebounce = true
				task.spawn(function()
					if GlobalState.Triggerbot.Delay > 0 then task.wait(GlobalState.Triggerbot.Delay / 1000) end
					if hum and hum.Health > 0 then if mouse1press then mouse1press() end; task.wait(0.05); if mouse1release then mouse1release() end end
					triggerDebounce = false
				end)
			end
		end
	end
end)

-- FOOTER
local Footer = Instance.new("Frame", MainFrame); Footer.Size = UDim2.new(1, 0, 0, 20); Footer.Position = UDim2.new(0, 0, 1, -20); Footer.BackgroundTransparency = 1
local FooterLine = Instance.new("Frame", Footer); FooterLine.Name = "DecoLine"; FooterLine.Size = UDim2.new(1, -20, 0, 1); FooterLine.Position = UDim2.new(0, 10, 0, 0); FooterLine.BackgroundColor3 = Theme.Border; FooterLine.BorderSizePixel = 0

local BuildTxt = Instance.new("TextLabel", Footer); BuildTxt.Text = "build:"; BuildTxt.Font = Theme.Font; BuildTxt.TextSize = 13; BuildTxt.TextColor3 = Theme.TextDark
BuildTxt.Size = UDim2.new(0, 40, 1, 0); BuildTxt.Position = UDim2.new(1, -90, 0, 0); BuildTxt.BackgroundTransparency = 1; BuildTxt.TextXAlignment = Enum.TextXAlignment.Right

local DevTxt = Instance.new("TextLabel", Footer); DevTxt.Text = "dev"; DevTxt.Font = Theme.Font; DevTxt.TextSize = 13; DevTxt.TextColor3 = Theme.Accent
DevTxt.Size = UDim2.new(0, 30, 1, 0); DevTxt.Position = UDim2.new(1, -48, 0, 0); DevTxt.BackgroundTransparency = 1; DevTxt.TextXAlignment = Enum.TextXAlignment.Right
