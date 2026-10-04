-- Procedural "riding the rocket" animation for the local player's avatar: holds on with both
-- arms, leans into turns and boosts, bobs and shakes with the engine, looks where you steer,
-- cheers on boost rings and flails when the fuel runs out.
-- Works with the new AnimationConstraint avatar joints (rotates each joint's parent-side rig
-- attachment) and with classic Motor6D rigs (rotates C0). Everything is restored on stop().
local Rider = {}

local JOINTS = { "Root", "Waist", "Neck", "RightShoulder", "LeftShoulder", "RightElbow", "LeftElbow" }
local active = nil

local function lerp(a, b, k)
	return a + (b - a) * k
end

function Rider.start(character)
	Rider.stop()
	if not character then
		return
	end
	local joints = {}
	for _, name in ipairs(JOINTS) do
		local j = character:FindFirstChild(name, true)
		if j and j:IsA("AnimationConstraint") and j.Attachment0 then
			local a0 = j.Attachment0
			local orig = a0.CFrame
			joints[name] = {
				set = function(cf)
					a0.CFrame = orig * cf
				end,
				reset = function()
					a0.CFrame = orig
				end,
			}
		elseif j and j:IsA("Motor6D") then
			local orig = j.C0
			joints[name] = {
				set = function(cf)
					j.C0 = orig * cf
				end,
				reset = function()
					j.C0 = orig
				end,
			}
		end
	end
	active = {
		joints = joints,
		t = 0,
		s = { lean = 0, side = 0, grip = 0, cheer = 0, flail = 0, yaw = 0, pitch = 0, shake = 0 },
	}
end

-- target: { lean, side, grip, cheer, flail, yaw, pitch, shake } (radians / 0..1 amounts)
function Rider.update(dt, target)
	local a = active
	if not a then
		return
	end
	a.t += dt
	local k = math.min(1, dt * 8)
	for key, v in pairs(target) do
		a.s[key] = lerp(a.s[key] or 0, v, k)
	end
	local s, t, J = a.s, a.t, a.joints
	-- engine buzz: small fast noise, bigger when boosting
	local buzz = s.shake * 0.035
	local n1 = math.noise(t * 17, 0.31) * buzz
	local n2 = math.noise(t * 19, 1.73) * buzz
	local n3 = math.noise(t * 15, 4.11) * buzz

	if J.Root then
		J.Root.set(CFrame.new(0, math.sin(t * 9) * 0.07 * s.shake, 0))
	end
	if J.Waist then
		-- negative X = lean forward, negative Z = lean right
		J.Waist.set(CFrame.Angles(-s.lean + n1, 0, -s.side + n2))
	end
	if J.Neck then
		J.Neck.set(CFrame.Angles(s.pitch + n3, s.yaw, 0))
	end

	-- arms: grip forward (~70°), cheer straight up (~165°), flail = windmilling
	local flailR = math.sin(t * 11) * 1.1 * s.flail
	local flailL = math.sin(t * 11 + math.pi) * 1.1 * s.flail
	local up = lerp(math.rad(70) * s.grip, math.rad(165), s.cheer)
	if J.RightShoulder then
		J.RightShoulder.set(CFrame.Angles(up + flailR + n2, 0, s.cheer * 0.35 - s.grip * 0.12))
	end
	if J.LeftShoulder then
		J.LeftShoulder.set(CFrame.Angles(up + flailL + n1, 0, -s.cheer * 0.35 + s.grip * 0.12))
	end
	local bend = math.rad(35) * s.grip * (1 - s.cheer)
	if J.RightElbow then
		J.RightElbow.set(CFrame.Angles(bend, 0, 0))
	end
	if J.LeftElbow then
		J.LeftElbow.set(CFrame.Angles(bend, 0, 0))
	end
end

function Rider.stop()
	if not active then
		return
	end
	for _, j in pairs(active.joints) do
		pcall(j.reset)
	end
	active = nil
end

return Rider
