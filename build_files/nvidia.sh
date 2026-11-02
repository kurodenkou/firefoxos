#!/usr/bin/bash
# NVIDIA variant (firox-nvidia-open): install Universal Blue's prebuilt,
# signed open NVIDIA kernel module + driver from ghcr.io/ublue-os/akmods-nvidia-open
# (bind-mounted at /akmods). Called from build.sh when FIROX_VARIANT=nvidia.
set -ouex pipefail

AKMODNV_PATH=/akmods/rpms
if [ ! -f "${AKMODNV_PATH}/kmods/nvidia-vars" ]; then
    echo "No NVIDIA akmods at ${AKMODNV_PATH}: build with 'just build-nvidia'." >&2
    exit 1
fi
# shellcheck source=/dev/null
source "${AKMODNV_PATH}/kmods/nvidia-vars"

# The module is built for one exact kernel; refuse to ship a mismatch.
KERNEL="$(rpm -q kernel --queryformat '%{VERSION}-%{RELEASE}.%{ARCH}\n' | tail -n1)"
if [ "${KERNEL}" != "${KERNEL_VERSION}" ]; then
    echo "Kernel mismatch: image has ${KERNEL}, NVIDIA modules are for ${KERNEL_VERSION}." >&2
    echo "Use 'just build-nvidia', which picks the matching akmods tag." >&2
    exit 1
fi

# Universal Blue's installer: driver, kmod, container toolkit, VA-API,
# 32-bit libs, and early (initramfs) loading via dracut config.
IMAGE_NAME=firox AKMODNV_PATH="${AKMODNV_PATH}" bash "${AKMODNV_PATH}/ublue-os/nvidia-install.sh"

# Kernel arguments, applied by bootc when switching to this image
install -Dm0644 /dev/stdin /usr/lib/bootc/kargs.d/00-nvidia.toml <<'KARGS'
kargs = ["rd.driver.blacklist=nouveau", "modprobe.blacklist=nouveau", "nvidia-drm.modeset=1"]
KARGS

# The dracut change above only takes effect once the initramfs is rebuilt.
# /root links to /var/roothome, which only exists on a booted system;
# create it for dracut so it doesn't log "installing '/root'" errors.
roothome_created=0
if [ ! -e /var/roothome ]; then mkdir -p /var/roothome; roothome_created=1; fi
/usr/bin/dracut --no-hostonly --kver "${KERNEL}" --reproducible --add ostree \
    -f "/usr/lib/modules/${KERNEL}/initramfs.img"
chmod 0600 "/usr/lib/modules/${KERNEL}/initramfs.img"
if [ "${roothome_created}" = 1 ]; then rmdir /var/roothome; fi

# Branding
sed -i \
    -e 's/^PRETTY_NAME="\(.*\))"$/PRETTY_NAME="\1, NVIDIA)"/' \
    /usr/lib/os-release
grep -q '^VARIANT_ID=' /usr/lib/os-release && sed -i 's/^VARIANT_ID=.*/VARIANT_ID=nvidia/' /usr/lib/os-release \
    || echo 'VARIANT_ID=nvidia' >> /usr/lib/os-release
