# The Flutter tooling requires that developers have CMake 3.10 or later
# installed. You should not increase this version, as doing so will cause
# the plugin to fail to compile for some customers of the plugin.
cmake_minimum_required(VERSION 3.10)

# Project-level configuration.
set(PROJECT_NAME "rust_lib_app")
project(${PROJECT_NAME} LANGUAGES CXX)

include("../cargokit/cmake/cargokit.cmake")

if(EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/../../../bibliogenius")
    set(RUST_MANIFEST_PATH "../../../bibliogenius")
else()
    set(RUST_MANIFEST_PATH "../bibliogenius")
endif()

apply_cargokit(${PROJECT_NAME} ${RUST_MANIFEST_PATH} rust_lib_app "")

# List of absolute paths to libraries that should be bundled with the plugin.
# This list could contain prebuilt libraries, or libraries created by an
# external build triggered from this build file.
set(rust_lib_app_bundled_libraries
  "${${PROJECT_NAME}_cargokit_lib}"
  PARENT_SCOPE
)
