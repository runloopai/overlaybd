include(FetchContent)

if(${BUILD_CURL_FROM_SOURCE})
    message("Add and build standalone libopenssl")
    include(FetchContent)

    # make openssl into bundle
    FetchContent_Declare(
        openssl102
        GIT_REPOSITORY https://github.com/openssl/openssl.git
        GIT_TAG OpenSSL_1_0_2-stable
        GIT_PROGRESS 1)

    FetchContent_GetProperties(openssl102)

    if(NOT TARGET openssl102_static_build)
        if(NOT openssl102_POPULATED)
            FetchContent_Populate(openssl102)
        endif()
        set(OPENSSL_BUILD_SOURCE_DIR "${openssl102_BINARY_DIR}/source")
        set(_openssl_build_signature "${openssl102_BINARY_DIR}/overlaybd-build-config")
        file(GENERATE OUTPUT "${_openssl_build_signature}" CONTENT
            "CC=${CMAKE_C_COMPILER}\nAR=${CMAKE_AR}\nRANLIB=${CMAKE_RANLIB}\nCFLAGS=${CMAKE_C_FLAGS}\nPROCESSOR=${OVERLAYBD_SYSTEM_PROCESSOR}\nTRIPLET=${OVERLAYBD_TARGET_TRIPLET}\n")
        set(_openssl_configure_command sh config)
        if(CMAKE_CROSSCOMPILING)
            if(OVERLAYBD_SYSTEM_PROCESSOR MATCHES "^(aarch64|arm64)$")
                set(_openssl_target linux-aarch64)
            else()
                set(_openssl_target linux-x86_64)
            endif()
            set(_openssl_configure_command perl ./Configure ${_openssl_target})
        endif()
        add_custom_command(
            OUTPUT
                ${openssl102_BINARY_DIR}/lib/libssl.a
                ${openssl102_BINARY_DIR}/lib/libcrypto.a
                ${openssl102_BINARY_DIR}/include/openssl/ssl.h
            BYPRODUCTS ${openssl102_BINARY_DIR}/bin/openssl
            COMMAND ${CMAKE_COMMAND} -E remove_directory ${OPENSSL_BUILD_SOURCE_DIR}
            COMMAND ${CMAKE_COMMAND} -E copy_directory
                ${openssl102_SOURCE_DIR} ${OPENSSL_BUILD_SOURCE_DIR}
            COMMAND ${CMAKE_COMMAND} -E chdir ${OPENSSL_BUILD_SOURCE_DIR}
                ${CMAKE_COMMAND} -E env
                "CC=${CMAKE_C_COMPILER}"
                "AR=${CMAKE_AR}"
                "RANLIB=${CMAKE_RANLIB}"
                "CFLAGS=${CMAKE_C_FLAGS} -fPIC"
                ${_openssl_configure_command} -fPIC no-unit-test no-shared
                --openssldir=${openssl102_BINARY_DIR}
                --prefix=${openssl102_BINARY_DIR}
            COMMAND ${CMAKE_COMMAND} -E chdir ${OPENSSL_BUILD_SOURCE_DIR}
                ${OVERLAYBD_MAKE_EXECUTABLE} depend
            COMMAND ${CMAKE_COMMAND} -E chdir ${OPENSSL_BUILD_SOURCE_DIR}
                ${OVERLAYBD_MAKE_EXECUTABLE} -j${OVERLAYBD_SUBBUILD_JOBS}
            COMMAND ${CMAKE_COMMAND} -E chdir ${OPENSSL_BUILD_SOURCE_DIR}
                ${OVERLAYBD_MAKE_EXECUTABLE} install
            DEPENDS
                ${openssl102_SOURCE_DIR}/Configure
                ${openssl102_SOURCE_DIR}/config
                "${_openssl_build_signature}"
                "${CMAKE_CURRENT_LIST_FILE}"
            VERBATIM)
        add_custom_target(openssl102_static_build DEPENDS
            ${openssl102_BINARY_DIR}/lib/libssl.a
            ${openssl102_BINARY_DIR}/lib/libcrypto.a
            ${openssl102_BINARY_DIR}/include/openssl/ssl.h)
        make_directory(${openssl102_BINARY_DIR}/include)
    endif()

    set(OPENSSL_FOUND yes)
    set(OPENSSL_ROOT_DIR ${openssl102_BINARY_DIR})
    set(OPENSSL_INCLUDE_DIR ${OPENSSL_ROOT_DIR}/include)
    set(OPENSSL_INCLUDE_DIRS ${OPENSSL_INCLUDE_DIR})
    set(OPENSSL_SSL_LIBRARY ${OPENSSL_ROOT_DIR}/lib/libssl.a)
    set(OPENSSL_SSL_LIBRARIES ${OPENSSL_SSL_LIBRARY})
    set(OPENSSL_CRYPTO_LIBRARY ${OPENSSL_ROOT_DIR}/lib/libcrypto.a)
    set(OPENSSL_CRYPTO_LIBRARIES ${OPENSSL_CRYPTO_LIBRARY})
    set(OPENSSL_LINK_DIR ${OPENSSL_ROOT_DIR}/lib)
    set(OPENSSL_LINK_DIRS ${OPENSSL_LINK_DIR})

    if(NOT TARGET OpenSSL::SSL)
        add_library(OpenSSL::SSL STATIC IMPORTED)
        add_dependencies(OpenSSL::SSL openssl102_static_build)
        set_target_properties(
            OpenSSL::SSL
            PROPERTIES IMPORTED_LINK_INTERFACE_LANGUAGES "C"
                       IMPORTED_LOCATION "${OPENSSL_SSL_LIBRARY}"
                       INTERFACE_INCLUDE_DIRECTORIES "${OPENSSL_INCLUDE_DIRS}"
                       INTERFACE_LINK_LIBRARIES "OpenSSL::Crypto")
    endif()

    if(NOT TARGET OpenSSL::Crypto)
        add_library(OpenSSL::Crypto STATIC IMPORTED)
        add_dependencies(OpenSSL::Crypto openssl102_static_build)
        set_target_properties(
            OpenSSL::Crypto
            PROPERTIES IMPORTED_LINK_INTERFACE_LANGUAGES "C"
                       IMPORTED_LOCATION "${OPENSSL_CRYPTO_LIBRARY}"
                       INTERFACE_INCLUDE_DIRECTORIES "${OPENSSL_INCLUDE_DIRS}"
                       INTERFACE_LINK_LIBRARIES "dl")
    endif()
else()
    include(${CMAKE_ROOT}/Modules/FindOpenSSL.cmake)
endif()
