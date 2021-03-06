public struct ClientResponse {
    public var status: HTTPStatus
    public var headers: HTTPHeaders
    public var body: ByteBuffer?

    public init(status: HTTPStatus = .ok, headers: HTTPHeaders = [:], body: ByteBuffer? = nil) {
        self.status = status
        self.headers = headers
        self.body = body
    }
}

extension ClientResponse {
    private struct _ContentContainer: ContentContainer {
        var body: ByteBuffer?
        var headers: HTTPHeaders

        var contentType: HTTPMediaType? {
            return self.headers.contentType
        }

        mutating func encode<E>(_ encodable: E, using encoder: ContentEncoder) throws where E : Encodable {
            var body = ByteBufferAllocator().buffer(capacity: 0)
            try encoder.encode(encodable, to: &body, headers: &self.headers)
            self.body = body
        }

        func decode<D>(_ decodable: D.Type, using decoder: ContentDecoder) throws -> D where D : Decodable {
            guard let body = self.body else {
                throw Abort(.lengthRequired)
            }
            return try decoder.decode(D.self, from: body, headers: self.headers)
        }
    }

    public var content: ContentContainer {
        get {
            return _ContentContainer(body: self.body, headers: self.headers)
        }
        set {
            let container = (newValue as! _ContentContainer)
            self.body = container.body
            self.headers = container.headers
        }
    }
}

extension ClientResponse: CustomStringConvertible {
    public var description: String {
        var desc = ["HTTP/1.1 \(status.code) \(status.reasonPhrase)"]
        desc += self.headers.map { "\($0.name): \($0.value)" }
        if var body = self.body {
            let string = body.readString(length: body.readableBytes) ?? ""
            desc += ["", string]
        }
        return desc.joined(separator: "\n")
    }
}

extension ClientResponse: ResponseEncodable {
    public func encodeResponse(for request: Request) -> EventLoopFuture<Response> {
        let body: Response.Body
        if let buffer = self.body {
            body = .init(buffer: buffer)
        } else {
            body = .empty
        }
        let response = Response(
            status: self.status,
            headers: self.headers,
            body: body
        )
        return request.eventLoop.makeSucceededFuture(response)
    }
}

extension ClientResponse: Codable {
    private enum CodingKeys: String, CodingKey {
        case status = "status"
        case headers = "headers"
        case body = "body"
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.status = try container.decode(HTTPStatus.self, forKey: .status)
        self.headers = try container.decode(HTTPHeaders.self, forKey: .headers)
        let bodyString = try container.decode(String?.self, forKey: .body)
        guard let s = bodyString, let bodyData = Data(base64Encoded: s) else {
            throw Abort(.internalServerError, reason: "Could not decode client response body from base64 string")
        }
        var body = ByteBufferAllocator().buffer(capacity: 0)
        body.writeBytes(bodyData)
        self.body = body
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(self.status, forKey: .status)
        try container.encode(self.headers, forKey: .headers)
        if let body = self.body {
            let string = Data(body.readableBytesView).base64EncodedString()
            try container.encode(string, forKey: .body)
        } else {
            try container.encodeNil(forKey: .body)
        }
    }
}

extension ClientResponse: Equatable { }
