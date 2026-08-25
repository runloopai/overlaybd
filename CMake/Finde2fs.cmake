if(NOT ORIGIN_EXT2FS)
    message("Add and build standalone libext2fs")
    include(FetchContent)
    set(_e2fsprogs_htree_patch "${CMAKE_CURRENT_LIST_DIR}/patches/e2fsprogs-fix-htree-root-limit.patch")
    FetchContent_Declare(
        e2fsprogs
        GIT_REPOSITORY https://github.com/data-accelerator/e2fsprogs.git
        GIT_TAG b4cf6c751196a12b1df9a269d8e0b516b99fe6a7
        PATCH_COMMAND sh -c "git apply --reverse --check '${_e2fsprogs_htree_patch}' 2>/dev/null || git apply '${_e2fsprogs_htree_patch}'"
    )
    FetchContent_GetProperties(e2fsprogs)

    if(NOT TARGET libext2fs_build)
        if (NOT e2fsprogs_POPULATED)
            FetchContent_Populate(e2fsprogs)
        endif()
        set(LIBEXT2FS_BUILD_DIR "${e2fsprogs_BINARY_DIR}/overlaybd-build")
        set(LIBEXT2FS_INSTALL_DIR "${LIBEXT2FS_BUILD_DIR}/install" CACHE PATH
            "Bundled e2fsprogs installation directory")
        set(E2FS_LIBRARY "${LIBEXT2FS_INSTALL_DIR}/lib/libext2fs.so")
        set(E2FS_INCLUDE_DIR "${LIBEXT2FS_INSTALL_DIR}/include")
        set(_e2fs_build_signature "${e2fsprogs_BINARY_DIR}/overlaybd-build-config")
        file(GENERATE OUTPUT "${_e2fs_build_signature}" CONTENT
            "CC=${CMAKE_C_COMPILER}\nCXX=${CMAKE_CXX_COMPILER}\nAR=${CMAKE_AR}\nRANLIB=${CMAKE_RANLIB}\nCFLAGS=${CMAKE_C_FLAGS}\nCXXFLAGS=${CMAKE_CXX_FLAGS}\nTRIPLET=${OVERLAYBD_TARGET_TRIPLET}\n")

        set(_e2fs_configure_args
            --enable-elf-shlibs
            --disable-debugfs
            --disable-imager
            --disable-resizer
            --disable-defrag
            --disable-uuidd
            --disable-fuse2fs
            --disable-fsck
            --disable-e2initrd-helper
            "--prefix=${LIBEXT2FS_INSTALL_DIR}")
        if(CMAKE_CROSSCOMPILING)
            # e2fsprogs generates CRC tables with executables that must run on
            # the build host.  Keep those tools on the host compiler even
            # though the libraries themselves use the target compiler.
            find_program(_e2fs_build_cc NAMES cc gcc REQUIRED)
            if(OVERLAYBD_TARGET_TRIPLET)
                list(APPEND _e2fs_configure_args "--host=${OVERLAYBD_TARGET_TRIPLET}")
            elseif(CMAKE_C_COMPILER_TARGET)
                list(APPEND _e2fs_configure_args "--host=${CMAKE_C_COMPILER_TARGET}")
            elseif(OVERLAYBD_SYSTEM_PROCESSOR MATCHES "^(aarch64|arm64)$")
                list(APPEND _e2fs_configure_args --host=aarch64-linux-gnu)
            else()
                list(APPEND _e2fs_configure_args --host=x86_64-linux-gnu)
            endif()
        endif()

        add_custom_command(
            OUTPUT "${E2FS_LIBRARY}" "${E2FS_INCLUDE_DIR}/ext2fs/ext2fs.h"
            BYPRODUCTS
                "${LIBEXT2FS_INSTALL_DIR}/lib/libext2fs.a"
                "${LIBEXT2FS_INSTALL_DIR}/lib/libcom_err.a"
            COMMAND ${CMAKE_COMMAND} -E remove_directory "${LIBEXT2FS_BUILD_DIR}"
            COMMAND ${CMAKE_COMMAND} -E make_directory "${LIBEXT2FS_BUILD_DIR}"
            COMMAND ${CMAKE_COMMAND} -E chdir "${LIBEXT2FS_BUILD_DIR}"
                ${CMAKE_COMMAND} -E env
                "CC=${CMAKE_C_COMPILER}"
                "CXX=${CMAKE_CXX_COMPILER}"
                "AR=${CMAKE_AR}"
                "RANLIB=${CMAKE_RANLIB}"
                $<$<BOOL:${CMAKE_CROSSCOMPILING}>:BUILD_CC=${_e2fs_build_cc}>
                $<$<BOOL:${CMAKE_CROSSCOMPILING}>:BUILD_CFLAGS=-O2>
                "CFLAGS=${CMAKE_C_FLAGS} -fPIC -O3"
                "CXXFLAGS=${CMAKE_CXX_FLAGS} -fPIC -O3"
                "${e2fsprogs_SOURCE_DIR}/configure" ${_e2fs_configure_args}
            COMMAND ${CMAKE_COMMAND} -E chdir "${LIBEXT2FS_BUILD_DIR}"
                ${OVERLAYBD_MAKE_EXECUTABLE} -j${OVERLAYBD_SUBBUILD_JOBS}
                $<$<BOOL:${CMAKE_CROSSCOMPILING}>:BUILD_CC=${_e2fs_build_cc}>
                $<$<BOOL:${CMAKE_CROSSCOMPILING}>:BUILD_CFLAGS=-O2>
            COMMAND ${CMAKE_COMMAND} -E chdir "${LIBEXT2FS_BUILD_DIR}"
                ${OVERLAYBD_MAKE_EXECUTABLE} install-libs
                $<$<BOOL:${CMAKE_CROSSCOMPILING}>:BUILD_CC=${_e2fs_build_cc}>
                $<$<BOOL:${CMAKE_CROSSCOMPILING}>:BUILD_CFLAGS=-O2>
            WORKING_DIRECTORY "${e2fsprogs_BINARY_DIR}"
            DEPENDS
                "${e2fsprogs_SOURCE_DIR}/configure"
                "${_e2fs_build_signature}"
                "${_e2fsprogs_htree_patch}"
                "${CMAKE_CURRENT_LIST_FILE}"
            VERBATIM
        )
        add_custom_target(libext2fs_build DEPENDS
            "${E2FS_LIBRARY}" "${E2FS_INCLUDE_DIR}/ext2fs/ext2fs.h")
    endif()

    set(E2FS_FOUND yes)
    set(E2FS_LIBRARIES ${E2FS_LIBRARY})
    set(E2FS_INCLUDE_DIRS ${E2FS_INCLUDE_DIR})

    # Imported targets validate include paths while generating the build graph.
    file(MAKE_DIRECTORY "${E2FS_INCLUDE_DIR}")

    if(NOT TARGET E2FSPROGS::libext2fs)
        add_library(E2FSPROGS::libext2fs SHARED IMPORTED GLOBAL)
        set_target_properties(E2FSPROGS::libext2fs PROPERTIES
            IMPORTED_LOCATION "${E2FS_LIBRARY}"
            INTERFACE_INCLUDE_DIRECTORIES "${E2FS_INCLUDE_DIR}")
    endif()
    add_dependencies(E2FSPROGS::libext2fs libext2fs_build)

else()
    find_path(E2FS_INCLUDE_DIRS ext2fs/ext2fs.h)
    find_library(E2FS_LIBRARY ext2fs)
    set(E2FS_LIBRARIES ${E2FS_LIBRARY})
    if(E2FS_LIBRARY AND NOT TARGET E2FSPROGS::libext2fs)
        add_library(E2FSPROGS::libext2fs UNKNOWN IMPORTED GLOBAL)
        set_target_properties(E2FSPROGS::libext2fs PROPERTIES
            IMPORTED_LOCATION "${E2FS_LIBRARY}"
            INTERFACE_INCLUDE_DIRECTORIES "${E2FS_INCLUDE_DIRS}")
    endif()
endif()

find_package_handle_standard_args(e2fs DEFAULT_MSG E2FS_LIBRARIES E2FS_INCLUDE_DIRS)

mark_as_advanced(E2FS_INCLUDE_DIRS E2FS_LIBRARY E2FS_LIBRARIES)
