-- CCTweaked-Theater Menu
-- Fetches catalog from GitHub, lets user pick a movie, launches player

-- Read config for repo base URL
if not fs.exists("/.theater-config") then
  printError("Theater not configured. Run the installer first.")
  return
end

local f = fs.open("/.theater-config", "r")
local repoBase = f.readLine()
f.close()

-- Fetch catalog
local catalogUrl = repoBase .. "/catalog.json"
local res = http.get(catalogUrl)
if not res then
  printError("Failed to fetch catalog from:")
  printError(catalogUrl)
  return
end

local catalogData = res.readAll()
res.close()

local catalog = textutils.unserialiseJSON(catalogData)
if not catalog or #catalog == 0 then
  print("No movies in catalog.")
  return
end

-- Display menu
term.clear()
term.setCursorPos(1, 1)
print("=== Movie Night ===")
print()
for i, entry in ipairs(catalog) do
  print(i .. ". " .. entry.name)
end
print()
write("Pick a movie (or q to quit): ")

local input = read()
if input == "q" then return end

local choice = tonumber(input)
if not choice or not catalog[choice] then
  printError("Invalid choice.")
  return
end

local movie = catalog[choice]
local movieUrl = repoBase .. "/" .. movie.path

print()
print("Now playing: " .. movie.name)
print("Press Ctrl+T to stop playback.")
sleep(2)

-- Find a monitor
local monitor = nil

for _, side in ipairs({"left", "right", "top", "bottom", "front", "back"}) do
  if peripheral.getType(side) == "monitor" then
    monitor = peripheral.wrap(side)
    break
  end
end

if not monitor then
  for _, name in ipairs(peripheral.getNames()) do
    if peripheral.getType(name) == "monitor" then
      monitor = peripheral.wrap(name)
      break
    end
  end
end

if monitor then
  monitor.setTextScale(0.5)
  local originalTerm = term.redirect(monitor)
  term.clear()
  shell.run("/32vid-player", movieUrl)
  term.redirect(originalTerm)
else
  -- No monitor, play on computer screen
  shell.run("/32vid-player", movieUrl)
end

-- Reset terminal
term.setBackgroundColor(colors.black)
term.setTextColor(colors.white)
term.clear()
term.setCursorPos(1, 1)
print("Playback finished: " .. movie.name)
