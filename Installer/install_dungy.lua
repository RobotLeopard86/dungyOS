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

local function convertURL(url, branch)
    local splitURL = split(url, "/")
    
    if ends_with(splitURL[5], ".git") then 
        splitURL[5] = string.sub(splitURL[5], 0, string.len(splitURL[5]) - 4) 
    end

    local repoSection = splitURL[4] .. "/" .. splitURL[5]

    local api = "https://api.github.com/repos/" .. repoSection .. "/git/trees/" .. branch .. "?recursive=1"

    local raw = "https://raw.githubusercontent.com/" .. repoSection .. "/" .. branch .. "/"

    return {
        apiPath = api,
        rawPath = raw
    }
end

local function gitDownload(repoURL, branch, output)
    local converted = convertURL(repoURL, branch)
    local request = http.get(converted.apiPath)
    if request ~= nil then
        local contents = textutils.unserializeJSON(request.readAll())
        request.close()
        for i, file in ipairs(contents.tree) do
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

print("Starting installer...")
sleep(1)

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

local bgImage = paintutils.parseImage(bg)
paintutils.drawImage(bgImage, 1, 1)

while true do
    sleep(0.05)
end