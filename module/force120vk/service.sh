#!/system/bin/sh
# Late boot. Applies runtime tuning, then keeps the refresh-rate settings and
# logger services pinned down.
#
# Optional overrides in /data/adb/force120vk.conf, e.g.:
#   TARGET=120        refresh rate
#   ZRAM_SIZE=6G      zram disksize (G or M)
#   SWAPPINESS=140
[ -f /data/adb/force120vk.conf ] && . /data/adb/force120vk.conf
TARGET=${TARGET:-120}
ZRAM_SIZE=${ZRAM_SIZE:-6G}
SWAPPINESS=${SWAPPINESS:-140}

LOGGERS="logd logcatd statsd traced traced_probes incidentd"

while [ "$(getprop sys.boot_completed)" != "1" ]; do sleep 2; done
sleep 10

# ---------------------------------------------------------------- zram/zstd
# Re-create zram0 with zstd (best ratio -> more background apps stay in RAM).
# Done once per boot; skipped if it already is zstd at the right size.
setup_zram() {
  Z=/sys/block/zram0
  [ -d "$Z" ] || return 0
  # swapoff can fail under memory pressure; never reset a zram that is in use
  swapoff /dev/block/zram0 2>/dev/null
  grep -q zram0 /proc/swaps && return 0
  echo 1 > $Z/reset
  echo zstd > $Z/comp_algorithm 2>/dev/null
  echo "$ZRAM_SIZE" > $Z/disksize
  mkswap /dev/block/zram0 >/dev/null 2>&1
  swapon -p 32758 /dev/block/zram0 >/dev/null 2>&1
}
setup_zram

# --------------------------------------------------------------- vm tuning
echo "$SWAPPINESS" > /proc/sys/vm/swappiness
echo 0   > /proc/sys/vm/page-cluster          # zram: no readahead clustering
echo 60  > /proc/sys/vm/vfs_cache_pressure    # keep dentries/inodes a bit longer
echo 1   > /proc/sys/vm/overcommit_memory

# ----------------------------------------------- kernel debug/watchdog off
echo 0 > /proc/sys/kernel/watchdog        2>/dev/null
echo 0 > /proc/sys/kernel/nmi_watchdog    2>/dev/null
echo 0 > /proc/sys/kernel/soft_watchdog   2>/dev/null
echo 0 > /proc/sys/kernel/hung_task_timeout_secs 2>/dev/null
echo "0 0 0 0" > /proc/sys/kernel/printk 2>/dev/null
echo off > /proc/sys/kernel/printk_devkmsg 2>/dev/null
echo 0 > /proc/sys/kernel/sched_schedstats 2>/dev/null

# ---------------------------------------------------------- ANGLE (GL->VK)
# Ask the framework to run every GLES app on ANGLE's Vulkan backend. Only
# works if the ROM actually ships ANGLE (libGLESv2_angle.so); otherwise apps
# silently fall back to the native GLES driver.
settings put global angle_gl_driver_all_angle 1
settings put global angle_gl_driver_selection_pkgs '*'
settings put global angle_gl_driver_selection_values angle

# ---------------------------------------------------------- blur / animations
settings put global disable_window_blurs 1

stop_loggers() {
  for svc in $LOGGERS; do
    [ "$(getprop init.svc.$svc)" = "running" ] && stop "$svc" >/dev/null 2>&1
  done
}

apply() {
  # --- refresh rate: AOSP / Pixel / most custom ROMs ---
  settings put system min_refresh_rate "$TARGET"
  settings put system peak_refresh_rate "$TARGET"
  settings put system user_refresh_rate "$TARGET"
  # --- Samsung One UI ---
  settings put system refresh_rate_mode 2
  # --- Xiaomi / HyperOS / MIUI ---
  settings put system miui_refresh_rate "$TARGET"
  # --- OnePlus / Oppo / Realme ---
  settings put system oneplus_screen_refresh_rate 0
  settings put system screen_refresh_rate 0
  settings put secure oplus_customize_screen_refresh_rate 0
  settings put secure smooth_display 1

  # --- battery saver must never kick in (it forces 60Hz) ---
  settings put global low_power 0
  settings put global low_power_sticky 0
  settings put global low_power_trigger_level 0
  settings put global automatic_power_save_mode 0
  cmd power set-mode 0 >/dev/null 2>&1

  settings put global disable_window_blurs 1
}

# keep everything pinned: re-apply every 30s (cheap: a handful of settings calls)
while true; do
  stop_loggers
  apply >/dev/null 2>&1
  sleep 30
done
