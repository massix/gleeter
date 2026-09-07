import birl
import gleam/uri
import gleeter/xkcd
import gleeunit/should
import simplifile

fn check_result(
  file sample_file: String,
  title expected_title: String,
  num expected_num: Int,
  date expected_date: String,
  img expected_img_url: String,
) -> Nil {
  let assert Ok(data) = simplifile.read(sample_file)
  let assert Ok(expected_img_url) = uri.parse(expected_img_url)

  let xkcd.Xkcd(number:, title:, img_url:, publication_date:, ..) =
    xkcd.api_decoder(data)
    |> should.be_ok()

  number |> should.equal(expected_num)
  title |> should.equal(expected_title)
  birl.to_naive_date_string(publication_date) |> should.equal(expected_date)
  img_url |> should.equal(expected_img_url)
}

pub fn xkcd_can_decode_sample_1_test() {
  check_result(
    file: "test_data/sample_1.json",
    num: 361,
    title: "Christmas Back Home",
    img: "https://imgs.xkcd.com/comics/christmas_back_home.png",
    date: "2007-12-24",
  )
}

pub fn xkcd_can_decode_sample_2_test() {
  check_result(
    file: "test_data/sample_2.json",
    num: 120,
    title: "Dating Service",
    img: "https://imgs.xkcd.com/comics/dating_service.png",
    date: "2006-06-26",
  )
}

pub fn xkcd_can_decode_sample_3_test() {
  check_result(
    file: "test_data/sample_3.json",
    num: 440,
    title: "Road Rage",
    img: "https://imgs.xkcd.com/comics/road_rage.png",
    date: "2008-06-23",
  )
}
