# 🚀 Android Kernel Builder
## ⚠️ Important Notice

This workflow is configured for specific devices. **You must modify the settings for your device** or it may not work properly.

## 🔧 Quick Start

1. **Fork this repository**
2. Go to **Actions** tab → **"Build kernels"** workflow
3. Click **"Run workflow"** and configure:

### Workflow Settings

| Setting | Description | Default |
|---------|-------------|---------|
| **Kernel source URL** | Your kernel repository URL | `https://github.com/topnotchfreaks/kernel_msm-5.15` |
| **Kernel branch** | Branch to build from | `codelinaro` |
| **Device** | Device name for defconfig | `gki` |
| **Custom localversion** | Add custom version suffix | (empty) |
| **Build KSU variant** | Include KernelSU version | `true` |
| **LTO mode** | Optimization level | `thin` |

4. **Wait for build** (20-40 minutes)
5. **Download** the flashable ZIP from artifacts

## 📱 Telegram Notifications (Optional)

Get build results sent to Telegram:

1. Create a bot with [@BotFather](https://t.me/BotFather)
2. Get your chat ID from [@GetIDsBot](https://t.me/GetIDsBot)
3. Add these secrets in repository **Settings** → **Secrets**:
   - `TELEGRAM_BOT_TOKEN`
   - `TELEGRAM_USER_ID`

## 🤝 Credits

- **@PhamtomK12** – Original builder
- **@ssocozy** – Contributor  
- **@NVG-064** – Contributor
- **@ShirkNeko** – SUSFS integration
- **@thewildjames** – Wild-KSU
- **@belowzeroiq** – Guides, Mentoring and Resources
- **@kusonekoworld-max** – SUSFS Script, Reflex + Vorpal implementation
- **@RapliVx** – KSUN Multi Manager Script
- **@NotPichayut** – Kernel Version Spoof Script
- **@Ling_Luo & @init_user0** – SUSFS Script and patches


---

**Ready to build? Hit that "Run workflow" button! 🎉**

---

## 🔒 120Hz-lock / O3 / quiet build (this fork)

The `Build kernels` workflow now, before compiling:

1. Applies every patch in `patches/`
   - `0001` – DRM core: internal panels (DSI/eDP/LVDS/DPI) only expose their 120Hz modes and atomic commits at any other rate are rejected. No sysfs/property/param switch. If a panel has no 120Hz mode, nothing is filtered (display can't go blank).
   - `0002` – lets `-O3` be selected on arm64 (upstream only allows it on ARC).
2. Sets `-O3`, drops `printk` timestamps/caller, lowers console/message loglevel to 1, disables pstore console/pmsg and `PAGE_OWNER`. (SUSFS logging must stay enabled: this SUSFS version does not build with it off.)
3. Builds the ReSukiSU + SUSFS (`ksu`) variant by default.

Config added in the second round: `HZ=100` (arm64 has no 50Hz option), KPTI and branch-history mitigations off plus `mitigations=off` on the kernel command line, `nowatchdog nosoftlockup nmi_watchdog=0`, `quiet loglevel=0`, 4KB log buffer, zstd as the default zram algorithm. Options that would remove symbols vendor modules link against (CFI, shadow call stack, stack protector, DEBUG_FS, PRINTK, WATCHDOG core, PM_WAKELOCKS) are deliberately left on.

`module/force120vk-v1.6.zip` is a KernelSU module for the userspace side: Vulkan (SkiaVK, plus ANGLE for GL apps where the ROM ships it), SurfaceFlinger frame-rate overrides/idle timers off, battery saver disabled, blur off, loggers stopped, 6GB zstd zram + swappiness 140.

Run **Actions → Build kernels → Run workflow** and pick the branch containing this change.

### Tapas (Redmi Note 12 4G) notes
- This fork is trimmed to one workflow (`main.yml`) and the flasher only accepts `tapas`/`topaz`.
- Kernel: BFQ and Kyber removed (mq-deadline kept), MGLRU on by default, zstd zram default, HZ=100.
- Module v1.6 (no background loop, for a 6.12 GKI kernel): `mq-deadline` with read priority, `iostats` off, MGLRU, zstd zram, more cached apps, animations 0.5x. Overrides go in `/data/adb/force120vk.conf` (`TARGET`, `ZRAM_SIZE`, `SWAPPINESS`, `ANIM_SCALE`, `MAX_CACHED`, `IO_SCHED`).
