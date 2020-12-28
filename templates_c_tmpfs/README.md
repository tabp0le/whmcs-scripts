# WHMCS templates_c to tmpfs

## Disclaimer
Use this script at your own risk. DO NOT run anything, including this script, unless you've gone over the code and are comfortable with what it does. PLEASE review all the code in this script before running. It's highly suggested you test this in a development environment before using in a production environment. This script makes changes to core parts of your operating system (fstab) and can possibly prevent your system from booting.

## Intro
This script will set up an fstab entry to mount your templates_c (template/tpl cache) to tmpfs. This can significantly improve template caching time and speed up your WHMCS client area. It will set up a systemd one-shot service at boot which will restore your cache to RAM in case of powerloss or reboot.

## Requirements
- Bash
- SystemD
- Rsync
- Root Access to WHMCS server
- Basic knowledge and understanding of Linux cli
- Understanding of how to create a cronjob

## Instructions
- Download script to your server
- Open script and set your variables
- Run script as root or sudo
- Create cronjob as web user to run every 5 minutes or so (this will sync the tpl cache to disk in case of power loss or reboot)  

Example cronjob:

`*/5 * * * * /usr/local/sbin/synctemplate_c_cache`
