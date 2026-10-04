-- Lobby life (client-only visuals): things tagged LobbySpin turn slowly (attribute SpinSpeed) and
-- bob up and down (attribute Bob = height), e.g. the eggs in the Egg Garden.
-- Only runs while the camera is near the lobby.
local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")

local camera = workspace.CurrentCamera
local LOBBY = Vector3.new(-95, 0, 0)

local spinners = {}
local function add(m)
	spinners[m] = { base = m:GetPivot(), speed = m:GetAttribute("SpinSpeed") or 1, bob = m:GetAttribute("Bob") or 0, phase = math.random() * 6 }
end
for _, m in ipairs(CollectionService:GetTagged("LobbySpin")) do
	add(m)
end
CollectionService:GetInstanceAddedSignal("LobbySpin"):Connect(add)
CollectionService:GetInstanceRemovedSignal("LobbySpin"):Connect(function(m)
	spinners[m] = nil
end)

RunService.RenderStepped:Connect(function()
	if (camera.CFrame.Position - LOBBY).Magnitude > 450 then
		return
	end
	local now = os.clock()
	for m, s in pairs(spinners) do
		local lift = s.bob > 0 and (math.sin(now * 2 + s.phase) + 1) * s.bob or 0
		m:PivotTo(s.base * CFrame.new(0, lift, 0) * CFrame.Angles(0, now * s.speed + s.phase, 0))
	end
end)
