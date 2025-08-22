#include "opentelemetry/context/runtime_context.h"
#include "tracer_common.h"
#include "context_storage.h"

namespace overlaybd_otel {

void InitTracer() {
    // Install a libphoton coroutine-aware context storage implementation, which uses libphoton's thread-local implementation.
    opentelemetry::context::RuntimeContext::SetRuntimeContextStorage(
        opentelemetry::nostd::unique_ptr<opentelemetry::context::RuntimeContextStorage>(
            new LibPhotonContextStorage()));
    
    // Create OTLP/HTTP exporter using the factory
    std::vector<std::unique_ptr<opentelemetry::sdk::trace::SpanProcessor>> processors;
    processors.push_back(
        opentelemetry::sdk::trace::BatchSpanProcessorFactory::Create(
            opentelemetry::exporter::otlp::OtlpHttpExporterFactory::Create(), {}));

    // Default is an always-on sampler
    std::shared_ptr<opentelemetry::trace::TracerProvider> provider =
        opentelemetry::sdk::trace::TracerProviderFactory::Create(
            opentelemetry::sdk::trace::TracerContextFactory::Create(std::move(processors)));

    // Set the global trace provider
    opentelemetry::sdk::trace::Provider::SetTracerProvider(provider);
}

void CleanupTracer() {
    std::shared_ptr<opentelemetry::trace::TracerProvider> none;
    opentelemetry::sdk::trace::Provider::SetTracerProvider(none);
}

opentelemetry::nostd::shared_ptr<opentelemetry::trace::Tracer> GetTracer(opentelemetry::nostd::string_view tracer_name) {
    return opentelemetry::trace::Provider::GetTracerProvider()->GetTracer(tracer_name);
}

} // namespace overlaybd_otel
