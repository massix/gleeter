import envoy
import gleam/option.{None, Some}
import gleeter/config.{
  Configuration, IdAlias, LatestAlias, MetricsConfiguration, RandomAlias,
  get_configuration_file, parse,
}
import gleeunit/should

pub fn config_get_configuration_file_test() {
  envoy.set("GLEETER_CONFIG_FILE", "/tmp/config.toml")
  envoy.set("HOME", "/home/user")
  envoy.set("XDG_CONFIG_HOME", "/home/user/.config")

  get_configuration_file()
  |> should.equal("/tmp/config.toml")

  envoy.unset("GLEETER_CONFIG_FILE")
  get_configuration_file()
  |> should.equal("/home/user/.config/gleeter/config.toml")

  envoy.unset("XDG_CONFIG_HOME")
  get_configuration_file()
  |> should.equal("/home/user/.config/gleeter/config.toml")

  envoy.unset("HOME")
  get_configuration_file()
  |> should.equal("./gleeter/config.toml")
}

pub fn config_parses_configuration_test() {
  parse("test_data/config.toml")
  |> should.equal(
    Configuration(Some(38), Some(80), Some(23), None, [
      IdAlias("bobbytables", 987),
      IdAlias("trimmed_alias", 987),
      RandomAlias("rnd"),
      LatestAlias("l"),
    ]),
  )
}

pub fn config_ignores_invalid_stuff_test() {
  parse("test_data/config_invalid.toml")
  |> should.equal(
    Configuration(None, Some(31), None, None, [IdAlias("valid", 123)]),
  )
}

pub fn config_returns_empty_configuration_if_file_is_missing_test() {
  parse("test_data/nonexistant.toml")
  |> should.equal(Configuration(None, None, None, None, []))
}

pub fn config_metrics_parses_all_values_if_present_test() {
  parse("test_data/config_metrics.toml")
  |> should.equal(
    Configuration(
      None,
      None,
      None,
      Some(MetricsConfiguration(True, Some(#("username", "password")))),
      [],
    ),
  )
}

pub fn config_metrics_skips_credentials_if_one_is_missing_test() {
  parse("test_data/config_metrics_missing.toml")
  |> should.equal(
    Configuration(None, None, None, Some(MetricsConfiguration(False, None)), []),
  )
}
