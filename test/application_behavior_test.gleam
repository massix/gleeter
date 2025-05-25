import application_behavior
import startest.{describe, it}
import startest/expect

pub fn application_behavior_tests() {
  describe("application_behavior", [
    it("default behavior", fn() {
      application_behavior.parse_arguments([])
      |> expect.to_equal(application_behavior.PrintVersion)
    }),
    it("if id is invalid, fails silently", fn() {
      application_behavior.parse_arguments(["id", "not a number"])
      |> expect.to_equal(application_behavior.LatestComic)
    }),
    it("if id is valid, behavior is changed", fn() {
      application_behavior.parse_arguments(["id", "14"])
      |> expect.to_equal(application_behavior.WithIDComic(14))
    }),
    describe("serve", [
      it("witout parameters", fn() {
        application_behavior.parse_arguments(["serve"])
        |> expect.to_equal(application_behavior.Serve(8080, ""))
      }),
      it("port specified", fn() {
        application_behavior.parse_arguments(["serve", "9000"])
        |> expect.to_equal(application_behavior.Serve(9000, ""))
      }),
      it("port not an int", fn() {
        application_behavior.parse_arguments(["serve", "not a number"])
        |> expect.to_equal(application_behavior.Serve(8080, ""))
      }),
      it("port and path specified", fn() {
        application_behavior.parse_arguments(["serve", "9000", "/xkcd"])
        |> expect.to_equal(application_behavior.Serve(9000, "/xkcd"))
      }),
    ]),
  ])
}
