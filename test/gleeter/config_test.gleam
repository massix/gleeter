import envoy
import gleam/option.{None, Some}
import gleeter/config.{
  Configuration, IdAlias, LatestAlias, RandomAlias, get_configuration_file,
  parse,
}
import startest.{describe, it}
import startest/expect
import startest/test_tree

pub fn config_tests() -> test_tree.TestTree {
  describe("gleeter/config", [
    it("returns the path for the configuration file", fn() {
      envoy.set("HOME", "/home/user")
      envoy.set("XDG_CONFIG_HOME", "/home/user/.config")
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
        Configuration(Some(38), Some(80), Some(23), [
          IdAlias("bobbytables", 987),
          RandomAlias("rnd"),
          LatestAlias("l"),
        ]),
      )
    }),
    it("ignores invalid stuff", fn() {
      parse("test_data/config_invalid.toml")
      |> expect.to_equal(
        Configuration(None, Some(31), None, [IdAlias("valid", 123)]),
      )
    }),
    it("returns empty configuration if file is missing", fn() {
      parse("test_data/nonexistant.toml")
      |> expect.to_equal(Configuration(None, None, None, []))
    }),
  ])
}
