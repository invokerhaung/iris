cmake_minimum_required(VERSION 3.14)
project(runner LANGUAGES CXX)

# Define the application target. To change its name, change BINARY_NAME in the
# top-level CMakeLists.txt, not the value here, or `flutter run` will no longer
# work.
#
# Any new source files that you add to the application should be added here.
add_executable(${BINARY_NAME} WIN32
  "flutter_window.cpp"
  "main.cpp"
  "utils.cpp"
  "win32_window.cpp"
  "${FLUTTER_MANAGED_DIR}/generated_plugin_registrant.cc"
  "Runner.rc"
  "runner.exe.manifest"
)

# Apply the standard set of build settings. This can be removed for applications
# that need different build settings.
apply_standard_settings(${BINARY_NAME})

# Add preprocessor definitions for the build version.
target_compile_definitions(${BINARY_NAME} PRIVATE "FLUTTER_VERSION=\"${FLUTTER_VERSION}\"")
target_compile_definitions(${BINARY_NAME} PRIVATE "FLUTTER_VERSION_MAJOR=${FLUTTER_VERSION_MAJOR}")
target_compile_definitions(${BINARY_NAME} PRIVATE "FLUTTER_VERSION_MINOR=${FLUTTER_VERSION_MINOR}")
target_compile_definitions(${BINARY_NAME} PRIVATE "FLUTTER_VERSION_PATCH=${FLUTTER_VERSION_PATCH}")
target_compile_definitions(${BINARY_NAME} PRIVATE "FLUTTER_VERSION_BUILD=${FLUTTER_VERSION_BUILD}")

# Disable Windows macros that collide with C++ standard library functions.
target_compile_definitions(${BINARY_NAME} PRIVATE "NOMINMAX")

# Add dependency libraries and include directories. Add any application-specific
# dependencies here.
target_link_libraries(${BINARY_NAME} PRIVATE flutter flutter_wrapper_app)
target_link_libraries(${BINARY_NAME} PRIVATE "dwmapi.lib")
target_include_directories(${BINARY_NAME} PRIVATE "${CMAKE_SOURCE_DIR}")

# Run the Flutter tool portions of the build. This must not be removed.
add_dependencies(${BINARY_NAME} flutter_assemble)

# 拷贝 curl-impersonate 依赖 DLL
set(IMPERSONATE_DLLS
  "${CMAKE_CURRENT_SOURCE_DIR}/lib/libcurl-11bfc6a4136d7ce248863d4c5ef4c6be.dll"
  "${CMAKE_CURRENT_SOURCE_DIR}/lib/libnghttp2-14-a5a14079d5e6f7e02bdea4c68e15625e.dll"
  "${CMAKE_CURRENT_SOURCE_DIR}/lib/libbrotlidec-252c2f843d5224cc9b1ee9be5b889404.dll"
  "${CMAKE_CURRENT_SOURCE_DIR}/lib/libbrotlicommon-9015c7e64e1216016fe7f8f27253ab5a.dll"
  "${CMAKE_CURRENT_SOURCE_DIR}/lib/libzstd-4a24f8e0e538f6782383866e3242d5c7.dll"
  "${CMAKE_CURRENT_SOURCE_DIR}/lib/zlib1-14685ce489c41d0eb9cd110148c86d46.dll"
  "${CMAKE_CURRENT_SOURCE_DIR}/lib/libpsl-5-8e6d3ac480752bbffa34ca209d96a185.dll"
  "${CMAKE_CURRENT_SOURCE_DIR}/lib/libidn2-0-8086a128bb32ed858feb3e2a888df65b.dll"
  "${CMAKE_CURRENT_SOURCE_DIR}/lib/libunistring-5-bade1bc819b29d8ddf30ff7be6a66e53.dll"
  "${CMAKE_CURRENT_SOURCE_DIR}/lib/libiconv-2-657ca3a64139260fa69df2a4af38e3d9.dll"
  "${CMAKE_CURRENT_SOURCE_DIR}/lib/libintl-8-bc88842044f5ddc85d72473aa45dc56a.dll"
)
foreach(dll ${IMPERSONATE_DLLS})
  add_custom_command(TARGET ${BINARY_NAME} POST_BUILD
    COMMAND ${CMAKE_COMMAND} -E copy_if_different "${dll}" "$<TARGET_FILE_DIR:${BINARY_NAME}>")
endforeach()

# 拷贝 Legado FFI DLL
add_custom_command(TARGET ${BINARY_NAME} POST_BUILD
  COMMAND ${CMAKE_COMMAND} -E copy_if_different
    "${CMAKE_CURRENT_SOURCE_DIR}/../../ffi_lib/legado_ffi.dll"
    "$<TARGET_FILE_DIR:${BINARY_NAME}>")
