import gleam/list
import gleeter/utils
import gleeunit/should

pub fn utils_correctly_detects_jpg_extensions_test() {
  [
    "something.jpg",
    "something.jpeg",
    "https://xkcd.com/images/1.jpg",
    "mixedCase.jPeG",
  ]
  |> list.map(utils.is_jpeg)
  |> list.all(fn(x) { x == True })
  |> should.be_true()
}

pub fn utils_detects_non_jpeg_files_test() {
  [
    "something.png",
    "something.jpeg",
    "https://xkcd.com/images/1.jpg",
    "mixedCase.jPeG",
  ]
  |> list.map(utils.is_jpeg)
  |> list.drop(1)
  |> list.all(fn(x) { x == True })
  |> should.be_true()
}

pub fn utils_correctly_detects_png_extensions_test() {
  [
    "something.png",
    "something.png",
    "https://xkcd.com/images/1.png",
    "mixedCase.pnG",
  ]
  |> list.map(utils.is_png)
  |> list.all(fn(x) { x == True })
  |> should.be_true()
}
