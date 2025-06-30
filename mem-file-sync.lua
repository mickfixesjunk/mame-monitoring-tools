local log_file_path = "memory_access.log"
local max_log_size = 500 * 1024 * 1024  -- 50 MB
local frame_counter = 0
local delay_frames = 60  -- 65 seconds at 60 FPS
local logger_enabled = false

-- Attempt to open the log file for writing
local log_file = io.open(log_file_path, "w")
if log_file == nil then
    error(string.format("Failed to open log file at path: %s. Please check the path and permissions.", log_file_path))
end

local main_cpu_name = nil
-- Identify the CPU automatically
for device_name, device in pairs(manager.machine.devices) do
    if device_name:find("cpu") then
        main_cpu_name = device_name
        print(string.format("Using device: %s", main_cpu_name))  -- Print to console instead of logging to file
        break
    end
end

if main_cpu_name == nil then
    error("No CPU found for memory access")
end

-- Function to save a snapshot
local function save_frame_snapshot()
    local filename = string.format("frames/%05d.png", frame_counter) -- e.g., frames/00001.png
    local screen = manager.machine.screens[":screen"]
    if screen then
        screen:snapshot(filename)
    else
        print("No screen found in the current machine.")
    end
end

-- Get the program memory space for the identified CPU
local main_cpu = manager.machine.devices[main_cpu_name]
local mem_space = manager.machine.devices[main_cpu_name].spaces["program"]

if mem_space == nil then
    error(string.format("Program memory space for device %s not found", main_cpu_name))
end

-- Get the screen device to access the frame number
local screen = manager.machine.screens["screen"]
if screen == nil then
    error("No screen device found")
end

-- Function to write to the log and handle log rollover
local write_buffer = {}
local buffer_size = 5000  -- Buffer size for batching log writes

local function write_to_log(data)
    if log_file == nil then
        error("Log file is not open. Unable to write data.")
    end
    table.insert(write_buffer, data)
    if #write_buffer >= buffer_size then
        log_file:write(table.concat(write_buffer))
        write_buffer = {}  -- Clear buffer after writing
    end
    --if frame_counter % 6000 == 0 then
    log_file:flush()
    --end

    -- Check if the log file exceeds the maximum size and rotate if necessary
    local file_size = log_file:seek("end")
    if file_size > max_log_size then
        log_file:close()
        local backup_file_path = log_file_path .. ".backup"
        os.remove(backup_file_path)  -- Remove the old backup file if it exists
        os.rename(log_file_path, backup_file_path)  -- Rename current log file to backup
        log_file = io.open(log_file_path, "w")  -- Create a new log file
        if log_file == nil then
            error(string.format("Failed to open new log file at path: %s.", log_file_path))
        end
    end
end

-- Function to determine size based on mem_mask
local function determine_size(mem_mask)
    local size = 0
    -- Iterate over each byte in the mask to determine the size
    while mem_mask > 0 do
        if (mem_mask & 0xFF) ~= 0 then
            size = size + 1
        end
        mem_mask = mem_mask >> 8
    end
    return size
end

-- Callback function for memory write
local function on_memory_write(address, value, mem_mask)

    if logger_enabled then 
        local current_frame1 = screen:frame_number()
        local pc = main_cpu.state["CURPC"].value
        local size = determine_size(mem_mask)
        --local instruction = cpu.disassemble(pc)
        local old_value = 0 --mem_space:read_u8(offset)  -- Assuming an 8-bit read before writing
        local log_entry = string.format(
            "%d,W,%X,%X,%d,%X,%X",
            current_frame1, address, value, size, pc, mem_mask
        )
        write_to_log(log_entry .. "\n")
    end
end

-- Callback function for memory read
local function on_memory_read(address, value, mem_mask)
    
    if logger_enabled then 
        local size = determine_size(mem_mask)
        local current_frame1 = screen:frame_number()
        local pc = main_cpu.state["CURPC"].value

        --local instruction = main_cpu.disassemble(pc)
        --rint("4")
        --print(string.format("4-DEBUG: frame=%s, offset=%s, value=%s, size=%s, pc=%s, mem_mask=%X", tostring(current_frame1), tostring(address), tostring(value), tostring(size), tostring(pc), mem_mask))

        local old_value = 0 -- mem_space:read_u8(address)  -- Assuming an 8-bit read
        --print(string.format("5-DEBUG: frame=%d, offset=%X, value=%X, size=%d, pc=%X, old_value=%d, mem_mask=%X", current_frame1, address, value, size, pc, old_value, mem_mask))

        --print("5")

        local log_entry = string.format(
            "%d,R,%X,%X,%d,%X,%X",
            current_frame1, address, value, size, pc, mem_mask
        )

        write_to_log(log_entry .. "\n")
    end
end

-- Function to set memory taps
local function set_memory_taps()

    if logger_enabled then 
        print("Setting memory read and write taps...")
        passthrough_read = mem_space:install_read_tap(0x000000, 0xFFFFFF, "reads", on_memory_read)
        passthrough_write = mem_space:install_write_tap(0x000000, 0xFFFFFF, "writes", on_memory_write)
    end
end

set_memory_taps()

-- Register a frame done callback to manage log buffer flushes and reinstall taps if necessary
emu.register_frame_done(function()

    frame_counter = screen:frame_number()

    if logger_enabled then
        save_frame_snapshot()
    end

    -- Detect the CTRL+SHIFT+D key combination to toggle logging on/off
    local ctrl_shift_d_pressed = manager.machine.input:seq_pressed(manager.machine.input:seq_from_tokens("KEYCODE_LCONTROL KEYCODE_LSHIFT KEYCODE_D"))
    if ctrl_shift_d_pressed and not logger_toggle_debounced then
        -- Toggle the logger state
        logger_enabled = not logger_enabled
        print("hypertracing " .. (logger_enabled and "enabled" or "disabled"))

        -- Stop the previous trace (if it's running)
        manager.machine.debugger:command('trace off')

        if logger_enabled then
            -- Manually construct the trace command string
            local frame_str = "frame=" .. tostring(frame_counter)  -- Convert the frame number to a string
            local trace_command = 'trace ./instructions/'.. tostring(frame_counter) ..'.log,,noloop,{ tracelog "' .. frame_str .. ' D0=%x D1=%x D2=%x D3=%x D4=%x D5=%x D6=%x D7=%x A0=%x A1=%x A2=%x A3=%x A4=%x A5=%x A6=%x PC=%x -- ",d0,d1,d2,d3,d4,d5,d6,d7,a0,a1,a2,a3,a4,a5,a6,pc }'

            -- Execute the trace command
            manager.machine.debugger:command(trace_command)
        end
        -- Set debounce flag to true to avoid repeated toggling
        logger_toggle_debounced = true
    elseif not ctrl_shift_d_pressed then
        -- Reset debounce flag when the keys are released
        logger_toggle_debounced = false
    end

    -- Skip processing if the emulator is paused
    if manager.machine.paused then
        return
    end

    -- Update trace command each frame if logging is enabled
    if logger_enabled then
        -- Stop the previous trace (if it's running)
        manager.machine.debugger:command('trace off')

        -- Construct the new trace command with the current frame number
        local frame_str = "frame=" .. tostring(frame_counter)
        local trace_command = 'trace ./instructions/'.. tostring(frame_counter) ..'.log,,noloop,{ tracelog "' .. frame_str .. ' D0=%x D1=%x D2=%x D3=%x D4=%x D5=%x D6=%x D7=%x A0=%x A1=%x A2=%x A3=%x A4=%x A5=%x A6=%x PC=%x -- ",d0,d1,d2,d3,d4,d5,d6,d7,a0,a1,a2,a3,a4,a5,a6,pc }'

        -- Start the trace again with the updated frame number
        manager.machine.debugger:command(trace_command)
    end

    -- Flush the buffer to the log file every frame
    if #write_buffer > 0 then
        log_file:write(table.concat(write_buffer))
        write_buffer = {}
    end

    -- Reinstall memory taps every 60 frames
    if frame_counter % 60 == 0 then
        set_memory_taps()
    end
end)

