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
        set(LIBEXT2FS_INSTALL_DIR ${e2fsprogs_SOURCE_DIR}/build/libext2fs CACHE STRING "")

        add_custom_command(
            OUTPUT ${LIBEXT2FS_INSTALL_DIR}/lib
            WORKING_DIRECTORY ${e2fsprogs_SOURCE_DIR}
            COMMAND chmod 755 build.sh && ./build.sh
        )
        add_custom_target(libext2fs_build DEPENDS ${LIBEXT2FS_INSTALL_DIR}/lib)
    endif()

    set(E2FS_FOUND yes)
    set(E2FS_LIBRARY ${LIBEXT2FS_INSTALL_DIR}/lib/libext2fs.so)
    set(E2FS_LIBRARIES ${E2FS_LIBRARY})
    set(E2FS_INCLUDE_DIR ${LIBEXT2FS_INSTALL_DIR}/include)
    set(E2FS_INCLUDE_DIRS ${E2FS_INCLUDE_DIR})

    if(NOT TARGET libext2fs)
        add_library(libext2fs UNKNOWN IMPORTED)
    endif()
    add_dependencies(libext2fs libext2fs_build)

else()
    find_path(E2FS_INCLUDE_DIRS ext2fs/ext2fs.h)
    find_library(E2FS_LIBRARIES ext2fs)
endif()

find_package_handle_standard_args(e2fs DEFAULT_MSG E2FS_LIBRARIES E2FS_INCLUDE_DIRS)

mark_as_advanced(E2FS_INCLUDE_DIRS E2FS_LIBRARIES)
