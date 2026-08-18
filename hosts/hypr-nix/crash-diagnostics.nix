####################################################################
# CRASH DIAGNOSTICS — make the next hard freeze leave evidence
#
# WHY THIS FILE EXISTS
#
# On 2026-08-17 at 23:39:04 this machine hard-locked: mouse, keyboard and
# window focus all dead at once, requiring a power-button hold. The next
# boot confirmed it was not a clean shutdown — `systemd-fsck` logged
# "root: recovering journal" and "Dirty bit is set. Fs was not properly
# unmounted". It was the only boot in the preceding eight to end that way.
#
# The journal from that session simply stops mid-stride. No oops, no
# panic, no stack trace, no shutdown sequence. Post-mortem ruled out the
# usual suspects: memory was fine (3.4G of 62G used, no OOM kill), thermals
# were fine (thermald active, zero MCE/EDAC/throttle events), it was not
# hypridle or hyprlock (the session was active 66 seconds prior, and the
# shortest idle timeout is 150s), and it was not a config regression
# (generation 13 had already run and shut down cleanly on Aug 14).
#
# The reason there was nothing to read is that NOTHING WAS ARMED TO LOOK.
# The relevant state at the time of the freeze was:
#
#   kernel.soft_watchdog = 1     <- soft lockup detector ON
#   kernel.nmi_watchdog  = 0     <- HARD lockup detector OFF
#   kernel.hardlockup_panic = 0
#   kernel.panic         = 0     <- hang forever rather than reboot
#   kernel.panic_on_oops = 0
#
# That combination is diagnostically the worst case, and it is also
# informative: because the SOFT lockup detector was on and caught nothing,
# the failure was not a task spinning in kernel space, and not a userspace
# wedge (a dying Hyprland would have left the kernel logging normally).
# What is left is a genuine hard lockup — interrupts dead, kernel unable to
# write anything — which is exactly the one class this box could not record.
#
# Root cause therefore remains UNDETERMINED, and this file does not claim
# to fix it. It makes the next occurrence diagnosable instead of silent.
# The two realistic candidates for this hardware are Raptor Lake i9-14900HX
# instability (microcode 0x137 is loaded, which prevents FURTHER
# degradation but cannot repair silicon already damaged) and a hybrid
# i915/NVIDIA hang. The logs cannot distinguish them without the below.
#
# WHAT TO DO AFTER THE NEXT FREEZE
#
#   sudo dmesg --ciphertext=never -k  # nothing useful; the box rebooted
#   ls /var/lib/systemd/pstore/       # <-- THE PANIC LIVES HERE
#   journalctl -b -1 -k -p err
#
# systemd-pstore.service is already enabled on this system and archives
# /sys/fs/pstore into /var/lib/systemd/pstore on boot, backed by
# efi_pstore (the panic survives in NVRAM across the reboot). That half
# already worked — it simply never had anything to archive, because
# nothing converted the freeze into a panic. The settings below are what
# produce the panic in the first place.
####################################################################

{ config, lib, pkgs, ... }:

{
  ####################################################################
  # Hard lockup detector
  ####################################################################
  # The NMI/perf-based hard lockup detector runs off a non-maskable
  # interrupt, so it still fires when the box is wedged badly enough that
  # ordinary interrupts and scheduling have stopped — the exact situation
  # where the soft lockup detector is useless. It permanently consumes one
  # hardware PMU counter, which is the tradeoff: `perf` has one fewer
  # general-purpose counter available. On a laptop that is a non-issue.
  #
  # Set as a kernel parameter AND a sysctl on purpose: the parameter covers
  # early boot before sysctls are applied, the sysctl makes the setting
  # visible and greppable in the running system.
  boot.kernelParams = [ "nmi_watchdog=1" ];

  boot.kernel.sysctl = {
    "kernel.nmi_watchdog" = 1;

    # Turn a detected hard lockup into a panic. Without this the detector
    # only prints a trace — and printing is precisely what a wedged box
    # cannot do reliably. The panic path, by contrast, writes to pstore
    # (NVRAM) synchronously, which is why this is the single most
    # important line in the file.
    "kernel.hardlockup_panic" = 1;

    # Reboot 30 seconds after a panic instead of sitting frozen forever
    # (the old value, 0, means "hang indefinitely"). 30s leaves the panic
    # legible on screen if you happen to be watching, and pstore has
    # already been written by then — the record does not depend on you
    # catching it live.
    "kernel.panic" = 30;

    # Escalate a kernel oops to a full panic so it also lands in pstore.
    #
    # TRADEOFF, read before keeping: an oops that the kernel might have
    # limped through now reboots the machine immediately, so you can lose
    # unsaved work to a fault that would previously have been survivable.
    # Given nvidia.ko is an out-of-tree tainted module here, that is a real
    # possibility. If this proves trigger-happy in practice, set it to 0 —
    # you keep the hard lockup capture above, which is what actually
    # targets the observed failure.
    "kernel.panic_on_oops" = 1;

    # DELIBERATELY LEFT AT 0 (the default): soft lockups are frequently
    # transient and recoverable, and they are already logged by the soft
    # watchdog. Panicking on them would trade a survivable stall for a
    # guaranteed reboot, which is a bad deal.
    # "kernel.softlockup_panic" = 0;
  };

  ####################################################################
  # Hardware watchdog — the backstop
  ####################################################################
  # This machine has an Intel TCO watchdog (iTCO_wdt, /dev/watchdog0) that
  # was present but unused. Arming it makes PID 1 pet the device on a
  # timer; if the kernel dies hard enough that even the panic path above
  # cannot run, the petting stops and the hardware resets the box. That
  # turns "frozen until I notice and hold the power button" — which is
  # what happened on Aug 17, costing ~10 minutes — into an automatic
  # reboot within a minute.
  #
  # SUSPEND SAFETY: verified before enabling. The iTCO_wdt driver
  # implements suspend/resume handlers (iTCO_wdt_suspend_noirq /
  # iTCO_wdt_resume_noirq, confirmed present in /proc/kallsyms) which stop
  # the timer across S3 and restart it on resume. This box does suspend —
  # there is a successful S3 cycle in the current boot — so without those
  # handlers this setting would cause spurious resets on every wake. It
  # does not.
  #
  # 60s is comfortably inside the iTCO hardware maximum (613s on TCO v2+);
  # systemd re-reads the timeout the driver actually applied and pets at
  # half that interval, so a clamp would be handled gracefully anyway.
  #
  # These are set via `systemd.settings.Manager.*` rather than the older
  # `systemd.watchdog.{runtimeTime,rebootTime}` aliases — nixpkgs 26.05
  # still accepts those but emits a rename warning on every rebuild.
  systemd.settings.Manager.RuntimeWatchdogSec = "60s";

  # Also cover a hang during the reboot itself — a shutdown that wedges
  # would otherwise still need the power button.
  systemd.settings.Manager.RebootWatchdogSec = "3min";
}
