import gleam/option.{None, Some}
import gleeter/config.{Configuration, IdAlias, LatestAlias, RandomAlias, parse}
import startest.{describe, it}
import startest/expect
import startest/test_tree

pub fn config_tests() -> test_tree.TestTree {
  describe("gleeter/config", [
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
