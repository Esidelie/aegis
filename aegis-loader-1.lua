--[[
	Aegis Solutions loader

	What it does
	  1. Builds a device ID (HWID).
	  2. If a key was saved earlier, checks it with the Aegis server (GET /check) and, when it is
	     valid, downloads the script for the key's tier (GET /load) and runs it.
	  3. Otherwise shows a Rayfield window where the user pastes the key once.

	The scripts are not stored in this repository. The server only sends them to a valid,
	device-locked key. Network access uses game:HttpGet only, so it works on mobile executors.
]]

local WORKER_URL = "https://aegis-keys.gillathissnev4pro.workers.dev"
local SITE_URL = "aegis-key.pages.dev"
local RAYFIELD_URL = "https://sirius.menu/rayfield"

local KEY_FILE = "aegis_key.txt"
local HWID_FILE = "aegis_hwid.txt"
local TAG = "[Aegis] "

local HttpService = game:GetService("HttpService")

-- Executor environment table (shared between runs). Falls back to _G.
local genv = (type(getgenv) == "function" and getgenv()) or _G

--------------------------------------------------------------------------------
-- Helpers
--------------------------------------------------------------------------------

local function trim(value)
	return (tostring(value or ""):gsub("^%s+", ""):gsub("%s+$", ""))
end

local function logWarn(message)
	warn(TAG .. tostring(message))
end

-- Keys are letters, digits and dashes. Whitespace from copy and paste is removed.
local function cleanKey(value)
	return (tostring(value or ""):gsub("%s", ""))
end

local function decodeJson(text)
	local ok, result = pcall(function()
		return HttpService:JSONDecode(text)
	end)
	if ok and type(result) == "table" then
		return result
	end
	return nil
end

--------------------------------------------------------------------------------
-- Local storage
-- 1) writefile/readfile  2) getgenv().AegisKey / AegisHWID  3) Rayfield ConfigurationSaving
--    (the third one is the key input of the verification window, see showKeyWindow)
--------------------------------------------------------------------------------

local Storage = {}

local function hasFiles()
	return type(writefile) == "function" and type(readfile) == "function" and type(isfile) == "function"
end

function Storage.read(fileName, envName)
	if hasFiles() then
		local okExists, exists = pcall(isfile, fileName)
		if okExists and exists then
			local okRead, data = pcall(readfile, fileName)
			if okRead and type(data) == "string" and trim(data) ~= "" then
				return trim(data)
			end
		end
	end
	local value = genv[envName]
	if type(value) == "string" and trim(value) ~= "" then
		return trim(value)
	end
	return nil
end

function Storage.write(fileName, envName, value)
	genv[envName] = value
	if hasFiles() then
		local ok, err = pcall(writefile, fileName, value)
		if not ok then
			logWarn("Could not write " .. fileName .. ": " .. tostring(err))
		end
	end
end

function Storage.delete(fileName, envName)
	genv[envName] = nil
	if type(delfile) == "function" and type(isfile) == "function" then
		pcall(function()
			if isfile(fileName) then
				delfile(fileName)
			end
		end)
	elseif hasFiles() then
		pcall(writefile, fileName, "")
	end
end

--------------------------------------------------------------------------------
-- Device ID (HWID)
-- The server accepts 8 to 128 characters of a-z A-Z 0-9 - _
--------------------------------------------------------------------------------

local function cleanHwid(raw)
	if raw == nil then
		return nil
	end
	local value = tostring(raw):gsub("[^%w%-_]", "")
	if #value > 128 then
		value = value:sub(1, 128)
	end
	if #value < 8 then
		return nil
	end
	return value
end

--[[
	Priority 1: gethwid()
	Priority 2: RbxAnalyticsService:GetClientId()
	Priority 3: UserId plus the time of the first run. This one is not tied to the hardware,
	            so it is generated once and read back from aegis_hwid.txt on later runs.
	The first two are read again on every launch. The saved file is only used for priority 3,
	so copying aegis_hwid.txt to another computer does not move a key lock.
]]
local function getHwid()
	if type(gethwid) == "function" then
		local ok, raw = pcall(gethwid)
		local id = ok and cleanHwid(raw)
		if id then
			return id
		end
	end

	local okClient, clientId = pcall(function()
		return game:GetService("RbxAnalyticsService"):GetClientId()
	end)
	local id = okClient and cleanHwid(clientId)
	if id then
		return id
	end

	local saved = cleanHwid(Storage.read(HWID_FILE, "AegisHWID"))
	if saved then
		return saved
	end
	logWarn("No hardware ID available. Using a generated ID, so the device lock is weaker.")
	local player = game:GetService("Players").LocalPlayer
	local userId = player and player.UserId or 0
	return cleanHwid(tostring(userId) .. "-" .. tostring(math.floor(tick())))
end

--------------------------------------------------------------------------------
-- Network (game:HttpGet only)
--------------------------------------------------------------------------------

local function httpGet(url)
	local ok, body = pcall(function()
		return game:HttpGet(url)
	end)
	if ok and type(body) == "string" then
		return body, nil
	end
	return nil, tostring(body)
end

-- HttpGet raises an error for non-2xx answers and the message contains the status code
local function statusFromError(err)
	-- Drop a "chunk:line:" prefix so a line number is never mistaken for a status code
	local text = tostring(err):gsub("^[^\n]-:%d+:%s*", "")
	local code = text:match("HTTP%s*(%d%d%d)") or text:match("%f[%d]([45]%d%d)%f[%D]")
	return code and tonumber(code) or nil
end

-- Retries once when the request failed without a client error (timeout, dropped connection)
local function httpGetWithRetry(url)
	local body, err = httpGet(url)
	if body then
		return body, nil
	end
	local status = statusFromError(err)
	if status and status >= 400 and status < 500 then
		return nil, err
	end
	logWarn("Request failed, retrying once: " .. tostring(err))
	task.wait(1.5)
	return httpGet(url)
end

local function endpoint(path, key, hwid)
	return string.format(
		"%s%s?key=%s&hwid=%s&t=%d",
		WORKER_URL,
		path,
		HttpService:UrlEncode(key),
		HttpService:UrlEncode(hwid),
		math.floor(tick())
	)
end

--------------------------------------------------------------------------------
-- Rayfield (loaded on demand) and notifications
--------------------------------------------------------------------------------

local UI = { rayfield = nil, tried = false }

local function loadRayfield()
	if UI.rayfield then
		return UI.rayfield
	end
	if UI.tried then
		return nil
	end
	UI.tried = true

	local body, err = httpGet(RAYFIELD_URL)
	if not body then
		logWarn("Could not download Rayfield: " .. tostring(err))
		return nil
	end
	local fn, compileError = loadstring(body)
	if not fn then
		logWarn("Rayfield did not compile: " .. tostring(compileError))
		return nil
	end
	local ok, library = pcall(fn)
	if ok and type(library) == "table" then
		UI.rayfield = library
		return library
	end
	logWarn("Rayfield did not start: " .. tostring(library))
	return nil
end

-- Errors also go to the console through warn
local function notify(content, isError, duration)
	if isError then
		logWarn(content)
	end
	local rayfield = loadRayfield()
	if rayfield then
		local ok = pcall(function()
			rayfield:Notify({ Title = "Aegis", Content = content, Duration = duration or 8 })
		end)
		if ok then
			return
		end
	end
	pcall(function()
		game:GetService("StarterGui"):SetCore("SendNotification", { Title = "Aegis", Text = content, Duration = duration or 8 })
	end)
end

--------------------------------------------------------------------------------
-- Verification and loading
--------------------------------------------------------------------------------

local REASON_MESSAGES = {
	expired = "Key expired, get new one at " .. SITE_URL,
	hwid_mismatch = "Key locked to another device. Reset it at " .. SITE_URL .. " or open a ticket on Discord.",
	invalid_key = "Invalid key. Check it and try again.",
	banned = "This account is banned.",
	invalid_hwid = "Could not read a valid device ID.",
	script_not_found = "The script is not available right now. Contact support on Discord.",
}

-- Answers of /load for HTTP errors. HttpGet only reports the status code, not the JSON body.
local STATUS_MESSAGES = {
	[400] = REASON_MESSAGES.invalid_hwid,
	[401] = "The server rejected the key. It is invalid or expired.",
	[403] = "Access denied. The key is banned or locked to another device.",
	[500] = REASON_MESSAGES.script_not_found,
}

local function failure(reason, message)
	notify(message, true)
	return { loaded = false, reason = reason }
end

-- Downloads the script for the key and runs it.
local function loadScript(key, hwid, tier)
	local body, err = httpGetWithRetry(endpoint("/load", key, hwid))
	if not body then
		local status = statusFromError(err)
		return failure("load_failed", STATUS_MESSAGES[status] or "Cannot reach server. Check internet.")
	end

	-- HttpGet returns only the body, so the answer is told apart by its shape:
	-- JSON with an "error" field is an error, anything else is Lua code.
	if body:match("^%s*{") then
		local decoded = decodeJson(body)
		if decoded and decoded.error then
			return failure(tostring(decoded.error), REASON_MESSAGES[decoded.error] or ("Server error: " .. tostring(decoded.error)))
		end
	end
	if trim(body) == "" then
		return failure("empty", "The server sent an empty script. Contact support on Discord.")
	end

	local fn, compileError = loadstring(body)
	if not fn then
		return failure("compile", "The script could not be loaded: " .. tostring(compileError))
	end

	genv.AegisLoaded = true
	print(TAG .. "Loaded tier: " .. tostring(tier))
	local ok, runError = pcall(fn)
	if not ok then
		logWarn("The script stopped with an error: " .. tostring(runError))
	end
	return { loaded = true, tier = tier }
end

-- Checks the key with the server (this also locks it to the device on first use), then loads.
local function verifyAndLoad(key, hwid)
	local body, err = httpGetWithRetry(endpoint("/check", key, hwid))
	if not body then
		return failure("network", "Cannot reach server. Check internet.")
	end

	local check = decodeJson(body)
	if not check then
		return failure("bad_response", "The server sent an answer the loader does not understand.")
	end

	if check.valid ~= true then
		local reason = tostring(check.reason)
		-- A key that can never work again is forgotten, so the user is asked for a new one
		if reason == "expired" or reason == "invalid_key" then
			Storage.delete(KEY_FILE, "AegisKey")
		end
		return failure(reason, REASON_MESSAGES[reason] or ("Verification failed: " .. reason))
	end

	Storage.write(KEY_FILE, "AegisKey", key)
	Storage.write(HWID_FILE, "AegisHWID", hwid)
	return loadScript(key, hwid, check.tier)
end

--------------------------------------------------------------------------------
-- Key window
--------------------------------------------------------------------------------

local function showKeyWindow(hwid, prefill)
	local rayfield = loadRayfield()
	if not rayfield then
		logWarn('Rayfield could not be loaded, so the key window is unavailable. Run getgenv().AegisKey = "YOUR-KEY" and execute the loader again.')
		return
	end

	local window = rayfield:CreateWindow({
		Name = "Aegis | Verification",
		LoadingTitle = "Aegis",
		LoadingSubtitle = "Key verification",
		Theme = "Default",
		DisableRayfieldPrompts = true,
		DisableBuildWarnings = true,
		KeySystem = false,
		-- Last storage fallback: Rayfield remembers the text of the key field between sessions
		ConfigurationSaving = { Enabled = true, FolderName = "Aegis", FileName = "AegisKeyConfig" },
	})
	local tab = window:CreateTab("Verification", 4483362458)
	tab:CreateSection("License key")

	local entered = prefill or ""
	tab:CreateInput({
		Name = "Key",
		PlaceholderText = "AEGIS-XXXX-XXXX",
		CurrentValue = prefill or "",
		RemoveTextAfterFocusLost = false,
		Flag = "AegisKey",
		Callback = function(text)
			entered = text
		end,
	})

	local busy = false
	tab:CreateButton({
		Name = "Verify",
		Callback = function()
			if busy then
				return
			end
			local key = cleanKey(entered)
			if key == "" then
				local flag = rayfield.Flags and rayfield.Flags.AegisKey
				key = cleanKey(flag and flag.CurrentValue)
			end
			if key == "" then
				notify("Enter your key first.", false, 5)
				return
			end

			busy = true
			local result = verifyAndLoad(key, hwid)
			busy = false
			if result.loaded then
				pcall(function()
					rayfield:Destroy()
				end)
			end
		end,
	})

	-- Restores the key saved by Rayfield, if any (runs the Input callback)
	pcall(function()
		rayfield:LoadConfiguration()
	end)
end

--------------------------------------------------------------------------------
-- Start
--------------------------------------------------------------------------------

local function main()
	if genv.AegisLoaded then
		logWarn("Aegis is already loaded in this session.")
		return
	end

	local hwid = getHwid()
	if not hwid then
		notify("Could not create a device ID.", true)
		return
	end
	Storage.write(HWID_FILE, "AegisHWID", hwid)

	local prefill = nil
	local savedKey = Storage.read(KEY_FILE, "AegisKey")
	if savedKey then
		local result = verifyAndLoad(cleanKey(savedKey), hwid)
		if result.loaded then
			return
		end
		-- Keep a key that failed for a temporary reason in the field. Forget dead ones.
		if result.reason ~= "expired" and result.reason ~= "invalid_key" then
			prefill = cleanKey(savedKey)
		end
	end

	showKeyWindow(hwid, prefill)
end

local ok, err = pcall(main)
if not ok then
	logWarn("Unexpected error: " .. tostring(err))
end
