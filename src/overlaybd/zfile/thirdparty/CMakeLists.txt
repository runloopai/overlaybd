include(ExternalProject)

if(ENABLE_DSA)
    set(DML_INSTALL_DIR "${CMAKE_CURRENT_BINARY_DIR}/dml-install")
    set(DML_LIBRARY "${DML_INSTALL_DIR}/lib/libdmlhl.a")
    set(_dml_utility_patch "${CMAKE_SOURCE_DIR}/CMake/patches/dml-include-utility.patch")
    file(MAKE_DIRECTORY "${DML_INSTALL_DIR}/include")

    set(_dml_cmake_args
        -DCMAKE_BUILD_TYPE=Release
        -DCMAKE_INSTALL_PREFIX=${DML_INSTALL_DIR}
        -DCMAKE_C_COMPILER=${CMAKE_C_COMPILER}
        -DCMAKE_CXX_COMPILER=${CMAKE_CXX_COMPILER}
        -DCMAKE_C_FLAGS=${CMAKE_C_FLAGS}
        -DCMAKE_CXX_FLAGS=${CMAKE_CXX_FLAGS})
    if(CMAKE_TOOLCHAIN_FILE)
        list(APPEND _dml_cmake_args -DCMAKE_TOOLCHAIN_FILE=${CMAKE_TOOLCHAIN_FILE})
    endif()

    ExternalProject_Add(dml_external
        SOURCE_DIR "${CMAKE_CURRENT_SOURCE_DIR}/DML"
        BINARY_DIR "${CMAKE_CURRENT_BINARY_DIR}/dml-build"
        CONFIGURE_COMMAND ""
        BUILD_COMMAND ${CMAKE_COMMAND} --build <BINARY_DIR> --parallel ${OVERLAYBD_SUBBUILD_JOBS}
        INSTALL_COMMAND ${CMAKE_COMMAND} --install <BINARY_DIR>
        BUILD_BYPRODUCTS "${DML_LIBRARY}"
        PATCH_COMMAND sh -c "git apply --reverse --check '${_dml_utility_patch}' 2>/dev/null || git apply '${_dml_utility_patch}'"
        UPDATE_COMMAND "")
    ExternalProject_Add_Step(dml_external overlaybd_configure
        COMMAND ${CMAKE_COMMAND}
            -S <SOURCE_DIR>
            -B <BINARY_DIR>
            ${_dml_cmake_args}
        DEPENDEES download
        DEPENDERS build
        ALWAYS TRUE)

    add_library(DML::dmlhl STATIC IMPORTED GLOBAL)
    set_target_properties(DML::dmlhl PROPERTIES
        IMPORTED_LOCATION "${DML_LIBRARY}"
        INTERFACE_INCLUDE_DIRECTORIES "${DML_INSTALL_DIR}/include")
    add_dependencies(DML::dmlhl dml_external)
endif()

if(ENABLE_ISAL)
    set(ISAL_BUILD_SOURCE_DIR "${CMAKE_CURRENT_BINARY_DIR}/isa-l-source")
    set(ISAL_LIBRARY "${ISAL_BUILD_SOURCE_DIR}/.libs/libisal.a")
    set(ISAL_INCLUDE_DIR "${ISAL_BUILD_SOURCE_DIR}/include")
    set(_isal_build_signature "${CMAKE_CURRENT_BINARY_DIR}/isa-l-build-config")
    file(GENERATE OUTPUT "${_isal_build_signature}" CONTENT
        "CC=${CMAKE_C_COMPILER}\nAR=${CMAKE_AR}\nRANLIB=${CMAKE_RANLIB}\nCFLAGS=${CMAKE_C_FLAGS}\nTRIPLET=${OVERLAYBD_TARGET_TRIPLET}\n")
    file(MAKE_DIRECTORY "${ISAL_INCLUDE_DIR}")
    set(_isal_configure_args --enable-static --disable-shared)
    if(CMAKE_CROSSCOMPILING)
        if(OVERLAYBD_TARGET_TRIPLET)
            list(APPEND _isal_configure_args --host=${OVERLAYBD_TARGET_TRIPLET})
        elseif(CMAKE_C_COMPILER_TARGET)
            list(APPEND _isal_configure_args --host=${CMAKE_C_COMPILER_TARGET})
        elseif(OVERLAYBD_SYSTEM_PROCESSOR MATCHES "^(aarch64|arm64)$")
            list(APPEND _isal_configure_args --host=aarch64-linux-gnu)
        else()
            list(APPEND _isal_configure_args --host=x86_64-linux-gnu)
        endif()
    endif()

    add_custom_command(
        OUTPUT "${ISAL_LIBRARY}" "${ISAL_INCLUDE_DIR}/crc.h"
        COMMAND ${CMAKE_COMMAND} -E remove_directory "${ISAL_BUILD_SOURCE_DIR}"
        COMMAND ${CMAKE_COMMAND} -E copy_directory
            "${CMAKE_CURRENT_SOURCE_DIR}/isa-l" "${ISAL_BUILD_SOURCE_DIR}"
        COMMAND ${CMAKE_COMMAND} -E chdir "${ISAL_BUILD_SOURCE_DIR}"
            ${CMAKE_COMMAND} -E env
            "CC=${CMAKE_C_COMPILER}"
            "AR=${CMAKE_AR}"
            "RANLIB=${CMAKE_RANLIB}"
            "CFLAGS=${CMAKE_C_FLAGS} -fPIC"
            /bin/sh ./autogen.sh
        COMMAND ${CMAKE_COMMAND} -E chdir "${ISAL_BUILD_SOURCE_DIR}"
            ${CMAKE_COMMAND} -E env
            "CC=${CMAKE_C_COMPILER}"
            "AR=${CMAKE_AR}"
            "RANLIB=${CMAKE_RANLIB}"
            "CFLAGS=${CMAKE_C_FLAGS} -fPIC"
            /bin/sh ./configure ${_isal_configure_args}
        COMMAND ${CMAKE_COMMAND} -E chdir "${ISAL_BUILD_SOURCE_DIR}"
            ${OVERLAYBD_MAKE_EXECUTABLE} -j${OVERLAYBD_SUBBUILD_JOBS}
        WORKING_DIRECTORY "${CMAKE_CURRENT_BINARY_DIR}"
        DEPENDS
            "${CMAKE_CURRENT_SOURCE_DIR}/isa-l/autogen.sh"
            "${CMAKE_CURRENT_SOURCE_DIR}/isa-l/configure.ac"
            "${_isal_build_signature}"
            "${CMAKE_CURRENT_LIST_FILE}"
        VERBATIM)
    add_custom_target(isal_external DEPENDS "${ISAL_LIBRARY}" "${ISAL_INCLUDE_DIR}/crc.h")

    add_library(ISA_L::isal STATIC IMPORTED GLOBAL)
    set_target_properties(ISA_L::isal PROPERTIES
        IMPORTED_LOCATION "${ISAL_LIBRARY}"
        INTERFACE_INCLUDE_DIRECTORIES "${ISAL_INCLUDE_DIR}")
    add_dependencies(ISA_L::isal isal_external)
endif()
