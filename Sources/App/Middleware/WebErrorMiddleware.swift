import Vapor

public final class WebErrorMiddleware: Middleware {
    
    public static func `default`(environment: Environment) -> ErrorMiddleware {
        return .init { req, error in
            // Report the error to logger.
            req.logger.report(error: error)

            // inspect the error type
            switch error {
            case let abort as AbortError:
                // this is an abort error, we should use its status, reason, and headers
                switch abort.status {
                case .notFound:
                    return req.redirect(to: "/404")
                case .internalServerError:
                    return Response(status: abort.status, headers: [:])
                default:
                    return req.redirect(to: "/")
                }
            default:
                return req.redirect(to: "/")
            }
        }
    }
    
    /// Error-handling closure.
    private let closure: (Request, Error) -> (Response)
    
    /// Create a new `ErrorMiddleware`.
    ///
    /// - parameters:
    ///     - closure: Error-handling closure. Converts `Error` to `Response`.
    public init(_ closure: @escaping (Request, Error) -> (Response)) {
        self.closure = closure
    }
    
    /// See `Middleware`.
    public func respond(to request: Request, chainingTo next: Responder) -> EventLoopFuture<Response> {
        return next.respond(to: request).flatMapErrorThrowing { error in
            return self.closure(request, error)
        }
    }
}
