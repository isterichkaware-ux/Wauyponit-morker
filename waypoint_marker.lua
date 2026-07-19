-- Waypoint Marker - мини-утилита для записи координат 2 точек
-- Встань в нужном месте -> жми "Mark Waypoint 1" / "Mark Waypoint 2"
-- Координаты печатаются в консоль и копируются в буфер обмена (если экзекутор поддерживает setclipboard)

local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

local Fluent = loadstring(game:HttpGet("https://github.com/dawid-scripts/Fluent/releases/latest/download/main.lua"))()

local Window = Fluent:CreateWindow({
    Title = "Waypoint Marker",
    SubTitle = "Тереяки с Клаудом",
    TabWidth = 120,
    Size = UDim2.fromOffset(420, 260),
    Acrylic = false,
    Theme = "Dark",
    MinimizeKey = Enum.KeyCode.RightControl
})

local Tabs = {
    Main = Window:AddTab({ Title = "Waypoints", Icon = "map-pin" })
}

local Waypoint1 = nil
local Waypoint2 = nil

local function getPosition()
    local character = LocalPlayer.Character
    local hrp = character and character:FindFirstChild("HumanoidRootPart")
    if not hrp then
        Fluent:Notify({ Title = "Waypoint Marker", Content = "Персонаж не найден", Duration = 2 })
        return nil
    end
    return hrp.Position
end

local function formatVector(pos)
    if not pos then return "не установлен" end
    return string.format("Vector3.new(%.2f, %.2f, %.2f)", pos.X, pos.Y, pos.Z)
end

local wp1Label = Tabs.Main:AddParagraph({
    Title = "Waypoint 1",
    Content = "не установлен"
})

local wp2Label = Tabs.Main:AddParagraph({
    Title = "Waypoint 2",
    Content = "не установлен"
})

local function copyToClipboard(text)
    if type(setclipboard) == "function" then
        pcall(setclipboard, text)
        return true
    end
    return false
end

Tabs.Main:AddButton({
    Title = "Mark Waypoint 1",
    Description = "Записать текущую позицию персонажа как точку 1",
    Callback = function()
        local pos = getPosition()
        if not pos then return end
        Waypoint1 = pos
        local text = formatVector(pos)
        wp1Label:SetDesc(text)
        print("[WAYPOINT 1] " .. text)
        local copied = copyToClipboard(text)
        Fluent:Notify({
            Title = "Waypoint 1 записан",
            Content = copied and "Скопировано в буфер" or "Смотри консоль",
            Duration = 3
        })
    end
})

Tabs.Main:AddButton({
    Title = "Mark Waypoint 2",
    Description = "Записать текущую позицию персонажа как точку 2",
    Callback = function()
        local pos = getPosition()
        if not pos then return end
        Waypoint2 = pos
        local text = formatVector(pos)
        wp2Label:SetDesc(text)
        print("[WAYPOINT 2] " .. text)
        local copied = copyToClipboard(text)
        Fluent:Notify({
            Title = "Waypoint 2 записан",
            Content = copied and "Скопировано в буфер" or "Смотри консоль",
            Duration = 3
        })
    end
})

Tabs.Main:AddButton({
    Title = "Print Both / Copy Both",
    Description = "Вывести обе точки разом (удобно скопировать целиком)",
    Callback = function()
        local text = "Waypoint1 = " .. formatVector(Waypoint1) .. "\nWaypoint2 = " .. formatVector(Waypoint2)
        print("---- WAYPOINTS ----")
        print(text)
        print("-------------------")
        local copied = copyToClipboard(text)
        Fluent:Notify({
            Title = "Обе точки",
            Content = copied and "Скопировано в буфер" or "Смотри консоль",
            Duration = 3
        })
    end
})

Fluent:Notify({ Title = "Waypoint Marker", Content = "Загружено. Встань в точке и жми Mark.", Duration = 3 })
