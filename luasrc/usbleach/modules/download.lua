local usbleach = require "luci.usbleach"

--- @module luci.usbleach.modules.download
local download = {}

function download.index()
    return { name = "Download" }
end

function download.act(t)
    local filestat = t.filestat
    local file = t.file

    if file:sub(1, 7) == "http://" or file:sub(1, 8) == "https://" then
        return { infos = t.infos, link = file }
    end

    local basename = t.basename

    if filestat and filestat.type ~= "reg" then
        return luci.dispatcher.error404("?? not a regular file")
    end

    local tmpfile = luci.sys.uniqueid(6)
    nixio.fs.mkdir("/www/usbleach/")
    nixio.fs.mkdir("/www/usbleach/" .. t.device)
    nixio.fs.mkdir("/www/usbleach/" .. t.device .. "/" .. tmpfile)
    nixio.fs.symlink(file, "/www/usbleach/" .. t.device .. "/" .. tmpfile .. "/" .. basename)
    return { infos = t.infos, link = "/usbleach/" .. t.device .. "/" .. tmpfile .. "/" .. basename }
end

return download