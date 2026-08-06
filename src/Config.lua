-- Config: все настройки игры в одном месте.
-- Меняешь число здесь — меняется игра после следующей публикации.

local Config = {}

Config.Name = "Lava Run"
Config.Version = "1.0.0"
Config.Seed = 20260806

-- Трасса
Config.Stages = 18
Config.PlatformSize = Vector3.new(16, 1, 16)
Config.Gap = 14
Config.StartHeight = 10
Config.HeightStep = 1.5

-- Лава внизу
Config.LavaY = -8
Config.LavaWidth = 400

-- Монеты
Config.CoinsPerStage = 2
Config.CoinValue = 1
Config.CoinRespawn = 8
Config.CoinSpinSpeed = 120

-- Игрок
Config.WalkSpeed = 16
Config.JumpPower = 50
Config.FinishBonus = 50

-- Магазин прокачки
Config.Upgrades = {
	{ id = "speed", name = "Скорость", desc = "+2 к скорости бега", cost = 20, growth = 1.55, max = 12, step = 2 },
	{ id = "jump", name = "Прыжок", desc = "+3 к силе прыжка", cost = 30, growth = 1.6, max = 10, step = 3 },
	{ id = "magnet", name = "Магнит", desc = "+5 к радиусу сбора монет", cost = 80, growth = 1.9, max = 6, step = 5 },
	{ id = "luck", name = "Удача", desc = "+1 монета за каждую собранную", cost = 150, growth = 2.1, max = 5, step = 1 },
}

-- Цвета площадок
Config.Palette = {
	Color3.fromRGB(86, 180, 233),
	Color3.fromRGB(120, 200, 140),
	Color3.fromRGB(240, 200, 90),
	Color3.fromRGB(200, 130, 220),
	Color3.fromRGB(240, 140, 110),
}

-- Сохранения
Config.SaveKey = "LavaRun_v1"
Config.AutosaveSeconds = 90

return Config
