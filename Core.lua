--!strict
if getgenv().ExecutiveLoaded then
	return
end
getgenv().ExecutiveLoaded = true

local getgenv: () -> ({[string]: any}) = getfenv().getgenv

if not getgenv().ScriptVersion then
	getgenv().ScriptVersion = "Dev Mode"
end

print("[Executive] Loaded")

local StartLoadTime = tick()

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local StarterGui = game:GetService("StarterGui")
local UserInputService = game:GetService("UserInputService")

local Player = Players.LocalPlayer

local PlaceName: string = getgenv().PlaceName or game:GetService("AssetService"):GetGamePlacesAsync(game.GameId):GetCurrentPage()[1].Name

local queue_on_teleport: (Code: string) -> () = getfenv().queue_on_teleport
local firesignal: (RBXScriptSignal) -> () = getfenv().firesignal

getgenv().Connections = getgenv().Connections or {}

local function HandleConnection(Connection: RBXScriptConnection?, Name: string)
	if getgenv().Connections[Name] then
		getgenv().Connections[Name]:Disconnect()
	end

	getgenv().Connections[Name] = Connection
end

getgenv().HandleConnection = HandleConnection

if not getgenv().PlaceFileName then
	local PlaceFileName = PlaceName:gsub("%b[]", "")
	PlaceFileName = PlaceFileName:gsub("[^%a]", "")
	getgenv().PlaceFileName = PlaceFileName
end

local OriginalFlags = {}

if getgenv().Flags then
	for FlagName: string, FlagInfo in getgenv().Flags do
		if typeof(FlagInfo.CurrentValue) ~= "boolean" then
			continue
		end

		OriginalFlags[FlagName] = FlagInfo.CurrentValue
		FlagInfo:Set(false)
	end
end

repeat
	Luna = loadstring(game:HttpGet("https://raw.githubusercontent.com/futurewayys/executive/refs/heads/main/Luna.lua"))
	
	if Luna then
		Luna = Luna()
	end
	
	if not Luna then
		warn("[Executive]: Failed to load Luna, retrying")
	end
	
	task.wait()
until Luna

getgenv().Initiated = nil

type Element = {
	CurrentValue: any,
	CurrentOption: {string},
	Set: (self: Element, any) -> ()
}

type Flags = {
	[string]: Element
}

local function Notify(Title: string, Content: string, Image: string, Source: string)
	if not Luna then
		return
	end

	Luna:Notification({
		Title = Title,
    Icon = Image or "notifications_active",
    ImageSource = Source or "Material",
    Content = Content,
	})
end

getgenv().Notify = Notify

local Flags: Flags = Luna.Options

getgenv().Flags = Flags

local Window = Luna:CreateWindow({
  Name = `Executive | {PlaceName}`,
  Subtitle = `{ScriptVersion or "Dev Mode"}`,
  LogoID = "96618585329014",
  LoadingEnabled = true,
  LoadingTitle = `Executive's {ScriptVersion or "Dev Mode"}`,
  LoadingSubtitle = PlaceName,
  ConfigSettings = {
		RootFolder = "Executive",
		ConfigFolder = `{getgenv().PlaceFileName}-{Player.Name}`,
		AutoLoadConfig = true,
	},
})

getgenv().Window = Window

local Tab: Tab = Window:CreateTab({
	Name = "Home",
	Icon = "dashboard",
	ImageSource = "Material",
	ShowTitle = true,
})

Tab:CreateSection("Change Log")

Tab:CreateParagraph({
	Title = `{PlaceName} | {ScriptVersion}`,
	Text = getgenv().Changelog or "No changelog found",
})

Tab:CreateSection("Performance")

local PingLabel = Tab:CreateLabel({
	Text = "Ping: 0 ms",
	Style = 1,
	Icon = "wifi",
	ImageSource = "Lucide",
})
local FPSLabel = Tab:CreateLabel({
	Text = "FPS: 0/s",
	Style = 1,
	Icon = "monitor",
	ImageSource = "Lucide",
})

local Stats = game:GetService("Stats")

task.spawn(function()
	while getgenv().Flags == Flags and task.wait(0.25) do
		PingLabel:Set(`Ping: {math.floor(Stats.PerformanceStats.Ping:GetValue() * 100) / 100} ms`)
		FPSLabel:Set(`FPS: {math.floor(1 / Stats.FrameTime * 10) / 10}/s`)
	end
end)

Tab:CreateDivider()

local VirtualUser = game:GetService("VirtualUser")
local VirtualInputManager = game:GetService("VirtualInputManager")

local LastProtected

HandleConnection(Player.Idled:Connect(function()
	VirtualUser:CaptureController()
	VirtualUser:ClickButton2(Vector2.zero)
	VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.RightMeta, false, game)
	VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.RightMeta, false, game)

	LastProtected = tick()
end), "AntiAFK")

local AFKMessage = "Anti AFK Protected You:"

local AntiAFKLabel = Tab:CreateLabel({
	Text = `{AFKMessage} Never`,
	Style = 2,
	Icon = "shield",
	ImageSource = "Material",
})

task.spawn(function()
	while getgenv().Flags == Flags and task.wait(1) do
		if not LastProtected then
			continue
		end
		
		AntiAFKLabel:Set(`{AFKMessage} {math.floor(tick() - LastProtected)} seconds ago`)
	end
end)

local PlaytimeMessage = "Time Spent In Session:"
local PlaytimeLabel = Tab:CreateLabel({
	Text = `{PlaytimeMessage} 0 seconds`,
	Style = 1,
	Icon = "timer",
	ImageSource = "Lucide",
})

task.spawn(function()
	while getgenv().Flags == Flags and task.wait(1) do
		PlaytimeLabel:Set(`{PlaytimeMessage} {math.floor(tick() - StartLoadTime)} seconds`)
	end
end)

local StarterPlayer = game:GetService("StarterPlayer")

local SpeedConnection: RBXScriptConnection?
local ConnectedHumanoid

local function SetSpeed()
	local Character = Player.Character

	if not Character then
		return
	end

	local Humanoid: Humanoid = Character:FindFirstChild("Humanoid")

	if not Humanoid then
		return
	end
	
	if Flags.ChangeSpeed.CurrentValue then
		Humanoid.WalkSpeed = Flags.Speed.CurrentValue
	else
		Humanoid.WalkSpeed = StarterPlayer.CharacterWalkSpeed
	end
	
	if not SpeedConnection then
		SpeedConnection = Humanoid:GetPropertyChangedSignal("WalkSpeed"):Connect(SetSpeed)
		ConnectedHumanoid = Humanoid
		HandleConnection(SpeedConnection, "WalkSpeedConnection")
	end
end

HandleConnection(Player.CharacterAdded:Connect(function()
	if SpeedConnection then
		SpeedConnection:Disconnect()
		SpeedConnection = nil
	end

	SetSpeed()
end), "WalkSpeedCharacterAdded")

local Connections = {}

local OriginalText: {[TextLabel]: string} = {}

local function HandleUsernameChange(Object)
	if not Flags.HideIdentity.CurrentValue then
		return
	end

	if not Object:IsA("TextLabel") and not Object:IsA("TextBox") and not Object:IsA("TextButton") then
		return
	end

	local NameReplacement = Flags.NameReplacement.CurrentValue

	if not Connections[Object] then
		Connections[Object] = Object:GetPropertyChangedSignal("Text"):Connect(function()
			HandleUsernameChange(Object)
		end)
	end

	if Object.Text:find(Player.Name) then
		OriginalText[Object] = Object.Text
		Object.Text = Object.Text:gsub(Player.Name, NameReplacement)
	elseif Object.Text:find(Player.DisplayName) then
		OriginalText[Object] = Object.Text
		Object.Text = Object.Text:gsub(Player.DisplayName, NameReplacement)
	end
end

local SpacePressed = false

HandleConnection(UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end
	if input.KeyCode == Enum.KeyCode.Space then
		SpacePressed = true
		if Flags.InfJump and Flags.InfJump.CurrentValue and SpacePressed then
			if Player.Character then
				local Humanoid = Player.Character:FindFirstChildWhichIsA("Humanoid")
				if Humanoid then
					Humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
				end
			end
		end
	end
end), "InputBeganConnection")

HandleConnection(UserInputService.InputEnded:Connect(function(input)
	if input.KeyCode == Enum.KeyCode.Space then
		SpacePressed = false
	end
end), "InputEndedConnection")

local DescendantAddedConnection
local InfJumpConnection = nil

function teleportToPlayer(playerName)
	if not playerName or playerName == "" then
		Notify("Executive", "Please enter a valid player name to teleport to.", "alert-circle", "Lucide")
		return
	end

	local targetPlayer = nil
	
	for _, player in Players:GetPlayers() do
		if player ~= Player then
			local name = player.Name:lower()
			local displayName = player.DisplayName:lower()
			local searchName = playerName:lower()
			
			if name:find(searchName, 1, true) or displayName:find(searchName, 1, true) then
				targetPlayer = player
				break
			end
		end
	end
	
	if not targetPlayer then
		Notify("Executive", "Player '" .. playerName .. "' not found. Try using their username or display name.", "user-x", "Lucide")
		return
	end
	
	if not Player.Character or not Player.Character:FindFirstChild("HumanoidRootPart") then
		Notify("Executive", "You don't have a character!", "alert-triangle", "Lucide")
		return
	end
	
	if not targetPlayer.Character or not targetPlayer.Character:FindFirstChild("HumanoidRootPart") then
		Notify("Executive", targetPlayer.DisplayName .. " doesn't have a character.", "user-x", "Lucide")
		return
	end

	local success, result = pcall(function()
		Player.Character:PivotTo(targetPlayer.Character.HumanoidRootPart.CFrame * CFrame.new(0, 0, -5))
	end)

	if success then
		Notify("Executive", "Teleported to " .. targetPlayer.DisplayName .. " (@" .. targetPlayer.Name .. ")", "move", "Lucide")
	else
		Notify("Executive", "Failed to teleport: " .. tostring(result), "x-circle", "Lucide")
	end
end

type FeaturesList = {
	[string]: {
		{
			Element: string,
			Info: {}
		}
	}
}

local Features: FeaturesList = {
	QoL = {
		{
			Element = "Toggle",
			Info = {
				Name = "Change Speed",
				Flag = "ChangeSpeed",
				Callback = SetSpeed,
				AfterLoop = function()
					local Character = Player.Character

					if not Character then
						return
					end

					local Humanoid: Humanoid = Character:FindFirstChild("Humanoid")

					if not Humanoid then
						return
					end
					
					Humanoid.WalkSpeed = StarterPlayer.CharacterWalkSpeed
				end,
			},
		},
		{
			Element = "Slider",
			Info = {
				Name = "Speed",
				Range = {0, 250},
				Increment = 1,
				CurrentValue = StarterPlayer.CharacterWalkSpeed,
				Flag = "Speed",
				Callback = SetSpeed,
			}
		},
		{
			Element = "Bind",
			Info = {
				Name = "Change Speed Keybind",
				Description = "Press the key to toggle the speed change",
				CurrentBind = "Z",
				HoldToInteract = false,
				Flag = "ChangeSpeedKeybind",
				Callback = function()
					Flags.ChangeSpeed:Set({
						CurrentValue = not Flags.ChangeSpeed.CurrentValue,
					})
				end,
			}
		},
		{
			Element = "Divider",
			Info = {}
		},
		{
			Element = "Toggle",
			Info = {
				Name = "Infinite Jump",
				Flag = "InfJump",
				Callback = function()
					if Flags.InfJump.CurrentValue then
						if not InfJumpConnection then
							InfJumpConnection = UserInputService.JumpRequest:Connect(function()
								if Flags.InfJump.CurrentValue and SpacePressed then
									if Player.Character then
										local Humanoid = Player.Character:FindFirstChildWhichIsA("Humanoid")
										if Humanoid then
											Humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
										end
									end
								end
							end)
							HandleConnection(InfJumpConnection, "InfJumpConnection")
						end
					else
						if InfJumpConnection then
							InfJumpConnection:Disconnect()
							InfJumpConnection = nil
						end
					end
				end
			}
		},
	},
	HideIdentity = {
		{
			Element = "Toggle",
			Info = {
				Name = "Hide Identity",
				Flag = "HideIdentity",
				Callback = function()
					if Flags.HideIdentity.CurrentValue and not DescendantAddedConnection then
						for i,v in game:GetDescendants() do
							HandleUsernameChange(v)
						end

						DescendantAddedConnection = game.DescendantAdded:Connect(HandleUsernameChange)

						HandleConnection(DescendantAddedConnection, "HideIdentity")
					elseif DescendantAddedConnection then
						DescendantAddedConnection:Disconnect()
						DescendantAddedConnection = nil

						for Object, Text in OriginalText do
							Object.Text = Text
						end

						OriginalText = {}
					end
				end,
			}
		},
		{
			Element = "Input",
			Info = {
				Name = "Name To Replace With",
				Description = "The name that will replace your name in the game",
				CurrentValue = "Executive",
				PlaceholderText = "New Name Here",
				RemoveTextAfterFocusLost = false,
				Numeric = false,
				Enter = false,
				MaxCharacters = nil,
				Flag = "NameReplacement",
			}
		},
		{
			Element = "Divider",
			Info = {}
		},
		{
			Element = "Input",
			Info = {
				Name = "Name To Teleport To",
				Description = "The name of the person you want to teleport to",
				CurrentValue = "",
				PlaceholderText = "Name Here",
				RemoveTextAfterFocusLost = false,
				Numeric = false,
				Enter = false,
				MaxCharacters = nil,
				Flag = "NameTeleport",
			}
		},
		{
			Element = "Button",
			Info = {
				Name = "Teleport",
				Description = "Teleport to the person you want to teleport to",
				Callback = function()
					teleportToPlayer(Flags.NameTeleport.CurrentValue)
				end
			}
		},
		{
			Element = "Button",
			Info = {
				Name = "Rejoin",
				Description = "Rejoin the current server",
				Callback = function()
					Notify("Executive", "Rejoining...", "reload", "Lucide")
					task.wait(1)
					game:GetService("TeleportService"):TeleportToPlaceInstance(game.PlaceId, game.JobId, Player)
				end
			}
		},
		{
			Element = "Divider",
			Info = {}
		},
		{
			Element = "Button",
			Info = {
				Name = "Destroy UI",
				Description = "Destroy the UI",
				Callback = function()
					Notify("Executive", "UI Destroyed", "user-round-check", "Lucide")
					getgenv().ExecutiveLoaded = nil
					Luna:Destroy()
				end
			}
		},
		{
			Element = "Button",
			Info = {
				Name = "Infinity Yield",
				Description = "Load Infinity Yield, a powerful admin script",
				Callback = function()
					loadstring(game:HttpGet("https://raw.githubusercontent.com/EdgeIY/infiniteyield/master/source"))()
				end
			}
		}
	}
}

getgenv().CreateFeature = function(Tab: Tab, FeatureName: string)
	if not Features[FeatureName] then
		return warn(`The feature '{FeatureName}' does not exist in the Features.`)
	end
	
	for _, Data in Features[FeatureName] do
		Tab[`Create{Data.Element}`](Tab, Data.Info, Data.Info.Flag)
	end
end

getgenv().CreateUniversalTabs = function()
	Luna:LoadAutoloadConfig()

	task.wait(1)

	for FlagName: string, CurrentValue: boolean? in OriginalFlags do
		local FlagInfo = Flags[FlagName]

		if not FlagInfo then
			continue
		end

		FlagInfo:Set({
			CurrentValue = CurrentValue,
		})
	end

	Notify("Welcome to Executive", `Loaded in {math.floor((tick() - StartLoadTime) * 10) / 10}s`, "loader", "Lucide")
end

local Started = getgenv().Started

if Started then
	Started()
end
