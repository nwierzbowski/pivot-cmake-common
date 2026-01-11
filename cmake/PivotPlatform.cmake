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

function(set_common_edition VAR_NAME)
    # 1. Use ${VAR_NAME} to get the name ('PIVOT_EDITION')
    # Use ${${VAR_NAME}} to get the actual value (e.g., 'pro' or 'STANDARD')
    
    # Set default in CACHE if the variable isn't defined yet
    if(NOT DEFINED ${VAR_NAME})
        set(${VAR_NAME} "PRO" CACHE STRING "Edition to build (PRO or STANDARD)")
    endif()

    set_property(CACHE ${VAR_NAME} PROPERTY STRINGS PRO STANDARD)

    # 2. Correct/Sanitize the value
    string(TOUPPER "${${VAR_NAME}}" UPDATED_VAL)

    # 3. Validate
    if(NOT UPDATED_VAL STREQUAL "PRO" AND NOT UPDATED_VAL STREQUAL "STANDARD")
        message(FATAL_ERROR "Invalid ${VAR_NAME} '${UPDATED_VAL}'. Choose PRO or STANDARD.")
    endif()

    return(PROPAGATE ${VAR_NAME})
endfunction()