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

local function password(user)
    window.clear()
    window.setCursorPos(1, 1)
    window.write(user.displayname .. " was selected.")
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
                end
            end
        end
    end
end

local function drawFirstOptions()
    window.clear()
    window.setCursorPos(1, 1)
    window.write("Sign in")
    window.setCursorPos(1, 3)
    window.write("Reboot")
    window.setCursorPos(1, 5)
    window.write("Shut down")

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
            end
        end
    end
end

drawFirstOptions()