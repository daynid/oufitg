--[[
    Outfit Hub V2 - Fait par Dayni
    Menu ameliore via IA
]]

if _G.__OH_CLEANUP then
    pcall(_G.__OH_CLEANUP)
end

local cleanupList = {}
local function addCleanup(fn)
    cleanupList[#cleanupList + 1] = fn
end

local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local VirtualUser = game:GetService("VirtualUser")
local TeleportService = game:GetService("TeleportService")
local localPlayer = Players.LocalPlayer
if not localPlayer then
    for _ = 1, 600 do
        task.wait()
        localPlayer = Players.LocalPlayer
        if localPlayer then break end
    end
end
local mouse = localPlayer:GetMouse()
local camera = workspace.CurrentCamera
if not camera then
    for _ = 1, 200 do
        task.wait()
        camera = workspace.CurrentCamera
        if camera then break end
    end
end

local FILENAME = "MesTenuesSauvegardees.json"
local SETTINGS_FILENAME = "OutfitStudioSettings.json"
local HISTORY_FILENAME = "OutfitHistory.json"
local CATEGORIES_FILENAME = "OutfitCategories.json"
local COLOR_PROPERTIES = {
    "HeadColor", "TorsoColor", "LeftArmColor", "RightArmColor", "LeftLegColor", "RightLegColor"
}

local ACCESSORY_PROPERTIES = {
    "HatAccessory", "HairAccessory", "FaceAccessory", "NeckAccessory",
    "ShouldersAccessory", "FrontAccessory", "BackAccessory", "WaistAccessory"
}

local function normalizeAssetUrl(v)
    if type(v) == "number" then
        return "rbxassetid://" .. tostring(v)
    end
    if type(v) == "string" then
        v = string.gsub(v, "rbxassetid://", "")
        local id = string.match(v, "%d+")
        if id then return "rbxassetid://" .. id end
    end
    return v
end

local THEMES = {
    dark = {
        bg = Color3.fromRGB(12, 12, 16),
        panel = Color3.fromRGB(22, 22, 28),
        panelLight = Color3.fromRGB(30, 30, 38),
        panelHover = Color3.fromRGB(36, 36, 46),
        teal = Color3.fromRGB(0, 210, 190),
        tealDark = Color3.fromRGB(0, 160, 145),
        tealGlow = Color3.fromRGB(0, 255, 220),
        text = Color3.fromRGB(225, 225, 235),
        muted = Color3.fromRGB(110, 110, 130),
        off = Color3.fromRGB(50, 50, 60),
        border = Color3.fromRGB(38, 38, 48),
        borderLight = Color3.fromRGB(45, 45, 56),
        row = Color3.fromRGB(240, 240, 240),
        rowBg = Color3.fromRGB(28, 30, 40),
        del = Color3.fromRGB(220, 55, 55),
        delHover = Color3.fromRGB(255, 70, 70),
        success = Color3.fromRGB(50, 200, 120),
        warning = Color3.fromRGB(255, 180, 50),
        discord = Color3.fromRGB(88, 101, 242),
        discordHover = Color3.fromRGB(105, 115, 255),
    },
    light = {
        bg = Color3.fromRGB(232, 234, 238),
        panel = Color3.fromRGB(248, 248, 250),
        panelLight = Color3.fromRGB(255, 255, 255),
        panelHover = Color3.fromRGB(240, 242, 246),
        teal = Color3.fromRGB(0, 170, 155),
        tealDark = Color3.fromRGB(0, 140, 128),
        tealGlow = Color3.fromRGB(0, 200, 180),
        text = Color3.fromRGB(28, 30, 38),
        muted = Color3.fromRGB(110, 115, 128),
        off = Color3.fromRGB(200, 203, 210),
        border = Color3.fromRGB(210, 213, 220),
        borderLight = Color3.fromRGB(218, 221, 228),
        row = Color3.fromRGB(30, 32, 40),
        rowBg = Color3.fromRGB(225, 228, 232),
        del = Color3.fromRGB(210, 55, 55),
        delHover = Color3.fromRGB(235, 65, 65),
        success = Color3.fromRGB(40, 180, 110),
        warning = Color3.fromRGB(230, 165, 40),
        discord = Color3.fromRGB(88, 101, 242),
        discordHover = Color3.fromRGB(105, 115, 255),
    },
}
local themeName = "dark"
local C = THEMES[themeName]
local FONT = Enum.Font.GothamMedium
local FONT_BOLD = Enum.Font.GothamBold
local FONT_LIGHT = Enum.Font.Gotham

local applyTheme
local saveUiPositions
local uiRoot
local repaintGameBtn = nil

local function setTheme(name)
    local old = THEMES[themeName]
    themeName = name
    C = THEMES[name] or THEMES.dark
    if applyTheme then applyTheme(old, C) end
    if saveUiPositions then saveUiPositions() end
end

local DEFAULT_THEME_COLORS = {}
local colorKeyLookup = {}
for _themeName, pal in pairs(THEMES) do
    DEFAULT_THEME_COLORS[_themeName] = {}
    for _key, _val in pairs(pal) do
        DEFAULT_THEME_COLORS[_themeName][_key] = _val
        colorKeyLookup[tostring(_val)] = _key
    end
end

local customColors = {}

local function colorToHex(c)
    return string.format("#%02X%02X%02X",
        math.floor(c.R * 255 + 0.5),
        math.floor(c.G * 255 + 0.5),
        math.floor(c.B * 255 + 0.5))
end

local function hexToColor(h)
    if type(h) ~= "string" then return nil end
    h = h:gsub("#", ""):gsub("%s", "")
    if #h ~= 6 then return nil end
    local r = tonumber(h:sub(1, 2), 16)
    local g = tonumber(h:sub(3, 4), 16)
    local b = tonumber(h:sub(5, 6), 16)
    if not r or not g or not b then return nil end
    return Color3.fromRGB(r, g, b)
end

local function applyCustomColors()
    for theme, overrides in pairs(customColors) do
        local pal = THEMES[theme]
        if pal then
            for key, rgb in pairs(overrides) do
                if pal[key] and type(rgb) == "table" then
                    pcall(function()
                        pal[key] = Color3.fromRGB(rgb[1] or 0, rgb[2] or 0, rgb[3] or 0)
                    end)
                end
            end
        end
    end
end

local sessionOutfits = {}
local webhookURL = ""
local MAX_OUTFITS = 50
searchFilter = ""

espEnabled = false
espCache = {}
espConnections = {}
clickModeActive = false
noclipEnabled = false
flyEnabled = false
infJumpEnabled = false
antiAfkEnabled = false
walkSpeedValue = 16
jumpPowerValue = 50
flySpeed = 60
noclipConn = nil
flyConn = nil
lastJumpTime = 0
spinConn = nil
fullbrightConn = nil
spinEnabled = false
spinSpeed = 15
fullbrightEnabled = false
autoEquipEnabled = false
autoEquipOutfitName = nil
zoomDistance = 50
outfitHistory = {}
MAX_HISTORY = 20
keybindNoclip = nil
keybindFly = nil
keybindSpeed = nil
keybindClick = nil
keybindClickTp = nil
clickTpEnabled = false
rpNamePhrases = {}
_savedChatTag = ""
_savedChatTagColor = "#FF0000"
_savedChatNameColor = "#FFFFFF"
_savedChatTextColor = "#FFFFFF"
rpAutoEnabled = false
savedRpName = ""
savedRpLabel = nil
autoAfkStatusEnabled = false
outfitCategories = {}
spectateTarget = nil
spectateConn = nil
spectateStatusLabel = nil
perfHudLabel = nil
perfHudConn = nil

local function new(className, props, parent)
    local instance = Instance.new(className)
    for key, value in pairs(props) do
        instance[key] = value
    end
    if parent then instance.Parent = parent end
    return instance
end

local function withCorner(parent, radius)
    return nil
end

local function withStroke(parent, color, thickness, transparency)
    return new("UIStroke", { Color = color, Thickness = thickness or 1, Transparency = transparency or 0 }, parent)
end

local function withPadding(parent, t, b, l, r)
    return new("UIPadding", {
        PaddingTop = UDim.new(0, t or 0),
        PaddingBottom = UDim.new(0, b or 0),
        PaddingLeft = UDim.new(0, l or 0),
        PaddingRight = UDim.new(0, r or 0),
    }, parent)
end

local function brightenColor(color, amount)
    return Color3.new(
        math.clamp(color.R + amount, 0, 1),
        math.clamp(color.G + amount, 0, 1),
        math.clamp(color.B + amount, 0, 1)
    )
end

local function darkenColor(color, amount)
    return brightenColor(color, -amount)
end

local function tw(instance, props, duration, style, direction)
    local info = TweenInfo.new(
        duration or 0.25,
        style or Enum.EasingStyle.Quint,
        direction or Enum.EasingDirection.Out
    )
    local t = TweenService:Create(instance, info, props)
    t:Play()
    return t
end

local function serializeProperties(props)
    if type(props) ~= "table"then return {} end
    local clean = {}
    for k, v in pairs(props) do
        if typeof(v) == "Color3" then
            clean[k] = { __isColor = true, r = v.R, g = v.G, b = v.B }
        elseif type(v) == "table"then
            clean[k] = serializeProperties(v)
        elseif typeof(v) ~= "Instance" and type(v) ~= "function" then
            clean[k] = v
        end
    end
    return clean
end

local function deserializeProperties(props)
    if type(props) ~= "table"then return {} end
    local real = {}
    for k, v in pairs(props) do
        if type(v) == "table"then
            if v.__isColor then
                real[k] = Color3.new(v.r, v.g, v.b)
            else
                real[k] = deserializeProperties(v)
            end
        elseif type(v) == "string" and table.find(COLOR_PROPERTIES, k) then
            local ok, col = pcall(function() return Color3.fromHex(v) end)
            real[k] = (ok and col) or Color3.fromRGB(255, 255, 255)
        else
            real[k] = v
        end
    end
    return real
end

local function extractPropertiesFromDescription(desc)
    if not desc then return {} end
    local props = {}
    local propertiesToFetch = {
        "HatAccessory", "HairAccessory", "FaceAccessory", "NeckAccessory", "ShouldersAccessory", "FrontAccessory", "BackAccessory", "WaistAccessory",
        "Shirt", "Pants", "GraphicTShirt", "Face", "Head", "Torso", "LeftArm", "RightArm", "LeftLeg", "RightLeg",
        "ClimbAnimation", "FallAnimation", "IdleAnimation", "JumpAnimation", "MoodAnimation", "PoseAnimation", "RunAnimation", "SwimAnimation", "WalkAnimation",
        "HeadColor", "TorsoColor", "LeftArmColor", "RightArmColor", "LeftLegColor", "RightLegColor",
        "DepthScale", "HeightScale", "WidthScale", "HeadScale", "BodyTypeScale", "ProportionScale", "BodyHeightScale", "BodyWidthScale", "StaticFacialAnimation"
    }
    for _, prop in ipairs(propertiesToFetch) do
        pcall(function() props[prop] = desc[prop] end)
    end
    return props
end

local function getOutfitFromCharacter(char)
    if not char then return nil, nil end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hum then return nil, nil end
    local ok, desc = pcall(function() return hum:GetAppliedDescription() end)
    if not ok or not desc then return nil, nil end
    return extractPropertiesFromDescription(desc), hum.RigType
end

local function loadSavedOutfits()
    if isfile and isfile(FILENAME) then
        local ok, data = pcall(function() return HttpService:JSONDecode(readfile(FILENAME)) end)
        if ok and type(data) == "table"then
            for k, v in pairs(data) do sessionOutfits[k] = v end
        end
    end
    return sessionOutfits
end

local function saveOutfitsToFile()
    if not writefile then return end
    local ok, res = pcall(function() return HttpService:JSONEncode(sessionOutfits) end)
    if ok then pcall(function() writefile(FILENAME, res) end) end
end

local function resolveRigType(rigType)
    if typeof(rigType) == "EnumItem"then return rigType end
    for _, item in ipairs(Enum.HumanoidRigType:GetEnumItems()) do
        if item.Value == rigType then return item end
    end
    return Enum.HumanoidRigType.R15
end

local catalogModule = nil

local function tryLoadCatalogModule()
    if catalogModule then return catalogModule end
    local viewPlayer = localPlayer.PlayerGui:FindFirstChild("ViewPlayer")
    if viewPlayer then
        local sf = viewPlayer:FindFirstChild("Main", true)
            and viewPlayer.Main:FindFirstChild("Menu", true)
            and viewPlayer.Main.Menu:FindFirstChild("ScrollingFrame", true)
            and viewPlayer.Main.Menu.ScrollingFrame:FindFirstChild("WearOutfit", true)
        if sf then
            local ok, conns = pcall(function() return getconnections(sf.Activated) end)
            if ok and conns and conns[1] then
                local ok2, ups = pcall(function() return getupvalues(conns[1].Function) end)
                if ok2 and typeof(ups[3]) == "table" and typeof(ups[3].ToDictionary) == "function" then
                    catalogModule = ups[3]
                end
            end
        end
    end
    return catalogModule
end

local function stealOutfitFromCharacter(targetPlayer)
    if not targetPlayer or not targetPlayer.Character then return end
    local hum = targetPlayer.Character:FindFirstChildOfClass("Humanoid")
    if not hum then return end
    local ok, desc = pcall(function() return hum:GetAppliedDescription() end)
    if not ok or not desc or not desc:IsA("HumanoidDescription") then return end
    local rigType = hum.RigType

    local remote = ReplicatedStorage:FindFirstChild("CatalogGuiRemote") or ReplicatedStorage:FindFirstChild("CatalogGuiRemote", true)
    if not remote then
        for _, obj in ipairs(ReplicatedStorage:GetDescendants()) do
            if (obj:IsA("RemoteEvent") or obj:IsA("RemoteFunction")) and string.find(string.lower(obj.Name), "catalog") then
                remote = obj
                break
            end
        end
    end
    if not remote then return end

    local mod = tryLoadCatalogModule()
    if mod and typeof(mod.ToDictionary) == "function" then
        pcall(function()
            remote:InvokeServer({
                Action = "CreateAndWearHumanoidDescription",
                Properties = mod:ToDictionary(desc),
                RigType = rigType,
            })
        end)
    else
        local cleanProps = serializeProperties(extractPropertiesFromDescription(desc))
        pcall(function()
            remote:InvokeServer({
                Action = "CreateAndWearHumanoidDescription",
                Properties = cleanProps,
                RigType = resolveRigType(rigType),
            })
        end)
    end
end

local function wearOutfit(outfitData)
    if not outfitData or not outfitData.Properties then return end
    local cleanProperties = deserializeProperties(outfitData.Properties)
    local remote = ReplicatedStorage:FindFirstChild("CatalogGuiRemote") or ReplicatedStorage:FindFirstChild("CatalogGuiRemote", true)
    if not remote then
        for _, obj in ipairs(ReplicatedStorage:GetDescendants()) do
            if (obj:IsA("RemoteEvent") or obj:IsA("RemoteFunction")) and string.find(string.lower(obj.Name), "catalog") then
                remote = obj
                break
            end
        end
    end
    if not remote then return end

    local mod = tryLoadCatalogModule()
    if mod and typeof(mod.ToDictionary) == "function" then
        local realProps = deserializeProperties(outfitData.Properties)
        local d = Instance.new("HumanoidDescription")
        local buildErrors = {}
        for k, v in pairs(realProps) do
            local setOk = pcall(function() d[k] = v end)
            if not setOk then
                local ok2 = false
                if table.find(ACCESSORY_PROPERTIES, k) then
                    ok2 = pcall(function() d[k] = normalizeAssetUrl(v) end)
                end
                if not ok2 then buildErrors[#buildErrors + 1] = k end
            end
        end
        pcall(function()
            local dict = mod:ToDictionary(d)
            for _, k in ipairs(buildErrors) do
                if dict[k] == nil then
                    dict[k] = normalizeAssetUrl(realProps[k])
                end
            end
            remote:InvokeServer({
                Action = "CreateAndWearHumanoidDescription",
                Properties = dict,
                RigType = resolveRigType(outfitData.RigType),
            })
        end)
        return
    end

    pcall(function()
        remote:InvokeServer({
            Action = "CreateAndWearHumanoidDescription",
            Properties = cleanProperties,
            RigType = resolveRigType(outfitData.RigType),
        })
    end)
end

local function loadUiPositions()
    if isfile and isfile(SETTINGS_FILENAME) then
        local ok, data = pcall(function() return HttpService:JSONDecode(readfile(SETTINGS_FILENAME)) end)
        if ok and type(data) == "table"then
            if type(data.Webhook) == "string"then webhookURL = data.Webhook end
            if type(data.Theme) == "string" and THEMES[data.Theme] then
                themeName = data.Theme
                C = THEMES[themeName]
            end
            if type(data.AutoEquipEnabled) == "boolean" then autoEquipEnabled = data.AutoEquipEnabled end
            if type(data.AutoEquipOutfit) == "string" then autoEquipOutfitName = data.AutoEquipOutfit end
            if type(data.Fullbright) == "boolean" then fullbrightEnabled = data.Fullbright end
            if type(data.ZoomDistance) == "number" then zoomDistance = data.ZoomDistance end
            if type(data.WalkSpeed) == "number" then walkSpeedValue = data.WalkSpeed end
            if type(data.JumpPower) == "number" then jumpPowerValue = data.JumpPower end
            if type(data.SpinEnabled) == "boolean" then spinEnabled = data.SpinEnabled end
            if type(data.SpinSpeed) == "number" then spinSpeed = data.SpinSpeed end
            if type(data.FlySpeed) == "number" then flySpeed = data.FlySpeed end
            if type(data.KeybindNoclip) == "string" and data.KeybindNoclip ~= "" then keybindNoclip = Enum.KeyCode[data.KeybindNoclip] end
            if type(data.KeybindFly) == "string" and data.KeybindFly ~= "" then keybindFly = Enum.KeyCode[data.KeybindFly] end
            if type(data.KeybindSpeed) == "string" and data.KeybindSpeed ~= "" then keybindSpeed = Enum.KeyCode[data.KeybindSpeed] end
            if type(data.KeybindClick) == "string" and data.KeybindClick ~= "" then keybindClick = Enum.KeyCode[data.KeybindClick] end
            if type(data.KeybindClickTp) == "string" and data.KeybindClickTp ~= "" then keybindClickTp = Enum.KeyCode[data.KeybindClickTp] end
            if type(data.ClickTp) == "boolean" then clickTpEnabled = data.ClickTp end
            if type(data.RpNamePhrases) == "table" then rpNamePhrases = data.RpNamePhrases end
            if type(data.Esp) == "boolean" then espEnabled = data.Esp end
            if type(data.Noclip) == "boolean" then noclipEnabled = data.Noclip end
            if type(data.Fly) == "boolean" then flyEnabled = data.Fly end
            if type(data.InfJump) == "boolean" then infJumpEnabled = data.InfJump end
            if type(data.AntiAfk) == "boolean" then antiAfkEnabled = data.AntiAfk end
            if type(data.AutoAfkStatus) == "boolean" then autoAfkStatusEnabled = data.AutoAfkStatus end
            if type(data.ClickMode) == "boolean" then clickModeActive = data.ClickMode end
            if type(data.RpAuto) == "boolean" then rpAutoEnabled = data.RpAuto end
            if type(data.RpName) == "string" then savedRpName = data.RpName end
            if type(data.ChatTag) == "string" then _savedChatTag = data.ChatTag end
            if type(data.ChatTagColor) == "string" then _savedChatTagColor = data.ChatTagColor end
            if type(data.ChatNameColor) == "string" then _savedChatNameColor = data.ChatNameColor end
            if type(data.ChatTextColor) == "string" then _savedChatTextColor = data.ChatTextColor end
            if type(data.CustomColors) == "table" then
                customColors = data.CustomColors
                applyCustomColors()
            end
        end
    end
end

saveUiPositions = function()
    if not writefile then return end
    local ok, data = pcall(function()
        return HttpService:JSONEncode({
            Webhook = webhookURL,
            Theme = themeName,
            AutoEquipEnabled = autoEquipEnabled,
            AutoEquipOutfit = autoEquipOutfitName,
            Fullbright = fullbrightEnabled,
            ZoomDistance = zoomDistance,
            WalkSpeed = walkSpeedValue,
            JumpPower = jumpPowerValue,
            SpinEnabled = spinEnabled,
            SpinSpeed = spinSpeed,
            FlySpeed = flySpeed,
            KeybindNoclip = keybindNoclip and keybindNoclip.Name or nil,
            KeybindFly = keybindFly and keybindFly.Name or nil,
            KeybindSpeed = keybindSpeed and keybindSpeed.Name or nil,
            KeybindClick = keybindClick and keybindClick.Name or nil,
            KeybindClickTp = keybindClickTp and keybindClickTp.Name or nil,
            ClickTp = clickTpEnabled,
            RpNamePhrases = rpNamePhrases,
            ChatTag = _savedChatTag,
            ChatTagColor = _savedChatTagColor,
            ChatNameColor = _savedChatNameColor,
            ChatTextColor = _savedChatTextColor,
            Esp = espEnabled,
            Noclip = noclipEnabled,
            Fly = flyEnabled,
            InfJump = infJumpEnabled,
            AntiAfk = antiAfkEnabled,
            AutoAfkStatus = autoAfkStatusEnabled,
            ClickMode = clickModeActive,
            RpAuto = rpAutoEnabled,
            RpName = savedRpName,
            CustomColors = customColors,
        })
    end)
    if ok then pcall(function() writefile(SETTINGS_FILENAME, data) end) end
end

applyTheme = function(oldPal, newPal)
    if not uiRoot then return end
    local swap = {}
    for k, v in pairs(oldPal) do
        swap[tostring(v)] = newPal[k]
    end
    local function fixColor(c)
        return swap[tostring(c)] or c
    end
    local function fixInstance(inst)
        if inst:IsA("GuiObject") then
            inst.BackgroundColor3 = fixColor(inst.BackgroundColor3)
        end
        if inst:IsA("TextLabel") or inst:IsA("TextButton") or inst:IsA("TextBox") then
            inst.TextColor3 = fixColor(inst.TextColor3)
        end
        if inst:IsA("ImageLabel") or inst:IsA("ImageButton") then
            inst.ImageColor3 = fixColor(inst.ImageColor3)
        end
        if inst:IsA("UIStroke") then
            inst.Color = fixColor(inst.Color)
        end
        if inst:IsA("ScrollingFrame") then
            inst.ScrollBarImageColor3 = fixColor(inst.ScrollBarImageColor3)
        end
    end
    for _, inst in ipairs(uiRoot:GetDescendants()) do
        fixInstance(inst)
    end
    if repaintGameBtn then repaintGameBtn() end
end

local function sendWebhook(url, payload)
    local headers = { ["Content-Type"] = "application/json"}
    if request then
        local success = pcall(function() return request({ Url = url, Method = "POST", Headers = headers, Body = payload }) end)
        return success
    elseif syn and syn.request then
        local success = pcall(function() return syn.request({ Url = url, Method = "POST", Headers = headers, Body = payload }) end)
        return success
    else
        return pcall(function()
            HttpService:PostAsync(url, payload, Enum.HttpContentType.ApplicationJson)
        end)
    end
end

local function exportOutfitsToDiscord()
    local url = webhookURL
    if url == "" then return false end
    local rawProps, rigType = getOutfitFromCharacter(localPlayer.Character)
    if not rawProps then return false end
    local currentOutfit = {
        Properties = serializeProperties(rawProps),
        RigType = (rigType or Enum.HumanoidRigType.R15).Value
    }
    local body = HttpService:JSONEncode(currentOutfit)
    if #body > 1500 then body = string.sub(body, 1, 1500) .. "\n..."end
    local payload = HttpService:JSONEncode({
        content = "**OutfitStudio - Skin actuel**\n```json\n".. body .. "```",
    })
    return sendWebhook(url, payload)
end

local function applyMovement(char)
    if not char then return end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if hum then
        hum.WalkSpeed = walkSpeedValue
        hum.JumpPower = jumpPowerValue
    end
end

local function setNoclip(state)
    noclipEnabled = state
    if state then
        if noclipConn then pcall(function() noclipConn:Disconnect() end) end
        noclipConn = RunService.Stepped:Connect(function()
            if not noclipEnabled then return end
            local char = localPlayer.Character
            if not char then return end
            for _, part in ipairs(char:GetDescendants()) do
                if part:IsA("BasePart") then
                    part.CanCollide = false
                end
            end
        end)
    else
        if noclipConn then
            pcall(function() noclipConn:Disconnect() end)
            noclipConn = nil
        end
    end
end

local function startFly()
    if flyConn then pcall(function() flyConn:Disconnect() end) end
    local char = localPlayer.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if not root then return end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if hum then hum.PlatformStand = true end

    local bodyVelocity = Instance.new("BodyVelocity")
    bodyVelocity.MaxForce = Vector3.new(100000, 100000, 100000)
    bodyVelocity.Velocity = Vector3.new(0, 0, 0)
    for _, v in ipairs(root:GetChildren()) do
        if v:IsA("BodyVelocity") or v:IsA("BodyGyro") then
            pcall(function() v:Destroy() end)
        end
    end
    bodyVelocity.Parent = root

    local bodyGyro = Instance.new("BodyGyro")
    bodyGyro.MaxTorque = Vector3.new(0, 0, 0)
    bodyGyro.P = 100000
    bodyGyro.Parent = root

    flyConn = RunService.RenderStepped:Connect(function(dt)
        if not flyEnabled then return end
        local c = localPlayer.Character
        local r = c and c:FindFirstChild("HumanoidRootPart")
        if not r then return end
        local camCF = camera and camera.CFrame or CFrame.new()
        local dir = Vector3.new(0, 0, 0)
        if UserInputService:IsKeyDown(Enum.KeyCode.W) then dir = dir + camCF.LookVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.S) then dir = dir - camCF.LookVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.A) then dir = dir - camCF.RightVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.D) then dir = dir + camCF.RightVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.Space) then dir = dir + Vector3.new(0, 1, 0) end
        if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then dir = dir - Vector3.new(0, 1, 0) end
        if dir.Magnitude > 0 then dir = dir.Unit * flySpeed end
        bodyVelocity.Velocity = dir
        bodyGyro.CFrame = camCF
    end)
end

local function stopFly()
    if flyConn then
        pcall(function() flyConn:Disconnect() end)
        flyConn = nil
    end
    local char = localPlayer.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if root then
        for _, v in ipairs(root:GetChildren()) do
            if v:IsA("BodyVelocity") or v:IsA("BodyGyro") then
                pcall(function() v:Destroy() end)
            end
        end
    end
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if hum then hum.PlatformStand = false end
end

local notificationGui = nil

local function showNotification(text, duration)
    if not uiRoot then return end
    if notificationGui then pcall(function() notificationGui:Destroy() end) end
    local notif = new("Frame", {
        Size = UDim2.new(0, 300, 0, 40),
        Position = UDim2.new(0.5, -150, 1, 60),
        BackgroundColor3 = C.panel,
        ZIndex = 50,
    }, uiRoot)
    withCorner(notif, 10)
    withStroke(notif, C.teal, 1)
    new("TextLabel", {
        Text = text,
        TextSize = 13,
        TextColor3 = C.text,
        Font = FONT,
        BackgroundTransparency = 1,
        Size = UDim2.new(1, -20, 1, 0),
        Position = UDim2.new(0, 10, 0, 0),
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 51,
    }, notif)
    notificationGui = notif
    tw(notif, { Position = UDim2.new(0.5, -150, 1, -50) }, 0.3, Enum.EasingStyle.Back)
    task.delay(duration or 2, function()
        if notif and notif.Parent then
            tw(notif, { Position = UDim2.new(0.5, -150, 1, 60) }, 0.25)
            task.wait(0.25)
            if notif and notif.Parent then notif:Destroy() end
            if notificationGui == notif then notificationGui = nil end
        end
    end)
end

local function teleportToPlayer(player)
    if not player then return false end
    local char = localPlayer.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if not root or not root.Parent then return false end
    local tChar = player.Character
    local tRoot = tChar and tChar:FindFirstChild("HumanoidRootPart")
    if not tRoot then
        local deadline = os.clock() + 5
        while os.clock() < deadline do
            task.wait(0.2)
            tChar = player.Character
            tRoot = tChar and tChar:FindFirstChild("HumanoidRootPart")
            if tRoot then break end
        end
    end
    if not tRoot or not tRoot.Parent then return false end
    local cf = tRoot.CFrame * CFrame.new(0, 0, 6)
    local deadline = os.clock() + 0.6
    while os.clock() < deadline do
        if not root.Parent or not tRoot.Parent then break end
        pcall(function()
            root.CFrame = cf
            root.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
        end)
        task.wait(0.03)
    end
    return true
end

local function stopSpectate()
    if spectateConn then
        pcall(function() spectateConn:Disconnect() end)
        spectateConn = nil
    end
    spectateTarget = nil
    if spectateStatusLabel then spectateStatusLabel.Text = "" end
    pcall(function()
        camera.CameraType = Enum.CameraType.Custom
    end)
end

local function startSpectate(player)
    if not player then return end
    stopSpectate()
    spectateTarget = player
    spectateConn = RunService.RenderStepped:Connect(function()
        local target = spectateTarget
        if not target or not target.Parent then
            stopSpectate()
            return
        end
        local tChar = target.Character
        local tRoot = tChar and tChar:FindFirstChild("HumanoidRootPart")
        if not tRoot or not tRoot.Parent then return end
        pcall(function() camera.CameraType = Enum.CameraType.Scriptable end)
        local targetCF = tRoot.CFrame * CFrame.new(0, 3, 9)
        camera.CFrame = camera.CFrame:Lerp(targetCF, 0.15)
    end)
    if spectateStatusLabel then spectateStatusLabel.Text = "Spectate: " .. player.Name end
    showNotification("Spectate: " .. player.Name)
end

local function antiAfkLoop()
    while antiAfkEnabled do
        pcall(function()
            VirtualUser:CaptureController()
            VirtualUser:ClickButton2(Vector2.new())
        end)
        task.wait(120)
    end
end

local function setSpin(state)
    spinEnabled = state
    if state then
        if spinConn then pcall(function() spinConn:Disconnect() end) end
        spinConn = RunService.RenderStepped:Connect(function(dt)
            if not spinEnabled then return end
            local char = localPlayer.Character
            local root = char and char:FindFirstChild("HumanoidRootPart")
            if root then
                root.CFrame = root.CFrame * CFrame.Angles(0, math.rad(spinSpeed), 0)
            end
        end)
    else
        if spinConn then
            pcall(function() spinConn:Disconnect() end)
            spinConn = nil
        end
    end
end

local function setFullbright(state)
    fullbrightEnabled = state
    if state then
        pcall(function()
            Lighting.Ambient = Color3.fromRGB(178, 178, 178)
            Lighting.Brightness = 2
            Lighting.ClockTime = 14
            Lighting.FogEnd = 100000
            Lighting.GlobalShadows = false
            Lighting.FogStart = 0
            for _, v in ipairs(Lighting:GetDescendants()) do
                if v:IsA("Atmosphere") then v.Density = 0 end
                if v:IsA("BloomEffect") then v.Enabled = false end
            end
        end)
        if fullbrightConn then pcall(function() fullbrightConn:Disconnect() end) end
        fullbrightConn = RunService.RenderStepped:Connect(function()
            if not fullbrightEnabled then return end
            pcall(function()
                Lighting.Ambient = Color3.fromRGB(178, 178, 178)
                Lighting.Brightness = 2
                Lighting.GlobalShadows = false
                Lighting.FogEnd = 100000
            end)
        end)
    else
        pcall(function()
            Lighting.Ambient = Color3.fromRGB(0, 0, 0)
            Lighting.Brightness = 1
            Lighting.ClockTime = 12
            Lighting.FogEnd = 100000
            Lighting.GlobalShadows = true
            for _, v in ipairs(Lighting:GetDescendants()) do
                if v:IsA("Atmosphere") then v.Density = 0.3 end
            end
        end)
        if fullbrightConn then
            pcall(function() fullbrightConn:Disconnect() end)
            fullbrightConn = nil
        end
    end
end

local function setZoomDistance(dist)
    zoomDistance = dist
    pcall(function()
        localPlayer.CameraMaxZoomDistance = dist
        localPlayer.CameraMinZoomDistance = 0.5
    end)
    pcall(function()
        camera.MaxZoomDistance = dist
        camera.MinZoomDistance = 0.5
    end)
end

local function setAutoAfkStatus(state)
    autoAfkStatusEnabled = state
    if state then
        showNotification("AFK Status ON")
        task.spawn(function()
            while autoAfkStatusEnabled do
                pcall(function()
                    game:GetService("ReplicatedStorage").Events.UpdatePlayerStatus:FireServer("[AFK]")
                end)
                task.wait(1)
            end
        end)
    else
        showNotification("AFK Status OFF")
    end
end

local function rpAutoLoop()
    while rpAutoEnabled do
        if #rpNamePhrases == 0 then break end
        local chosen = rpNamePhrases[math.random(1, #rpNamePhrases)]
        for i = 1, #chosen do
            if not rpAutoEnabled then break end
            local partial = string.sub(chosen, 1, i)
            pcall(function()
                game.ReplicatedStorage.Events.SettingsRemoteFunction:InvokeServer({
                    Action = "SetDisplayName",
                    DisplayName = partial
                })
            end)
            task.wait(0.5)
        end
        if rpAutoEnabled and chosen ~= "" then
            savedRpName = chosen
            pcall(function() saveUiPositions() end)
            if savedRpLabel then savedRpLabel.Text = "RP sauvegarde: " .. chosen end
        end
        if not rpAutoEnabled then break end
        task.wait(2)
    end
end

local function rejoinServer()
    showNotification("Rejoint du serveur en cours...")
    task.spawn(function()
        local ok, err = pcall(function()
            if game.JobId and game.JobId ~= "" then
                TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, localPlayer)
            else
                TeleportService:Teleport(game.PlaceId, localPlayer)
            end
        end)
        if not ok then
            showNotification("Erreur rejoin: " .. tostring(err))
        end
    end)
end

local function fetchUrl(url)
    local httpRequest = (request or (syn and syn.request) or (http and http.request))
    if httpRequest then
        local response = httpRequest({ Url = url, Method = "GET" })
        return response.Body or response.body
    elseif game.HttpGet then
        return game:HttpGet(url)
    end
    return nil
end

local function serverHop()
    showNotification("Recherche d'un nouveau serveur...")
    task.spawn(function()
        local ok, err = pcall(function()
            local cursor = ""
            local candidates = {}
            local maxPages = 3

            for _ = 1, maxPages do
                local url = string.format(
                    "https://games.roblox.com/v1/games/%d/servers/Public?sortOrder=Desc&limit=100%s",
                    game.PlaceId,
                    cursor ~= "" and ("&cursor=" .. cursor) or ""
                )

                local body = fetchUrl(url)
                if not body then
                    showNotification("HTTP non disponible")
                    return
                end

                local data = HttpService:JSONDecode(body)
                if data and data.data then
                    for _, server in ipairs(data.data) do
                        if server.id ~= game.JobId
                           and server.playing
                           and server.playing < server.maxPlayers then
                            table.insert(candidates, server)
                        end
                    end
                end

                if #candidates > 0 then break end
                if not data or not data.nextPageCursor then break end

                cursor = data.nextPageCursor
            end

            if #candidates > 0 then
                local chosen = candidates[math.random(1, #candidates)]
                showNotification("Teleportation vers un serveur (" .. chosen.playing .. "/" .. chosen.maxPlayers .. ")...")
                TeleportService:TeleportToPlaceInstance(game.PlaceId, chosen.id, localPlayer)
            else
                showNotification("Aucun serveur disponible trouve")
            end
        end)
        if not ok then
            showNotification("Erreur server hop: " .. tostring(err))
        end
    end)
end

local function addToHistory(outfitName)
    for i, h in ipairs(outfitHistory) do
        if h.name == outfitName then
            table.remove(outfitHistory, i)
            break
        end
    end
    table.insert(outfitHistory, 1, { name = outfitName, time = os.time() })
    if #outfitHistory > MAX_HISTORY then
        table.remove(outfitHistory)
    end
    if writefile then
        pcall(function() writefile(HISTORY_FILENAME, HttpService:JSONEncode(outfitHistory)) end)
    end
end

local function loadHistory()
    if isfile and isfile(HISTORY_FILENAME) then
        local ok, data = pcall(function() return HttpService:JSONDecode(readfile(HISTORY_FILENAME)) end)
        if ok and type(data) == "table" then
            outfitHistory = data
        end
    end
end

local function saveCategories()
    if writefile then
        pcall(function() writefile(CATEGORIES_FILENAME, HttpService:JSONEncode(outfitCategories)) end)
    end
end

local function loadCategories()
    if isfile and isfile(CATEGORIES_FILENAME) then
        local ok, data = pcall(function() return HttpService:JSONDecode(readfile(CATEGORIES_FILENAME)) end)
        if ok and type(data) == "table" then
            outfitCategories = data
        end
    end
end

local function getOutfitCategory(outfitName)
    return outfitCategories[outfitName] or "General"
end

local function setOutfitCategory(outfitName, cat)
    outfitCategories[outfitName] = cat
    saveCategories()
end

loadHistory()
loadCategories()

local function destroyESP()
    for _, data in pairs(espCache) do
        if data and data.gui then
            pcall(function() data.gui:Destroy() end)
        end
    end
    espCache = {}
    for _, conns in pairs(espConnections) do
        for _, conn in ipairs(conns) do
            pcall(function() conn:Disconnect() end)
        end
    end
    espConnections = {}
end

local function setEspInfoText(data)
    if not data or not data.infoLabel then return end
    local parts = {}
    if data.lastDist then
        parts[#parts + 1] = data.lastDist .. "m"
    end
    if data.friendCount ~= nil then
        parts[#parts + 1] = data.friendCount .. (data.friendCount == 1 and " ami" or " amis")
    end
    data.infoLabel.Text = table.concat(parts, "| ")
end

local function fetchFriendCount(player)
    task.spawn(function()
        local ok, pages = pcall(function()
            return Players:GetFriendsAsync(player.UserId)
        end)
        if not ok or not pages then return end
        local count = 0
        repeat
            local pageOk, page = pcall(function() return pages:GetCurrentPage() end)
            if pageOk and type(page) == "table"then
                count = count + #page
            end
            local advOk = pcall(function()
                pages:AdvanceToNextPageAsync()
            end)
        until pages.IsFinished or not advOk
        local cache = espCache[player]
        if cache then
            cache.friendCount = count
            setEspInfoText(cache)
        end
    end)
end

local function createESP(player)
    if player == localPlayer then return end
    if espConnections[player] then
        for _, conn in ipairs(espConnections[player]) do
            pcall(function() conn:Disconnect() end)
        end
        espConnections[player] = nil
    end

    local conns = {}
    espConnections[player] = conns

    local function setup(char)
        if not espEnabled then return end
        if espCache[player] and espCache[player].gui then
            pcall(function() espCache[player].gui:Destroy() end)
            espCache[player] = nil
        end

        local head = char:FindFirstChild("Head")
        if not head then head = char:WaitForChild("Head", 5) end
        if not espEnabled or not head or not head.Parent then return end

        local gui = Instance.new("BillboardGui")
        gui.Name = "OSESP"
        gui.Size = UDim2.new(0, 200, 0, 40)
        gui.StudsOffset = Vector3.new(0, 2.8, 0)
        gui.AlwaysOnTop = true
        gui.LightInfluence = 0
        gui.MaxDistance = 1500
        gui.Parent = head

        local nameLabel = Instance.new("TextLabel")
        nameLabel.Size = UDim2.new(1, 0, 0.5, 0)
        nameLabel.BackgroundTransparency = 1
        nameLabel.TextColor3 = Color3.new(1, 1, 1)
        nameLabel.TextStrokeTransparency = 0
        nameLabel.TextStrokeColor3 = Color3.new(0, 0, 0)
        nameLabel.Font = Enum.Font.GothamBold
        nameLabel.TextSize = 14
        nameLabel.Text = player.Name
        nameLabel.Parent = gui

        local infoLabel = Instance.new("TextLabel")
        infoLabel.Size = UDim2.new(1, 0, 0.5, 0)
        infoLabel.Position = UDim2.new(0, 0, 0.5, 0)
        infoLabel.BackgroundTransparency = 1
        infoLabel.TextColor3 = Color3.fromRGB(180, 180, 180)
        infoLabel.TextStrokeTransparency = 0
        infoLabel.TextStrokeColor3 = Color3.new(0, 0, 0)
        infoLabel.Font = Enum.Font.Gotham
        infoLabel.TextSize = 12
        infoLabel.Text = ""
        infoLabel.Parent = gui

        espCache[player] = {
            gui = gui,
            nameLabel = nameLabel,
            infoLabel = infoLabel,
            head = head,
            lastDist = nil,
            friendCount = nil,
        }
        fetchFriendCount(player)
    end

    if player.Character then setup(player.Character) end
    conns[#conns + 1] = player.CharacterAdded:Connect(function(char)
        if not espEnabled then return end
        task.wait(0.5)
        setup(char)
    end)
    conns[#conns + 1] = player.CharacterRemoving:Connect(function()
        if espCache[player] then
            pcall(function() espCache[player].gui:Destroy() end)
            espCache[player] = nil
        end
    end)
end

local function enableESP()
    espEnabled = true
    for _, player in ipairs(Players:GetPlayers()) do
        createESP(player)
    end
end

local function disableESP()
    espEnabled = false
    destroyESP()
end

local function resolveCurrentColor(c)
    local key = colorKeyLookup[tostring(c)]
    if key and C[key] then return C[key] end
    for _, pal in pairs(THEMES) do
        for k2, v2 in pairs(pal) do
            if v2 == c then return C[k2] end
        end
    end
    return c
end

local function makeLabel(parent, text, fontSize, color, height, alignX)
    return new("TextLabel", {
        Size = UDim2.new(1, 0, 0, height or 20),
        BackgroundTransparency = 1,
        TextColor3 = color or C.muted,
        Text = text,
        TextXAlignment = alignX or Enum.TextXAlignment.Left,
        Font = FONT,
        TextSize = fontSize or 12,
        ZIndex = 4,
    }, parent)
end

local function makeInput(parent, placeholder, x, w, height)
    local box = new("TextBox", {
        Size = UDim2.new(w, 0, 0, height),
        Position = UDim2.new(x, 0, 0, 0),
        BackgroundColor3 = C.panelLight,
        TextColor3 = C.text,
        PlaceholderText = placeholder,
        PlaceholderColor3 = C.muted,
        Text = "",
        Font = FONT,
        TextSize = 12,
        ClearTextOnFocus = false,
        ZIndex = 4,
    }, parent)
    withCorner(box, 10)
    withStroke(box, C.borderLight, 1)
    box.Focused:Connect(function()
        tw(box, { BackgroundColor3 = brightenColor(C.panelLight, 0.04) }, 0.2)
        box.UIStroke.Color = C.teal
    end)
    box.FocusLost:Connect(function()
        tw(box, { BackgroundColor3 = C.panelLight }, 0.2)
        box.UIStroke.Color = C.borderLight
    end)
    return box
end

local function makeButton(parent, text, size, color, textColor)
    local baseColor = color or C.teal
    local palKey = colorKeyLookup[tostring(baseColor)]
    if not palKey then
        for k, v in pairs(C) do
            if v == baseColor then palKey = k break end
        end
    end
    local function curColor()
        if palKey and C[palKey] then return C[palKey] end
        return resolveCurrentColor(baseColor)
    end
    local btn = new("TextButton", {
        Size = size,
        BackgroundColor3 = baseColor,
        Text = text,
        TextColor3 = textColor or C.bg,
        Font = FONT_BOLD,
        TextSize = 12,
        AutoButtonColor = false,
        ZIndex = 4,
    }, parent)
    withCorner(btn, 10)
    withStroke(btn, darkenColor(baseColor, 0.1), 1)
    btn.MouseEnter:Connect(function()
        tw(btn, { BackgroundColor3 = brightenColor(curColor(), 0.08) }, 0.15)
    end)
    btn.MouseLeave:Connect(function()
        tw(btn, { BackgroundColor3 = curColor() }, 0.15)
    end)
    btn.MouseButton1Down:Connect(function()
        tw(btn, { BackgroundColor3 = darkenColor(curColor(), 0.05) }, 0.05)
    end)
    btn.MouseButton1Up:Connect(function()
        tw(btn, { BackgroundColor3 = brightenColor(curColor(), 0.08) }, 0.1)
    end)
    return btn
end

local function makeToggle(parent, label, getState, onToggle)
    local row = new("Frame", { Size = UDim2.new(1, 0, 0, 44), BackgroundColor3 = C.panel, ZIndex = 3 }, parent)
    withCorner(row, 10)
    withStroke(row, C.border, 1)
    new("TextLabel", {
        Text = label,
        TextSize = 14,
        TextColor3 = C.text,
        Font = FONT,
        TextXAlignment = Enum.TextXAlignment.Left,
        BackgroundTransparency = 1,
        Position = UDim2.fromOffset(14, 0),
        Size = UDim2.new(1, -76, 1, 0),
        ZIndex = 3,
    }, row)
    local pill = new("Frame", {
        Size = UDim2.fromOffset(48, 26),
        Position = UDim2.new(1, -62, 0.5, -13),
        BackgroundColor3 = C.off,
        ZIndex = 3,
    }, row)
    withCorner(pill, 13)
    local knob = new("Frame", {
        Size = UDim2.fromOffset(20, 20),
        Position = UDim2.fromOffset(3, 3),
        BackgroundColor3 = Color3.fromRGB(255, 255, 255),
        ZIndex = 4,
    }, pill)
    withCorner(knob, 10)
    local hit = new("TextButton", {
        Text = "",
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 1, 0),
        ZIndex = 5,
    }, row)
    local toggle = {}
    function toggle.set(state)
        if state then
            tw(pill, { BackgroundColor3 = C.teal }, 0.2)
            tw(knob, { Position = UDim2.fromOffset(25, 3) }, 0.2, Enum.EasingStyle.Back)
        else
            tw(pill, { BackgroundColor3 = C.off }, 0.2)
            tw(knob, { Position = UDim2.fromOffset(3, 3) }, 0.2, Enum.EasingStyle.Back)
        end
    end
    toggle.set(getState())
    hit.Activated:Connect(function()
        local state = not getState()
        onToggle(state)
        toggle.set(getState())
        pcall(function()
            if saveUiPositions then saveUiPositions() end
        end)
    end)
    row.MouseEnter:Connect(function()
        tw(row, { BackgroundColor3 = C.panelHover }, 0.15)
    end)
    row.MouseLeave:Connect(function()
        tw(row, { BackgroundColor3 = C.panel }, 0.15)
    end)
    return toggle
end

local function makeSlider(parent, label, min, max, default, onChange)
    local bg = new("Frame", { Size = UDim2.new(1, 0, 0, 40), BackgroundTransparency = 1 }, parent)
    new("TextLabel", {
        Size = UDim2.new(0.6, 0, 0, 14),
        BackgroundTransparency = 1,
        TextColor3 = C.text,
        Text = label,
        TextXAlignment = Enum.TextXAlignment.Left,
        Font = FONT,
        TextSize = 12,
        ZIndex = 4,
    }, bg)
    local valLbl = new("TextLabel", {
        Size = UDim2.new(0.4, 0, 0, 14),
        Position = UDim2.new(0.6, 0, 0, 0),
        BackgroundTransparency = 1,
        TextColor3 = C.teal,
        Text = "",
        TextXAlignment = Enum.TextXAlignment.Right,
        Font = FONT_BOLD,
        TextSize = 12,
        ZIndex = 4,
    }, bg)
    local track = new("Frame", {
        Size = UDim2.new(1, 0, 0, 5),
        Position = UDim2.new(0, 0, 0, 22),
        BackgroundColor3 = C.panelLight,
        ZIndex = 4,
    }, bg)
    withCorner(track, 3)
    local fill = new("Frame", { Size = UDim2.new(0, 0, 1, 0), BackgroundColor3 = C.teal, ZIndex = 5 }, track)
    withCorner(fill, 3)
    local knob = new("TextButton", {
        Size = UDim2.new(0, 14, 0, 14),
        Position = UDim2.new(0, 0, 0.5, -7),
        BackgroundColor3 = Color3.fromRGB(255, 255, 255),
        Text = "",
        ZIndex = 6,
    }, track)
    withCorner(knob, 7)
    withStroke(knob, C.teal, 1.5)

    local function setValue(v)
        v = math.clamp(v, min, max)
        valLbl.Text = tostring(math.floor(v))
        local t = (v - min) / (max - min)
        tw(fill, { Size = UDim2.new(t, 0, 1, 0) }, 0.15)
        tw(knob, { Position = UDim2.new(t, -7, 0.5, -7) }, 0.15)
        return math.floor(v)
    end

    local dragging = false
    local function updateFromMouse()
        if not bg.Parent then return end
        if not track.AbsoluteSize.X or track.AbsoluteSize.X == 0 then return end
        local mx = UserInputService:GetMouseLocation().X
        local t = math.clamp((mx - track.AbsolutePosition.X) / track.AbsoluteSize.X, 0, 1)
        local v = min + (max - min) * t
        onChange(setValue(v))
    end

    knob.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
        end
    end)
    knob.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)
    track.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            updateFromMouse()
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if not bg.Parent then return end
        if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
            updateFromMouse()
        end
    end)
    UserInputService.InputEnded:Connect(function(input)
        if not bg.Parent then return end
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)
    setValue(default)
    return { set = setValue }
end

local function makeList(parent)
    local frame = new("Frame", {
        Size = UDim2.new(1, 0, 0, 0),
        BackgroundTransparency = 1,
        AutomaticSize = Enum.AutomaticSize.Y,
        ZIndex = 4,
    }, parent)
    new("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }, frame)
    withPadding(frame, 4, 4, 4, 4)
    return frame
end

loadUiPositions()

;(function()

local playerGui = localPlayer:WaitForChild("PlayerGui")
local oldGui = playerGui:FindFirstChild("OutfitManagerGUI")
if oldGui then oldGui:Destroy() end

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "OutfitManagerGUI"
ScreenGui.ResetOnSpawn = false
ScreenGui.DisplayOrder = 999
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.Parent = playerGui
uiRoot = ScreenGui

local Window = new("Frame", {
    Size = UDim2.fromOffset(800, 540),
    Position = UDim2.new(0.5, -400, 0.5, -270),
    BackgroundColor3 = C.bg,
    ClipsDescendants = true,
    Active = true,
    ZIndex = 5,
    BackgroundTransparency = 0,
}, ScreenGui)
withCorner(Window, 16)
withStroke(Window, C.border, 1)
Window.Size = UDim2.new(0, 0, 0, 0)
Window.Position = UDim2.new(0.5, 0, 0.5, 0)
tw(Window, {
    Size = UDim2.fromOffset(800, 540),
    Position = UDim2.new(0.5, -400, 0.5, -270),
}, 0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out)

local sidebar = new("Frame", {
    Size = UDim2.new(0, 195, 1, 0),
    Position = UDim2.new(0, 0, 0, 0),
    BackgroundColor3 = C.panel,
    ZIndex = 3,
}, Window)
withCorner(sidebar, 16)
withStroke(sidebar, C.border, 1)

local logo = new("Frame", {
    Size = UDim2.new(1, 0, 0, 52),
    Position = UDim2.new(0, 0, 0, 12),
    BackgroundTransparency = 1,
    ZIndex = 4,
}, sidebar)

new("TextLabel", {
    Text = "OUTFIT",
    TextSize = 20,
    TextColor3 = C.teal,
    Font = FONT_BOLD,
    BackgroundTransparency = 1,
    Size = UDim2.new(1, 0, 0, 24),
    Position = UDim2.new(0, 0, 0, 0),
    TextXAlignment = Enum.TextXAlignment.Center,
    ZIndex = 5,
}, logo)

new("TextLabel", {
    Text = "HUB",
    TextSize = 14,
    TextColor3 = C.muted,
    Font = FONT_LIGHT,
    BackgroundTransparency = 1,
    Size = UDim2.new(1, 0, 0, 18),
    Position = UDim2.new(0, 0, 0, 22),
    TextXAlignment = Enum.TextXAlignment.Center,
    ZIndex = 5,
}, logo)

local avatar = new("ImageLabel", {
    Size = UDim2.fromOffset(58, 58),
    Position = UDim2.new(0.5, -29, 0, 78),
    Image = "rbxthumb://type=AvatarHeadShot&id=".. localPlayer.UserId .. "&w=100&h=100",
    ImageColor3 = Color3.new(1, 1, 1),
    BackgroundColor3 = C.panelLight,
    ZIndex = 4,
}, sidebar)
withCorner(avatar, 29)
withStroke(avatar, C.teal, 2)

local userNameLabel = new("TextLabel", {
    Text = localPlayer.DisplayName,
    TextSize = 12,
    TextColor3 = C.text,
    Font = FONT_BOLD,
    BackgroundTransparency = 1,
    Size = UDim2.new(1, 0, 0, 16),
    Position = UDim2.new(0, 0, 0, 140),
    TextXAlignment = Enum.TextXAlignment.Center,
    ZIndex = 4,
}, sidebar)

local navContainer = new("ScrollingFrame", {
    Size = UDim2.new(1, 0, 1, -200),
    Position = UDim2.new(0, 0, 0, 166),
    BackgroundTransparency = 1,
    ClipsDescendants = true,
    ZIndex = 3,
    ScrollBarThickness = 2,
    ScrollBarImageColor3 = C.teal,
    AutomaticCanvasSize = Enum.AutomaticSize.Y,
    BorderSizePixel = 0,
}, sidebar)
new("UIListLayout", { Padding = UDim.new(0, 4), HorizontalAlignment = Enum.HorizontalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder }, navContainer)
withPadding(navContainer, 0, 0, 6, 6)

local titleBar = new("Frame", {
    Size = UDim2.new(1, -195, 0, 44),
    Position = UDim2.new(0, 195, 0, 0),
    BackgroundColor3 = C.panel,
    ZIndex = 4,
}, Window)
withStroke(titleBar, C.border, 1)

local titleText = new("TextLabel", {
    Text = "OUTFIT HUB",
    TextSize = 16,
    TextColor3 = C.teal,
    Font = FONT_BOLD,
    TextXAlignment = Enum.TextXAlignment.Left,
    BackgroundTransparency = 1,
    Position = UDim2.fromOffset(20, 0),
    Size = UDim2.new(0.6, -18, 1, 0),
    ZIndex = 5,
}, titleBar)

local function makeWindowButton(parent, text, offset)
    local button = new("TextButton", {
        Text = text,
        TextSize = 14,
        TextColor3 = C.muted,
        Font = FONT_BOLD,
        Size = UDim2.fromOffset(30, 26),
        Position = UDim2.new(1, -(10 + offset), 0, 9),
        BackgroundColor3 = C.panelLight,
        AutoButtonColor = false,
        ZIndex = 5,
    }, parent)
    withCorner(button, 8)
    button.MouseEnter:Connect(function()
        tw(button, { BackgroundColor3 = C.tealDark, TextColor3 = Color3.new(1, 1, 1) }, 0.15)
    end)
    button.MouseLeave:Connect(function()
        tw(button, { BackgroundColor3 = C.panelLight, TextColor3 = C.muted }, 0.15)
    end)
    return button
end

local minimizeBtn = makeWindowButton(titleBar, "-", 70)
local closeBtn = makeWindowButton(titleBar, "x", 36)

local dragToggle = false
local dragInput = nil
local dragStart = Vector3.new()
local dragPos = UDim2.new()

titleBar.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragToggle = true
        dragStart = input.Position
        dragPos = Window.Position
    end
end)
titleBar.InputChanged:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
        dragInput = input
    end
end)
local dragInputChangedConn = UserInputService.InputChanged:Connect(function(input)
    if input == dragInput and dragToggle then
        local delta = input.Position - dragStart
        Window.Position = UDim2.new(dragPos.X.Scale, dragPos.X.Offset + delta.X, dragPos.Y.Scale, dragPos.Y.Offset + delta.Y)
    end
end)
addCleanup(function()
    if dragInputChangedConn then pcall(function() dragInputChangedConn:Disconnect() end) end
end)
titleBar.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragToggle = false
        dragInput = nil
    end
end)

local contentPanel = new("Frame", {
    Size = UDim2.new(1, -195, 1, -44),
    Position = UDim2.new(0, 195, 0, 44),
    BackgroundColor3 = C.bg,
    ZIndex = 2,
}, Window)
withCorner(contentPanel, 0)

local pageTitle = new("TextLabel", {
    Text = "Settings Menu",
    TextSize = 22,
    TextColor3 = C.teal,
    Font = FONT_BOLD,
    TextXAlignment = Enum.TextXAlignment.Left,
    BackgroundTransparency = 1,
    Position = UDim2.fromOffset(24, 14),
    Size = UDim2.new(1, -48, 0, 32),
    ZIndex = 3,
}, contentPanel)

local subtitleLine = new("Frame", {
    Size = UDim2.new(1, -48, 0, 1),
    Position = UDim2.new(0, 24, 0, 52),
    BackgroundColor3 = C.border,
    ZIndex = 3,
}, contentPanel)

local pageContainer = new("Frame", {
    Size = UDim2.new(1, -48, 1, -68),
    Position = UDim2.new(0, 24, 0, 60),
    BackgroundTransparency = 1,
    ZIndex = 2,
}, contentPanel)

local pages = {}
local function createPage()
    local page = new("ScrollingFrame", {
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundTransparency = 1,
        Visible = false,
        ZIndex = 2,
        ScrollBarThickness = 2,
        ScrollBarImageColor3 = C.teal,
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        CanvasSize = UDim2.new(0, 0, 0, 0),
        BorderSizePixel = 0,
    }, pageContainer)
    new("UIListLayout", { Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder }, page)
    withPadding(page, 4, 4, 0, 0)
    return page
end

local outfitsPage = createPage()
local webhookPage = createPage()
local importPage = createPage()
local espPage = createPage()
local tpPage = createPage()
local movePage = createPage()
local settingsPage = createPage()
local historyPage = createPage()
local serverPage = createPage()

pages.outfits = outfitsPage
pages.webhook = webhookPage
pages.import = importPage
pages.esp = espPage
pages.tp = tpPage
pages.move = movePage
pages.history = historyPage
pages.server = serverPage
pages.settings = settingsPage

local NAV_ITEMS = {
    { id = "outfits", label = "Tenues", order = 1 },
    { id = "history", label = "Historique", order = 2 },
    { id = "webhook", label = "Webhook", order = 3 },
    { id = "import", label = "Import", order = 4 },
    { id = "esp", label = "ESP", order = 5 },
    { id = "tp", label = "Teleport", order = 6 },
    { id = "move", label = "Mouvement", order = 7 },
    { id = "server", label = "Serveur", order = 8 },
    { id = "settings", label = "Reglages", order = 9 },
}

local refreshPlayerList = nil

local function switchTab(name)
    for _, item in ipairs(NAV_ITEMS) do
        local active = item.id == name
        item.page.Visible = active
        if active then
            tw(item.btn, { BackgroundColor3 = C.panelHover, BackgroundTransparency = 0, TextColor3 = C.text }, 0.2)
            tw(item.indicator, { BackgroundTransparency = 0 }, 0.2)
        else
            tw(item.btn, { BackgroundColor3 = C.panel, BackgroundTransparency = 1, TextColor3 = C.muted }, 0.2)
            tw(item.indicator, { BackgroundTransparency = 1 }, 0.2)
        end
    end
    local titles = {
        outfits = "Mes Tenues",
        webhook = "Discord Webhook",
        import = "Importer un Skin",
        esp = "ESP Joueur",
        tp = "Teleport Joueur",
        move = "Mouvement",
        history = "Historique",
        server = "Serveur",
        settings = "Reglages",
    }
    pageTitle.Text = titles[name] or name
    if name == "tp" and refreshPlayerList then
        refreshPlayerList()
    end
end

for _, item in ipairs(NAV_ITEMS) do
    local btn = new("TextButton", {
        Text = " ".. item.label,
        TextSize = 13,
        TextColor3 = C.muted,
        Font = FONT,
        AutoButtonColor = false,
        Size = UDim2.new(1, -12, 0, 36),
        BackgroundColor3 = C.panelLight,
        BackgroundTransparency = 1,
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 3,
        LayoutOrder = item.order,
    }, navContainer)
    withCorner(btn, 10)

    local indicator = new("Frame", {
        Size = UDim2.new(0, 3, 0.5, 0),
        Position = UDim2.new(0, 0, 0.25, 0),
        BackgroundColor3 = C.teal,
        BackgroundTransparency = 1,
        ZIndex = 4,
    }, btn)
    withCorner(indicator, 2)

    btn.MouseEnter:Connect(function()
        if item.page.Visible then return end
        tw(btn, { BackgroundTransparency = 0.7 }, 0.15)
        btn.TextColor3 = C.text
    end)
    btn.MouseLeave:Connect(function()
        if item.page.Visible then return end
        tw(btn, { BackgroundTransparency = 1 }, 0.15)
        btn.TextColor3 = C.muted
    end)
    btn.Activated:Connect(function()
        switchTab(item.id)
    end)
    item.btn = btn
    item.indicator = indicator
    item.page = pages[item.id]
end

local randomRow = new("Frame", { Size = UDim2.new(1, 0, 0, 36), BackgroundTransparency = 1 }, outfitsPage)
local RandomBtn = makeButton(randomRow, "Tenue aleatoire", UDim2.new(0.48, 0, 0, 36), C.teal)
RandomBtn.Position = UDim2.new(0, 0, 0, 0)
local LikeOutfitBtn = makeButton(randomRow, "Like Outfit", UDim2.new(0.48, 0, 0, 36), C.discord, Color3.new(1, 1, 1))
LikeOutfitBtn.Position = UDim2.new(0.5, 0, 0, 0)
local AutoEquipToggle = makeToggle(outfitsPage, "Auto-equip au spawn", function() return autoEquipEnabled end, function(state)
    autoEquipEnabled = state
    if state and autoEquipOutfitName then
        showNotification("Auto-equip: " .. autoEquipOutfitName)
    else
        autoEquipOutfitName = nil
    end
    saveUiPositions()
end)

local clickToggle = makeToggle(outfitsPage, "Mode vol au clic", function() return clickModeActive end, function(state)
    clickModeActive = state
end)

local clickTpToggle = makeToggle(outfitsPage, "Click TP (clique un joueur)", function() return clickTpEnabled end, function(state)
    clickTpEnabled = state
end)

local saveRow = new("Frame", { Size = UDim2.new(1, 0, 0, 42), BackgroundTransparency = 1 }, outfitsPage)
local SaveNameInput = makeInput(saveRow, "Nom de la tenue...", 0, 0.62, 42)
local SaveMyBtn = makeButton(saveRow, "Sauvegarder", UDim2.new(0.36, 0, 0, 42), C.teal)
SaveMyBtn.Position = UDim2.new(0.64, 0, 0, 0)

local counterRow = new("Frame", { Size = UDim2.new(1, 0, 0, 24), BackgroundTransparency = 1 }, outfitsPage)
local CounterLabel = makeLabel(counterRow, "0/" .. MAX_OUTFITS .. " tenues", 12, C.muted, 24)

local searchBar = new("Frame", {
    Size = UDim2.new(1, 0, 0, 36),
    BackgroundColor3 = C.panelLight,
    ZIndex = 3,
}, outfitsPage)
withCorner(searchBar, 10)
withStroke(searchBar, C.borderLight, 1)
local searchBox = new("TextBox", {
    PlaceholderText = "Rechercher une tenue...",
    Text = "",
    TextSize = 12,
    TextColor3 = C.text,
    PlaceholderColor3 = C.muted,
    Font = FONT,
    BackgroundTransparency = 1,
    ClearTextOnFocus = false,
    Position = UDim2.fromOffset(10, 0),
    Size = UDim2.new(1, -18, 1, 0),
    ZIndex = 4,
}, searchBar)

local outfitList = makeList(outfitsPage)

makeLabel(webhookPage, "WEBHOOK DISCORD", 11, C.teal, 18)
local webhookRow = new("Frame", { Size = UDim2.new(1, 0, 0, 42), BackgroundTransparency = 1 }, webhookPage)
local WebhookInput = makeInput(webhookRow, "https://discord.com/api/webhooks/...", 0, 0.62, 42)
WebhookInput.Text = webhookURL
WebhookInput.FocusLost:Connect(function()
    webhookURL = WebhookInput.Text
    saveUiPositions()
end)
local ExportBtn = makeButton(webhookRow, "Exporter", UDim2.new(0.36, 0, 0, 42), C.discord, Color3.new(1, 1, 1))
ExportBtn.Position = UDim2.new(0.64, 0, 0, 0)

makeLabel(importPage, "IMPORTER UN SKIN", 11, C.teal, 18)
makeLabel(importPage, "Colle le JSON du skin a importer", 11, C.muted, 18)
local ImportInput = makeInput(importPage, "Colle le JSON ici...", 0, 1, 80)
local ImportNameInput = makeInput(importPage, "Nom pour la tenue...", 0, 1, 38)
local ImportBtn = makeButton(importPage, "Importer", UDim2.new(1, 0, 0, 42), C.teal)

makeLabel(espPage, "ESP : nom | distance | amis", 11, C.teal, 18)
local espToggle = makeToggle(espPage, "Activer ESP", function() return espEnabled end, function(state)
    if state then enableESP() else disableESP() end
end)
makeLabel(espPage, "Distance et nombre d'amis mis a jour auto.", 11, C.muted, 30)

makeLabel(tpPage, "TP ou Spectate sur un joueur", 11, C.teal, 18)
local TpRefreshBtn = makeButton(tpPage, "Rafraichir", UDim2.new(0.48, 0, 0, 34), C.teal)
TpRefreshBtn.Position = UDim2.new(0, 0, 0, 0)
local SpectateStopBtn = makeButton(tpPage, "Stop Spectate", UDim2.new(0.48, 0, 0, 34), C.discord, Color3.new(1, 1, 1))
SpectateStopBtn.Position = UDim2.new(0.5, 0, 0, 0)
spectateStatusLabel = makeLabel(tpPage, "", 11, C.muted, 18)
local tpList = makeList(tpPage)

local wsSlider = makeSlider(movePage, "WalkSpeed", 0, 250, 16, function(v)
    walkSpeedValue = v
    applyMovement(localPlayer.Character)
    saveUiPositions()
end)
local jpSlider = makeSlider(movePage, "JumpPower", 0, 250, 50, function(v)
    jumpPowerValue = v
    applyMovement(localPlayer.Character)
    saveUiPositions()
end)
local ResetMoveBtn = makeButton(movePage, "Reset mouvement", UDim2.new(0.5, 0, 0, 36), C.panelLight, C.text)
ResetMoveBtn.Position = UDim2.new(0.25, 0, 0, 0)
local noclipToggle = makeToggle(movePage, "Noclip", function() return noclipEnabled end, function(state)
    setNoclip(state)
end)
local flyToggle = makeToggle(movePage, "Vol (Fly)", function() return flyEnabled end, function(state)
    flyEnabled = state
    if state then startFly() else stopFly() end
end)
local flySpeedSlider = makeSlider(movePage, "Vitesse du vol", 10, 400, flySpeed, function(v)
    flySpeed = v
    saveUiPositions()
end)
local infJumpToggle = makeToggle(movePage, "Infinite Jump", function() return infJumpEnabled end, function(state)
    infJumpEnabled = state
end)
local antiAfkToggle = makeToggle(movePage, "Anti-AFK", function() return antiAfkEnabled end, function(state)
    antiAfkEnabled = state
    if state then task.spawn(antiAfkLoop) end
end)
local autoAfkStatusToggle = makeToggle(movePage, "Auto AFK Status", function() return autoAfkStatusEnabled end, function(state)
    setAutoAfkStatus(state)
end)
local spinToggle = makeToggle(movePage, "Spin", function() return spinEnabled end, function(state)
    setSpin(state)
    saveUiPositions()
end)
local spinSpeedSlider = makeSlider(movePage, "Vitesse du spin", 1, 1000, spinSpeed, function(v)
    spinSpeed = v
    saveUiPositions()
end)
makeLabel(movePage, "PRESETS VITESSE", 11, C.teal, 18)
local presetsRow = new("Frame", { Size = UDim2.new(1, 0, 0, 36), BackgroundTransparency = 1 }, movePage)
local p16 = makeButton(presetsRow, "16", UDim2.new(0.24, 0, 0, 36), C.panelLight, C.text)
p16.Position = UDim2.new(0, 0, 0, 0)
local p32 = makeButton(presetsRow, "32", UDim2.new(0.24, 0, 0, 36), C.panelLight, C.text)
p32.Position = UDim2.new(0.25, 0, 0, 0)
local p50 = makeButton(presetsRow, "50", UDim2.new(0.24, 0, 0, 36), C.panelLight, C.text)
p50.Position = UDim2.new(0.5, 0, 0, 0)
local p100 = makeButton(presetsRow, "100", UDim2.new(0.24, 0, 0, 36), C.panelLight, C.text)
p100.Position = UDim2.new(0.75, 0, 0, 0)
p16.Activated:Connect(function() walkSpeedValue = 16 wsSlider.set(16) applyMovement(localPlayer.Character) showNotification("Speed: 16") end)
p32.Activated:Connect(function() walkSpeedValue = 32 wsSlider.set(32) applyMovement(localPlayer.Character) showNotification("Speed: 32") end)
p50.Activated:Connect(function() walkSpeedValue = 50 wsSlider.set(50) applyMovement(localPlayer.Character) showNotification("Speed: 50") end)
p100.Activated:Connect(function() walkSpeedValue = 100 wsSlider.set(100) applyMovement(localPlayer.Character) showNotification("Speed: 100") end)
makeLabel(movePage, "SPEED PERSONNALISEE", 11, C.teal, 18)
local speedRow = new("Frame", { Size = UDim2.new(1, 0, 0, 36), BackgroundTransparency = 1 }, movePage)
local speedInput = makeInput(speedRow, "Vitesse (ex: 250)...", 0, 0.62, 36)
local speedApplyBtn = makeButton(speedRow, "Appliquer", UDim2.new(0.36, 0, 0, 36), C.teal)
speedApplyBtn.Position = UDim2.new(0.64, 0, 0, 0)
speedApplyBtn.Activated:Connect(function()
    local v = tonumber(speedInput.Text)
    if not v or v < 0 or v > 2000 then
        showNotification("Vitesse invalide")
        return
    end
    walkSpeedValue = v
    applyMovement(localPlayer.Character)
    wsSlider.set(v)
    speedInput.Text = ""
    saveUiPositions()
    showNotification("Speed: " .. tostring(v))
end)
makeLabel(movePage, "KEYBINDS (clique pour changer)", 11, C.teal, 18)
local function makeKeybindRow(parent, label, current, onChange)
    local row = new("Frame", { Size = UDim2.new(1, 0, 0, 36), BackgroundColor3 = C.panel, ZIndex = 3 }, parent)
    withCorner(row, 10)
    withStroke(row, C.border, 1)
    new("TextLabel", {
        Text = label, TextSize = 13, TextColor3 = C.text, Font = FONT,
        TextXAlignment = Enum.TextXAlignment.Left, BackgroundTransparency = 1,
        Position = UDim2.fromOffset(12, 0), Size = UDim2.new(0.5, 0, 1, 0), ZIndex = 4,
    }, row)
    local keyText = new("TextButton", {
        Text = current and current.Name or "Aucun",
        TextSize = 12, TextColor3 = C.teal, Font = FONT_BOLD,
        BackgroundColor3 = C.panelLight, Size = UDim2.new(0.35, 0, 0.6, 0),
        Position = UDim2.new(0.6, 0, 0.2, 0), ZIndex = 4,
    }, row)
    withCorner(keyText, 8)
    local listening = false
    keyText.Activated:Connect(function()
        if listening then return end
        listening = true
        keyText.Text = "..."
        keyText.TextColor3 = C.warning
        local conn
        conn = UserInputService.InputBegan:Connect(function(input, gpe)
            if gpe then return end
            if input.UserInputType == Enum.UserInputType.Keyboard then
                onChange(input.KeyCode)
                keyText.Text = input.KeyCode.Name
                keyText.TextColor3 = C.teal
                listening = false
                if conn then conn:Disconnect() end
            end
        end)
    end)
end
makeKeybindRow(movePage, "Noclip", keybindNoclip, function(key) keybindNoclip = key; saveUiPositions() end)
makeKeybindRow(movePage, "Fly", keybindFly, function(key) keybindFly = key; saveUiPositions() end)
makeKeybindRow(movePage, "Speed x2", keybindSpeed, function(key) keybindSpeed = key; saveUiPositions() end)
makeKeybindRow(movePage, "Click (vol de tenue)", keybindClick, function(key) keybindClick = key; saveUiPositions() end)
makeKeybindRow(movePage, "Click TP", keybindClickTp, function(key) keybindClickTp = key; saveUiPositions() end)

makeLabel(settingsPage, "REGLAGES", 11, C.teal, 18)
local ThemeBtn = makeButton(settingsPage, "Theme : " .. (themeName == "dark" and "Sombre" or "Clair"), UDim2.new(1, 0, 0, 42), C.teal)
local FullbrightToggle = makeToggle(settingsPage, "Fullbright (lumiere)", function() return fullbrightEnabled end, function(state)
    setFullbright(state)
    showNotification(state and "Fullbright active" or "Fullbright desactive")
    saveUiPositions()
end)
local zoomSlider = makeSlider(settingsPage, "Distance zoom cam", 10, 200, zoomDistance, function(v)
    zoomDistance = v
    setZoomDistance(v)
    saveUiPositions()
end)
makeLabel(settingsPage, "COULEURS DU MENU (hex)", 11, C.teal, 18)
local colorRows = {}
local function makeColorRow(parent, key, label)
    local row = new("Frame", { Size = UDim2.new(1, 0, 0, 38), BackgroundTransparency = 1 }, parent)
    makeLabel(row, label, 12, C.text, 38)
    local input = makeInput(row, "#RRGGBB", 0.45, 0.38, 32)
    input.Position = UDim2.new(0.45, 0, 0, 2)
    input.Text = colorToHex(C[key])
    local swatch = new("Frame", {
        Size = UDim2.new(0, 26, 0, 26),
        Position = UDim2.new(0.9, -13, 0, 5),
        BackgroundColor3 = C[key],
        ZIndex = 4,
    }, row)
    withStroke(swatch, C.borderLight, 1)
    local function applyColor()
        local col = hexToColor(input.Text)
        if not col then
            input.Text = colorToHex(C[key])
            showNotification("Hex invalide: #RRGGBB")
            return
        end
        local old = {}
        for k, v in pairs(C) do old[k] = v end
        C[key] = col
        customColors[themeName] = customColors[themeName] or {}
        customColors[themeName][key] = {
            math.floor(col.R * 255 + 0.5),
            math.floor(col.G * 255 + 0.5),
            math.floor(col.B * 255 + 0.5)
        }
        swatch.BackgroundColor3 = col
        if applyTheme then applyTheme(old, C) end
        if repaintGameBtn then repaintGameBtn() end
        saveUiPositions()
        showNotification(label .. " -> " .. input.Text)
    end
    input.FocusLost:Connect(function(enter)
        if enter or input.Text ~= "" then applyColor() end
    end)
    table.insert(colorRows, { key = key, input = input, swatch = swatch })
end
makeColorRow(settingsPage, "bg", "Fond")
makeColorRow(settingsPage, "panel", "Panneau")
makeColorRow(settingsPage, "teal", "Accent")
makeColorRow(settingsPage, "text", "Texte")
makeColorRow(settingsPage, "muted", "Muted")
makeColorRow(settingsPage, "border", "Bordure")
local ResetColorsBtn = makeButton(settingsPage, "Reset couleurs", UDim2.new(1, 0, 0, 40), C.panelLight, C.text)
ResetColorsBtn.Activated:Connect(function()
    local pal = THEMES[themeName]
    local old = {}
    for k, v in pairs(pal) do old[k] = v end
    local def = DEFAULT_THEME_COLORS[themeName]
    if def then
        for k, v in pairs(def) do
            pcall(function() pal[k] = Color3.new(v.R, v.G, v.B) end)
        end
    end
    if customColors[themeName] then customColors[themeName] = nil end
    for _, row in ipairs(colorRows) do
        row.input.Text = colorToHex(pal[row.key])
        row.swatch.BackgroundColor3 = pal[row.key]
    end
    if applyTheme then applyTheme(old, pal) end
    if repaintGameBtn then repaintGameBtn() end
    saveUiPositions()
    showNotification("Couleurs reinitialisees")
end)
makeLabel(settingsPage, "AUTO-EQUIP", 11, C.teal, 18)
local autoEquipLabel = makeLabel(settingsPage, "Aucune tenue selectionnee", 12, C.muted, 20)
local autoEquipPickRow = new("Frame", { Size = UDim2.new(1, 0, 0, 36), BackgroundTransparency = 1 }, settingsPage)
local autoEquipPickBtn = makeButton(autoEquipPickRow, "Choisir une tenue", UDim2.new(0.5, 0, 0, 36), C.teal)
autoEquipPickBtn.Position = UDim2.new(0.25, 0, 0, 0)
autoEquipPickBtn.Activated:Connect(function()
    if autoEquipEnabled then
        autoEquipEnabled = false
        autoEquipOutfitName = nil
        autoEquipLabel.Text = "Aucune tenue selectionnee"
        showNotification("Auto-equip desactive")
    else
        autoEquipEnabled = true
        local first = next(sessionOutfits)
        if first then
            autoEquipOutfitName = first
            autoEquipLabel.Text = "Auto-equip: " .. first
            showNotification("Auto-equip: " .. first)
        else
            autoEquipEnabled = false
            showNotification("Aucune tenue sauvegardee")
        end
    end
    saveUiPositions()
end)
local SettingsResetBtn = makeButton(settingsPage, "Reset mouvement", UDim2.new(1, 0, 0, 42), C.panelLight, C.text)
local SettingsDeleteBtn = makeButton(settingsPage, "Supprimer toutes les tenues", UDim2.new(1, 0, 0, 42), C.del, Color3.new(1, 1, 1))
makeLabel(settingsPage, "RP NAME", 11, C.teal, 18)
savedRpLabel = makeLabel(settingsPage, "RP sauvegarde: " .. (savedRpName ~= "" and savedRpName or "aucun"), 12, C.muted, 20)
local rpNameList = makeList(settingsPage)
local function refreshRpNameList()
    for _, child in ipairs(rpNameList:GetChildren()) do
        if child:IsA("Frame") or child:IsA("TextLabel") then child:Destroy() end
    end
    if #rpNamePhrases == 0 then
        makeLabel(rpNameList, "Aucune phrase", 12, C.muted, 24)
        return
    end
    for i, phrase in ipairs(rpNamePhrases) do
        local row = new("Frame", { Size = UDim2.new(1, 0, 0, 30), BackgroundColor3 = C.panelLight, BackgroundTransparency = 0.5 }, rpNameList)
        withCorner(row, 4)
        makeLabel(row, phrase, 12, C.text, 30)
        local delBtn = new("TextButton", {
            Size = UDim2.new(0, 24, 0, 24),
            Position = UDim2.new(1, -28, 0, 3),
            BackgroundColor3 = C.del,
            Text = "X",
            TextColor3 = Color3.new(1,1,1),
            Font = FONT_BOLD,
            TextSize = 11,
            ZIndex = 4,
        }, row)
        withCorner(delBtn, 4)
        delBtn.Activated:Connect(function()
            table.remove(rpNamePhrases, i)
            refreshRpNameList()
            saveUiPositions()
        end)
    end
end
refreshRpNameList()
local rpNameInputRow = new("Frame", { Size = UDim2.new(1, 0, 0, 36), BackgroundTransparency = 1 }, settingsPage)
local rpNameInput = makeInput(rpNameInputRow, "Nouvelle phrase...", 0, 0.62, 36)
local rpNameAddBtn = makeButton(rpNameInputRow, "Ajouter", UDim2.new(0.36, 0, 0, 36), C.teal)
rpNameAddBtn.Position = UDim2.new(0.64, 0, 0, 0)
rpNameAddBtn.Activated:Connect(function()
    local txt = rpNameInput.Text
    if txt and txt ~= "" then
        table.insert(rpNamePhrases, txt)
        rpNameInput.Text = ""
        refreshRpNameList()
        saveUiPositions()
        showNotification("Phrase ajoutee: " .. txt)
    end
end)
local rpNameChangeBtn = makeButton(settingsPage, "Changer le RP Name", UDim2.new(1, 0, 0, 42), C.teal)
rpNameChangeBtn.Activated:Connect(function()
    if #rpNamePhrases == 0 then
        showNotification("Ajoute des phrases d'abord")
        return
    end
    local chosen = rpNamePhrases[math.random(1, #rpNamePhrases)]
    local ok, err = pcall(function()
        game.ReplicatedStorage.Events.SettingsRemoteFunction:InvokeServer({
            Action = "SetDisplayName",
            DisplayName = chosen
        })
    end)
    if ok then
        savedRpName = chosen
        savedRpLabel.Text = "RP sauvegarde: " .. chosen
        saveUiPositions()
        showNotification("RP Name: " .. chosen)
    else
        showNotification("Erreur RP Name")
    end
end)
local rpNameReapplyBtn = makeButton(settingsPage, "Reappliquer le RP sauvegarde", UDim2.new(1, 0, 0, 42), C.panelLight, C.text)
rpNameReapplyBtn.Activated:Connect(function()
    if savedRpName == "" then
        showNotification("Aucun RP sauvegarde")
        return
    end
    local ok, err = pcall(function()
        game.ReplicatedStorage.Events.SettingsRemoteFunction:InvokeServer({
            Action = "SetDisplayName",
            DisplayName = savedRpName
        })
    end)
    if ok then
        showNotification("RP reapplique: " .. savedRpName)
    else
        showNotification("Erreur reapplication RP")
    end
end)
local rpAutoToggle = makeToggle(settingsPage, "RP Name lettre par lettre", function() return rpAutoEnabled end, function(state)
    rpAutoEnabled = state
    if state then
        if #rpNamePhrases == 0 then
            rpAutoEnabled = false
            showNotification("Ajoute des phrases d'abord")
            return
        end
        showNotification("RP auto lettre par lettre ON")
        task.spawn(rpAutoLoop)
    else
        showNotification("RP auto OFF")
    end
end)
makeLabel(settingsPage, "CHAT COLOR", 11, C.teal, 18)
local chatTagInputRow = new("Frame", { Size = UDim2.new(1, 0, 0, 36), BackgroundTransparency = 1 }, settingsPage)
makeLabel(chatTagInputRow, "Tag:", 12, C.text, 36)
local chatTagInput = makeInput(chatTagInputRow, "Chat tag...", 0.15, 0.85, 36)
chatTagInput.Position = UDim2.new(0.15, 0, 0, 0)
local chatTagColorRow = new("Frame", { Size = UDim2.new(1, 0, 0, 36), BackgroundTransparency = 1 }, settingsPage)
makeLabel(chatTagColorRow, "Tag (hex):", 12, C.text, 36)
local chatTagColorInput = makeInput(chatTagColorRow, "#FF0000", 0.4, 0.6, 36)
chatTagColorInput.Position = UDim2.new(0.4, 0, 0, 0)
local chatNameColorRow = new("Frame", { Size = UDim2.new(1, 0, 0, 36), BackgroundTransparency = 1 }, settingsPage)
makeLabel(chatNameColorRow, "Nom (hex):", 12, C.text, 36)
local chatNameColorInput = makeInput(chatNameColorRow, "#FFFFFF", 0.4, 0.6, 36)
chatNameColorInput.Position = UDim2.new(0.4, 0, 0, 0)
local chatTextColorRow = new("Frame", { Size = UDim2.new(1, 0, 0, 36), BackgroundTransparency = 1 }, settingsPage)
makeLabel(chatTextColorRow, "Texte (hex):", 12, C.text, 36)
local chatTextColorInput = makeInput(chatTextColorRow, "#FFFFFF", 0.4, 0.6, 36)
chatTextColorInput.Position = UDim2.new(0.4, 0, 0, 0)
chatTagInput:GetPropertyChangedSignal("Text"):Connect(function() _savedChatTag = chatTagInput.Text; saveUiPositions() end)
chatTagColorInput:GetPropertyChangedSignal("Text"):Connect(function() _savedChatTagColor = chatTagColorInput.Text; saveUiPositions() end)
chatNameColorInput:GetPropertyChangedSignal("Text"):Connect(function() _savedChatNameColor = chatNameColorInput.Text; saveUiPositions() end)
chatTextColorInput:GetPropertyChangedSignal("Text"):Connect(function() _savedChatTextColor = chatTextColorInput.Text; saveUiPositions() end)
local chatColorBtn = makeButton(settingsPage, "Appliquer Chat Color", UDim2.new(1, 0, 0, 42), C.teal)
chatColorBtn.Activated:Connect(function()
    local tag = chatTagInput.Text ~= "" and chatTagInput.Text or nil
    local tagColor = chatTagColorInput.Text ~= "" and chatTagColorInput.Text or "#FF0000"
    local nameColor = chatNameColorInput.Text ~= "" and chatNameColorInput.Text or "#FFFFFF"
    local textColor = chatTextColorInput.Text ~= "" and chatTextColorInput.Text or "#FFFFFF"
    local ok, err = pcall(function()
        game.ReplicatedStorage.Events.SettingsRemoteFunction:InvokeServer({
            Action = "UpdateChatStyle",
            ChatTag = tag,
            ChatTagColour = Color3.fromHex(tagColor),
            NameColour = Color3.fromHex(nameColor),
            TextColour = Color3.fromHex(textColor),
        })
    end)
    if ok then
        showNotification("Chat color appliquee")
    else
        showNotification("Erreur chat color")
    end
end)
makeLabel(settingsPage, "Outfit Hub v2 - Fait par Dayni", 11, C.muted, 20)

makeLabel(historyPage, "HISTORIQUE DES TENUES", 11, C.teal, 18)
makeLabel(historyPage, "Les dernieres tenues portees", 11, C.muted, 18)
local historyList = makeList(historyPage)
local function refreshHistory()
    for _, child in ipairs(historyList:GetChildren()) do
        if child:IsA("Frame") or child:IsA("TextLabel") then child:Destroy() end
    end
    if #outfitHistory == 0 then
        makeLabel(historyList, "Aucun historique", 12, C.muted, 30)
        return
    end
    for idx, entry in ipairs(outfitHistory) do
        local row = new("Frame", {
            Size = UDim2.new(1, -8, 0, 42),
            BackgroundColor3 = C.panel,
            ZIndex = 3,
        }, historyList)
        withCorner(row, 10)
        withStroke(row, C.border, 1)
        local timeAgo = ""
        local diff = os.time() - (entry.time or 0)
        if diff < 60 then timeAgo = "a l'instant"
        elseif diff < 3600 then timeAgo = math.floor(diff / 60) .. "min"
        elseif diff < 86400 then timeAgo = math.floor(diff / 3600) .. "h"
        else timeAgo = math.floor(diff / 86400) .. "j"
        end
        new("TextLabel", {
            Size = UDim2.new(0.55, 0, 1, 0),
            Position = UDim2.new(0.04, 0, 0, 0),
            BackgroundTransparency = 1,
            TextColor3 = C.row,
            Text = entry.name,
            TextXAlignment = Enum.TextXAlignment.Left,
            Font = FONT,
            TextSize = 13,
            ZIndex = 4,
        }, row)
        new("TextLabel", {
            Size = UDim2.new(0.2, 0, 1, 0),
            Position = UDim2.new(0.55, 0, 0, 0),
            BackgroundTransparency = 1,
            TextColor3 = C.muted,
            Text = timeAgo,
            Font = FONT_LIGHT,
            TextSize = 11,
            ZIndex = 4,
        }, row)
        local wearBtn = new("TextButton", {
            Size = UDim2.new(0.18, 0, 0.55, 0),
            Position = UDim2.new(0.78, 0, 0.225, 0),
            BackgroundColor3 = C.teal,
            TextColor3 = C.bg,
            Text = "Porter",
            Font = FONT_BOLD,
            TextSize = 12,
            ZIndex = 4,
        }, row)
        withCorner(wearBtn, 10)
        wearBtn.Activated:Connect(function()
            local outfitData = sessionOutfits[entry.name]
            if outfitData then
                wearOutfit(outfitData)
                showNotification("Tenue portee: " .. entry.name)
                addToHistory(entry.name)
                refreshHistory()
            end
        end)
    end
end

makeLabel(serverPage, "SERVEUR", 11, C.teal, 18)
local RejoinBtn = makeButton(serverPage, "Rejoindre ce serveur", UDim2.new(1, 0, 0, 42), C.teal)
local ServerHopBtn = makeButton(serverPage, "Changer de serveur", UDim2.new(1, 0, 0, 42), C.discord, Color3.new(1, 1, 1))
makeLabel(serverPage, "", 8, C.muted, 8)
makeLabel(serverPage, "Rejoindre: recharge le meme serveur", 11, C.muted, 18)
makeLabel(serverPage, "Changer: rejoint un autre serveur", 11, C.muted, 18)

RejoinBtn.Activated:Connect(function()
    showNotification("Rejoind du serveur...")
    rejoinServer()
end)
ServerHopBtn.Activated:Connect(function()
    showNotification("Changement de serveur...")
    serverHop()
end)

ThemeBtn.Activated:Connect(function()
    setTheme(themeName == "dark" and "light" or "dark")
    ThemeBtn.Text = "Theme : " .. (themeName == "dark" and "Sombre" or "Clair")
    if repaintGameBtn then repaintGameBtn() end
end)

local function refreshOutfitList()
    for _, child in ipairs(outfitList:GetChildren()) do
        if child:IsA("Frame") or child:IsA("TextLabel") then child:Destroy() end
    end

    local count = 0
    for _ in pairs(sessionOutfits) do count = count + 1 end
    CounterLabel.Text = count .. "/" .. MAX_OUTFITS .. " tenues"

    local outfits = loadSavedOutfits()
    local sortedNames = {}
    for name in pairs(outfits) do
        if searchFilter == "" or string.find(string.lower(name), string.lower(searchFilter), 1, true) then
            table.insert(sortedNames, name)
        end
    end
    table.sort(sortedNames, function(a, b) return string.lower(a) < string.lower(b) end)

    for idx, outfitName in ipairs(sortedNames) do
        local outfitData = outfits[outfitName]
        local row = new("Frame", {
            Size = UDim2.new(1, -8, 0, 48),
            BackgroundColor3 = C.panel,
            ZIndex = 3,
        }, outfitList)
        withCorner(row, 10)
        withStroke(row, C.border, 1)

        new("TextLabel", {
            Size = UDim2.new(0.5, 0, 1, 0),
            Position = UDim2.new(0.04, 0, 0, 0),
            BackgroundTransparency = 1,
            TextColor3 = C.row,
            Text = outfitName,
            TextXAlignment = Enum.TextXAlignment.Left,
            Font = FONT,
            TextSize = 13,
            ZIndex = 4,
        }, row)

        local wearBtn = new("TextButton", {
            Size = UDim2.new(0.2, 0, 0.55, 0),
            Position = UDim2.new(0.58, 0, 0.225, 0),
            BackgroundColor3 = C.teal,
            TextColor3 = C.bg,
            Text = "Porter",
            Font = FONT_BOLD,
            TextSize = 12,
            ZIndex = 4,
        }, row)
        withCorner(wearBtn, 10)
        wearBtn.MouseEnter:Connect(function()
            tw(wearBtn, { BackgroundColor3 = brightenColor(C.teal, 0.08) }, 0.15)
        end)
        wearBtn.MouseLeave:Connect(function()
            tw(wearBtn, { BackgroundColor3 = C.teal }, 0.15)
        end)
        wearBtn.Activated:Connect(function()
            wearOutfit(outfitData)
            addToHistory(outfitName)
            showNotification("Tenue portee: " .. outfitName)
        end)

        local delBtn = new("TextButton", {
            Size = UDim2.new(0.14, 0, 0.55, 0),
            Position = UDim2.new(0.82, 0, 0.225, 0),
            BackgroundColor3 = C.del,
            TextColor3 = Color3.new(1, 1, 1),
            Text = "Del",
            Font = FONT_BOLD,
            TextSize = 12,
            ZIndex = 4,
        }, row)
        withCorner(delBtn, 10)
        delBtn.MouseEnter:Connect(function()
            tw(delBtn, { BackgroundColor3 = C.delHover }, 0.15)
        end)
        delBtn.MouseLeave:Connect(function()
            tw(delBtn, { BackgroundColor3 = C.del }, 0.15)
        end)
        delBtn.Activated:Connect(function()
            sessionOutfits[outfitName] = nil
            saveOutfitsToFile()
            refreshOutfitList()
        end)

        row.BackgroundTransparency = 1
        for _, c in ipairs(row:GetDescendants()) do
            if c:IsA("TextLabel") or c:IsA("TextButton") then
                c.TextTransparency = 1
            end
        end
        task.delay(idx * 0.03, function()
            if row.Parent then
                tw(row, { BackgroundTransparency = 0 }, 0.2)
                for _, c in ipairs(row:GetDescendants()) do
                    if c:IsA("TextLabel") or c:IsA("TextButton") then
                        tw(c, { TextTransparency = 0 }, 0.2)
                    end
                end
            end
        end)
    end
end

refreshPlayerList = function()
    for _, child in ipairs(tpList:GetChildren()) do
        if child:IsA("Frame") or child:IsA("TextLabel") then child:Destroy() end
    end
    local players = Players:GetPlayers()
    table.sort(players, function(a, b) return string.lower(a.Name) < string.lower(b.Name) end)
    for idx, p in ipairs(players) do
        if p ~= localPlayer then
            local row = new("Frame", {
                Size = UDim2.new(1, -8, 0, 44),
                BackgroundColor3 = C.panel,
                ZIndex = 3,
            }, tpList)
            withCorner(row, 10)
            withStroke(row, C.border, 1)

            new("TextLabel", {
                Size = UDim2.new(0.36, 0, 1, 0),
                Position = UDim2.new(0.03, 0, 0, 0),
                BackgroundTransparency = 1,
                TextColor3 = C.row,
                Text = p.Name,
                TextXAlignment = Enum.TextXAlignment.Left,
                Font = FONT,
                TextSize = 13,
                ZIndex = 4,
            }, row)

            local tpBtn = new("TextButton", {
                Size = UDim2.new(0.26, 0, 0.55, 0),
                Position = UDim2.new(0.41, 0, 0.225, 0),
                BackgroundColor3 = C.teal,
                TextColor3 = C.bg,
                Text = "TP",
                Font = FONT_BOLD,
                TextSize = 12,
                ZIndex = 4,
            }, row)
            withCorner(tpBtn, 10)
            tpBtn.MouseEnter:Connect(function()
                tw(tpBtn, { BackgroundColor3 = brightenColor(C.teal, 0.08) }, 0.15)
            end)
            tpBtn.MouseLeave:Connect(function()
                tw(tpBtn, { BackgroundColor3 = C.teal }, 0.15)
            end)
            tpBtn.Activated:Connect(function()
                task.spawn(function()
                    local ok = teleportToPlayer(p)
                    if not ok then
                        showNotification("TP impossible, spectate: " .. p.Name)
                        startSpectate(p)
                    end
                end)
            end)

            local spectBtn = new("TextButton", {
                Size = UDim2.new(0.26, 0, 0.55, 0),
                Position = UDim2.new(0.71, 0, 0.225, 0),
                BackgroundColor3 = C.discord,
                TextColor3 = Color3.new(1, 1, 1),
                Text = "Spect",
                Font = FONT_BOLD,
                TextSize = 12,
                ZIndex = 4,
            }, row)
            withCorner(spectBtn, 10)
            spectBtn.MouseEnter:Connect(function()
                tw(spectBtn, { BackgroundColor3 = brightenColor(C.discord, 0.08) }, 0.15)
            end)
            spectBtn.MouseLeave:Connect(function()
                tw(spectBtn, { BackgroundColor3 = C.discord }, 0.15)
            end)
            spectBtn.Activated:Connect(function()
                startSpectate(p)
            end)

            row.BackgroundTransparency = 1
            for _, c in ipairs(row:GetDescendants()) do
                if c:IsA("TextLabel") or c:IsA("TextButton") then
                    c.TextTransparency = 1
                end
            end
            task.delay(idx * 0.03, function()
                if row.Parent then
                    tw(row, { BackgroundTransparency = 0 }, 0.2)
                    for _, c in ipairs(row:GetDescendants()) do
                        if c:IsA("TextLabel") or c:IsA("TextButton") then
                            tw(c, { TextTransparency = 0 }, 0.2)
                        end
                    end
                end
            end)
        end
    end
end

searchBox:GetPropertyChangedSignal("Text"):Connect(function()
    searchFilter = searchBox.Text
    refreshOutfitList()
end)

TpRefreshBtn.Activated:Connect(function()
    refreshPlayerList()
end)

SpectateStopBtn.Activated:Connect(function()
    stopSpectate()
    showNotification("Spectate arrete")
end)

ResetMoveBtn.Activated:Connect(function()
    walkSpeedValue = 16
    jumpPowerValue = 50
    wsSlider.set(16)
    jpSlider.set(50)
    applyMovement(localPlayer.Character)
    saveUiPositions()
end)

SettingsResetBtn.Activated:Connect(function()
    walkSpeedValue = 16
    jumpPowerValue = 50
    wsSlider.set(16)
    jpSlider.set(50)
    applyMovement(localPlayer.Character)
    saveUiPositions()
end)

local PopupOverlay = new("Frame", {
    Size = UDim2.new(1, 0, 1, 0),
    BackgroundColor3 = Color3.fromRGB(0, 0, 0),
    BackgroundTransparency = 1,
    ZIndex = 99,
    Visible = false,
}, ScreenGui)

local PopupFrame = new("Frame", {
    Size = UDim2.fromOffset(340, 180),
    Position = UDim2.new(0.5, -170, 0.5, -90),
    BackgroundColor3 = C.panel,
    ZIndex = 100,
    Visible = false,
    BackgroundTransparency = 1,
}, ScreenGui)
withCorner(PopupFrame, 16)
withStroke(PopupFrame, C.teal, 1.5)

local PopupLabel = new("TextLabel", {
    Size = UDim2.new(0.9, 0, 0, 44),
    Position = UDim2.new(0.05, 0, 0, 12),
    BackgroundTransparency = 1,
    TextColor3 = C.text,
    Text = "Confirmer ?",
    Font = FONT_BOLD,
    TextSize = 13,
    TextWrapped = true,
    ZIndex = 101,
}, PopupFrame)

local PopupConfirmBtn = makeButton(PopupFrame, "Sauvegarder", UDim2.new(0.3, 0, 0, 36), C.teal)
PopupConfirmBtn.Position = UDim2.new(0.04, 0, 0, 110)
local PopupWearBtn = makeButton(PopupFrame, "Porter", UDim2.new(0.3, 0, 0, 36), C.discord, Color3.new(1, 1, 1))
PopupWearBtn.Position = UDim2.new(0.35, 0, 0, 110)
local PopupCancelBtn = makeButton(PopupFrame, "Annuler", UDim2.new(0.3, 0, 0, 36), C.panelLight, C.text)
PopupCancelBtn.Position = UDim2.new(0.66, 0, 0, 110)

local popupCallback = nil
local popupWearCallback = nil

local function showPopup(message, callback, wearCallback)
    PopupLabel.Text = message
    PopupFrame.Visible = true
    PopupOverlay.Visible = true
    popupCallback = callback
    popupWearCallback = wearCallback
    PopupOverlay.BackgroundTransparency = 1
    PopupFrame.BackgroundTransparency = 1
    PopupFrame.Position = UDim2.new(0.5, -170, 0.5, -70)
    tw(PopupOverlay, { BackgroundTransparency = 0.5 }, 0.2)
    tw(PopupFrame, { BackgroundTransparency = 0, Position = UDim2.new(0.5, -170, 0.5, -90) }, 0.3, Enum.EasingStyle.Back)
    PopupWearBtn.Visible = (wearCallback ~= nil)
end

local function hidePopup()
    tw(PopupOverlay, { BackgroundTransparency = 1 }, 0.15)
    tw(PopupFrame, { BackgroundTransparency = 1, Position = UDim2.new(0.5, -170, 0.5, -70) }, 0.15, Enum.EasingStyle.Quint, Enum.EasingDirection.In)
    task.delay(0.15, function()
        PopupFrame.Visible = false
        PopupOverlay.Visible = false
    end)
    popupCallback = nil
    popupWearCallback = nil
end

PopupConfirmBtn.Activated:Connect(function()
    local cb = popupCallback
    hidePopup()
    if cb then cb() end
end)
PopupWearBtn.Activated:Connect(function()
    local cb = popupWearCallback
    hidePopup()
    if cb then cb() end
end)
PopupCancelBtn.Activated:Connect(function()
    hidePopup()
end)
PopupOverlay.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        hidePopup()
    end
end)

SettingsDeleteBtn.Activated:Connect(function()
    local count = 0
    for _ in pairs(sessionOutfits) do count = count + 1 end
    if count == 0 then return end
    showPopup("Supprimer toutes les tenues ?", function()
        sessionOutfits = {}
        saveOutfitsToFile()
        refreshOutfitList()
    end)
end)

task.spawn(function()
    local playerGui = localPlayer:WaitForChild("PlayerGui")
    local function findOutfitButton()
        return playerGui:FindFirstChild("OpenSavedOutfits", true)
    end
    local originalOutfitButton = findOutfitButton()
    for i = 1, 5 do
        if originalOutfitButton then break end
        task.wait(2)
        originalOutfitButton = findOutfitButton()
    end
    if not originalOutfitButton then return end
    local outfitButtonParent = originalOutfitButton.Parent
    if not outfitButtonParent then return end
    local existingBtn = outfitButtonParent:FindFirstChild("OutfitGrabBtn")
    if existingBtn then
        pcall(function() existingBtn:Destroy() end)
    end

    local outfitGrabBtn = originalOutfitButton:Clone()
    outfitGrabBtn.Name = "OutfitGrabBtn"
    outfitGrabBtn.Position = UDim2.new(originalOutfitButton.Position.X.Scale, originalOutfitButton.Position.X.Offset, originalOutfitButton.Position.Y.Scale, originalOutfitButton.Position.Y.Offset - originalOutfitButton.AbsoluteSize.Y - 6)
    outfitGrabBtn.Active = true
    outfitGrabBtn.AutoButtonColor = true
    outfitGrabBtn.ZIndex = originalOutfitButton.ZIndex + 1
    for _, child in ipairs(outfitGrabBtn:GetDescendants()) do
        if child:IsA("LocalScript") or child:IsA("Script") then
            child:Destroy()
        end
    end
    local function paintGui(gui)
        pcall(function() gui.BackgroundColor3 = C.teal end)
        pcall(function()
            if gui:IsA("ImageLabel") or gui:IsA("ImageButton") then
                gui.ImageColor3 = C.teal
                gui.ImageTransparency = 0
                if gui.BackgroundTransparency == 0 then gui.BackgroundTransparency = 0 end
            end
        end)
    end
    local function paintAll()
        paintGui(outfitGrabBtn)
        if outfitGrabBtn:IsA("TextButton") or outfitGrabBtn:IsA("TextLabel") then
            pcall(function()
                outfitGrabBtn.Text = "Outfit Hub"
                outfitGrabBtn.TextSize = 13
                outfitGrabBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
            end)
        end
        for _, child in ipairs(outfitGrabBtn:GetDescendants()) do
            paintGui(child)
            if child:IsA("TextLabel") or child:IsA("TextButton") then
                pcall(function()
                    child.Text = "Outfit Hub"
                    child.TextSize = 13
                    child.TextColor3 = Color3.fromRGB(255, 255, 255)
                end)
            end
        end
    end
    repaintGameBtn = paintAll
    paintAll()
    outfitGrabBtn.Parent = outfitButtonParent
    task.defer(paintAll)

    local toggleLocked = false
    local function toggleOutfitMenu()
        if toggleLocked then return end
        toggleLocked = true
        if Window.Visible then
            tw(Window, {
                Size = UDim2.new(0, 0, 0, 0),
                Position = UDim2.new(0.5, 0, 0.5, 0),
            }, 0.25, Enum.EasingStyle.Quint, Enum.EasingDirection.In)
            task.delay(0.25, function()
                Window.Visible = false
                Window.Size = UDim2.fromOffset(800, 540)
                Window.Position = UDim2.new(0.5, -400, 0.5, -270)
            end)
        else
            Window.Visible = true
            Window.Size = UDim2.new(0, 0, 0, 0)
            Window.Position = UDim2.new(0.5, 0, 0.5, 0)
            tw(Window, {
                Size = UDim2.fromOffset(800, 540),
                Position = UDim2.new(0.5, -400, 0.5, -270),
            }, 0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
            switchTab("outfits")
        end
        task.delay(0.15, function() toggleLocked = false end)
    end
    pcall(function() outfitGrabBtn.MouseButton1Click:Connect(toggleOutfitMenu) end)
    pcall(function() outfitGrabBtn.Activated:Connect(toggleOutfitMenu) end)
end)

minimizeBtn.Activated:Connect(function()
    tw(Window, {
        Size = UDim2.new(0, 0, 0, 0),
        Position = UDim2.new(0.5, 0, 0.5, 0),
    }, 0.25, Enum.EasingStyle.Quint, Enum.EasingDirection.In)
    task.delay(0.25, function()
        Window.Visible = false
        Window.Size = UDim2.fromOffset(800, 540)
        Window.Position = UDim2.new(0.5, -400, 0.5, -270)
    end)
end)

closeBtn.Activated:Connect(function()
    tw(Window, {
        Size = UDim2.new(0, 0, 0, 0),
        Position = UDim2.new(0.5, 0, 0.5, 0),
    }, 0.25, Enum.EasingStyle.Quint, Enum.EasingDirection.In)
    task.delay(0.25, function()
        Window.Visible = false
        Window.Size = UDim2.fromOffset(800, 540)
        Window.Position = UDim2.new(0.5, -400, 0.5, -270)
    end)
end)

ExportBtn.Activated:Connect(function()
    webhookURL = WebhookInput.Text
    saveUiPositions()
    ExportBtn.Text = "..."
    local ok, res = pcall(function() return exportOutfitsToDiscord() end)
    ExportBtn.Text = (ok and res) and "OK" or "Erreur"
    task.wait(1.5)
    ExportBtn.Text = "Exporter"
end)

ImportBtn.Activated:Connect(function()
    local json = ImportInput.Text
    if json == "" then
        ImportNameInput.PlaceholderText = "Colle le JSON !"
        return
    end
    local importName = ImportNameInput.Text
    if importName == "" then
        ImportNameInput.PlaceholderText = "Nom requis !"
        return
    end
    local ok, data = pcall(function() return HttpService:JSONDecode(json) end)
    if not ok or type(data) ~= "table" then
        ImportNameInput.PlaceholderText = "JSON invalide !"
        return
    end
    if not data.Properties then
        ImportNameInput.PlaceholderText = "JSON incomplet !"
        return
    end
    local count = 0
    for _ in pairs(sessionOutfits) do count = count + 1 end
    if count >= MAX_OUTFITS then
        ImportNameInput.PlaceholderText = "Limite atteinte !"
        return
    end
    sessionOutfits[importName] = {
        Properties = data.Properties,
        RigType = data.RigType or 1,
    }
    saveOutfitsToFile()
    ImportInput.Text = ""
    ImportNameInput.Text = ""
    ImportNameInput.PlaceholderText = "Importee !"
    refreshOutfitList()
end)

local function isClickingGui()
    local pos = UserInputService:GetMouseLocation()
    local ok, guis = pcall(function() return UserInputService:GetGuiObjectsAtPosition(pos.X, pos.Y) end)
    if not ok or not guis then return false end
    for _, g in ipairs(guis) do
        if g:IsA("TextButton") or g:IsA("ImageButton") or g:IsA("TextBox") then
            return true
        end
    end
    return false
end

local function getClickedPlayer(target)
    local current = target
    while current do
        if current:IsA("Model") then
            local p = Players:GetPlayerFromCharacter(current)
            if p then return p end
        end
        current = current.Parent
    end
    return nil
end

local button1DownConn = mouse.Button1Down:Connect(function()
    if isClickingGui() then return end
    local target = mouse.Target
    if not target then return end
    local player = getClickedPlayer(target)
    if not player or player == localPlayer then return end
    if clickTpEnabled then
        task.spawn(function()
            local ok = teleportToPlayer(player)
            showNotification(ok and ("TP vers: " .. player.Name) or ("TP impossible: " .. player.Name))
        end)
        return
    end
    if not clickModeActive then return end
    print("[OutfitHub] Tenue volee sur: " .. player.Name .. " (ID: " .. player.UserId .. ")")
    local rawProps, rigType = getOutfitFromCharacter(player.Character)
    if not rawProps then
        print("[OutfitHub] Impossible de lire les props de " .. player.Name)
        return
    end
    local stolenData = {
        Properties = serializeProperties(rawProps),
        RigType = (rigType or Enum.HumanoidRigType.R15).Value,
        _targetPlayer = player,
    }
    local outfitData = stolenData
    clickModeActive = false
    clickToggle.set(false)

    showPopup("Tenue de " .. player.Name .. "\nSauvegarder cette tenue ?", function()
        local dataToSave = { Properties = outfitData.Properties, RigType = outfitData.RigType }
        sessionOutfits[player.Name] = dataToSave
        saveOutfitsToFile()
        refreshOutfitList()
        if outfitData._targetPlayer then
            stealOutfitFromCharacter(outfitData._targetPlayer)
        else
            wearOutfit(dataToSave)
        end
        addToHistory(player.Name)
        showNotification("Tenue sauvegardee et portee: " .. player.Name)
    end, function()
        if outfitData._targetPlayer then
            stealOutfitFromCharacter(outfitData._targetPlayer)
        else
            wearOutfit(outfitData)
        end
        showNotification("Tenue portee (non sauvegardee)")
    end)
end)
addCleanup(function() button1DownConn:Disconnect() end)

SaveMyBtn.Activated:Connect(function()
    local name = SaveNameInput.Text
    if name == "" then
        SaveNameInput.PlaceholderText = "Nom requis !"
        return
    end
    local rawProps, rigType = getOutfitFromCharacter(localPlayer.Character)
    if not rawProps then return end
    local function doSave()
        sessionOutfits[name] = {
            Properties = serializeProperties(rawProps),
            RigType = (rigType or Enum.HumanoidRigType.R15).Value
        }
        saveOutfitsToFile()
        SaveNameInput.Text = ""
        SaveNameInput.PlaceholderText = "Sauvegardee !"
        refreshOutfitList()
        showNotification("Tenue sauvegardee: " .. name)
    end
    if sessionOutfits[name] then
        showPopup("Ecraser la tenue \"".. name .. "\"?", function()
            doSave()
        end)
        return
    end
    local count = 0
    for _ in pairs(sessionOutfits) do count = count + 1 end
    if count >= MAX_OUTFITS then
        SaveNameInput.PlaceholderText = "Limite atteinte !"
        return
    end
    doSave()
end)

local playerAddedConn = Players.PlayerAdded:Connect(function(player)
    if espEnabled and player ~= localPlayer then
        createESP(player)
    end
    if refreshPlayerList then refreshPlayerList() end
end)
addCleanup(function() playerAddedConn:Disconnect() end)

local playerRemovingConn = Players.PlayerRemoving:Connect(function(player)
    if spectateTarget == player then stopSpectate() end
    if espCache[player] then
        pcall(function() espCache[player].gui:Destroy() end)
        espCache[player] = nil
    end
    if espConnections[player] then
        for _, conn in ipairs(espConnections[player]) do
            pcall(function() conn:Disconnect() end)
        end
        espConnections[player] = nil
    end
    if refreshPlayerList then refreshPlayerList() end
end)
addCleanup(function() playerRemovingConn:Disconnect() end)

local heartbeatConn = RunService.Heartbeat:Connect(function()
    if not espEnabled then return end
    local myChar = localPlayer.Character
    local myHead = myChar and myChar:FindFirstChild("Head")
    for player, data in pairs(espCache) do
        if player.Parent and data and data.gui and data.gui.Parent then
            if myHead and data.head and data.head.Parent then
                local dist = (myHead.Position - data.head.Position).Magnitude
                data.lastDist = math.floor(dist)
                setEspInfoText(data)
            elseif data.head and not data.head.Parent then
                if player.Character and player.Character:FindFirstChild("Head") then
                    createESP(player)
                else
                    espCache[player] = nil
                end
            end
        elseif player.Parent then
            espCache[player] = nil
            if espEnabled and player ~= localPlayer and player.Character then
                createESP(player)
            end
        else
            espCache[player] = nil
        end
    end
end)
addCleanup(function() heartbeatConn:Disconnect() end)

local function doInfJump()
    if not infJumpEnabled then return end
    local char = localPlayer.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if hum and hum.Health > 0 and os.clock() - lastJumpTime > 0.1 then
        hum:ChangeState(Enum.HumanoidStateType.Jumping)
        lastJumpTime = os.clock()
    end
end

local jumpRequestConn = UserInputService.JumpRequest:Connect(doInfJump)
addCleanup(function() jumpRequestConn:Disconnect() end)
local spaceConn = UserInputService.InputBegan:Connect(function(input, gpe)
    if gpe then return end
    if input.KeyCode == Enum.KeyCode.Space then
        doInfJump()
    end
end)
addCleanup(function() spaceConn:Disconnect() end)

local charAddedConn = localPlayer.CharacterAdded:Connect(function(char)
    applyMovement(char)
    if flyEnabled then
        task.wait(0.5)
        startFly()
    end
    if autoEquipEnabled and autoEquipOutfitName and sessionOutfits[autoEquipOutfitName] then
        task.wait(0.5)
        wearOutfit(sessionOutfits[autoEquipOutfitName])
        showNotification("Auto-equip: " .. autoEquipOutfitName)
    end
end)
addCleanup(function() charAddedConn:Disconnect() end)

RandomBtn.Activated:Connect(function()
    local keys = {}
    for k in pairs(sessionOutfits) do keys[#keys + 1] = k end
    if #keys == 0 then
        showNotification("Aucune tenue sauvegardee")
        return
    end
    local pick = keys[math.random(1, #keys)]
    wearOutfit(sessionOutfits[pick])
    addToHistory(pick)
    showNotification("Tenue aleatoire: " .. pick)
    if historyPage then refreshHistory() end
end)

LikeOutfitBtn.Activated:Connect(function()
    local Event = ReplicatedStorage:FindFirstChild("Events") and ReplicatedStorage.Events:FindFirstChild("LikeOutfit")
    if not Event then
        showNotification("LikeOutfit introuvable")
        return
    end
    local count = 0
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= localPlayer then
            pcall(function() Event:FireServer(player) end)
            count = count + 1
        end
    end
    showNotification("Like envoye a " .. count .. " joueur(s)")
end)

local keybindConn = UserInputService.InputBegan:Connect(function(input, gpe)
    if gpe then return end
    if keybindNoclip and input.KeyCode == keybindNoclip then
        noclipEnabled = not noclipEnabled
        setNoclip(noclipEnabled)
        showNotification("Noclip: " .. (noclipEnabled and "ON" or "OFF"))
    end
    if keybindFly and input.KeyCode == keybindFly then
        flyEnabled = not flyEnabled
        if flyEnabled then startFly() else stopFly() end
        showNotification("Fly: " .. (flyEnabled and "ON" or "OFF"))
    end
    if keybindSpeed and input.KeyCode == keybindSpeed then
        if walkSpeedValue < 50 then
            walkSpeedValue = 100
        else
            walkSpeedValue = 16
        end
        applyMovement(localPlayer.Character)
        showNotification("Speed: " .. walkSpeedValue)
    end
    if keybindClick and input.KeyCode == keybindClick then
        clickModeActive = not clickModeActive
clickToggle.set(clickModeActive)
clickTpToggle.set(clickTpEnabled)
        saveUiPositions()
        showNotification("Click mode: " .. (clickModeActive and "ON" or "OFF"))
    end
    if keybindClickTp and input.KeyCode == keybindClickTp then
        clickTpEnabled = not clickTpEnabled
        clickTpToggle.set(clickTpEnabled)
        saveUiPositions()
        showNotification("Click TP: " .. (clickTpEnabled and "ON" or "OFF"))
    end
end)
addCleanup(function() keybindConn:Disconnect() end)

applyMovement(localPlayer.Character)
refreshOutfitList()
refreshHistory()
switchTab("outfits")

wsSlider.set(walkSpeedValue)
jpSlider.set(jumpPowerValue)
flySpeedSlider.set(flySpeed)
spinSpeedSlider.set(spinSpeed)
zoomSlider.set(zoomDistance)
if fullbrightEnabled then setFullbright(true) end
FullbrightToggle.set(fullbrightEnabled)
if spinEnabled then setSpin(true) end
spinToggle.set(spinEnabled)

if noclipEnabled then setNoclip(true) end
noclipToggle.set(noclipEnabled)

if espEnabled then enableESP() end
espToggle.set(espEnabled)

if antiAfkEnabled then task.spawn(antiAfkLoop) end
antiAfkToggle.set(antiAfkEnabled)

if autoAfkStatusEnabled then setAutoAfkStatus(true) end
autoAfkStatusToggle.set(autoAfkStatusEnabled)

infJumpToggle.set(infJumpEnabled)

if rpAutoEnabled and #rpNamePhrases > 0 then
    task.spawn(rpAutoLoop)
end
rpAutoToggle.set(rpAutoEnabled)

clickToggle.set(clickModeActive)

if flyEnabled then
    task.spawn(function()
        task.wait(0.5)
        if flyEnabled then startFly() end
    end)
end
flyToggle.set(flyEnabled)

if autoEquipEnabled and autoEquipOutfitName then
    autoEquipLabel.Text = "Auto-equip: " .. autoEquipOutfitName
end
if _savedChatTag ~= "" then chatTagInput.Text = _savedChatTag end
if _savedChatTagColor ~= "" then chatTagColorInput.Text = _savedChatTagColor end
if _savedChatNameColor ~= "" then chatNameColorInput.Text = _savedChatNameColor end
if _savedChatTextColor ~= "" then chatTextColorInput.Text = _savedChatTextColor end
refreshRpNameList()
if savedRpName ~= "" then
    if savedRpLabel then savedRpLabel.Text = "RP sauvegarde: " .. savedRpName end
    task.spawn(function()
        task.wait(3)
        pcall(function()
            game.ReplicatedStorage.Events.SettingsRemoteFunction:InvokeServer({
                Action = "SetDisplayName",
                DisplayName = savedRpName
            })
        end)
    end)
end

perfHudLabel = new("TextLabel", {
    Size = UDim2.new(0, 160, 0, 22),
    Position = UDim2.new(0, 10, 1, -30),
    BackgroundColor3 = Color3.new(0, 0, 0),
    BackgroundTransparency = 0.35,
    Text = "FPS: ... | MS: ...",
    TextSize = 13,
    TextColor3 = Color3.new(255, 255, 255),
    Font = FONT_BOLD,
    TextXAlignment = Enum.TextXAlignment.Left,
    ZIndex = 999,
}, ScreenGui)
local perfFpsAvg = 0
local perfFrameCount = 0
local perfLastTime = 0
local perfPingItem = nil
pcall(function() perfPingItem = game:GetService("Stats").Network.ServerStatsItem["Data Ping"] end)
perfHudConn = RunService.RenderStepped:Connect(function()
    local now = os.clock()
    perfFrameCount = perfFrameCount + 1
    if perfLastTime == 0 then perfLastTime = now end
    local elapsed = now - perfLastTime
    if elapsed >= 0.5 then
        local fps = perfFrameCount / elapsed
        perfFpsAvg = perfFpsAvg * 0.7 + fps * 0.3
        perfLastTime = now
        perfFrameCount = 0
    end
    local ms = 0
    if perfPingItem then
        pcall(function() ms = math.floor(perfPingItem:GetValue()) end)
    end
    if perfHudLabel then
        perfHudLabel.Text = "FPS: " .. math.floor(perfFpsAvg) .. " | MS: " .. tostring(ms)
    end
end)
addCleanup(function()
    if perfHudConn then pcall(function() perfHudConn:Disconnect() end) perfHudConn = nil end
end)

_G.__OH_CLEANUP = function()
    for _, espData in pairs(espCache) do
        if espData and espData.gui then pcall(function() espData.gui:Destroy() end) end
    end
    for player, conns in pairs(espConnections) do
        for _, c in ipairs(conns) do pcall(function() c:Disconnect() end) end
    end
    espCache = {}
    espConnections = {}
    for _, conn in ipairs(cleanupList) do pcall(function() conn() end) end
    cleanupList = {}
    if noclipConn then pcall(function() noclipConn:Disconnect() end) noclipConn = nil end
    if flyConn then pcall(function() flyConn:Disconnect() end) flyConn = nil end
    if spinConn then pcall(function() spinConn:Disconnect() end) spinConn = nil end
    if fullbrightConn then pcall(function() fullbrightConn:Disconnect() end) fullbrightConn = nil end
    if spectateConn then pcall(function() spectateConn:Disconnect() end) spectateConn = nil end
    spectateTarget = nil
    pcall(function() camera.CameraType = Enum.CameraType.Custom end)
    if noclipEnabled then noclipEnabled = false end
    if flyEnabled then
        pcall(function() stopFly() end)
        flyEnabled = false
    end
    local gui = playerGui:FindFirstChild("OutfitManagerGUI")
    if gui then gui:Destroy() end
end

end)()

