module("luci.controller.usbleach.docbleach", package.seeall)

--~ This module should not depend on fs

local docbleach = require "luci.usbleach.modules.docbleach"

function index()
    local e

    e = entry({ "admin", "usbleach", "docbleach" }, call("action_docbleach"), "DocBleach", 2)
    e.sysauth = false
    e.dependent = false
end

function action_docbleach()
    local unique_id = luci.sys.uniqueid(16)
    local upload_tmp = "/tmp/docbleach_" .. unique_id

    local fp, content_type, filename
    luci.http.setfilehandler(function(meta, chunk, eof)
        if not fp and meta and meta.name == "media" then
            fp = io.open(upload_tmp, "w")
            filename = meta.file
            content_type = meta.headers["Content-Type"] or ""
        end
        if fp and chunk then
            fp:write(chunk)
        end
        if fp and eof then
            fp:close()
        end
    end)

    if luci.http.getenv("REQUEST_METHOD") ~= "POST" then
        luci.template.render("usbleach/docbleach")
        return
    end

    luci.http.formvalue("media") -- Parse the uploaded file

    if filename == nil then
        return luci.dispatcher.error404("No files sent??")
    end

    if not docbleach.is_office_file(filename) then
        nixio.fs.unlink(upload_tmp)
        luci.http.write_json({ errors = { "This file is not an Office document." } })
        return
    end

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