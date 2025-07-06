import gleam/option.{None, Some}
import gleeter/config
import gleeter/serve
import startest.{describe, it}
import startest/expect
import startest/test_tree.{type TestTree}

pub fn serve_tests() -> TestTree {
  let default_empty_config = config.Configuration(None, None, None, None, [])

  let metrics_config = config.MetricsConfiguration(True, None)
  let config_with_ignore =
    config.Configuration(None, None, None, Some(metrics_config), [])
  describe("gleeter/serve", [
    it("strips base path", fn() {
      serve.strip_base_path(["a", "b"], ["a", "b", "c"], default_empty_config)
      |> expect.to_be_ok()
      |> expect.to_equal(["c"])
    }),
    it("errors if request does not match", fn() {
      serve.strip_base_path(["a", "b"], ["metrics"], default_empty_config)
      |> expect.to_be_error()
    }),
    it("ignores base path for /metrics if specified", fn() {
      serve.strip_base_path(["a", "b"], ["metrics"], config_with_ignore)
      |> expect.to_be_ok()
      |> expect.to_equal(["metrics"])
    }),
  ])
}
