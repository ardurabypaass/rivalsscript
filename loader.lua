local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local CoreGui = game:GetService("CoreGui")
local Lighting = game:GetService("Lighting")
local HttpService = game:GetService("HttpService")
local Camera = workspace.CurrentCamera

-- // EXTERNAL LIBRARIES //
local ESPLib = loadstring(game:HttpGet("https://raw.githubusercontent.com/linemaster2/esp-library/main/library.lua"))()

-- // CONFIG //
local ACCENT_COLOR = Color3.fromRGB(150, 200, 60)
local BG_COLOR = Color3.fromRGB(18, 18, 18)
local SECTION_COLOR = Color3.fromRGB(25, 25, 25)
local ELEMENT_BG = Color3.fromRGB(35, 35, 35)
local TEXT_COLOR = Color3.fromRGB(230, 230, 230)
local TEXT_DIM = Color3.fromRGB(140, 140, 140)

-- // FOLDERS //
local CONFIG_FOLDER = "minthack_configs"
local AUTOLOAD_FILE = CONFIG_FOLDER .. "/autoload.txt"
local AUTOEXEC_FILE = "minthack_autoexec.lua"

-- Create folders
pcall(function()
    if not isfolder(CONFIG_FOLDER) then
        makefolder(CONFIG_FOLDER)
    end
end)

-- // AUTO RE-EXECUTE ON REJOIN //
pcall(function()
    if not isfile(AUTOEXEC_FILE) then
        -- Создаём файл автозапуска в autoexec папке эксплоита
        local autoexecFolder = "autoexec"
        if not isfolder(autoexecFolder) then
            makefolder(autoexecFolder)
        end
    end
end)

-- Устанавливаем флаг чтобы не загружать дважды
if getgenv().__minthack_loaded then
    return
end
getgenv().__minthack_loaded = true

-- // GLOBAL SETTINGS //
local Settings = {
    FOV = Camera.FieldOfView,
    Zoom = { Enabled = false, Value = 30, Key = Enum.KeyCode.C },
    Fullbright = false,
    Airjump = false,
    Console = true,
    AutoRejoin = false
}

-- // AIMBOT SETTINGS //
local AimbotSettings = {
    Enabled = false,
    TeamCheck = false,
    VisibleCheck = false,
    TargetPart = "Head",
    FOVRadius = 200,
    ShowFOV = false,
    FOVColor = Color3.fromRGB(150, 200, 60),
    Smoothing = 5,
    MaxDistance = 1000,
    StickyAim = false,
    AutoShoot = false,
    ActivationKey = Enum.UserInputType.MouseButton2,
    PredictionEnabled = false,
    PredictionAmount = 0.1,
    SnapLine = false,
    SnapLineColor = Color3.fromRGB(150, 200, 60),
    LockOnNotify = true,
    CurrentTarget = nil,
    Locked = false
}

local OriginalLighting = {
    Ambient = Lighting.Ambient,
    Brightness = Lighting.Brightness,
    OutdoorAmbient = Lighting.OutdoorAmbient,
    GlobalShadows = Lighting.GlobalShadows
}

-- // LIBRARY UTILS //
local Library = { Registry = {} }
local Utility = {}

function Utility:Create(className, properties)
    local instance = Instance.new(className)
    for k, v in pairs(properties) do
        instance[k] = v
    end
    return instance
end

function Utility:MakeDraggable(topbar, object)
    local dragging, dragInput, dragStart, startPos
    topbar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true
            dragStart = input.Position
            startPos = object.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then dragging = false end
            end)
        end
    end)
    topbar.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement then dragInput = input end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if input == dragInput and dragging then
            local delta = input.Position - dragStart
            TweenService:Create(object, TweenInfo.new(0.1), {Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)}):Play()
        end
    end)
end

-- Удаляем старый UI если есть
pcall(function()
    local old = CoreGui:FindFirstChild("MinthackUI")
    if old then old:Destroy() end
    local oldConsole = CoreGui:FindFirstChild("MinthackConsole")
    if oldConsole then oldConsole:Destroy() end
end)

local ScreenGui = Utility:Create("ScreenGui", {
    Name = "MinthackUI",
    Parent = (RunService:IsStudio() and Players.LocalPlayer:WaitForChild("PlayerGui")) or CoreGui,
    ResetOnSpawn = false,
    ZIndexBehavior = Enum.ZIndexBehavior.Sibling
})

-- // FOV CIRCLE //
local FOVCircle = Drawing.new("Circle")
FOVCircle.Thickness = 1.5
FOVCircle.NumSides = 64
FOVCircle.Filled = false
FOVCircle.Transparency = 0.8
FOVCircle.Color = AimbotSettings.FOVColor
FOVCircle.Radius = AimbotSettings.FOVRadius
FOVCircle.Visible = false

-- // SNAP LINE //
local SnapLine = Drawing.new("Line")
SnapLine.Thickness = 1.5
SnapLine.Color = AimbotSettings.SnapLineColor
SnapLine.Transparency = 0.8
SnapLine.Visible = false

-- // CONSOLE SYSTEM //
local Console = {}
function Console:Setup()
    self.Gui = Utility:Create("ScreenGui", {Name = "MinthackConsole", Parent = CoreGui, Enabled = Settings.Console})
    self.Container = Utility:Create("ScrollingFrame", {
        Parent = self.Gui, BackgroundTransparency = 1, Size = UDim2.new(0.4, 0, 0.3, 0), Position = UDim2.new(0, 10, 0, 10),
        CanvasSize = UDim2.new(0,0,0,0), AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollBarThickness = 0
    })
    Utility:Create("UIListLayout", {Parent = self.Container, SortOrder = Enum.SortOrder.LayoutOrder, VerticalAlignment = Enum.VerticalAlignment.Bottom})
end
function Console:Log(text, color)
    if not self.Gui then return end
    local label = Utility:Create("TextLabel", {
        Parent = self.Container, Text = text, TextColor3 = color or Color3.new(1,1,1),
        Font = Enum.Font.Code, TextSize = 14, BackgroundTransparency = 1,
        Size = UDim2.new(1,0,0,18), TextXAlignment = Enum.TextXAlignment.Left, TextStrokeTransparency = 0.5
    })
    game:GetService("Debris"):AddItem(label, 8)
end
Console:Setup()

-- ============================================
-- // CONFIG SYSTEM //
-- ============================================
local ConfigSystem = {}
ConfigSystem.SelectedConfig = ""
ConfigSystem.ConfigListDropdown = nil

function ConfigSystem:GetConfigs()
    local configs = {}
    local success = pcall(function()
        if isfolder and listfiles then
            if isfolder(CONFIG_FOLDER) then
                local files = listfiles(CONFIG_FOLDER)
                for _, file in pairs(files) do
                    local name = string.match(file, "([^/\\]+)$")
                    if name then
                        local cfgName = string.match(name, "(.+)%.cfg$")
                        if cfgName then
                            table.insert(configs, cfgName)
                        end
                    end
                end
            end
        end
    end)
    if not success then
        Console:Log("[Config] Failed to list configs", Color3.new(1, 0.3, 0.3))
    end
    return configs
end

function ConfigSystem:Save(name)
    if not name or name == "" then
        return false, "Empty name"
    end
    local data = {}
    for elementName, element in pairs(Library.Registry) do
        local success2, val = pcall(element.Get)
        if success2 then
            if typeof(val) == "Color3" then
                val = {R = val.R, G = val.G, B = val.B, _isColor = true}
            end
            data[elementName] = val
        end
    end
    local success, err = pcall(function()
        if not isfolder(CONFIG_FOLDER) then
            makefolder(CONFIG_FOLDER)
        end
        writefile(CONFIG_FOLDER .. "/" .. name .. ".cfg", HttpService:JSONEncode(data))
    end)
    return success, err
end

function ConfigSystem:Load(name)
    if not name or name == "" then
        return false, "Empty name"
    end
    local path = CONFIG_FOLDER .. "/" .. name .. ".cfg"
    local exists = false
    pcall(function() exists = isfile(path) end)
    if not exists then
        return false, "Config not found"
    end
    local success, err = pcall(function()
        local raw = readfile(path)
        local data = HttpService:JSONDecode(raw)
        for elementName, val in pairs(data) do
            if Library.Registry[elementName] then
                if type(val) == "table" and val._isColor then
                    val = Color3.new(val.R, val.G, val.B)
                end
                pcall(Library.Registry[elementName].Set, val)
            end
        end
    end)
    return success, err
end

function ConfigSystem:Delete(name)
    if not name or name == "" then
        return false, "Empty name"
    end
    local path = CONFIG_FOLDER .. "/" .. name .. ".cfg"
    local exists = false
    pcall(function() exists = isfile(path) end)
    if not exists then
        return false, "Config not found"
    end
    local success, err = pcall(function()
        delfile(path)
    end)
    if success then
        local autoload = self:GetAutoload()
        if autoload == name then
            self:SetAutoload("")
        end
    end
    return success, err
end

function ConfigSystem:Overwrite(name)
    if not name or name == "" then
        return false, "Empty name"
    end
    return self:Save(name)
end

function ConfigSystem:SetAutoload(name)
    pcall(function()
        if not isfolder(CONFIG_FOLDER) then
            makefolder(CONFIG_FOLDER)
        end
        if name and name ~= "" then
            writefile(AUTOLOAD_FILE, name)
        else
            if isfile(AUTOLOAD_FILE) then
                delfile(AUTOLOAD_FILE)
            end
        end
    end)
end

function ConfigSystem:GetAutoload()
    local name = ""
    pcall(function()
        if isfile(AUTOLOAD_FILE) then
            name = readfile(AUTOLOAD_FILE)
        end
    end)
    return name
end

function ConfigSystem:RefreshDropdown()
    if self.ConfigListDropdown then
        self.ConfigListDropdown:Refresh()
    end
end

-- // AUTOEXEC SYSTEM //
local AutoExecSystem = {}

function AutoExecSystem:IsEnabled()
    local enabled = false
    pcall(function()
        if isfolder("autoexec") then
            enabled = isfile("autoexec/minthack.lua")
        end
    end)
    return enabled
end

function AutoExecSystem:Enable(scriptUrl)
    pcall(function()
        if not isfolder("autoexec") then
            makefolder("autoexec")
        end
        -- Сохраняем лоадер в autoexec
        local loaderCode = scriptUrl or 'loadstring(readfile("minthack_loader.lua"))()'
        writefile("autoexec/minthack.lua", loaderCode)
        -- Сохраняем основной скрипт
        -- Используем текущий source если доступен
    end)
end

function AutoExecSystem:Disable()
    pcall(function()
        if isfile("autoexec/minthack.lua") then
            delfile("autoexec/minthack.lua")
        end
    end)
end

-- // AIMBOT FUNCTIONS //
local function IsAlive(plr)
    local char = plr.Character
    if not char then return false end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hum or hum.Health <= 0 then return false end
    local root = char:FindFirstChild("HumanoidRootPart")
    if not root then return false end
    return true
end

local function IsVisible(part)
    if not AimbotSettings.VisibleCheck then return true end
    local localChar = Players.LocalPlayer.Character
    if not localChar then return true end
    local head = localChar:FindFirstChild("Head")
    if not head then return true end
    local rayParams = RaycastParams.new()
    rayParams.FilterType = Enum.RaycastFilterType.Exclude
    rayParams.FilterDescendantsInstances = {localChar}
    local direction = (part.Position - head.Position)
    local result = workspace:Raycast(head.Position, direction, rayParams)
    if result then return result.Instance:IsDescendantOf(part.Parent) end
    return true
end

local function IsTeammate(plr)
    if not AimbotSettings.TeamCheck then return false end
    local localPlayer = Players.LocalPlayer
    if localPlayer.Team and plr.Team then return localPlayer.Team == plr.Team end
    return false
end

local function GetClosestPlayer()
    local closest = nil
    local shortestDist = math.huge
    local mousePos = UserInputService:GetMouseLocation()
    local localPlayer = Players.LocalPlayer
    for _, plr in pairs(Players:GetPlayers()) do
        if plr ~= localPlayer and IsAlive(plr) and not IsTeammate(plr) then
            local char = plr.Character
            local targetPart = char:FindFirstChild(AimbotSettings.TargetPart) or char:FindFirstChild("Head")
            if targetPart then
                local screenPos, onScreen = Camera:WorldToViewportPoint(targetPart.Position)
                if onScreen then
                    local dist2D = (Vector2.new(screenPos.X, screenPos.Y) - mousePos).Magnitude
                    local dist3D = (targetPart.Position - Camera.CFrame.Position).Magnitude
                    if dist2D <= AimbotSettings.FOVRadius and dist3D <= AimbotSettings.MaxDistance then
                        if IsVisible(targetPart) then
                            if dist2D < shortestDist then
                                shortestDist = dist2D
                                closest = plr
                            end
                        end
                    end
                end
            end
        end
    end
    return closest
end

local function GetPredictedPosition(plr, targetPart)
    if not AimbotSettings.PredictionEnabled then return targetPart.Position end
    local velocity = targetPart.Velocity or Vector3.new(0, 0, 0)
    return targetPart.Position + (velocity * AimbotSettings.PredictionAmount)
end

-- // UNLOCK ALL //
local UnlockAllLoaded = false
local function RunUnlockAll()
    if game.GameId ~= 6035872082 then
        Console:Log("[Unlock All] Wrong game!", Color3.new(1, 0.3, 0.3))
        return
    end
    if UnlockAllLoaded then
        Console:Log("[Unlock All] Already loaded!", Color3.fromRGB(255, 200, 0))
        return
    end
    Console:Log("[Unlock All] Loading...", Color3.fromRGB(255, 200, 0))
    local success, err = pcall(function()
        local constructingWeapon, viewingProfile = nil, nil
        local lastUsedWeapon = nil
        local ua_equipped, ua_favorites = {}, {}
        local ReplicatedStorage = game:GetService("ReplicatedStorage")
        local player = Players.LocalPlayer
        local playerScripts = player.PlayerScripts
        local controllers = playerScripts.Controllers
        local saveFile = "unlockall/config.json"
        local EnumLibrary = require(ReplicatedStorage.Modules:WaitForChild("EnumLibrary", 10))
        if EnumLibrary then EnumLibrary:WaitForEnumBuilder() end
        local CosmeticLibrary = require(ReplicatedStorage.Modules:WaitForChild("CosmeticLibrary", 10))
        local ItemLibrary = require(ReplicatedStorage.Modules:WaitForChild("ItemLibrary", 10))
        local DataController = require(controllers:WaitForChild("PlayerDataController", 10))
        local function cloneCosmetic(name, cosmeticType, options)
            local base = CosmeticLibrary.Cosmetics[name]; if not base then return nil end; local data = {}
            for key, value in pairs(base) do data[key] = value end; data.Name = name; data.Type = data.Type or cosmeticType; data.Seed = data.Seed or math.random(1, 1000000)
            if EnumLibrary then local s, enumId = pcall(EnumLibrary.ToEnum, EnumLibrary, name); if s and enumId then data.Enum, data.ObjectID = enumId, data.ObjectID or enumId end end
            if options then if options.inverted ~= nil then data.Inverted = options.inverted end; if options.favoritesOnly ~= nil then data.OnlyUseFavorites = options.favoritesOnly end end; return data
        end
        local function saveUAConfig() if not writefile then return end; pcall(function() local config = {equipped = {}, favorites = ua_favorites}; for weapon, cosmetics in pairs(ua_equipped) do config.equipped[weapon] = {}; for cosmeticType, cosmeticData in pairs(cosmetics) do if cosmeticData and cosmeticData.Name then config.equipped[weapon][cosmeticType] = {name = cosmeticData.Name, seed = cosmeticData.Seed, inverted = cosmeticData.Inverted} end end end; if not isfolder("unlockall") then makefolder("unlockall") end; writefile(saveFile, HttpService:JSONEncode(config)) end) end
        local function loadUAConfig() if not readfile or not isfile or not isfile(saveFile) then return end; pcall(function() local config = HttpService:JSONDecode(readfile(saveFile)); if config.equipped then for weapon, cosmetics in pairs(config.equipped) do ua_equipped[weapon] = {}; for cosmeticType, cosmeticData in pairs(cosmetics) do local cloned = cloneCosmetic(cosmeticData.name, cosmeticType, {inverted = cosmeticData.inverted}); if cloned then cloned.Seed = cosmeticData.seed; ua_equipped[weapon][cosmeticType] = cloned end end end end; ua_favorites = config.favorites or {} end) end
        CosmeticLibrary.OwnsCosmeticNormally = function() return true end; CosmeticLibrary.OwnsCosmeticUniversally = function() return true end; CosmeticLibrary.OwnsCosmeticForWeapon = function() return true end
        local originalOwnsCosmetic = CosmeticLibrary.OwnsCosmetic; CosmeticLibrary.OwnsCosmetic = function(self, inventory, name, weapon) if name:find("MISSING_") then return originalOwnsCosmetic(self, inventory, name, weapon) end; return true end
        local originalGet = DataController.Get; DataController.Get = function(self, key) local data = originalGet(self, key); if key == "CosmeticInventory" then local proxy = {}; if data then for k, v in pairs(data) do proxy[k] = v end end; return setmetatable(proxy, {__index = function() return true end}) end; if key == "FavoritedCosmetics" then local result = data and table.clone(data) or {}; for weapon, favs in pairs(ua_favorites) do result[weapon] = result[weapon] or {}; for name2, isFav in pairs(favs) do result[weapon][name2] = isFav end end; return result end; return data end
        local originalGetWeaponData = DataController.GetWeaponData; DataController.GetWeaponData = function(self, weaponName) local data = originalGetWeaponData(self, weaponName); if not data then return nil end; local merged = {}; for key, value in pairs(data) do merged[key] = value end; merged.Name = weaponName; if ua_equipped[weaponName] then for cosmeticType, cosmeticData in pairs(ua_equipped[weaponName]) do merged[cosmeticType] = cosmeticData end end; return merged end
        local FighterController; pcall(function() FighterController = require(controllers:WaitForChild("FighterController", 10)) end)
        if hookmetamethod then
            local remotes = ReplicatedStorage:FindFirstChild("Remotes"); local dataRemotes = remotes and remotes:FindFirstChild("Data"); local equipRemote = dataRemotes and dataRemotes:FindFirstChild("EquipCosmetic"); local favoriteRemote = dataRemotes and dataRemotes:FindFirstChild("FavoriteCosmetic"); local replicationRemotes = remotes and remotes:FindFirstChild("Replication"); local fighterRemotes = replicationRemotes and replicationRemotes:FindFirstChild("Fighter"); local useItemRemote = fighterRemotes and fighterRemotes:FindFirstChild("UseItem")
            if equipRemote then local oldNamecall; oldNamecall = hookmetamethod(game, "__namecall", function(self, ...) if getnamecallmethod() ~= "FireServer" then return oldNamecall(self, ...) end; local args = {...}; if useItemRemote and self == useItemRemote then local objectID = args[1]; if FighterController then pcall(function() local fighter = FighterController:GetFighter(player); if fighter and fighter.Items then for _, item in pairs(fighter.Items) do if item:Get("ObjectID") == objectID then lastUsedWeapon = item.Name; break end end end end) end end; if self == equipRemote then local weaponName, cosmeticType, cosmeticName, options2 = args[1], args[2], args[3], args[4] or {}; if cosmeticName and cosmeticName ~= "None" and cosmeticName ~= "" then local inventory = DataController:Get("CosmeticInventory"); if inventory and rawget(inventory, cosmeticName) then return oldNamecall(self, ...) end end; ua_equipped[weaponName] = ua_equipped[weaponName] or {}; if not cosmeticName or cosmeticName == "None" or cosmeticName == "" then ua_equipped[weaponName][cosmeticType] = nil; if not next(ua_equipped[weaponName]) then ua_equipped[weaponName] = nil end else local cloned = cloneCosmetic(cosmeticName, cosmeticType, {inverted = options2.IsInverted, favoritesOnly = options2.OnlyUseFavorites}); if cloned then ua_equipped[weaponName][cosmeticType] = cloned end end; task.defer(function() pcall(function() DataController.CurrentData:Replicate("WeaponInventory") end); task.wait(0.2); saveUAConfig() end); return end; if self == favoriteRemote then ua_favorites[args[1]] = ua_favorites[args[1]] or {}; ua_favorites[args[1]][args[2]] = args[3] or nil; saveUAConfig(); task.spawn(function() pcall(function() DataController.CurrentData:Replicate("FavoritedCosmetics") end) end); return end; return oldNamecall(self, ...) end) end
        end
        local ClientItem; pcall(function() ClientItem = require(player.PlayerScripts.Modules.ClientReplicatedClasses.ClientFighter.ClientItem) end)
        if ClientItem and ClientItem._CreateViewModel then local originalCreateViewModel = ClientItem._CreateViewModel; ClientItem._CreateViewModel = function(self2, viewmodelRef) local weaponName = self2.Name; local weaponPlayer = self2.ClientFighter and self2.ClientFighter.Player; constructingWeapon = (weaponPlayer == player) and weaponName or nil; if weaponPlayer == player and ua_equipped[weaponName] and ua_equipped[weaponName].Skin and viewmodelRef then local dataKey, skinKey, nameKey = self2:ToEnum("Data"), self2:ToEnum("Skin"), self2:ToEnum("Name"); if viewmodelRef[dataKey] then viewmodelRef[dataKey][skinKey] = ua_equipped[weaponName].Skin; viewmodelRef[dataKey][nameKey] = ua_equipped[weaponName].Skin.Name elseif viewmodelRef.Data then viewmodelRef.Data.Skin = ua_equipped[weaponName].Skin; viewmodelRef.Data.Name = ua_equipped[weaponName].Skin.Name end end; local result = originalCreateViewModel(self2, viewmodelRef); constructingWeapon = nil; return result end end
        local viewModelModule = player.PlayerScripts.Modules.ClientReplicatedClasses.ClientFighter.ClientItem:FindFirstChild("ClientViewModel")
        if viewModelModule then local ClientViewModel = require(viewModelModule); if ClientViewModel.GetWrap then local originalGetWrap = ClientViewModel.GetWrap; ClientViewModel.GetWrap = function(self2) local weaponName = self2.ClientItem and self2.ClientItem.Name; local weaponPlayer = self2.ClientItem and self2.ClientItem.ClientFighter and self2.ClientItem.ClientFighter.Player; if weaponName and weaponPlayer == player and ua_equipped[weaponName] and ua_equipped[weaponName].Wrap then return ua_equipped[weaponName].Wrap end; return originalGetWrap(self2) end end; local originalNew = ClientViewModel.new; ClientViewModel.new = function(replicatedData, clientItem) local weaponPlayer = clientItem.ClientFighter and clientItem.ClientFighter.Player; local weaponName = constructingWeapon or clientItem.Name; if weaponPlayer == player and ua_equipped[weaponName] then local ReplicatedClass = require(ReplicatedStorage.Modules.ReplicatedClass); local dataKey = ReplicatedClass:ToEnum("Data"); replicatedData[dataKey] = replicatedData[dataKey] or {}; local cosmetics = ua_equipped[weaponName]; if cosmetics.Skin then replicatedData[dataKey][ReplicatedClass:ToEnum("Skin")] = cosmetics.Skin end; if cosmetics.Wrap then replicatedData[dataKey][ReplicatedClass:ToEnum("Wrap")] = cosmetics.Wrap end; if cosmetics.Charm then replicatedData[dataKey][ReplicatedClass:ToEnum("Charm")] = cosmetics.Charm end end; local result = originalNew(replicatedData, clientItem); if weaponPlayer == player and ua_equipped[weaponName] and ua_equipped[weaponName].Wrap and result._UpdateWrap then result:_UpdateWrap(); task.delay(0.1, function() if not result._destroyed then result:_UpdateWrap() end end) end; return result end end
        local originalGetViewModelImage = ItemLibrary.GetViewModelImageFromWeaponData; ItemLibrary.GetViewModelImageFromWeaponData = function(self2, weaponData, highRes) if not weaponData then return originalGetViewModelImage(self2, weaponData, highRes) end; local weaponName = weaponData.Name; local shouldShowSkin = (weaponData.Skin and ua_equipped[weaponName] and weaponData.Skin == ua_equipped[weaponName].Skin) or (viewingProfile == player and ua_equipped[weaponName] and ua_equipped[weaponName].Skin); if shouldShowSkin and ua_equipped[weaponName] and ua_equipped[weaponName].Skin then local skinInfo = self2.ViewModels[ua_equipped[weaponName].Skin.Name]; if skinInfo then return skinInfo[highRes and "ImageHighResolution" or "Image"] or skinInfo.Image end end; return originalGetViewModelImage(self2, weaponData, highRes) end
        pcall(function() local ViewProfile = require(player.PlayerScripts.Modules.Pages.ViewProfile); if ViewProfile and ViewProfile.Fetch then local originalFetch = ViewProfile.Fetch; ViewProfile.Fetch = function(self2, targetPlayer) viewingProfile = targetPlayer; return originalFetch(self2, targetPlayer) end end end)
        local ClientEntity; pcall(function() ClientEntity = require(player.PlayerScripts.Modules.ClientReplicatedClasses.ClientEntity) end)
        if ClientEntity and ClientEntity.ReplicateFromServer then local originalReplicateFromServer = ClientEntity.ReplicateFromServer; ClientEntity.ReplicateFromServer = function(self2, action, ...) if action == "FinisherEffect" then local args = {...}; local killerName = args[3]; local decodedKiller = killerName; if type(killerName) == "userdata" and EnumLibrary and EnumLibrary.FromEnum then local ok, decoded = pcall(EnumLibrary.FromEnum, EnumLibrary, killerName); if ok and decoded then decodedKiller = decoded end end; local isOurKill = tostring(decodedKiller) == player.Name or tostring(decodedKiller):lower() == player.Name:lower(); if isOurKill and lastUsedWeapon and ua_equipped[lastUsedWeapon] and ua_equipped[lastUsedWeapon].Finisher then local finisherData = ua_equipped[lastUsedWeapon].Finisher; local finisherEnum = finisherData.Enum; if not finisherEnum and EnumLibrary then local ok2, result2 = pcall(EnumLibrary.ToEnum, EnumLibrary, finisherData.Name); if ok2 and result2 then finisherEnum = result2 end end; if finisherEnum then args[1] = finisherEnum; return originalReplicateFromServer(self2, action, unpack(args)) end end end; return originalReplicateFromServer(self2, action, ...) end end
        loadUAConfig()
    end)
    if success then
        UnlockAllLoaded = true
        Console:Log("[Unlock All] Successfully loaded!", ACCENT_COLOR)
    else
        Console:Log("[Unlock All] Error: " .. tostring(err), Color3.new(1, 0, 0))
    end
end

-- // MAIN LIBRARY //
function Library:Window(title)
    local Window = {}
    local MainFrame = Utility:Create("Frame", {Name = "MainFrame", Parent = ScreenGui, BackgroundColor3 = BG_COLOR, BorderSizePixel = 0, Position = UDim2.new(0.5, -300, 0.5, -200), Size = UDim2.new(0, 600, 0, 450), ClipsDescendants = false})
    Utility:Create("UICorner", {Parent = MainFrame, CornerRadius = UDim.new(0, 6)})
    local Header = Utility:Create("Frame", {Parent = MainFrame, BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 50)})
    Utility:MakeDraggable(Header, MainFrame)
    local Logo = Utility:Create("TextLabel", {Parent = Header, Text = title, Font = Enum.Font.GothamBold, TextSize = 22, TextColor3 = Color3.new(1,1,1), BackgroundTransparency = 1, Position = UDim2.new(0.5, -100, 0, 0), Size = UDim2.new(0, 200, 1, 0), TextXAlignment = Enum.TextXAlignment.Center})
    local LogoGradient = Utility:Create("UIGradient", {Parent = Logo, Color = ColorSequence.new({ColorSequenceKeypoint.new(0, Color3.fromRGB(0,60,0)), ColorSequenceKeypoint.new(0.2, Color3.fromRGB(0,60,0)), ColorSequenceKeypoint.new(0.5, ACCENT_COLOR), ColorSequenceKeypoint.new(0.8, Color3.fromRGB(0,60,0)), ColorSequenceKeypoint.new(1, Color3.fromRGB(0,60,0))}), Rotation = 0})
    RunService.RenderStepped:Connect(function() if MainFrame.Visible then LogoGradient.Offset = Vector2.new((tick() * 2.2) % 3 - 1.5, 0) end end)

    local TabsContainer = Utility:Create("Frame", {Parent = MainFrame, BackgroundColor3 = Color3.fromRGB(15,15,15), BorderSizePixel = 0, Position = UDim2.new(0,0,1,-40), Size = UDim2.new(1,0,0,40), ClipsDescendants = true})
    Utility:Create("UICorner", {Parent = TabsContainer, CornerRadius = UDim.new(0, 6)})
    Utility:Create("UIListLayout", {Parent = TabsContainer, FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 0)})
    local ContentArea = Utility:Create("Frame", {Parent = MainFrame, BackgroundTransparency = 1, Position = UDim2.new(0,0,0,50), Size = UDim2.new(1,0,1,-90), ClipsDescendants = true})

    local Tabs = {}
    local FirstTab = true

    function Window:Tab(name)
        local Tab = {}
        local TabBtn = Utility:Create("TextButton", {Parent = TabsContainer, BackgroundTransparency = 1, Size = UDim2.new(0,0,1,0), Text = name, Font = Enum.Font.GothamBold, TextSize = 14, TextColor3 = TEXT_DIM, ZIndex = 2})
        local TabLine = Utility:Create("Frame", {Parent = TabBtn, BackgroundColor3 = ACCENT_COLOR, Size = UDim2.new(0.8,0,0,3), Position = UDim2.new(0.1,0,1,-3), BorderSizePixel = 0, BackgroundTransparency = 1})
        Utility:Create("UICorner", {Parent = TabLine, CornerRadius = UDim.new(1, 0)})
        local TabFrame = Utility:Create("ScrollingFrame", {Name = name.."Frame", Parent = ContentArea, Size = UDim2.new(1,0,1,0), BackgroundTransparency = 1, Visible = false, ScrollBarThickness = 2, ScrollBarImageColor3 = ACCENT_COLOR, CanvasSize = UDim2.new(0,0,0,0), AutomaticCanvasSize = Enum.AutomaticSize.Y, ClipsDescendants = true})
        Utility:Create("UIPadding", {Parent = TabFrame, PaddingTop = UDim.new(0,15), PaddingLeft = UDim.new(0,15), PaddingRight = UDim.new(0,15), PaddingBottom = UDim.new(0,15)})
        local LeftColumn = Utility:Create("Frame", {Name = "LeftColumn", Parent = TabFrame, BackgroundTransparency = 1, Size = UDim2.new(0.45,0,1,0), Position = UDim2.new(0,0,0,0)})
        Utility:Create("UIListLayout", {Parent = LeftColumn, SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 12)})
        local RightColumn = Utility:Create("Frame", {Name = "RightColumn", Parent = TabFrame, BackgroundTransparency = 1, Size = UDim2.new(0.45,0,1,0), Position = UDim2.new(0.51,0,0,0)})
        Utility:Create("UIListLayout", {Parent = RightColumn, SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 12)})

        TabBtn.MouseButton1Click:Connect(function()
            for _, t in pairs(Tabs) do t.Frame.Visible = false; TweenService:Create(t.Btn, TweenInfo.new(0.2), {TextColor3 = TEXT_DIM}):Play(); TweenService:Create(t.Line, TweenInfo.new(0.2), {BackgroundTransparency = 1}):Play() end
            TabFrame.Visible = true
            TweenService:Create(TabBtn, TweenInfo.new(0.2), {TextColor3 = ACCENT_COLOR}):Play()
            TweenService:Create(TabLine, TweenInfo.new(0.2), {BackgroundTransparency = 0}):Play()
        end)
        if FirstTab then TabFrame.Visible = true; TabBtn.TextColor3 = ACCENT_COLOR; TabLine.BackgroundTransparency = 0; FirstTab = false end
        table.insert(Tabs, {Frame = TabFrame, Btn = TabBtn, Line = TabLine})
        for _, t in pairs(Tabs) do t.Btn.Size = UDim2.new(1 / #Tabs, 0, 1, 0) end

        function Tab:Section(sectionTitle, side)
            local Section = {}
            local ParentCol = (side == "Right" and RightColumn) or LeftColumn
            local SectionFrame = Utility:Create("Frame", {Parent = ParentCol, BackgroundColor3 = SECTION_COLOR, Size = UDim2.new(1,0,0,0), AutomaticSize = Enum.AutomaticSize.Y, ClipsDescendants = true})
            Utility:Create("UICorner", {Parent = SectionFrame, CornerRadius = UDim.new(0, 5)})
            Utility:Create("TextLabel", {Parent = SectionFrame, Text = sectionTitle, Font = Enum.Font.GothamBold, TextSize = 12, TextColor3 = Color3.new(1,1,1), BackgroundTransparency = 1, Size = UDim2.new(1,-10,0,30), Position = UDim2.new(0,10,0,0), TextXAlignment = Enum.TextXAlignment.Left})
            local Container = Utility:Create("Frame", {Parent = SectionFrame, BackgroundTransparency = 1, Position = UDim2.new(0,0,0,30), Size = UDim2.new(1,0,0,0), AutomaticSize = Enum.AutomaticSize.Y})
            Utility:Create("UIListLayout", {Parent = Container, SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 6)})
            Utility:Create("UIPadding", {Parent = Container, PaddingBottom = UDim.new(0,10), PaddingLeft = UDim.new(0,8), PaddingRight = UDim.new(0,8)})

            function Section:Toggle(text, default, callback)
                local state = default or false
                local ToggleBtn = Utility:Create("TextButton", {Parent = Container, BackgroundTransparency = 1, Size = UDim2.new(1,0,0,24), Text = ""})
                local Label = Utility:Create("TextLabel", {Parent = ToggleBtn, Text = text, Font = Enum.Font.Gotham, TextSize = 12, TextColor3 = TEXT_DIM, BackgroundTransparency = 1, Size = UDim2.new(1,-30,1,0), TextXAlignment = Enum.TextXAlignment.Left})
                local Box = Utility:Create("Frame", {Parent = ToggleBtn, BackgroundColor3 = ELEMENT_BG, Size = UDim2.new(0,16,0,16), Position = UDim2.new(1,-16,0.5,-8)})
                Utility:Create("UICorner", {Parent = Box, CornerRadius = UDim.new(0, 4)})
                local function update()
                    if state then TweenService:Create(Box, TweenInfo.new(0.2), {BackgroundColor3 = ACCENT_COLOR}):Play(); TweenService:Create(Label, TweenInfo.new(0.2), {TextColor3 = TEXT_COLOR}):Play()
                    else TweenService:Create(Box, TweenInfo.new(0.2), {BackgroundColor3 = ELEMENT_BG}):Play(); TweenService:Create(Label, TweenInfo.new(0.2), {TextColor3 = TEXT_DIM}):Play() end
                    if callback then callback(state) end
                end
                ToggleBtn.MouseButton1Click:Connect(function() state = not state; update() end)
                update()
                Library.Registry[text] = {Type = "Toggle", Set = function(v) state = v; update() end, Get = function() return state end}
            end

            function Section:Button(text, callback)
                local Btn = Utility:Create("TextButton", {Parent = Container, BackgroundColor3 = ELEMENT_BG, Size = UDim2.new(1,0,0,26), Text = text, Font = Enum.Font.Gotham, TextSize = 12, TextColor3 = TEXT_COLOR, AutoButtonColor = false})
                Utility:Create("UICorner", {Parent = Btn, CornerRadius = UDim.new(0, 4)})
                Btn.MouseButton1Click:Connect(function()
                    TweenService:Create(Btn, TweenInfo.new(0.1), {BackgroundColor3 = ACCENT_COLOR}):Play()
                    task.wait(0.1)
                    TweenService:Create(Btn, TweenInfo.new(0.1), {BackgroundColor3 = ELEMENT_BG}):Play()
                    if callback then callback() end
                end)
            end

            function Section:Slider(text, min, max, default, callback)
                local value = default or min; local dragging = false
                local SliderFrame = Utility:Create("Frame", {Parent = Container, BackgroundTransparency = 1, Size = UDim2.new(1,0,0,36)})
                Utility:Create("TextLabel", {Parent = SliderFrame, Text = text, Font = Enum.Font.Gotham, TextSize = 12, TextColor3 = TEXT_DIM, BackgroundTransparency = 1, Size = UDim2.new(1,0,0,16), TextXAlignment = Enum.TextXAlignment.Left})
                local ValueLabel = Utility:Create("TextLabel", {Parent = SliderFrame, Text = tostring(value), Font = Enum.Font.Gotham, TextSize = 12, TextColor3 = TEXT_COLOR, BackgroundTransparency = 1, Size = UDim2.new(1,0,0,16), TextXAlignment = Enum.TextXAlignment.Right})
                local SlideBar = Utility:Create("Frame", {Parent = SliderFrame, BackgroundColor3 = ELEMENT_BG, Size = UDim2.new(1,0,0,6), Position = UDim2.new(0,0,0,22)}); Utility:Create("UICorner", {Parent = SlideBar, CornerRadius = UDim.new(1,0)})
                local Fill = Utility:Create("Frame", {Parent = SlideBar, BackgroundColor3 = ACCENT_COLOR, Size = UDim2.new(0,0,1,0)}); Utility:Create("UICorner", {Parent = Fill, CornerRadius = UDim.new(1,0)})
                local function updateSlider(input) local p = math.clamp((input.Position.X - SlideBar.AbsolutePosition.X) / SlideBar.AbsoluteSize.X, 0, 1); Fill.Size = UDim2.new(p,0,1,0); value = math.floor(min + ((max - min) * p)); ValueLabel.Text = tostring(value); if callback then callback(value) end end
                local function setVal(v) value = v; Fill.Size = UDim2.new((v - min)/(max - min),0,1,0); ValueLabel.Text = tostring(v); if callback then callback(v) end end
                SlideBar.InputBegan:Connect(function(input) if input.UserInputType == Enum.UserInputType.MouseButton1 then dragging = true; updateSlider(input) end end)
                UserInputService.InputEnded:Connect(function(input) if input.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false end end)
                UserInputService.InputChanged:Connect(function(input) if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then updateSlider(input) end end)
                setVal(default)
                Library.Registry[text] = {Type = "Slider", Set = setVal, Get = function() return value end}
            end

            function Section:Dropdown(text, options, callback)
                local isOpened = false; local selected = options[1] or "None"
                local DropFrame = Utility:Create("Frame", {Parent = Container, BackgroundTransparency = 1, Size = UDim2.new(1,0,0,42), ZIndex = 2})
                Utility:Create("TextLabel", {Parent = DropFrame, Text = text, Font = Enum.Font.Gotham, TextSize = 12, TextColor3 = TEXT_DIM, BackgroundTransparency = 1, Size = UDim2.new(1,0,0,16), TextXAlignment = Enum.TextXAlignment.Left})
                local MainBtn = Utility:Create("TextButton", {Parent = DropFrame, BackgroundColor3 = ELEMENT_BG, Size = UDim2.new(1,0,0,22), Position = UDim2.new(0,0,0,18), Text = "  "..selected, Font = Enum.Font.Gotham, TextSize = 12, TextColor3 = TEXT_COLOR, TextXAlignment = Enum.TextXAlignment.Left, AutoButtonColor = false})
                Utility:Create("UICorner", {Parent = MainBtn, CornerRadius = UDim.new(0, 4)})
                local Arrow = Utility:Create("ImageLabel", {Parent = MainBtn, Image = "rbxassetid://6031091004", BackgroundTransparency = 1, Size = UDim2.new(0,14,0,14), Position = UDim2.new(1,-20,0.5,-7), ImageColor3 = TEXT_DIM})
                local ListContainer = Utility:Create("Frame", {Parent = Container, BackgroundTransparency = 1, Size = UDim2.new(1,0,0,0), Visible = false, ClipsDescendants = true})
                local ListFrame = Utility:Create("Frame", {Parent = ListContainer, BackgroundColor3 = ELEMENT_BG, Size = UDim2.new(1,0,1,0)}); Utility:Create("UICorner", {Parent = ListFrame, CornerRadius = UDim.new(0, 4)}); Utility:Create("UIListLayout", {Parent = ListFrame, SortOrder = Enum.SortOrder.LayoutOrder})
                local function setSel(opt) selected = opt; MainBtn.Text = "  "..selected; if callback then callback(opt) end end
                for _, opt in pairs(options) do local OptBtn = Utility:Create("TextButton", {Parent = ListFrame, BackgroundTransparency = 1, Size = UDim2.new(1,0,0,22), Text = "  "..opt, Font = Enum.Font.Gotham, TextSize = 12, TextColor3 = TEXT_DIM, TextXAlignment = Enum.TextXAlignment.Left}); OptBtn.MouseButton1Click:Connect(function() setSel(opt); isOpened = false; ListContainer.Visible = false; ListContainer.Size = UDim2.new(1,0,0,0); TweenService:Create(Arrow, TweenInfo.new(0.2), {Rotation = 0}):Play() end) end
                MainBtn.MouseButton1Click:Connect(function() isOpened = not isOpened; if isOpened then ListContainer.Visible = true; TweenService:Create(ListContainer, TweenInfo.new(0.2), {Size = UDim2.new(1,0,0,math.min(#options*22,150))}):Play(); TweenService:Create(Arrow, TweenInfo.new(0.2), {Rotation = 180}):Play() else TweenService:Create(ListContainer, TweenInfo.new(0.2), {Size = UDim2.new(1,0,0,0)}):Play(); TweenService:Create(Arrow, TweenInfo.new(0.2), {Rotation = 0}):Play(); task.wait(0.2); ListContainer.Visible = false end end)
                Library.Registry[text] = {Type = "Dropdown", Set = setSel, Get = function() return selected end}
            end

            -- Refreshable Dropdown
            function Section:DynamicDropdown(text, getOptionsFn, callback)
                local isOpened = false
                local selected = "None"
                local DropFrame = Utility:Create("Frame", {Parent = Container, BackgroundTransparency = 1, Size = UDim2.new(1,0,0,42), ZIndex = 2})
                Utility:Create("TextLabel", {Parent = DropFrame, Text = text, Font = Enum.Font.Gotham, TextSize = 12, TextColor3 = TEXT_DIM, BackgroundTransparency = 1, Size = UDim2.new(1,0,0,16), TextXAlignment = Enum.TextXAlignment.Left})
                local MainBtn = Utility:Create("TextButton", {Parent = DropFrame, BackgroundColor3 = ELEMENT_BG, Size = UDim2.new(1,0,0,22), Position = UDim2.new(0,0,0,18), Text = "  "..selected, Font = Enum.Font.Gotham, TextSize = 12, TextColor3 = TEXT_COLOR, TextXAlignment = Enum.TextXAlignment.Left, AutoButtonColor = false})
                Utility:Create("UICorner", {Parent = MainBtn, CornerRadius = UDim.new(0, 4)})
                local Arrow = Utility:Create("ImageLabel", {Parent = MainBtn, Image = "rbxassetid://6031091004", BackgroundTransparency = 1, Size = UDim2.new(0,14,0,14), Position = UDim2.new(1,-20,0.5,-7), ImageColor3 = TEXT_DIM})
                local ListContainer = Utility:Create("Frame", {Parent = Container, BackgroundTransparency = 1, Size = UDim2.new(1,0,0,0), Visible = false, ClipsDescendants = true})
                local ListFrame = Utility:Create("Frame", {Parent = ListContainer, BackgroundColor3 = ELEMENT_BG, Size = UDim2.new(1,0,1,0)})
                Utility:Create("UICorner", {Parent = ListFrame, CornerRadius = UDim.new(0, 4)})
                local ListLayout = Utility:Create("UIListLayout", {Parent = ListFrame, SortOrder = Enum.SortOrder.LayoutOrder})

                local dropdownObj = {}

                local function setSel(opt)
                    selected = opt
                    MainBtn.Text = "  " .. selected
                    if callback then callback(opt) end
                end

                local function rebuildList()
                    for _, child in pairs(ListFrame:GetChildren()) do
                        if child:IsA("TextButton") then child:Destroy() end
                    end
                    local opts = getOptionsFn()
                    for _, opt in pairs(opts) do
                        local OptBtn = Utility:Create("TextButton", {Parent = ListFrame, BackgroundTransparency = 1, Size = UDim2.new(1,0,0,22), Text = "  "..opt, Font = Enum.Font.Gotham, TextSize = 12, TextColor3 = TEXT_DIM, TextXAlignment = Enum.TextXAlignment.Left})
                        OptBtn.MouseButton1Click:Connect(function()
                            setSel(opt)
                            isOpened = false
                            ListContainer.Visible = false
                            ListContainer.Size = UDim2.new(1,0,0,0)
                            TweenService:Create(Arrow, TweenInfo.new(0.2), {Rotation = 0}):Play()
                        end)
                    end
                    return opts
                end

                MainBtn.MouseButton1Click:Connect(function()
                    isOpened = not isOpened
                    if isOpened then
                        local opts = rebuildList()
                        ListContainer.Visible = true
                        local h = math.max(math.min(#opts * 22, 150), 22)
                        TweenService:Create(ListContainer, TweenInfo.new(0.2), {Size = UDim2.new(1,0,0,h)}):Play()
                        TweenService:Create(Arrow, TweenInfo.new(0.2), {Rotation = 180}):Play()
                    else
                        TweenService:Create(ListContainer, TweenInfo.new(0.2), {Size = UDim2.new(1,0,0,0)}):Play()
                        TweenService:Create(Arrow, TweenInfo.new(0.2), {Rotation = 0}):Play()
                        task.wait(0.2)
                        ListContainer.Visible = false
                    end
                end)

                function dropdownObj:Set(opt) setSel(opt) end
                function dropdownObj:Get() return selected end
                function dropdownObj:Refresh() rebuildList() end

                return dropdownObj
            end

            function Section:ColorPicker(text, default, callback)
                local color = default or Color3.new(1,1,1); local isOpened = false
                local PickerFrame = Utility:Create("Frame", {Parent = Container, BackgroundTransparency = 1, Size = UDim2.new(1,0,0,24), ZIndex = 2})
                Utility:Create("TextLabel", {Parent = PickerFrame, Text = text, Font = Enum.Font.Gotham, TextSize = 12, TextColor3 = TEXT_DIM, BackgroundTransparency = 1, Size = UDim2.new(1,-40,1,0), TextXAlignment = Enum.TextXAlignment.Left})
                local ColorPreview = Utility:Create("TextButton", {Parent = PickerFrame, BackgroundColor3 = color, Size = UDim2.new(0,30,0,14), Position = UDim2.new(1,-30,0.5,-7), Text = ""}); Utility:Create("UICorner", {Parent = ColorPreview, CornerRadius = UDim.new(0, 4)})
                local SlidersFrame = Utility:Create("Frame", {Parent = Container, BackgroundColor3 = ELEMENT_BG, Size = UDim2.new(1,0,0,0), ClipsDescendants = true, Visible = false}); Utility:Create("UICorner", {Parent = SlidersFrame, CornerRadius = UDim.new(0, 4)})
                local function CreateRGBSlider(comp, yPos) local sFrame = Utility:Create("Frame", {Parent = SlidersFrame, BackgroundTransparency = 1, Size = UDim2.new(1,-10,0,20), Position = UDim2.new(0,5,0,yPos)}); local bar = Utility:Create("Frame", {Parent = sFrame, BackgroundColor3 = Color3.fromRGB(60,60,60), Size = UDim2.new(1,0,0,4), Position = UDim2.new(0,0,0.5,-2)}); local fill = Utility:Create("Frame", {Parent = bar, BackgroundColor3 = (comp=="R" and Color3.new(1,0,0)) or (comp=="G" and Color3.new(0,1,0)) or Color3.new(0,0,1), Size = UDim2.new(0,0,1,0)}); local d = false; local function upd(input) local p = math.clamp((input.Position.X - bar.AbsolutePosition.X)/bar.AbsoluteSize.X, 0, 1); fill.Size = UDim2.new(p,0,1,0); local r,g,b = color.R, color.G, color.B; if comp=="R" then r=p end; if comp=="G" then g=p end; if comp=="B" then b=p end; color = Color3.new(r,g,b); ColorPreview.BackgroundColor3 = color; if callback then callback(color) end end; sFrame.InputBegan:Connect(function(i) if i.UserInputType == Enum.UserInputType.MouseButton1 then d=true; upd(i) end end); UserInputService.InputEnded:Connect(function(i) if i.UserInputType == Enum.UserInputType.MouseButton1 then d=false end end); UserInputService.InputChanged:Connect(function(i) if d and i.UserInputType == Enum.UserInputType.MouseMovement then upd(i) end end) end
                CreateRGBSlider("R", 5); CreateRGBSlider("G", 30); CreateRGBSlider("B", 55)
                ColorPreview.MouseButton1Click:Connect(function() isOpened = not isOpened; if isOpened then SlidersFrame.Visible = true; TweenService:Create(SlidersFrame, TweenInfo.new(0.2), {Size = UDim2.new(1,0,0,80)}):Play() else TweenService:Create(SlidersFrame, TweenInfo.new(0.2), {Size = UDim2.new(1,0,0,0)}):Play(); task.wait(0.2); SlidersFrame.Visible = false end end)
                Library.Registry[text] = {Type = "Color", Set = function(c) color = c; ColorPreview.BackgroundColor3 = c; if callback then callback(c) end end, Get = function() return color end}
            end

            function Section:Textbox(text, placeholder, callback)
                local container2 = Utility:Create("Frame", {Size = UDim2.new(1,0,0,36), BackgroundTransparency = 1, Parent = Container})
                Utility:Create("TextLabel", {Parent = container2, Size = UDim2.new(1,0,0.5,0), Text = text, Font = Enum.Font.Gotham, TextSize = 12, TextColor3 = TEXT_DIM, TextXAlignment = Enum.TextXAlignment.Left, BackgroundTransparency = 1})
                local box = Utility:Create("TextBox", {Parent = container2, Position = UDim2.new(0,0,0.5,0), Size = UDim2.new(1,0,0.5,0), BackgroundColor3 = ELEMENT_BG, Text = "", PlaceholderText = placeholder, TextColor3 = TEXT_COLOR, Font = Enum.Font.Gotham, TextSize = 12, ClearTextOnFocus = false})
                Utility:Create("UICorner", {Parent = box, CornerRadius = UDim.new(0, 4)})
                box.FocusLost:Connect(function() if callback then callback(box.Text) end end)
                return box
            end

            function Section:Label(text)
                local lbl = Utility:Create("TextLabel", {Parent = Container, Text = text, Font = Enum.Font.Gotham, TextSize = 11, TextColor3 = TEXT_DIM, BackgroundTransparency = 1, Size = UDim2.new(1,0,0,16), TextXAlignment = Enum.TextXAlignment.Left, TextWrapped = true})
                local obj = {}
                function obj:SetText(t) lbl.Text = t end
                return obj
            end

            return Section
        end
        return Tab
    end
    return Window
end

-- ============================================
-- // BUILD UI //
-- ============================================
local Window = Library:Window("minthack.eu")

-- 1. AIMBOT
local Aimbot = Window:Tab("Aimbot")
local AimbotMain = Aimbot:Section("Main", "Left")
AimbotMain:Toggle("Enabled", false, function(v) AimbotSettings.Enabled = v; Console:Log(v and "[Aimbot] Enabled" or "[Aimbot] Disabled", ACCENT_COLOR) end)
AimbotMain:Toggle("Team Check", false, function(v) AimbotSettings.TeamCheck = v end)
AimbotMain:Toggle("Visible Check", false, function(v) AimbotSettings.VisibleCheck = v end)
AimbotMain:Toggle("Sticky Aim", false, function(v) AimbotSettings.StickyAim = v end)
AimbotMain:Dropdown("Target Part", {"Head","HumanoidRootPart","UpperTorso","LowerTorso"}, function(v) AimbotSettings.TargetPart = v end)
AimbotMain:Dropdown("Activation", {"Hold RMB","Hold LMB","Toggle RMB","Always"}, function(v) if v=="Hold RMB" then AimbotSettings.ActivationKey=Enum.UserInputType.MouseButton2 elseif v=="Hold LMB" then AimbotSettings.ActivationKey=Enum.UserInputType.MouseButton1 elseif v=="Toggle RMB" then AimbotSettings.ActivationKey="ToggleRMB" else AimbotSettings.ActivationKey="Always" end end)
AimbotMain:Slider("Smoothing", 1, 50, 5, function(v) AimbotSettings.Smoothing = v end)
AimbotMain:Slider("Max Distance", 100, 5000, 1000, function(v) AimbotSettings.MaxDistance = v end)

local AimbotFOV = Aimbot:Section("FOV Circle", "Right")
AimbotFOV:Toggle("Show FOV", false, function(v) AimbotSettings.ShowFOV = v end)
AimbotFOV:Slider("FOV Radius", 50, 600, 200, function(v) AimbotSettings.FOVRadius = v; FOVCircle.Radius = v end)
AimbotFOV:ColorPicker("FOV Color", ACCENT_COLOR, function(v) AimbotSettings.FOVColor = v; FOVCircle.Color = v end)

local AimbotExtra = Aimbot:Section("Extra", "Right")
AimbotExtra:Toggle("Prediction", false, function(v) AimbotSettings.PredictionEnabled = v end)
AimbotExtra:Slider("Prediction Amount", 1, 30, 10, function(v) AimbotSettings.PredictionAmount = v / 100 end)
AimbotExtra:Toggle("Snap Line", false, function(v) AimbotSettings.SnapLine = v end)
AimbotExtra:ColorPicker("Snap Line Color", ACCENT_COLOR, function(v) AimbotSettings.SnapLineColor = v; SnapLine.Color = v end)
AimbotExtra:Toggle("Lock-On Notify", true, function(v) AimbotSettings.LockOnNotify = v end)

-- 2. VISUALS
local Visuals = Window:Tab("Visuals")
local ESPSection = Visuals:Section("ESP", "Left")
ESPSection:Toggle("Enabled", false, function(v) ESPLib.Enabled = v end)
ESPSection:Toggle("Boxes", false, function(v) ESPLib.ShowBox = v end)
ESPSection:Toggle("Names", false, function(v) ESPLib.ShowName = v end)
ESPSection:Toggle("Health", false, function(v) ESPLib.ShowHealth = v end)
ESPSection:Toggle("Distance", false, function(v) ESPLib.ShowDistance = v end)
ESPSection:Toggle("Tracers", false, function(v) ESPLib.ShowTracer = v end)
ESPSection:Toggle("Team Check", false, function(v) ESPLib.TeamCheck = v end)

local WorldSection = Visuals:Section("World", "Right")
WorldSection:Slider("FOV Changer", 70, 120, 70, function(v) Settings.FOV = v end)
WorldSection:Slider("Time Changer", 0, 24, 14, function(v) Lighting.ClockTime = v end)
WorldSection:Toggle("Fullbright", false, function(v) Settings.Fullbright = v end)
WorldSection:Toggle("Zoom (Key: C)", false, function(v) Settings.Zoom.Enabled = v end)
WorldSection:Slider("Zoom Value", 10, 60, 30, function(v) Settings.Zoom.Value = v end)
WorldSection:Dropdown("Removals", {"None","Grass"}, function(v) local t = workspace:FindFirstChildOfClass("Terrain"); if t then t.Decoration = (v ~= "Grass") end end)

-- 3. MISC
local Misc = Window:Tab("Misc")
local MovementSection = Misc:Section("Movement", "Left")
MovementSection:Toggle("Airjump", false, function(v) Settings.Airjump = v end)
local UnlockSection = Misc:Section("Game", "Left")
UnlockSection:Button("Unlock All", function() RunUnlockAll() end)
local OtherSection = Misc:Section("Other", "Right")
OtherSection:Toggle("Draw Console Output", true, function(v) Settings.Console = v; if Console.Gui then Console.Gui.Enabled = v end end)

-- 4. SETTINGS
local SettingsTab = Window:Tab("Settings")

-- CONFIG SECTION
local ConfigSection = SettingsTab:Section("Configs", "Left")

-- Config selector dropdown (dynamic, refreshes on open)
local ConfigDropdown = ConfigSection:DynamicDropdown("Select Config", function()
    local cfgs = ConfigSystem:GetConfigs()
    if #cfgs == 0 then return {"No configs"} end
    return cfgs
end, function(v)
    if v ~= "No configs" then
        ConfigSystem.SelectedConfig = v
    else
        ConfigSystem.SelectedConfig = ""
    end
end)

ConfigSystem.ConfigListDropdown = ConfigDropdown

ConfigSection:Button("⟳ Refresh List", function()
    ConfigDropdown:Refresh()
    Console:Log("[Config] List refreshed", TEXT_DIM)
end)

local ConfigNameInput = ""
ConfigSection:Textbox("New Config Name", "Enter name...", function(t) ConfigNameInput = t end)

ConfigSection:Button("💾 Save New Config", function()
    if ConfigNameInput == "" then Console:Log("[Config] Enter a name!", Color3.new(1,0,0)); return end
    local ok, err = ConfigSystem:Save(ConfigNameInput)
    if ok then
        Console:Log("[Config] Saved: " .. ConfigNameInput, ACCENT_COLOR)
        ConfigDropdown:Refresh()
        ConfigDropdown:Set(ConfigNameInput)
        ConfigSystem.SelectedConfig = ConfigNameInput
    else
        Console:Log("[Config] Save failed: " .. tostring(err), Color3.new(1,0,0))
    end
end)

ConfigSection:Button("📂 Load Selected", function()
    local sel = ConfigSystem.SelectedConfig
    if sel == "" or sel == "No configs" then Console:Log("[Config] Select a config!", Color3.new(1,0,0)); return end
    local ok, err = ConfigSystem:Load(sel)
    if ok then Console:Log("[Config] Loaded: " .. sel, ACCENT_COLOR)
    else Console:Log("[Config] Load failed: " .. tostring(err), Color3.new(1,0,0)) end
end)

ConfigSection:Button("📝 Overwrite Selected", function()
    local sel = ConfigSystem.SelectedConfig
    if sel == "" or sel == "No configs" then Console:Log("[Config] Select a config!", Color3.new(1,0,0)); return end
    local ok, err = ConfigSystem:Overwrite(sel)
    if ok then Console:Log("[Config] Overwritten: " .. sel, ACCENT_COLOR)
    else Console:Log("[Config] Overwrite failed: " .. tostring(err), Color3.new(1,0,0)) end
end)

ConfigSection:Button("🗑 Delete Selected", function()
    local sel = ConfigSystem.SelectedConfig
    if sel == "" or sel == "No configs" then Console:Log("[Config] Select a config!", Color3.new(1,0,0)); return end
    local ok, err = ConfigSystem:Delete(sel)
    if ok then
        Console:Log("[Config] Deleted: " .. sel, ACCENT_COLOR)
        ConfigSystem.SelectedConfig = ""
        ConfigDropdown:Refresh()
        ConfigDropdown:Set("None")
    else
        Console:Log("[Config] Delete failed: " .. tostring(err), Color3.new(1,0,0))
    end
end)

-- AUTOLOAD SECTION
local AutoloadSection = SettingsTab:Section("Autoload", "Right")
local curAutoload = ConfigSystem:GetAutoload()
local AutoloadLabel = AutoloadSection:Label("Current: " .. (curAutoload ~= "" and curAutoload or "None"))

local AutoloadDropdown = AutoloadSection:DynamicDropdown("Autoload Config", function()
    local cfgs = ConfigSystem:GetConfigs()
    table.insert(cfgs, 1, "None")
    return cfgs
end, function(v) end)

AutoloadSection:Button("✅ Set Autoload", function()
    local sel = AutoloadDropdown:Get()
    if sel == "None" or sel == "" or sel == "No configs" then
        ConfigSystem:SetAutoload("")
        AutoloadLabel:SetText("Current: None")
        Console:Log("[Autoload] Disabled", TEXT_DIM)
    else
        local path = CONFIG_FOLDER .. "/" .. sel .. ".cfg"
        local exists = false
        pcall(function() exists = isfile(path) end)
        if exists then
            ConfigSystem:SetAutoload(sel)
            AutoloadLabel:SetText("Current: " .. sel)
            Console:Log("[Autoload] Set: " .. sel, ACCENT_COLOR)
        else
            Console:Log("[Autoload] Config not found!", Color3.new(1,0,0))
        end
    end
end)

AutoloadSection:Button("❌ Clear Autoload", function()
    ConfigSystem:SetAutoload("")
    AutoloadLabel:SetText("Current: None")
    Console:Log("[Autoload] Cleared", TEXT_DIM)
end)

-- AUTO RE-EXECUTE SECTION
local ReexecSection = SettingsTab:Section("Auto Re-Execute", "Right")
local isAutoExec = AutoExecSystem:IsEnabled()
local AutoExecLabel = ReexecSection:Label("Status: " .. (isAutoExec and "Enabled" or "Disabled"))

ReexecSection:Toggle("Auto Execute on Rejoin", isAutoExec, function(v)
    if v then
        -- Сохраняем скрипт в autoexec
        pcall(function()
            if not isfolder("autoexec") then makefolder("autoexec") end
            -- Сохраняем лоадер который перезапустит скрипт
            local source = getgenv().__minthack_source
            if source then
                writefile("autoexec/minthack.lua", source)
            else
                -- Фоллбэк: пишем loadstring с URL если есть
                writefile("autoexec/minthack.lua", '-- minthack auto-execute\ngetgenv().__minthack_loaded = nil\nloadstring(readfile("minthack_main.lua"))()')
                -- Сохраняем основной скрипт если можем
            end
        end)
        AutoExecLabel:SetText("Status: Enabled")
        Console:Log("[AutoExec] Enabled - script will run on rejoin", ACCENT_COLOR)
    else
        AutoExecSystem:Disable()
        AutoExecLabel:SetText("Status: Disabled")
        Console:Log("[AutoExec] Disabled", TEXT_DIM)
    end
end)

ReexecSection:Button("Save Script for Rejoin", function()
    pcall(function()
        if not isfolder("autoexec") then makefolder("autoexec") end
        -- Создаём минимальный лоадер
        local loaderCode = [[
-- minthack auto-execute loader
getgenv().__minthack_loaded = nil
if isfile("minthack_main.lua") then
    loadstring(readfile("minthack_main.lua"))()
end
]]
        writefile("autoexec/minthack.lua", loaderCode)
        Console:Log("[AutoExec] Loader saved to autoexec/minthack.lua", ACCENT_COLOR)
        Console:Log("[AutoExec] Make sure minthack_main.lua exists!", Color3.fromRGB(255, 200, 0))
    end)
end)

-- LUA API
local LuaSection = SettingsTab:Section("Lua API", "Right")
local ScriptToExec = ""
LuaSection:Textbox("Script Code", "print('hello')", function(t) ScriptToExec = t end)
LuaSection:Button("Execute", function()
    local f, err = loadstring(ScriptToExec)
    if f then getgenv().minthack = {create_window = function(t) return Library:Window(t) end, log = function(t, c) Console:Log(t, c) end}; f(); Console:Log("Script Executed", ACCENT_COLOR)
    else Console:Log("Error: "..err, Color3.new(1,0,0)) end
end)

-- ============================================
-- // AIMBOT LOGIC //
-- ============================================
local aimToggled = false
UserInputService.InputBegan:Connect(function(input, processed)
    if processed then return end
    if AimbotSettings.ActivationKey == "ToggleRMB" then
        if input.UserInputType == Enum.UserInputType.MouseButton2 then
            aimToggled = not aimToggled
            if not aimToggled then AimbotSettings.CurrentTarget = nil; AimbotSettings.Locked = false end
        end
    end
end)

-- ============================================
-- // MAIN RENDER LOOP //
-- ============================================
RunService.RenderStepped:Connect(function()
    if Settings.Zoom.Enabled and UserInputService:IsKeyDown(Settings.Zoom.Key) then Camera.FieldOfView = Settings.Zoom.Value else Camera.FieldOfView = Settings.FOV end
    if Settings.Fullbright then Lighting.Ambient = Color3.new(1,1,1); Lighting.Brightness = 2; Lighting.OutdoorAmbient = Color3.new(1,1,1); Lighting.GlobalShadows = false
    else Lighting.Ambient = OriginalLighting.Ambient; Lighting.Brightness = OriginalLighting.Brightness; Lighting.OutdoorAmbient = OriginalLighting.OutdoorAmbient; Lighting.GlobalShadows = OriginalLighting.GlobalShadows end

    local mousePos = UserInputService:GetMouseLocation()
    FOVCircle.Position = Vector2.new(mousePos.X, mousePos.Y); FOVCircle.Visible = AimbotSettings.ShowFOV and AimbotSettings.Enabled; FOVCircle.Radius = AimbotSettings.FOVRadius; FOVCircle.Color = AimbotSettings.FOVColor

    if AimbotSettings.Enabled then
        local isActive = false
        if AimbotSettings.ActivationKey == "Always" then isActive = true
        elseif AimbotSettings.ActivationKey == "ToggleRMB" then isActive = aimToggled
        elseif typeof(AimbotSettings.ActivationKey) == "EnumItem" then isActive = UserInputService:IsMouseButtonPressed(AimbotSettings.ActivationKey) end
        if isActive then
            if not (AimbotSettings.StickyAim and AimbotSettings.CurrentTarget and IsAlive(AimbotSettings.CurrentTarget)) then
                local newTarget = GetClosestPlayer()
                if newTarget ~= AimbotSettings.CurrentTarget then AimbotSettings.CurrentTarget = newTarget; if newTarget and AimbotSettings.LockOnNotify then Console:Log("[Aimbot] Locked: " .. newTarget.Name, ACCENT_COLOR) end end
            end
            local target = AimbotSettings.CurrentTarget
            if target and IsAlive(target) then
                local char = target.Character; local targetPart = char:FindFirstChild(AimbotSettings.TargetPart) or char:FindFirstChild("Head")
                if targetPart then
                    local targetPos = GetPredictedPosition(target, targetPart); local screenPos, onScreen = Camera:WorldToViewportPoint(targetPos)
                    if onScreen then local cm = UserInputService:GetMouseLocation(); local ts = Vector2.new(screenPos.X, screenPos.Y); local delta = (ts - cm) / AimbotSettings.Smoothing; mousemoverel(delta.X, delta.Y)
                        if AimbotSettings.SnapLine then SnapLine.From = Vector2.new(cm.X, cm.Y); SnapLine.To = ts; SnapLine.Color = AimbotSettings.SnapLineColor; SnapLine.Visible = true else SnapLine.Visible = false end
                    else SnapLine.Visible = false end
                end
            else AimbotSettings.CurrentTarget = nil; SnapLine.Visible = false end
        else if not AimbotSettings.StickyAim then AimbotSettings.CurrentTarget = nil end; SnapLine.Visible = false end
    else AimbotSettings.CurrentTarget = nil; SnapLine.Visible = false end
end)

-- ============================================
-- // INPUT //
-- ============================================
UserInputService.InputBegan:Connect(function(input, proc)
    if not proc and input.KeyCode == Enum.KeyCode.Space and Settings.Airjump then
        local char = Players.LocalPlayer.Character; if char and char:FindFirstChild("Humanoid") then char.Humanoid:ChangeState(Enum.HumanoidStateType.Jumping) end
    end
    if input.KeyCode == Enum.KeyCode.Insert then ScreenGui.Enabled = not ScreenGui.Enabled end
end)

-- ============================================
-- // AUTOLOAD CONFIG ON START //
-- ============================================
task.defer(function()
    task.wait(1)
    local autoloadName = ConfigSystem:GetAutoload()
    if autoloadName and autoloadName ~= "" then
        local ok, err = ConfigSystem:Load(autoloadName)
        if ok then
            Console:Log("[Autoload] Loaded: " .. autoloadName, ACCENT_COLOR)
        else
            Console:Log("[Autoload] Failed: " .. tostring(err), Color3.new(1, 0.3, 0.3))
        end
    end
end)

-- ============================================
-- // REJOIN HANDLER //
-- ============================================
Players.LocalPlayer.OnTeleport:Connect(function(state)
    if state == Enum.TeleportState.Started then
        -- Перезапускаем скрипт после телепорта
        pcall(function()
            getgenv().__minthack_loaded = nil
            local queueteleport = syn and syn.queue_on_teleport or queue_on_teleport or fluxus and fluxus.queue_on_teleport
            if queueteleport then
                -- Пытаемся получить source
                local source = getgenv().__minthack_source
                if source then
                    queueteleport(source)
                elseif isfile("minthack_main.lua") then
                    queueteleport('getgenv().__minthack_loaded = nil; loadstring(readfile("minthack_main.lua"))()')
                end
                Console:Log("[Rejoin] Script queued for next server", ACCENT_COLOR)
            end
        end)
    end
end)

-- // EXPORT //
getgenv().minthack = {
    create_window = function(t) return Library:Window(t) end,
    log = function(t, c) Console:Log(t, c) end,
    aimbot = AimbotSettings,
    config = ConfigSystem
}

Console:Log("[minthack] Loaded successfully!", ACCENT_COLOR)
Console:Log("[minthack] Press INSERT to toggle UI", TEXT_DIM)