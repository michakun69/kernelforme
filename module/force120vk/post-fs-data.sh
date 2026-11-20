#!/system/bin/sh
# Early boot (before zygote / SurfaceFlinger start): properties are read once
# at process start, so everything SF / HWUI must see goes here. No daemon.

# ---- Vulkan -----------------------------------------------------------
resetprop ro.hwui.use_vulkan true
resetprop debug.hwui.renderer skiavk
resetprop debug.renderengine.backend skiavkthreaded

# ---- Refresh rate: SurfaceFlinger must not follow per-app / content rates
resetprop ro.surface_flinger.enable_frame_rate_override false
resetprop ro.surface_flinger.use_content_detection_for_refresh_rate false
resetprop ro.surface_flinger.set_idle_timer_ms 0
resetprop ro.surface_flinger.set_touch_timer_ms 0
resetprop ro.surface_flinger.set_display_power_timer_ms 0
resetprop ro.surface_flinger.game_default_frame_rate_override 120

# ---- Blur off (own props + the two new ones from Bye-Blur v3) -----------
resetprop ro.surface_flinger.supports_background_blur 0
resetprop persist.sysui.disableBlur true
resetprop persist.sys.sf.disable_blurs 1
resetprop ro.launcher.blur.appLaunch 0
resetprop persist.sys.background_blur_supported false

# ---- GPU/DDR bandwidth: keep UBWC (compressed buffers) explicitly on ----
# (stock default already; from GPU Turbo Boost, the only item there with a
#  real mechanism: less memory traffic -> less power/heat)
resetprop debug.gralloc.gfx_ubwc_disable 0
resetprop vendor.gralloc.disable_ubwc 0
resetprop debug.mdpcomp.logs 0

# ---- Logging props ----------------------------------------------------
resetprop persist.log.tag S
resetprop persist.logd.size 64K
resetprop persist.traced.enable 0
resetprop ro.logd.size 64K
