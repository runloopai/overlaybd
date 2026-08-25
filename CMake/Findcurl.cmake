include(FetchContent)

if(${BUILD_CURL_FROM_SOURCE})
    message("Add and build standalone libcurl")
    include(FetchContent)
    FetchContent_Declare(
        curl_bundle
        GIT_REPOSITORY https://github.com/curl/curl.git
        GIT_TAG curl-7_42_1
        GIT_PROGRESS 1)

    FetchContent_GetProperties(curl_bundle)

    # In libcurl, CMakeLists build static lib is broken add build command via
    # make
    if(NOT TARGET libcurl_static_build)
        if (NOT curl_bundle_POPULATED)
            FetchContent_Populate(curl_bundle)
        endif()
        set(CURL_BUILD_SOURCE_DIR "${curl_bundle_BINARY_DIR}/source")
        find_package(openssl)
        set(_curl_build_signature "${curl_bundle_BINARY_DIR}/overlaybd-build-config")
        file(GENERATE OUTPUT "${_curl_build_signature}" CONTENT
            "CC=${CMAKE_C_COMPILER}\nCXX=${CMAKE_CXX_COMPILER}\nAR=${CMAKE_AR}\nRANLIB=${CMAKE_RANLIB}\nCFLAGS=${CMAKE_C_FLAGS}\nCXXFLAGS=${CMAKE_CXX_FLAGS}\nTRIPLET=${OVERLAYBD_TARGET_TRIPLET}\nOPENSSL=${OPENSSL_SSL_LIBRARY}\n")
        set(_curl_configure_args
            --with-ssl=${OPENSSL_ROOT_DIR}
            --without-libssh2 --enable-static --enable-shared=no --enable-optimize
            --disable-manual --without-libidn
            --disable-ftp --disable-file --disable-ldap --disable-ldaps
            --disable-rtsp --disable-dict --disable-telnet --disable-tftp
            --disable-pop3 --disable-imap --disable-smb --disable-smtp
            --disable-gopher --without-nghttp2 --enable-http
            --with-pic=PIC
            --prefix=${curl_bundle_BINARY_DIR})
        if(CMAKE_CROSSCOMPILING)
            if(OVERLAYBD_TARGET_TRIPLET)
                list(APPEND _curl_configure_args --host=${OVERLAYBD_TARGET_TRIPLET})
            elseif(CMAKE_C_COMPILER_TARGET)
                list(APPEND _curl_configure_args --host=${CMAKE_C_COMPILER_TARGET})
            elseif(OVERLAYBD_SYSTEM_PROCESSOR MATCHES "^(aarch64|arm64)$")
                list(APPEND _curl_configure_args --host=aarch64-linux-gnu)
            else()
                list(APPEND _curl_configure_args --host=x86_64-linux-gnu)
            endif()
        endif()
        add_custom_command(
            OUTPUT
                ${curl_bundle_BINARY_DIR}/lib/libcurl.a
                ${curl_bundle_BINARY_DIR}/include/curl/curl.h
            COMMAND ${CMAKE_COMMAND} -E remove_directory ${CURL_BUILD_SOURCE_DIR}
            COMMAND ${CMAKE_COMMAND} -E copy_directory
                ${curl_bundle_SOURCE_DIR} ${CURL_BUILD_SOURCE_DIR}
            COMMAND ${CMAKE_COMMAND} -E chdir ${CURL_BUILD_SOURCE_DIR}
                ${CMAKE_COMMAND} -E env
                "CC=${CMAKE_C_COMPILER}"
                "CXX=${CMAKE_CXX_COMPILER}"
                "LD=${CMAKE_LINKER}"
                "AR=${CMAKE_AR}"
                "RANLIB=${CMAKE_RANLIB}"
                "CFLAGS=${CMAKE_C_FLAGS} -fPIC"
                "CXXFLAGS=${CMAKE_CXX_FLAGS} -fPIC"
                "LIBS=-ldl"
                autoreconf -i
            COMMAND ${CMAKE_COMMAND} -E chdir ${CURL_BUILD_SOURCE_DIR}
                ${CMAKE_COMMAND} -E env
                "CC=${CMAKE_C_COMPILER}"
                "CXX=${CMAKE_CXX_COMPILER}"
                "LD=${CMAKE_LINKER}"
                "AR=${CMAKE_AR}"
                "RANLIB=${CMAKE_RANLIB}"
                "CFLAGS=${CMAKE_C_FLAGS} -fPIC"
                "CXXFLAGS=${CMAKE_CXX_FLAGS} -fPIC"
                "LIBS=-ldl"
                sh configure ${_curl_configure_args}
            COMMAND ${CMAKE_COMMAND} -E chdir ${CURL_BUILD_SOURCE_DIR}
                ${OVERLAYBD_MAKE_EXECUTABLE} -j${OVERLAYBD_SUBBUILD_JOBS}
            COMMAND ${CMAKE_COMMAND} -E chdir ${CURL_BUILD_SOURCE_DIR}
                ${OVERLAYBD_MAKE_EXECUTABLE} install
            DEPENDS
                ${curl_bundle_SOURCE_DIR}/configure.ac
                "${_curl_build_signature}"
                "${OPENSSL_SSL_LIBRARY}"
                "${CMAKE_CURRENT_LIST_FILE}"
            VERBATIM)
        add_custom_target(libcurl_static_build DEPENDS
            ${curl_bundle_BINARY_DIR}/lib/libcurl.a
            ${curl_bundle_BINARY_DIR}/include/curl/curl.h)
        add_dependencies(libcurl_static_build OpenSSL::SSL OpenSSL::Crypto)
        make_directory(${curl_bundle_BINARY_DIR}/include)
    endif()

    set(CURL_FOUND yes)
    set(CURL_LIBRARY ${curl_bundle_BINARY_DIR}/lib/libcurl.a)
    set(CURL_THIRDPARTY_DEPS OpenSSL::SSL OpenSSL::Crypto z)
    set(CURL_LIBRARIES CURL::libcurl)
    set(CURL_INCLUDE_DIR ${curl_bundle_BINARY_DIR}/include)
    set(CURL_INCLUDE_DIRS ${CURL_INCLUDE_DIR})
    set(CURL_VERSION_STRING 7.42.1)

    # Use libcurl static lib instead of cmake defined shared lib
    if(NOT TARGET CURL::libcurl)
        add_library(CURL::libcurl UNKNOWN IMPORTED)
    endif()
    add_dependencies(CURL::libcurl libcurl_static_build)
    message("${CURL_LIBRARY}")
    set_target_properties(
        CURL::libcurl
        PROPERTIES IMPORTED_LINK_INTERFACE_LANGUAGES "C"
                   IMPORTED_LOCATION "${CURL_LIBRARY}"
                   INTERFACE_INCLUDE_DIRECTORIES "${CURL_INCLUDE_DIRS}"
                   INTERFACE_LINK_LIBRARIES "${CURL_THIRDPARTY_DEPS}")
else()
    include(${CMAKE_ROOT}/Modules/FindCURL.cmake)
endif()
