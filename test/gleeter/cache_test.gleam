import birdie
import birl
import envoy
import gleam/option
import gleam/regexp
import gleam/uri
import gleeter/cache.{type Cache}
import gleeter/xkcd
import pprint
import startest.{describe, it}
import startest/expect
import startest/test_tree.{type TestTree}

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
      let assert Ok(now) = birl.parse("2025-05-10T16:34:23.342Z")
      let comic =
        xkcd.Xkcd(
          number: 320,
          alternative_text: "alt_text",
          img_url:,
          link: option.Some("https://link"),
          news: option.None,
          publication_date: now,
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
      |> cache.insert_image(comic_number, comic_data, <<"Image Data":utf8>>)
      |> pprint.format
      |> remove_erlref
      |> birdie.snap("cache_insert_image_ok")
    }),
    it("fail if fk not respected", fn() {
      valid_cache
      |> cache.insert_image(321, "comic_data", <<>>)
      |> pprint.format
      |> remove_erlref
      |> birdie.snap("cache_insert_image_ko")
    }),
  ]
}

fn cache_get_comic_tests(valid_cache: Cache) -> List(TestTree) {
  [
    it("retrieve existing comic", fn() {
      valid_cache
      |> cache.get_comic(320)
      |> expect.to_be_some
      |> pprint.format
      |> birdie.snap("cache_get_comic_ok")
    }),
    it("fails if comic does not exist", fn() {
      valid_cache
      |> cache.get_comic(1024)
      |> expect.to_be_none
    }),
    it("returns empty data if there is no data", fn() {
      let assert Ok(now) = birl.parse("2025-05-10T16:30:34Z")
      let assert Ok(uri) = uri.parse("https://example.com/1.png")
      valid_cache
      |> cache.insert_comic(xkcd.Xkcd(
        now,
        120,
        option.None,
        option.None,
        "safe_title",
        option.None,
        "alt_text",
        uri,
        "title",
      ))

      valid_cache
      |> cache.get_comic(120)
      |> expect.to_be_none
    }),
  ]
}

pub fn cache_tests() {
  let valid_cache = cache.new(":memory:")

  describe("cache", [
    describe("location", [
      it("fetches the right environment variable", fn() {
        envoy.set("XDG_CACHE_HOME", "/xdg-cache-home")
        cache.get_cache_location()
        |> expect.string_to_start_with("/xdg-cache-home")
      }),
      it("falls back to HOME if XDG_CACHE_HOME does not exist", fn() {
        envoy.unset("XDG_CACHE_HOME")
        envoy.set("HOME", "/home")

        cache.get_cache_location()
        |> expect.string_to_start_with("/home")
      }),
      it("falls back to :memory: if no variables are set", fn() {
        envoy.unset("XDG_CACHE_HOME")
        envoy.unset("HOME")

        cache.get_cache_location()
        |> expect.string_to_contain(":memory:")
      }),
    ]),
    describe("init", cache_init_tests(valid_cache)),
    describe("comic insert", cache_insert_comic_tests(valid_cache)),
    describe("image insert", cache_insert_image_tests(valid_cache)),
    describe("get comic", cache_get_comic_tests(valid_cache)),
  ])
}
