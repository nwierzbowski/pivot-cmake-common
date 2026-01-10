include_guard(GLOBAL)

function(pivot_common_install_executable_target target config_file_in)
    include(CMakePackageConfigHelpers)
    include(GNUInstallDirs)

    write_basic_package_version_file(
        "${CMAKE_CURRENT_BINARY_DIR}/${target}ConfigVersion.cmake"
        COMPATIBILITY AnyNewerVersion
    )

    configure_package_config_file(
        "${config_file_in}"
        "${CMAKE_CURRENT_BINARY_DIR}/${target}Config.cmake"
        INSTALL_DESTINATION "lib/cmake/${target}"
    )

    install(TARGETS ${target} EXPORT ${target}Targets RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR})
    install(EXPORT ${target}Targets FILE ${target}Targets.cmake NAMESPACE ${target}:: DESTINATION "lib/cmake/${target}")
    install(FILES
        "${CMAKE_CURRENT_BINARY_DIR}/${target}Config.cmake"
        "${CMAKE_CURRENT_BINARY_DIR}/${target}ConfigVersion.cmake"
        DESTINATION "lib/cmake/${target}"
    )
endfunction()
