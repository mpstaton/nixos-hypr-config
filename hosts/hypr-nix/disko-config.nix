{
  # Declarative disk partitioning (nix-community/disko).
  # Adapted from disko-templates#single-disk-ext4 — GPT + ESP + ext4 root,
  # works on both BIOS and UEFI, pairs with systemd-boot below.
  #
  # BEFORE INSTALLING: boot the installer, run `lsblk`, and set `device`
  # below to your actual disk (e.g. "/dev/nvme0n1", "/dev/sda"). Everything
  # on that disk will be destroyed.
  disko.devices = {
    disk = {
      main = {
        type = "disk";
        device = "/dev/nvme0n1"; # CHANGE ME — verify with `lsblk` before running disko
        content = {
          type = "gpt";
          partitions = {
            ESP = {
              size = "1G";
              type = "EF00";
              content = {
                type = "filesystem";
                format = "vfat";
                mountpoint = "/boot";
                mountOptions = [ "umask=0077" ];
              };
            };
            root = {
              size = "100%";
              content = {
                type = "filesystem";
                format = "ext4";
                mountpoint = "/";
              };
            };
          };
        };
      };
    };
  };
}
