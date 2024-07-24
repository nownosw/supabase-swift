//
//  PostgrestTypedBuilder.swift
//
//
//  Created by Guilherme Souza on 20/06/24.
//

import ConcurrencyExtras
import Foundation
import Helpers

public class PostgrestTypedBuilder<Model: PostgrestModel, Response: Sendable>: @unchecked Sendable {
  let configuration: PostgrestClient.Configuration
  let http: any HTTPClientType
  let request: LockIsolated<HTTPRequest>

  init(
    configuration: PostgrestClient.Configuration,
    request: HTTPRequest
  ) {
    self.configuration = configuration
    self.request = LockIsolated(request)

    var interceptors: [any HTTPClientInterceptor] = []
    if let logger = configuration.logger {
      interceptors.append(LoggerInterceptor(logger: logger))
    }

    http = HTTPClient(fetch: configuration.fetch, interceptors: interceptors)
  }

  public func execute() async throws where Response == Void {
    try await execute { _ in }
  }

  @discardableResult
  public func execute() async throws -> Response where Response: PostgrestDecodable {
    try await execute {
      try $0.decoded(as: Response.self, decoder: Response.decoder)
    }
  }

  private func execute(decode: (HTTPResponse) throws -> Response) async throws -> Response {
    let response = try await http.send(request.value)

    guard 200 ..< 300 ~= response.statusCode else {
      if let error = try? configuration.decoder.decode(PostgrestError.self, from: response.data) {
        throw error
      }

      throw HTTPError(data: response.data, response: response.underlyingResponse)
    }

    return try decode(response)
  }
}
