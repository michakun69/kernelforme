#!/system/bin/sh
# Module removed: put the settings it forced back to defaults.
# (zram/vm/sysctl values and props reset by themselves on the next reboot.)
settings delete system min_refresh_rate
settings delete system peak_refresh_rate
settings delete system user_refresh_rate
settings delete global disable_window_blurs
settings delete global angle_gl_driver_all_angle
settings delete global angle_gl_driver_selection_pkgs
settings delete global angle_gl_driver_selection_values
settings delete global low_power_trigger_level
settings delete global automatic_power_save_mode
rm -f /data/adb/force120vk.conf
