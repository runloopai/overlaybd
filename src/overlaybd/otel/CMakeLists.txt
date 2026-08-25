set(SOURCE_OTEL
    tracer_common.cpp
    context_storage.cpp
)

include(FetchContent)
FetchContent_Declare(
    opentelemetry-cpp
    GIT_REPOSITORY https://github.com/open-telemetry/opentelemetry-cpp.git
    GIT_TAG v1.22.0
    GIT_SHALLOW TRUE
    GIT_SUBMODULES
        third_party/nlohmann-json
        third_party/opentelemetry-proto
)

# Set OpenTelemetry build options without leaking them into OverlayBD's cache.
set(_otel_saved_BUILD_TESTING "${BUILD_TESTING}")
set(_otel_saved_WITH_EXAMPLES "${WITH_EXAMPLES}")
set(_otel_saved_OPENTELEMETRY_INSTALL "${OPENTELEMETRY_INSTALL}")
set(_otel_saved_WITH_OTLP_GRPC "${WITH_OTLP_GRPC}")
set(_otel_saved_WITH_OTLP_HTTP "${WITH_OTLP_HTTP}")
set(_otel_saved_WITH_FUNC_TESTS "${WITH_FUNC_TESTS}")
set(_otel_saved_BUILD_SHARED_LIBS "${BUILD_SHARED_LIBS}")
set(BUILD_TESTING OFF CACHE BOOL "Build tests" FORCE)
set(WITH_EXAMPLES OFF CACHE BOOL "Build examples" FORCE)
set(OPENTELEMETRY_INSTALL ON CACHE BOOL "Install OpenTelemetry" FORCE)
set(WITH_OTLP_GRPC OFF CACHE BOOL "Build with OTLP GRPC" FORCE)
set(WITH_OTLP_HTTP ON CACHE BOOL "Build with OTLP HTTP" FORCE)
set(WITH_FUNC_TESTS OFF CACHE BOOL "Build functional tests" FORCE)
set(BUILD_SHARED_LIBS OFF CACHE BOOL "Build with shared library" FORCE)

FetchContent_MakeAvailable(opentelemetry-cpp)

set(BUILD_TESTING "${_otel_saved_BUILD_TESTING}" CACHE BOOL "Build tests" FORCE)
set(WITH_EXAMPLES "${_otel_saved_WITH_EXAMPLES}" CACHE BOOL "Build examples" FORCE)
set(OPENTELEMETRY_INSTALL "${_otel_saved_OPENTELEMETRY_INSTALL}" CACHE BOOL
    "Install OpenTelemetry" FORCE)
set(WITH_OTLP_GRPC "${_otel_saved_WITH_OTLP_GRPC}" CACHE BOOL "Build OTLP gRPC" FORCE)
set(WITH_OTLP_HTTP "${_otel_saved_WITH_OTLP_HTTP}" CACHE BOOL "Build OTLP HTTP" FORCE)
set(WITH_FUNC_TESTS "${_otel_saved_WITH_FUNC_TESTS}" CACHE BOOL
    "Build functional tests" FORCE)
set(BUILD_SHARED_LIBS "${_otel_saved_BUILD_SHARED_LIBS}" CACHE BOOL
    "Build shared libraries" FORCE)

add_library(otel_lib STATIC ${SOURCE_OTEL})
set_target_properties(otel_lib PROPERTIES LINKER_LANGUAGE CXX)

target_include_directories(otel_lib PUBLIC 
    ${CMAKE_CURRENT_SOURCE_DIR}
    ${PHOTON_INCLUDE_DIR}
    ${opentelemetry-cpp_SOURCE_DIR}/api/include
    ${opentelemetry-cpp_SOURCE_DIR}/sdk/include
    ${opentelemetry-cpp_SOURCE_DIR}/exporters/otlp/include
    ${opentelemetry-cpp_SOURCE_DIR}/ext/include 
)

# Link against specific OpenTelemetry targets
target_link_libraries(otel_lib PRIVATE
    opentelemetry-cpp::api
    opentelemetry-cpp::sdk
    opentelemetry-cpp::trace
    opentelemetry-cpp::otlp_http_client
    opentelemetry-cpp::http_client_curl
    opentelemetry-cpp::ext
    opentelemetry-cpp::otlp_http_exporter
)
