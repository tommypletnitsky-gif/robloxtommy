-- Dev tool (run in Studio, Edit mode): turns a generate_mesh cannon into a cannon skin.
--   _G.normalizeCannon(model, skinName) -> summary string
-- Straightens the random yaw, points the muzzle (the higher end of the barrel) at +X, scales it to
-- 30 studs long, puts the pivot on the ground under its middle, measures the muzzle opening and
-- stores it as ReplicatedStorage.CannonSkins[skinName] with attribute MuzzleLocal.
-- Parts are renamed Barrel / Carriage / WheelL / WheelR / Fuse (RocketClient animates Barrel + Fuse).
local NAMES = { barrel = "Barrel", carriage = "Carriage", ["left wheel"] = "WheelL", ["right wheel"] = "WheelR", fuse = "Fuse" }
local LENGTH = 30

local function aabb(parts)
	local mn, mx = Vector3.one * 1e9, -Vector3.one * 1e9
	for _, p in ipairs(parts) do
		local cf, s = p.CFrame, p.Size
		for _, sx in ipairs({ -1, 1 }) do
			for _, sy in ipairs({ -1, 1 }) do
				for _, sz in ipairs({ -1, 1 }) do
					local w = cf * Vector3.new(sx * s.X / 2, sy * s.Y / 2, sz * s.Z / 2)
					mn, mx = mn:Min(w), mx:Max(w)
				end
			end
		end
	end
	return mn, mx
end

_G.normalizeCannon = function(src, skinName)
	local m = Instance.new("Model")
	m.Name = skinName
	for _, p in ipairs(src:GetDescendants()) do
		if p:IsA("BasePart") then
			local key = p.Name:gsub('[%[%]\\"]', ""):gsub("_geom", "")
			local c = p:Clone()
			for _, d in ipairs(c:GetDescendants()) do
				if d:IsA("LuaSourceContainer") or d:IsA("JointInstance") or d:IsA("WeldConstraint") then
					d:Destroy()
				end
			end
			c.Name = NAMES[key] or key
			c.Anchored = true
			c.CanTouch = false
			c.CanCollide = false
			c.CanQuery = true
			c.Parent = m
		end
	end
	local barrel = m:FindFirstChild("Barrel") or m:FindFirstChildWhichIsA("BasePart")
	m.Parent = workspace
	-- 1) undo the random yaw (all generated parts share it)
	local _, yaw = barrel.CFrame:ToOrientation()
	local cf = m:GetBoundingBox()
	m.WorldPivot = CFrame.new(cf.Position)
	m:PivotTo(CFrame.new(0, 5000, 0) * CFrame.Angles(0, -yaw, 0))
	-- 2) barrel's long side along X
	local mn, mx = aabb({ barrel })
	if (mx.Z - mn.Z) > (mx.X - mn.X) then
		m:PivotTo(m:GetPivot() * CFrame.Angles(0, math.rad(90), 0))
		mn, mx = aabb({ barrel })
	end
	-- 3) muzzle = the higher end of the barrel -> +X
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { barrel }
	local function topAt(x)
		local zc = (mn.Z + mx.Z) / 2
		local best = -1e9
		for dz = -2, 2, 1 do
			local hit = workspace:Raycast(Vector3.new(x, mx.Y + 10, zc + dz), Vector3.new(0, -(mx.Y - mn.Y) - 20, 0), params)
			if hit then
				best = math.max(best, hit.Position.Y)
			end
		end
		return best
	end
	local len = mx.X - mn.X
	if topAt(mn.X + len * 0.12) > topAt(mx.X - len * 0.12) then
		m:PivotTo(m:GetPivot() * CFrame.Angles(0, math.pi, 0))
	end
	-- 4) scale to LENGTH and put the pivot on the ground under the middle
	m.WorldPivot = CFrame.new(m:GetBoundingBox().Position)
	local _, size = m:GetBoundingBox()
	m:ScaleTo(LENGTH / size.X)
	local bb, size2 = m:GetBoundingBox()
	m.WorldPivot = CFrame.new(bb.Position.X, bb.Position.Y - size2.Y / 2, bb.Position.Z)
	m:PivotTo(CFrame.new(0, 5000, 0))
	-- 5) muzzle = middle of the barrel's front end (top and bottom of the barrel just behind its tip)
	mn, mx = aabb({ barrel })
	local zc = (mn.Z + mx.Z) / 2
	local x = mx.X - 1.2
	local down = workspace:Raycast(Vector3.new(x, mx.Y + 10, zc), Vector3.new(0, -(mx.Y - mn.Y) - 20, 0), params)
	local up = workspace:Raycast(Vector3.new(x, mn.Y - 10, zc), Vector3.new(0, (mx.Y - mn.Y) + 20, 0), params)
	local muzzleY = (down and up) and (down.Position.Y + up.Position.Y) / 2 or (mn.Y + mx.Y) / 2
	local ys = { down and down.Position.Y or 0, up and up.Position.Y or 0 }
	local pivot = m:GetPivot().Position
	local muzzle = Vector3.new(mx.X, muzzleY, zc) - pivot
	m:SetAttribute("MuzzleLocal", muzzle)
	m:PivotTo(CFrame.new())
	local folder = game.ReplicatedStorage:FindFirstChild("CannonSkins") or Instance.new("Folder")
	folder.Name = "CannonSkins"
	folder.Parent = game.ReplicatedStorage
	local old = folder:FindFirstChild(skinName)
	if old then
		old:Destroy()
	end
	m.Parent = folder
	src:Destroy()
	return string.format("%s size=%s muzzle=%s (front top %.1f bottom %.1f)", skinName, tostring(size2), tostring(muzzle), ys[1] - pivot.Y, ys[2] - pivot.Y)
end
-- Re-measure the muzzle of a skin already in ReplicatedStorage.CannonSkins.
_G.remeasureCannon = function(skinName)
	local skin = game.ReplicatedStorage.CannonSkins[skinName]
	local barrel = skin:FindFirstChild("Barrel")
	skin:PivotTo(CFrame.new(0, 5000, 0))
	skin.Parent = workspace
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { barrel }
	local mn, mx = aabb({ barrel })
	local zc = (mn.Z + mx.Z) / 2
	local x = mx.X - 1.2
	local down = workspace:Raycast(Vector3.new(x, mx.Y + 10, zc), Vector3.new(0, -(mx.Y - mn.Y) - 20, 0), params)
	local up = workspace:Raycast(Vector3.new(x, mn.Y - 10, zc), Vector3.new(0, (mx.Y - mn.Y) + 20, 0), params)
	local muzzleY = (down and up) and (down.Position.Y + up.Position.Y) / 2 or (mn.Y + mx.Y) / 2
	local muzzle = Vector3.new(mx.X, muzzleY, zc) - Vector3.new(0, 5000, 0)
	skin:SetAttribute("MuzzleLocal", muzzle)
	skin:PivotTo(CFrame.new())
	skin.Parent = game.ReplicatedStorage.CannonSkins
	return skinName .. " muzzle=" .. tostring(muzzle)
end
return "normalizeCannon ready"
