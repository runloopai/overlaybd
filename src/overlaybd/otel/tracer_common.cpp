#include "tracer_common.h"

#include "context_storage.h"
#include "opentelemetry/context/runtime_context.h"

using opentelemetry::nostd::unique_ptr;
using opentelemetry::nostd::shared_ptr;
using opentelemetry::nostd::string_view;
using opentelemetry::nostd::function_ref;

namespace overlaybd_otel {

void InitTracer() {
    // Install a libphoton coroutine-aware context storage implementation, which uses libphoton's thread-local implementation.
    opentelemetry::context::RuntimeContext::SetRuntimeContextStorage(
        unique_ptr<opentelemetry::context::RuntimeContextStorage>(
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
    opentelemetry::sdk::trace::Provider::SetTracerProvider({});
}

opentelemetry::nostd::shared_ptr<opentelemetry::trace::Tracer> GetTracer(opentelemetry::nostd::string_view tracer_name) {
    return opentelemetry::trace::Provider::GetTracerProvider()->GetTracer(tracer_name);
}

class JsonTextMapCarrier : public opentelemetry::context::propagation::TextMapCarrier {
public:
    JsonTextMapCarrier(const rapidjson::Document& traceContext): m_traceContext(traceContext) {}

    string_view Get(string_view key) const noexcept override {
        for (auto iter = m_traceContext.MemberBegin(); iter != m_traceContext.MemberEnd(); ++iter) {
            if (key == iter->name.GetString() && iter->value.IsString()) {
                return iter->value.GetString();
            }
        }
        return {};
    }

    void Set(string_view key, string_view value) noexcept override {
        // not implemented
    }

private:
    const rapidjson::Document& m_traceContext;
};

opentelemetry::context::Context ExtractTraceContext(const rapidjson::Document& document) {
    if (!document.IsObject()) {
        return {};
    }

    // Extract the traceContext if it exists.
    opentelemetry::context::Context context;
    auto carrier = JsonTextMapCarrier(document);
    auto propagator = opentelemetry::trace::propagation::HttpTraceContext();
    return propagator.Extract(carrier, context);
}

} // namespace overlaybd_otel
