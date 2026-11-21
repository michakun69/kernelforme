#!/system/bin/sh
# One-shot late-boot script: no loop, no daemon. Memory stays stock.
# Optional override in /data/adb/force120vk.conf:  IO_SCHED=mq-deadline
[ -f /data/adb/force120vk.conf ] && . /data/adb/force120vk.conf
IO_SCHED=${IO_SCHED:-mq-deadline}
S="cmd settings"

while [ "$(getprop sys.boot_completed)" != "1" ]; do sleep 2; done
sleep 10

w() { [ -w "$1" ] && echo "$2" > "$1"; }

# multi-gen LRU: kernel build enables it by default; on other kernels turn it on here
[ "$(cat /sys/kernel/mm/lru_gen/enabled 2>/dev/null)" = "0x0000" ] && w /sys/kernel/mm/lru_gen/enabled y

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

# log / debug overhead off at runtime
w /proc/sys/kernel/hung_task_timeout_secs 0
w /proc/sys/kernel/printk "0 0 0 0"
w /proc/sys/kernel/printk_devkmsg off
w /sys/module/printk/parameters/time N
w /proc/sys/kernel/sched_schedstats 0
w /proc/sys/kernel/perf_cpu_time_max_percent 1
w /sys/kernel/tracing/events/enable 0
w /sys/kernel/debug/tracing/events/enable 0
w /proc/sys/vm/stat_interval 10

# One-time cleanup of settings that module v1.x/v2.x wrote and left behind
if [ ! -f /data/adb/force120vk.cleaned ]; then
  for k in min_refresh_rate peak_refresh_rate user_refresh_rate oplus_customize_screen_refresh_rate; do
    $S delete system $k
  done
  for k in disable_window_blurs angle_gl_driver_all_angle angle_gl_driver_selection_pkgs \
           angle_gl_driver_selection_values low_power_trigger_level automatic_power_save_mode \
           low_power_sticky; do
    $S delete global $k
  done
  for k in window_animation_scale transition_animation_scale animator_duration_scale; do
    $S put global $k 1.0
  done
  : > /data/adb/force120vk.cleaned
fi

stop_loggers() {
  for svc in logd logcatd statsd traced traced_probes incidentd \
             cnss_diag vendor.cnss_diag diag_mdlog tcpdump; do
    [ "$(getprop init.svc.$svc)" = "running" ] && stop "$svc" >/dev/null 2>&1
  done
}
stop_loggers
sleep 90
stop_loggers
exit 0
