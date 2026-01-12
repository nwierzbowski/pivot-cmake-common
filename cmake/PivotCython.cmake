include_guard(GLOBAL)

function(pivot_common_cython_add_blender_symlink)
    set(oneValueArgs TARGET_NAME SOURCE_PATH PACKAGE_NAME BLENDER_SITE_PACKAGES)
    cmake_parse_arguments(PIVOT_SYMLINK "" "${oneValueArgs}" "" ${ARGN})

    if(NOT PIVOT_SYMLINK_TARGET_NAME)
        message(FATAL_ERROR "pivot_common_cython_add_blender_symlink requires TARGET_NAME")
    endif()
    if(NOT PIVOT_SYMLINK_SOURCE_PATH)
        message(FATAL_ERROR "pivot_common_cython_add_blender_symlink requires SOURCE_PATH")
    endif()
    if(NOT PIVOT_SYMLINK_PACKAGE_NAME)
        message(FATAL_ERROR "pivot_common_cython_add_blender_symlink requires PACKAGE_NAME")
    endif()

    if(LINK_TO_BLENDER AND PIVOT_SYMLINK_BLENDER_SITE_PACKAGES)
        set(_pivot_target_path "${PIVOT_SYMLINK_BLENDER_SITE_PACKAGES}/${PIVOT_SYMLINK_PACKAGE_NAME}")
        if(EXISTS "${_pivot_target_path}")
            add_custom_command(TARGET ${PIVOT_SYMLINK_TARGET_NAME} POST_BUILD
                COMMAND ${CMAKE_COMMAND} -E rm -rf "${_pivot_target_path}"
                COMMAND ${CMAKE_COMMAND} -E create_symlink "${PIVOT_SYMLINK_SOURCE_PATH}" "${_pivot_target_path}"
                COMMENT "Creating symlink to Blender site-packages for development"
            )
        else()
            message(STATUS "Skipping Blender symlink for ${PIVOT_SYMLINK_PACKAGE_NAME}: target ${_pivot_target_path} absent")
        endif()
    else()
        if(NOT LINK_TO_BLENDER)
            message(STATUS "Skipping Blender symlink for ${PIVOT_SYMLINK_PACKAGE_NAME}: LINK_TO_BLENDER is OFF or unset")
        elseif(NOT PIVOT_SYMLINK_BLENDER_SITE_PACKAGES)
            message(STATUS "Skipping Blender symlink for ${PIVOT_SYMLINK_PACKAGE_NAME}: BLENDER_SITE_PACKAGES not set")
        endif()
    endif()
endfunction()
