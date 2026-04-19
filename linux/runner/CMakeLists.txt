cmake_minimum_required(VERSION 3.10)
project(nebula_vpn_runner LANGUAGES CXX)

set(BINARY_NAME "nebula_vpn")
set(FLUTTER_LIBRARY "${FLUTTER_MANAGED_DIR}/libflutter_linux_gtk.so")

# Source files
set(SOURCES
  "my_application.cc"
  "vpn_handler.cc"
  "vpn_handler.h"
)

# Include directories
include_directories(
  ${FLUTTER_MANAGED_DIR}
)

# Add executable
add_executable(${BINARY_NAME} ${SOURCES})

# Apply Flutter definitions
target_compile_definitions(${BINARY_NAME} PRIVATE FLUTTER_VERSION_MAJOR=${FLUTTER_VERSION_MAJOR})
target_compile_definitions(${BINARY_NAME} PRIVATE FLUTTER_VERSION_MINOR=${FLUTTER_VERSION_MINOR})
target_compile_definitions(${BINARY_NAME} PRIVATE FLUTTER_VERSION_PATCH=${FLUTTER_VERSION_PATCH})
target_compile_definitions(${BINARY_NAME} PRIVATE FLUTTER_VERSION_BUILD=${FLUTTER_VERSION_BUILD})

# Link libraries
target_link_libraries(${BINARY_NAME} PRIVATE PkgConfig::GTK3)
target_link_libraries(${BINARY_NAME} PRIVATE flutter)

# Install
install(TARGETS ${BINARY_NAME} RUNTIME DESTINATION bin)
