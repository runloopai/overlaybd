#include "context_storage.h"

#include <vector>

#include "photon/thread/thread-local.h"

using opentelemetry::context::Context;
using opentelemetry::context::Token;

static std::vector<Context>& GetStack() {
    static photon::thread_local_ptr<std::vector<Context>> stack;
    return *stack;
}

namespace overlaybd_otel {

Context LibPhotonContextStorage::GetCurrent() noexcept {
    std::vector<Context>& stack = GetStack();
    if (stack.empty()) {
        return Context();
    }
    return stack.back();
}

bool LibPhotonContextStorage::Detach(Token &token) noexcept {
    std::vector<Context>& stack = GetStack();
    if (stack.empty()) {
        return false;
    }
    for (auto it = stack.rbegin(); it != stack.rend(); ++it) {
        if (token == *it) {
            stack.erase(std::prev(it.base()), stack.end());
            return true;
        }
    }
    return false;
}

opentelemetry::nostd::unique_ptr<Token> LibPhotonContextStorage::Attach(const Context& context) noexcept {
    std::vector<Context>& stack = GetStack();
    stack.push_back(context);
    return CreateToken(context);
}

} // overlaybd_otel
