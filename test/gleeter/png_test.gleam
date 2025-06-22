import gleeter/png
import simplifile
import startest.{describe, it}
import startest/expect

pub fn png_tests() {
  describe("png", [
    describe("detects png", [
      it("ok", fn() {
        let assert Ok(data) = simplifile.read_bits("test_data/road_rage.png")
        data
        |> png.is_png
        |> expect.to_be_true
      }),
      it("ko", fn() {
        let assert Ok(data) = simplifile.read_bits("test_data/sample_1.json")
        data
        |> png.is_png
        |> expect.to_be_false
      }),
    ]),
    describe("get image size", [
      it("get image size", fn() {
        let assert Ok(data) = simplifile.read_bits("test_data/road_rage.png")
        data
        |> png.get_image_size
        |> expect.to_be_ok
        |> expect.to_equal(png.ImageSize(740, 216))
      }),
      it("get image size error", fn() {
        let assert Ok(data) = simplifile.read_bits("test_data/sample_1.json")
        data
        |> png.get_image_size
        |> expect.to_be_error
      }),
    ]),
  ])
}
