-- GameClient: весь интерфейс игрока. Собирается кодом, крупный, под телефон.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local remotes = ReplicatedStorage:WaitForChild("Remotes")
local syncRemote = remotes:WaitForChild("Sync")
local buyRemote = remotes:WaitForChild("Buy")
local toastRemote = remotes:WaitForChild("Toast")
local respawnRemote = remotes:WaitForChild("Respawn")

local ACCENT = Color3.fromRGB(96, 205, 255)
local PANEL = Color3.fromRGB(22, 24, 32)
local TEXT = Color3.fromRGB(240, 244, 255)
local GOLD = Color3.fromRGB(255, 208, 92)

local state = { coins = 0, stage = 0, stages = 0, gameName = "", upgrades = {} }
local rows = {}
local toastToken = 0

-- =====================================================================
-- Хелперы
-- =====================================================================

local function round(instance, radius)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius or 12)
	corner.Parent = instance
	return corner
end

local function outline(instance, color, thickness)
	local stroke = Instance.new("UIStroke")
	stroke.Color = color or ACCENT
	stroke.Thickness = thickness or 1.5
	stroke.Transparency = 0.35
	stroke.Parent = instance
	return stroke
end

local function makeFrame(props)
	local frame = Instance.new("Frame")
	frame.BackgroundColor3 = PANEL
	frame.BorderSizePixel = 0
	for key, value in pairs(props) do
		frame[key] = value
	end
	return frame
end

local function makeLabel(props)
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextColor3 = TEXT
	label.TextXAlignment = Enum.TextXAlignment.Left
	for key, value in pairs(props) do
		label[key] = value
	end
	return label
end

local function makeButton(props)
	local button = Instance.new("TextButton")
	button.BackgroundColor3 = ACCENT
	button.BorderSizePixel = 0
	button.AutoButtonColor = true
	button.Font = Enum.Font.GothamBold
	button.TextColor3 = Color3.fromRGB(10, 14, 20)
	button.TextScaled = true
	for key, value in pairs(props) do
		button[key] = value
	end
	round(button, 12)
	return button
end

-- =====================================================================
-- Верхняя панель
-- =====================================================================

local gui = Instance.new("ScreenGui")
gui.Name = "HUD"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = playerGui

local topPanel = makeFrame({
	Name = "Top",
	Size = UDim2.new(0, 250, 0, 84),
	Position = UDim2.new(0, 16, 0, 16),
	BackgroundTransparency = 0.1,
	Parent = gui,
})
round(topPanel, 16)
outline(topPanel)

local coinsLabel = makeLabel({
	Name = "Coins",
	Size = UDim2.new(1, -24, 0, 34),
	Position = UDim2.new(0, 14, 0, 10),
	TextSize = 26,
	TextColor3 = GOLD,
	Text = "Монеты: 0",
	Parent = topPanel,
})

local stageLabel = makeLabel({
	Name = "Stage",
	Size = UDim2.new(1, -24, 0, 26),
	Position = UDim2.new(0, 14, 0, 46),
	TextSize = 20,
	Font = Enum.Font.Gotham,
	Text = "Этап: 0",
	Parent = topPanel,
})

local shopButton = makeButton({
	Name = "ShopButton",
	Size = UDim2.new(0, 170, 0, 58),
	Position = UDim2.new(0, 16, 0, 110),
	Text = "МАГАЗИН",
	Parent = gui,
})

local respawnButton = makeButton({
	Name = "RespawnButton",
	Size = UDim2.new(0, 170, 0, 48),
	Position = UDim2.new(0, 16, 0, 176),
	BackgroundColor3 = Color3.fromRGB(70, 76, 96),
	TextColor3 = TEXT,
	Text = "НА ЧЕКПОИНТ",
	Parent = gui,
})

local toastLabel = makeLabel({
	Name = "Toast",
	Size = UDim2.new(0, 460, 0, 44),
	Position = UDim2.new(0.5, -230, 0, 24),
	TextXAlignment = Enum.TextXAlignment.Center,
	TextSize = 24,
	TextStrokeTransparency = 0.4,
	TextTransparency = 1,
	Text = "",
	Parent = gui,
})

local function showToast(text)
	toastToken = toastToken + 1
	local token = toastToken
	toastLabel.Text = text
	toastLabel.TextTransparency = 0
	task.delay(2.5, function()
		if token == toastToken then
			toastLabel.TextTransparency = 1
		end
	end)
end

-- =====================================================================
-- Магазин
-- =====================================================================

local shop = makeFrame({
	Name = "Shop",
	Size = UDim2.new(0, 460, 0, 420),
	Position = UDim2.new(0.5, -230, 0.5, -210),
	BackgroundTransparency = 0.05,
	Visible = false,
	Parent = gui,
})
round(shop, 18)
outline(shop)

local shopTitle = makeLabel({
	Name = "Title",
	Size = UDim2.new(1, -120, 0, 40),
	Position = UDim2.new(0, 20, 0, 14),
	TextSize = 26,
	Text = "Магазин прокачки",
	Parent = shop,
})

local shopCoins = makeLabel({
	Name = "ShopCoins",
	Size = UDim2.new(1, -40, 0, 24),
	Position = UDim2.new(0, 20, 0, 52),
	Font = Enum.Font.Gotham,
	TextSize = 18,
	TextColor3 = GOLD,
	Text = "Монеты: 0",
	Parent = shop,
})

local closeButton = makeButton({
	Name = "Close",
	Size = UDim2.new(0, 44, 0, 44),
	Position = UDim2.new(1, -58, 0, 14),
	BackgroundColor3 = Color3.fromRGB(230, 90, 90),
	TextColor3 = Color3.fromRGB(255, 255, 255),
	Text = "X",
	Parent = shop,
})

local list = Instance.new("ScrollingFrame")
list.Name = "List"
list.Size = UDim2.new(1, -32, 1, -100)
list.Position = UDim2.new(0, 16, 0, 86)
list.BackgroundTransparency = 1
list.BorderSizePixel = 0
list.ScrollBarThickness = 6
list.CanvasSize = UDim2.new(0, 0, 0, 0)
list.AutomaticCanvasSize = Enum.AutomaticSize.Y
list.Parent = shop

local layout = Instance.new("UIListLayout")
layout.Padding = UDim.new(0, 10)
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.Parent = list

local function createRow(info, order)
	local row = makeFrame({
		Name = info.id,
		Size = UDim2.new(1, -8, 0, 78),
		BackgroundColor3 = Color3.fromRGB(32, 36, 48),
		LayoutOrder = order,
		Parent = list,
	})
	round(row, 12)

	local name = makeLabel({
		Size = UDim2.new(1, -150, 0, 26),
		Position = UDim2.new(0, 14, 0, 10),
		TextSize = 20,
		Text = info.name,
		Parent = row,
	})

	local desc = makeLabel({
		Size = UDim2.new(1, -150, 0, 20),
		Position = UDim2.new(0, 14, 0, 36),
		Font = Enum.Font.Gotham,
		TextSize = 15,
		TextColor3 = Color3.fromRGB(170, 178, 196),
		Text = info.desc,
		Parent = row,
	})

	local level = makeLabel({
		Size = UDim2.new(1, -150, 0, 18),
		Position = UDim2.new(0, 14, 0, 56),
		Font = Enum.Font.Gotham,
		TextSize = 14,
		TextColor3 = ACCENT,
		Text = "Уровень 0",
		Parent = row,
	})

	local buy = makeButton({
		Size = UDim2.new(0, 120, 0, 52),
		Position = UDim2.new(1, -132, 0, 13),
		Text = "Купить",
		Parent = row,
	})
	buy.Activated:Connect(function()
		buyRemote:FireServer(info.id)
	end)

	return { row = row, name = name, desc = desc, level = level, buy = buy }
end

local function renderShop()
	shopCoins.Text = "Монеты: " .. state.coins
	for order, info in ipairs(state.upgrades) do
		local entry = rows[info.id]
		if not entry then
			entry = createRow(info, order)
			rows[info.id] = entry
		end
		entry.name.Text = info.name
		entry.desc.Text = info.desc
		entry.level.Text = "Уровень " .. info.level .. " из " .. info.max
		if info.level >= info.max then
			entry.buy.Text = "Максимум"
			entry.buy.BackgroundColor3 = Color3.fromRGB(70, 76, 96)
		else
			entry.buy.Text = info.price .. " мон."
			if state.coins >= info.price then
				entry.buy.BackgroundColor3 = ACCENT
			else
				entry.buy.BackgroundColor3 = Color3.fromRGB(90, 96, 116)
			end
		end
	end
end

local function renderHud()
	coinsLabel.Text = "Монеты: " .. state.coins
	stageLabel.Text = "Этап: " .. state.stage .. " из " .. state.stages
	if state.gameName ~= "" then
		shopTitle.Text = "Магазин — " .. state.gameName
	end
	if shop.Visible then
		renderShop()
	end
end

shopButton.Activated:Connect(function()
	shop.Visible = not shop.Visible
	if shop.Visible then
		renderShop()
	end
end)

closeButton.Activated:Connect(function()
	shop.Visible = false
end)

respawnButton.Activated:Connect(function()
	respawnRemote:FireServer()
end)

syncRemote.OnClientEvent:Connect(function(payload)
	if type(payload) ~= "table" then
		return
	end
	state.coins = payload.coins or state.coins
	state.stage = payload.stage or state.stage
	state.stages = payload.stages or state.stages
	state.gameName = payload.gameName or state.gameName
	state.upgrades = payload.upgrades or state.upgrades
	renderHud()
end)

toastRemote.OnClientEvent:Connect(function(text)
	if type(text) == "string" then
		showToast(text)
	end
end)

renderHud()
