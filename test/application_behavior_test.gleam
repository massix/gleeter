import application_behavior
import startest.{describe, it}
import startest/expect

pub fn application_behavior_tests() {
  describe("application_behavior", [
    it("default behavior", fn() {
      application_behavior.parse_arguments([], application_behavior.RandomComic)
      |> expect.to_equal(application_behavior.RandomComic)
    }),
    it("last argument wins", fn() {
      application_behavior.parse_arguments(
        ["random", "latest", "id", "4", "latest"],
        application_behavior.RandomComic,
      )
      |> expect.to_equal(application_behavior.LatestComic)
    }),
    it("if id is invalid, fails silently", fn() {
      application_behavior.parse_arguments(
        ["id", "not a number"],
        application_behavior.LatestComic,
      )
      |> expect.to_equal(application_behavior.LatestComic)
    }),
    it("if id is valid, behavior is changed", fn() {
      application_behavior.parse_arguments(
        ["id", "14"],
        application_behavior.RandomComic,
      )
      |> expect.to_equal(application_behavior.WithIDComic(14))
    }),
  ])
}
