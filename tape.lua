# Reposting the full tape control script for OpenComputers

tape_script = '''--[[ tape program, provides basic tape modification and access tools
Authors: Bizzycola and Vexatos
]]
local component = require("component")
local fs = require("filesystem")
local shell = require("shell")
local term = require("term")

local args, options = shell.parse(...)

if not component.isAvailable("tape_drive") then
  io.stderr:write("This program requires a tape drive to run.\\n")
  return
end

local function printUsage()
  print("Usage:")
  print(" - 'tape play' to start playing a tape")
  print(" - 'tape pause' to pause playing the tape")
  print(" - 'tape stop' to stop playing and rewind the tape")
  print(" - 'tape rewind' to rewind the tape")
  print(" - 'tape wipe' to wipe any data on the tape and erase it completely")
  print(" - 'tape label [name]' to label the tape, leave 'name' empty to get current label")
  print(" - 'tape speed <speed>' to set the playback speed. Needs to be between 0.25 and 2.0")
  print(" - 'tape volume <volume>' to set the volume of the tape. Needs to be between 0.0 and 1.0")
  print(" - 'tape write <path/of/audio/file>' to write to the tape from a file")
  print(" - 'tape write <URL>' to write from a URL")
  print("Other options:")
  print(" '--address=<address>' to use a specific tape drive")
  print(" '--b=<bytes>' to specify the size of the chunks the program will write to a tape")
  print(" '--t=<timeout>' to specify a custom maximum timeout in seconds when writing from a URL")
  print(" '-y' to not ask for confirmation before starting to write")
end

local function getTapeDrive()
  local tape
  if options.address then
    local fulladdr = component.get(options.address)
    if not fulladdr or component.type(fulladdr) ~= "tape_drive" then
      io.stderr:write("Invalid tape drive address.\\n")
      return
    end
    tape = component.proxy(fulladdr)
  else
    tape = component.tape_drive
  end
  return tape
end

local tape = getTapeDrive()
if not tape or not tape.isReady() then
  io.stderr:write("The tape drive does not contain a tape.\\n")
  return
end

local function label(name)
  if not name then
    print("Tape label: " .. (tape.getLabel() or "<none>"))
  else
    tape.setLabel(name)
    print("Tape label set to: " .. name)
  end
end

local function rewind()
  tape.seek(-tape.getSize())
  print("Tape rewound.")
end

local function play()
  if tape.getState() == "PLAYING" then
    print("Tape is already playing.")
  else
    tape.play()
    print("Tape playing.")
  end
end

local function stop()
  tape.stop()
  tape.seek(-tape.getSize())
  print("Tape stopped and rewound.")
end

local function pause()
  tape.stop()
  print("Tape paused.")
end

local function speed(val)
  local s = tonumber(val)
  if s and s >= 0.25 and s <= 2.0 then
    tape.setSpeed(s)
    print("Speed set to: " .. s)
  else
    io.stderr:write("Invalid speed. Must be 0.25–2.0\\n")
  end
end

local function volume(val)
  local v = tonumber(val)
  if v and v >= 0.0 and v <= 1.0 then
    tape.setVolume(v)
    print("Volume set to: " .. v)
  else
    io.stderr:write("Invalid volume. Must be 0.0–1.0\\n")
  end
end

local function confirm(msg)
  if not options.y then
    print(msg .. " Type y to confirm:")
    local r = io.read()
    if r:lower():sub(1,1) ~= "y" then
      print("Cancelled.")
      return false
    end
  end
  return true
end

local function wipe()
  if not confirm("Wipe tape?") then return end
  tape.stop()
  tape.seek(-tape.getSize())
  local fill = string.rep("\\xAA", 8192)
  for i = 1, tape.getSize(), 8192 do
    tape.write(fill)
  end
  tape.seek(-tape.getSize())
  print("Tape wiped.")
end

local function writeTape(path)
  local file, msg
  if not confirm("Write to tape?") then return end
  local blockSize = tonumber(options.b or 2048)
  tape.stop()
  tape.seek(-tape.getSize())

  if path:match("^https?://") then
    if not component.isAvailable("internet") then
      io.stderr:write("No internet card present.\\n")
      return
    end
    local internet = component.internet
    file = internet.request(path)
    if not file then
      io.stderr:write("Failed to download.\\n")
      return
    end
  else
    file, msg = io.open(shell.resolve(path), "rb")
    if not file then
      io.stderr:write("Error opening file: " .. msg .. "\\n")
      return
    end
  end

  print("Writing...")
  local read = file.read or function(n) return file:read(n) end
  while true do
    local chunk = read(file, blockSize)
    if not chunk then break end
    tape.write(chunk)
  end
  if file.close then file:close() end
  tape.stop()
  tape.seek(-tape.getSize())
  print("Done writing.")
end

if args[1] == "play" then play()
elseif args[1] == "pause" then pause()
elseif args[1] == "stop" then stop()
elseif args[1] == "rewind" then rewind()
elseif args[1] == "label" then label(args[2])
elseif args[1] == "speed" then speed(args[2])
elseif args[1] == "volume" then volume(args[2])
elseif args[1] == "wipe" then wipe()
elseif args[1] == "write" then writeTape(args[2])
else printUsage()
end
'''

# Save this to a file the user can download
with open("/mnt/data/tape.lua", "w") as f:
    f.write(tape_script)

"/mnt/data/tape.lua"
