file(GLOB SOURCE_ZSTD "*.cpp")

add_library(zstd_lib STATIC ${SOURCE_ZSTD})

target_include_directories(zstd_lib PUBLIC
    ${PHOTON_INCLUDE_DIR}
)

include(FetchContent)

# Use FetchContent to download zstd
FetchContent_Declare(
    zstd
    GIT_REPOSITORY https://github.com/facebook/zstd.git
    GIT_TAG        v1.5.6
    SOURCE_SUBDIR  build/cmake
)

set(ZSTD_BUILD_PROGRAMS OFF CACHE BOOL "" FORCE)
set(ZSTD_BUILD_TESTS OFF CACHE BOOL "" FORCE)
set(ZSTD_BUILD_SHARED OFF CACHE BOOL "" FORCE)
set(ZSTD_BUILD_STATIC ON CACHE BOOL "" FORCE)
FetchContent_MakeAvailable(zstd)

target_link_libraries(zstd_lib photon_static libzstd_static)
