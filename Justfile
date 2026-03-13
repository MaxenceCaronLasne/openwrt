# Paths
SPARSEBUNDLE   := "/Volumes/My Passport for Mac/OpenWrtBuild.sparsebundle"
EXTERNAL_DRIVE := "/Volumes/OpenWrtBuild"
IMAGE          := "openwrt-builder"
ARTIFACTS      := EXTERNAL_DRIVE / "bin/targets/armvirt/64"

# Build the Docker image (only if missing, or `just image` to force)
image:
    docker build --platform linux/arm64 \
        --build-arg UID=$(id -u) --build-arg GID=$(id -g) \
        -t {{IMAGE}} devenv/

# First-time setup: feeds + defconfig (runs inside container)
setup: _check-drive
    just _run devenv/setup.sh

# Incremental build
build: _check-drive
    just _run make -j$(nproc) V=sc

# Full clean rebuild
build-clean: _check-drive
    just _run make clean
    just build

# Interactive shell inside container
shell: _check-drive
    just _run --shell

# Boot QEMU with HVF acceleration (runs on macOS host)
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

# Internal: run a command (or shell) inside the Docker container
_run *ARGS:
    #!/usr/bin/env bash
    DRIVE="{{EXTERNAL_DRIVE}}"
    if [[ "{{ARGS}}" == "--shell" ]]; then
        CMD="bash"
        FLAGS="-it"
    else
        CMD="{{ARGS}}"
        FLAGS=""
    fi
    DEPLOY_KEY="$HOME/.ssh/id_ed25519_dendro_deploy"
    if [ ! -f "$DEPLOY_KEY" ]; then
        echo "ERROR: Deploy key not found at $DEPLOY_KEY" >&2
        echo "Run: ssh-keygen -t ed25519 -f $DEPLOY_KEY -N \"\"" >&2
        echo "Then add the public key as a deploy key on the dendro GitHub repo." >&2
        exit 1
    fi
    docker run --rm $FLAGS --platform linux/arm64 \
        -v "$DRIVE:/build" \
        -v "$DEPLOY_KEY:/home/builder/.ssh/id_ed25519:ro" \
        -e GIT_SSH_COMMAND="ssh -i /home/builder/.ssh/id_ed25519 -o StrictHostKeyChecking=accept-new" \
        {{IMAGE}} $CMD

_mount:
    #!/usr/bin/env bash
    if [ ! -d "{{EXTERNAL_DRIVE}}" ]; then
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
    if [ ! -d "{{EXTERNAL_DRIVE}}" ]; then
        echo "ERROR: Build volume not mounted at {{EXTERNAL_DRIVE}}" >&2; exit 1
    fi

_check-artifacts:
    #!/usr/bin/env bash
    if [ ! -f "{{ARTIFACTS}}/openwrt-armvirt-64-Image" ]; then
        echo "ERROR: Build artifacts not found. Run 'just build' first." >&2; exit 1
    fi
