if pocket or turtle then
    printError("ERROR: dungyOS must be run on a regular computer!")
end

if not term.isColor() then
    printError("ERROR: dungyOS requires color!")
end

os.pullEvent = os.pullEventRaw

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
term.clear()
term.setCursorPos(1, 1)
term.setTextColor(colors.orange)
print("Starting dungyOS 2022.1")
print("============================")
term.setTextColor(colors.white)
print()
term.write("<")
term.setCursorPos(24, 4)
term.write(">")
term.setCursorPos(2, 4)
term.setTextColor(colors.yellow)
textutils.slowWrite("----------------------", 5)
term.setTextColor(colors.white)
term.setCursorPos(24, 4)
term.write(">")