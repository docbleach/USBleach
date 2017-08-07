local usbleach = require "luci.usbleach"

local m = Map("usbleach", translate("USBleach"), translate("It knows USB, and even laundry!"))
local s = m:section(TypedSection, "usbleach", "General")
s.addremove = false
s.anonymous = true

local enabled = s:option(Flag, "enabled", translate("Enable"),
    translate("Do you want to enable USBleach?"))
enabled.enabled = "on"
enabled.disabled = "off"
enabled.default = enabled.enabled
enabled.rmempty = false

local yara = s:option(Flag, "yarascan", translate("Use Yara-Rules?"),
    translate("When enabled, <a target='_blank' href='https://virustotal.github.io/yara/'>yara rules</a> will be used to scan your files, highlighting the files matched in the file browser."))
yara.enabled = "on"
yara.disabled = "off"
yara.default = yara.enabled
yara.rmempty = false

local only_one_user = s:option(Flag, "only_one_user", translate("Enforce single user per partition"),
    translate("Only one browser session will be allowed to access the files. Useful when USBleach is used as a shared platform."))
only_one_user.enabled = "on"
only_one_user.disabled = "off"
only_one_user.default = only_one_user.enabled
only_one_user.rmempty = false

local use_whitelist = s:option(Flag, "use_whitelist", translate("Disallow extensions that are not whitelisted"),
    translate("Prevents users from interacting with file types that are not allowed."))
use_whitelist.enabled = "on"
use_whitelist.disabled = "off"
use_whitelist.default = use_whitelist.enabled
use_whitelist.rmempty = false


local allow_no_ext = s:option(Flag, "allow_no_ext", translate("Allow actions on extensionless files"), translate("Only effective if the whitelist option is enabled. Prevents users from downloading files that don't have an extension (linux programs, ...)"))
allow_no_ext.optional = false
allow_no_ext.enabled = "on"
allow_no_ext.disabled = "off"
allow_no_ext.default = allow_no_ext.enabled
allow_no_ext:depends("use_whitelist", "on")

local ext_whitelist = s:option(DynamicList, "ext_whitelist", translate("Extensions à autoriser"), translate("Only effective if the whitelist option is enabled. i.e. to allow office documents, add these: <code>doc</code>, <code>xls</code> ..."))
ext_whitelist.optional = false
ext_whitelist.datatype = string
ext_whitelist.placeholder = "docx"

-- ext_whitelist:depends("use_whitelist", "on")
-- -- DO NOT DO THIS, when used, the dynamic list is erased if use_whitelist is off.


local official_modules = {
    ["luci.usbleach.modules.docbleach"] = 1,
    ["luci.usbleach.modules.docbleach-local"] = 1,
    ["luci.usbleach.modules.email"] = 1,
    ["luci.usbleach.modules.plik"] = 1,
    ["luci.usbleach.modules.download"] = 1
}

local modules = luci.usbleach.get_modules()
for _, mod in pairs(modules) do
    official_modules[_] = nil
    if mod.config ~= nil then
        mod.config(m)
    end
end

if next(official_modules) ~= nil then
    s = m:section(TypedSection, "usbleach", "Additionnal modules")
    s.addremove = false
    s.anonymous = true

    if official_modules["luci.usbleach.modules.docbleach"] then
        s:option(luci.cbi.DummyValue, "option", "", translate("Did you know? The module <b>docbleach</b> allows you to sanitize your Office documents before you download them. <a href='TODO'>Get it!</a>"))
    end
    if official_modules["luci.usbleach.modules.docbleach-local"] then
        s:option(luci.cbi.DummyValue, "option", "", translate("Did you know? The module <b>docbleach-local</b> allows you to sanitize your Office documents locally, on your device."))
    end
    if official_modules["luci.usbleach.modules.email"] then
        s:option(luci.cbi.DummyValue, "option", "", translate("Did you know? The module <b>email</b> allows you to send your files to yourself via email. <a href='TODO'>Get it!</a>"))
    end
    if official_modules["luci.usbleach.modules.plik"] then
        s:option(luci.cbi.DummyValue, "option", "", translate("Did you know? The module <b><a href='plik.root.gg'>Plik</a></b> allows you to host your files on the free cloud storage Plik. <a href='TODO'>Get it!</a>"))
    end
    if official_modules["luci.usbleach.modules.download"] then
        s:option(luci.cbi.DummyValue, "option", "", translate("Did you know? The module <b>download</b> allows you to download files directly from your browser. <a href='TODO'>Get it!</a>"))
    end
end

return m
