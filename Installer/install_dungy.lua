print("Please enter repository owner:")
local owner = read()
print("Please enter repository name:")
local repo = read()
print("Loading installer...")
sleep(1)

local expect = require "cc.expect".expect

local function ends_with(str, suffix)
    return #str >= #suffix and str:sub(-#suffix) == suffix
end

local function split(str, deliminator)
    expect(1, str, "string")
    expect(2, deliminator, "string")
  
    local out, out_n, pos = {}, 0, 1
    while not limit or out_n < limit - 1 do
        local start, finish = str:find(deliminator, pos, false)
        if not start then break end
    
        out_n = out_n + 1
        out[out_n] = str:sub(pos, start - 1)
        pos = finish + 1
    end
  
    if pos == 1 then return { str } end
  
    out[out_n + 1] = str:sub(pos)
    return out
end

local function convertURL(tree)
    local api = "https://api.github.com/repos/" .. owner .. "/" .. repo .. "/git/trees/" .. tree .. "?recursive=1"

    local raw = "https://raw.githubusercontent.com/" .. owner .. "/" .. repo .. "/" .. tree .. "/"

    return {
        apiPath = api,
        rawPath = raw
    }
end

local function gitDownload(tree, output)
    local converted = convertURL(tree)
    print("Making tree download request...")
    local request = http.get(converted.apiPath)
    if request ~= nil then
        local contents = textutils.unserializeJSON(request.readAll())
        print("Tree downloaded!")
        print()
        print("Downloading files:")
        for i, file in ipairs(contents.tree) do
            print("#" .. i .. ": " .. fs.getName(file.path))
            if file.type == "blob" then
                local request = http.get(converted.rawPath .. file.path)
                local handle = fs.open(output .. "/" .. file.path, "w")
                handle.write(request.readAll())
                handle.close()
                request.close()
            elseif file.type == "tree" then
                fs.makeDir(output .. "/" .. file.path)
            end
        end
    end
end

term.setPaletteColor(colors.lightGray, 0xCCCCCC)
term.setPaletteColor(colors.gray, 0x595959)
term.setPaletteColor(colors.brown, 0xAC7339)
term.setPaletteColor(colors.red, 0xE60000)
term.setPaletteColor(colors.orange, 0xFF8C1A)
term.setPaletteColor(colors.yellow, 0xFFD11A)
term.setPaletteColor(colors.lime, 0x5CD65C)
term.setPaletteColor(colors.green, 0x267326)
term.setPaletteColor(colors.cyan, 0x00CCCC)
term.setPaletteColor(colors.lightBlue, 0x66CCFF)
term.setPaletteColor(colors.blue, 0x007ACC)
term.setPaletteColor(colors.purple, 0x8A00E6)
term.setPaletteColor(colors.magenta, 0xCC00CC)
term.setPaletteColor(colors.pink, 0xFF00BF)

local bg = [[00e000000000eee000000eeeeee0eeeee0ff4ffff4ffff4ffff
00e000000000e0e00e0e0e0000e0e00000ffff4fffff4ffffff
eee0e0e0eee0eee000e00e0000e0eeeee0f4ffffff4ffffffff
e0e0e0e0e0e000e00e000e0000e00000e0fffffffddff4fffff
eee0eee0e0e0eee0e0000eeeeee0eeeee0fffddfdddffffffff
0000000000000000000000000000000000f4fdddddfffff4fff
8888888888888888888888888888888880ffffddcccffffffff
8888888888888888888888888888888880ffffffddfcfffffff
8888888888888888888888888888888880fffffdddffcffffff
8888888888888888888888888888888880fffffddfffcffffff
8888888888888888888888888888888880ffffffffffcffffff
8888888888888888888888888888888880fffffffffffcfffff
8888888888888888888888888888888880fffffffffffcfffff
8888888888888888888888888888888880fffffffffffcfffff
8888888888888888888888888888888880ffffffffffffcffff
8888888888888888888888888888888880ffffffffffffcffff
8888888888888888888888888888888880ffffffffffffcffff
8888888888888888888888888888888880ddddddddddddddddd
8888888888888888888888888888888880ddddddddddddddddd"]]

local requestForAllTags = http.get("https://api.github.com/repos/" .. owner .. "/" .. repo .. "/tags")
local tags = textutils.unserializeJSON(requestForAllTags.readAll())

local releases = {}
local requestForReleases = http.get("https://api.github.com/repos/" .. owner .. "/" .. repo .. "/releases")
local unformattedReleases = textutils.unserializeJSON(requestForReleases.readAll())

for _, release in ipairs(unformattedReleases) do
    releases[release.tag_name] = release
end

local parentTerm = term.current()

local bgImage = paintutils.parseImage(bg)
paintutils.drawImage(bgImage, 1, 1)

local readyToInstall = false
local toInstall = ""

local content = window.create(term.current(), 1, 7, 33, 200, true)
term.redirect(content)

local function adjustForWindowCoords(x, y)
    return x, y - 6
end

local function terminate()
    term.redirect(parentTerm)
    for _, color in ipairs(colors) do
        term.setPaletteColor(term.nativePaletteColor(color))
    end
    os.reboot()
end

local function fetchTagCommitUrl(tagName)
    for i, tag in ipairs(tags) do
        if tag.name == tagName then
            return tag.commit.url
        end
    end
end

local function fetchReleaseData(tagName)
    local selected = -1
    for i, tag in ipairs(tags) do
        if tag.name == tagName then
            selected = i
            break
        end
    end

    if selected == -1 then
        return nil
    end

    local releaseData = releases[tags[selected].name]

    if releaseData.draft == true then
        return nil
    end

    return releaseData
end

local function getCommitFromURL(url)
    local splitCommitURL = split(url, "/")
    return splitCommitURL[8]
end

local function getReleaseCommit(type, ...)
    if type == "pre" or type == "stable" then
        for _, tag in ipairs(tags) do
            local releaseData = fetchReleaseData(tag.name)
            if releaseData.draft == false then
                if releaseData.prerelease == true and type == "pre" then
                    return getCommitFromURL(tag.commit.url)
                end

                if releaseData.prerelease == false then
                    return getCommitFromURL(tag.commit.url)
                end
            end
        end
    elseif type == "version" then
        local version = arg[1]
        local releaseData = fetchReleaseData("dungy-v" .. version)
        if releaseData ~= nil then
            return getCommitFromURL(fetchTagCommitUrl("dungy-v" .. version))
        end
    end

    return nil
end

local function getNewest(type)
    for i, tag in ipairs(tags) do
        local releaseData = fetchReleaseData(tag.name)
        if releaseData.draft == false then
            if releaseData.prerelease == true and type == "pre" then
                return releaseData.name
            end

            if releaseData.prerelease == false then
                return releaseData.name
            end
        end
    end

    return nil
end

local function installBleedingEdge()
    term.clear()
    term.setCursorPos(1, 1)

    print("Loading...")
    local version = getNewest("pre")

    term.clear()
    term.setCursorPos(1, 1)
    print("Latest pre-release version:")
    print(version)
    print()
    print("Install this version?")
    print()
    print("Yes")
    print()
    print("No")

    local actions = {
        {
            fromX = 1,
            fromY = 6,
            toX = 3,
            toY = 6,
            trigger = function()
                toInstall = getNewest("pre")
                readyToInstall = true
            end,
        },
        {
            fromX = 1,
            fromY = 8,
            toX = 2,
            toY = 8,
            trigger = function()
                readyToInstall = false
            end,
        },
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

local function installStable()
    term.clear()
    term.setCursorPos(1, 1)

    print("Loading...")
    local version = getNewest("stable")

    term.clear()
    term.setCursorPos(1, 1)

    if version ~= nil then
        print("Stable release version:")
        print(version)
        print()
        print("Install this version?")
        print()
        print("Yes")
        print()
        print("No")

        local actions = {
            {
                fromX = 1,
                fromY = 6,
                toX = 3,
                toY = 6,
                trigger = function()
                    toInstall = getReleaseCommit("stable")
                    readyToInstall = true
                end,
            },
            {
                fromX = 1,
                fromY = 8,
                toX = 2,
                toY = 8,
                trigger = function()
                    readyToInstall = false
                end,
            },
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
    else
        print("No stable releases available. Would you like to install the latest pre-release instead?")
        print()
        print("Yes")
        print()
        print("No") 
        
        local actions = {
            {
                fromX = 1,
                fromY = 5,
                toX = 3,
                toY = 5,
                trigger = installBleedingEdge,
            },
            {
                fromX = 1,
                fromY = 7,
                toX = 2,
                toY = 7,
                trigger = terminate,
            },
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
end

local function installOther()
    term.clear()
    term.setCursorPos(1, 1)

    print("Please enter a version:")
    local input = read()
    print()
    print("Checking if version exists...")
    local commit = getReleaseCommit("version", input)

    if commit == nil then
        print()
        term.setTextColor(colors.red)
        print("Version " .. input .. " does not exist! Try again.")
        sleep(2)
        term.setTextColor(colors.lime)
        installOther()
    else
        print()
        term.setTextColor(colors.lightBlue)
        print("Version " .. input .. " exists!")
        sleep(1)
        term.setTextColor(colors.lime) 
        
        term.setCursorPos(1, 1)
        term.clear()
        print("Selected version:")
        print(input)
        print()
        print("Install this version?")
        print()
        print("Yes")
        print()
        print("No")

        local actions = {
            {
                fromX = 1,
                fromY = 6,
                toX = 3,
                toY = 6,
                trigger = function()
                    toInstall = commit
                    readyToInstall = true
                end,
            },
            {
                fromX = 1,
                fromY = 8,
                toX = 2,
                toY = 8,
                trigger = function()
                    readyToInstall = false
                end,
            },
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
end

local function drawFirstScreen()
    term.setBackgroundColor(colors.gray)
    term.setTextColor(colors.lime)
    term.clear()
    term.setCursorPos(1, 1)

    print("Welcome to the dungyOS Installer!")
    print("Please select an option:")
    print()
    print("Install stable release")
    print()
    print("Install latest pre-release")
    print()
    print("Install a specific version")
    print()
    print("Exit installer")

    local actions = {
        {
            fromX = 1,
            fromY = 4,
            toX = 22,
            toY = 4,
            trigger = installStable,
        },
        {
            fromX = 1,
            fromY = 6,
            toX = 26,
            toY = 6,
            trigger = installBleedingEdge,
        },
        {
            fromX = 1,
            fromY = 8,
            toX = 26,
            toY = 8,
            trigger = installOther
        },
        {
            fromX = 1,
            fromY = 10,
            toX = 14,
            toY = 10,
            trigger = terminate
        },
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

local function postInstall()
    term.clear()
    term.setCursorPos(1, 1)
    print("dungyOS has successfully been installed on your computer. Thanks for choosing dungyOS. In just a few moments, post-install setup will begin.")
    sleep(3)
    print()

    print("Starting post-install setup...")
    while true do
        sleep(0.05)
    end
end

local function runInstallation()
    term.clear()
    term.setCursorPos(1, 1)

    print("Wiping computer...")
    for _, file in ipairs(fs.list("/")) do
        if not fs.isReadOnly("/" .. file) then
            fs.delete(file)
        end
    end
    print("Computer wiped!")

    print()
    sleep(0.25)

    print("Installing...")
    gitDownload(toInstall, "/downloads")
    print("Cleaning up...")
    fs.makeDir("/tmp")
    fs.copy("/downloads/dungyOS", "/tmp")
    fs.delete("/downloads")
    fs.copy("/tmp/*", "/")
    fs.delete("/tmp")
    print("All done!")

    sleep(1)
    postInstall()
end

local function installerWarning()
    os.pullEvent = os.pullEventRaw
    term.clear()
    term.setCursorPos(1, 1)
    term.setTextColor(colors.red)
    print("WARNING:")
    print("To ensure the best experience, this installer will delete all files on this computer. Please exit the installer and move files to a backup disk in order to keep them.")
    print()
    term.setTextColor(colors.lime)
    print("Continue")
    print()
    print("Exit")
    
    local actions = {
        {
            fromX = 1,
            fromY = 9,
            toX = 8,
            toY = 9,
            trigger = runInstallation,
        },
        {
            fromX = 1,
            fromY = 11,
            toX = 4,
            toY = 11,
            trigger = terminate,
        },
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

while readyToInstall ~= true do
    drawFirstScreen()
end

installerWarning()