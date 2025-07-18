import envoy
import gleam/option.{None, Some}
import gleeter/config.{
  Configuration, IdAlias, LatestAlias, MetricsConfiguration, RandomAlias,
  get_configuration_file, parse,
}
import startest.{describe, it}
import startest/expect
import startest/test_tree

pub fn config_tests() -> test_tree.TestTree {
  describe("gleeter/config", [
    it("returns the path for the configuration file", fn() {
      // Here we are also testing the different priority levels.
      envoy.set("GLEETER_CONFIG_FILE", "/tmp/config.toml")
      envoy.set("HOME", "/home/user")
      envoy.set("XDG_CONFIG_HOME", "/home/user/.config")

      get_configuration_file()
      |> expect.to_equal("/tmp/config.toml")

      envoy.unset("GLEETER_CONFIG_FILE")
      get_configuration_file()
      |> expect.to_equal("/home/user/.config/gleeter/config.toml")

      envoy.unset("XDG_CONFIG_HOME")
      get_configuration_file()
      |> expect.to_equal("/home/user/.config/gleeter/config.toml")

      envoy.unset("HOME")
      get_configuration_file()
      |> expect.to_equal("./gleeter/config.toml")
    }),
    it("parses configuration", fn() {
      parse("test_data/config.toml")
      |> expect.to_equal(
        Configuration(Some(38), Some(80), Some(23), None, [
          IdAlias("bobbytables", 987),
          IdAlias("trimmed_alias", 987),
          RandomAlias("rnd"),
          LatestAlias("l"),
        ]),
      )
    }),
    it("ignores invalid stuff", fn() {
      parse("test_data/config_invalid.toml")
      |> expect.to_equal(
        Configuration(None, Some(31), None, None, [IdAlias("valid", 123)]),
      )
    }),
    it("returns empty configuration if file is missing", fn() {
      parse("test_data/nonexistant.toml")
      |> expect.to_equal(Configuration(None, None, None, None, []))
    }),
    describe("metrics", [
      it("parses all values if they are present", fn() {
        parse("test_data/config_metrics.toml")
        |> expect.to_equal(
          Configuration(
            None,
            None,
            None,
            Some(MetricsConfiguration(True, Some(#("username", "password")))),
            [],
          ),
        )
      }),
      it("skips username or password if one is missing", fn() {
        parse("test_data/config_metrics_missing.toml")
        |> expect.to_equal(
          Configuration(
            None,
            None,
            None,
            Some(MetricsConfiguration(False, None)),
            [],
          ),
        )
      }),
    ]),
  ])
}
