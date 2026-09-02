# my-nix

Portable, encrypted NixOS configuration for a 2 TB Samsung T7 Shield. The system is a self-contained UEFI daily driver with DriftWM, Home Manager, LUKS2, Btrfs snapshots, a generic Intel/AMD graphics profile, a modern dedicated-NVIDIA specialization, and a machine-specific Intel/NVIDIA PRIME-offload specialization.

## Safety boundary

`scripts/install-t7.sh` is destructive. It is permanently bound to this exact disk:

```text
/dev/disk/by-id/usb-Samsung_PSSD_T7_Shield_S6NSNJ0W901819H-0:0
serial: S6NSNJ0W901819H
```

The installer validates the by-id path, model, serial, 2 TB capacity, whole-disk type, and running root device. It builds and verifies the complete NixOS system closure before asking for the exact phrase `ERASE S6NSNJ0W901819H`. Installation uses that already-built closure, so it does not evaluate the flake or require network access after erasure.

Snapshots are not backups. This repository does not configure an off-device backup destination.

## Layout

- GPT disk with an 8 GiB FAT32 EFI System Partition.
- GRUB at the removable-media path `EFI/BOOT/BOOTX64.EFI`; host EFI variables are never changed.
- One passphrase-only LUKS2 partition using the rest of the disk.
- Btrfs subvolumes for `/`, `/home`, `/nix`, `/var/log`, and independent root/home snapshot stores.
- UUID-based mounts, Zstandard compression, no atime updates, and no discard because this enclosure currently advertises no USB TRIM support.

The UUID values in `hosts/portable/storage.nix` are non-secret and deliberately fixed. The installer applies those exact values while formatting.

## Validate without changing the SSD

Run from the repository root:

```bash
nix flake check
nix build .#nixosConfigurations.portable.config.system.build.toplevel
./scripts/install-t7.sh --preflight-only
```

The preflight command only inspects the target and makes no changes.

## Install from the current Ubuntu host

Close files and terminals using `/media/nop/T7 Shield`, then run as the normal `nop` user:

```bash
./scripts/install-t7.sh
```

Do not prefix the command with `sudo`. The script enters a Nix shell when Ubuntu lacks installation tools and elevates only individual privileged operations. You will be prompted for:

1. The exact destructive confirmation phrase.
2. Your Ubuntu sudo password.
3. A new LUKS passphrase, entered twice. Use characters available on the US boot keymap.
4. A login password for the NixOS user `nop`.

If any step fails, the cleanup trap unmounts `/mnt` and closes `cryptroot`. The disk may already have been erased, so correct the reported problem and rerun the same installer; it will require the destructive phrase again.

If installation and the bootloader completed but only the final login-password step failed, do not reinstall. Recover non-destructively with:

```bash
./scripts/install-t7.sh --set-password-only
```

To deploy a corrected configuration from another Linux installation without formatting the portable disk, use:

```bash
./scripts/install-t7.sh --update-existing
```

## First boot

1. Shut the computer down completely. Never unplug the SSD while mounted.
2. In firmware settings, enable UEFI boot and disable Secure Boot.
3. Select the Samsung T7 Shield from the one-time boot menu.
4. Enter the LUKS passphrase using the US keyboard layout.
5. Select the GPU entry appropriate for the host, using the table below.
6. Log in as `nop` through tuigreet and select DriftWM. TTYs remain available with `Ctrl+Alt+F2` and later function keys.

| Boot entry | Use case |
| --- | --- |
| Ordinary generation | Intel/AMD graphics, unknown hardware, or recovery |
| `nvidia` | Dedicated NVIDIA graphics or a laptop switched to dGPU-only mode in firmware |
| `nvidia-intel-offload` | The current ASUS laptop with Intel `00:02.0` and NVIDIA `01:00.0` |

The generic profile intentionally does not enable NixOS's NVIDIA module. If an NVIDIA boot fails, return to GRUB and use the generic entry for TTY recovery. Both NVIDIA specializations target Turing-or-newer GPUs using Nixpkgs's packaged stable driver and open kernel module.

The PRIME bus IDs in `nvidia-intel-offload` are machine-specific. Do not select it on another hybrid laptop until `lspci -D -d ::03xx` confirms Intel at `0000:00:02.0` and NVIDIA at `0000:01:00.0`. In that profile, Intel renders DriftWM and ordinary applications while the NVIDIA GPU can runtime-suspend until requested.

Run graphics applications on NVIDIA with:

```bash
nvidia-offload blender
nvidia-offload vulkaninfo --summary
nvidia-offload steam
```

For one Steam game, use `nvidia-offload gamemoderun %command%` as its launch option; prefix it with `MANGOHUD=1` to show MangoHud. CUDA programs select NVIDIA independently and do not need `nvidia-offload`. The hybrid profile includes CUDA 12.9 and its compiler, but ML frameworks should remain in project-specific development environments.

After booting the hybrid profile, validate the renderer and compute stack with:

```bash
glxinfo -B | grep -E 'OpenGL vendor|OpenGL renderer'
nvidia-offload glxinfo -B | grep -E 'OpenGL vendor|OpenGL renderer'
nvidia-smi
nvcc --version
```

The first command should report Intel and the offloaded command should report NVIDIA. To check whether the idle GPU suspended, first close NVIDIA workloads and then read `/sys/bus/pci/devices/0000:01:00.0/power/runtime_status`; querying `nvidia-smi` can wake it.

The internal panel is wired to Intel, but some HDMI/DisplayPort connectors appear to be wired to NVIDIA. PRIME sync and reverse sync are not available as equivalent solutions under native Wayland. If an external display is unavailable in offload mode, switch the firmware MUX to dGPU-only mode when supported and boot the `nvidia` entry.

## Desktop behavior

- DriftWM uses US and Russian layouts; `Super+Space` switches layouts.
- `Super+L` locks with swaylock, `Super+Return` opens Foot, and `Super+D` opens Fuzzel.
  Swaylock supplies a transparent lock surface, while the pinned DriftWM fork
  renders the animated canvas background underneath it. DriftWM freezes the
  camera and zoom for the duration of the lock and never composites ordinary
  windows or layer-shell surfaces into the lock frame.
- Waybar, Mako, NetworkManager/Bluetooth applets, and a Polkit agent start with DriftWM.
- `bluetooth-pair-by-name "DEVICE NAME"` scans for an exact, case-insensitive
  Bluetooth name, then interactively pairs, trusts, and connects it.
- Clash Verge Rev provides Mihomo profiles, system proxying, and system-wide TUN mode through a hardened NixOS service.
- Suspend, hibernate, hybrid sleep, and suspend-then-hibernate are disabled. There is no persistent swap or resume device; zram is used under memory pressure.
- SSH is disabled. Wi-Fi credentials and the desktop keyring live only on the encrypted system.

## Updating and rollback

From the installed system:

```bash
cd ~/Projects/my-nix
nix flake update
nix flake check
sudo nixos-rebuild switch --flake .#portable
```

The `nvidia-intel-offload` closure includes Steam and the full CUDA toolkit, so its first build is large. On a limited connection, defer the download and later install the new boot entries without changing the running system with:

```bash
sudo nixos-rebuild boot --flake .#portable
```

Review upstream changes before committing a new `flake.lock`. GRUB keeps ten NixOS generations. Weekly garbage collection removes store objects older than 30 days.

Snapper keeps, for both root and home, 10 hourly, 7 daily, 4 weekly, and 3 monthly snapshots. `/nix` and `/var/log` are separate subvolumes and are not captured by root snapshots. Inspect snapshots with:

```bash
snapper -c root list
snapper -c home list
```

Use a previous GRUB generation for declarative system rollback. Snapshot restoration is a separate administrative operation; inspect the affected snapshot before replacing live data.

## Recovery and verification

Useful checks after boot:

```bash
findmnt / /home /nix /var/log /boot
sudo cryptsetup status cryptroot
sudo btrfs subvolume list /
systemctl status greetd NetworkManager bluetooth
journalctl --user -u driftwm.service
```

Always shut down and wait for power-off before disconnecting the SSD. Sleep is disabled specifically to prevent unplugging a still-mounted portable root filesystem.
