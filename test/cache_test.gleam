import birdie
import birl
import cache
import gleam/int
import gleam/iterator
import gleam/option
import gleam/regex
import gleam/uri
import pprint
import startest.{describe, it}
import xkcd/api

fn random_comic() -> iterator.Iterator(api.Xkcd) {
  let first =
    api.Xkcd(
      birl.now(),
      1,
      option.None,
      option.None,
      "safe title",
      option.None,
      "alternative text",
      {
        let assert Ok(uri) = uri.parse("https://xkcd.com/image/1.png")
        uri
      },
      "title",
    )

  iterator.unfold(first, fn(current_xkcd) {
    let api.Xkcd(number:, ..) = current_xkcd
    let assert Ok(uri) =
      uri.parse("https://xkcd.com/image/" <> int.to_string(number + 1))

    let new_xkcd =
      api.Xkcd(
        ..current_xkcd,
        number: number + 1,
        img_url: uri,
        publication_date: birl.now(),
      )
    iterator.Next(current_xkcd, new_xkcd)
  })
}

// Removes the //Erl part from a pprinted string
// //erl(#Ref<0.2449756419.657850390.181484>) -> ErlRef
fn remove_erl(in: String) -> String {
  let assert Ok(regex) =
    regex.compile("//erl\\(.*?\\)", regex.Options(False, False))
  regex.replace(regex, in, "ErlRef")
}

pub fn cache_tests() {
  describe("cache", [
    it("init", fn() {
      cache.new(":memory:")
      |> pprint.format
      |> remove_erl
      |> birdie.snap(title: "Cache system OK")

      cache.new("file:/no_write_permission.db")
      |> pprint.format
      |> birdie.snap(title: "Cache system KO")
    }),
    it("insert", fn() {
      let assert Ok(comic) =
        random_comic() |> iterator.drop(15) |> iterator.first

      cache.new(":memory:")
      |> cache.insert_comic(comic)
      |> pprint.format
      |> remove_erl
      |> birdie.snap("Insert comic in DB")
    }),
  ])
}
