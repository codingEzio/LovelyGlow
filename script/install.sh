#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck disable=SC1091
source "$ROOT_DIR/script/product_config.sh"
load_product_config "$ROOT_DIR/config/product.conf"

BUILT_APP="$ROOT_DIR/dist/$APP_BUNDLE_NAME.app"
APP_PARENT="$HOME/Applications"
APP_BUNDLE="$APP_PARENT/$APP_BUNDLE_NAME.app"
APP_BINARY="$APP_BUNDLE/Contents/MacOS/$EXECUTABLE_NAME"

path_present() {
    [[ -e "$1" || -L "$1" ]]
}

process_ids_for_path() {
    local path="$1"
    /bin/ps -axo pid=,command= | /usr/bin/awk \
        -v expected="$path" -v self="$$" '$1 != self && $2 == expected { print $1 }'
}

designated_requirement() {
    local output requirement
    output="$(/usr/bin/codesign -d -r- "$1" 2>&1)" || {
        echo "install.sh: could not read designated requirement from $1" >&2
        return 1
    }
    requirement="$(printf '%s\n' "$output" | /usr/bin/sed -n 's/^designated => //p')"
    [[ -n "$requirement" ]] || {
        echo "install.sh: designated requirement is empty for $1" >&2
        return 1
    }
    printf '%s\n' "$requirement"
}

verify_bundle() {
    local bundle="$1"
    [[ -d "$bundle" ]] || {
        echo "install.sh: missing app bundle $bundle" >&2
        return 1
    }
    [[ -x "$bundle/Contents/MacOS/$EXECUTABLE_NAME" ]] || {
        echo "install.sh: missing app executable in $bundle" >&2
        return 1
    }
    /usr/bin/codesign --verify --deep --strict --verbose=2 "$bundle" >/dev/null
    /usr/bin/plutil -lint "$bundle/Contents/Info.plist" >/dev/null
    [[ "$(/usr/bin/plutil -extract CFBundleIdentifier raw "$bundle/Contents/Info.plist")" == "$BUNDLE_ID" ]] || {
        echo "install.sh: bundle identifier mismatch in $bundle" >&2
        return 1
    }
}

wait_for_process_exit() {
    local attempts=0
    while (( attempts < 40 )); do
        if [[ -z "$(process_ids_for_path "$APP_BINARY")" ]]; then
            return 0
        fi
        /bin/sleep 0.1
        attempts=$((attempts + 1))
    done
    echo "install.sh: installed Lovely Glow did not exit" >&2
    return 1
}

stop_installed_process() {
    local pid
    while read -r pid; do
        [[ -n "$pid" ]] || continue
        /bin/kill -TERM "$pid"
    done < <(process_ids_for_path "$APP_BINARY")
    wait_for_process_exit
}

install_app() {
    local staging_root previous_root staging_app previous_app
    local candidate_requirement installed_requirement
    local deployment_started=0 deployment_succeeded=0
    local app_replaced=0 exit_status

    verify_bundle "$BUILT_APP"
    candidate_requirement="$(designated_requirement "$BUILT_APP")"

    /bin/mkdir -p "$APP_PARENT"
    staging_root="$(/usr/bin/mktemp -d "$APP_PARENT/.lovelyglow.staging.XXXXXX")"
    previous_root="$(/usr/bin/mktemp -d "$APP_PARENT/.lovelyglow.previous.XXXXXX")"
    staging_app="$staging_root/$APP_BUNDLE_NAME.app"
    previous_app="$previous_root/$APP_BUNDLE_NAME.app"

    cleanup() {
        exit_status=$?
        trap - EXIT HUP INT TERM
        if (( deployment_started == 1 && deployment_succeeded != 1 )); then
            process_ids_for_path "$APP_BINARY" | while read -r pid; do
                [[ -n "$pid" ]] && /bin/kill -TERM "$pid" || true
            done
            if (( app_replaced == 1 )); then
                path_present "$APP_BUNDLE" && /bin/mv "$APP_BUNDLE" "$staging_root/Failed $APP_BUNDLE_NAME.app" || true
                path_present "$previous_app" && /bin/mv "$previous_app" "$APP_BUNDLE" || true
            fi
        fi
        /bin/rm -rf -- "$staging_root" "$previous_root"
        exit "$exit_status"
    }
    trap cleanup EXIT HUP INT TERM

    /usr/bin/ditto "$BUILT_APP" "$staging_app"
    verify_bundle "$staging_app"
    [[ "$(designated_requirement "$staging_app")" == "$candidate_requirement" ]]

    if path_present "$APP_BUNDLE"; then
        verify_bundle "$APP_BUNDLE"
        installed_requirement="$(designated_requirement "$APP_BUNDLE")"
        [[ "$candidate_requirement" == "$installed_requirement" ]] || {
            echo "install.sh: candidate signing requirement differs from $APP_BUNDLE" >&2
            exit 1
        }
        /usr/bin/env python3 "$ROOT_DIR/script/migrate_settings.py" "$APP_BUNDLE" --check
    fi

    deployment_started=1
    stop_installed_process
    if path_present "$APP_BUNDLE"; then
        /usr/bin/env python3 "$ROOT_DIR/script/migrate_settings.py" "$APP_BUNDLE"
    fi

    if path_present "$APP_BUNDLE"; then
        /bin/mv "$APP_BUNDLE" "$previous_app"
    fi
    app_replaced=1
    /bin/mv "$staging_app" "$APP_BUNDLE"

    verify_bundle "$APP_BUNDLE"
    deployment_succeeded=1
    trap - EXIT HUP INT TERM
    /bin/rm -rf -- "$staging_root" "$previous_root"
    echo "Installed $APP_BUNDLE"
}

"$ROOT_DIR/script/build_and_run.sh" --stage
install_app
if [[ "${LOVELYGLOW_DIAGNOSTICS:-0}" == "1" ]]; then
    /usr/bin/open --env LOVELYGLOW_DIAGNOSTICS=1 "$APP_BUNDLE"
else
    /usr/bin/open "$APP_BUNDLE"
fi
