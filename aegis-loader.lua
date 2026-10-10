-- Aegis Solutions | Loader
-- built for those who never miss.

local CONFIG = {
    projectId = "aegis-keys-37a0b",
    apiKey = "AIzaSyDuqtI_DHo68FK8ey4kO9E1C8vaEyQd0UI",
    scriptUrl = "https://raw.githubusercontent.com/Esidelie/aegis/main/aegis-script.lua",
    premiumUrl = "https://raw.githubusercontent.com/Esidelie/aegis/main/aegis-premium.lua",
}

local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()

local function checkKey(key)
    local url = string.format(
        "https://firestore.googleapis.com/v1/projects/%s/databases/(default)/documents/keys/%s?key=%s",
        CONFIG.projectId, key, CONFIG.apiKey
    )

    local ok, response = pcall(function() return game:HttpGet(url) end)
    if not ok or not response then
        warn("[Aegis] HttpGet failed")
        return nil
    end

    if type(response) == "table" and response.Body then
        response = response.Body
    end

    if #response < 10 then
        warn("[Aegis] Empty response")
        return nil
    end

    if response:find('"error"') then
        warn("[Aegis] Firebase error: " .. string.sub(response, 1, 200))
        return nil
    end

    local tier = response:match('"tier"[^}]*"stringValue"[^"]*"([^"]+)"')
    local expires = response:match('"expires"[^}]*"integerValue"[^"]*"([^"]+)"')

    if not tier then
        if response:find('"premium"') then tier = "premium"
        elseif response:find('"free"') then tier = "free" end
    end

    if not tier then
        warn("[Aegis] Could not parse tier. Response: " .. string.sub(response, 1, 300))
        return nil
    end

    if expires and tonumber(expires) and tonumber(expires) > 0 then
        if os.time() > tonumber(expires) then
            warn("[Aegis] Key expired")
            return nil
        end
    end

    return tier
end

local Window = Rayfield:CreateWindow({
    Name = "Aegis Solutions",
    LoadingTitle = "Aegis",
    LoadingSubtitle = "built for those who never miss.",
    ConfigurationSaving = { Enabled = false },
    KeySystem = false,
})

local KeyTab = Window:CreateTab("Verification", 4483362458)

local userKey = nil

KeyTab:CreateSection("Enter your key")
KeyTab:CreateInput({
    Name = "Key",
    PlaceholderText = "AEGIS-XXXX-XXXX",
    RemoveTextAfterFocusLost = false,
    Callback = function(text) userKey = text end,
})

KeyTab:CreateSection("Actions")
KeyTab:CreateButton({
    Name = "Verify",
    Callback = function()
        if not userKey or userKey == "" then
            Rayfield:Notify({
                Title = "Aegis",
                Content = "Enter a key first.",
                Duration = 5,
            })
            return
        end

        local tier = checkKey(userKey)
        if not tier then
            Rayfield:Notify({
                Title = "Aegis",
                Content = "Invalid or expired key. Get a new one in #get-key.",
                Duration = 5,
            })
            return
        end

        Rayfield:Notify({
            Title = "Aegis",
            Content = "Verified as " .. string.upper(tier) .. ". Loading...",
            Duration = 3,
        })

        task.wait(1)

        local url = (tier == "premium") and CONFIG.premiumUrl or CONFIG.scriptUrl

        if Window and Window.Destroy then
            pcall(function() Window:Destroy() end)
        end

        loadstring(game:HttpGet(url))()
    end,
})

KeyTab:CreateSection("Info")
KeyTab:CreateLabel("Free keys: 12 hours")
KeyTab:CreateLabel("Premium: permanent access")
KeyTab:CreateLabel("Get keys at discord.gg/aegis")
