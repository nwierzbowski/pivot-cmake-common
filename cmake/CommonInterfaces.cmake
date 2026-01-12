include_guard(GLOBAL)

# Sets global CMake cache variables that affect the entire build system.
# This includes IPO settings and platform-specific defaults.
# Must be called before any targets are created to ensure cache variables are set early.
function(setup_common_toolchain)

    get_property(is_setup GLOBAL PROPERTY PIVOT_GLOBAL_CACHE_SETUP_DONE)

    if(is_setup)
        return()
    endif()

    # Set platform-specific cache variables for consistent build behavior
    if(WIN32)
        # Force static CRT linking for MSVC to match Blender's requirements
        set(CACHE{CMAKE_MSVC_RUNTIME_LIBRARY} TYPE STRING FORCE VALUE "MultiThreaded$<$<CONFIG:Debug>:Debug>")
    elseif(APPLE)
        # Set minimum macOS deployment target for compatibility
        set(CACHE{CMAKE_OSX_DEPLOYMENT_TARGET} TYPE STRING FORCE VALUE "10.15")
    endif()
    set_property(GLOBAL PROPERTY PIVOT_GLOBAL_CACHE_SETUP_DONE TRUE)
endfunction()

# Creates common interface targets for compiler settings, warnings, and linking.
# These targets can be linked to provide consistent build configuration across projects.
# Depends on setup_global_cache_variables being called first.
function(setup_common_interfaces)

    if(TARGET pivot_common::base)
        return()
    endif()

        # Check and enable Interprocedural Optimization (IPO/LTO) for Release builds if supported
    include(CheckIPOSupported)
    check_ipo_supported(RESULT ipo_supported OUTPUT ipo_msg)

    if(ipo_supported)
        message(STATUS "IPO/LTO is supported and enabled for Release builds")
        
        # Enable IPO for Release, RelWithDebInfo, and MinSizeRel configurations
        set(CACHE{CMAKE_INTERPROCEDURAL_OPTIMIZATION_RELEASE} TYPE BOOL FORCE VALUE TRUE)
        set(CACHE{CMAKE_INTERPROCEDURAL_OPTIMIZATION_RELWITHDEBINFO} TYPE BOOL FORCE VALUE TRUE)
        set(CACHE{CMAKE_INTERPROCEDURAL_OPTIMIZATION_MINSIZEREL} TYPE BOOL FORCE VALUE TRUE)
    else()
        message(WARNING "IPO/LTO is not supported: ${ipo_msg}")
    endif()

    # 1. Platform & Definitions Target
    # Provides platform-specific compile definitions and options
    add_library(pivot_platform INTERFACE)
    add_library(pivot_common::platform ALIAS pivot_platform)
    
    if(WIN32)
        # Windows 8.1 minimum version for Blender compatibility
        target_compile_definitions(pivot_platform INTERFACE _WIN32_WINNT=0x0603 WINVER=0x0603)
        # MSVC: Stop Boost autolink and fix __cplusplus macro
        if(MSVC)
            target_compile_definitions(pivot_platform INTERFACE BOOST_ALL_NO_LIB BOOST_INTERPROCESS_NO_LIB)
            target_compile_options(pivot_platform INTERFACE /Zc:__cplusplus /utf-8)
        endif()
    endif()

    # 2. Warnings Target
    # Enables comprehensive compiler warnings
    add_library(pivot_warnings INTERFACE)
    add_library(pivot_common::warnings ALIAS pivot_warnings)
    if(MSVC)
        target_compile_options(pivot_warnings INTERFACE /W4 /permissive- /EHsc)
    else()
        target_compile_options(pivot_warnings INTERFACE -Wall -Wextra -Wpedantic)
    endif()

    # 3. C++ Standard Target
    # Enforces C++20 standard
    add_library(pivot_cxx20 INTERFACE)
    add_library(pivot_common::cxx20 ALIAS pivot_cxx20)
    target_compile_features(pivot_cxx20 INTERFACE cxx_std_20)

    # 4. Static Runtime Linking Target
    # Ensures static linking of runtime libraries for portability
    add_library(pivot_runtime_static INTERFACE)
    add_library(pivot_common::runtime_static ALIAS pivot_runtime_static)

    if(MSVC)
        # CMAKE_MSVC_RUNTIME_LIBRARY already set in setup_global_cache_variables
    elseif(APPLE)
        # macOS uses dynamic linking by default, no changes needed
    else()
        # Linux: Static link GCC and stdlib, include threads and realtime libs
        target_link_options(pivot_runtime_static INTERFACE -static-libgcc -static-libstdc++)

        # Include threading support
        find_package(Threads REQUIRED)
        target_link_libraries(pivot_runtime_static INTERFACE Threads::Threads)
        
        # Required for shared memory IPC on Linux
        if(CMAKE_SYSTEM_NAME MATCHES "Linux")
            target_link_libraries(pivot_runtime_static INTERFACE rt)
        endif()
    endif()

    # 5. Master Base Target
    # Combines all common settings into one convenient target
    add_library(pivot_base INTERFACE)
    add_library(pivot_common::base ALIAS pivot_base)
    target_link_libraries(pivot_base INTERFACE 
        pivot_common::platform 
        pivot_common::warnings 
        pivot_common::cxx20
        pivot_common::runtime_static
    )
endfunction()