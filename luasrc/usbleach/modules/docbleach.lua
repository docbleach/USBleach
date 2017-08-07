local usbleach = require "luci.usbleach"

--- @module luci.usbleach.modules.docbleach
local docbleach = {}

local json = require "luci.json"

local officeFiles = {
    "doc", "docm", "docx", "dot", "dotm", "dox", "mpp", "mso", "msw", "oxps", "pdf", "pot", "potx", "pps", "ppsm",
    "ppt", "pptm", "pptx", "pub", "pwi", "rtf", "snp", "xls", "xlsm", "xlsx"
}

function docbleach.index()
    return { name = "Docbleach" }
end

function docbleach.pre_action_hook(t)
    local isEnabled = uci.cursor():get("usbleach", "main", "docbleach_enabled", {})
    if isEnabled ~= "on" then
        return
    end

    local filestat = t.filestat
    local file = t.file

    if not docbleach.is_office_file(file) then
        return
    end

    local exit_code, final_file, output

    if luci.usbleach.file_exists("/usr/bin/docbleach/Main") then
        exit_code, final_file, output = docbleach.clean_local(t.basename, file, filestat)
    else
        exit_code, final_file, output = docbleach.clean(file, filestat)
    end
    table.insert(t.infos, output)
    if exit_code == 0 then
        t.file = final_file
        t.filestat = nil
    end
end

function docbleach.is_office_file(filename)
    local ext = usbleach.get_extension(filename)
    return luci.util.contains(officeFiles, ext)
end

function docbleach.clean(file, filestat)
    if not filestat or filestat.type ~= "reg" then
        return "Not a regular file"
    end

    local output, exit_code = usbleach.run(string.format("/usr/bin/docbleach.sh %q 2>&1", file))
    if exit_code ~= 0 then
        return exit_code, file, ""
    end
    local jsonOutput = json.decode(output).result
    local final_file = jsonOutput.final_file
    local output = jsonOutput.output
    return 0, final_file, output
end

function docbleach.clean_local(basename, file, filestat)
    if not filestat or filestat.type ~= "reg" then
        return "Not a regular file"
    end

    local out_file = "/tmp/" .. luci.sys.uniqueid(10) .. "_" .. basename

    local output, exit_code = usbleach.run(string.format("/usr/bin/docbleach/Main -batch -in - -out %q 2>&1 < %q", out_file, file))
    nixio.fs.chown(out_file, 770)
    return exit_code, out_file, output
end

function docbleach.config(map)
    local s = map:section(luci.cbi.TypedSection, "usbleach", "DocBleach")
    s.addremove = false
    s.anonymous = true

    s:option(luci.cbi.DummyValue, "option", "", luci.i18n.translate("<a href=''>DocBleach</a> is an utility that sanitizes your PDFs and Office documents.<br>" ..
            "This process might be done in the cloud or directly on this device, depending on whether or not you have installed it."))
    local enabled = s:option(luci.cbi.Flag, "docbleach_enabled", luci.i18n.translate("Enable"),
        luci.i18n.translate("Do you want to enable docbleach? If you do, PDFs and Office Documents will be sanitized before actions (download, email, ...) are taken on them."))
    enabled.enabled = "on"
    enabled.disabled = "off"
    enabled.default = enabled.enabled
    enabled.rmempty = false
end

return docbleach
