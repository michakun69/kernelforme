#!/system/bin/sh
# One-shot late-boot script: no loop, no daemon, exits in ~100s. Memory stays stock.
#
# Optional overrides in /data/adb/force120vk.conf:
#   TARGET=120          refresh-rate setting
#   ANIM_SCALE=0.5      window/transition/animator scale ("" = leave alone)
#   IO_SCHED=mq-deadline
[ -f /data/adb/force120vk.conf ] && . /data/adb/force120vk.conf
TARGET=${TARGET:-120}
ANIM_SCALE=${ANIM_SCALE-0.5}
IO_SCHED=${IO_SCHED:-mq-deadline}

S="cmd settings"      # native binder client: far cheaper than the `settings` app_process

while [ "$(getprop sys.boot_completed)" != "1" ]; do sleep 2; done
sleep 10

w() { [ -w "$1" ] && echo "$2" > "$1"; }

# multi-gen LRU: compiled in, off by default
w /sys/kernel/mm/lru_gen/enabled y

# I/O: mq-deadline (tiny CPU cost), reads served ahead of background writes
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

# watchdog / log / trace overhead off at runtime (harmless if the kernel already did it)
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

# Settings written once (not repeated)
$S put global angle_gl_driver_all_angle 1        # GL via ANGLE/Vulkan, only if the ROM ships ANGLE
$S put global angle_gl_driver_selection_pkgs '*'
$S put global angle_gl_driver_selection_values angle
$S put global disable_window_blurs 1
if [ -n "$ANIM_SCALE" ]; then
  $S put global window_animation_scale "$ANIM_SCALE"
  $S put global transition_animation_scale "$ANIM_SCALE"
  $S put global animator_duration_scale "$ANIM_SCALE"
fi

# Older versions of this module disabled battery saver (those settings persist
# across upgrades). Put battery saver back to normal; refresh rate is held by
# the kernel's 120Hz-only mode list, not by turning the saver off.
$S delete global low_power_trigger_level
$S delete global automatic_power_save_mode
$S delete global low_power_sticky

apply() {
  $S put system min_refresh_rate "$TARGET"
  $S put system peak_refresh_rate "$TARGET"
  $S put system user_refresh_rate "$TARGET"
  $S put system oplus_customize_screen_refresh_rate 0
}

stop_loggers() {
  for svc in logd logcatd statsd traced traced_probes incidentd; do
    [ "$(getprop init.svc.$svc)" = "running" ] && stop "$svc" >/dev/null 2>&1
  done
}

# Now, and once more after the ROM has settled
stop_loggers; apply >/dev/null 2>&1
sleep 90
stop_loggers; apply >/dev/null 2>&1
exit 0
