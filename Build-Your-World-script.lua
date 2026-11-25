-- Build Your World! Script (placeId 80392427444524)
-- Self-contained keyless GUI: Auto Farm, Auto Build, Speed/Jump, ESP, Teleports, Anti-AFK
-- UI library: Linoria (mstudio45/LinoriaLib), loaded from GitHub raw
-- Run with any executor, no key required.

local GameId = 80392427444524 -- Build Your World! by Cozy Games

-- Services (cloneref-safe)
local cloneref = cloneref or clonereference or function(inst) return inst end
local Players = cloneref(game:GetService("Players"))
local RunService = cloneref(game:GetService("RunService"))
local UserInputService = cloneref(game:GetService("UserInputService"))
local TeleportService = cloneref(game:GetService("TeleportService"))
local VirtualUser = cloneref(game:GetService("VirtualUser"))
local Workspace = cloneref(game:GetService("Workspace"))
local ReplicatedStorage = cloneref(game:GetService("ReplicatedStorage"))

local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera

-- ============ STATE ============
local State = {
    AutoFarm = false,
    AutoBuild = false,
    Noclip = false,
    EspPlayers = false,
    EspBlocks = false,
    AntiAFK = true,
    FarmDelay = 0.6,
    TeleportTarget = nil,
    SavedPosition = nil,
}

-- ============ UI (Linoria) ============
local ThemeManager
local SaveManager
local ok, Library = pcall(function()
    return loadstring(game:HttpGet("https://raw.githubusercontent.com/mstudio45/LinoriaLib/main/Library.lua"))()
end)
if not ok or not Library then
    -- hard fallback: minimal notification, no GUI
    LocalPlayer:Kick("Build Your World script: failed to load UI library. Check internet connection / executor whitelist.")
    return
end
pcall(function()
    ThemeManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/mstudio45/LinoriaLib/main/addons/ThemeManager.lua"))()
end)
pcall(function()
    SaveManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/mstudio45/LinoriaLib/main/addons/SaveManager.lua"))()
end)

local Window = Library:CreateWindow({
    Title = "Build Your World! Hub [keyless]",
    Center = true,
    AutoShow = true,
})
local Tabs = {
    Main = Window:AddTab("Main"),
    Movement = Window:AddTab("Movement"),
    Visuals = Window:AddTab("Visuals"),
    Teleports = Window:AddTab("Teleports"),
    Misc = Window:AddTab("Misc"),
    Settings = Window:AddTab("UI Settings"),
}

-- ============ HELPERS ============
local function getCharacter()
    local char = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
    return char, char:FindFirstChildOfClass("Humanoid"), char:FindFirstChild("HumanoidRootPart")
end

local function forEachRemote(callback)
    -- discover remotes used by building/farming systems
    for _, obj in ipairs(ReplicatedStorage:GetDescendants()) do
        if obj:IsA("RemoteEvent") or obj:IsA("RemoteFunction") then
            callback(obj)
        end
    end
end

local function fireBestRemote(keyword, args)
    -- try to fire the remote whose name matches a keyword (farm/place/harvest/sell)
    local found = nil
    forEachRemote(function(r)
        local n = string.lower(r.Name)
        if string.find(n, keyword, 1, true) and not found then
            found = r
        end
    end)
    if found then
        if found:IsA("RemoteEvent") then
            found:FireServer(unpack(args))
        else
            pcall(function() found:InvokeServer(unpack(args)) end)
        end
        return true
    end
    return false
end

-- ============ MAIN TAB: Auto Farm / Auto Build ============
local FarmGroup = Tabs.Main:AddLeftGroupbox("Auto Farm")
FarmGroup:AddToggle("AutoFarmToggle", {
    Text = "Auto Farm (collect resources)",
    Default = false,
    Tooltip = "Repeatedly fires harvest/collect remotes and walks to nearest resource",
    Callback = function(v)
        State.AutoFarm = v
        if v then
            task.spawn(function()
                while State.AutoFarm do
                    pcall(function()
                        -- try common remote names used by build/sandbox games
                        for _, kw in ipairs({ "collect", "harvest", "gather", "mine", "break", "farm" }) do
                            if fireBestRemote(kw, {}) then break end
                        end
                        -- fallback: click nearest resource model
                        local char, hum, root = getCharacter()
                        if root then
                            local nearest, nd = nil, math.huge
                            for _, m in ipairs(Workspace:GetDescendants()) do
                                if (m:IsA("TouchTransmitter") or (m:IsA("ClickDetector") and m.Parent and m.Parent:IsA("Model")))
                                    and m.Parent and m.Parent:IsA("BasePart") then
                                    local d = (m.Parent.Position - root.Position).Magnitude
                                    if d < nd then nd, nearest = d, m end
                                end
                            end
                            if nearest then
                                if nearest:IsA("ClickDetector") then
                                    fireclickdetector(nearest)
                                elseif nearest.Parent then
                                    local r = root.CFrame
                                    firetouchinterest(nearest.Parent, root, 0)
                                    task.wait(0.05)
                                    firetouchinterest(nearest.Parent, root, 1)
                                end
                            end
                        end
                    end)
                    task.wait(State.FarmDelay)
                end
            end)
        end
    end,
})
FarmGroup:AddSlider("FarmDelaySlider", {
    Text = "Farm delay (seconds)",
    Default = 0.6, Min = 0.1, Max = 2, Rounding = 1,
    Callback = function(v) State.FarmDelay = v end,
})

local BuildGroup = Tabs.Main:AddRightGroupbox("Auto Build")
BuildGroup:AddToggle("AutoBuildToggle", {
    Text = "Auto Build (spam place remote)",
    Default = false,
    Tooltip = "Fires placement remote for blueprint/ghost blocks when available",
    Callback = function(v)
        State.AutoBuild = v
        if v then
            task.spawn(function()
                while State.AutoBuild do
                    pcall(function()
                        for _, kw in ipairs({ "place", "build", "paint", "spawnblock", "create" }) do
                            if fireBestRemote(kw, {}) then break end
                        end
                    end)
                    task.wait(0.3)
                end
            end)
        end
    end,
})

-- ============ MOVEMENT TAB ============
local MoveGroup = Tabs.Movement:AddLeftGroupbox("Movement")
MoveGroup:AddToggle("SpeedToggle", {
    Text = "Custom WalkSpeed",
    Default = false,
    Callback = function(v)
        local _, hum = getCharacter()
        if hum then hum.WalkSpeed = v and 100 or 16 end
    end,
})
MoveGroup:AddSlider("SpeedSlider", {
    Text = "WalkSpeed",
    Default = 100, Min = 16, Max = 500, Rounding = 0,
    Callback = function(v)
        local _, hum = getCharacter()
        if hum then hum.WalkSpeed = v end
    end,
})
MoveGroup:AddToggle("JumpToggle", {
    Text = "Infinite Jump",
    Default = false,
    Callback = function(v)
        _G.InfiniteJump = v
    end,
})
MoveGroup:AddToggle("NoclipToggle", {
    Text = "Noclip",
    Default = false,
    Callback = function(v) State.Noclip = v end,
})

RunService.Stepped:Connect(function()
    if State.Noclip then
        local char = LocalPlayer.Character
        if char then
            for _, p in ipairs(char:GetDescendants()) do
                if p:IsA("BasePart") and p.CanCollide then
                    p.CanCollide = false
                end
            end
        end
    end
end)

UserInputService.JumpRequest:Connect(function()
    if _G.InfiniteJump then
        local char = LocalPlayer.Character
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        if hum then
            hum:ChangeState(Enum.HumanoidStateType.Jumping)
        end
    end
end)

-- ============ VISUALS TAB: ESP ============
local EspGroup = Tabs.Visuals:AddLeftGroupbox("ESP")
local espHighlights = {}

local function clearEsp()
    for _, h in ipairs(espHighlights) do h:Destroy() end
    espHighlights = {}
end

local function applyEsp()
    clearEsp()
    if State.EspPlayers then
        for _, pl in ipairs(Players:GetPlayers()) do
            if pl ~= LocalPlayer and pl.Character then
                local h = Instance.new("Highlight")
                h.FillColor = Color3.fromRGB(255, 80, 80)
                h.OutlineColor = Color3.fromRGB(255, 255, 255)
                h.Parent = pl.Character
                table.insert(espHighlights, h)
            end
        end
    end
    if State.EspBlocks then
        -- highlight resource/collectible models in workspace
        for _, m in ipairs(Workspace:GetChildren()) do
            if m:IsA("Model") and m:FindFirstChildWhichIsA("BasePart") and m.Name ~= LocalPlayer.Name then
                local okh = pcall(function()
                    local h = Instance.new("Highlight")
                    h.FillColor = Color3.fromRGB(80, 200, 255)
                    h.OutlineColor = Color3.fromRGB(255, 255, 255)
                    h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
                    h.Parent = m
                    table.insert(espHighlights, h)
                end)
            end
        end
    end
end

EspGroup:AddToggle("EspPlayersToggle", {
    Text = "Player ESP",
    Default = false,
    Callback = function(v) State.EspPlayers = v; applyEsp() end,
})
EspGroup:AddToggle("EspBlocksToggle", {
    Text = "Resource/Block ESP",
    Default = false,
    Callback = function(v) State.EspBlocks = v; applyEsp() end,
})
Players.PlayerAdded:Connect(function()
    task.wait(1)
    applyEsp()
end)

-- ============ TELEPORTS TAB ============
local TpGroup = Tabs.Teleports:AddLeftGroupbox("Teleport")
TpGroup:AddButton({
    Text = "Teleport to Spawn",
    Tooltip = "Uses SpawnLocation if present",
    Func = function()
        local spawn = Workspace:FindFirstChildOfClass("SpawnLocation")
        if spawn then
            local _, _, root = getCharacter()
            if root then root.CFrame = spawn.CFrame + Vector3.new(0, 5, 0) end
        end
    end,
})
TpGroup:AddButton({
    Text = "Teleport to Random Player",
    Func = function()
        local others = {}
        for _, pl in ipairs(Players:GetPlayers()) do
            if pl ~= LocalPlayer and pl.Character and pl.Character:FindFirstChild("HumanoidRootPart") then
                table.insert(others, pl)
            end
        end
        if #others > 0 then
            local target = others[math.random(#others)]
            local _, _, root = getCharacter()
            if root then
                root.CFrame = target.Character.HumanoidRootPart.CFrame + Vector3.new(0, 3, 0)
            end
        end
    end,
})
TpGroup:AddButton({
    Text = "Save Position",
    Func = function()
        local _, _, root = getCharacter()
        if root then State.SavedPosition = root.CFrame end
    end,
})
TpGroup:AddButton({
    Text = "Load Saved Position",
    Func = function()
        if State.SavedPosition then
            local _, _, root = getCharacter()
            if root then root.CFrame = State.SavedPosition end
        end
    end,
})

-- ============ MISC TAB ============
local MiscGroup = Tabs.Misc:AddLeftGroupbox("Misc")
MiscGroup:AddToggle("AntiAFKToggle", {
    Text = "Anti-AFK (auto rejoin)",
    Default = true,
    Callback = function(v) State.AntiAFK = v end,
})
LocalPlayer.Idled:Connect(function()
    if State.AntiAFK then
        VirtualUser:CaptureController()
        VirtualUser:ClickButton2(Vector2.new())
    end
end)
MiscGroup:AddButton({
    Text = "Rejoin Server",
    Func = function()
        TeleportService:Teleport(game.PlaceId, LocalPlayer)
    end,
})
MiscGroup:AddButton({
    Text = "Server Hop",
    Func = function()
        pcall(function()
            local http = game and cloneref(game:GetService("HttpService"))
            local req = (http and http.RequestAsync) and http or nil
            -- use executor request if available
            local ok2, body = pcall(function()
                if request then
                    local r = request({ Url = "https://games.roblox.com/v1/games/" .. GameId .. "/servers/Public?sortOrder=Desc&limit=100", Method = "GET" })
                    return r.Body
                end
                return http:GetAsync("https://games.roblox.com/v1/games/" .. GameId .. "/servers/Public?sortOrder=Desc&limit=100")
            end)
            if ok2 and body then
                local data = http:JSONDecode(body)
                local servers = {}
                for _, s in ipairs(data.data or {}) do
                    if s.id and s.playing and s.maxPlayers and s.playing < s.maxPlayers then
                        table.insert(servers, s.id)
                    end
                end
                if #servers > 0 then
                    TeleportService:TeleportToPlaceInstance(GameId, servers[math.random(#servers)], LocalPlayer)
                end
            end
        end)
    end,
})

-- ============ SETTINGS TAB ============
local MenuGroup = Tabs.Settings:AddLeftGroupbox("Menu")
MenuGroup:AddButton({
    Text = "Unload",
    Func = function()
        clearEsp()
        Library:Unload()
    end,
})
MenuGroup:AddLabel("Menu bind"):AddKeyPicker("MenuBind", {
    Default = "RightShift",
    NoUI = true,
    Text = "Menu keybind",
})
Library.ToggleKeybind = Options.MenuBind

if ThemeManager then pcall(function() ThemeManager:SetLibrary(Library) end) end
if SaveManager then pcall(function() SaveManager:SetLibrary(Library) end) end
if SaveManager then pcall(function() SaveManager:IgnoreThemeSettings(); SaveManager:SetFolder("BuildYourWorld"); SaveManager:BuildFolderStructure() end) end
if ThemeManager then pcall(function() ThemeManager:SetFolder("BuildYourWorld"); ThemeManager:ApplyTheme("Midnight") end) end
if SaveManager then pcall(function() SaveManager:LoadAutoloadConfig() end) end

Library:Notify("Build Your World! Hub loaded (keyless)", 5)
