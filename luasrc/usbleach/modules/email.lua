--- @module luci.usbleach.modules.email
local email = {}

function email.index()
    return { name = "Email" }
end

--- EDIT ME PLEASE :)

-- Default domain appended to "email" addresses when
-- they don't contain an arobase symbol
local DEFAULT_DOMAIN = "@gmail.com"

-- SMTP server to be used.
local SMTP_HOST = "your_smtp_server.com"

--- STOP EDITING ME PLEASE :)

local mailMessageLink = [===[
Hello, the file %s you've asked me is available here:
%s

This link will work for the next 6 hours, and will then be deleted.

Please stay vigilent, this file may contain malicious things.
]===]

function email.act(t)
    local filestat = t.filestat
    local file = t.file
    local basename = t.basename

    local email = luci.http.formvalue("email")

    if email == nil or #email < 1 or email == "null" then
        return luci.dispatcher.error404('Email not given')
    end

    if not string.find(email, "@") then
        email = email .. DEFAULT_DOMAIN
    end

    local smtp = require 'socket.smtp'

    local fromEmail = uci.cursor():get("usbleach", "main", "email_source", {})

    local r, e

    if file:sub(1, 7) == "http://" or file:sub(1, 8) == "https://" then
        r, e = smtp.send {
            from = fromEmail,
            rcpt = email,
            server = SMTP_HOST,
            source = smtp.message {
                headers = {
                    subject = "[USBleach] Your file " .. basename
                },
                body = string.format(mailMessageLink, basename, file)
            }
        }
    else
        if filestat and filestat.type ~= "reg" then
            return luci.dispatcher.error404("?? not a regular file (" .. file .. "," .. filestat.type .. ")")
        end
        r, e = smtp.send {
            from = fromEmail,
            rcpt = email,
            server = SMTP_HOST,
            source = smtp.message {
                headers = {
                    subject = "[USBleach] Your file " .. basename,
                    ["content-type"] = 'text/html',
                    ["content-disposition"] = 'attachment; filename="' .. basename .. '"',
                    ["content-description"] = basename,
                    ["content-transfer-encoding"] = "BASE64",
                },
                body = {
                    "",
                    ltn12.source.chain(ltn12.source.file(io.open(file, "rb")),
                        ltn12.filter.chain(mime.encode("base64"), mime.wrap()))
                }
            }
        }
    end
    if not r then return { errors = { "ERROR " .. e } } end
    table.insert(t.infos, "Mail envoyé")
    return { infos = t.infos }
end

function email.config(map)
    local s = map:section(luci.cbi.TypedSection, "usbleach", "Module Email")
    s.addremove = false
    s.anonymous = true

    local allow_dangerous = s:option(luci.cbi.Value, "email_source", luci.i18n.translate("Expéditeur"),
        luci.i18n.translate("Adresse email à partir de laquelle les informations seront transmises aux utilisateurs"))
    allow_dangerous.default = "donot@keepme.org"
    allow_dangerous.rmempty = false

    if luci.usbleach.is_module_available("luci.usbleach.modules.plik") then
        local use_plik = s:option(luci.cbi.Flag, "email_store_on_plik", luci.i18n.translate("Store files on Plik"),
            luci.i18n.translate("When enabled, the files you send yourself via email are store on plik and not attached to the email. This way, sensitive files are stored and automatically removed"))
        use_plik.enabled = "on"
        use_plik.disabled = "off"
        use_plik.default = use_plik.enabled
        use_plik.rmempty = false
    else
        s:option(luci.cbi.DummyValue, "option", "", "Did you know? A module is available to host your files on <a href='plik.root.gg'>Plik</a>")
    end
end

---
-- Options to include:
-- SMTP Auth (username, password), Host (hostname, port), Auth (PLAIN, LOGIN), Crypto (TLSv1, v1.1, v1.2)
-- SSL: https://stackoverflow.com/questions/29312494/sending-email-using-luasocket-smtp-and-ssl
--
--
return email
