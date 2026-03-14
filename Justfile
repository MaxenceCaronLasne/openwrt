# Paths
SPARSEBUNDLE   := "/Volumes/My Passport for Mac/OpenWrtBuild.sparsebundle"
BUILD_DIR      := "/Volumes/OpenWrtBuild/openwrt"
ARTIFACTS      := BUILD_DIR / "bin/targets/armvirt/64"

# Check/install build dependencies via Homebrew
deps:
    #!/usr/bin/env bash
    pkgs=(coreutils diffutils findutils gawk gnu-getopt gnu-sed grep wget xz \
          bison flex gettext openssl swig libelf python-setuptools)
    missing=()
    for p in "${pkgs[@]}"; do
        brew list "$p" &>/dev/null || missing+=("$p")
    done
    if [ ${#missing[@]} -gt 0 ]; then
        echo "Installing missing brew packages: ${missing[*]}"
        brew install "${missing[@]}"
    else
        echo "All build dependencies present."
    fi

# First-time setup: feeds + defconfig
setup: _check-drive
    #!/usr/bin/env bash
    set -euo pipefail
    cd "{{BUILD_DIR}}"
    ./scripts/feeds update -a
    ./scripts/feeds install -a
    cp diffconfig .config
    make defconfig

# Incremental build
build: _check-drive
    #!/usr/bin/env bash
    # Strip GNU binutils from PATH — its ar/ranlib produce GNU-format archives
    # that macOS ld cannot read. Homebrew's GNU make stays because it's not in binutils.
    SAFE_PATH="$(printf '%s' "$PATH" | tr ':' '\n' | grep -v 'binutils' | paste -sd':')"
    cd "{{BUILD_DIR}}" && PATH="$SAFE_PATH" make -j$(sysctl -n hw.logicalcpu) V=sc

# Full clean rebuild
build-clean: _check-drive
    #!/usr/bin/env bash
    SAFE_PATH="$(printf '%s' "$PATH" | tr ':' '\n' | grep -v 'binutils' | paste -sd':')"
    cd "{{BUILD_DIR}}" && PATH="$SAFE_PATH" make clean
    just build

# Wipe Linux host tools so they rebuild natively for macOS
clean-host: _check-drive
    cd "{{BUILD_DIR}}" && make dirclean

# Interactive shell in build directory
shell: _check-drive
    cd "{{BUILD_DIR}}" && exec bash

# Boot QEMU with HVF acceleration
run: _check-artifacts
    #!/usr/bin/env bash
    IMG="{{ARTIFACTS}}/openwrt-armvirt-64-rootfs-ext4.img"
    if [ ! -f "$IMG" ]; then
        gunzip -k "{{ARTIFACTS}}/openwrt-armvirt-64-rootfs-ext4.img.gz"
    fi
    qemu-system-aarch64 \
        -M virt,accel=hvf -cpu host -m 256 \
        -kernel "{{ARTIFACTS}}/openwrt-armvirt-64-Image" \
        -append "root=/dev/vda rootwait console=ttyAMA0" \
        -drive file="$IMG",format=raw,if=virtio \
        -nographic \
        -netdev user,id=net0,hostfwd=tcp::1122-:22 \
        -device virtio-net-pci,netdev=net0
    echo "→ SSH: ssh -p 1122 root@localhost"

# Fresh QEMU run (discards VM disk state)
run-fresh: _check-artifacts
    rm -f "{{ARTIFACTS}}/openwrt-armvirt-64-rootfs-ext4.img"
    just run

_mount:
    #!/usr/bin/env bash
    if [ ! -d "{{BUILD_DIR}}" ]; then
        if [ ! -e "{{SPARSEBUNDLE}}" ]; then
            echo "Creating case-sensitive build volume (60 GB sparse)..."
            hdiutil create -size 60g -type SPARSEBUNDLE \
                -fs "Case-sensitive APFS" -volname OpenWrtBuild \
                "{{SPARSEBUNDLE}}"
        fi
        hdiutil attach "{{SPARSEBUNDLE}}"
    fi

_check-drive: _mount
    #!/usr/bin/env bash
    if [ ! -d "{{BUILD_DIR}}" ]; then
        echo "ERROR: Build volume not mounted at {{BUILD_DIR}}" >&2; exit 1
    fi

_check-artifacts:
    #!/usr/bin/env bash
    if [ ! -f "{{ARTIFACTS}}/openwrt-armvirt-64-Image" ]; then
        echo "ERROR: Build artifacts not found. Run 'just build' first." >&2; exit 1
    fi
