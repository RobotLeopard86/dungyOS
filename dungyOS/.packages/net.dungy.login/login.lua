term.clear();

local bg = paintutils.loadImage("/.packages/net.dungy.login/loginbg.ccimg")
paintutils.drawImage(bg, 1, 1)

term.setBackgroundColor(colors.lightGray)
term.setTextColor(colors.blue)
term.setCursorPos(1, 7)
print("Welcome to dungyOS!")
print("Please select an option:")

local window = window.create(term.current(), 1, 10, 33, 10, true)
window.setBackgroundColor(colors.white)
window.setTextColor(colors.blue)

local function adjustForWindowCoords(x, y)
    return x, y - 9
end

local function drawUsernames()
    window.clear()
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

            window.write(adjX .. ", " .. adjY)

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