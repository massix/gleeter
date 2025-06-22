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
      application_behavior.parse_arguments([], aliases)
      |> expect.to_equal(application_behavior.Help)
    }),
    it("if id is invalid, fails silently", fn() {
      application_behavior.parse_arguments(["id", "not a number"], aliases)
      |> expect.to_equal(application_behavior.Help)
    }),
    it("if id is valid, behavior is changed", fn() {
      application_behavior.parse_arguments(["id", "14"], aliases)
      |> expect.to_equal(application_behavior.WithIDComic(14))
    }),
    describe("aliases", [
      it("correctly uses a latest alias", fn() {
        application_behavior.parse_arguments(["lt"], aliases)
        |> expect.to_equal(application_behavior.LatestComic)

        application_behavior.parse_arguments(["ltst"], aliases)
        |> expect.to_equal(application_behavior.LatestComic)
      }),
      it("correctly uses a random alias", fn() {
        application_behavior.parse_arguments(["rnd"], aliases)
        |> expect.to_equal(application_behavior.RandomComic)
      }),
      it("recognizes named aliases (bobbytables)", fn() {
        application_behavior.parse_arguments(["bobbytables"], aliases)
        |> expect.to_equal(application_behavior.WithIDComic(327))
      }),
      it("recognizes named aliases (tenthousands)", fn() {
        application_behavior.parse_arguments(["tenthousands"], aliases)
        |> expect.to_equal(application_behavior.WithIDComic(1053))
      }),
    ]),
    describe("serve", [
      it("witout parameters", fn() {
        application_behavior.parse_arguments(["serve"], aliases)
        |> expect.to_equal(application_behavior.Serve(8080, ""))
      }),
      it("port specified", fn() {
        application_behavior.parse_arguments(["serve", "9000"], aliases)
        |> expect.to_equal(application_behavior.Serve(9000, ""))
      }),
      it("port not an int", fn() {
        application_behavior.parse_arguments(["serve", "not a number"], aliases)
        |> expect.to_equal(application_behavior.Serve(8080, ""))
      }),
      it("port and path specified", fn() {
        application_behavior.parse_arguments(
          ["serve", "9000", "/xkcd"],
          aliases,
        )
        |> expect.to_equal(application_behavior.Serve(9000, "/xkcd"))
      }),
    ]),
  ])
}
