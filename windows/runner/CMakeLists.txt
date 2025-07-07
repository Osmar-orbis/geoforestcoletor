# CMake build file for the runner app.

#
# Copyright 2014 The Flutter Authors. All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
#
#     * Redistributions of source code must retain the above copyright
#       notice, this list of conditions and the following disclaimer.
#     * Redistributions in binary form must reproduce the above
#       copyright notice, this list of conditions and the following
#       disclaimer in the documentation and/or other materials provided
#       with the distribution.
#     * Neither the name of Google Inc. nor the names of its
#       contributors may be used to endorse or promote products derived
#       from this software without specific prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
# AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
# ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE
# LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
# CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
# SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
# INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
# CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
# ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
# POSSIBILITY OF SUCH DAMAGE.

# The name of the executable created for the application.
set(BINARY_NAME "geoforestcoletorv1")

# The name of the Visual Studio project created for the application.
project(${BINARY_NAME} LANGUAGES CXX)

# Add parent project's settings to this project.
# APPLY_STANDARD_SETTINGS is defined in the top-level CMakeLists.txt.
APPLY_STANDARD_SETTINGS(${BINARY_NAME})

# Set the C++ standard to 17.
set_property(TARGET ${BINARY_NAME} PROPERTY CXX_STANDARD 17)

# The directory where the Dart code for the app is.
set(FLUTTER_PROJECT_DIR "${CMAKE_SOURCE_DIR}/../..")

# The entrypoint for the Dart code.
set(FLUTTER_ENTRYPOINT "lib/main.dart")

# The directory to generate project files in.
set(FLUTTER_BUILD_DIR "${CMAKE_BINARY_DIR}/flutter_build")

# Use a separate build directory for the runner, to avoid issues with
# simultaneous builds of the runner and the main project.
set_property(DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}" PROPERTY "build_dir" "${FLUTTER_BUILD_DIR}")

# The list of plugins to be injected into the compiled application.
# This is set by flutter/generated_plugins.cmake.
# It is empty if there are no plugins.
set(PLUGIN_LIBRARIES "")

# === Dart Project Generation ===
# The following section is internally used by the Flutter tool. It is not intended for
# copying or modification.

# The following variables are set by the Flutter tool.
# They are used to generate the build files for the Dart project.
# You can learn more about these variables at:
# https://docs.flutter.dev/deployment/build-windows
set(FLUTTER_TARGET_PLATFORM "" CACHE STRING "")
set(DART_DEFINES "" CACHE STRING "")
set(DART_OBFUSCATION "" CACHE STRING "")
set(TRACK_WIDGET_CREATION "" CACHE STRING "")
set(EXTRA_FRONT_END_OPTIONS "" CACHE STRING "")
set(EXTRA_GEN_SNAPSHOT_OPTIONS "" CACHE STRING "")
set(SPLIT_DEBUG_INFO "" CACHE STRING "")
set(TREE_SHAKE_ICONS "" CACHE STRING "")
set(FLUTTER_ROOT "" CACHE STRING "")
set(FLUTTER_EPHEMERAL_DIR "" CACHE STRING "")
set(FLUTTER_ENGINE_VERSION "" CACHE STRING "")
set(PROJECT_TYPE "" CACHE STRING "")

# Generate the build files for the Dart project.
execute_process(
  COMMAND ${CMAKE_COMMAND} -E env FLUTTER_ROOT=${FLUTTER_ROOT}
    "${FLUTTER_EPHEMERAL_DIR}/flutter_windows.bat"
      --build
      --dart-entrypoint-args "dummy"
      --target-platform "${FLUTTER_TARGET_PLATFORM}"
      --flutter-build-dir "${FLUTTER_BUILD_DIR}"
  WORKING_DIRECTORY "${FLUTTER_PROJECT_DIR}"
  RESULT_VARIABLE result
)
if(result)
  message(FATAL_ERROR "Failed to generate build files.")
endif()
# === End Dart Project Generation ===

# Add the Dart project as a subdirectory.
add_subdirectory(
  "${FLUTTER_BUILD_DIR}"
  "${CMAKE_CURRENT_BINARY_DIR}/flutter"
  EXCLUDE_FROM_ALL
)

# Source files for the runner.
set(RUNNER_SRC
  "flutter_window.cpp"
  "main.cpp"
  "run_loop.cpp"
  "utils.cpp"
  "win32_window.cpp"
  "resource.rc"
)

# Add the runner as an executable.
add_executable(${BINARY_NAME} WIN32 ${RUNNER_SRC})

# APPLY_STANDARD_SETTINGS is defined in the top-level CMakeLists.txt.
APPLY_STANDARD_SETTINGS(${BINARY_NAME})

# === Link Libraries ===
# Link the runner with the Flutter library and the plugin implementations.
target_link_libraries(${BINARY_NAME}
  PRIVATE
    flutter
    flutter_wrapper_app
    ${PLUGIN_LIBRARIES}
)

# <<< LINHA ADICIONADA PARA CORRIGIR O ERRO C2220 >>>
# Instrui o compilador a não tratar avisos de segurança como erros fatais.
target_compile_definitions(${BINARY_NAME} PRIVATE _CRT_SECURE_NO_WARNINGS)

# === Manifest ===
# The manifest file for the application.
set(MANIFEST_SRC "runner.exe.manifest")

# Embed the manifest file in the executable.
if(CMAKE_HOST_WIN32)
  target_sources(${BINARY_NAME} PRIVATE ${MANIFEST_SRC})
else()
  # Use a placeholder for the manifest file on non-Windows hosts.
  # This is necessary to avoid a build error when generating the project files.
  # The manifest file is not used on non-Windows hosts.
  configure_file(
    "${CMAKE_CURRENT_SOURCE_DIR}/runner.exe.manifest"
    "${CMAKE_CURRENT_BINARY_DIR}/runner.exe.manifest"
    COPYONLY
  )
  set(MANIFEST_SRC "${CMAKE_CURRENT_BINARY_DIR}/runner.exe.manifest")
endif()

# === Target Properties ===
# Set the target properties for the runner.
set_target_properties(${BINARY_NAME} PROPERTIES
  # Set the output directory for the executable.
  RUNTIME_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}"
  # Set the manifest file for the executable.
  VS_WIN32_EXECUTABLE_MANIFEST ${MANIFEST_SRC}
)

# === Installation ===
# Install the executable.
install(
  TARGETS ${BINARY_NAME}
  RUNTIME DESTINATION "."
)