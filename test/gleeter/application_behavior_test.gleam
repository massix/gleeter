import gleeter/application_behavior
import gleeter/config.{IdAlias, LatestAlias, RandomAlias}
import gleeunit/should

fn aliases() {
  [
    IdAlias("bobbytables", 327),
    LatestAlias("ltst"),
    IdAlias("tenthousands", 1053),
    LatestAlias("lt"),
    RandomAlias("rnd"),
  ]
}

pub fn application_behavior_default_behavior_test() {
  application_behavior.parse_arguments([], aliases(), False)
  |> should.equal(application_behavior.Help)
}

pub fn application_behavior_invalid_id_fails_silently_test() {
  application_behavior.parse_arguments(["id", "not a number"], aliases(), False)
  |> should.equal(application_behavior.Help)
}

pub fn application_behavior_valid_id_changes_behavior_test() {
  application_behavior.parse_arguments(["id", "14"], aliases(), False)
  |> should.equal(application_behavior.WithIDComic(14, False))
}

pub fn application_behavior_uses_cache_flag_default_value_test() {
  application_behavior.parse_arguments(["id", "24"], aliases(), False)
  |> should.equal(application_behavior.WithIDComic(24, False))
}

pub fn application_behavior_gets_cache_value_from_short_flag_test() {
  application_behavior.parse_arguments(["-n", "random"], aliases(), False)
  |> should.equal(application_behavior.RandomComic(True))
}

pub fn application_behavior_gets_cache_value_from_long_flag_test() {
  application_behavior.parse_arguments(
    ["--no-cache", "random"],
    aliases(),
    False,
  )
  |> should.equal(application_behavior.RandomComic(True))
}

pub fn application_behavior_ignores_cache_flag_after_command_test() {
  application_behavior.parse_arguments(["id", "24", "-n"], aliases(), False)
  |> should.equal(application_behavior.WithIDComic(24, False))
}

pub fn application_behavior_uses_latest_alias_test() {
  application_behavior.parse_arguments(["lt"], aliases(), False)
  |> should.equal(application_behavior.LatestComic(False))

  application_behavior.parse_arguments(["ltst"], aliases(), False)
  |> should.equal(application_behavior.LatestComic(False))
}

pub fn application_behavior_uses_random_alias_test() {
  application_behavior.parse_arguments(["rnd"], aliases(), False)
  |> should.equal(application_behavior.RandomComic(False))
}

pub fn application_behavior_recognizes_bobbytables_alias_test() {
  application_behavior.parse_arguments(["bobbytables"], aliases(), False)
  |> should.equal(application_behavior.WithIDComic(327, False))
}

pub fn application_behavior_recognizes_tenthousands_alias_test() {
  application_behavior.parse_arguments(["tenthousands"], aliases(), False)
  |> should.equal(application_behavior.WithIDComic(1053, False))
}

pub fn application_behavior_serve_without_parameters_test() {
  application_behavior.parse_arguments(["serve"], aliases(), False)
  |> should.equal(application_behavior.Serve(8080, ""))
}

pub fn application_behavior_serve_with_port_test() {
  application_behavior.parse_arguments(["serve", "9000"], aliases(), False)
  |> should.equal(application_behavior.Serve(9000, ""))
}

pub fn application_behavior_serve_with_non_int_port_test() {
  application_behavior.parse_arguments(
    ["serve", "not a number"],
    aliases(),
    False,
  )
  |> should.equal(application_behavior.Serve(8080, ""))
}

pub fn application_behavior_serve_with_port_and_path_test() {
  application_behavior.parse_arguments(
    ["serve", "9000", "/xkcd"],
    aliases(),
    False,
  )
  |> should.equal(application_behavior.Serve(9000, "/xkcd"))
}

pub fn application_behavior_detects_help_test() {
  application_behavior.parse_arguments(["--help"], [], False)
  |> should.equal(application_behavior.Help)

  application_behavior.parse_arguments(["help"], [], False)
  |> should.equal(application_behavior.Help)
}

pub fn application_behavior_detects_version_test() {
  application_behavior.parse_arguments(["--version"], [], False)
  |> should.equal(application_behavior.PrintVersion)

  application_behavior.parse_arguments(["version"], [], False)
  |> should.equal(application_behavior.PrintVersion)
}

pub fn application_behavior_detects_clearcache_command_test() {
  application_behavior.parse_arguments(["clearcache"], [], False)
  |> should.equal(application_behavior.ClearCache)
}
