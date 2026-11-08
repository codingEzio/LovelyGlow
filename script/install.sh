#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
path_present() {
    [[ -e "$1" || -L "$1" ]]
}

release_install_lock() {
    if ! path_present "$lg_lock_dir"; then
        echo "install.sh: install lock disappeared: $lg_lock_dir" >&2
        return 1
    fi
    if [[ "$(/usr/bin/stat -f '%d:%i' "$lg_lock_dir")" != "$lg_lock_id" ]] || ! /bin/rmdir "$lg_lock_dir"; then
        echo "install.sh: install lock changed or is not empty; inspect $lg_lock_dir" >&2
        return 1
    fi
}

# Keep the saved previous bundle if either step of restoration fails. The
# caller owns both temporary roots and decides when they can be removed.
restore_previous_app() {
    local app_bundle="$1" previous_app="$2" failed_app="$3" expected_id="$4" previous_saved="$5"
    if (( previous_saved == 1 )) && ! path_present "$previous_app"; then
        echo "install.sh: expected previous bundle is missing; candidate left in place" >&2
        return 1
    fi
    if path_present "$app_bundle"; then
        if [[ -z "$expected_id" || "$(/usr/bin/stat -f '%d:%i' "$app_bundle")" != "$expected_id" ]]; then
            echo "install.sh: destination is not the installed candidate; previous bundle retained at $previous_app" >&2
            return 1
        fi
        if ! /usr/bin/python3 "$ROOT_DIR/script/exclusive_move.py" "$app_bundle" "$failed_app"; then
            echo "install.sh: could not move failed candidate aside; previous bundle retained at $previous_app" >&2
            return 1
        fi
    fi
    if (( previous_saved == 1 )); then
        if ! path_present "$previous_app" || ! /usr/bin/python3 "$ROOT_DIR/script/exclusive_move.py" "$previous_app" "$app_bundle"; then
            echo "install.sh: could not restore previous bundle; recovery directory retained at $(dirname "$previous_app")" >&2
            return 1
        fi
    elif path_present "$previous_app"; then
        echo "install.sh: unexpected previous bundle; retained at $previous_app" >&2
        return 1
    fi
}

recover_failed_install() {
    local app_bundle="$1" previous_app="$2" staging_root="$3" previous_root="$4" failed_name="$5" expected_id="$6" previous_saved="$7"
    local recovered=1
    if ! restore_previous_app "$app_bundle" "$previous_app" "$staging_root/$failed_name" "$expected_id" "$previous_saved"; then
        recovered=0
    fi
    if (( recovered == 1 )); then
        /bin/rm -rf -- "$staging_root"
        /bin/rm -rf -- "$previous_root"
    else
        echo "install.sh: recovery directories retained: $previous_root and $staging_root" >&2
        return 1
    fi
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
    local candidate_requirement installed_requirement
    lg_deployment_started=0 lg_deployment_succeeded=0
    lg_previous_saved=0 lg_previous_move_started=0 lg_candidate_move_started=0 lg_candidate_id="" lg_had_installed=0 lg_installed_id="" lg_exit_status=0 lg_recovery_attempted=0
    lg_staging_root="" lg_previous_root="" lg_staging_app="" lg_previous_app=""

    verify_bundle "$BUILT_APP"
    candidate_requirement="$(designated_requirement "$BUILT_APP")"

    /bin/mkdir -p "$APP_PARENT"
    lg_lock_dir="$APP_PARENT/.lovelyglow.install.lock"
    if ! /bin/mkdir "$lg_lock_dir"; then
        echo "install.sh: another install or a retained lock exists: $lg_lock_dir" >&2
        return 1
    fi
    lg_lock_id="$(/usr/bin/stat -f '%d:%i' "$lg_lock_dir")"

    cleanup() {
        lg_exit_status=$?
        trap - EXIT HUP INT TERM
        if (( lg_deployment_started == 1 && lg_deployment_succeeded != 1 )); then
            # A signal may arrive after the atomic rename but before the next
            # shell assignment. Inspect the owned backup path in that window.
            if (( lg_previous_move_started == 1 && lg_previous_saved == 0 )) && path_present "$lg_previous_app"; then
                lg_previous_saved=1
            fi
            if (( lg_previous_saved == 1 )) && path_present "$lg_previous_app" && [[ "$(/usr/bin/stat -f '%d:%i' "$lg_previous_app")" != "$lg_installed_id" ]]; then
                lg_recovery_attempted=1
                echo "install.sh: previous bundle changed; recovery directory retained: $lg_previous_root" >&2
                /bin/rm -rf -- "$lg_staging_root"
                (( lg_exit_status != 0 )) || lg_exit_status=1
            elif (( lg_previous_saved == 1 || lg_candidate_move_started == 1 )); then
                lg_recovery_attempted=1
                if ! recover_failed_install "$APP_BUNDLE" "$lg_previous_app" "$lg_staging_root" "$lg_previous_root" "Failed $APP_BUNDLE_NAME.app" "$lg_candidate_id" "$lg_previous_saved"; then
                    (( lg_exit_status != 0 )) || lg_exit_status=1
                fi
            elif (( lg_previous_move_started == 1 )) && ! path_present "$APP_BUNDLE"; then
                lg_recovery_attempted=1
                echo "install.sh: previous bundle location is unknown; recovery directory retained: $lg_previous_root" >&2
                /bin/rm -rf -- "$lg_staging_root"
                (( lg_exit_status != 0 )) || lg_exit_status=1
            fi
        fi
        if (( lg_recovery_attempted == 0 )); then
            [[ -z "$lg_staging_root" ]] || /bin/rm -rf -- "$lg_staging_root"
            [[ -z "$lg_previous_root" ]] || /bin/rm -rf -- "$lg_previous_root"
        fi
        release_install_lock || { (( lg_exit_status != 0 )) || lg_exit_status=1; }
        release_package_lock || { (( lg_exit_status != 0 )) || lg_exit_status=1; }
        exit "$lg_exit_status"
    }
    trap cleanup EXIT
    trap 'exit 129' HUP
    trap 'exit 130' INT
    trap 'exit 143' TERM

    lg_staging_root="$(/usr/bin/mktemp -d "$APP_PARENT/.lovelyglow.staging.XXXXXX")"
    lg_previous_root="$(/usr/bin/mktemp -d "$APP_PARENT/.lovelyglow.previous.XXXXXX")"
    lg_staging_app="$lg_staging_root/$APP_BUNDLE_NAME.app"
    lg_previous_app="$lg_previous_root/$APP_BUNDLE_NAME.app"

    /usr/bin/ditto "$BUILT_APP" "$lg_staging_app"
    verify_bundle "$lg_staging_app"
    [[ "$(designated_requirement "$lg_staging_app")" == "$candidate_requirement" ]]

    if path_present "$APP_BUNDLE"; then
        lg_had_installed=1
        lg_installed_id="$(/usr/bin/stat -f '%d:%i' "$APP_BUNDLE")"
        verify_bundle "$APP_BUNDLE"
        installed_requirement="$(designated_requirement "$APP_BUNDLE")"
        [[ "$(/usr/bin/stat -f '%d:%i' "$APP_BUNDLE")" == "$lg_installed_id" ]] || {
            echo "install.sh: installed bundle changed during verification" >&2
            return 1
        }
        [[ "$candidate_requirement" == "$installed_requirement" ]] || {
            echo "install.sh: candidate signing requirement differs from $APP_BUNDLE" >&2
            exit 1
        }
        /usr/bin/env python3 "$ROOT_DIR/script/migrate_settings.py" "$APP_BUNDLE" --check
    fi

    lg_deployment_started=1
    stop_installed_process
    if (( lg_had_installed == 1 )); then
        [[ "$(/usr/bin/stat -f '%d:%i' "$APP_BUNDLE")" == "$lg_installed_id" ]] || {
            echo "install.sh: installed bundle changed before migration" >&2
            return 1
        }
        /usr/bin/env python3 "$ROOT_DIR/script/migrate_settings.py" "$APP_BUNDLE"
    fi

    if (( lg_had_installed == 1 )); then
        lg_previous_move_started=1
        /usr/bin/python3 "$ROOT_DIR/script/exclusive_move.py" "$APP_BUNDLE" "$lg_previous_app"
        lg_previous_saved=1
        [[ "$(/usr/bin/stat -f '%d:%i' "$lg_previous_app")" == "$lg_installed_id" ]] || {
            echo "install.sh: installed bundle changed during replacement" >&2
            return 1
        }
    fi
    lg_candidate_id="$(/usr/bin/stat -f '%d:%i' "$lg_staging_app")"
    lg_candidate_move_started=1
    /usr/bin/python3 "$ROOT_DIR/script/exclusive_move.py" "$lg_staging_app" "$APP_BUNDLE"

    verify_bundle "$APP_BUNDLE"
    [[ "$(/usr/bin/stat -f '%d:%i' "$APP_BUNDLE")" == "$lg_candidate_id" ]] || {
        echo "install.sh: candidate bundle changed during final verification" >&2
        return 1
    }
    lg_deployment_succeeded=1
    /bin/rm -rf -- "$lg_staging_root" "$lg_previous_root"
    release_install_lock
    trap - EXIT HUP INT TERM
    echo "Installed $APP_BUNDLE"
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    # shellcheck disable=SC1091
    source "$ROOT_DIR/script/product_config.sh"
    load_product_config "$ROOT_DIR/config/product.conf"
    BUILT_APP="$ROOT_DIR/dist/$APP_BUNDLE_NAME.app"
    APP_PARENT="$HOME/Applications"
    APP_BUNDLE="$APP_PARENT/$APP_BUNDLE_NAME.app"
    APP_BINARY="$APP_BUNDLE/Contents/MacOS/$EXECUTABLE_NAME"

    # Hold the checkout lock across stage and installation, so another stage
    # cannot replace the verified dist bundle before it is copied.
    # shellcheck disable=SC1091
    if [[ -n "${LOVELYGLOW_GUARD_FD:-}" && "${LOVELYGLOW_GUARD_ROOT:-}" != "$ROOT_DIR" ]]; then
        unset LOVELYGLOW_GUARD_FD LOVELYGLOW_GUARD_TOKEN LOVELYGLOW_GUARD_OWNER_PID LOVELYGLOW_GUARD_ROOT
    fi
    if [[ -z "${LOVELYGLOW_GUARD_FD:-}" ]]; then
        exec /usr/bin/python3 "$ROOT_DIR/script/package_guard.py" "$ROOT_DIR" /bin/bash "$0" "$@"
    fi
    source "$ROOT_DIR/script/package_lock.sh"
    acquire_package_lock
    cleanup_package_lock() {
        local status=$?
        trap - EXIT HUP INT TERM
        release_package_lock || { (( status != 0 )) || status=1; }
        exit "$status"
    }
    trap cleanup_package_lock EXIT
    trap 'exit 129' HUP
    trap 'exit 130' INT
    trap 'exit 143' TERM
    "$ROOT_DIR/script/build_and_run.sh" --stage
    install_app
    release_package_lock
    trap - EXIT HUP INT TERM
    if [[ "${LOVELYGLOW_DIAGNOSTICS:-0}" == "1" ]]; then
        /usr/bin/open --env LOVELYGLOW_DIAGNOSTICS=1 "$APP_BUNDLE"
    else
        /usr/bin/open "$APP_BUNDLE"
    fi
fi
