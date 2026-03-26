file(GLOB SOURCE_LSMT "*.cpp")

add_library(lsmt_lib STATIC ${SOURCE_LSMT})
target_include_directories(lsmt_lib PUBLIC
    ${PHOTON_INCLUDE_DIR}
)

if(ENABLE_REWRITE_STATS)
    target_compile_definitions(lsmt_lib PRIVATE ENABLE_REWRITE_STATS)
endif()

if(BUILD_TESTING)
  add_subdirectory(test)
endif()
