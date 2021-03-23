require "lfs"

infiles = {}
fileindex = 0
for f in lfs.dir(".") do
  if f:match(".woz$") then
    infiles[#infiles + 1] = f
  end
end
table.sort(infiles)

function calc(line)
  return line % 8 * 1024 + math.floor(line / 64) * 40 + math.floor((line%64) / 8) * 128 + 8192
end

function textcalc(line)
  return calc(line * 8) - 8192 + 0x0400
end

function striphibitstring(a)
  local b = ""
  for i = 1, string.len(a) do
    b = b .. string.char(a:byte(i) & 0x7f)
  end
  return b
end

mainmem = emu.item(manager.machine.devices[":ram"].items["0/m_pointer"])  -- always gets main memory
function getscreenline(i)
  return striphibitstring(mainmem:read_block(textcalc(i), 40))
end

function getscreen()
  local b = ""
  for i = 0, 23 do
    b = b .. getscreenline(i) .. "\n"
  end
  return b
end

function savescreen(outfile)
  local h = io.open(outfile, "w")
  h:write(getscreen())
  h:close()
end

function createblankdsk(outfile)
  local h = io.open(outfile, "wb")
  for i = 1, 143360 do
    h:write(0x00)
  end
  h:close()
end

state = "waiting_for_main_menu"
function driver()
  if state == "waiting_for_main_menu" then
    if getscreen():match("rack disk") then
      fileindex = fileindex + 1
      if fileindex > #infiles then
        manager.machine:exit()
        return
      end
      dsk, subcount = infiles[fileindex]:gsub(".woz$", ".dsk")
      if subcount == 0 then
        print("ERROR unable to parse filename")
        return
      end
      print(infiles[fileindex])
      createblankdsk(dsk)
      manager.machine.images[":sl6:diskiing:0:525"]:load(infiles[fileindex])
      manager.machine.images[":sl6:diskiing:1:525"]:load(dsk)
      emu.keypost("C")
      state = "waiting_for_process"
    end
  end
  if state == "waiting_for_process" then
    if getscreen():match("Press any key") then
      log, subcount = infiles[fileindex]:gsub(".woz$", ".log")
      savescreen(log)
      emu.keypost(" ")
      state = "waiting_for_main_menu"
    end
  end
end

;manager.machine.video.frameskip = 10
;manager.machine.video.throttled = false
emu.register_frame_done(driver)
