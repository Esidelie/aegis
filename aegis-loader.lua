-- Aegis Solutions | Loader
-- built for those who never miss.

local CONFIG = {
    workerUrl = "https://aegis-keys.gillathissnev4pro.workers.dev",
    scriptUrl = "https://raw.githubusercontent.com/Esidelie/aegis/main/aegis-script.lua",
    premiumUrl = "https://raw.githubusercontent.com/Esidelie/aegis/main/aegis-premium.lua",
}

local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()

local function checkKey(key)
    local url = CONFIG.workerUrl .. "/check?key=" .. key
    local ok, response = pcall(function() return game:HttpGet(url) end)
    if not ok or not response then
        warn("[Aegis] HttpGet failed")
        return nil
    end
    if type(response) == "table" and response.Body then
        response = response.Body
    end
    if response:find('"valid":true') then
        local tier = response:match('"tier":"(%w+)"') or "free"
        return tier
    end
    return nil
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
KeyTab:CreateLabel("Get keys at aegis-key.pages.dev")
