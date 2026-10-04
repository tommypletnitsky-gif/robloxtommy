-- Procedural rocket-riding pose. The rider kneels on the rocket with the knees spread, leans forward
-- and holds the handlebar that RocketModel puts in front of the seat. On top of that base pose it
-- leans into turns, tucks low on boosts, pumps a fist through boost rings, flails when the fuel runs
-- out and buzzes with the engine.
-- The character is PlatformStanding while riding (GameServer), so no default animation fights the
-- pose. Works with the new AnimationConstraint avatar joints (rotates each joint's parent-side rig
-- attachment) and with classic Motor6D rigs (rotates C0). destroy() restores everything.
-- Used for your own rider (full motion) and for other players' riders (base pose + lean).
local Rider = {}
Rider.__index = Rider

local V = Vector3.new
-- Base pose in radians (X = swing forward/back, Y = twist, Z = out/in). Tuned in Studio on an R15
-- avatar: the hands land on the handlebar grips (1.55 studs ahead of the seat, 0.62 above it,
-- 1.5 to each side) and the head looks straight ahead.
local BASE = {
	Root = V(0, 0, 0),
	Waist = V(-0.8, 0, 0),
	Neck = V(0.7, 0, 0),
	RightHip = V(0.75, 0, 0.5),
	LeftHip = V(0.75, 0, -0.5),
	RightKnee = V(-2.0, 0, 0),
	LeftKnee = V(-2.0, 0, 0),
	RightAnkle = V(0.6, 0, 0),
	LeftAnkle = V(0.6, 0, 0),
	RightShoulder = V(1.1, 0, 0.3),
	LeftShoulder = V(1.1, 0, -0.3),
	RightElbow = V(0.3, 0, 0),
	LeftElbow = V(0.3, 0, 0),
	RightWrist = V(-0.35, 0, 0),
	LeftWrist = V(-0.35, 0, 0),
}
Rider.BASE = BASE

local DEFAULTS = { lean = 0, side = 0, cheer = 0, flail = 0, yaw = 0, pitch = 0, shake = 0 }

local function lerp(a, b, k)
	return a + (b - a) * k
end

-- character -> rider (nil if the rig has none of the joints)
function Rider.new(character)
	if not character then
		return nil
	end
	local joints = {}
	local found = false
	for name in pairs(BASE) do
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
			found = true
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
			found = true
		end
	end
	if not found then
		return nil
	end
	local self = setmetatable({ character = character, joints = joints, t = math.random() * 10, s = table.clone(DEFAULTS) }, Rider)
	self:update(0, {})
	return self
end

-- target: { lean, side, cheer, flail, yaw, pitch, shake } (radians / 0..1 amounts)
--   lean  = extra forward tuck (+) or pushed back (-)     side = lean into a turn (+ = right)
--   yaw / pitch = where the head looks                     shake = engine buzz strength
function Rider:update(dt, target)
	self.t += dt
	local k = 1 - math.exp(-dt * 9)
	for key, v in pairs(DEFAULTS) do
		self.s[key] = lerp(self.s[key], target[key] or v, k)
	end
	local s, t, J = self.s, self.t, self.joints
	local function set(name, x, y, z)
		local j = J[name]
		if j then
			j.set(CFrame.Angles(x, y, z))
		end
	end

	-- engine buzz: small smooth noise, stronger when boosting
	local buzz = s.shake * 0.035
	local n1 = math.noise(t * 17, 0.31) * buzz
	local n2 = math.noise(t * 19, 1.73) * buzz
	local n3 = math.noise(t * 15, 4.11) * buzz

	if J.Root then
		J.Root.set(CFrame.new(0, math.sin(t * 9) * 0.05 * s.shake, 0))
	end
	-- torso: base lean + tuck, leaning into turns
	local lean = BASE.Waist.X - s.lean
	set("Waist", lean + n1, 0, -s.side + n2)
	-- head stays level-ish and looks where you steer
	set("Neck", BASE.Neck.X + s.lean * 0.8 + s.pitch + n3, s.yaw, s.side * 0.5)

	-- legs: kneeling, squeezing a little with the engine
	local squeeze = math.sin(t * 7) * 0.03 * s.shake
	for _, side in ipairs({ "Right", "Left" }) do
		local hip, knee, ankle = BASE[side .. "Hip"], BASE[side .. "Knee"], BASE[side .. "Ankle"]
		set(side .. "Hip", hip.X + squeeze, 0, hip.Z)
		set(side .. "Knee", knee.X - squeeze, 0, 0)
		set(side .. "Ankle", ankle.X, 0, 0)
	end

	-- arms: hold the bar (the shoulders make up for the torso's tuck so the hands stay on the grips),
	-- right fist pumps on boost rings, both windmill when the engine dies
	local hold = s.lean * 0.9
	local flailR = math.sin(t * 11) * 1.2 * s.flail
	local flailL = math.sin(t * 11 + math.pi) * 1.2 * s.flail
	local rs, ls = BASE.RightShoulder, BASE.LeftShoulder
	local cheerX = lerp(rs.X + hold, 2.9, s.cheer)
	set("RightShoulder", cheerX + flailR + n2, 0, lerp(rs.Z - s.side * 0.4, 0.4, s.cheer))
	set("LeftShoulder", ls.X + hold + flailL + n1, 0, ls.Z - s.side * 0.4)
	set("RightElbow", lerp(BASE.RightElbow.X, 0.9, s.cheer) + s.flail * 0.5, 0, 0)
	set("LeftElbow", BASE.LeftElbow.X + s.flail * 0.5, 0, 0)
	set("RightWrist", BASE.RightWrist.X, 0, 0)
	set("LeftWrist", BASE.LeftWrist.X, 0, 0)
end

function Rider:destroy()
	for _, j in pairs(self.joints) do
		pcall(j.reset)
	end
	table.clear(self.joints)
end

return Rider
