#!/usr/bin/env bash
# Shared font selection for packaging and isolated development bundles.
select_font() {
    local root="$1" requirement="$2"
    LOVELYGLOW_FONT_ROOT="$root"
    LOVELYGLOW_SELECTED_FONT=""
    if [[ ${LOVELYGLOW_PRIVATE_FONT+x} ]]; then
        [[ -n "$LOVELYGLOW_PRIVATE_FONT" ]] || { echo 'Private font path is empty.' >&2; return 1; }
        LOVELYGLOW_SELECTED_FONT="$LOVELYGLOW_PRIVATE_FONT"
        [[ "$LOVELYGLOW_SELECTED_FONT" = /* ]] || LOVELYGLOW_SELECTED_FONT="$PWD/$LOVELYGLOW_SELECTED_FONT"
    else
        local pinned="$root/Resources/Fonts/DeparturePixelZhCompact-Regular.ttf"
        if [[ "$requirement" == optional && ! -e "$pinned" && ! -L "$pinned" ]]; then
            return 0
        fi
        /usr/bin/python3 "$root/script/get_compact_font.py" --check || return 1
        LOVELYGLOW_SELECTED_FONT="$pinned"
    fi
    /usr/bin/swift "$root/script/validate_font.swift" "$LOVELYGLOW_SELECTED_FONT"
}

copy_selected_font() {
    /bin/cp "$LOVELYGLOW_SELECTED_FONT" "$1" || return 1
    /usr/bin/swift "$LOVELYGLOW_FONT_ROOT/script/validate_font.swift" "$1"
}
