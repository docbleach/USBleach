module("luci.controller.usbleach.main", package.seeall)

--~ This module should not depend on fs

local usbleach = require "luci.usbleach"

function index()
    local e
    e = entry({ "admin", "usbleach" }, firstchild(), "USBleach", 20)
    e.index = true
    e.sysauth = false
    e.target = alias("admin", "usbleach", "overview")

    e = entry({ "admin", "usbleach", "overview" }, call("action_intro"), "Overview", 1)
    e.sysauth = false

    e = entry({ "admin", "usbleach", "browse" }, call("action_browse"), "Navigation - USBleach")
    e.leaf = true
    e.hidden = true
    e.sysauth = false

    e = entry({ "admin", "usbleach", "action" }, call("action_action"))
    e.hidden = true
    e.leaf = true
    e.sysauth = false

    e = entry({ "admin", "usbleach", "mkdir" }, call("action_mkdir"))
    e.hidden = true
    e.leaf = true
    e.sysauth = false

    e = entry({ "admin", "usbleach", "upfile" }, call("action_upfile"))
    e.hidden = true
    e.leaf = true
    e.sysauth = false

    local e = entry({ "admin", "usbleach", "config" }, cbi("usbleach/config"), "Configuration", 3)
    e.dependent = false
    e.sysauth = "root"
    e.sysauth_authenticator = "htmlauth"
end

function action_intro()
    if luci.http.formvalue("ajax") ~= nil then
        luci.http.write_json({ usb = usbleach.generate_usb_tree() })
        return
    end
    luci.template.render("usbleach/index", {
        usbleach = usbleach,
        myMounts = usbleach.generate_usb_tree()
    })
end

function action_browse() --~ Should be sda1/ or sda1/some/long/path/here/...
    local request = luci.dispatcher.context.args
    if request == nil or #request == 0 then
        return luci.dispatcher.error404("Device & path not specified!")
    end

    local path = {}
    local device
    for i = 1, #request do
        if request[i] ~= ".." and #request[i] > 0 then
            if device == nil then
                device = request[i]
            else
                path[#path + 1] = request[i]
            end
        end
    end

    if not usbleach.has_device(device)
    then
        return luci.template.render("usbleach/notfound", { device = device })
    end

    if not usbleach.acquire_session(device) then
        return locked(device)
    end

    local mount_dir = usbleach.get_mount_dir(device) .. "/"
    local deviceid = nixio.fs.stat(mount_dir, "dev")

    local filepath = table.concat(path, "/")
    local filestat = nixio.fs.stat(mount_dir .. filepath)

    if filestat and filestat.type == "reg" then
        table.remove(path, #path)
        filepath = table.concat(path, "/") .. "/"
    elseif not (filestat and filestat.type == "dir") then
        path = { "" }
        filepath = "/"
    else
        filepath = filepath .. "/"
    end

    local baseurl = luci.dispatcher.build_url("admin", "usbleach", "browse", device) .. "/" .. filepath

    local actionurl = luci.dispatcher.build_url("admin", "usbleach", "action", device) .. "/" .. filepath

    local entries = nixio.util.consume(nixio.fs.dir(mount_dir .. filepath))

    --~ Yara rules
    local yara_completed = not usbleach.file_exists("/tmp/usbleach/" .. device .. "/yara_processing")
    local yara_content = {}
    local yara_flagged = {}
    if usbleach.file_exists("/tmp/usbleach/" .. device .. "/yara") then
        local fh, err = io.open("/tmp/usbleach/" .. device .. "/yara")
        if err then print("Oops"); return; end

        while true do
            local line = fh:read("*line")
            if line == nil then break end
            local filter, tag, file = string.match(line, "(.+) %[(.+)%] (.+)")
            if file == nil then break end
            yara_content[#yara_content + 1] = { filter = filter, tag = tag, file = file }
            yara_flagged[file] = 1
        end
        fh:close()
    end

    luci.template.render("usbleach/browse", {
        deviceid = deviceid,
        device = device,
        label = usbleach.get_label(device),
        mount_point = mount_dir,
        yara_completed = yara_completed,
        yara_content = yara_content,
        yara_flagged = yara_flagged,
        entries = entries,
        filepath = mount_dir .. "/" .. filepath,
        relative_filepath = filepath,
        baseurl = baseurl,
        actionurl = actionurl,
        path = path,
        usbleach = usbleach
    })
end

function action_action(device)
    local action = luci.http.formvalue("action")
    if action == nil or #action < 1 then
        return luci.dispatcher.error404('?? action not given')
    end

    local request = luci.dispatcher.context.args
    if request == nil or #request == 0 then
        return luci.dispatcher.error404("Device & path not specified!")
    end

    if not usbleach.has_device(device)
    then
        return luci.template.render("usbleach/notfound", { device = device })
    end

    if not usbleach.acquire_session(device) then
        return locked(device)
    end

    local mount_dir = usbleach.get_mount_dir(device)
    local deviceid = nixio.fs.stat(mount_dir, "dev")

    local file = mount_dir .. luci.http.formvalue("file")
    local filestat = nixio.fs.stat(file)

    if filestat.dev ~= deviceid then --~ Prevent symlinks from accessing other partitions
        return luci.dispatcher.error404("Wrong device id (hack attempt?!)")
    end


    local basename = nixio.fs.basename(file)
    if not usbleach.is_whitelisted(basename) then
        return luci.dispatcher.error404("Download forbidden for this file type.")
    end

    local module = "luci.usbleach.modules." .. action
    local actionHandler = require(module)
    if not actionHandler.act then
        return luci.dispatcher.error404("No act method defined in " .. module)
    end

    local data = {
        action = action,
        device = device,
        file = file,
        basename = basename,
        filestat = filestat,
        infos = {}
    }

    local modules = luci.usbleach.get_modules()
    for _, mod in pairs(modules) do
        if mod.pre_action_hook ~= nil then
            local mod_return = mod.pre_action_hook(data)
            if mod_return ~= nil then
                return mod_return
            end
        end
    end

    local result = actionHandler.act(data)

    local modules = luci.usbleach.get_modules()
    for _, mod in pairs(modules) do
        if mod.post_action_hook ~= nil then
            mod.post_action_hook(data)
        end
    end

    if result ~= nil then
        if type(result) == "table" then
            luci.http.prepare_content("application/json")
            luci.http.write_json(result)
            return
        end
        luci.http.prepare_content("text/html")
        luci.http.write(result)
    end
end

function locked(device)
    return luci.template.render("usbleach/locked", { device = device })
end

function action_upfifdsdsfdsffdsfdsfdle()
    local tmp_file = luci.sys.uniqueid(32)
    nixio.fs.mkdir("/www/usbleach/docbleach/")
    nixio.fs.mkdir("/www/usbleach/docbleach/" .. tmp_file)

    local filestat = nixio.fs.stat(upload_tmp)
    local out_file = "/usbleach/docbleach/" .. tmp_file .. "/" .. filename
    local output, exit_code = docbleach.clean(upload_tmp, filestat, "/www" .. out_file)
    nixio.fs.unlink(upload_tmp)

    local data = {
        action = "docbleach",
        device = "-",
        file = tmp_file,
        basename = filename,
        filestat = filestat,
        infos = { output }
    }

    local modules = luci.usbleach.get_modules()
    for _, mod in pairs(modules) do
        if mod.post_action_hook ~= nil then
            mod.post_action_hook(data)
        end
    end

    if exit_code ~= 0 then
        luci.http.write_json({
            errors = { "SEVERE Non 0 exit code: " .. exit_code, output }
        })
        return
    end

    luci.http.write_json({
        link = out_file,
        infos = { output }
    })
end


function action_mkdir()
    local request = luci.dispatcher.context.args
    if request == nil or #request == 0 then
        return luci.dispatcher.error404("Device & path not specified!")
    end

    local path = {}
    local device
    for i = 1, #request do
        if request[i] ~= ".." and #request[i] > 0 then
            if device == nil then
                device = request[i]
            else
                path[#path + 1] = request[i]
            end
        end
    end

    if not usbleach.has_device(device)
    then
        return luci.template.render("usbleach/notfound", { device = device })
    end

    if not usbleach.acquire_session(device) then
        return locked(device)
    end

    local mount_dir = usbleach.get_mount_dir(device) .. "/"

    local filepath = table.concat(path, "/")
    local filestat = nixio.fs.stat(mount_dir .. filepath)

    if filestat and filestat.type == "reg" then
        table.remove(path, #path)
        filepath = table.concat(path, "/") .. "/"
    elseif not (filestat and filestat.type == "dir") then
        path = { "" }
        filepath = "/"
    else
        filepath = filepath .. "/"
    end

    local filestat = nixio.fs.stat(mount_dir .. filepath)
    if not filestat or filestat.type ~= "dir" then
        return
    end

    local dir = luci.http.formvalue("dir")
    local fullpath = mount_dir .. filepath .. "/" .. dir
    if string.match(dir, "/") then
        return
    end
    nixio.fs.mkdir(fullpath)
    luci.http.prepare_content("application/json")
    luci.http.write_json({ result = "ok" })
end

function action_upfile()
    local request = luci.dispatcher.context.args
    if request == nil or #request == 0 then
        return luci.dispatcher.error404("Device & path not specified!")
    end

    local path = {}
    local device
    for i = 1, #request do
        if request[i] ~= ".." and #request[i] > 0 then
            if device == nil then
                device = request[i]
            else
                path[#path + 1] = request[i]
            end
        end
    end

    if not usbleach.has_device(device)
    then
        return luci.template.render("usbleach/notfound", { device = device })
    end

    if not usbleach.acquire_session(device) then
        return locked(device)
    end

    local mount_dir = usbleach.get_mount_dir(device) .. "/"

    local filepath = table.concat(path, "/")
    local filestat = nixio.fs.stat(mount_dir .. filepath)

    if filestat and filestat.type == "reg" then
        table.remove(path, #path)
        filepath = table.concat(path, "/") .. "/"
    elseif not (filestat and filestat.type == "dir") then
        path = { "" }
        filepath = "/"
    else
        filepath = filepath .. "/"
    end

    local filestat = nixio.fs.stat(mount_dir .. filepath)
    if not filestat or filestat.type ~= "dir" then
        return
    end

    local fp, content_type, filename, upload_dest
    luci.http.setfilehandler(function(meta, chunk, eof)
        if not fp and meta and meta.name == "file" then
            filename = meta.file
            if string.match(filename, "/") then
                return
            end
            upload_dest = mount_dir .. filepath .. "/" .. filename
            fp = io.open(upload_dest, "w")
        end
        if fp and chunk then
            fp:write(chunk)
        end
        if fp and eof then
            fp:close()
        end
    end)
    luci.http.formvalue("file") -- Parse the uploaded file


    if fp then
        luci.http.prepare_content("application/json")
        luci.http.write_json({ result = "ok" })
    end
end