import envoy
import gleam/bit_array
import gleam/bytes_tree.{type BytesTree}
import gleam/dynamic.{type Dynamic}
import gleam/http
import gleam/http/request.{type Request}
import gleam/http/response.{type Response, Response}
import gleam/list
import gleam/option
import gleam/result
import gleam/string
import gleam/uri

/// Order matters: the first environment variable set wins.
const ssl_cert_file_env_names: List(String) = [
  "GLEETER_SSL_CERT_FILE",
  "NIX_SSL_CERT_FILE",
  "SSL_CERT_FILE",
]

pub type Error {
  InvalidUtf8Response
  // TODO: refine error type
  Other(Dynamic)
}

/// Returns the path of the first `*_SSL_CERT_FILE` environment variable that
/// is set to a non-empty value, if any.
pub fn cacert_file() -> option.Option(String) {
  case
    ssl_cert_file_env_names
    |> list.filter_map(envoy.get)
    |> list.find(fn(path) { string.trim(path) != "" })
  {
    Ok(path) -> option.Some(path)
    Error(_) -> option.None
  }
}

@external(erlang, "gleeter_hackney_ffi", "send")
fn ffi_send(
  method: String,
  url: String,
  headers: List(http.Header),
  body: BytesTree,
  cacert_file: String,
) -> Result(Response(BitArray), Error)

pub fn send_bits(
  request: Request(BytesTree),
) -> Result(Response(BitArray), Error) {
  let method = http.method_to_string(request.method)
  let cacert_file = option.unwrap(cacert_file(), "")

  use response <- result.try(
    request
    |> request.to_uri
    |> uri.to_string
    |> ffi_send(method, _, request.headers, request.body, cacert_file),
  )

  let headers = list.map(response.headers, normalise_header)
  Ok(Response(..response, headers: headers))
}

pub fn send(req: Request(String)) -> Result(Response(String), Error) {
  use resp <- result.try(
    req
    |> request.map(bytes_tree.from_string)
    |> send_bits,
  )

  case bit_array.to_string(resp.body) {
    Ok(body) -> Ok(response.set_body(resp, body))
    Error(_) -> Error(InvalidUtf8Response)
  }
}

fn normalise_header(header: http.Header) -> http.Header {
  #(string.lowercase(header.0), header.1)
}
