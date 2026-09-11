import envoy
import gleam/dynamic.{type Dynamic}
import gleam/list
import gleam/option.{None, Some}
import gleeter/hackney
import gleeunit/should

@external(erlang, "gleeter_hackney_ffi", "load_bundle")
fn ffi_load_bundle(path: String) -> Result(List(BitArray), Dynamic)

fn unset_all_ssl_cert_vars() -> Nil {
  envoy.unset("GLEETER_SSL_CERT_FILE")
  envoy.unset("NIX_SSL_CERT_FILE")
  envoy.unset("SSL_CERT_FILE")
}

pub fn cacert_file_returns_none_when_unset_test() {
  unset_all_ssl_cert_vars()

  hackney.cacert_file() |> should.equal(None)
}

pub fn cacert_file_prefers_gleeter_var_test() {
  envoy.set("GLEETER_SSL_CERT_FILE", "/etc/certs/gleeter.pem")
  envoy.set("NIX_SSL_CERT_FILE", "/etc/certs/nix.pem")
  envoy.set("SSL_CERT_FILE", "/etc/certs/ssl.pem")

  hackney.cacert_file() |> should.equal(Some("/etc/certs/gleeter.pem"))
}

pub fn cacert_file_falls_back_to_nix_var_test() {
  envoy.unset("GLEETER_SSL_CERT_FILE")
  envoy.set("NIX_SSL_CERT_FILE", "/etc/certs/nix.pem")
  envoy.set("SSL_CERT_FILE", "/etc/certs/ssl.pem")

  hackney.cacert_file() |> should.equal(Some("/etc/certs/nix.pem"))
}

pub fn cacert_file_falls_back_to_ssl_var_test() {
  unset_all_ssl_cert_vars()
  envoy.set("SSL_CERT_FILE", "/etc/certs/ssl.pem")

  hackney.cacert_file() |> should.equal(Some("/etc/certs/ssl.pem"))
}

pub fn cacert_file_ignores_empty_values_test() {
  unset_all_ssl_cert_vars()
  envoy.set("GLEETER_SSL_CERT_FILE", "")
  envoy.set("NIX_SSL_CERT_FILE", "   ")
  envoy.set("SSL_CERT_FILE", "/etc/certs/ssl.pem")

  hackney.cacert_file() |> should.equal(Some("/etc/certs/ssl.pem"))
}

pub fn load_bundle_reads_cert_from_pem_fixture_test() {
  let assert Ok(certs) = ffi_load_bundle("test_data/ssl_ca_test.pem")

  list.length(certs) |> should.equal(1)
}
