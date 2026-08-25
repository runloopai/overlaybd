cmake_minimum_required(VERSION 3.14)

project(
  overlaybd
  LANGUAGES C CXX
)
enable_language(C)

include(CheckCXXCompilerFlag)

set(OVERLAYBD_SUBBUILD_JOBS 1 CACHE STRING
  "Parallel jobs for nested non-CMake dependency builds")
if(OVERLAYBD_SUBBUILD_JOBS LESS 1)
  message(FATAL_ERROR "OVERLAYBD_SUBBUILD_JOBS must be at least 1")
endif()
find_program(OVERLAYBD_MAKE_EXECUTABLE NAMES gmake make)
if(NOT OVERLAYBD_MAKE_EXECUTABLE)
  message(FATAL_ERROR "A make implementation is required for bundled dependencies")
endif()

set(CMAKE_CXX_FLAGS_RELEASE "-O2 -DNDEBUG")
set(CMAKE_CXX_FLAGS_RELWITHDEBINFO "-O2 -DNDEBUG -g")

string(TOLOWER "${CMAKE_SYSTEM_PROCESSOR}" OVERLAYBD_SYSTEM_PROCESSOR)
if(NOT OVERLAYBD_SYSTEM_PROCESSOR MATCHES "^(x86_64|amd64|aarch64|arm64)$")
    message(FATAL_ERROR "Unknown CPU architecture ${CMAKE_SYSTEM_PROCESSOR}")
endif ()

set(OBD_VER "overlaybd/0.0.0-undefined" CACHE STRING "Overlaybd version")

set(CMAKE_ARCHIVE_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/output")
set(CMAKE_LIBRARY_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/output")
set(CMAKE_RUNTIME_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/output")
# Retain these aliases for the existing test and packaging CMake files.
set(LIBRARY_OUTPUT_PATH "${CMAKE_LIBRARY_OUTPUT_DIRECTORY}")
set(EXECUTABLE_OUTPUT_PATH "${CMAKE_RUNTIME_OUTPUT_DIRECTORY}")

set(CMAKE_MODULE_PATH ${CMAKE_MODULE_PATH} "${CMAKE_CURRENT_SOURCE_DIR}/CMake")

set(CMAKE_POSITION_INDEPENDENT_CODE ON)
set(CMAKE_EXPORT_COMPILE_COMMANDS ON)
add_compile_options(-Wall -Werror=sign-compare)
add_compile_definitions(OVERLAYBD_VER=${OBD_VER})

if(OVERLAYBD_SYSTEM_PROCESSOR MATCHES "^(aarch64|arm64)$")
  set(_overlaybd_arch_flags "${CMAKE_C_FLAGS} ${CMAKE_CXX_FLAGS}")
  if(NOT _overlaybd_arch_flags MATCHES "(^|[ ;])-m(arch|cpu)=")
    add_compile_options(-march=armv8-a+crc)
  endif()
  add_compile_options($<$<COMPILE_LANGUAGE:CXX>:-fsigned-char>
                      $<$<COMPILE_LANGUAGE:CXX>:-fno-stack-protector>
                      $<$<COMPILE_LANGUAGE:CXX>:-fomit-frame-pointer>)
endif ()

set(CMAKE_CXX_STANDARD_LIBRARIES "-static-libgcc ${CMAKE_CXX_STANDARD_LIBRARIES}")
find_library(STATIC_LIBSTDCXX libstdc++.a)
if(STATIC_LIBSTDCXX)
  set(CMAKE_CXX_STANDARD_LIBRARIES "-static-libstdc++ ${CMAKE_CXX_STANDARD_LIBRARIES}")
endif()

set(CMAKE_CXX_STANDARD 14)
set(CMAKE_CXX_STANDARD_REQUIRED on)
set(ENABLE_MIMIC_VDSO off)

option(BUILD_CURL_FROM_SOURCE "Compile static libcurl" off)
option(ORIGIN_EXT2FS "Use original libext2fs" off)
option(ENABLE_DSA "Build the Intel DML crc32 backend" off)
option(ENABLE_ISAL "Build the Intel ISA-L crc32 backend" off)
if((ENABLE_DSA OR ENABLE_ISAL) AND NOT OVERLAYBD_SYSTEM_PROCESSOR MATCHES "^(x86_64|amd64)$")
  message(FATAL_ERROR "ENABLE_DSA and ENABLE_ISAL are supported only on x86_64")
endif()
find_package(photon REQUIRED)
find_package(tcmu REQUIRED)
find_package(yamlcpp)
if (NOT yamlcpp_FOUND)
  FetchContent_Declare(
    yamlcpp
    GIT_REPOSITORY https://github.com/jbeder/yaml-cpp.git
    GIT_TAG 0.8.0
  )
  FetchContent_MakeAvailable(yamlcpp)
endif()


if(BUILD_TESTING)
  enable_testing()
  include(CTest)
  
  # Setup googletest
  include(FetchContent)
  FetchContent_Declare(
    googletest
    GIT_REPOSITORY https://github.com/google/googletest.git
    GIT_TAG v1.14.0
  )
  # For Windows: Prevent overriding the parent project's compiler/linker settings
  set(gtest_force_shared_crt ON CACHE BOOL "" FORCE)
  FetchContent_MakeAvailable(googletest)
endif()

add_subdirectory(src)

add_subdirectory(baselayers)

include(CMake/pack.cmake)
