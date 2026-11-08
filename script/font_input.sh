#!/usr/bin/env bash
# Shared font selection for packaging and isolated development bundles.
select_font() {
    local root="$1" requirement="$2"
    LOVELYGLOW_FONT_ROOT="$root"
    LOVELYGLOW_SELECTED_FONT=""
    LOVELYGLOW_SELECTED_NOTICES=""
    LOVELYGLOW_USING_PRIVATE_FONT=0
    local selection rest configured_font configured_notices
    selection="$(/usr/bin/python3 "$root/script/font_config.py" "$root")" || return 1
    configured_font="${selection%%$'\n'*}"
    rest="${selection#*$'\n'}"
    configured_notices="${rest%%$'\n'*}"
    if [[ -n "$configured_font" ]]; then
        LOVELYGLOW_USING_PRIVATE_FONT=1
        LOVELYGLOW_SELECTED_FONT="$configured_font"
        LOVELYGLOW_SELECTED_NOTICES="$configured_notices"
    else
        local pinned="$root/Resources/Fonts/DeparturePixelZhCompact-Regular.ttf"
        if [[ "$requirement" == optional && ! -e "$pinned" && ! -L "$pinned" ]]; then
            return 0
        fi
        /usr/bin/python3 "$root/script/get_compact_font.py" --check || return 1
        LOVELYGLOW_SELECTED_FONT="$pinned"
    fi
    /usr/bin/swift "$root/script/validate_font.swift" "$LOVELYGLOW_SELECTED_FONT" || return 1
    if [[ -n "$LOVELYGLOW_SELECTED_NOTICES" ]]; then
        /usr/bin/python3 "$root/script/validate_font_notices.py" "$LOVELYGLOW_SELECTED_NOTICES" || return 1
    fi
}

copy_selected_font() {
    /bin/cp "$LOVELYGLOW_SELECTED_FONT" "$1" || return 1
    /usr/bin/swift "$LOVELYGLOW_FONT_ROOT/script/validate_font.swift" "$1"
}

copy_font_notices() {
    local destination="$1"
    if [[ "$LOVELYGLOW_USING_PRIVATE_FONT" == 1 ]]; then
        /bin/mkdir -p "$destination" || return 1
        if [[ -n "$LOVELYGLOW_SELECTED_NOTICES" ]]; then
            /usr/bin/ditto "$LOVELYGLOW_SELECTED_NOTICES" "$destination/PrivateFont" || return 1
            /usr/bin/python3 "$LOVELYGLOW_FONT_ROOT/script/validate_font_notices.py" "$destination/PrivateFont" || return 1
            printf '%s\n' 'Locally supplied font; supplied notices are in PrivateFont/.' > "$destination/LOCAL-FONT.txt" || return 1
        else
            printf '%s\n' 'Locally supplied font; no notices were supplied.' > "$destination/LOCAL-FONT.txt" || return 1
        fi
    else
        /usr/bin/ditto "$LOVELYGLOW_FONT_ROOT/Resources/Licenses/" "$destination/" || return 1
    fi
}
