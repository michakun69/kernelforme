#!/system/bin/sh
# Early boot (before zygote / SurfaceFlinger start): props are read once at
# process start, so everything that must be seen by SF / HWUI goes here.

# ---- Vulkan -----------------------------------------------------------
# HWUI (app UI rendering) -> Skia on Vulkan
resetprop ro.hwui.use_vulkan true
resetprop debug.hwui.renderer skiavk
# SurfaceFlinger RenderEngine (composition) -> Skia on Vulkan (Android 13+)
resetprop debug.renderengine.backend skiavkthreaded

# ---- Refresh rate: stop SurfaceFlinger honoring per-app / content rates -
resetprop ro.surface_flinger.enable_frame_rate_override false
resetprop ro.surface_flinger.use_content_detection_for_refresh_rate false
resetprop ro.surface_flinger.set_idle_timer_ms 0
resetprop ro.surface_flinger.set_touch_timer_ms 0
resetprop ro.surface_flinger.set_display_power_timer_ms 0
resetprop ro.surface_flinger.game_default_frame_rate_override 120

# ---- Blur off ---------------------------------------------------------
resetprop ro.surface_flinger.supports_background_blur 0
resetprop persist.sysui.disableBlur true
resetprop persist.sys.sf.disable_blurs 1

# ---- Logging props ----------------------------------------------------
resetprop persist.log.tag S
resetprop persist.logd.size 64K
resetprop persist.traced.enable 0
resetprop ro.logd.size 64K
