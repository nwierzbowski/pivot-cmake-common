include_guard(GLOBAL)

function(pivot_common_cython_find_python)
    if(NOT TARGET Python3::Module)
        find_package(Python3 COMPONENTS Interpreter Development.Module NumPy REQUIRED)
    endif()
    if(NOT CYTHON_EXECUTABLE)
        find_program(CYTHON_EXECUTABLE cython REQUIRED)
    endif()
endfunction()

function(pivot_common_cython_create_modules)
    set(oneValueArgs PYX_ROOT BINARY_DIR WHEEL_PKG_DIR MODULE_TARGETS_VAR OVERRIDE_FUNCTION)
    set(multiValueArgs MODULE_SOURCES INCLUDE_DIRS DEFINES)
    cmake_parse_arguments(PIVOT_CYTHON "" "${oneValueArgs}" "${multiValueArgs}" ${ARGN})

    if(NOT PIVOT_CYTHON_PYX_ROOT)
        message(FATAL_ERROR "pivot_common_cython_create_modules requires PYX_ROOT")
    endif()
    if(NOT PIVOT_CYTHON_BINARY_DIR)
        set(PIVOT_CYTHON_BINARY_DIR "${CMAKE_CURRENT_BINARY_DIR}")
    endif()
    if(NOT PIVOT_CYTHON_WHEEL_PKG_DIR)
        message(FATAL_ERROR "pivot_common_cython_create_modules requires WHEEL_PKG_DIR")
    endif()
    if(NOT PIVOT_CYTHON_MODULE_TARGETS_VAR)
        message(FATAL_ERROR "pivot_common_cython_create_modules requires MODULE_TARGETS_VAR")
    endif()

    pivot_common_cython_find_python()

    set(_cython_include_dirs ${PIVOT_CYTHON_INCLUDE_DIRS})
    list(REMOVE_DUPLICATES _cython_include_dirs)

    set(_module_targets)
    foreach(mod_src IN LISTS PIVOT_CYTHON_MODULE_SOURCES)
        get_filename_component(mod_name "${mod_src}" NAME_WE)
        set(src_path "${PIVOT_CYTHON_PYX_ROOT}/${mod_src}")
        set(out_path "${PIVOT_CYTHON_BINARY_DIR}/${mod_name}.cpp")

        set(_cython_deps "${src_path}")
        set(pxd_file "${PIVOT_CYTHON_PYX_ROOT}/${mod_name}.pxd")
        if(EXISTS "${pxd_file}")
            list(APPEND _cython_deps "${pxd_file}")
        endif()

        set(_cython_cmd "${CYTHON_EXECUTABLE}" --cplus)
        foreach(_inc_dir IN LISTS _cython_include_dirs)
            list(APPEND _cython_cmd -I "${_inc_dir}")
        endforeach()
        list(APPEND _cython_cmd -o "${out_path}" "${src_path}")

        add_custom_command(
            OUTPUT "${out_path}"
            COMMAND ${_cython_cmd}
            DEPENDS ${_cython_deps}
            COMMENT "Cythonizing ${src_path}"
        )

        add_library(${mod_name} MODULE "${out_path}")
        list(APPEND _module_targets ${mod_name})

        if(PIVOT_CYTHON_OVERRIDE_FUNCTION)
            cmake_language(CALL ${PIVOT_CYTHON_OVERRIDE_FUNCTION} ${mod_name})
        endif()

        set_target_properties(${mod_name} PROPERTIES PREFIX "")
        if(WIN32)
            set_target_properties(${mod_name} PROPERTIES SUFFIX ".pyd")
        endif()

        target_link_libraries(${mod_name} PRIVATE Python3::Module)
        if(CMAKE_SYSTEM_NAME MATCHES "Linux")
            target_link_libraries(${mod_name} PRIVATE rt)
        endif()

        if(PIVOT_CYTHON_DEFINES)
            target_compile_definitions(${mod_name} PRIVATE ${PIVOT_CYTHON_DEFINES})
        endif()
        if(_cython_include_dirs)
            target_include_directories(${mod_name} PRIVATE ${_cython_include_dirs})
        endif()

        set_target_properties(${mod_name} PROPERTIES LIBRARY_OUTPUT_DIRECTORY "${PIVOT_CYTHON_WHEEL_PKG_DIR}")
    endforeach()

    set(${PIVOT_CYTHON_MODULE_TARGETS_VAR} ${_module_targets} PARENT_SCOPE)
endfunction()

function(pivot_common_cython_create_wheel_target)
    set(oneValueArgs TARGET_NAME SCRIPT_PATH OUTPUT_DIR WORKING_DIRECTORY COMMENT)
    set(multiValueArgs MODULE_TARGETS)
    cmake_parse_arguments(PIVOT_CYTHON_WHEEL "" "${oneValueArgs}" "${multiValueArgs}" ${ARGN})

    if(NOT PIVOT_CYTHON_WHEEL_TARGET_NAME)
        message(FATAL_ERROR "pivot_common_cython_create_wheel_target needs TARGET_NAME")
    endif()
    if(NOT PIVOT_CYTHON_WHEEL_SCRIPT_PATH)
        message(FATAL_ERROR "pivot_common_cython_create_wheel_target needs SCRIPT_PATH")
    endif()
    if(NOT PIVOT_CYTHON_WHEEL_OUTPUT_DIR)
        message(FATAL_ERROR "pivot_common_cython_create_wheel_target needs OUTPUT_DIR")
    endif()
    pivot_common_cython_find_python()

    set(_working_dir ${PIVOT_CYTHON_WHEEL_WORKING_DIRECTORY})
    if(NOT _working_dir)
        set(_working_dir "${PROJECT_SOURCE_DIR}")
    endif()

    set(_comment ${PIVOT_CYTHON_WHEEL_COMMENT})
    if(NOT _comment)
        set(_comment "Building ${PIVOT_CYTHON_WHEEL_TARGET_NAME} wheel")
    endif()

    file(MAKE_DIRECTORY "${PIVOT_CYTHON_WHEEL_OUTPUT_DIR}")

    add_custom_target(${PIVOT_CYTHON_WHEEL_TARGET_NAME} ALL
        COMMAND ${Python3_EXECUTABLE} "${PIVOT_CYTHON_WHEEL_SCRIPT_PATH}" --output-dir "${PIVOT_CYTHON_WHEEL_OUTPUT_DIR}"
        WORKING_DIRECTORY "${_working_dir}"
        COMMENT "${_comment}"
        DEPENDS ${PIVOT_CYTHON_WHEEL_MODULE_TARGETS}
    )
endfunction()

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
        add_custom_command(TARGET ${PIVOT_SYMLINK_TARGET_NAME} POST_BUILD
            COMMAND ${CMAKE_COMMAND} -E rm -rf "${PIVOT_SYMLINK_BLENDER_SITE_PACKAGES}/${PIVOT_SYMLINK_PACKAGE_NAME}"
            COMMAND ${CMAKE_COMMAND} -E create_symlink "${PIVOT_SYMLINK_SOURCE_PATH}" "${PIVOT_SYMLINK_BLENDER_SITE_PACKAGES}/${PIVOT_SYMLINK_PACKAGE_NAME}"
            COMMENT "Creating symlink to Blender site-packages for development"
        )
    endif()
endfunction()
