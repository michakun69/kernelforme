#!/system/bin/sh
# One-shot late-boot script (no loop, no daemon). Memory/zram/VM stay stock.
#
# Optional overrides in /data/adb/force120vk.conf:
#   TARGET=120          refresh rate setting
#   ANIM_SCALE=0.5      window/transition/animator scale ("" = leave alone)
#   IO_SCHED=mq-deadline
[ -f /data/adb/force120vk.conf ] && . /data/adb/force120vk.conf
TARGET=${TARGET:-120}
ANIM_SCALE=${ANIM_SCALE-0.5}
IO_SCHED=${IO_SCHED:-mq-deadline}

LOGGERS="logd logcatd statsd traced traced_probes incidentd"
S="cmd settings put"   # native binder client: far cheaper than `settings`

while [ "$(getprop sys.boot_completed)" != "1" ]; do sleep 2; done
sleep 10

w() { [ -w "$1" ] && echo "$2" > "$1"; }

# --------------------------------------------------------- multi-gen LRU
# Built into this kernel but off by default.
w /sys/kernel/mm/lru_gen/enabled y

# ------------------------------------------------------------------ I/O
# mq-deadline: tiny CPU cost, reads (app launches) served ahead of background
# writes; no per-IO accounting.
for b in /sys/block/sd[a-z] /sys/block/mmcblk[0-9]; do
  [ -d "$b/queue" ] || continue
  grep -q "$IO_SCHED" $b/queue/scheduler 2>/dev/null && w $b/queue/scheduler "$IO_SCHED"
  w $b/queue/iostats 0
  w $b/queue/add_random 0
  w $b/queue/iosched/read_expire 250
  w $b/queue/iosched/write_expire 5000
  w $b/queue/iosched/writes_starved 4
  w $b/queue/iosched/front_merges 0
done

# --------------------- watchdog / log / trace overhead (this kernel ships
# with them on: loglevel 7, hung-task check, tracing, printk timestamps)
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

# ------------------------------------------ Vulkan: GL apps via ANGLE
# Only has an effect if the ROM ships ANGLE (libGLESv2_angle.so).
$S global angle_gl_driver_all_angle 1
$S global angle_gl_driver_selection_pkgs '*'
$S global angle_gl_driver_selection_values angle

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

apply() {
  # refresh rate (AOSP / ColorOS / HyperOS keys; unknown ones are harmless)
  $S system min_refresh_rate "$TARGET"
  $S system peak_refresh_rate "$TARGET"
  $S system user_refresh_rate "$TARGET"
  $S system oplus_customize_screen_refresh_rate 0
  $S system screen_refresh_rate 0
  $S system miui_refresh_rate "$TARGET"
  $S secure smooth_display 1
  # battery saver would force 60Hz: keep it from engaging
  $S global low_power 0
  $S global low_power_sticky 0
  $S global low_power_trigger_level 0
  $S global automatic_power_save_mode 0
  $S global disable_window_blurs 1
}

# Once now, once after the ROM has settled, then exit.
stop_loggers; apply >/dev/null 2>&1
sleep 90
stop_loggers; apply >/dev/null 2>&1
exit 0
