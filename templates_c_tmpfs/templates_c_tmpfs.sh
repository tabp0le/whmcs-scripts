#!/bin/bash

TEMPLATES_C_LOCATION="/var/www/vhosts/domain.com"
TEMPLATES_C_DIR="$TEMPLATES_C_LOCATION/templates_c"
TEMPLATES_C_PERSIST_DIR="$TEMPLATES_C_LOCATION/templates_c_persist"
# templates_c/WHMCS directory owner user
WEBUSER=
# templates_c/WHMCS directory group
WEBGROUP=
WEBUID=$(id -u $WEBUSER)
WEBGID=$(id -g $WEBUSER)


mkdir $TEMPLATES_C_PERSIST_DIR
chown $WEBUSER:$WEBGROUP $TEMPLATES_C_PERSIST_DIR

cat <<EOF > /usr/local/sbin/restoretemplate_c_cache
#!/bin/bash
echo "Restoring WHMCS templates_c from disk to tmpfs"
/usr/bin/ionice -c3 -n7 /bin/nice -n 19 /usr/bin/rsync -ahv --stats --delete $TEMPLATES_C_PERSIST_DIR/ $TEMPLATES_C_DIR/ > /dev/null 2>&1
echo "templates_c restored"
EOF

chmod +x /usr/local/sbin/restoretemplate_c_cache

cat <<EOF > /usr/local/sbin/synctemplate_c_cache
#!/bin/bash
starttime="$(date +%a\ %b\ %d\ %H:%M:%S:)$(($(date +%N)/1000000)) $(date +%Z\ %Y)"
printf "===========================================\nSyncing templates_c in-memory cache to disk\nBegin: $starttime\n===========================================\n\n"
sleep 5s
/usr/bin/ionice -c3 -n7 /bin/nice -n 19 /usr/bin/rsync -avh --stats --delete $TEMPLATES_C_DIR/ $TEMPLATES_C_PERSIST_DIR/
endtime="$(date +%a\ %b\ %d\ %H:%M:%S:)$(($(date +%N)/1000000)) $(date +%Z\ %Y)"
printf "===========================================\nCached templates_c synced to disk\nEnd: $endtime\n===========================================\n\n"
EOF
chmod +x /usr/local/sbin/synctemplate_c_cache

cat <<EOF > /usr/lib/systemd/system/whmcs-restore-tpl-cache.service
[Unit]
Description=Restore WHMCS templates_c cache from disk to tmpfs
Before=network.target

[Service]
Type=oneshot
ExecStart=runuser -l $WEBUSER -c '/usr/local/sbin/restoretemplate_c_cache'
StandardOutput=journal
SELinuxContext=system_u:system_r:unconfined_t:s0
[Install]
WantedBy=multi-user.target
EOF

chown $WEBUSER:$WEBGROUP /usr/lib/systemd/system/whmcs-restore-tpl-cache.service
chmod 0644 /usr/lib/systemd/system/whmcs-restore-tpl-cache.service

echo "Creating fstab entry..."

cat <<EOF >> /etc/fstab
tmpfs $TEMPLATES_C_DIR tmpfs defaults,size=1g,noexec,uid=$WEBUID,gid=$WEBGID,mode=0755 0 0
EOF

echo "fstab entry created"
echo ""
echo "Backing up templates_c directory to templates_c_persist..."
bash -c "/usr/local/sbin/synctemplate_c_cache"
echo "templates_c backed up"
echo ""
echo "Cleaning out templates_c dir to prepare for tmpfs mount..."
rm -rf $TEMPLATES_C_DIR/*
echo "templates_c dir cleaned"
echo ""
echo "Mounting new templates_c fstab entry to tmpfs..."
mount -a
echo "templates_c mounted to tmpfs"
echo ""
echo "Restoring templates_c cache from disk to tmpfs dir..."
bash -c "/usr/local/sbin/restoretemplate_c_cache"
echo "templates_c cache populated into tmpfs"

echo ""
echo "Reloading systemd..."
systemctl daemon-reload
echo "Systemd reloaded"
echo "Enabling boot service to restore cache on powerloss or reboot..."
systemctl enable whmcs-restore-tpl-cache
echo "Boot service enabled"
echo ""
echo "######################"
echo "          Done        "
echo "######################"
echo ""
echo "##########################################################################"
echo "Don't forget to create a cronjob to sync your templates_c dir to disk,
so the boot service can restore the cache in case of power loss.

Create the cronjob under your web user. Something like the following:

*/5 * * * * /usr/local/sbin/synctemplate_c_cache"
echo "##########################################################################"
echo ""
