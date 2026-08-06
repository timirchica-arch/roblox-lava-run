-- GameServer: строит весь мир кодом и ведёт игру.
-- В файле плейса ничего нет, кроме скриптов, поэтому любое изменение
-- игры — это правка этого файла и новая публикация.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataStoreService = game:GetService("DataStoreService")
local TweenService = game:GetService("TweenService")
local Lighting = game:GetService("Lighting")

local Config = require(ReplicatedStorage:WaitForChild("Config"))

Players.RespawnTime = 2

-- =====================================================================
-- Базовые хелперы
-- =====================================================================

local world = Instance.new("Folder")
world.Name = "World"
world.Parent = workspace

local function makePart(props)
	local part = Instance.new("Part")
	part.Anchored = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Material = Enum.Material.SmoothPlastic
	for key, value in pairs(props) do
		part[key] = value
	end
	if part.Parent == nil then
		part.Parent = world
	end
	return part
end

local function makeSign(parent, text, color, offsetY)
	local gui = Instance.new("BillboardGui")
	gui.Name = "Sign"
	gui.Size = UDim2.new(0, 220, 0, 60)
	gui.StudsOffset = Vector3.new(0, offsetY or 3, 0)
	gui.MaxDistance = 260
	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, 0, 1, 0)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextScaled = true
	label.TextColor3 = color or Color3.fromRGB(255, 255, 255)
	label.TextStrokeTransparency = 0.35
	label.Text = text
	label.Parent = gui
	gui.Parent = parent
	return gui
end

local function playerFromHit(hit)
	local character = hit and hit.Parent
	if not character then
		return nil, nil
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return nil, nil
	end
	local player = Players:GetPlayerFromCharacter(character)
	if not player then
		return nil, nil
	end
	return player, humanoid
end

local function setupLighting()
	Lighting.Brightness = 2.6
	Lighting.ClockTime = 15.5
	Lighting.Ambient = Color3.fromRGB(70, 70, 85)
	Lighting.OutdoorAmbient = Color3.fromRGB(130, 125, 140)
	Lighting.FogEnd = 1400
	Lighting.FogColor = Color3.fromRGB(190, 160, 150)
	local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
	if not atmosphere then
		atmosphere = Instance.new("Atmosphere")
	end
	atmosphere.Density = 0.3
	atmosphere.Haze = 1.4
	atmosphere.Color = Color3.fromRGB(230, 190, 170)
	atmosphere.Decay = Color3.fromRGB(120, 90, 90)
	atmosphere.Parent = Lighting
end

-- =====================================================================
-- Сетевые события и хранилище
-- =====================================================================

local remotes = Instance.new("Folder")
remotes.Name = "Remotes"

local function makeRemote(name)
	local remote = Instance.new("RemoteEvent")
	remote.Name = name
	remote.Parent = remotes
	return remote
end

local syncRemote = makeRemote("Sync")
local buyRemote = makeRemote("Buy")
local toastRemote = makeRemote("Toast")
local respawnRemote = makeRemote("Respawn")
remotes.Parent = ReplicatedStorage

local store = nil
do
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(Config.SaveKey)
	end)
	if ok then
		store = result
	end
end

local sessions = {}
local lastAction = {}

-- =====================================================================
-- Данные игрока
-- =====================================================================

local function defaultData()
	return { stage = 0, coins = 0, upgrades = {} }
end

local function loadData(player)
	local data = defaultData()
	if not store then
		return data
	end
	local ok, saved = pcall(function()
		return store:GetAsync("p_" .. player.UserId)
	end)
	if ok and type(saved) == "table" then
		data.stage = tonumber(saved.stage) or 0
		data.coins = tonumber(saved.coins) or 0
		if type(saved.upgrades) == "table" then
			for key, value in pairs(saved.upgrades) do
				if type(key) == "string" and tonumber(value) then
					data.upgrades[key] = tonumber(value)
				end
			end
		end
	end
	return data
end

local function saveData(player)
	local data = sessions[player]
	if not data or not store then
		return
	end
	pcall(function()
		store:SetAsync("p_" .. player.UserId, {
			stage = data.stage,
			coins = data.coins,
			upgrades = data.upgrades,
		})
	end)
end

local function upgradeDef(id)
	for _, def in ipairs(Config.Upgrades) do
		if def.id == id then
			return def
		end
	end
	return nil
end

local function levelOf(data, id)
	if not data then
		return 0
	end
	return data.upgrades[id] or 0
end

local function priceOf(def, level)
	return math.floor(def.cost * (def.growth ^ level) + 0.5)
end

local function updateStats(player)
	local data = sessions[player]
	local stats = player:FindFirstChild("leaderstats")
	if not data or not stats then
		return
	end
	local stageValue = stats:FindFirstChild("Этап")
	local coinValue = stats:FindFirstChild("Монеты")
	if stageValue then
		stageValue.Value = data.stage
	end
	if coinValue then
		coinValue.Value = data.coins
	end
end

local function syncPlayer(player)
	local data = sessions[player]
	if not data then
		return
	end
	local list = {}
	for _, def in ipairs(Config.Upgrades) do
		local level = levelOf(data, def.id)
		table.insert(list, {
			id = def.id,
			name = def.name,
			desc = def.desc,
			level = level,
			max = def.max,
			price = priceOf(def, level),
		})
	end
	syncRemote:FireClient(player, {
		coins = data.coins,
		stage = data.stage,
		stages = Config.Stages,
		gameName = Config.Name,
		upgrades = list,
	})
end

local function toast(player, text)
	toastRemote:FireClient(player, text)
end

local function applyUpgrades(player)
	local data = sessions[player]
	local character = player.Character
	if not data or not character then
		return
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end
	local speedDef = upgradeDef("speed")
	local jumpDef = upgradeDef("jump")
	local speedStep = speedDef and speedDef.step or 0
	local jumpStep = jumpDef and jumpDef.step or 0
	humanoid.WalkSpeed = Config.WalkSpeed + levelOf(data, "speed") * speedStep
	humanoid.UseJumpPower = true
	humanoid.JumpPower = Config.JumpPower + levelOf(data, "jump") * jumpStep
end

local function giveCoins(player, amount)
	local data = sessions[player]
	if not data or amount <= 0 then
		return
	end
	data.coins = data.coins + amount
	updateStats(player)
	syncPlayer(player)
end

local function throttled(player, key, seconds)
	local now = os.clock()
	local bucket = lastAction[player]
	if not bucket then
		bucket = {}
		lastAction[player] = bucket
	end
	local previous = bucket[key] or 0
	if now - previous < seconds then
		return true
	end
	bucket[key] = now
	return false
end

-- =====================================================================
-- Мир: чекпоинты, монеты, препятствия
-- =====================================================================

local checkpoints = {}
local coins = {}
local blades = {}

local function collectCoin(player, coin)
	if coin:GetAttribute("Ready") ~= true then
		return
	end
	local data = sessions[player]
	if not data then
		return
	end
	coin:SetAttribute("Ready", false)
	coin.Transparency = 1
	coin.CanTouch = false

	local luckDef = upgradeDef("luck")
	local bonus = levelOf(data, "luck") * (luckDef and luckDef.step or 0)
	giveCoins(player, Config.CoinValue + bonus)

	task.delay(Config.CoinRespawn, function()
		if coin.Parent then
			coin.Transparency = 0
			coin.CanTouch = true
			coin:SetAttribute("Ready", true)
		end
	end)
end

local function makeCoin(position)
	local coin = makePart({
		Name = "Coin",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.4, 2.2, 2.2),
		Position = position,
		Color = Color3.fromRGB(255, 206, 74),
		Material = Enum.Material.Neon,
		CanCollide = false,
	})
	coin:SetAttribute("Ready", true)
	coin:SetAttribute("Base", position)
	coin.Touched:Connect(function(hit)
		local player = playerFromHit(hit)
		if player then
			collectCoin(player, coin)
		end
	end)
	table.insert(coins, coin)
	return coin
end

local function reachCheckpoint(player, stage)
	local data = sessions[player]
	if not data or stage <= data.stage then
		return
	end
	data.stage = stage
	updateStats(player)
	giveCoins(player, 3)
	if stage >= Config.Stages then
		giveCoins(player, Config.FinishBonus)
		toast(player, "ФИНИШ! +" .. Config.FinishBonus .. " монет")
	else
		toast(player, "Этап " .. stage .. " из " .. Config.Stages)
	end
	syncPlayer(player)
	saveData(player)
end

local function teleportToStage(player)
	local data = sessions[player]
	local character = player.Character
	if not data or not character then
		return
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end
	local target = checkpoints[data.stage] or checkpoints[0]
	if target then
		root.CFrame = target
	end
end

local function buildLava()
	local spanX = Config.PlatformSize.X + Config.Gap
	local length = (Config.Stages + 3) * spanX
	local lava = makePart({
		Name = "Lava",
		Size = Vector3.new(length, 4, Config.LavaWidth),
		Position = Vector3.new(length / 2 - spanX, Config.LavaY, 0),
		Color = Color3.fromRGB(255, 94, 40),
		Material = Enum.Material.Neon,
	})
	lava.Touched:Connect(function(hit)
		local _, humanoid = playerFromHit(hit)
		if humanoid then
			humanoid.Health = 0
		end
	end)
end

local function buildObstacle(rng, midX, midY, color)
	local kind = rng:NextInteger(1, 3)

	if kind == 1 then
		-- две ступеньки со смещением в сторону
		for _, shift in ipairs({ -Config.Gap / 3, Config.Gap / 3 }) do
			makePart({
				Name = "Step",
				Size = Vector3.new(5, 1, 5),
				Position = Vector3.new(midX + shift, midY, rng:NextNumber(-4, 4)),
				Color = color,
			})
		end
	elseif kind == 2 then
		-- платформа, катающаяся туда-сюда
		local mover = makePart({
			Name = "Mover",
			Size = Vector3.new(8, 1, 8),
			Position = Vector3.new(midX, midY, -9),
			Color = Color3.fromRGB(250, 226, 120),
		})
		local info = TweenInfo.new(rng:NextNumber(2.5, 4), Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true)
		TweenService:Create(mover, info, { Position = mover.Position + Vector3.new(0, 0, 18) }):Play()
	else
		-- узкий мостик с вращающимся лезвием
		makePart({
			Name = "Narrow",
			Size = Vector3.new(Config.Gap + 2, 1, 4),
			Position = Vector3.new(midX, midY, 0),
			Color = color,
		})
		local blade = makePart({
			Name = "Blade",
			Size = Vector3.new(1.2, 1.2, 16),
			Position = Vector3.new(midX, midY + 2.5, 0),
			Color = Color3.fromRGB(255, 76, 76),
			Material = Enum.Material.Neon,
			CanCollide = false,
		})
		blade:SetAttribute("Pivot", blade.Position)
		blade:SetAttribute("Speed", rng:NextNumber(1.2, 2.4))
		blade.Touched:Connect(function(hit)
			local _, humanoid = playerFromHit(hit)
			if humanoid then
				humanoid.Health = 0
			end
		end)
		table.insert(blades, blade)
	end
end

local function buildStart()
	local spawnPoint = Instance.new("SpawnLocation")
	spawnPoint.Name = "Start"
	spawnPoint.Size = Vector3.new(10, 1, 10)
	spawnPoint.Position = Vector3.new(0, Config.StartHeight + 1, 0)
	spawnPoint.Anchored = true
	spawnPoint.Neutral = true
	spawnPoint.Duration = 0
	spawnPoint.Color = Color3.fromRGB(90, 200, 255)
	spawnPoint.Material = Enum.Material.Neon
	spawnPoint.TopSurface = Enum.SurfaceType.Smooth
	spawnPoint.Parent = world
	makeSign(spawnPoint, Config.Name .. " — старт", Color3.fromRGB(150, 230, 255), 4)
end

local function buildFinish(lastX, lastY)
	local podium = makePart({
		Name = "Finish",
		Size = Vector3.new(22, 2, 22),
		Position = Vector3.new(lastX + Config.PlatformSize.X + 12, lastY + 1, 0),
		Color = Color3.fromRGB(120, 255, 180),
		Material = Enum.Material.Neon,
	})
	makeSign(podium, "ФИНИШ", Color3.fromRGB(190, 255, 215), 5)
end

local function buildCourse()
	local rng = Random.new(Config.Seed)
	local spanX = Config.PlatformSize.X + Config.Gap
	local lastX = 0
	local lastY = Config.StartHeight

	for stage = 0, Config.Stages do
		local x = stage * spanX
		local y = Config.StartHeight + stage * Config.HeightStep
		local color = Config.Palette[(stage % #Config.Palette) + 1]
		lastX = x
		lastY = y

		makePart({
			Name = "Stage" .. stage,
			Size = Config.PlatformSize,
			Position = Vector3.new(x, y, 0),
			Color = color,
		})

		checkpoints[stage] = CFrame.new(x, y + 4, 0)

		if stage > 0 then
			local pad = makePart({
				Name = "Checkpoint",
				Size = Vector3.new(7, 0.4, 7),
				Position = Vector3.new(x, y + 0.7, 0),
				Color = Color3.fromRGB(80, 230, 140),
				Material = Enum.Material.Neon,
				CanCollide = false,
			})
			makeSign(pad, tostring(stage), Color3.fromRGB(180, 255, 205), 2)
			local stageNumber = stage
			pad.Touched:Connect(function(hit)
				local player = playerFromHit(hit)
				if player then
					reachCheckpoint(player, stageNumber)
				end
			end)
		end

		for index = 1, Config.CoinsPerStage do
			local offsetZ = (index - (Config.CoinsPerStage + 1) / 2) * 4
			makeCoin(Vector3.new(x + rng:NextNumber(-3, 3), y + 4, offsetZ))
		end

		if stage < Config.Stages then
			buildObstacle(rng, x + spanX / 2, y + Config.HeightStep / 2, color)
		end
	end

	buildFinish(lastX, lastY)
end

setupLighting()
buildLava()
buildStart()
buildCourse()

-- =====================================================================
-- Игроки
-- =====================================================================

local function onCharacterAdded(player, character)
	character:WaitForChild("Humanoid", 10)
	task.wait(0.2)
	teleportToStage(player)
	applyUpgrades(player)
end

Players.PlayerAdded:Connect(function(player)
	sessions[player] = loadData(player)

	local stats = Instance.new("Folder")
	stats.Name = "leaderstats"
	local stageValue = Instance.new("IntValue")
	stageValue.Name = "Этап"
	stageValue.Parent = stats
	local coinValue = Instance.new("IntValue")
	coinValue.Name = "Монеты"
	coinValue.Parent = stats
	stats.Parent = player

	updateStats(player)
	syncPlayer(player)

	player.CharacterAdded:Connect(function(character)
		onCharacterAdded(player, character)
	end)
	if player.Character then
		onCharacterAdded(player, player.Character)
	end
end)

Players.PlayerRemoving:Connect(function(player)
	saveData(player)
	sessions[player] = nil
	lastAction[player] = nil
end)

game:BindToClose(function()
	for _, player in ipairs(Players:GetPlayers()) do
		saveData(player)
	end
	task.wait(1)
end)

-- =====================================================================
-- Кнопки с клиента
-- =====================================================================

buyRemote.OnServerEvent:Connect(function(player, id)
	if type(id) ~= "string" or throttled(player, "buy", 0.25) then
		return
	end
	local data = sessions[player]
	local def = upgradeDef(id)
	if not data or not def then
		return
	end
	local level = levelOf(data, id)
	if level >= def.max then
		toast(player, def.name .. ": уже максимум")
		return
	end
	local price = priceOf(def, level)
	if data.coins < price then
		toast(player, "Не хватает монет: нужно " .. price)
		return
	end
	data.coins = data.coins - price
	data.upgrades[id] = level + 1
	updateStats(player)
	applyUpgrades(player)
	syncPlayer(player)
	toast(player, def.name .. ": уровень " .. (level + 1))
	saveData(player)
end)

respawnRemote.OnServerEvent:Connect(function(player)
	if throttled(player, "respawn", 1) then
		return
	end
	teleportToStage(player)
end)

-- =====================================================================
-- Живой мир
-- =====================================================================

local clock = 0
RunService.Heartbeat:Connect(function(delta)
	clock = clock + delta
	local spin = math.rad(Config.CoinSpinSpeed) * clock

	for _, coin in ipairs(coins) do
		if coin.Parent and coin.Transparency < 1 then
			local base = coin:GetAttribute("Base")
			if base then
				local bob = math.sin(clock * 2 + base.X * 0.2) * 0.35
				coin.CFrame = CFrame.new(base + Vector3.new(0, bob, 0)) * CFrame.Angles(0, spin, 0)
			end
		end
	end

	for _, blade in ipairs(blades) do
		local pivot = blade:GetAttribute("Pivot")
		local speed = blade:GetAttribute("Speed") or 1
		if pivot then
			blade.CFrame = CFrame.new(pivot) * CFrame.Angles(0, clock * speed, 0)
		end
	end
end)

task.spawn(function()
	local magnetDef = upgradeDef("magnet")
	local magnetStep = magnetDef and magnetDef.step or 0
	while true do
		task.wait(0.25)
		for _, player in ipairs(Players:GetPlayers()) do
			local data = sessions[player]
			local level = levelOf(data, "magnet")
			if data and level > 0 then
				local character = player.Character
				local root = character and character:FindFirstChild("HumanoidRootPart")
				if root then
					local radius = level * magnetStep
					for _, coin in ipairs(coins) do
						if coin:GetAttribute("Ready") == true then
							if (coin.Position - root.Position).Magnitude <= radius then
								collectCoin(player, coin)
							end
						end
					end
				end
			end
		end
	end
end)

task.spawn(function()
	while true do
		task.wait(Config.AutosaveSeconds)
		for _, player in ipairs(Players:GetPlayers()) do
			saveData(player)
		end
	end
end)

print("[" .. Config.Name .. "] мир построен: этапов " .. Config.Stages .. ", монет " .. #coins)
