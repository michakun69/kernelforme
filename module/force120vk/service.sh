#!/system/bin/sh
# Late boot tuning for Redmi Note 12 4G (tapas) on a ColorOS/Android 15 port.
#
# Optional overrides in /data/adb/force120vk.conf, e.g.:
#   TARGET=120          refresh rate
#   ZRAM_SIZE=6G        zram disksize
#   ZRAM_ALGO=zstd      zram algorithm ("" = leave zram untouched, lz4kd = stock)
#   SWAPPINESS=140
#   ANIM_SCALE=0.5      window/transition/animator scale ("" = leave alone)
#   MAX_CACHED=64       cached background processes ("" = leave alone)
#   IO_SCHED=mq-deadline
[ -f /data/adb/force120vk.conf ] && . /data/adb/force120vk.conf
TARGET=${TARGET:-120}
ZRAM_SIZE=${ZRAM_SIZE:-6G}
ZRAM_ALGO=${ZRAM_ALGO-zstd}   # zstd = bigger ratio (more apps cached); lz4kd = faster, less CPU
SWAPPINESS=${SWAPPINESS:-140}
ANIM_SCALE=${ANIM_SCALE-0.5}
MAX_CACHED=${MAX_CACHED-64}
IO_SCHED=${IO_SCHED:-mq-deadline}

LOGGERS="logd logcatd statsd traced traced_probes incidentd"
S="cmd settings put"   # native binder client: far cheaper than `settings` (app_process)

while [ "$(getprop sys.boot_completed)" != "1" ]; do sleep 2; done
sleep 10

w() { [ -w "$1" ] && echo "$2" > "$1"; }

# ----------------------------------------------------------------- zram/zstd
setup_zram() {
  Z=/sys/block/zram0
  [ -d "$Z" ] || return 0
  [ -n "$ZRAM_ALGO" ] || return 0                        # ZRAM_ALGO="" -> leave zram alone
  # Only touch zram if the kernel really offers the algorithm (this kernel's
  # default is the ColorOS-style lz4kd) and no writeback device is attached.
  grep -qw "$ZRAM_ALGO" $Z/comp_algorithm 2>/dev/null || return 0
  [ ! -e $Z/backing_dev ] || [ "$(cat $Z/backing_dev 2>/dev/null)" = "none" ] || return 0
  swapoff /dev/block/zram0 2>/dev/null
  grep -q zram0 /proc/swaps && return 0     # still in use: don't touch it
  echo 1 > $Z/reset
  echo "$ZRAM_ALGO" > $Z/comp_algorithm 2>/dev/null
  echo "$ZRAM_SIZE" > $Z/disksize
  mkswap /dev/block/zram0 >/dev/null 2>&1
  swapon -p 32758 /dev/block/zram0 >/dev/null 2>&1
  w $Z/queue/read_ahead_kb 0
}
setup_zram

# ---------------------------------------------------------------- memory/vm
w /sys/kernel/mm/lru_gen/enabled y            # multi-gen LRU
w /proc/sys/vm/swappiness "$SWAPPINESS"
w /proc/sys/vm/page-cluster 0                 # zram: no swap readahead
w /proc/sys/vm/vfs_cache_pressure 60
w /proc/sys/vm/watermark_boost_factor 0       # no reclaim storms after fragmentation
w /proc/sys/vm/overcommit_memory 1
# fewer periodic wakeups
w /proc/sys/vm/stat_interval 10
w /proc/sys/vm/dirty_background_ratio 5
w /proc/sys/vm/dirty_ratio 20
w /proc/sys/vm/dirty_expire_centisecs 3000
w /proc/sys/vm/dirty_writeback_centisecs 3000

# ---------------------------------------------------------------------- I/O
# mq-deadline: tiny CPU cost, and tuned to serve reads (app launches) ahead of
# background writes. BFQ is compiled out of the kernel.
for b in /sys/block/sd[a-z] /sys/block/mmcblk[0-9]; do
  [ -d "$b/queue" ] || continue
  grep -q "$IO_SCHED" $b/queue/scheduler 2>/dev/null && w $b/queue/scheduler "$IO_SCHED"
  w $b/queue/iostats 0                        # no per-IO accounting
  w $b/queue/add_random 0                     # don't feed entropy pool from IO
  w $b/queue/iosched/read_expire 250
  w $b/queue/iosched/write_expire 5000
  w $b/queue/iosched/writes_starved 4
  w $b/queue/iosched/front_merges 0
done

# This kernel ships with the watchdog, hung-task check, loglevel 7, printk
# timestamps and tracing all on, so turn them down at runtime.
w /proc/sys/kernel/watchdog 0
w /proc/sys/kernel/nmi_watchdog 0
w /proc/sys/kernel/soft_watchdog 0
w /proc/sys/kernel/hung_task_timeout_secs 0
w /proc/sys/kernel/printk "0 0 0 0"
w /proc/sys/kernel/printk_devkmsg off
w /sys/module/printk/parameters/time N
w /proc/sys/kernel/sched_schedstats 0
w /sys/kernel/tracing/tracing_on 0
w /sys/kernel/debug/tracing/tracing_on 0

# --------------------------------------------- Vulkan: GL apps via ANGLE
# Only has an effect if the ROM ships ANGLE (libGLESv2_angle.so).
$S global angle_gl_driver_all_angle 1
$S global angle_gl_driver_selection_pkgs '*'
$S global angle_gl_driver_selection_values angle

# --------------------------------- background apps + snappier UI (once/boot)
# Phantom-process killer off, more cached processes allowed.
$S global settings_enable_monitor_phantom_procs false
cmd device_config put activity_manager max_phantom_processes 2147483647 >/dev/null 2>&1
[ -n "$MAX_CACHED" ] && \
  cmd device_config put activity_manager max_cached_processes "$MAX_CACHED" >/dev/null 2>&1
if [ -n "$ANIM_SCALE" ]; then
  $S global window_animation_scale "$ANIM_SCALE"
  $S global transition_animation_scale "$ANIM_SCALE"
  $S global animator_duration_scale "$ANIM_SCALE"
fi

stop_loggers() {
  for svc in $LOGGERS; do
    [ "$(getprop init.svc.$svc)" = "running" ] && stop "$svc" >/dev/null 2>&1
  done
}

# No loop: a stopped service stays stopped until reboot, and the kernel already
# only offers 120Hz. Apply once now and once more after the ROM has settled.
apply() {
  # --- refresh rate (AOSP / ColorOS / HyperOS keys; unknown ones are harmless)
  $S system min_refresh_rate "$TARGET"
  $S system peak_refresh_rate "$TARGET"
  $S system user_refresh_rate "$TARGET"
  $S system oplus_customize_screen_refresh_rate 0
  $S system screen_refresh_rate 0
  $S system miui_refresh_rate "$TARGET"
  $S secure smooth_display 1
  # --- battery saver would force 60Hz: keep it from ever engaging
  $S global low_power 0
  $S global low_power_sticky 0
  $S global low_power_trigger_level 0
  $S global automatic_power_save_mode 0
  $S global disable_window_blurs 1
}

stop_loggers
apply >/dev/null 2>&1
sleep 90
stop_loggers
apply >/dev/null 2>&1
exit 0
