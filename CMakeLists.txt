cmake_minimum_required(VERSION 3.16)

project(pivot_cmake_common LANGUAGES NONE)

include("${CMAKE_CURRENT_LIST_DIR}/cmake/PivotCommon.cmake")
pivot_common_define_targets()
