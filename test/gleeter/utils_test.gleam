import gleam/list
import gleeter/utils
import startest.{describe, it}
import startest/expect
import startest/test_tree

pub fn utils_tests() -> test_tree.TestTree {
  describe("gleeter/utils", [
    it("correctly detects jpg extensions", fn() {
      [
        "something.jpg", "something.jpeg", "https://xkcd.com/images/1.jpg",
        "mixedCase.jPeG",
      ]
      |> list.map(utils.is_jpeg)
      |> list.all(fn(x) { x == True })
      |> expect.to_be_true
    }),
    it("detects non jpeg files", fn() {
      [
        "something.png", "something.jpeg", "https://xkcd.com/images/1.jpg",
        "mixedCase.jPeG",
      ]
      |> list.map(utils.is_jpeg)
      |> list.drop(1)
      |> list.all(fn(x) { x == True })
      |> expect.to_be_true
    }),
    it("correctly detects png extensions", fn() {
      [
        "something.png", "something.png", "https://xkcd.com/images/1.png",
        "mixedCase.pnG",
      ]
      |> list.map(utils.is_png)
      |> list.all(fn(x) { x == True })
      |> expect.to_be_true
    }),
  ])
}
