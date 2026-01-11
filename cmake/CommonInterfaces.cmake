include_guard(GLOBAL)

function(setup_common_interfaces)

    # Run only once
    if(TARGET pivot_common::warnings)
        return()
    endif()

    # Cpp warnings
    add_library(pivot_common_warnings INTERFACE)
    add_library(pivot_common::warnings ALIAS pivot_common_warnings)
    if(MSVC)
        target_compile_options(pivot_common_warnings INTERFACE /W4 /permissive- /EHsc)
    else()
        target_compile_options(pivot_common_warnings INTERFACE -Wall -Wextra -pedantic)
    endif()

    # C++20 standard
    add_library(pivot_common_cxx20 INTERFACE)
    add_library(pivot_common::cxx20 ALIAS pivot_common_cxx20)
    target_compile_features(pivot_common_cxx20 INTERFACE cxx_std_20)

    # MSVC no autolink to stop boost from trying to link libs itself
    add_library(pivot_common_msvc_no_autolib INTERFACE)
    add_library(pivot_common::msvc_no_autolib ALIAS pivot_common_msvc_no_autolib)
    if(MSVC)
        target_compile_definitions(pivot_common_msvc_no_autolib INTERFACE BOOST_ALL_NO_LIB BOOST_INTERPROCESS_NO_LIB)
    endif()
endfunction()
