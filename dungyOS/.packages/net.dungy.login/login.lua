local hash = require("net.dungy.sha", "sha")

term.clear();

local bg = paintutils.loadImage("/.packages/net.dungy.login/loginbg.ccimg")
paintutils.drawImage(bg, 1, 1)

term.setBackgroundColor(colors.lightGray)
term.setTextColor(colors.blue)
term.setCursorPos(1, 7)
print("Welcome to dungyOS!")
print("Please select an option:")

local window = window.create(term.current(), 1, 10, 33, 200, true)
window.setBackgroundColor(colors.white)
window.setTextColor(colors.blue)

local function adjustForWindowCoords(x, y)
    return x, y - 9
end

local function adjustForWindowCoordsWhenScrolling(x, y, scroll)
    return x, (y - 9) + scroll
end

local function drawCentered(text, y)
    local w, h = window.getSize()
    window.setCursorPos((w / 2) - (string.len(text) / 2), y)
    window.write(text)
end

local function saltAndHash(value)
    local saltedInput = value .. salt
    local hashedInput = hash(saltedInput)
    return hashedInput
end

local function password(user)
    window.clear()
    window.setTextColor(colors.blue)
    drawCentered("Hi, " .. user.displayname .. "!", 1)
    drawCentered("Please enter your password:", 2)
    window.setCursorPos(1, 4)
    window.setBackgroundColor(colors.white)
    window.write("                                 ")
    window.setCursorPos(1, 4)
    local default = term.current()
    term.redirect(window)
    local inputtedPassword = read("*")
    term.redirect(default)
    local hashed = saltAndHash(inputtedPassword)

    window.clear()

    if hashed == user.password then
        window.setTextColor(colors.lime)
        drawCentered("Welcome, " .. user.displayname .. "!", 1)
        drawCentered("Logging you in...", 2)
        sleep(1)

        local usrData = {
            username = user.username,
            displayname = user.displayname,
            permission = user.permissions
        }

        local tabId = multishell.launch({
            ["shell"] = shell,
            ["multishell"] = multishell,
            ["require"] = require,
            ["read"] = read,
            ["user"] = usrData
        }, "/.packages/net.dungy.desktop/temp_desktop.lua")
        multishell.setFocus(tabId)
        return
    else
        window.setTextColor(colors.red)
        drawCentered("Incorrect password.", 1)
        drawCentered("Please try again.", 2)
        sleep(1)
        password(user)
    end
end

local function drawUsernames()
    window.clear()

    local filenames = fs.list("/.system-storage/users")

    local users = {}
    local actions = {}
    
    for _, file in ipairs(filenames) do
        local path = "/.system-storage/users/" .. file
        local handle = fs.open(path, "r")
        table.insert(users, textutils.unserializeJSON(handle.readAll()))
        handle.close()
    end

    local drawIndex = 1

    for _, usr in ipairs(users) do
        window.setCursorPos(1, drawIndex)
        window.write(usr.displayname)
        table.insert(actions, {
            fromX = 1,
            fromY = drawIndex,
            toX = string.len(usr.displayname),
            toY = drawIndex,
            argument = usr
        })
        drawIndex = drawIndex + 2
    end

    local windowScroll = 1
    local maxScroll = drawIndex - 10

    while true do
        
        local event, pressed, x, y = os.pullEvent()

        if event == "key" then
            if pressed == keys.down then
                if windowScroll < maxScroll then
                    windowScroll = windowScroll + 2
                    window.scroll(2)
                end
            else if pressed == keys.up then
                if windowScroll > 1 then
                    windowScroll = windowScroll - 2
                    
                    window.clear()
                    drawIndex = 1
                    for _, usr in ipairs(users) do
                        window.setCursorPos(1, drawIndex)
                        window.write(usr.displayname)
                        drawIndex = drawIndex + 2
                    end

                    window.scroll(windowScroll - 1)
                end
            end
        end
        else if event == "mouse_click" and pressed == 1 then
                local selected = -1
                local adjX, adjY = adjustForWindowCoordsWhenScrolling(x, y, windowScroll - 1)

                for i, action in ipairs(actions) do

                    if adjX >= action.fromX and adjX <= action.toX and adjY >= action.fromY and adjY <= action.toY then
                        selected = i
                        break
                    end
                end

                if selected ~= -1 then
                    password(actions[selected].argument)
                    return
                end
            end
        end
    end
end

local function hashing()
    window.clear()
    window.setCursorPos(1, 1)
    window.write("Enter a value:")
    window.setCursorPos(1, 2)
    local default = term.current()
    term.redirect(window)
    local input = read()
    term.redirect(default)
    window.setCursorPos(1, 4)
    window.write("The resulting hash was:")
    window.setCursorPos(1, 5)
    local hashed = saltAndHash(input)
    window.write(hashed)
    window.setCursorPos(1, 7)
    window.write("Save to file:")
    window.setCursorPos(1, 8)
    local path = read()
    local handle = fs.open(path, "a")
    handle.writeLine(input .. ": " .. hashed)
    handle.close()
    window.setCursorPos(1, 10)
    window.write("Done! Rebooting...")
    sleep(0.5)
    os.reboot()
end

local function drawFirstOptions()
    window.clear()
    window.setCursorPos(1, 1)
    window.write("Sign in")
    window.setCursorPos(1, 3)
    window.write("Reboot")
    window.setCursorPos(1, 5)
    window.write("Shut down")
    window.setCursorPos(1, 7)
    window.write("Hashing (DEV TOOL)")

    local actions = {
        {
            fromX = 1,
            fromY = 1,
            toX = 7,
            toY = 1,
            trigger = drawUsernames
        },
        {
            fromX = 1,
            fromY = 3,
            toX = 6,
            toY = 3,
            trigger = os.reboot
        },
        {
            fromX = 1,
            fromY = 5,
            toX = 9,
            toY = 5,
            trigger = os.shutdown
        },
        {
            fromX = 1,
            fromY = 7,
            toX = 18,
            toY = 7,
            trigger = hashing
        }
    }

    while true do
        local event, button, x, y = os.pullEvent("mouse_click")

        if button == 1 then
            local selected = -1
            local adjX, adjY = adjustForWindowCoords(x, y)

            for i, action in ipairs(actions) do

                if adjX >= action.fromX and adjX <= action.toX and adjY >= action.fromY and adjY <= action.toY then
                    selected = i
                    break
                end
            end

            if selected ~= -1 then
                actions[selected].trigger()
                return
            end
        end
    end
end

drawFirstOptions()

term.setBackgroundColor(colors.black)
term.setTextColor(colors.white)
term.setCursorPos(1, 1)
window.setVisible(false)
window = nil
term.clear()
print("Enjoy dungyOS! I just stay here so that the computer doesn't crash. I'm basically just the immortal task. Also, why are you here? You're not supposed to see this.")

while true do
    sleep(0.05)
end