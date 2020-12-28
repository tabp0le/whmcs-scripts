#!/bin/bash

TEMPLATES_C_LOCATION="/var/www/vhosts/domain.com"
TEMPLATES_C_DIR="$TEMPLATES_C_LOCATION/templates_c"
TEMPLATES_C_PERSIST_DIR="$TEMPLATES_C_LOCATION/templates_c_persist"
WEBUSER=
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

cat <<EOF >> /etc/fstab
tmpfs $TEMPLATES_C_DIR tmpfs defaults,size=1g,noexec,uid=$WEBUID,gid=$WEBGID,mode=0755 0 0
EOF

rm -rf $TEMPLATES_C_DIR/*
mount -a

systemctl daemon-reload
systemctl enable whmcs-restore-tpl-cache
