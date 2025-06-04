--[[ tape program, provides basic tape modification and access tools
Authors: Bizzycola and Vexatos
Fixed for consistent tape detection
]]

local component = require("component")
local fs = require("filesystem")
local shell = require("shell")
local term = require("term")

local args, options = shell.parse(...)

-- Validate tape drive availability
local function getTapeDrive()
  for address, ctype in component.list("tape_drive") do
    return component.proxy(address)
  end
end

local tape = getTapeDrive()

if not tape then
  io.stderr:write("No tape drive found.\n")
  return
end

if not tape.isReady() then
  io.stderr:write("Tape drive is present, but no tape inserted.\n")
  return
end

-- Display usage
local function printUsage()
  print("Usage:")
  print("  tape play")
  print("  tape pause")
  print("  tape stop")
  print("  tape rewind")
  print("  tape wipe")
  print("  tape label [name]")
  print("  tape speed <speed>")
  print("  tape volume <volume>")
  print("  tape write <file or URL>")
  print("Options:")
  print("  --b=<bytes>   Set chunk size")
  print("  --t=<timeout> Set network timeout (seconds)")
  print("  -y            Skip confirmation prompts")
end

-- Basic operations
local function play()
  if tape.getState() == "PLAYING" then
    print("Already playing.")
  else
    tape.play()
    print("Playback started.")
  end
end

local function pause()
  if tape.getState() == "STOPPED" then
    print("Already paused.")
  else
    tape.stop()
    print("Playback paused.")
  end
end

local function stop()
  if tape.getState() == "STOPPED" then
    print("Already stopped.")
  else
    tape.stop()
    tape.seek(-tape.getSize())
    print("Playback stopped and rewound.")
  end
end

local function rewind()
  tape.seek(-tape.getSize())
  print("Tape rewound.")
end

local function label(name)
  if not name then
    local l = tape.getLabel()
    print("Label: " .. (l == "" and "<none>" or l))
  else
    tape.setLabel(name)
    print("Label set to: " .. name)
  end
end

local function speed(sp)
  local s = tonumber(sp)
  if not s or s < 0.25 or s > 2.0 then
    io.stderr:write("Speed must be between 0.25 and 2.0\n")
    return
  end
  tape.setSpeed(s)
  print("Speed set to " .. s)
end

local function volume(vol)
  local v = tonumber(vol)
  if not v or v < 0 or v > 1 then
    io.stderr:write("Volume must be between 0.0 and 1.0\n")
    return
  end
  tape.setVolume(v)
  print("Volume set to " .. v)
end

local function confirm(msg)
  if options.y then return true end
  io.write(msg .. " [y/N]: ")
  local r = io.read()
  return r and r:lower():match("^y")
end

local function wipe()
  if not confirm("Wipe tape contents?") then return end
  tape.stop()
  tape.seek(-tape.getSize())
  local chunk = string.rep("\x00", 8192)
  for i = 1, tape.getSize(), 8192 do
    tape.write(chunk)
  end
  tape.seek(-tape.getSize())
  print("Tape wiped.")
end

local function writeTape(path)
  local blockSize = tonumber(options.b) or 2048
  local file
  local totalSize = tape.getSize()
  local fromInternet = path:match("^https?://")

  if not confirm("Write to tape? Existing contents will be overwritten.") then return end

  tape.stop()
  tape.seek(-totalSize)

  if fromInternet then
    if not component.isAvailable("internet") then
      io.stderr:write("No internet card available.\n")
      return
    end
    local internet = component.internet
    local handle, reason = internet.request(path)
    if not handle then
      io.stderr:write("Failed to connect: " .. reason .. "\n")
      return
    end
    local timeout = tonumber(options.t) or 5
    for i = 1, timeout * 10 do
      local connected = handle.finishConnect()
      if connected or connected == nil then break end
      os.sleep(0.1)
    end
    file = handle
  else
    local f, err = io.open(shell.resolve(path), "rb")
    if not f then
      io.stderr:write("File error: " .. err .. "\n")
      return
    end
    file = f
  end

  print("Writing to tape...")
  local written = 0
  while written < totalSize do
    local chunk = file:read(blockSize)
    if not chunk then break end
    if not tape.isReady() then
      io.stderr:write("Tape was removed during write.\n")
      break
    end
    tape.write(chunk)
    written = written + #chunk
    term.write(string.format("\r%d / %d bytes written...", written, totalSize))
  end

  if file.close then file:close() end
  tape.seek(-tape.getSize())
  print("\nWrite complete.")
end

-- Dispatch command
local cmd = args[1]
if cmd == "play" then play()
elseif cmd == "pause" then pause()
elseif cmd == "stop" then stop()
elseif cmd == "rewind" then rewind()
elseif cmd == "label" then label(args[2])
elseif cmd == "speed" then speed(args[2])
elseif cmd == "volume" then volume(args[2])
elseif cmd == "wipe" then wipe()
elseif cmd == "write" then writeTape(args[2])
else printUsage() end
