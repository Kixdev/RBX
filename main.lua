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
local humanoid

--------------------------------------------------
-- STATES
--------------------------------------------------
local WalkSpeedEnabled = false
local InstantInteractEnabled = false
local InfiniteJumpEnabled = false
local AntiAFKEnabled = false
local NoclipEnabled = false
local FlyEnabled = false

local DEFAULT_WALKSPEED = 16
local TargetWalkSpeed = DEFAULT_WALKSPEED
local walkSpeedConn

--------------------------------------------------
-- FLY STATES
--------------------------------------------------
local flyConn, flyBV, flyBG
local flyUp = false
local flyDown = false
local VERTICAL_MULTIPLIER = 1.6
local camera = workspace.CurrentCamera

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
-- INPUT (FLY)
--------------------------------------------------
UserInputService.InputBegan:Connect(function(input, gp)
	if gp then return end
	if input.KeyCode == Enum.KeyCode.Space then
		flyUp = true
	elseif input.KeyCode == Enum.KeyCode.LeftShift then
		flyDown = true
	end
end)

UserInputService.InputEnded:Connect(function(input)
	if input.KeyCode == Enum.KeyCode.Space then
		flyUp = false
	elseif input.KeyCode == Enum.KeyCode.LeftShift then
		flyDown = false
	end
end)

--------------------------------------------------
-- FLY FUNCTIONS (DEFINED BEFORE USE)
--------------------------------------------------
local function disableFly()
	FlyEnabled = false
	flyUp = false
	flyDown = false

	if flyConn then flyConn:Disconnect() flyConn = nil end
	if flyBV then flyBV:Destroy() flyBV = nil end
	if flyBG then flyBG:Destroy() flyBG = nil end
end

local function enableFly()
	if FlyEnabled or not humanoid then return end
	FlyEnabled = true

	local hrp = humanoid.Parent:WaitForChild("HumanoidRootPart")

	flyBV = Instance.new("BodyVelocity")
	flyBV.MaxForce = Vector3.new(1e5, 1e5, 1e5)
	flyBV.Parent = hrp

	flyBG = Instance.new("BodyGyro")
	flyBG.MaxTorque = Vector3.new(1e5, 1e5, 1e5)
	flyBG.P = 5e4
	flyBG.Parent = hrp

	flyConn = RunService.RenderStepped:Connect(function()
		if not FlyEnabled or not humanoid then return end

		local dir = humanoid.MoveDirection
		local speed = WalkSpeedEnabled and TargetWalkSpeed or DEFAULT_WALKSPEED

		local y = 0
		if flyUp then y = speed * VERTICAL_MULTIPLIER end
		if flyDown then y = -speed * VERTICAL_MULTIPLIER end

		flyBV.Velocity = Vector3.new(dir.X * speed * 2, y, dir.Z * speed * 2)
		flyBG.CFrame = camera.CFrame
	end)
end

--------------------------------------------------
-- WALK SPEED FUNCTIONS
--------------------------------------------------

local function applyWalkSpeedGuard()
	if not humanoid then return end

	humanoid.WalkSpeed = TargetWalkSpeed

	if walkSpeedConn then
		walkSpeedConn:Disconnect()
		walkSpeedConn = nil
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
	disableFly()
end

if player.Character then setupHumanoid(player.Character) end
player.CharacterAdded:Connect(setupHumanoid)

-- reset noclip saat respawn
if noclipConn then
	noclipConn:Disconnect()
	noclipConn = nil
end

table.clear(originalCollisions)
NoclipEnabled = false
if noclipSwitch then
	noclipSwitch.set(false)
end

if WalkSpeedEnabled then
	task.wait(0.1)
	applyWalkSpeedGuard()
end

--------------------------------------------------
-- UI WINDOW
--------------------------------------------------
local window = engine.new({
	text = "Movement",
	size = Vector2.new(380, 300),
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
-- UI LABELS (SAFE & CLEAN)
--------------------------------------------------
local runtimeLabel = tab.new("label", {
	text = "Runtime: 00:00:00",
})

local statsLabel = tab.new("label", {
	text = "FPS: 0 | Ping: 0 ms",
})


--------------------------------------------------
-- WALKSPEED
--------------------------------------------------
tab.new("switch", { text = "Enable WalkSpeed" }).event:Connect(function(v)
	WalkSpeedEnabled = v
	if humanoid then
		applyWalkSpeedGuard()
	else
		if walkSpeedConn then
			walkSpeedConn:Disconnect()
			walkSpeedConn = nil
		end
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
-- SWITCHES
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

tab.new("switch", { text = "Fly Mode" }).event:Connect(function(v)
	if v then enableFly() else disableFly() end
end)

--------------------------------------------------
-- NOCLIP SWITCH (SAFE & SMOOTH)
--------------------------------------------------
local noclipSwitch = tab.new("switch", {
	text = "Noclip",
})
noclipSwitch.set(false)

noclipSwitch.event:Connect(function(state)
	NoclipEnabled = state

	if state then
		-- ENABLE NOCLIP
		table.clear(originalCollisions)

		if humanoid then
			for _, part in ipairs(humanoid.Parent:GetDescendants()) do
				if part:IsA("BasePart") then
					originalCollisions[part] = part.CanCollide
					part.CanCollide = false
				end
			end
		end

		if noclipConn then noclipConn:Disconnect() end
		noclipConn = RunService.Stepped:Connect(function()
			if not humanoid then return end
			for _, part in ipairs(humanoid.Parent:GetDescendants()) do
				if part:IsA("BasePart") then
					part.CanCollide = false
				end
			end
		end)

	else
		-- DISABLE NOCLIP (RESTORE ORIGINAL COLLISION)
		if noclipConn then
			noclipConn:Disconnect()
			noclipConn = nil
		end

		for part, canCollide in pairs(originalCollisions) do
			if part and part.Parent then
				part.CanCollide = canCollide
			end
		end

		table.clear(originalCollisions)
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
		task.wait(0.03)
		VirtualUser:Button2Up(Vector2.new(), camera.CFrame)
	end
end)

--------------------------------------------------
-- UI TOGGLE (,)
--------------------------------------------------
local imgui = CoreGui:WaitForChild("imgui2")
local hidden = false

UserInputService.InputBegan:Connect(function(i, gp)
	if gp then return end
	if i.KeyCode == Enum.KeyCode.Comma then
		for _, v in ipairs(imgui:GetChildren()) do
			if v:IsA("ImageLabel") and v.Name == "Main" then
				hidden = not hidden
				v.Visible = not hidden
			end
		end
	end
end)

--------------------------------------------------
-- TIMER, FPS & PING (OPTIMIZED)
--------------------------------------------------
RunService.Heartbeat:Connect(function()
	-- FPS
	frameCount += 1
	local now = os.clock()

	if now - lastFpsUpdate >= 1 then
		fps = math.floor(frameCount / (now - lastFpsUpdate))
		frameCount = 0
		lastFpsUpdate = now
	end

	-- Runtime
	local t = math.floor(now - startTime)
	runtimeLabel.setText(string.format(
		"Runtime: %02d:%02d:%02d",
		t // 3600,
		(t % 3600) // 60,
		t % 60
	))

	-- Ping
	local pingMs = math.floor(player:GetNetworkPing() * 1000)

	-- FPS + Ping (ONE LINE)
	statsLabel.setText(
		string.format("FPS: %d | Ping: %d ms", fps, pingMs)
	)
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
