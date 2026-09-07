import gleam/option.{None, Some}
import gleeter/config
import gleeter/serve
import gleeunit/should

fn default_empty_config() -> config.Configuration {
  config.Configuration(None, None, None, None, [])
}

fn config_with_ignore() -> config.Configuration {
  config.Configuration(
    None,
    None,
    None,
    Some(config.MetricsConfiguration(True, None)),
    [],
  )
}

pub fn strips_base_path_test() {
  serve.strip_base_path(["a", "b"], ["a", "b", "c"], default_empty_config())
  |> should.be_ok()
  |> should.equal(["c"])
}

pub fn errors_if_request_does_not_match_test() {
  serve.strip_base_path(["a", "b"], ["metrics"], default_empty_config())
  |> should.be_error()
}

pub fn ignores_base_path_for_metrics_if_specified_test() {
  serve.strip_base_path(["a", "b"], ["metrics"], config_with_ignore())
  |> should.be_ok()
  |> should.equal(["metrics"])
}
