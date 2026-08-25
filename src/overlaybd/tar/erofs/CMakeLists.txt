include(FetchContent)

FetchContent_Declare(
    erofs-utils
    GIT_REPOSITORY https://git.kernel.org/pub/scm/linux/kernel/git/xiang/erofs-utils.git
    GIT_TAG        eec6f7a2755dfccc8f655aa37cf6f26db9164e60
)

FetchContent_GetProperties(erofs-utils)
if(NOT erofs-utils_POPULATED)
    FetchContent_Populate(erofs-utils)
endif()

set(EROFS_BUILD_SOURCE_DIR "${erofs-utils_BINARY_DIR}/source")
set(EROFS_LIB_INCLUDE_DIR "${EROFS_BUILD_SOURCE_DIR}/include/" CACHE PATH
    "erofs-utils include path")
set(EROFS_CONFIG_FILE "${EROFS_BUILD_SOURCE_DIR}/config.h" CACHE FILEPATH
    "erofs-utils config file")
set(EROFS_LIB_STATIC "${EROFS_BUILD_SOURCE_DIR}/lib/.libs/liberofs.a" CACHE FILEPATH
    "erofs-utils static library")
set(_erofs_build_signature "${erofs-utils_BINARY_DIR}/overlaybd-build-config")
file(GENERATE OUTPUT "${_erofs_build_signature}" CONTENT
    "CC=${CMAKE_C_COMPILER}\nAR=${CMAKE_AR}\nRANLIB=${CMAKE_RANLIB}\nCFLAGS=${CMAKE_C_FLAGS}\nTRIPLET=${OVERLAYBD_TARGET_TRIPLET}\n")

set(_erofs_configure_args
    --disable-lz4
    --disable-lzma
    --without-libzstd
    --without-uuid
    --disable-multithreading)
if(CMAKE_CROSSCOMPILING)
    if(OVERLAYBD_TARGET_TRIPLET)
        list(APPEND _erofs_configure_args "--host=${OVERLAYBD_TARGET_TRIPLET}")
    elseif(CMAKE_C_COMPILER_TARGET)
        list(APPEND _erofs_configure_args "--host=${CMAKE_C_COMPILER_TARGET}")
    elseif(OVERLAYBD_SYSTEM_PROCESSOR MATCHES "^(aarch64|arm64)$")
        list(APPEND _erofs_configure_args --host=aarch64-linux-gnu)
    else()
        list(APPEND _erofs_configure_args --host=x86_64-linux-gnu)
    endif()
endif()

add_custom_command(
    OUTPUT "${EROFS_LIB_STATIC}" "${EROFS_CONFIG_FILE}"
    COMMAND ${CMAKE_COMMAND} -E remove_directory "${EROFS_BUILD_SOURCE_DIR}"
    COMMAND ${CMAKE_COMMAND} -E copy_directory
        "${erofs-utils_SOURCE_DIR}" "${EROFS_BUILD_SOURCE_DIR}"
    COMMAND ${CMAKE_COMMAND} -E chdir "${EROFS_BUILD_SOURCE_DIR}"
        ${CMAKE_COMMAND} -E env
        "CC=${CMAKE_C_COMPILER}"
        "AR=${CMAKE_AR}"
        "RANLIB=${CMAKE_RANLIB}"
        "CFLAGS=${CMAKE_C_FLAGS} -fPIC"
        /bin/sh ./autogen.sh
    COMMAND ${CMAKE_COMMAND} -E chdir "${EROFS_BUILD_SOURCE_DIR}"
        ${CMAKE_COMMAND} -E env
        "CC=${CMAKE_C_COMPILER}"
        "AR=${CMAKE_AR}"
        "RANLIB=${CMAKE_RANLIB}"
        "CFLAGS=${CMAKE_C_FLAGS} -fPIC"
        /bin/sh ./configure ${_erofs_configure_args}
    COMMAND ${CMAKE_COMMAND} -E chdir "${EROFS_BUILD_SOURCE_DIR}"
        ${OVERLAYBD_MAKE_EXECUTABLE} -j${OVERLAYBD_SUBBUILD_JOBS}
    WORKING_DIRECTORY "${erofs-utils_BINARY_DIR}"
    DEPENDS
        "${erofs-utils_SOURCE_DIR}/autogen.sh"
        "${erofs-utils_SOURCE_DIR}/configure.ac"
        "${erofs-utils_SOURCE_DIR}/Makefile.am"
        "${_erofs_build_signature}"
        "${CMAKE_CURRENT_LIST_FILE}"
    VERBATIM)
add_custom_target(erofs_utils_build DEPENDS "${EROFS_LIB_STATIC}" "${EROFS_CONFIG_FILE}")

file(MAKE_DIRECTORY "${EROFS_LIB_INCLUDE_DIR}")
if(NOT TARGET EROFS::utils)
    add_library(EROFS::utils STATIC IMPORTED GLOBAL)
    set_target_properties(EROFS::utils PROPERTIES
        IMPORTED_LOCATION "${EROFS_LIB_STATIC}"
        INTERFACE_INCLUDE_DIRECTORIES "${EROFS_LIB_INCLUDE_DIR}"
        INTERFACE_COMPILE_OPTIONS "-include${EROFS_CONFIG_FILE}")
    add_dependencies(EROFS::utils erofs_utils_build)
endif()

file(GLOB EROFS_SOURCE "*.cpp")

add_library(erofs_lib STATIC ${EROFS_SOURCE})

target_include_directories(erofs_lib PRIVATE
    ${PHOTON_INCLUDE_DIR}
)

target_link_libraries(erofs_lib PRIVATE EROFS::utils)

if(BUILD_TESTING)
  add_subdirectory(test)
endif()
