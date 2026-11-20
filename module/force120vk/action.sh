#!/system/bin/sh
# Action button: re-apply the refresh-rate settings right now.
[ -f /data/adb/force120vk.conf ] && . /data/adb/force120vk.conf
T=${TARGET:-120}
for k in min_refresh_rate peak_refresh_rate user_refresh_rate; do cmd settings put system $k $T; done
cmd settings put system oplus_customize_screen_refresh_rate 0
echo "Refresh-rate settings re-applied ($T Hz)"
