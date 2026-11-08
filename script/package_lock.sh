#!/usr/bin/env bash
# The entrypoint is re-executed with a guard fd; nested stages inherit it.
acquire_package_lock() {
    /usr/bin/python3 "$ROOT_DIR/script/package_guard.py" "$ROOT_DIR" --verify
}
release_package_lock() {
    if [[ "${LOVELYGLOW_GUARD_OWNER_PID:-}" == "$$" ]]; then
        /usr/bin/python3 "$ROOT_DIR/script/package_guard.py" "$ROOT_DIR" --release "$$"
    fi
}
