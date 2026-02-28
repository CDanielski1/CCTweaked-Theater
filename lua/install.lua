-- CCTweaked-Theater Installer
-- Run in-game: wget run https://raw.githubusercontent.com/CDanielski1/CCTweaked-Theater/main/lua/install.lua

-- SET THIS TO YOUR REPO before pushing
local repoBase = "https://raw.githubusercontent.com/CDanielski1/CCTweaked-Theater/main"

term.clear()
term.setCursorPos(1, 1)
print("=== CCTweaked-Theater Installer ===")
print()

-- Save the repo URL so menu.lua knows where to fetch from
print("Saving config...")
local f = fs.open("/.theater-config", "w")
f.writeLine(repoBase)
f.close()

-- Download menu
print("Downloading menu...")
local res = http.get(repoBase .. "/lua/menu.lua")
if not res then
  printError("Failed to download menu.")
  return
end
local f = fs.open("/movie", "w")
f.write(res.readAll())
f.close()
res.close()
print("  Saved as /movie")

-- Download player
print("Downloading player...")
local res = http.get(repoBase .. "/lua/player.lua")
if not res then
  printError("Failed to download player.")
  return
end
local f = fs.open("/32vid-player", "w")
f.write(res.readAll())
f.close()
res.close()
print("  Saved as /32vid-player")

print()
print("Install complete!")
print("Run 'movie' to start.")
print()
print("Hardware needed:")
print("  - Advanced monitors (8x4 recommended)")
print("  - Speaker")
