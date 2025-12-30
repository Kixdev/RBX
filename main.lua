--------------------------------------------------
-- LOAD ENGINE (rbimgui-2)
--------------------------------------------------
local engine = loadstring(game:HttpGet(
    "https://raw.githubusercontent.com/Singularity5490/rbimgui-2/main/rbimgui-2.lua"
))()

--------------------------------------------------
-- SERVICES
--------------------------------------------------
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local ProximityPromptService = game:GetService("ProximityPromptService")
local CoreGui = game:GetService("CoreGui")
local VirtualUser = game:GetService("VirtualUser")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera
local humanoid

local Lighting = game:GetService("Lighting")

--------------------------------------------------
-- STATES
--------------------------------------------------
local WalkSpeedEnabled = false
local InstantInteractEnabled = false
local InfiniteJumpEnabled = false
local AntiAFKEnabled = false
local NoclipEnabled = false

local DEFAULT_WALKSPEED = 16
local TargetWalkSpeed = DEFAULT_WALKSPEED
local walkSpeedConn

--------------------------------------------------
-- NO FOG
--------------------------------------------------
local NoFogEnabled = false
local DEFAULT_FOG_START = Lighting.FogStart
local DEFAULT_FOG_END = Lighting.FogEnd

--------------------------------------------------
-- FLY STATES
--------------------------------------------------
local flying = false
local flyConnection = nil

--------------------------------------------------
-- NOCLIP STATES
--------------------------------------------------
local noclipConn
local originalCollisions = {}

--------------------------------------------------
-- RUNTIME & FPS
--------------------------------------------------
local startTime = os.clock()
local fps = 0
local frameCount = 0
local lastFpsUpdate = os.clock()

--------------------------------------------------
-- FLY FUNCTIONS (CLEAN & SAFE)
--------------------------------------------------
local function startFlying()
	if flying then return end
	flying = true

	local character = player.Character
	if not character then return end

	local hrp = character:FindFirstChild("HumanoidRootPart")
	if not hrp then return end

	local gyro = Instance.new("BodyGyro")
	gyro.Name = "FlyGyro"
	gyro.P = 9e4
	gyro.MaxTorque = Vector3.new(9e9, 9e9, 9e9)
	gyro.CFrame = camera.CFrame
	gyro.Parent = hrp

	local velocity = Instance.new("BodyVelocity")
	velocity.Name = "FlyVelocity"
	velocity.MaxForce = Vector3.new(9e9, 9e9, 9e9)
	velocity.Parent = hrp

	flyConnection = RunService.RenderStepped:Connect(function()
		if not flying then return end

		local moveVec = Vector3.zero
		local camCF = camera.CFrame
		local speed = WalkSpeedEnabled and TargetWalkSpeed or DEFAULT_WALKSPEED

		if UserInputService:IsKeyDown(Enum.KeyCode.W) then moveVec += camCF.LookVector end
		if UserInputService:IsKeyDown(Enum.KeyCode.S) then moveVec -= camCF.LookVector end
		if UserInputService:IsKeyDown(Enum.KeyCode.A) then moveVec -= camCF.RightVector end
		if UserInputService:IsKeyDown(Enum.KeyCode.D) then moveVec += camCF.RightVector end
		if UserInputService:IsKeyDown(Enum.KeyCode.Space) then moveVec += camCF.UpVector end
		if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then moveVec -= camCF.UpVector end

		velocity.Velocity = moveVec.Magnitude > 0 and moveVec.Unit * speed or Vector3.zero
		gyro.CFrame = camCF
	end)
end

local function stopFlying()
	flying = false

	if flyConnection then
		flyConnection:Disconnect()
		flyConnection = nil
	end

	local character = player.Character
	if not character then return end

	local hrp = character:FindFirstChild("HumanoidRootPart")
	if not hrp then return end

	for _, v in ipairs(hrp:GetChildren()) do
		if v:IsA("BodyGyro") or v:IsA("BodyVelocity") then
			v:Destroy()
		end
	end
end

--------------------------------------------------
-- WALK SPEED GUARD (ANTI RESET)
--------------------------------------------------
local function applyWalkSpeedGuard()
	if not humanoid then return end

	humanoid.WalkSpeed = TargetWalkSpeed

	if walkSpeedConn then
		walkSpeedConn:Disconnect()
	end

	walkSpeedConn = humanoid:GetPropertyChangedSignal("WalkSpeed"):Connect(function()
		if WalkSpeedEnabled and humanoid.WalkSpeed ~= TargetWalkSpeed then
			humanoid.WalkSpeed = TargetWalkSpeed
		end
	end)
end

--------------------------------------------------
-- HUMANOID SETUP (RESPAWN SAFE)
--------------------------------------------------
local function setupHumanoid(char)
	humanoid = char:WaitForChild("Humanoid")
	DEFAULT_WALKSPEED = humanoid.WalkSpeed

	stopFlying()

	if WalkSpeedEnabled then
		task.delay(0.1, applyWalkSpeedGuard)
	end
end

if player.Character then setupHumanoid(player.Character) end
player.CharacterAdded:Connect(setupHumanoid)

--------------------------------------------------
-- UI WINDOW
--------------------------------------------------
local window = engine.new({
	text = "Movement",
	size = Vector2.new(350, 320),
})
window.open()

local tab = window.new({ text = "Player" })

--------------------------------------------------
-- UI THEME (CLIENT SIDE)
--------------------------------------------------
local TARGET_TEXT_SIZE = 20
local TARGET_FONT = Enum.Font.GothamSemibold

local imgui = CoreGui:WaitForChild("imgui2")

local function applyTheme(obj)
	if obj:IsA("TextLabel") or obj:IsA("TextButton") or obj:IsA("TextBox") then
		obj.TextSize = TARGET_TEXT_SIZE
		obj.Font = TARGET_FONT
	end
end

for _, v in ipairs(imgui:GetDescendants()) do
	applyTheme(v)
end
imgui.DescendantAdded:Connect(applyTheme)

--------------------------------------------------
-- UI LABELS
--------------------------------------------------
local runtimeLabel = tab.new("label", { text = "Runtime: 00:00:00" })
local statsLabel = tab.new("label", { text = "FPS: 0 | Ping: 0 ms" })

--------------------------------------------------
-- WALKSPEED
--------------------------------------------------
tab.new("switch", { text = "Enable WalkSpeed" }).event:Connect(function(v)
	WalkSpeedEnabled = v
	if v and humanoid then
		applyWalkSpeedGuard()
	elseif humanoid then
		if walkSpeedConn then walkSpeedConn:Disconnect() end
		humanoid.WalkSpeed = DEFAULT_WALKSPEED
	end
end)

tab.new("slider", {
	text = "Walk Speed",
	min = 16,
	max = 300,
	value = DEFAULT_WALKSPEED,
}).event:Connect(function(v)
	TargetWalkSpeed = v
	if WalkSpeedEnabled and humanoid then
		humanoid.WalkSpeed = v
	end
end)

--------------------------------------------------
-- FLY MODE (CLEAN)
--------------------------------------------------
tab.new("switch", { text = "Fly Mode" }).event:Connect(function(state)
	if state then
		startFlying()
	else
		stopFlying()
	end
end)

--------------------------------------------------
-- OTHER FEATURES
--------------------------------------------------
tab.new("switch", { text = "Instant Interact" }).event:Connect(function(v)
	InstantInteractEnabled = v
end)

tab.new("switch", { text = "Infinite Jump" }).event:Connect(function(v)
	InfiniteJumpEnabled = v
end)

tab.new("switch", { text = "Anti AFK" }).event:Connect(function(v)
	AntiAFKEnabled = v
end)

--------------------------------------------------
-- NOCLIP
--------------------------------------------------
local noclipSwitch = tab.new("switch", { text = "Noclip" })
noclipSwitch.set(false)

noclipSwitch.event:Connect(function(state)
	NoclipEnabled = state

	if state then
		table.clear(originalCollisions)

		for _, part in ipairs(humanoid.Parent:GetDescendants()) do
			if part:IsA("BasePart") then
				originalCollisions[part] = part.CanCollide
				part.CanCollide = false
			end
		end

		noclipConn = RunService.Stepped:Connect(function()
			for _, part in ipairs(humanoid.Parent:GetDescendants()) do
				if part:IsA("BasePart") then
					part.CanCollide = false
				end
			end
		end)
	else
		if noclipConn then noclipConn:Disconnect() end
		for part, canCollide in pairs(originalCollisions) do
			if part and part.Parent then
				part.CanCollide = canCollide
			end
		end
	end
end)

--------------------------------------------------
-- NO FOG (CLIENT VISUAL)
--------------------------------------------------
tab.new("switch", { text = "No Fog (Clear Skies)" }).event:Connect(function(state)
	NoFogEnabled = state

	if state then
		-- Disable fog
		Lighting.FogStart = 1e7
		Lighting.FogEnd = 1e7 + 1000
	else
		-- Restore default fog
		Lighting.FogStart = DEFAULT_FOG_START
		Lighting.FogEnd = DEFAULT_FOG_END
	end
end)

--------------------------------------------------
-- LOGICS
--------------------------------------------------
ProximityPromptService.PromptShown:Connect(function(p)
	if InstantInteractEnabled then p.HoldDuration = 0 end
end)

UserInputService.JumpRequest:Connect(function()
	if InfiniteJumpEnabled and humanoid then
		humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
	end
end)

player.Idled:Connect(function()
	if AntiAFKEnabled then
		VirtualUser:Button2Down(Vector2.new(), camera.CFrame)
		task.wait(0.05)
		VirtualUser:Button2Up(Vector2.new(), camera.CFrame)
	end
end)

--------------------------------------------------
-- TIMER, FPS & PING
--------------------------------------------------
RunService.Heartbeat:Connect(function()
	frameCount += 1
	local now = os.clock()

	if now - lastFpsUpdate >= 1 then
		fps = math.floor(frameCount / (now - lastFpsUpdate))
		frameCount = 0
		lastFpsUpdate = now
	end

	local t = math.floor(now - startTime)
	runtimeLabel.setText(string.format("Runtime: %02d:%02d:%02d", t//3600, (t%3600)//60, t%60))

	local ping = math.floor(player:GetNetworkPing() * 1000)
	statsLabel.setText(string.format("FPS: %d | Ping: %d ms", fps, ping))
end)

--------------------------------------------------
-- UI TOGGLE ( , )
--------------------------------------------------
local hidden = false
UserInputService.InputBegan:Connect(function(i, gp)
	if gp then return end
	if i.KeyCode == Enum.KeyCode.Comma then
		for _, v in ipairs(CoreGui.imgui2:GetChildren()) do
			if v:IsA("ImageLabel") and v.Name == "Main" then
				hidden = not hidden
				v.Visible = not hidden
			end
		end
	end
end)

--------------------------------------------------
-- KEYBIND INFO
--------------------------------------------------
local info = tab.new("label", { text = "Hide UI : , (Comma)" })
do
	local l = info.self
	l.TextSize = 26
	l.Font = Enum.Font.GothamBold
	l.TextXAlignment = Enum.TextXAlignment.Center
	l.Size = UDim2.new(1,0,0,36)
end

print("[Movement UI] Loaded successfully")
