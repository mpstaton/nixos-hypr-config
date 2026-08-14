####################################################################
# MACHINE-SPECIFIC — "sys76" (System76 Serval WS, serw13)
#   Intel Core i9-14900HX (Raptor Lake) + NVIDIA RTX 4070 Max-Q (AD106M)
#
# "sys76" is what this machine is called day to day — it is the same name
# used in the git identity on it (mps@sys76).
#
# Everything in this file describes THIS physical computer. None of it is
# required by the hypr-nix desktop setup itself — Hyprland, waybar, pipewire,
# fonts and the rest live in configuration.nix and work on any hardware.
#
# ON A NEW COMPUTER:
#   1. Delete the `./hardware-sys76.nix` line from configuration.nix's
#      `imports` list. Everything else keeps working — the generic path
#      (hardware.graphics.enable + mesa/nouveau) still gets you a desktop.
#   2. Write a new hardware-<name>.nix for that machine and import that
#      instead. Keep one file per machine; don't merge into configuration.nix.
#
# Detected with:  lspci -k | grep -A3 -E "(VGA|3D|Display)"
#                 cat /sys/class/dmi/id/{sys_vendor,product_name,product_version}
####################################################################

{ config, lib, pkgs, ... }:

{
  ####################################################################
  # System76 vendor support
  ####################################################################
  # Firmware daemon, ACPI/IO kernel modules, and system76-power (fan curves
  # + power profiles). This is the NixOS equivalent of the `system76-*`
  # packages that shipped on the previous Arch install.
  # (The option is `enableAll`, not `enable` — it switches on the kernel
  # modules, the power daemon and the firmware daemon together. Granular
  # alternatives exist: hardware.system76.{kernel-modules,power-daemon}.)
  hardware.system76.enableAll = true;

  ####################################################################
  # CPU — Intel i9-14900HX (Raptor Lake)
  ####################################################################
  # Microcode from nixpkgs rather than whatever the BIOS happens to carry.
  # Relevant on 13th/14th-gen Intel: the Raptor Lake instability/degradation
  # errata were fixed in microcode 0x12B and later. Declaring this keeps the
  # machine current without depending on a BIOS update landing.
  hardware.cpu.intel.updateMicrocode = true;

  # Intel's thermal daemon. Keeps the 14900HX off its thermal limits under
  # sustained load instead of relying on firmware throttling alone.
  services.thermald.enable = true;

  ####################################################################
  # Graphics — hybrid Intel iGPU + NVIDIA dGPU
  ####################################################################
  # NOTE: `hardware.graphics.enable = true` lives in configuration.nix — it is
  # generic and belongs there. Only the vendor-specific parts are here.

  # VA-API hardware video decode on the Intel iGPU. Without this, browsers and
  # players decode video on the CPU: measurably worse battery life and heat.
  # Verify after a rebuild with `vainfo` (should list H264/HEVC/VP9/AV1).
  hardware.graphics.extraPackages = with pkgs; [
    intel-media-driver # iHD driver — correct for Raptor Lake
    libva-vdpau-driver
    libvdpau-va-gl
  ];
  environment.sessionVariables.LIBVA_DRIVER_NAME = "iHD";

  environment.systemPackages = with pkgs; [
    libva-utils # provides `vainfo` for checking the above
  ];

  ####################################################################
  # NVIDIA RTX 4070 Max-Q — proprietary driver + PRIME offload
  ####################################################################
  # CURRENTLY OFF. The card runs on the in-kernel `nouveau` driver, which
  # cannot reclock Ada (40-series) silicon — it sits at boot clocks and has no
  # CUDA/NVENC. Functional, but a fraction of what the card can do.
  #
  # Uncomment the block below to switch to the proprietary driver. Bus IDs are
  # already filled in for THIS machine (lspci 00:02.0 -> PCI:0:2:0,
  # 01:00.0 -> PCI:1:0:0), so no further hardware lookup is needed.
  #
  # This is the change most likely to produce a black screen on a hybrid
  # laptop running Hyprland. If that happens: reboot, pick the previous
  # generation from the systemd-boot menu, and you are back — no live USB.
  # Enable it while you are sitting at the machine, not remotely.
  #
  # Pair it with the env vars in home/mps/home.nix's hyprland `env` list
  # (already noted in configuration.nix's graphics comment):
  #   "LIBVA_DRIVER_NAME,nvidia"
  #   "__GLX_VENDOR_LIBRARY_NAME,nvidia"
  #   "ELECTRON_OZONE_PLATFORM_HINT,auto"
  #
  # services.xserver.videoDrivers = [ "nvidia" ];
  # hardware.nvidia = {
  #   modesetting.enable = true;
  #   open = true; # open kernel module — supported and recommended on Ada
  #   nvidiaSettings = true;
  #   powerManagement.enable = true; # correct suspend/resume on hybrid laptops
  #   package = config.boot.kernelPackages.nvidiaPackages.stable;
  #   prime = {
  #     offload.enable = true;
  #     offload.enableOffloadCmd = true; # gives you `nvidia-offload <cmd>`
  #     intelBusId = "PCI:0:2:0";
  #     nvidiaBusId = "PCI:1:0:0";
  #   };
  # };
}
