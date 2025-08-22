#pragma once
#include <iterator>
#include <vector>

#include "opentelemetry/context/runtime_context.h"

namespace overlaybd_otel {

// ContextStorage implementation that uses photonlib's coroutine-aware thread local storage.
class LibPhotonContextStorage : public opentelemetry::context::RuntimeContextStorage {
public:
    LibPhotonContextStorage() noexcept = default;

    opentelemetry::context::Context GetCurrent() noexcept override;

    bool Detach(opentelemetry::context::Token &token) noexcept override;

    opentelemetry::nostd::unique_ptr<opentelemetry::context::Token> Attach(const opentelemetry::context::Context& context) noexcept override;
};

} // overlaybd_otel
