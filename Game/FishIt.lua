--!strict
local getgenv: () -> ({[string]: any}) = getfenv().getgenv

getgenv().ScriptVersion = "v0.0.0.1"
getgenv().Changelog = [[
v0.0.0.1
Welcome to EXECUTIVE
]]

do
  local Core = loadstring(game:HttpGet("https://raw.githubusercontent.com/futurewayys/executive/refs/heads/main/Core.lua"))
  if not Core then return warn("Failed to load the Executive Core") end
  Core()
end

type Element = {
	CurrentValue: any,
	CurrentOption: {string},
	Set: (self: Element, any) -> ()
}

type Tab = {
	CreateSection: (self: Tab, Name: string) -> Element,
	CreateDivider: (self: Tab) -> Element,
	CreateToggle: (self: Tab, any) -> Element,
	CreateSlider: (self: Tab, any) -> Element,
	CreateDropdown: (self: Tab, any) -> Element,
	CreateButton: (self: Tab, any) -> Element,
	CreateLabel: (self: Tab, any, any?) -> Element,
	CreateParagraph: (self: Tab, any) -> Element,
}

local Notify = getgenv().Notify
local CreateFeature = getgenv().CreateFeature

local Player = game:GetService("Players").LocalPlayer
local Character = Player.Character or Player.CharacterAdded:Wait()
local Humanoid = Character:WaitForChild("Humanoid")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Net = ReplicatedStorage:WaitForChild("Packages"):WaitForChild("_Index"):WaitForChild("sleitnick_net@0.2.0"):WaitForChild("net")
local Flags = getgenv().Flags

local MenuRings = Workspace:WaitForChild("!!! MENU RINGS")
local Zones = Workspace:WaitForChild("Zones")
local RfChargeFishingRod = Net:WaitForChild("RF/ChargeFishingRod")
local RfRequestFishingMinigame = Net:WaitForChild("RF/RequestFishingMinigameStarted")
local RfCancelFishingInputs = Net:WaitForChild("RF/CancelFishingInputs")
local ReFishingCompleted = Net:WaitForChild("RE/FishingCompleted")
local ReReplicateTextEffect = Net:WaitForChild("RE/ReplicateTextEffect")
local ReFishCaught = Net:WaitForChild("RE/FishCaught")
local ReEquipToolFromHotbar = Net:WaitForChild("RE/EquipToolFromHotbar")
local ReFavoriteItem = Net:WaitForChild("RE/FavoriteItem")
local RfPurchaseMarketItem = Net:WaitForChild("RF/PurchaseMarketItem")
local RfUpdateAutoSellThreshold = Net:WaitForChild("RF/UpdateAutoSellThreshold")

local ItemUtility = require(ReplicatedStorage.Shared.ItemUtility)
local Replion = require(ReplicatedStorage.Packages.Replion)
local PlayerData = Replion.Client:WaitReplion("Data")

Player.CharacterAdded:Connect(function(NewCharacter)
	Character = NewCharacter
	Humanoid = Character:WaitForChild("Humanoid")
end)

local RarityOrder = {
  Common = 1,
  Uncommon = 2,
  Rare = 3,
  Epic = 4,
  Legendary = 5,
  Mythical = 6,
  Secret = 7
}

local RarityMap = {
  ["255_250_246"] = "Common",
  ["195_255_85"] = "Uncommon",
  ["85_162_255"] = "Rare",
  ["173_79_255"] = "Epic",
  ["255_184_42"] = "Legendary",
  ["255_24_24"] = "Mythical"
}

local CutsceneController, NotificationController, AnimationController, FishingController

pcall(function()
  CutsceneController = require(ReplicatedStorage.Controllers.CutsceneController)
  local OriginalPlay = CutsceneController.Play
  CutsceneController.Play = function(self, ...)
    if Flags.SkipCutscenes.CurrentValue then
      Player:SetAttribute("IgnoreFOV", false)
      return
    end
    return OriginalPlay(self, ...)
  end

  local OriginalStop = CutsceneController.Stop
  CutsceneController.Stop = function(self, ...)
    Player:SetAttribute("IgnoreFOV", false)
    return OriginalStop(self, ...)
  end
end)

pcall(function()
  NotificationController = require(ReplicatedStorage.Controllers.NotificationController)
  local OriginalNotif = NotificationController.PlaySmallItemObtained
  NotificationController.PlaySmallItemObtained = function(self, ...)
    if Flags.HideNotifications.CurrentValue then return end
    return OriginalNotif(self, ...)
  end
end)

pcall(function()
  AnimationController = require(ReplicatedStorage.Controllers.AnimationController)
  local OriginalAnim = AnimationController.PlayAnimation
  AnimationController.PlayAnimation = function(self, ...)
    if Flags.DisableAnimations.CurrentValue then return end
    return OriginalAnim(self, ...)
  end
end)

local Window = getgenv().Window

local FishingTab = Window:CreateTab({
  Name = "Auto Fishing",
  Icon = "fish",
  ImageSource = "Lucide",
  ShowTitle = false
})

local FishingThreads = {}

local function ManageThread(name, flagName, func)
  if FishingThreads[name] then
    task.cancel(FishingThreads[name])
    FishingThreads[name] = nil
  end

  if not Flags[flagName].CurrentValue then
    pcall(RfCancelFishingInputs.InvokeServer, RfCancelFishingInputs)
    ReEquipToolFromHotbar:FireServer(1)
    return
  end

  FishingThreads[name] = task.spawn(func)
end

local function GetRarityFromRGB(r, g, b)
  return RarityMap[string.format("%d_%d_%d", r, g, b)] or "Secret"
end

local function AutoFishing()
  ManageThread("AutoFishing", "AutoFishing", function()
    while Flags.AutoFishing.CurrentValue and task.wait() do
      pcall(RfChargeFishingRod.InvokeServer, RfChargeFishingRod)
      pcall(RfRequestFishingMinigame.InvokeServer, RfRequestFishingMinigame, -1, 1, workspace:GetServerTimeNow())
    end
  end)
end

local function SuperBlatant()
  ManageThread("SuperBlatant", "SuperBlatant", function()
    while Flags.SuperBlatant.CurrentValue do
      task.spawn(function()
        pcall(function()
          RfCancelFishingInputs:InvokeServer()
          task.wait(0.001)
          ReEquipToolFromHotbar:FireServer(1)
          task.wait(0.001)
          RfChargeFishingRod:InvokeServer()
          RfRequestFishingMinigame:InvokeServer(-1, 1, workspace:GetServerTimeNow())
        end)
      end)
      task.wait(Flags.ReelDelay.CurrentValue)
    end
  end)
end

local function LegitFishing()
  ManageThread("LegitFishing", "LegitFishing", function()
    repeat task.wait() until game:IsLoaded()

    local FishingController = require(ReplicatedStorage.Controllers.FishingController)
    require(ReplicatedStorage.Shared.Constants).FishingCooldownTime = 0

    local State, CurrentGuid, MinigameCompleted, StateTime = "Idle", nil, false, os.clock()

    local function DetectState()
      local Guid = FishingController:GetCurrentGUID()
      if Guid then
        if State ~= "Minigame" then
          CurrentGuid, MinigameCompleted = Guid, false
        end
        return "Minigame"
      end

      if CurrentGuid and not Guid then
        local IsBusy = (FishingController.FishingLine and FishingController.FishingLine.Parent)
          or (FishingController.FishingBobber and FishingController.FishingBobber.Parent)
          or FishingController._isFishing or FishingController._isReeling

        if IsBusy then return "Reeling" end
        if MinigameCompleted then return "Completed" end
        CurrentGuid = nil
        return "Idle"
      end

      return (FishingController.OnCooldown and FishingController:OnCooldown()) and "Waiting" or "Idle"
    end

    while Flags.LegitFishing.CurrentValue do
      local NewState = DetectState()
      if NewState ~= State then
        State, StateTime = NewState, os.clock()
      end

      if (State == "Casting" or State == "Waiting") and (os.clock() - StateTime) > 8 then
        pcall(RfCancelFishingInputs.InvokeServer, RfCancelFishingInputs)
        State, StateTime = "Idle", os.clock()
      elseif State == "Idle" and not FishingController:OnCooldown() then
        pcall(RfCancelFishingInputs.InvokeServer, RfCancelFishingInputs)
        pcall(FishingController.RequestChargeFishingRod, FishingController, nil, true)
        State = "Casting"
      elseif State == "Minigame" then
        local Connection = RunService.Heartbeat:Connect(function()
          if FishingController:GetCurrentGUID() and Flags.LegitFishing.CurrentValue then
            for i = 1, 5 do
              pcall(FishingController.FishingMinigameClick, FishingController)
            end
          end
        end)

        repeat task.wait() until not FishingController:GetCurrentGUID() or not Flags.LegitFishing.CurrentValue
        Connection:Disconnect()

        if CurrentGuid then
          MinigameCompleted = true
          State = "Completed"
        end
      elseif State == "Completed" then
        CurrentGuid, MinigameCompleted, State = nil, false, "Idle"
      end
      task.wait()
    end
  end)
end

ReReplicateTextEffect.OnClientEvent:Connect(function(data)
  if not (data and data.TextData and data.TextData.EffectType == "Exclaim") then return end
  if not (Character and data.Container == Character:FindFirstChild("Head")) then return end

  local colorSeq = data.TextData.TextColor
  if not (colorSeq and typeof(colorSeq) == "ColorSequence" and #colorSeq.Keypoints > 0) then return end

  local color = colorSeq.Keypoints[1].Value
  local rarity = GetRarityFromRGB(math.floor(color.R * 255 + 0.5), math.floor(color.G * 255 + 0.5), math.floor(color.B * 255 + 0.5))

  if Flags.AutoFishing.CurrentValue or Flags.SuperBlatant.CurrentValue then
    if table.find(Flags.ExceptCatch.CurrentOption, rarity) then
      pcall(RfCancelFishingInputs.InvokeServer, RfCancelFishingInputs)
      ReEquipToolFromHotbar:FireServer(1)
      return
    end

    task.delay(Flags.CatchDelay.CurrentValue, function()
      for i = 1, 5 do
        pcall(ReFishingCompleted.FireServer, ReFishingCompleted)
        task.wait(0.1)
      end
    end)
  end
end)

ReFishCaught.OnClientEvent:Connect(function()
  task.delay(0.2, function()
    pcall(RfCancelFishingInputs.InvokeServer, RfCancelFishingInputs)
    ReEquipToolFromHotbar:FireServer(1)
  end)
end)

FishingTab:CreateSection("Fishing Modes")

FishingTab:CreateToggle({Name = "Legit Fishing", Callback = LegitFishing}, "LegitFishing")
FishingTab:CreateToggle({Name = "Auto Fishing", Callback = AutoFishing}, "AutoFishing")
FishingTab:CreateToggle({Name = "Super Blatant", Callback = SuperBlatant}, "SuperBlatant")

FishingTab:CreateSection("Fishing Settings")

FishingTab:CreateSlider({
  Name = "Reel Delay",
  Range = {0.01, 5},
  Increment = 0.01,
  CurrentValue = 1.9,
  Callback = function()end
}, "ReelDelay")

FishingTab:CreateSlider({
  Name = "Catch Delay",
  Range = {0.01, 5},
  Increment = 0.01,
  CurrentValue = 1.2,
  Callback = function()end
}, "CatchDelay")

FishingTab:CreateDropdown({
  Name = "Except Catch",
  Description = "Select fish to not auto catch.",
  Options = {"Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythical", "Secret"},
  CurrentOption = {},
  MultipleOptions = true,
  Callback = function()end
}, "ExceptCatch")

pcall(function()
  FishingController = require(ReplicatedStorage.Controllers.FishingController)
  require(ReplicatedStorage.Shared.Constants).FishingCooldownTime = 0

  local OriginalCooldown = FishingController.OnCooldown
  FishingController.OnCooldown = function(self, ...)
    if Flags.SuperBlatant.CurrentValue or Flags.AutoFishing.CurrentValue then
      return false
    end
    return OriginalCooldown(self, ...)
  end
end)

local InventoryTab = Window:CreateTab({
  Name = "Inventory",
  Icon = "backpack",
  ImageSource = "Lucide",
  ShowTitle = false
})

local function GetInventoryCount()
  if not (PlayerData and PlayerData.Data and PlayerData.Data.Inventory) then return 0 end
  local Count = 0
  for _, Item in pairs(PlayerData.Data.Inventory.Items) do
    if Item.Metadata and Item.Metadata.Weight then Count = Count + 1 end
  end
  return Count
end

local function IsFavorited(UUID)
  for _, Item in pairs(PlayerData.Data.Inventory.Items) do
    if Item.UUID == UUID then return Item.Favorited == true end
  end
  return false
end

local function AutoFavorite(name, rarities)
  local Items = PlayerData.Data.Inventory.Items
  if not Items or #Items == 0 then return end

  local rarityTiers = {}
  if rarities then
    for _, rarity in ipairs(rarities) do
      if RarityOrder[rarity] then table.insert(rarityTiers, RarityOrder[rarity]) end
    end
  end

  for _, Item in pairs(Items) do
    local FishData = ItemUtility:GetItemData(Item.Id)
    if FishData and FishData.Data and not IsFavorited(Item.UUID) then
      local matchName = (name and name ~= "" and FishData.Data.Name == name)
      local matchRarity = (#rarityTiers > 0 and table.find(rarityTiers, FishData.Data.Tier))

      if matchName or matchRarity then
        ReFavoriteItem:FireServer(Item.UUID)
      end
    end
  end
end

InventoryTab:CreateSection("Auto Favorite")

InventoryTab:CreateDropdown({
  Name = "Auto Favorite Rarity",
  Description = "Automatically favorite caught fish of the specified rarity.",
  Options = {"Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythical", "Secret"},
  CurrentOption = {},
  MultipleOptions = true,
  Callback = function()end
}, "AutoFavoriteRarity")

InventoryTab:CreateInput({
  Name = "Auto Favorite Fish",
  Description = "Automatically favorite caught fish of the specified name.",
  CurrentValue = "",
  PlaceholderText = "Fish Name",
  RemoveTextAfterFocusLost = false,
  Numeric = false,
  Enter = true,
  MaxCharacters = 30,
}, "AutoFavoriteFish")

InventoryTab:CreateToggle({
  Name = "Enable Auto Favorite",
  Callback = function()
    while Flags.EnableAutoFavorite.CurrentValue and task.wait(1) do
      AutoFavorite(Flags.AutoFavoriteFish.CurrentValue, Flags.AutoFavoriteRarity.CurrentOption)
    end
  end
}, "EnableAutoFavorite")

InventoryTab:CreateSection("Auto Sell")

InventoryTab:CreateDropdown({
  Name = "Threshold Sell Rarity",
  Description = "Set auto sell threshold for fish rarity.",
  Options = {"Secret", "Mythical", "Legendary"},
  CurrentOption = {},
  MultipleOptions = false,
  Callback = function(option)
    local RarityOrder = {
      Secret = 7,
      Mythical = 6,
      Legendary = 5,
    }

    if not RarityOrder[option] then return end

    RfUpdateAutoSellThreshold:InvokeServer(RarityOrder[option])

    Notify("Executive", "Set auto sell threshold to "..option)
  end
}, "ThresholdSell")

InventoryTab:CreateInput({
  Name = "Sell At Amount",
  Description = "Sets the amount of items to sell at once.",
  CurrentValue = "500",
  PlaceholderText = "Amount",
  RemoveTextAfterFocusLost = false,
  Numeric = true,
  Enter = false,
  MaxCharacters = 4,
}, "SellAtAmount")

InventoryTab:CreateToggle({
  Name = "Auto Sell",
  Callback = function()
    while Flags.AutoSellAll.CurrentValue and task.wait(.1) do
      if GetInventoryCount() >= tonumber(Flags.SellAtAmount.CurrentValue) then
        Net:WaitForChild("RF/SellAllItems"):InvokeServer()
      end
    end
  end
}, "AutoSellAll")

local ShopTab = Window:CreateTab({
  Name = "Shop",
  Icon = "shopping_cart",
  ImageSource = "Material",
  ShowTitle = false
})

local WeatherList = {
  "Wind (10,000)",
  "Cloudy (20,000)",
  "Snow (15,000)",
  "Storm (35,000)",
  "Radiant (50,000)",
  "Shark Hunt (300,000)"
}

ShopTab:CreateDropdown({
  Name = "Select Weather",
  Description = "Select the weather you want to buy.",
  Options = WeatherList,
  CurrentOption = {},
  MultipleOptions = true,
  Callback = function()end
}, "SelectWeather")

ShopTab:CreateToggle({
  Name = "Auto Buy Weather",
  Callback = function()
    while Flags.BuyWeather.CurrentValue and task.wait(1) do
      for _, Weather in pairs(Flags.SelectWeather.CurrentOption) do
        local Name = Weather:match("^(.-) %(")
        if Name then
          Net:WaitForChild("RF/PurchaseWeatherEvent"):InvokeServer(Name)
          task.wait(1)
        end
      end
    end
  end
}, "BuyWeather")

ShopTab:CreateSection("Item Shop")

local TotemList = {
  Luck = 5,
  Mutations = 8,
  Shiny = 7
}

ShopTab:CreateDropdown({
  Name = "Select Totem",
  Description = "Select the totem you want to buy.",
  Options = { "Luck", "Mutations", "Shiny" },
  CurrentOption = {},
  MultipleOptions = false,
  Callback = function()end
}, "SelectTotem")

ShopTab:CreateButton({
  Name = "Buy Totem",
  Callback = function()
    local TotemName = Flags.SelectTotem.CurrentOption
    if not TotemName or TotemName == "" then return end

    local TotemIndex = TotemList[TotemName]
    if not TotemIndex then return end

    RfPurchaseMarketItem:InvokeServer(TotemIndex)
  end
})

local TeleportTab = Window:CreateTab({
  Name = "Teleport",
  Icon = "flag-triangle-right",
  ImageSource = "Lucide",
  ShowTitle = false
})

local teleportLocations = {
  ["Fisherman Island"] = CFrame.new(92, 9, 2768),
  ["Arrow Lever"] = CFrame.new(898, 8, -363),
  ["Sisyphus Statue"] = CFrame.new(-3740, -136, -1013),
  ["Ancient Jungle"] = CFrame.new(1481, 11, -302),
  ["Weather Machine"] = CFrame.new(-1519, 2, 1908),
  ["Coral Refs"] = CFrame.new(-3105, 6, 2218),
  ["Tropical Island"] = CFrame.new(-2110, 53, 3649),
  ["Kohana"] = CFrame.new(-662, 3, 714),
  ["Esoteric Island"] = CFrame.new(2035, 27, 1386),
  ["Diamond Lever"] = CFrame.new(1818, 8, -285),
  ["Underground Cellar"] = CFrame.new(2098, -92, -703),
  ["Volcano"] = CFrame.new(-631, 54, 194),
  ["Enchant Room"] = CFrame.new(3255, -1302, 1371),
  ["Lost Isle"] = CFrame.new(-3717, 5, -1079),
  ["Sacred Temple"] = CFrame.new(1475, -22, -630),
  ["Creater Island"] = CFrame.new(981, 41, 5080),
  ["Double Enchant Room"] = CFrame.new(1480, 127, -590),
  ["Treasure Room"] = CFrame.new(-3599, -276, -1642),
  ["Crescent Lever"] = CFrame.new(1419, 31, 78),
  ["Hourglass Diamond Lever"] = CFrame.new(1484, 8, -862),
  ["Snow Island"] = CFrame.new(1627, 4, 3288),
  ["Ancient Ruin"] = CFrame.new(6087, -584, 4633),
  ["Classic Island"] = CFrame.new(1251, 11, 2803),
  ["Iron Cavern"] = CFrame.new(-8913, -580, 156),
  ["Iron Cafe"] = CFrame.new(-8642, -546, 149),
}

local function GetNameTeleport()
  local Names = {}
  for Key,_ in pairs(teleportLocations) do table.insert(Names, Key) end
  return Names
end

TeleportTab:CreateSection("Locations")

TeleportTab:CreateDropdown({
  Name = "Select Location",
  Description = "Select the location you want to teleport to.",
  Options = GetNameTeleport(),
  CurrentOption = {},
  MultipleOptions = false,
  Callback = function(option)
    if not teleportLocations[option] then return end
    if Character and Character:FindFirstChild("HumanoidRootPart") then
      Character:PivotTo(teleportLocations[option])
      Notify("Executive", "Teleported to " .. option)
    end
  end
})

TeleportTab:CreateSection("Events")

local function GetEventLocations()
  local List = {}
  for _, Obj in ipairs(MenuRings:GetChildren()) do
    if Obj:IsA("Model") and Obj.Name == "Props" then
      for _, Prop in ipairs(Obj:GetChildren()) do
        if Prop:IsA("Model") then
          if Prop.Name == "Model" then
            table.insert(List, "Worm Hunt")
          else
            table.insert(List, Prop.Name)
          end
        end
      end
    end
  end
  return List
end

TeleportTab:CreateDropdown({
  Name = "Select Event",
  Description = "Select the event location you want to teleport to.",
  Options = GetEventLocations(),
  CurrentOption = {},
  MultipleOptions = false,
  Callback = function() end
}, "SelectEvent")

TeleportTab:CreateButton({
  Name = "Teleport to Event",
  Callback = function()
    local EventName = Flags.SelectEvent.CurrentOption
    if not EventName or EventName == "" then return end

    local Target = nil
    for _, Obj in ipairs(MenuRings:GetChildren()) do
      if Obj:IsA("Model") and Obj.Name == "Props" then
        for _, Prop in ipairs(Obj:GetChildren()) do
          if Prop:IsA("Model") then
            if Prop.Name == EventName then
              Target = Prop
            end
          end
        end
      end
    end

    Character:PivotTo(Target:GetPivot())

    task.wait(.5)

    local Ocean = Zones:FindFirstChild("Ocean")
    for _, obj in ipairs(Ocean:GetDescendants()) do
      if obj:IsA("Texture") then
        obj.Parent.CanCollide = true
      end
    end
  end
})

task.spawn(function()
	while true and task.wait(0.5) do
		Flags.SelectEvent:Set({
      Options = GetEventLocations(),
    })
	end
end)

local GameTab = Window:CreateTab({
  Name = "Game Settings",
  Icon = "sliders-horizontal",
  ImageSource = "Lucide",
  ShowTitle = false
})

local VFX = ReplicatedStorage:WaitForChild("VFX")
local SavedVFX = {}

local function ToggleVFX()
  if Flags.DisableRodEffects.CurrentValue then
    SavedVFX = {}
    for _, obj in ipairs(VFX:GetChildren()) do
      if obj.Name:match("Dive") or obj.Name:match("Throw") then
        table.insert(SavedVFX, {Object = obj, Parent = obj.Parent})
        obj.Parent = nil
      end
    end
  else
    for _, data in ipairs(SavedVFX) do data.Object.Parent = data.Parent end
    SavedVFX = {}
  end
end

GameTab:CreateSection("Visual Settings")

GameTab:CreateToggle({Name = "Skip Cutscenes", Callback = function()end}, "SkipCutscenes")
GameTab:CreateToggle({Name = "Hide Notifications", Callback = function()end}, "HideNotifications")
GameTab:CreateToggle({Name = "Disable Animations", Callback = function()end}, "DisableAnimations")
GameTab:CreateToggle({Name = "Disable Rod Effects", Callback = ToggleVFX}, "DisableRodEffects")

GameTab:CreateSection("Bypasses")

GameTab:CreateToggle({
  Name = "Bypass Oxygen Tank",
  Callback = function()
    if Flags.BypassOxygen.CurrentValue then
      Net:WaitForChild("RF/EquipOxygenTank"):InvokeServer(105)
    else
      Net:WaitForChild("RF/UnequipOxygenTank"):InvokeServer()
    end
  end
}, "BypassOxygen")

GameTab:CreateToggle({
  Name = "Bypass Radar Fish",
  Callback = function()
    Net:WaitForChild("RF/UpdateFishingRadar"):InvokeServer(Flags.BypassRadar.CurrentValue)
  end
}, "BypassRadar")

local UtilTab = Window:CreateTab({
  Name = "Utilities",
  Icon = "wrench",
  ImageSource = "Lucide",
  ShowTitle = false
})

UtilTab:CreateSection("Quality of Life")
CreateFeature(UtilTab, "QoL")

UtilTab:CreateSection("Character")

UtilTab:CreateButton({
  Name = "Respawn to Last Location",
  Callback = function()
    local LastLoc = Character:GetPivot()

    local Humanoid = Character:WaitForChild("Humanoid")
    Humanoid.Health = 0

    Player.CharacterAdded:Wait()
    local NewCharacter = Player.Character

    NewCharacter:WaitForChild("HumanoidRootPart")
    NewCharacter:SetPrimaryPartCFrame(LastLoc)
  end
})

UtilTab:CreateSection("Safety & Identity")
CreateFeature(UtilTab, "HideIdentity")

local Tab = Window:CreateTab({
  Name = "Settings",
  Icon = "settings",
  ImageSource = "Lucide",
  ShowTitle = false
})

Tab:BuildConfigSection()
getgenv().CreateUniversalTabs()
