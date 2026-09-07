import birdie
import birl
import envoy
import gleam/option
import gleam/regexp
import gleam/string
import gleam/uri
import gleeter/cache
import gleeter/xkcd
import gleeunit/should
import pprint

fn remove_erlref(in: String) -> String {
  let assert Ok(re) = regexp.from_string("Esqlite3\\(.*\\)")
  regexp.replace(each: re, in:, with: "Esqlite3(ErlRef)")
}

fn comic_320() -> xkcd.Xkcd {
  let assert Ok(img_url) = uri.parse("https://example.com/img1.png")
  let assert Ok(now) = birl.parse("2025-05-10T16:34:23.342Z")
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
}

pub fn cache_is_loaded_test() {
  cache.new(":memory:")
  |> cache.is_cache_loaded
  |> should.be_true
}

pub fn cache_location_uses_xdg_cache_home_test() {
  envoy.set("XDG_CACHE_HOME", "/xdg-cache-home")
  should.be_true(string.starts_with(
    cache.get_cache_location(),
    "/xdg-cache-home",
  ))
}

pub fn cache_location_falls_back_to_home_test() {
  envoy.unset("XDG_CACHE_HOME")
  envoy.set("HOME", "/home")

  string.starts_with(cache.get_cache_location(), "/home")
  |> should.be_true()
}

pub fn cache_location_falls_back_to_memory_test() {
  envoy.unset("XDG_CACHE_HOME")
  envoy.unset("HOME")

  string.contains(cache.get_cache_location(), ":memory:")
  |> should.be_true()
}

pub fn cache_init_ok_test() {
  cache.new(":memory:")
  |> pprint.format
  |> remove_erlref
  |> birdie.snap("cache_init_ok")
}

pub fn cache_init_ko_test() {
  cache.new("/non-writable/test.db")
  |> pprint.format
  |> remove_erlref
  |> birdie.snap("cache_init_ko")
}

pub fn cache_insert_comic_test() {
  cache.new(":memory:")
  |> cache.insert_comic(comic_320())
  |> pprint.format
  |> remove_erlref
  |> birdie.snap("cache_insert_ok")
}

pub fn cache_insert_image_ok_test() {
  let valid_cache = cache.new(":memory:")
  valid_cache |> cache.insert_comic(comic_320()) |> fn(_) { Nil }
  valid_cache
  |> cache.insert_image(320, "comic_data", <<"Image Data":utf8>>)
  |> pprint.format
  |> remove_erlref
  |> birdie.snap("cache_insert_image_ok")
}

pub fn cache_insert_image_fk_not_respected_test() {
  cache.new(":memory:")
  |> cache.insert_image(321, "comic_data", <<>>)
  |> pprint.format
  |> remove_erlref
  |> birdie.snap("cache_insert_image_ko")
}

pub fn cache_get_comic_ok_test() {
  let valid_cache = cache.new(":memory:")
  valid_cache |> cache.insert_comic(comic_320()) |> fn(_) { Nil }
  valid_cache
  |> cache.insert_image(320, "comic_data", <<"Image Data":utf8>>)
  |> fn(_) { Nil }
  valid_cache
  |> cache.get_comic(320)
  |> should.be_some
  |> pprint.format
  |> birdie.snap("cache_get_comic_ok")
}

pub fn cache_get_comic_missing_test() {
  cache.new(":memory:")
  |> cache.get_comic(1024)
  |> should.be_none
}

pub fn cache_get_comic_no_image_test() {
  let valid_cache = cache.new(":memory:")
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
  |> should.be_none
}

pub fn cache_count_elements_test() {
  let valid_cache = cache.new(":memory:")
  valid_cache |> cache.insert_comic(comic_320()) |> fn(_) { Nil }
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

  cache.count_elements(valid_cache)
  |> should.be_some
  |> should.equal(2)
}

pub fn cache_clear_test() {
  let valid_cache = cache.new(":memory:")
  valid_cache |> cache.insert_comic(comic_320()) |> fn(_) { Nil }
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
  |> cache.clear
  |> cache.count_elements
  |> should.be_some
  |> should.equal(0)
}
