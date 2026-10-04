-- Pulls every script listed in sync.json from the local file server into Studio.
-- Run from execute_luau (Edit) while `python -m http.server 34873 --bind 127.0.0.1`
-- is running in the project folder. Needs HttpService.HttpEnabled = true.
local Http = game:GetService("HttpService")
local BASE = "http://127.0.0.1:34873/"
local manifest = Http:JSONDecode(Http:GetAsync(BASE .. "sync.json?t=" .. os.clock()))
local log = {}
for _, entry in ipairs(manifest) do
	local parts = string.split(entry.path, ".")
	local parent = game:GetService(parts[1])
	for i = 2, #parts - 1 do
		local child = parent:FindFirstChild(parts[i])
		if not child then
			child = Instance.new("Folder")
			child.Name = parts[i]
			child.Parent = parent
		end
		parent = child
	end
	local name = parts[#parts]
	local script = parent:FindFirstChild(name)
	if script and script.ClassName ~= entry.class then
		script:Destroy()
		script = nil
	end
	if not script then
		script = Instance.new(entry.class)
		script.Name = name
		script.Parent = parent
	end
	script.Source = Http:GetAsync(BASE .. entry.file .. "?t=" .. os.clock())
	table.insert(log, entry.path .. " (" .. #script.Source .. " chars)")
end
return table.concat(log, "\n")
