import birdie
import birl
import cache.{type Cache}
import gleam/option
import gleam/regexp
import gleam/uri
import pprint
import startest.{describe, it}
import startest/expect
import startest/test_tree.{type TestTree}
import xkcd/api

fn remove_erlref(in: String) -> String {
  let assert Ok(re) = regexp.from_string("Esqlite3\\(.*\\)")
  regexp.replace(each: re, in:, with: "Esqlite3(ErlRef)")
}

fn cache_init_tests(valid_cache: Cache) -> List(TestTree) {
  [
    it("ok", fn() {
      valid_cache
      |> pprint.format
      |> remove_erlref
      |> birdie.snap("cache_init_ok")
    }),
    it("ko (invalid path)", fn() {
      cache.new("/non-writable/test.db")
      |> pprint.format
      |> remove_erlref
      |> birdie.snap("cache_init_ko")
    }),
  ]
}

fn cache_insert_comic_tests(valid_cache: Cache) -> List(TestTree) {
  [
    it("insert new reference", fn() {
      let assert Ok(img_url) = uri.parse("https://example.com/img1.png")
      let comic =
        api.Xkcd(
          number: 320,
          alternative_text: "alt_text",
          img_url:,
          link: option.Some("https://link"),
          news: option.None,
          publication_date: birl.now(),
          safe_title: "Safe title",
          title: "Title",
          transcript: option.Some("Transcript"),
        )

      valid_cache
      |> cache.insert_comic(comic)
      |> pprint.format
      |> remove_erlref
      |> birdie.snap("cache_insert_ok")
    }),
  ]
}

fn cache_insert_image_tests(valid_cache: Cache) -> List(TestTree) {
  [
    it("new image with correct reference", fn() {
      let comic_number = 320
      let comic_data = "comic_data"

      valid_cache
      |> cache.insert_image(comic_number, comic_data)
      |> pprint.format
      |> remove_erlref
      |> birdie.snap("cache_insert_image_ok")
    }),
    it("fail if fk not respected", fn() {
      valid_cache
      |> cache.insert_image(321, "comic_data")
      |> pprint.format
      |> remove_erlref
      |> birdie.snap("cache_insert_image_ko")
    }),
  ]
}

pub fn cache_tests() {
  let valid_cache = cache.new(":memory:")

  describe("cache", [
    describe("init", cache_init_tests(valid_cache)),
    describe("comic insert", cache_insert_comic_tests(valid_cache)),
    describe("image insert", cache_insert_image_tests(valid_cache)),
  ])
}
