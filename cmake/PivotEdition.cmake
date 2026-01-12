include_guard(GLOBAL)

# Sets edition-specific compile definitions for a target.
# This centralizes the logic for PIVOT_EDITION_PRO, PIVOT_EDITION_STANDARD, and PIVOT_EDITION_NAME.
function(pivot_common_set_edition_defines target edition)
    if(edition STREQUAL "PRO")
        target_compile_definitions(${target} PRIVATE PIVOT_EDITION_PRO)
    else()
        target_compile_definitions(${target} PRIVATE PIVOT_EDITION_STANDARD)
    endif()
    target_compile_definitions(${target} PRIVATE PIVOT_EDITION_NAME=\"${edition}\")
endfunction()