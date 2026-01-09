# CMakeLists.txt - Common Pivot Build Configuration
# This file contains shared configuration used by all Pivot CMakeLists.txt files

# Locate the shared configuration so each subproject can include it directly.
get_filename_component(_pivot_common_dir ${CMAKE_CURRENT_LIST_FILE} PATH)
if(NOT DEFINED PIVOT_COMMON_DIR)
    set(PIVOT_COMMON_DIR "${_pivot_common_dir}")
endif()
if(NOT DEFINED PIVOT_PROJECT_ROOT)
    get_filename_component(_pivot_project_root "${PIVOT_COMMON_DIR}" DIRECTORY)
    set(PIVOT_PROJECT_ROOT "${_pivot_project_root}")
endif()

# Set minimum macOS deployment target
if(APPLE)
    set(CMAKE_OSX_DEPLOYMENT_TARGET "10.15" CACHE STRING "Minimum macOS version" FORCE)
endif()

# Windows compatibility settings
if(WIN32)
    add_compile_definitions(_WIN32_WINNT=0x0603 WINVER=0x0603)
endif()

if(MSVC)
    set(CMAKE_MSVC_RUNTIME_LIBRARY "MultiThreaded$<$<CONFIG:Debug>:Debug>")
endif()

# Build configuration
if(NOT CMAKE_BUILD_TYPE)
    set(CMAKE_BUILD_TYPE Release CACHE STRING "Choose build type: Debug, Release, etc." FORCE)
endif()

function(_pivot_configure_editions)
    if(NOT DEFINED PIVOT_EDITION)
        set(PIVOT_EDITION "PRO" CACHE STRING "Edition to build (PRO or STANDARD)" FORCE)
    endif()
    set_property(CACHE PIVOT_EDITION PROPERTY STRINGS PRO STANDARD)
    string(TOUPPER "${PIVOT_EDITION}" _pivot_edition_upper)
    set(_allowed_editions PRO STANDARD)
    list(FIND _allowed_editions "${_pivot_edition_upper}" _edition_index)
    if(_edition_index EQUAL -1)
        message(FATAL_ERROR "Invalid PIVOT_EDITION '${PIVOT_EDITION}'. Choose PRO or STANDARD.")
    endif()
    set(PIVOT_EDITION "${_pivot_edition_upper}" CACHE STRING "Edition to build (PRO or STANDARD)" FORCE)

    set(_edition_defines)
    if(PIVOT_EDITION STREQUAL "PRO")
        list(APPEND _edition_defines "PIVOT_EDITION_PRO")
        set(_edition_pro_flag 1)
        set(_edition_standard_flag 0)
    else()
        list(APPEND _edition_defines "PIVOT_EDITION_STANDARD")
        set(_edition_pro_flag 0)
        set(_edition_standard_flag 1)
    endif()
    list(APPEND _edition_defines "PIVOT_EDITION_NAME=\"${PIVOT_EDITION}\"")

    if(NOT DEFINED PIVOT_EDITION_DEFINES)
        set(PIVOT_EDITION_DEFINES "${_edition_defines}" CACHE INTERNAL "Compile definitions for the selected edition" FORCE)
    endif()
    if(NOT DEFINED PIVOT_EDITION_PRO_DEF)
        set(PIVOT_EDITION_PRO_DEF ${_edition_pro_flag} CACHE INTERNAL "Cython DEF flag for PRO edition" FORCE)
    endif()
    if(NOT DEFINED PIVOT_EDITION_STANDARD_DEF)
        set(PIVOT_EDITION_STANDARD_DEF ${_edition_standard_flag} CACHE INTERNAL "Cython DEF flag for STANDARD edition" FORCE)
    endif()
    if(NOT DEFINED PIVOT_EDITION_NAME_DEF)
        set(PIVOT_EDITION_NAME_DEF ${PIVOT_EDITION} CACHE INTERNAL "Cython DEF name for selected edition" FORCE)
    endif()
endfunction()

function(_pivot_detect_platform)
    string(TOLOWER "${CMAKE_SYSTEM_NAME}" _system_name)
    string(TOLOWER "${CMAKE_SYSTEM_PROCESSOR}" _processor)

    if(_processor MATCHES "^(x86_64|AMD64|amd64)$")
        set(_arch "x86-64")
    elseif(_processor MATCHES "^(aarch64|arm64)$")
        set(_arch "arm64")
    else()
        set(_arch "${_processor}")
    endif()

    set(PIVOT_PLATFORM_ID "${_system_name}-${_arch}" CACHE INTERNAL "Platform identifier" FORCE)
endfunction()

if(NOT DEFINED _pivot_globals_initialized)
    set(_pivot_globals_initialized TRUE)
    _pivot_configure_editions()
    _pivot_detect_platform()
endif()

# Prepare output directories
function(_pivot_prepare_dir dir platform_id)
    if(dir STREQUAL "")
        return()
    endif()
    file(MAKE_DIRECTORY "${dir}")
    set(marker "${dir}/.edition")
    set(marker_content "${platform_id}:${PIVOT_EDITION}")
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

# Boost setup (shared by SDK and engine)
macro(_pivot_setup_boost)
    cmake_policy(SET CMP0167 NEW)
    find_package(Boost 1.75 QUIET COMPONENTS interprocess json)
    if(Boost_FOUND)
        message(STATUS "Using system Boost (${Boost_VERSION})")
    else()
        message(STATUS "Boost not fully available; fetching headers via FetchContent")
        include(FetchContent)
        set(BOOST_VERSION 1.83.0 CACHE STRING "Boost release version to fetch")
        string(REPLACE "." "_" BOOST_VERSION_U ${BOOST_VERSION})
        FetchContent_Declare(
            boost_ext
            URL https://archives.boost.io/release/${BOOST_VERSION}/source/boost_${BOOST_VERSION_U}.tar.gz
            DOWNLOAD_EXTRACT_TIMESTAMP OFF
        )
        FetchContent_MakeAvailable(boost_ext)

        # Create Boost::json target if not available
        if(NOT TARGET Boost::json)
            file(GLOB BOOST_JSON_SRCS ${boost_ext_SOURCE_DIR}/libs/json/src/*.cpp)
            add_library(boost_json_objects OBJECT ${BOOST_JSON_SRCS})
            target_include_directories(boost_json_objects PRIVATE ${boost_ext_SOURCE_DIR})
            target_compile_features(boost_json_objects PRIVATE cxx_std_17)
            set_target_properties(boost_json_objects PROPERTIES POSITION_INDEPENDENT_CODE ON)
            if(MSVC)
                target_compile_definitions(boost_json_objects PRIVATE BOOST_ALL_NO_LIB BOOST_INTERPROCESS_NO_LIB)
            endif()
            add_library(Boost::json ALIAS boost_json_objects)
        endif()
    endif()
endmacro()

# Cython compilation setup (shared by SDK and bridge)
macro(_pivot_setup_cython)
    find_package(Python3 COMPONENTS Interpreter Development.Module NumPy REQUIRED)
    find_program(CYTHON_EXECUTABLE cython REQUIRED)
endmacro()

# Common Cython module compilation (shared by SDK and bridge)
macro(_pivot_add_cython_modules MODULE_SOURCES WHEEL_PKG_DIR WHEEL_OUTPUT_DIR)
    # Handle edition flags for bridge modules
    if(EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/edition_flags.pxi.in")
        set(EDITION_FLAGS_TEMPLATE ${CMAKE_CURRENT_SOURCE_DIR}/edition_flags.pxi.in)
        set(EDITION_FLAGS_FILE ${CMAKE_CURRENT_BINARY_DIR}/edition_flags.pxi)
        configure_file(${EDITION_FLAGS_TEMPLATE} ${EDITION_FLAGS_FILE} @ONLY)
    endif()

    file(MAKE_DIRECTORY "${WHEEL_PKG_DIR}")
    file(MAKE_DIRECTORY "${WHEEL_OUTPUT_DIR}")

    set(_cython_common_includes
        ${CMAKE_CURRENT_BINARY_DIR}
        ${CMAKE_CURRENT_SOURCE_DIR}
        ${CMAKE_CURRENT_SOURCE_DIR}/..
        ${Python3_INCLUDE_DIRS}
    )
    list(REMOVE_DUPLICATES _cython_common_includes)

    foreach(mod_src ${MODULE_SOURCES})
        get_filename_component(mod ${mod_src} NAME_WE)
        set(SRC ${CMAKE_CURRENT_SOURCE_DIR}/${mod_src})
        set(OUT ${CMAKE_CURRENT_BINARY_DIR}/${mod}.cpp)

        if(EXISTS ${SRC})
            set(PXD_FILE ${CMAKE_CURRENT_SOURCE_DIR}/${mod}.pxd)
            set(_cython_deps ${SRC})
            if(EXISTS ${PXD_FILE})
                list(APPEND _cython_deps ${PXD_FILE})
            endif()
            if(DEFINED EDITION_FLAGS_FILE)
                list(APPEND _cython_deps ${EDITION_FLAGS_FILE})
            endif()

            set(_pivot_module_overrides ${ARGN})
            set(_cython_command ${CYTHON_EXECUTABLE} --cplus)
            foreach(_inc_dir ${_cython_common_includes})
                list(APPEND _cython_command -I ${_inc_dir})
            endforeach()
            list(APPEND _cython_command -o ${OUT} ${SRC})

            add_custom_command(
                OUTPUT ${OUT}
                COMMAND ${_cython_command}
                DEPENDS ${_cython_deps}
                COMMENT "Cythonizing ${SRC}"
            )

            add_library(${mod} MODULE ${OUT})

            if(_pivot_module_overrides)
                foreach(_pivot_override ${_pivot_module_overrides})
                    if(NOT "${_pivot_override}" STREQUAL "")
                        cmake_language(CALL ${_pivot_override} ${mod})
                    endif()
                endforeach()
            endif()

            set_target_properties(${mod} PROPERTIES PREFIX "")
            if(WIN32)
                set_target_properties(${mod} PROPERTIES SUFFIX ".pyd")
            endif()

            target_link_libraries(${mod} PRIVATE Python3::Module)
            if(CMAKE_SYSTEM_NAME MATCHES "Linux")
                target_link_libraries(${mod} PRIVATE rt)
            endif()

            target_include_directories(${mod} PRIVATE ${Python3_INCLUDE_DIRS})
            if(Python3_NumPy_INCLUDE_DIRS)
                target_include_directories(${mod} PRIVATE ${Python3_NumPy_INCLUDE_DIRS})
            endif()

            # Core headers - use project root for consistent paths
            if(EXISTS "${PIVOT_PROJECT_ROOT}/core")
                target_include_directories(${mod} PRIVATE ${PIVOT_PROJECT_ROOT}/core)
            endif()

            target_compile_definitions(${mod} PRIVATE SIZEOF_VOID_P=${CMAKE_SIZEOF_VOID_P})
            if(DEFINED PIVOT_EDITION_DEFINES)
                foreach(def ${PIVOT_EDITION_DEFINES})
                    target_compile_definitions(${mod} PRIVATE ${def})
                endforeach()
            endif()

            add_custom_command(TARGET ${mod} PRE_BUILD
                COMMAND ${CMAKE_COMMAND} -E remove $<TARGET_FILE:${mod}>
                COMMENT "Removing old Cython module to force rebuild on edition switch"
            )
        endif()
    endforeach()

    # Clean up stale SDK binaries in bridge (only for bridge modules)
    if("${WHEEL_PKG_DIR}" MATCHES "pivot_lib")
        file(GLOB _pivot_lib_stale_sdk_bins
            "${WHEEL_PKG_DIR}/engine*.so" "${WHEEL_PKG_DIR}/engine*.pyd"
            "${WHEEL_PKG_DIR}/shm_bridge*.so" "${WHEEL_PKG_DIR}/shm_bridge*.pyd"
        )
        if(_pivot_lib_stale_sdk_bins)
            file(REMOVE ${_pivot_lib_stale_sdk_bins})
        endif()
    endif()

    set(CYTHON_ALL_MODULES)
    foreach(mod_src ${MODULE_SOURCES})
        get_filename_component(mod ${mod_src} NAME_WE)
        list(APPEND CYTHON_ALL_MODULES ${mod})
    endforeach()

    foreach(mod ${CYTHON_ALL_MODULES})
        if(TARGET ${mod})
            set_target_properties(${mod} PROPERTIES LIBRARY_OUTPUT_DIRECTORY "${WHEEL_PKG_DIR}")
        endif()
    endforeach()

    string(REPLACE "/" "_" PROJECT_TARGET_NAME ${PROJECT_NAME})
    add_custom_target(${PROJECT_TARGET_NAME}_wheel ALL
        COMMAND ${Python3_EXECUTABLE} "${CMAKE_CURRENT_SOURCE_DIR}/../build_wheel.py" --output-dir "${WHEEL_OUTPUT_DIR}"
        WORKING_DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}/.."
        COMMENT "Building ${PROJECT_NAME} wheel"
        DEPENDS ${CYTHON_ALL_MODULES}
    )
endmacro()

# Eigen setup (shared by engine and potentially others)
macro(_pivot_setup_eigen)
    # Disable Eigen extras we don't use
    set(BUILD_TESTING OFF CACHE BOOL "Disable all third-party test targets" FORCE)
    set(EIGEN_TEST_FORTRAN OFF CACHE BOOL "Disable Eigen Fortran tests" FORCE)
    set(EIGEN_BUILD_TESTING OFF CACHE BOOL "Disable Eigen self-tests" FORCE)
    set(EIGEN_BUILD_DOC OFF CACHE BOOL "Disable Eigen documentation build" FORCE)

    include(FetchContent)
    FetchContent_Declare(
        Eigen
        GIT_REPOSITORY https://gitlab.com/libeigen/eigen.git
        GIT_TAG 3.4.0
        GIT_SHALLOW TRUE
    )
    FetchContent_GetProperties(Eigen)
    if(NOT Eigen_POPULATED)
        FetchContent_Populate(Eigen)
    endif()
    if(NOT DEFINED Eigen_SOURCE_DIR AND DEFINED eigen_SOURCE_DIR)
        set(Eigen_SOURCE_DIR "${eigen_SOURCE_DIR}")
    endif()

    if(NOT TARGET Eigen3::Eigen)
        add_library(Eigen3::Eigen INTERFACE IMPORTED GLOBAL)
        set_target_properties(Eigen3::Eigen PROPERTIES
            INTERFACE_INCLUDE_DIRECTORIES "${Eigen_SOURCE_DIR}"
        )
    endif()
endmacro()

# Common target compile options (shared by engine and potentially others)
macro(_pivot_setup_target_compile_options TARGET)
    # C++ standard and warnings
    target_compile_features(${TARGET} PRIVATE cxx_std_20)
    if(MSVC)
        target_compile_options(${TARGET} PRIVATE /W4 /permissive- /EHsc)
        target_compile_definitions(${TARGET} PRIVATE BOOST_ALL_NO_LIB BOOST_INTERPROCESS_NO_LIB)
    else()
        target_compile_options(${TARGET} PRIVATE -Wall -Wextra -pedantic)
    endif()
endmacro()

# Common target linking (shared by engine and potentially others)
macro(_pivot_setup_target_linking TARGET)
    # Platform-specific linking
    if(MSVC)
        # Windows: Use static CRT
        target_compile_options(${TARGET} PRIVATE $<$<CONFIG:Release>:/MT> $<$<CONFIG:Debug>:/MTd>)
    elseif(APPLE)
        # macOS: Use fully dynamic linking
    else()
        # Linux / Unix: Static link GCC/Stdlib
        target_link_options(${TARGET} PRIVATE -static-libgcc -static-libstdc++)
        
        # REQUIRED for glibc < 2.34 (Manylinux 2.28) + Static linking
        # 1. Threads (pthread_create, pthread_join)
        find_package(Threads REQUIRED)
        target_link_libraries(${TARGET} PRIVATE Threads::Threads)
        
        # 2. Realtime Library (shm_open)
        if(CMAKE_SYSTEM_NAME MATCHES "Linux")
            target_link_libraries(${TARGET} PRIVATE rt)
        endif()
    endif()
endmacro()

# Common target output directories (shared by engine and potentially others)
macro(_pivot_setup_target_output_dirs TARGET OUTPUT_DIR)
    set_target_properties(${TARGET} PROPERTIES
        RUNTIME_OUTPUT_DIRECTORY ${OUTPUT_DIR}
        RUNTIME_OUTPUT_DIRECTORY_DEBUG ${OUTPUT_DIR}
        RUNTIME_OUTPUT_DIRECTORY_RELEASE ${OUTPUT_DIR}
        RUNTIME_OUTPUT_DIRECTORY_RELWITHDEBINFO ${OUTPUT_DIR}
        RUNTIME_OUTPUT_DIRECTORY_MINSIZEREL ${OUTPUT_DIR}
    )
endmacro()

# Common IPO/LTO setup (shared by engine and potentially others)
macro(_pivot_setup_target_ipo TARGET)
    include(CheckIPOSupported)
    check_ipo_supported(RESULT ipo_supported OUTPUT ipo_msg)
    if(ipo_supported)
        set_property(TARGET ${TARGET} PROPERTY INTERPROCEDURAL_OPTIMIZATION_RELEASE TRUE)
    endif()
endmacro()

# Common installation setup (shared by engine and potentially others)
macro(_pivot_setup_target_install TARGET CONFIG_FILE_IN)
    include(CMakePackageConfigHelpers)
    write_basic_package_version_file(${CMAKE_CURRENT_BINARY_DIR}/${TARGET}ConfigVersion.cmake COMPATIBILITY AnyNewerVersion)
    configure_package_config_file(${CONFIG_FILE_IN} ${CMAKE_CURRENT_BINARY_DIR}/${TARGET}Config.cmake INSTALL_DESTINATION lib/cmake/${TARGET})
    install(TARGETS ${TARGET} EXPORT ${TARGET}Targets RUNTIME DESTINATION bin)
    install(EXPORT ${TARGET}Targets FILE ${TARGET}Targets.cmake NAMESPACE ${TARGET}:: DESTINATION lib/cmake/${TARGET})
    install(FILES ${CMAKE_CURRENT_BINARY_DIR}/${TARGET}Config.cmake ${CMAKE_CURRENT_BINARY_DIR}/${TARGET}ConfigVersion.cmake DESTINATION lib/cmake/${TARGET})

    include(GNUInstallDirs)
    install(TARGETS ${TARGET} RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR})
endmacro()