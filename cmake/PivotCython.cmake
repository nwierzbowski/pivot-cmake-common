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

    message(STATUS "Link to blender: " ${LINK_TO_BLENDER})
    message(STATUS "Symlinking ${PIVOT_SYMLINK_SOURCE_PATH} to Blender site-packages at ${PIVOT_SYMLINK_BLENDER_SITE_PACKAGES}/${PIVOT_SYMLINK_PACKAGE_NAME}")
    
    if(LINK_TO_BLENDER AND PIVOT_SYMLINK_BLENDER_SITE_PACKAGES)
        add_custom_command(TARGET ${PIVOT_SYMLINK_TARGET_NAME} POST_BUILD
            COMMAND ${CMAKE_COMMAND} -E rm -rf "${PIVOT_SYMLINK_BLENDER_SITE_PACKAGES}/${PIVOT_SYMLINK_PACKAGE_NAME}"
            COMMAND ${CMAKE_COMMAND} -E create_symlink "${PIVOT_SYMLINK_SOURCE_PATH}" "${PIVOT_SYMLINK_BLENDER_SITE_PACKAGES}/${PIVOT_SYMLINK_PACKAGE_NAME}"
            COMMENT "Creating symlink to Blender site-packages for development"
        )
    endif()
endfunction()
