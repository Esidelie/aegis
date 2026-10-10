local CONFIG = {
    projectId = "aegis-keys-37a0b",
    apiKey = "AIzaSyDuqtI_DHo68FK8ey4kO9E1C8vaEyQd0UI",
    scriptUrl = "https://raw.githubusercontent.com/esidelie/aegis/main/aegis-script.lua",
    premiumUrl = "https://raw.githubusercontent.com/esidelie/aegis/main/aegis-premium.lua",
}

local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()

local function checkKey(key)
    local url = string.format(
        "https://firestore.googleapis.com/v1/projects/%s/databases/(default)/documents/keys/%s?key=%s",
        CONFIG.projectId, key, CONFIG.apiKey
    )
    local ok, response = pcall(function() return game:HttpGet(url) end)
    if not ok or not response then return nil end
    if response:find('"error"') then return nil end

    local tier = response:match('"tier".-"stringValue":"(%w+)"')
    local expires = response:match('"expires".-"integerValue":"(%d+)"')
    if not tier then return nil end
    if expires and tonumber(expires) > 0 and os.time() > tonumber(expires) then return nil end
    return tier
end

local Window = Rayfield:CreateWindow({
    Name = "Aegis Solutions",
    LoadingTitle = "Aegis",
    LoadingSubtitle = "built for those who never miss.",
    ConfigurationSaving = { Enabled = false },
    KeySystem = false,
})

local userKey, userTier = nil, nil

Window:CreateSection("Verification")
Window:CreateInput({
    Name = "Enter your key",
    PlaceholderText = "AEGIS-XXXX-XXXX",
    RemoveTextAfterFocusLost = false,
    Callback = function(text) userKey = text end,
})

Window:CreateButton({
    Name = "Verify",
    Callback = function()
        if not userKey then return end
        local tier = checkKey(userKey)
        if not tier then
            Rayfield:Notify({
                Title = "Aegis",
                Content = "Invalid or expired key. Get a new one in #get-key.",
                Duration = 5,
            })
            return
        end
        userTier = tier
        Rayfield:Notify({
            Title = "Aegis",
            Content = "Verified as " .. tier:upper() .. ". Loading...",
            Duration = 3,
        })
        task.wait(1)
        Window:Destroy()
        if tier == "premium" then
            loadstring(game:HttpGet(CONFIG.premiumUrl))()
        else
            loadstring(game:HttpGet(CONFIG.scriptUrl))()
        end
    end,
})
