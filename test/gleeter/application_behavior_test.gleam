import gleeter/application_behavior
import gleeter/config.{IdAlias, LatestAlias, RandomAlias}
import startest.{describe, it}
import startest/expect

pub fn application_behavior_tests() {
  let aliases = [
    IdAlias("bobbytables", 327),
    LatestAlias("ltst"),
    IdAlias("tenthousands", 1053),
    LatestAlias("lt"),
    RandomAlias("rnd"),
  ]
  describe("application_behavior", [
    it("default behavior", fn() {
      application_behavior.parse_arguments([], aliases, False)
      |> expect.to_equal(application_behavior.Help)
    }),
    it("if id is invalid, fails silently", fn() {
      application_behavior.parse_arguments(
        ["id", "not a number"],
        aliases,
        False,
      )
      |> expect.to_equal(application_behavior.Help)
    }),
    it("if id is valid, behavior is changed", fn() {
      application_behavior.parse_arguments(["id", "14"], aliases, False)
      |> expect.to_equal(application_behavior.WithIDComic(14, False))
    }),
    describe("cache flag", [
      it("uses the default value if no flag is specified", fn() {
        application_behavior.parse_arguments(["id", "24"], aliases, False)
        |> expect.to_equal(application_behavior.WithIDComic(24, False))
      }),
      it("gets the value to use from the short flag", fn() {
        application_behavior.parse_arguments(["-n", "random"], aliases, False)
        |> expect.to_equal(application_behavior.RandomComic(True))
      }),
      it("gets the value to use from the long flag", fn() {
        application_behavior.parse_arguments(
          ["--no-cache", "random"],
          aliases,
          False,
        )
        |> expect.to_equal(application_behavior.RandomComic(True))
      }),
      it("ignores the flag if it is it after the command", fn() {
        application_behavior.parse_arguments(["id", "24", "-n"], aliases, False)
        |> expect.to_equal(application_behavior.WithIDComic(24, False))
      }),
    ]),
    describe("aliases", [
      it("correctly uses a latest alias", fn() {
        application_behavior.parse_arguments(["lt"], aliases, False)
        |> expect.to_equal(application_behavior.LatestComic(False))

        application_behavior.parse_arguments(["ltst"], aliases, False)
        |> expect.to_equal(application_behavior.LatestComic(False))
      }),
      it("correctly uses a random alias", fn() {
        application_behavior.parse_arguments(["rnd"], aliases, False)
        |> expect.to_equal(application_behavior.RandomComic(False))
      }),
      it("recognizes named aliases (bobbytables)", fn() {
        application_behavior.parse_arguments(["bobbytables"], aliases, False)
        |> expect.to_equal(application_behavior.WithIDComic(327, False))
      }),
      it("recognizes named aliases (tenthousands)", fn() {
        application_behavior.parse_arguments(["tenthousands"], aliases, False)
        |> expect.to_equal(application_behavior.WithIDComic(1053, False))
      }),
    ]),
    describe("serve", [
      it("witout parameters", fn() {
        application_behavior.parse_arguments(["serve"], aliases, False)
        |> expect.to_equal(application_behavior.Serve(8080, ""))
      }),
      it("port specified", fn() {
        application_behavior.parse_arguments(["serve", "9000"], aliases, False)
        |> expect.to_equal(application_behavior.Serve(9000, ""))
      }),
      it("port not an int", fn() {
        application_behavior.parse_arguments(
          ["serve", "not a number"],
          aliases,
          False,
        )
        |> expect.to_equal(application_behavior.Serve(8080, ""))
      }),
      it("port and path specified", fn() {
        application_behavior.parse_arguments(
          ["serve", "9000", "/xkcd"],
          aliases,
          False,
        )
        |> expect.to_equal(application_behavior.Serve(9000, "/xkcd"))
      }),
    ]),
    describe("other commands", [
      it("detects help and --help", fn() {
        application_behavior.parse_arguments(["--help"], [], False)
        |> expect.to_equal(application_behavior.Help)

        application_behavior.parse_arguments(["help"], [], False)
        |> expect.to_equal(application_behavior.Help)
      }),
      it("detects version and --version", fn() {
        application_behavior.parse_arguments(["--version"], [], False)
        |> expect.to_equal(application_behavior.PrintVersion)

        application_behavior.parse_arguments(["version"], [], False)
        |> expect.to_equal(application_behavior.PrintVersion)
      }),
      it("detects the clearcache command", fn() {
        application_behavior.parse_arguments(["clearcache"], [], False)
        |> expect.to_equal(application_behavior.ClearCache)
      }),
    ]),
  ])
}
