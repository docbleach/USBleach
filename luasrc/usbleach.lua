module("luci.usbleach", package.seeall)

local fs = require "nixio.fs"
local util = require "luci.util"

function prettysize(bytes)
    if bytes < 1000 then return string.format("%.2f", bytes) .. "o" end
    if bytes < 1000 * 1000 then return string.format("%.2f", bytes / 1024) .. "Ko" end
    if bytes < 1000 * 1000 * 1000 then return string.format("%.2f", bytes / 1024 / 1024) .. "Mo" end
    return (bytes / 1024 / 1024 / 1024) .. "Go"
end

function get_mountdirs()
    local mounts = scandir("/var/run/usbleach/mount-for-dev/")
    local mountDirs = {}
    for _, file in ipairs(mounts) do
        local mount_dir = util.trim(fs.readfile("/var/run/usbleach/mount-for-dev/" .. file, 1024))
        if mount_dir ~= nil then
            mountDirs[file] = mount_dir
        end
    end
    return mountDirs
end

function get_mount_dir(device)
    return util.trim(fs.readfile("/var/run/usbleach/mount-for-dev/" .. device, 1024))
end

function generate_usb_tree()
    local mounts = get_mountdirs()
    local devices = {}

    for device, _ in pairs(mounts) do
        local device_name = string.match(device, "(%a+)")
        devices[device_name] = luci.util.trim(luci.sys.exec("readlink -f /sys/block/" .. device_name .. "/dev"))
    end


    local lsusb = luci.sys.exec("/usr/bin/usbleach_lsusb.sh"):split("\n")
    local lastLevel
    local outString = ""
    for _, line in ipairs(lsusb) do
        if line ~= "" then
            local type = line:sub(1, 1)
            if type == "T" then
                local device, level, class, subclass, protocol, vendor, product = string.match(line, "^T:  Dev=(.+) Lev=(%d+) Cls=(%x+) Sub=(%x+) Prot=(%d+) Vendor=(%x+) ProdID=(%x+)")

                level = tonumber(level)

                if lastLevel == nil then
                elseif lastLevel == level then
                    outString = outString .. "</ul></li>\n"
                elseif level > lastLevel then
                    outString = outString .. "</ul><ul>"
                elseif level < lastLevel then
                    outString = outString .. string.rep("</ul></li>\n", lastLevel - level + 1)
                end
                lastLevel = level

                local classes = "usbleach_class_" .. class .. " usbleach_subclass_" .. subclass ..
                        " usbleach_vendor_" .. vendor .. " usbleach_product_" .. product

                local desc = get_usb_class_label(class, subclass, protocol)

                if class == "00" and subclass == "00" then -- Display product informations for devices
                    local manufacturer, product = "", ""

                    if file_exists(device .. "/manufacturer") then
                        manufacturer = luci.sys.exec("cat " .. device .. "/manufacturer")
                    end

                    if file_exists(device .. "/product") then
                        product = luci.sys.exec("cat " .. device .. "/product")
                    end

                    desc = desc .. " <span>" .. manufacturer .. " &mdash; <b>" .. product .. "</b></span>"
                end
                outString = outString .. "<li class='" .. classes .. "'>" .. desc .. "<ul>"
            elseif type == "I" then
                local device, class, subclass, protocol = string.match(line, "^I:  Dev=(.+) Cls=(%x+) Sub=(%x+) Prot=(%d+)")
                if class ~= "09" then
                    local desc = get_usb_class_label(class, subclass, protocol)
                    if class == "08" then
                        local device_path = string.gsub(device, "/sys/bus/usb/devices/", "")
                        for dev, path in pairs(devices) do
                            if string.find(path, device_path, 1, true) then
                                desc = desc .. "<ul>"
                                for _device, _ in pairs(mounts) do
                                    if string.sub(_device, 1, string.len(dev)) == dev then
                                        local label = get_label(_device)
                                        if #label <= 1 then label = "-" end
                                        local link = luci.dispatcher.build_url("admin", "usbleach", "browse", _device)
                                        desc = desc .. "<li><a href='" .. link .. "'><i class='ico-hdd'></i> <b>" .. label .. "</b> (" .. _device .. "/)</a></li>"
                                    end
                                end
                                desc = desc .. "</ul>"
                            end
                        end
                    end
                    outString = outString .. "<li class='usbleach_class_" .. class .. " usbleach_subclass_" .. subclass .. "'>" .. desc .. "</li>\n"
                end
            end
        end
    end
    if lastLevel ~= nil then
        outString = outString .. string.rep("</ul></li>", lastLevel + 1)
    end
    outString = string.gsub(outString, "<ul></ul>", "")
    return outString
end

function has_device(device)
    return file_exists("/var/run/usbleach/mount-for-dev/" .. device)
end

function scandir(directory)
    local i, t = 0, {}
    local files = nixio.fs.dir(directory)
    if files == nil then
    	return t
    end
    for filename in files do
        i = i + 1
        t[i] = filename
    end
    return t
end

function file_exists(name)
    local f = io.open(name, "r")
    if f ~= nil then io.close(f) return true else return false end
end

function hex_dump(str)
    local len = string.len(str)
    local dump = ""
    local hex = ""
    local asc = ""

    for i = 1, len do
        if 1 == i % 8 then
            dump = dump .. hex .. asc .. "\n"
            hex = string.format("%04x: ", i - 1)
            asc = ""
        end

        local ord = string.byte(str, i)
        hex = hex .. string.format("%02x ", ord)
        if ord >= 32 and ord <= 126 then
            asc = asc .. string.char(ord)
        else
            asc = asc .. "."
        end
    end

    return dump .. hex
            .. string.rep(" ", 8 - len % 8) .. asc
end

function get_label(device)
    return util.trim(luci.sys.exec("blkid -s LABEL -o value /dev/" .. device))
end

function get_modules()
    local controllers = {}
    local modules = {}
    local base = "%s/usbleach/modules" % luci.util.libpath()
    local _, path

    for path in (nixio.fs.glob("%s*/*.lua" % base) or function() end) do
        controllers[#controllers + 1] = path
    end
    for _, path in ipairs(controllers) do
        --~ -4 stands for .lua
        local modname = "luci.usbleach.modules" .. path:sub(#base + 1, #path - 4):gsub("/", ".")
        local mod = require(modname)
        assert(mod ~= true,
            "Invalid controller file found\n" ..
                    "The file '" .. path .. "' contains an invalid module line.\n" ..
                    "Please verify whether the module name is set to '" .. modname ..
                    "' - It must correspond to the file path!")

        local idx = mod.index
        assert(type(idx) == "function",
            "Invalid module file found\n" ..
                    "The file '" .. path .. "' contains no index() function.\n" ..
                    "Please make sure that the module contains a valid " ..
                    "index function and verify the spelling!")
        modules[modname] = mod
    end
    return modules
end

function is_module_available(name)
    if package.loaded[name] then
        return true
    else
        for _, searcher in ipairs(package.searchers or package.loaders) do
            local loader = searcher(name)
            if type(loader) == 'function' then
                package.preload[name] = loader
                return true
            end
        end
        return false
    end
end

function acquire_session(device)
    if uci.cursor():get("usbleach", "main", "only_one_user", {}) ~= "on" then
        return true
    end

    local session = luci.http.getcookie('usbleach_token')

    if session == nil then
        session = luci.sys.uniqueid(17)
        luci.http.header("Set-Cookie", 'usbleach_token=%s; path=%s; HttpOnly' % { session, luci.dispatcher.build_url() })
    end

    local lock_path = "/tmp/usbleach/" .. device .. "/" .. "session"

    if file_exists(lock_path) then
        local lockTime = fs.stat(lock_path, "ctime") or 0
        if lockTime <= (os.time() - (60 * 60)) then
            nixio.fs.unlink(lock_path)
        end
    end

    -- If this device is not yet locked, we are free to lock it for this session
    if not file_exists(lock_path) then
        -- PUT
        nixio.fs.writefile(lock_path, session)
        return true
    end

    -- Here, file does not exist. We assert that the session is the right one
    local content = nixio.fs.readfile(lock_path) or ""
    return content == session
end

function get_extension(filename)
    if filename == nil then return "" end
    return string.match(string.lower(filename), ".-[^\\]-%.([^\\/%.]+)$") or ""
end

function is_whitelisted(filename)
    local cursor = uci.cursor()
    if cursor:get("usbleach", "main", "use_whitelist", {}) ~= "on" then
        return true
    end

    local ext = get_extension(filename)
    if ext == "" and cursor:get("usbleach", "main", "allow_no_ext", "off") ~= "off" then
        return true
    end

    local whitelisted_ext = cursor:get_list("usbleach", "main", "ext_whitelist", {})

    for _, v in pairs(whitelisted_ext) do
        if v == ext then
            return true
        end
    end
    return false
end

-- function run execute a program
-- return stdout and status code
function run(command)
    local handle = io.popen(command)
    local result = handle:read("*a")
    local rc = { handle:close() }
    return result, rc[4]
end

function get_usb_class_label(class, subclass, protocol)
    if class == "01" then
        return "<i class='ico-keyboard'></i> Audio"
    elseif class == "02" then
        return "<i class='ico-keyboard'></i> COM"
    elseif class == "03" then
        if protocol == "01" then
            return "<i class='ico-keyboard'></i> Keyboard"
        elseif protocol == "02" then
            return "<i class='ico-mouse-pointer'></i> Mouse"
        end
        return "<i class='ico-keyboard'></i> HID (?)"
    elseif class == "05" then
        return "<i class='ico-keyboard'></i> Joystick"
    elseif class == "06" then
        return "<i class='ico-camera'></i> Webcam"
    elseif class == "07" then
        return "<i class='ico-print'></i> Printer"
    elseif class == "08" then
        return "<i class='ico-hdd'></i> Mass Storage"
    elseif class == "09" then
        return "<i class='ico-usb'></i> USB Hub"
    elseif class == "0A" then
        return "<i class='ico-archive'></i> COM"
    elseif class == "0C" then
        return "<i class='ico-id-card-o'></i> Smart card reader"
    elseif class == "0D" then
        return "<i class='ico-up-hand'></i> Fingerprint reader"
    elseif class == "0E" then
        return "<i class='ico-camera'></i> Webcam"
    elseif class == "0F" then
        return "<i class='ico-heartbeat'></i> Healthcare (Pulse monitor)"
    elseif class == "10" then
        return "<i class='ico-play'></i> Audio/Video"
    elseif class == "11" then
        return "<i class='ico-desktop'></i> Billboard"
    elseif class == "DC" then
        return "<i class='ico-bug'></i> Diagnostic Device"
    elseif class == "E0" then
        return "<i class='ico-wifi'></i> Wireless Controller"
    elseif class == "EF" then
        return "<i class='ico-arrows-cw'></i> ActiveSync device"
    elseif class == "FE" then
        return "<i class='ico-help-circled'></i> Application-specific"
    elseif class == "FF" then
        return "<i class='ico-help-circled'></i> Vendor-specific (needs drivers)"
    end
    return "<i class='ico-usb'></i> Peripherals"
end