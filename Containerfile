# FirefoxOS — a Universal Blue image built around Firefox web apps (PWAs),
# Waydroid, and a classic "XP-style" Wayland desktop (labwc + waybar + a
# custom Start menu).

# Build context: scripts and files are bind-mounted, never copied as layers
FROM scratch AS ctx
COPY build_files /
COPY system_files /system_files

# Universal Blue's desktop-less Fedora Atomic base.
# It already ships the ublue tooling (ujust, flatpak setup, codecs, RPM Fusion).
FROM ghcr.io/ublue-os/base-main:latest

RUN --mount=type=bind,from=ctx,source=/,target=/ctx \
    --mount=type=cache,dst=/var/cache \
    --mount=type=cache,dst=/var/log \
    --mount=type=tmpfs,dst=/tmp \
    /ctx/build.sh

### LINTING
RUN bootc container lint
