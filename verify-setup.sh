#!/bin/bash
# ============================================================================
# MirrorRepos — setup verification
# ============================================================================
# Checks everything the mirror solution needs on this host:
#   1. host tools            4. config files        7. firewall rules
#   2. rootless podman setup 5. SELinux             8. webserver runtime
#   3. data directories      6. container images    9. mirrored content
#
# Read-only by default: without flags this script changes nothing.
# Usage:  bash verify-setup.sh [--fix]
#   --fix   attempt to repair failures that have a known fix (may use sudo)
# ============================================================================

PASS=0; WARN=0; FAIL=0
FAILED=()
FIX=0
[[ "${1:-}" == "--fix" ]] && FIX=1

section() { echo; echo "== $1 =="; }
ok()   { echo "  [ ✅ ] $1"; PASS=$((PASS+1)); }
warn() { echo "  [ ⚠️  ] $1"; WARN=$((WARN+1)); }
fail() { echo "  [ ❌ ] $1"; FAILED+=("$1"); FAIL=$((FAIL+1)); }

# --- 1. Host tools -------------------------------------------------------------
section "Host tools"
for cmd in podman curl tar unzip openssl; do
    if command -v "$cmd" >/dev/null 2>&1; then
        ok "'$cmd' found ($(command -v "$cmd"))"
    else
        fail "'$cmd' missing — install: sudo dnf install -y $cmd"
    fi
done
if command -v terraform >/dev/null 2>&1; then
    ok "'terraform' found ($(terraform version 2>/dev/null | head -1))"
else
    warn "'terraform' not installed on the host — only needed for standalone provider mirroring (the terraform-mirror container includes it)"
fi

# --- 2. Rootless podman ---------------------------------------------------------
section "Rootless podman"
if grep -q "^$USER:" /etc/subuid 2>/dev/null && grep -q "^$USER:" /etc/subgid 2>/dev/null; then
    ok "subuid/subgid ranges allocated for '$USER'"
else
    warn "no subuid/subgid range for '$USER' — see README.md Prerequisites (rootless containers)"
fi

# --- 3. Data directories ---------------------------------------------------------
section "Data directories (/data)"
for d in /data/repo/packages /data/log /data/config /data/config-terraform; do
    if [[ ! -d $d ]]; then
        fail "$d missing — create: sudo mkdir -p $d"
    elif [[ -w $d ]]; then
        ok "$d exists and is writable by $USER"
    else
        warn "$d exists but is NOT writable by $USER — fix: sudo chown -R $USER:$USER $d"
    fi
    # every file inside must be owned by the container user as well —
    # rootless podman cannot SELinux-relabel (:z) files owned by root:
    # "lsetxattr ... operation not permitted" when the container starts
    stray="$(find "$d" ! -user "$USER" -print -quit 2>/dev/null)"
    if [[ -n $stray ]]; then
        fail "$d contains files not owned by $USER (e.g. $stray) — fix: sudo chown -R $USER:$USER $d"
    fi
done

# --- 4. Configuration files ------------------------------------------------------
section "Configuration files"
[[ -f /data/config/all.repos ]]               && ok "/data/config/all.repos present"               || fail "/data/config/all.repos missing — copy: sudo cp -r repo-mirror/config/. /data/config/"
[[ -d /data/config/repos ]]                   && ok "/data/config/repos/ present"                  || fail "/data/config/repos/ missing — copy: sudo cp -r repo-mirror/config/. /data/config/"
[[ -f /data/config-terraform/all.providers ]] && ok "/data/config-terraform/all.providers present" || fail "/data/config-terraform/all.providers missing — copy: sudo cp -r terraform-mirror/config/. /data/config-terraform/"
[[ -f /data/config-terraform/all.modules ]]   && ok "/data/config-terraform/all.modules present"   || fail "/data/config-terraform/all.modules missing — copy: sudo cp -r terraform-mirror/config/. /data/config-terraform/"

# --- 5. SELinux -------------------------------------------------------------------
section "SELinux"
if command -v getenforce >/dev/null 2>&1; then
    mode="$(getenforce)"
    if [[ $mode == Enforcing ]]; then
        ok "SELinux is Enforcing — container volume mounts use the ':z' flag, so labels are handled"
        warn "if httpd runs on the HOST instead of a container, it needs: sudo semanage fcontext -a -t httpd_sys_content_t \"/data/repo/packages(/.*)?\" && sudo restorecon -Rv /data/repo/packages"
    else
        ok "SELinux mode: $mode"
    fi
else
    warn "getenforce not found — cannot determine SELinux mode"
fi

# --- 6. Container images -----------------------------------------------------------
section "Container images"
check_image() { # $1=image name  $2=build directory
    if podman image exists "localhost/$1:latest" 2>/dev/null; then
        ok "image localhost/$1:latest present"
    else
        fail "image '$1' missing — build: podman build -t $1 $2"
    fi
}
check_image rpm-repo-mirror-base ./repo-mirror-base
check_image rpm-repo-mirror      ./repo-mirror
check_image terraform-mirror     ./terraform-mirror

# --- 7. Firewall rules --------------------------------------------------------------
section "Firewall"
if ! command -v firewall-cmd >/dev/null 2>&1; then
    warn "firewall-cmd not found — cannot inspect the firewall; make sure 8080/tcp (and 8443/tcp for HTTPS) are allowed"
elif ! systemctl is-active --quiet firewalld 2>/dev/null; then
    ok "firewalld is not active — no host firewall blocking the webserver"
else
    open_ports="$(firewall-cmd --list-ports 2>/dev/null)"
    for port in 8080 8443; do
        if echo "$open_ports" | tr ' ' '\n' | grep -qx "$port/tcp"; then
            ok "firewalld: $port/tcp is open"
        elif [[ $FIX -eq 1 ]] && sudo firewall-cmd --add-port=$port/tcp --permanent >/dev/null \
             && sudo firewall-cmd --add-port=$port/tcp >/dev/null; then
            ok "firewalld: $port/tcp was NOT open — opened it (--fix)"
        else
            fail "firewalld: $port/tcp is NOT open — fix: sudo firewall-cmd --add-port=$port/tcp --permanent && sudo firewall-cmd --reload   (or run: $0 --fix)"
        fi
    done
fi

# --- 8. Webserver runtime -------------------------------------------------------------
section "Webserver"
if podman ps --format '{{.Names}}' 2>/dev/null | grep -qx webserver; then
    ok "container 'webserver' is running"
else
    fail "container 'webserver' is not running — start it per README.md Quickstart step 4"
fi
for url in http://localhost:8080/ https://localhost:8443/; do
    code="$(curl -sk -o /dev/null -w '%{http_code}' --max-time 5 "$url")"
    if [[ $code == 200 ]]; then
        ok "$url responds HTTP 200"
    else
        fail "$url responds HTTP '$code'"
    fi
done

# --- 9. Mirrored content ----------------------------------------------------------------
section "Mirrored content"
count=$(find /data/repo/packages -mindepth 1 -maxdepth 1 -type d 2>/dev/null | wc -l)
if [[ $count -gt 0 ]]; then
    ok "/data/repo/packages contains $count top-level directories"
else
    warn "/data/repo/packages is empty — run the mirror containers to populate it"
fi
[[ -d /data/repo/packages/terraform ]] \
    && ok "terraform mirror present under /data/repo/packages/terraform" \
    || warn "no terraform mirror under /data/repo/packages/terraform yet"

# --- Summary -----------------------------------------------------------------------------
section "Summary"
echo "  OK=$PASS  WARN=$WARN  FAIL=$FAIL"
if [[ $FAIL -eq 0 ]]; then
    echo "  All critical checks passed."
    exit 0
fi
echo "  Failed checks:"
for f in "${FAILED[@]}"; do
    echo "   ❌ $f"
done
echo
echo "  Fix the items above, or re-run with --fix where a fix is supported:"
echo "    bash verify-setup.sh --fix"
exit 1
