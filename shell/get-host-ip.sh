#!/bin/bash
# Print the IP at which the host machine is reachable from where this runs.
# Prints only the IP on stdout and writes nothing; see update-host-ip.sh for
# the similar detection plus .mcp.json/.env updates.
#
#   On the host itself (macOS, or a Linux machine that isn't a container):
#     127.0.0.1 — it loops back to itself.
#   In a container (Apple `container`, Docker, Podman): the host is the
#     container network's default gateway, read from /proc/net/route so it
#     needs no `ip`/iproute2 (slim images often lack it). Deliberately NOT
#     the /etc/resolv.conf nameserver: that is Docker's embedded DNS
#     (127.0.0.11) or Tailscale's (100.100.100.100) on many setups, and only
#     happens to equal the gateway on Apple `container`.
#
# "In a container": /.dockerenv or /run/.containerenv, or PID 1 isn't an init
# system. Apple `container` runs each container in its own VM and leaves no
# marker file, so PID 1 (e.g. tini) is the signal there.
set -e

in_container() {
    [ -e /.dockerenv ] || [ -e /run/.containerenv ] && return 0
    [ "$(uname -s)" = Linux ] || return 1
    case "$(cat /proc/1/comm 2>/dev/null)" in
        systemd|init|launchd|"") return 1 ;;
        *) return 0 ;;
    esac
}

if ! in_container; then
    echo 127.0.0.1
    exit 0
fi

# Default route = the line whose destination is 00000000; the gateway column
# is little-endian hex. Pure bash: slim images often have neither iproute2 nor
# an awk with strtonum (Debian's mawk).
HOST_IP=""
while read -r _ dest gw _; do
    if [ "$dest" = "00000000" ]; then
        HOST_IP=$(printf '%d.%d.%d.%d' "0x${gw:6:2}" "0x${gw:4:2}" "0x${gw:2:2}" "0x${gw:0:2}")
        break
    fi
done < <(tail -n +2 /proc/net/route 2>/dev/null)

# Last resort if /proc/net/route is unreadable.
if [ -z "$HOST_IP" ]; then
    HOST_IP=$(ip route show default 2>/dev/null | awk '{print $3; exit}')
fi

if ! echo "$HOST_IP" | grep -qE '^([0-9]{1,3}\.){3}[0-9]{1,3}$'; then
    echo "get-host-ip: could not determine host IP from the default route" >&2
    exit 1
fi

echo "$HOST_IP"
