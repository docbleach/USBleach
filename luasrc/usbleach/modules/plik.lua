local usbleach = require "luci.usbleach"

--- @module luci.usbleach.modules.plik
local plik = {}

function plik.index()
    return { name = "Docbleach" }
end

function plik.pre_action_hook(t)
    local isEnabled = uci.cursor():get("usbleach", "main", "plik_enabled", {})
    if isEnabled ~= "on" then
        return
    end
    local shouldProcess = false
    if t.action == "email" and
            uci.cursor():get("usbleach", "main", "email_store_on_plik", "off") == "on" then
        shouldProcess = true
    end

    if shouldProcess == false then
        return
    end

    local file = t.file
    local plikLink = getPlikLink(file)
    if plikLink ~= "" then
        t.file = plikLink
        t.filestat = nil
    end
end

function getPlikLink(file)
    local plik_url = uci.cursor():get("usbleach", "main", "plik_url")
    local command = string.format("/usr/bin/plik.sh -q -t 6h -u %q -r %q", plik_url, file)
    return luci.util.trim(luci.sys.exec(command))
end

function plik.config(map)
    local s = map:section(luci.cbi.TypedSection, "usbleach", "Plik")
    s.addremove = false
    s.anonymous = true

    s:option(luci.cbi.DummyValue, "option", "", luci.i18n.translate("" ..
            "<a href=''>Plik</a> is a web service that allows you to host files and" ..
            "get a shareable link to them."))
    local enabled = s:option(luci.cbi.Flag, "plik_enabled", luci.i18n.translate("Enable"),
        luci.i18n.translate("Do you want to host your files on Plik?"))
    enabled.enabled = "on"
    enabled.disabled = "off"
    enabled.default = enabled.enabled
    enabled.rmempty = false

    local enabled = s:option(luci.cbi.Value, "plik_url", luci.i18n.translate("Plik Server"),
        luci.i18n.translate("What server should be used to host your files?"))
    enabled.default = "https://plik.root.gg"
    enabled.rmempty = false
end

return plik
