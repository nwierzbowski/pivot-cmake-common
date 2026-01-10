include_guard(GLOBAL)

function(pivot_common_prepare_dir dir marker_content)
    if("${dir}" STREQUAL "")
        return()
    endif()

    file(MAKE_DIRECTORY "${dir}")
    set(marker "${dir}/.pivot_marker")

    set(should_clean TRUE)
    if(EXISTS "${marker}")
        file(READ "${marker}" existing_marker)
        string(STRIP "${existing_marker}" existing_marker)
        if(existing_marker STREQUAL "${marker_content}")
            set(should_clean FALSE)
        endif()
    endif()

    if(should_clean)
        file(GLOB entries "${dir}/*")
        if(entries)
            file(REMOVE_RECURSE ${entries})
        endif()
    endif()

    file(WRITE "${marker}" "${marker_content}\n")
endfunction()
