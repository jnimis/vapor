@testable import Vapor
import XCTest

final class HTTPHeaderValueTests: XCTestCase {
    func testValue() throws {
        var parser = HTTPHeaders.DirectiveParser(string: "foobar")
        XCTAssertEqual(parser.nextDirectives(), [.init(value: "foobar")])
    }

    func testValue_whitespace() throws {
        var parser = HTTPHeaders.DirectiveParser(string: " foobar  ")
        XCTAssertEqual(parser.nextDirectives(), [.init(value: "foobar")])
    }

    func testValue_semicolon_quote() throws {
        var parser = HTTPHeaders.DirectiveParser(string: #""foo;bar""#)
        XCTAssertEqual(parser.nextDirectives(), [
            .init(value: "foo;bar")
        ])
    }

    func testValue_semicolon_quote_escape() throws {
        var parser = HTTPHeaders.DirectiveParser(string: #""foo;\"bar""#)
        XCTAssertEqual(parser.nextDirectives(), [
            .init(value: #"foo;"bar"#)
        ])
    }

    func testValue_directives() throws {
        var parser = HTTPHeaders.DirectiveParser(string: #"a; b=c, d"#)
        XCTAssertEqual(parser.nextDirectives(), [
            .init(value: "a"),
            .init(value: "b", parameter: "c"),
        ])
        XCTAssertEqual(parser.nextDirectives(), [
            .init(value: "d")
        ])
    }

    func testValue_directives_quote() throws {
        var parser = HTTPHeaders.DirectiveParser(string: #""a;b"; c="d;e", f"#)
        XCTAssertEqual(parser.nextDirectives(), [
            .init(value: "a;b"),
            .init(value: "c", parameter: "d;e"),
        ])
        XCTAssertEqual(parser.nextDirectives(), [
            .init(value: "f")
        ])
    }

    func testValue_directives_contentType() throws {
        var parser = HTTPHeaders.DirectiveParser(string: "application/json; charset=utf8")
        XCTAssertEqual(parser.nextDirectives(), [
            .init(value: "application/json"),
            .init(value: "charset", parameter: "utf8"),
        ])
    }

    func testValue_directives_multiple() throws {
        var parser = HTTPHeaders.DirectiveParser(string: "foo; bar=1; baz=2")
        XCTAssertEqual(parser.nextDirectives(), [
            .init(value: "foo"),
            .init(value: "bar", parameter: "1"),
            .init(value: "baz", parameter: "2"),
        ])
    }

    func testValue_directives_multiple_quote() throws {
        var parser = HTTPHeaders.DirectiveParser(string: #"foo; bar=1; baz="2""#)
        XCTAssertEqual(parser.nextDirectives(), [
            .init(value: "foo"),
            .init(value: "bar", parameter: "1"),
            .init(value: "baz", parameter: "2"),
        ])
    }

    func testValue_directives_multiple_quotedSemicolon() throws {
        var parser = HTTPHeaders.DirectiveParser(string: #"foo; bar=1; baz="2;3""#)
        XCTAssertEqual(parser.nextDirectives(), [
            .init(value: "foo"),
            .init(value: "bar", parameter: "1"),
            .init(value: "baz", parameter: "2;3"),
        ])
    }

    func testValue_directives_multiple_quotedSemicolonEqual() throws {
        var parser = HTTPHeaders.DirectiveParser(string: #"foo; bar=1; baz="2;=3""#)
        XCTAssertEqual(parser.nextDirectives(), [
            .init(value: "foo"),
            .init(value: "bar", parameter: "1"),
            .init(value: "baz", parameter: "2;=3"),
        ])
    }

    func testValue_serialize() throws {
        let serializer = HTTPHeaders.DirectiveSerializer.init(directives: [
            [.init(value: "foo"), .init(value: "bar", parameter: "baz")],
            [.init(value: "qux", parameter: "quuz")]
        ])
        XCTAssertEqual(serializer.serialize(), "foo; bar=baz, qux=quuz")
    }

    func testForwarded() throws {
        var headers = HTTPHeaders()
        headers.replaceOrAdd(name: .forwarded, value: "for=192.0.2.60;proto=http;by=203.0.113.43")
        XCTAssertEqual(headers.forwarded.first?.for, "192.0.2.60")
        XCTAssertEqual(headers.forwarded.first?.proto, "http")
        XCTAssertEqual(headers.forwarded.first?.by, "203.0.113.43")
    }

    func testForwarded_quote() throws {
        var headers = HTTPHeaders()
        headers.replaceOrAdd(name: .forwarded, value: #"For="[2001:db8:cafe::17]:4711""#)
        XCTAssertEqual(headers.forwarded.first?.for, "[2001:db8:cafe::17]:4711")
    }

    func testForwarded_multiple() throws {
        var headers = HTTPHeaders()
        headers.replaceOrAdd(name: .forwarded, value: #"for=192.0.2.43, for="[2001:db8:cafe::17]""#)
        XCTAssertEqual(headers.forwarded.map { $0.for }, [
            "192.0.2.43",
            "[2001:db8:cafe::17]",
        ])
    }

    func testForwarded_multiple_deprecated() throws {
        let headers = HTTPHeaders([
            ("X-Forwarded-For", "192.0.2.43, 2001:db8:cafe::17 ")
        ])
        XCTAssertEqual(headers.forwarded.map { $0.for }, [
            "192.0.2.43",
            "2001:db8:cafe::17",
        ])
    }

    func testForwarded_serialization() throws {
        var headers = HTTPHeaders()
        headers.forwarded.append(.init(
            by: "203.0.113.43",
            for: "192.0.2.60",
            host: nil,
            proto: "http"
        ))
        XCTAssertEqual(
            headers.first(name: "Forwarded"),
            "by=203.0.113.43; for=192.0.2.60; proto=http"
        )
    }

    func testContentDisposition() throws {
        let headers = HTTPHeaders([
            ("Content-Disposition", #"form-data; name="fieldName"; filename="filename.jpg""#)
        ])
        XCTAssertEqual(headers.contentDisposition?.value, .formData)
        XCTAssertEqual(headers.contentDisposition?.name, "fieldName")
        XCTAssertEqual(headers.contentDisposition?.filename, "filename.jpg")
    }

    func testCookie_parsing() throws {
        let headers = HTTPHeaders([
            ("cookie", "vapor-session=0FuTYcHmGw7Bz1G4HiF+EA==; _ga=GA1.1.500315824.1585154561; _gid=GA1.1.500224287.1585154561")
        ])
        XCTAssertEqual(headers.cookie?["vapor-session"]?.string, "0FuTYcHmGw7Bz1G4HiF+EA==")
        XCTAssertEqual(headers.cookie?["_ga"]?.string, "GA1.1.500315824.1585154561")
        XCTAssertEqual(headers.cookie?["_gid"]?.string, "GA1.1.500224287.1585154561")
    }
}
