include_guard(GLOBAL)

include(FetchContent)

function(pivot_common_setup_eigen)
    if(TARGET Eigen3::Eigen)
        return()
    endif()

    FetchContent_Declare(
        pivot_eigen
        GIT_REPOSITORY https://gitlab.com/libeigen/eigen.git
        GIT_TAG 3.4.0
        GIT_SHALLOW TRUE
    )
    FetchContent_GetProperties(pivot_eigen)
    if(NOT pivot_eigen_POPULATED)
        FetchContent_Populate(pivot_eigen)
    endif()

    add_library(Eigen3::Eigen INTERFACE IMPORTED GLOBAL)
    set_target_properties(Eigen3::Eigen PROPERTIES
        INTERFACE_INCLUDE_DIRECTORIES "${pivot_eigen_SOURCE_DIR}"
    )
endfunction()
