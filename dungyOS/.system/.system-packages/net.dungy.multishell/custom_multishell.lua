--- Multishell allows multiple programs to be run at the same time.
--
-- When multiple programs are running, it displays a tab bar at the top of the
-- screen, which allows you to switch between programs. New programs can be
-- launched using the `fg` or `bg` programs, or using the @{shell.openTab} and
-- @{multishell.launch} functions.
--
-- Each process is identified by its ID, which corresponds to its position in
-- the tab list. As tabs may be opened and closed, this ID is _not_ constant
-- over a program's run. As such, be careful not to use stale IDs.
--
-- As with @{shell}, @{multishell} is not a "true" API. Instead, it is a
-- standard program, which launches a shell and injects its API into the shell's
-- environment. This API is not available in the global environment, and so is
-- not available to @{os.loadAPI|APIs}.
--
-- @module[module] multishell
-- @since 1.6

local expect = dofile("rom/modules/main/cc/expect.lua").expect

local userdat = {}

-- Setup process switching
local parentTerm = term.current()
local w, h = parentTerm.getSize()

local tProcesses = {}
local nCurrentProcess = nil
local nRunningProcess = nil
local bShowMenu = false
local bWindowsResized = false
local nScrollPos = 1
local bScrollRight = false

local function selectProcess(n)
    if nCurrentProcess ~= n then
        if nCurrentProcess then
            local tOldProcess = tProcesses[nCurrentProcess]
            tOldProcess.window.setVisible(false)
        end
        nCurrentProcess = n
        if nCurrentProcess then
            local tNewProcess = tProcesses[nCurrentProcess]
            tNewProcess.window.setVisible(true)
            tNewProcess.bInteracted = true
        end
    end
end

local function setProcessTitle(n, sTitle)
    tProcesses[n].sTitle = sTitle
end

local function resumeProcess(nProcess, sEvent, ...)
    local tProcess = tProcesses[nProcess]
    local sFilter = tProcess.sFilter
    if sFilter == nil or sFilter == sEvent or sEvent == "terminate" then
        local nPreviousProcess = nRunningProcess
        nRunningProcess = nProcess
        term.redirect(tProcess.terminal)
        local ok, result = coroutine.resume(tProcess.co, sEvent, ...)
        tProcess.terminal = term.current()
        if ok then
            tProcess.sFilter = result
        else
            printError(result)
        end
        nRunningProcess = nPreviousProcess
    end
end

local function launchProcess(bFocus, tProgramEnv, sProgramPath, ...)
    local tProgramArgs = table.pack(...)
    local tProcess = {}
    local nProcess = #tProcesses + 1
    tProcess.sTitle = fs.getName(sProgramPath)
    if bShowMenu then
        tProcess.window = window.create(parentTerm, 1, 2, w, h - 1, false)
    else
        tProcess.window = window.create(parentTerm, 1, 1, w, h, false)
    end
    tProcess.co = coroutine.create(function()
        os.run(tProgramEnv, sProgramPath, table.unpack(tProgramArgs, 1, tProgramArgs.n))
        if not tProcess.bInteracted then
            term.setCursorBlink(false)
            print("Press any key to continue")
            os.pullEvent("char")
        end
    end)
    tProcess.sFilter = nil
    tProcess.terminal = tProcess.window
    tProcess.bInteracted = false
    tProcesses[nProcess] = tProcess
    if bFocus then
        selectProcess(nProcess)
    end
    resumeProcess(nProcess)
    return nProcess
end

local function cullProcess(nProcess)
    local tProcess = tProcesses[nProcess]
    if coroutine.status(tProcess.co) == "dead" then
        if nCurrentProcess == nProcess then
            selectProcess(nil)
        end
        table.remove(tProcesses, nProcess)
        if nCurrentProcess == nil then
            if nProcess > 1 then
                selectProcess(nProcess - 1)
            elseif #tProcesses > 0 then
                selectProcess(1)
            end
        end
        nScrollPos = 0
        return true
    end
    return false
end

local function cullProcesses()
    local culled = false
    for n = #tProcesses, 1, -1 do
        culled = culled or cullProcess(n)
    end
    return culled
end

-- Setup the main menu
local menuMainTextColor, menuMainBgColor, menuOtherTextColor, menuOtherBgColor
if parentTerm.isColor() then
    menuMainTextColor, menuMainBgColor = colors.yellow, colors.black
    menuOtherTextColor, menuOtherBgColor = colors.black, colors.gray
else
    menuMainTextColor, menuMainBgColor = colors.white, colors.black
    menuOtherTextColor, menuOtherBgColor = colors.black, colors.gray
end

local function redrawMenu()
end

local function resizeWindows()
    local _, windowHeight = term.native().getSize()
    for n = 1, #tProcesses do
        local tProcess = tProcesses[n]
        tProcess.window.reposition(1, 1, w, windowHeight)
    end
    bWindowsResized = true
end

local function setMenuVisible(bVis)
    if true then
        bShowMenu = false
        resizeWindows()
        redrawMenu()
    end
end

local r = require "cc.require"

local function betterRequire(packageName, file, isSystemPackage)
    local env = setmetatable({}, { __index = _ENV })
    if isSystemPackage == true then
        env.require = r.make(env, "/.system/.system-packages/" .. packageName)
    else
        env.require = r.make(env, "/.users/.packages/" .. userdat.username .. "/" .. packageName)
    end
    return env.require(file)
end

local function betterRead(_sReplaceChar, _kCancelKey, _tHistory, _fnComplete, _sDefault)
    expect(1, _sReplaceChar, "string", "nil")
    expect(2, _kCancelKey, "number", "nil")
    expect(3, _tHistory, "table", "nil")
    expect(4, _fnComplete, "function", "nil")
    expect(5, _sDefault, "string", "nil")

    if _kCancelKey ~= nil and keys[_kCancelKey] == nil then
        printError("ERROR: Provided cancel key is not in keys map")
        return nil
    end

    local bannedCancelKeys = {
        tab = keys.tab,
        enter = keys.enter,
        left = keys.left,
        right = keys.right,
        up = keys.up,
        down = keys.down,
        home = keys.home,
        ["end"] = keys["end"],
        backspace = keys.backspace,
        delete = keys.delete
    }

    if _kCancelKey ~= nil and bannedCancelKeys[_kCancelKey] ~= nil then
        printError("ERROR: Provided cancel key cannot be used as it is necessary for input")
    end

    term.setCursorBlink(true)

    local sLine
    if type(_sDefault) == "string" then
        sLine = _sDefault
    else
        sLine = ""
    end
    local nHistoryPos
    local nPos, nScroll = #sLine, 0
    if _sReplaceChar then
        _sReplaceChar = string.sub(_sReplaceChar, 1, 1)
    end

    local tCompletions
    local nCompletion
    local function recomplete()
        if _fnComplete and nPos == #sLine then
            tCompletions = _fnComplete(sLine)
            if tCompletions and #tCompletions > 0 then
                nCompletion = 1
            else
                nCompletion = nil
            end
        else
            tCompletions = nil
            nCompletion = nil
        end
    end

    local function uncomplete()
        tCompletions = nil
        nCompletion = nil
    end

    local w = term.getSize()
    local sx = term.getCursorPos()

    local function redraw(_bClear)
        local cursor_pos = nPos - nScroll
        if sx + cursor_pos >= w then
            -- We've moved beyond the RHS, ensure we're on the edge.
            nScroll = sx + nPos - w
        elseif cursor_pos < 0 then
            -- We've moved beyond the LHS, ensure we're on the edge.
            nScroll = nPos
        end

        local _, cy = term.getCursorPos()
        term.setCursorPos(sx, cy)
        local sReplace = _bClear and " " or _sReplaceChar
        if sReplace then
            term.write(string.rep(sReplace, math.max(#sLine - nScroll, 0)))
        else
            term.write(string.sub(sLine, nScroll + 1))
        end

        if nCompletion then
            local sCompletion = tCompletions[nCompletion]
            local oldText, oldBg
            if not _bClear then
                oldText = term.getTextColor()
                oldBg = term.getBackgroundColor()
                term.setTextColor(colors.white)
                term.setBackgroundColor(colors.gray)
            end
            if sReplace then
                term.write(string.rep(sReplace, #sCompletion))
            else
                term.write(sCompletion)
            end
            if not _bClear then
                term.setTextColor(oldText)
                term.setBackgroundColor(oldBg)
            end
        end

        term.setCursorPos(sx + nPos - nScroll, cy)
    end

    local function clear()
        redraw(true)
    end

    recomplete()
    redraw()

    local function acceptCompletion()
        if nCompletion then
            -- Clear
            clear()

            -- Find the common prefix of all the other suggestions which start with the same letter as the current one
            local sCompletion = tCompletions[nCompletion]
            sLine = sLine .. sCompletion
            nPos = #sLine

            -- Redraw
            recomplete()
            redraw()
        end
    end
    while true do
        local sEvent, param, param1, param2 = os.pullEvent()
        if sEvent == "char" then
            -- Typed key
            clear()
            sLine = string.sub(sLine, 1, nPos) .. param .. string.sub(sLine, nPos + 1)
            nPos = nPos + 1
            recomplete()
            redraw()

        elseif sEvent == "paste" then
            -- Pasted text
            clear()
            sLine = string.sub(sLine, 1, nPos) .. param .. string.sub(sLine, nPos + 1)
            nPos = nPos + #param
            recomplete()
            redraw()

        elseif sEvent == "key" then
            if param == keys.enter then
                -- Enter
                if nCompletion then
                    clear()
                    uncomplete()
                    redraw()
                end
                break

            elseif param == keys.left then
                -- Left
                if nPos > 0 then
                    clear()
                    nPos = nPos - 1
                    recomplete()
                    redraw()
                end

            elseif param == keys.right then
                -- Right
                if nPos < #sLine then
                    -- Move right
                    clear()
                    nPos = nPos + 1
                    recomplete()
                    redraw()
                else
                    -- Accept autocomplete
                    acceptCompletion()
                end

            elseif param == keys.up or param == keys.down then
                -- Up or down
                if nCompletion then
                    -- Cycle completions
                    clear()
                    if param == keys.up then
                        nCompletion = nCompletion - 1
                        if nCompletion < 1 then
                            nCompletion = #tCompletions
                        end
                    elseif param == keys.down then
                        nCompletion = nCompletion + 1
                        if nCompletion > #tCompletions then
                            nCompletion = 1
                        end
                    end
                    redraw()

                elseif _tHistory then
                    -- Cycle history
                    clear()
                    if param == keys.up then
                        -- Up
                        if nHistoryPos == nil then
                            if #_tHistory > 0 then
                                nHistoryPos = #_tHistory
                            end
                        elseif nHistoryPos > 1 then
                            nHistoryPos = nHistoryPos - 1
                        end
                    else
                        -- Down
                        if nHistoryPos == #_tHistory then
                            nHistoryPos = nil
                        elseif nHistoryPos ~= nil then
                            nHistoryPos = nHistoryPos + 1
                        end
                    end
                    if nHistoryPos then
                        sLine = _tHistory[nHistoryPos]
                        nPos, nScroll = #sLine, 0
                    else
                        sLine = ""
                        nPos, nScroll = 0, 0
                    end
                    uncomplete()
                    redraw()

                end

            elseif param == keys.backspace then
                -- Backspace
                if nPos > 0 then
                    clear()
                    sLine = string.sub(sLine, 1, nPos - 1) .. string.sub(sLine, nPos + 1)
                    nPos = nPos - 1
                    if nScroll > 0 then nScroll = nScroll - 1 end
                    recomplete()
                    redraw()
                end

            elseif param == keys.home then
                -- Home
                if nPos > 0 then
                    clear()
                    nPos = 0
                    recomplete()
                    redraw()
                end

            elseif param == keys.delete then
                -- Delete
                if nPos < #sLine then
                    clear()
                    sLine = string.sub(sLine, 1, nPos) .. string.sub(sLine, nPos + 2)
                    recomplete()
                    redraw()
                end

            elseif param == keys["end"] then
                -- End
                if nPos < #sLine then
                    clear()
                    nPos = #sLine
                    recomplete()
                    redraw()
                end

            elseif param == keys.tab then
                -- Tab (accept autocomplete)
                acceptCompletion()

            elseif param == _kCancelKey then
                -- Cancel key, terminates input
                return nil
            end

        elseif sEvent == "mouse_click" or sEvent == "mouse_drag" and param == 1 then
            local _, cy = term.getCursorPos()
            if param1 >= sx and param1 <= w and param2 == cy then
                -- Ensure we don't scroll beyond the current line
                nPos = math.min(math.max(nScroll + param1 - sx, 0), #sLine)
                redraw()
            end

        elseif sEvent == "term_resize" then
            -- Terminal resized
            w = term.getSize()
            redraw()

        end
    end

    local _, cy = term.getCursorPos()
    term.setCursorBlink(false)
    term.setCursorPos(w + 1, cy)
    print()

    return sLine
end

local multishell = {} --- @export

--- Get the currently visible process. This will be the one selected on
-- the tab bar.
--
-- Note, this is different to @{getCurrent}, which returns the process which is
-- currently executing.
--
-- @treturn number The currently visible process's index.
-- @see setFocus
function multishell.getFocus()
    return nCurrentProcess
end

--- Change the currently visible process.
--
-- @tparam number n The process to switch to.
-- @treturn boolean If the process was changed successfully. This will
-- return @{false} if there is no process with this id.
-- @see getFocus
function multishell.setFocus(n)
    expect(1, n, "number")
    if n >= 1 and n <= #tProcesses then
        selectProcess(n)
        redrawMenu()
        return true
    end
    return false
end

--- Get the title of the given tab.
--
-- This starts as the name of the program, but may be changed using
-- @{multishell.setTitle}.
-- @tparam number n The process id.
-- @treturn string|nil The current process title, or @{nil} if the
-- process doesn't exist.
function multishell.getTitle(n)
    expect(1, n, "number")
    if n >= 1 and n <= #tProcesses  then
        return tProcesses[n].sTitle
    end
    return nil
end

--- Return all tab titles
--
-- @treturn table Titles of all currently running processes
-- @see getTitle
function multishell.getTitles()
    local titles = {}
    for _, process in ipairs(tProcesses) do
        table.insert(titles, multishell.getTitle(process))
    end
    return titles
end

--- Set the title of the given process.
--
-- @tparam number n The process id.
-- @tparam string title The new process title.
-- @see getTitle
-- @usage Change the title of the current process
--
--     multishell.setTitle(multishell.getCurrent(), "Hello")
function multishell.setTitle(n, title)
    expect(1, n, "number")
    expect(2, title, "string")
    if n >= 1 and n <= #tProcesses then
        setProcessTitle(n, title)
        redrawMenu()
    end
end

--- Get the index of the currently running process.
--
-- @treturn number The currently running process.
function multishell.getCurrent()
    return nRunningProcess
end

--- Start a new process, with the given environment, program and arguments.
--
-- The returned process index is not constant over the program's run. It can be
-- safely used immediately after launching (for instance, to update the title or
-- switch to that tab). However, after your program has yielded, it may no
-- longer be correct.
--
-- @tparam table tProgramEnv The environment to load the path under.
-- @tparam string sProgramPath The path to the program to run.
-- @param ... Additional arguments to pass to the program.
-- @treturn number The index of the created process.
-- @see os.run
-- @usage Run the "hello" program, and set its title to "Hello!"
--
--     local id = multishell.launch({}, "/rom/programs/fun/hello.lua")
--     multishell.setTitle(id, "Hello!")
function multishell.launch(tProgramEnv, sProgramPath, ...)
    expect(1, tProgramEnv, "table")
    expect(2, sProgramPath, "string")
    local previousTerm = term.current()
    tProgramEnv["require"] = betterRequire
    tProgramEnv["shell"] = shell
    tProgramEnv["user"] = userdat
    tProgramEnv["multishell"] = multishell
    tProgramEnv["settings"] = {}
    tProgramEnv["io"] = {}
    local nResult = launchProcess(false, tProgramEnv, sProgramPath, ...)
    redrawMenu()
    term.redirect(previousTerm)
    return nResult
end

--- Get the number of processes within this multishell.
--
-- @treturn number The number of processes.
function multishell.getCount()
    return #tProcesses
end

-- Begin
parentTerm.clear()
setMenuVisible(false)

local handle = fs.open("/.system/.system-storage/salt.txt", "r")
local salty = handle.readAll()
handle.close()

launchProcess(true, {
    ["shell"] = shell,
    ["multishell"] = multishell,
    ["require"] = betterRequire,
    ["read"] = betterRead,
    ["salt"] = salty,
    ["userdata"] = userdat
}, "/.system/.system-packages/net.dungy.login/login.lua")

-- Run processes
while #tProcesses > 0 do

    if coroutine.status(tProcesses[nCurrentProcess].co) == "dead" then
        local nOldProcess = nCurrentProcess
        if #tProcesses > 1 then
            if nCurrentProcess > 1 then
                selectProcess(nCurrentProcess - 1)
            else
                selectProcess(nCurrentProcess + 1)
            end
        end
        table.remove(tProcesses, nOldProcess)
        if #tProcesses == 0 then
            break
        end
    end

    setMenuVisible(false)
    -- Get the event
    local tEventData = table.pack(os.pullEventRaw())
    local sEvent = tEventData[1]
    if sEvent == "term_resize" then
        -- Resize event
        w, h = parentTerm.getSize()
        resizeWindows()
        redrawMenu()

    elseif sEvent == "char" or sEvent == "key" or sEvent == "key_up" or sEvent == "paste" or sEvent == "terminate" then
        -- Keyboard event
        -- Passthrough to current process
        resumeProcess(nCurrentProcess, table.unpack(tEventData, 1, tEventData.n))
        if cullProcess(nCurrentProcess) then
            setMenuVisible(false)
            redrawMenu()
        end

    elseif sEvent == "mouse_click" then
        -- Click event
        local button, x, y = tEventData[2], tEventData[3], tEventData[4]
        if bShowMenu and y == 1 then
            -- Switch process
            if x == 1 and nScrollPos ~= 1 then
                nScrollPos = nScrollPos - 1
                redrawMenu()
            elseif bScrollRight and x == term.getSize() then
                nScrollPos = nScrollPos + 1
                redrawMenu()
            else
                local tabStart = 1
                if nScrollPos ~= 1 then
                    tabStart = 2
                end
                for n = nScrollPos, #tProcesses do
                    local tabEnd = tabStart + #tProcesses[n].sTitle + 1
                    if x >= tabStart and x <= tabEnd then
                        selectProcess(n)
                        redrawMenu()
                        break
                    end
                    tabStart = tabEnd + 1
                end
            end
        else
            -- Passthrough to current process
            resumeProcess(nCurrentProcess, sEvent, button, x, bShowMenu and y - 1 or y)
            if cullProcess(nCurrentProcess) then
                setMenuVisible(false)
                redrawMenu()
            end
        end

    elseif sEvent == "mouse_drag" or sEvent == "mouse_up" or sEvent == "mouse_scroll" then
        -- Other mouse event
        local p1, x, y = tEventData[2], tEventData[3], tEventData[4]
        if bShowMenu and sEvent == "mouse_scroll" and y == 1 then
            if p1 == -1 and nScrollPos ~= 1 then
                nScrollPos = nScrollPos - 1
                redrawMenu()
            elseif bScrollRight and p1 == 1 then
                nScrollPos = nScrollPos + 1
                redrawMenu()
            end
        elseif not (bShowMenu and y == 1) then
            -- Passthrough to current process
            resumeProcess(nCurrentProcess, sEvent, p1, x, bShowMenu and y - 1 or y)
            if cullProcess(nCurrentProcess) then
                setMenuVisible(false)
                redrawMenu()
            end
        end

    else
        -- Other event
        -- Passthrough to all processes
        local nLimit = #tProcesses -- Storing this ensures any new things spawned don't get the event
        for n = 1, nLimit do
            resumeProcess(n, table.unpack(tEventData, 1, tEventData.n))
        end
        if cullProcesses() then
            setMenuVisible(#tProcesses >= 2)
            redrawMenu()
        end
    end

    if false then
        -- Pass term_resize to all processes
        local nLimit = #tProcesses -- Storing this ensures any new things spawned don't get the event
        for n = 1, nLimit do
            resumeProcess(n, "term_resize")
        end
        bWindowsResized = false
        if cullProcesses() then
            setMenuVisible(#tProcesses >= 2)
            redrawMenu()
        end
    end
    setMenuVisible(false)
end

-- Shutdown
term.redirect(parentTerm)