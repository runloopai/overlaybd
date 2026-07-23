include(FetchContent)
set(FETCHCONTENT_QUIET false)
set(PHOTON_ENABLE_EXTFS ON)

# Runloop: patch Photon's ext4 mkfs to enable uninitialized block groups
# (gdt_csum). This lets an offline resize2fs grow of a devbox rootfs mark new
# inode tables uninitialized instead of zeroing them — a near-instant grow with
# minimal writes into the layered (COW) block format.
# Idempotent: skips if the patch is already applied (reverse-check succeeds).
set(_photon_mkfs_patch "${CMAKE_CURRENT_LIST_DIR}/patches/photon-v0.6.17-ext4-uninit-bg.patch")
FetchContent_Declare(
  photon
  GIT_REPOSITORY https://github.com/alibaba/PhotonLibOS.git
  GIT_TAG v0.6.17
  PATCH_COMMAND sh -c "git apply --reverse --check '${_photon_mkfs_patch}' 2>/dev/null || git apply '${_photon_mkfs_patch}'"
)

if(BUILD_TESTING)
  set(BUILD_TESTING 0)
  FetchContent_MakeAvailable(photon)
  set(BUILD_TESTING 1)
else()
  FetchContent_MakeAvailable(photon)
endif()

if (BUILD_CURL_FROM_SOURCE)
  find_package(openssl REQUIRED)
  find_package(curl REQUIRED)
  add_dependencies(photon_obj CURL::libcurl OpenSSL::SSL OpenSSL::Crypto)
endif()

if(NOT ORIGIN_EXT2FS)
  add_dependencies(photon_obj libext2fs)
endif()

set(PHOTON_INCLUDE_DIR ${photon_SOURCE_DIR}/include/)
