local HttpService = game:GetService("HttpService")
local root = workspace:FindFirstChild("SimulatorLand")
local report = { root = root ~= nil }
if root then
	report.island = root:FindFirstChild("GrassIsland") ~= nil
	report.spawn = root:FindFirstChild("CenterSpawn") ~= nil
	report.plots = {}
	for n = 1, 8 do
		local plot = root:FindFirstChild("Plot" .. n)
		if plot then
			local fences = 0
			for _, c in ipairs(plot:GetChildren()) do
				if c.Name == "Fence" then fences += 1 end
			end
			local sign = plot:FindFirstChild("Sign")
			report.plots[n] = {
				exists = true,
				dirt = plot:FindFirstChild("Dirt") ~= nil,
				fences = fences,
				sign = sign ~= nil,
				signLabel = (sign and sign:FindFirstChildWhichIsA("BillboardGui", true) ~= nil) or false,
			}
		else
			report.plots[n] = { exists = false }
		end
	end
end
return HttpService:JSONEncode(report)
