term.setBackgroundColor(colors.white)
term.setTextColor(colors.green)
term.setCursorPos(1, 1)
term.clear()

print("Hello, " .. user.displayname .. "!")
print()
print("Welcome to your (work-in-progress) desktop!")
print()
print("You have " .. user.permission .. " permissions! Enjoy!")

while true do
    local _, key = os.pullEvent("key")
    if key == keys["end"] then
        break
    end
end
print()
term.setTextColor(colors.red)
print("You asked for this...")
sleep(1)
shell.exit()