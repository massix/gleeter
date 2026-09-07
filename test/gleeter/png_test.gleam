import gleeter/png
import gleeunit/should
import simplifile

pub fn png_detects_png_ok_test() {
  let assert Ok(data) = simplifile.read_bits("test_data/road_rage.png")
  data
  |> png.is_png()
  |> should.be_true()
}

pub fn png_detects_png_ko_test() {
  let assert Ok(data) = simplifile.read_bits("test_data/sample_1.json")
  data
  |> png.is_png()
  |> should.be_false()
}

pub fn png_get_image_size_test() {
  let assert Ok(data) = simplifile.read_bits("test_data/road_rage.png")
  data
  |> png.get_image_size()
  |> should.be_ok()
  |> should.equal(png.ImageSize(740, 216))
}

pub fn png_get_image_size_error_test() {
  let assert Ok(data) = simplifile.read_bits("test_data/sample_1.json")
  data
  |> png.get_image_size()
  |> should.be_error()
}
