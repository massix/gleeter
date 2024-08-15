import birl
import gleam/uri
import simplifile
import startest.{describe, it}
import startest/expect
import xkcd/api

pub fn xkcd_tests() {
  describe("xkcd/api", [decode_test()])
}

fn check_result(
  file sample_file: String,
  title expected_title: String,
  num expected_num: Int,
  date expected_date: String,
  img expected_img_url: String,
) {
  let assert Ok(data) = simplifile.read(sample_file)
  let assert Ok(expected_img_url) = uri.parse(expected_img_url)

  let api.Xkcd(number:, title:, img_url:, publication_date:, ..) =
    api.api_decoder(data)
    |> expect.to_be_ok

  expect.to_equal(number, expected_num)
  expect.to_equal(title, expected_title)
  expect.to_equal(birl.to_naive_date_string(publication_date), expected_date)
  expect.to_equal(img_url, expected_img_url)
}

fn decode_test() {
  describe("decode", [
    it("can decode sample_1", fn() {
      check_result(
        file: "test_data/sample_1.json",
        num: 361,
        title: "Christmas Back Home",
        img: "https://imgs.xkcd.com/comics/christmas_back_home.png",
        date: "2007-12-24",
      )
    }),
    it("can decode sample_2", fn() {
      check_result(
        file: "test_data/sample_2.json",
        num: 120,
        title: "Dating Service",
        img: "https://imgs.xkcd.com/comics/dating_service.png",
        date: "2006-06-26",
      )
    }),
    it("can decode sample_3", fn() {
      check_result(
        file: "test_data/sample_3.json",
        num: 440,
        title: "Road Rage",
        img: "https://imgs.xkcd.com/comics/road_rage.png",
        date: "2008-06-23",
      )
    }),
  ])
}
