include_guard(GLOBAL)

function(pivot_common_platform_id out_var)
    string(TOLOWER "${CMAKE_SYSTEM_NAME}" _system_name)
    string(TOLOWER "${CMAKE_SYSTEM_PROCESSOR}" _processor)

    if(_processor MATCHES "^(x86_64|amd64)$")
        set(_arch "x86-64")
    elseif(_processor MATCHES "^(aarch64|arm64)$")
        set(_arch "arm64")
    else()
        set(_arch "${_processor}")
    endif()

    set(${out_var} "${_system_name}-${_arch}" PARENT_SCOPE)
endfunction()
