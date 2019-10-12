[![USBleach](https://img.shields.io/badge/%E2%9D%A4-USBleach-green.svg?style=flat-square)](https://github.com/docbleach/usbleach/releases)

This OpenWRT package is a USB firewall between your corporate infrastructure and the public domain.

[![Build Status](https://img.shields.io/badge/build-not_yet-yellow.svg)](https://travis-ci.org/docbleach/usbleach)

*DISCLAIMER - THIS IS STILL A WORK IN PROGRESS*

Let's say you work for a serious company, with strict policies and periodic audits.
One of your partners puts an important file on his USB stick and wants to share it with you.

Three options are available to you:

- (BAD) plug the stick on your desk, bypassing the policies
- (GOOD) give the stick to your IT department so that they can sanitize it
- (BETTER) plug it into an OpenWRT sandbox with USBleach, use your web browser to pickup files

# USBleach's objectives

The one and only goal of this project is to _bring back the simplicity of USB's
file sharing feature, without the flaws_.

We considered multiple attacks using USB keys, not all of them are in the scope of this project:

- Physical threats (USB Killer): depends on your hardware, can't be done with soft.
- Mass Storage: we detect bad files and we either sanitize them when we can, or we prevent them from being used.
- Everything else is _assumed_ safe enough to be used on your desktop, but plugging anything else than an USB stick with warn you.

Using this scheme, [Bash Bunny](https://shop.hak5.org/products/bash-bunny), [Rubber Ducky](https://shop.hak5.org/products/usb-rubber-ducky-deluxe), [O.MG Cable](https://mg.lol/blog/omg-cable/) and [BadUSB](https://www.youtube.com/watch?v=nuruzFqMgIw) are blocked: if they "look like" USB keys but are not, you know something is odd.


# Installation

This project is bundled into an `.ipk` package, that you can install directly on your OpenWRT box.

USBleach depends on [yara](https://github.com/ovh/overthebox-feeds/tree/master/yara), so be sure to install it too.

If you're using a raw OpenWRT:

```
To Be Done
```

If you're using an [OverTheBox](https://www.ovhtelecom.fr/overthebox/):

```
$ wget https://github.com/docbleach/USBleach/releases/download/v0.4.12/usbleach_0.6-1_all.ipk
$ opkg install usbleach_0.6-1_all.ipk
```

## Get the sources

```bash
    git clone https://github.com/docbleach/USBleach.git
    cd usbleach
    # Start hacking
```

You have developed a new cool feature ? Fixed an annoying bug ?
We would be happy to hear from you !


## Configure
Edit the file `./luasrc/usbleach/modules/email.lua` to set the right domains:

```
local DEFAULT_DOMAIN = "@gmail.com"
local SMTP_HOST = "your_smtp_server.com"
```
