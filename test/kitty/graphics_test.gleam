import gleam/list
import kitty/graphics
import png
import simplifile
import startest.{describe, it, xit}
import startest/expect

pub fn graphics_tests() {
  describe("kitty/graphics", [
    terminal_size(),
    image_size(),
    string_split_into_chunks_test(),
    image_to_chunk_test(),
    chunks_to_kitty_controls_test(),
    kitty_control_to_string_test(),
    to_kitty_protocol_string_test(),
  ])
}

fn terminal_size() {
  describe("terminal size", [
    xit("returns terminal size", fn() {
      let graphics.TerminalSize(rows:, columns:) = graphics.get_terminal_size()
      expect.to_not_equal(columns, 0)
      expect.to_not_equal(rows, 0)

      Nil
    }),
  ])
}

fn image_size() {
  describe("image size", [
    it("square", fn() {
      let terminal_size = graphics.TerminalSize(rows: 24, columns: 80)
      let image_size = png.ImageSize(width: 100, height: 100)

      graphics.calculate_new_size(image_size, terminal_size)
      |> expect.to_equal(#(19, 38))
    }),
    it("wider", fn() {
      let terminal_size = graphics.TerminalSize(rows: 100, columns: 240)
      let image_size = png.ImageSize(width: 400, height: 100)

      graphics.calculate_new_size(image_size, terminal_size)
      |> expect.to_equal(#(24, 192))
    }),
    it("taller", fn() {
      let terminal_size = graphics.TerminalSize(rows: 100, columns: 240)
      let image_size = png.ImageSize(width: 100, height: 400)

      graphics.calculate_new_size(image_size, terminal_size)
      |> expect.to_equal(#(80, 40))
    }),
  ])
}

fn string_split_into_chunks_test() {
  describe("string split", [
    it("empty string", fn() {
      ""
      |> graphics.string_split_into_chunks(16, [])
      |> expect.to_equal([])
    }),
    it("string size less than chunk size", fn() {
      "hello world"
      |> graphics.string_split_into_chunks(1024, [])
      |> expect.to_equal([graphics.Chunk("hello world", 11)])
    }),
    it("multiple chunks", fn() {
      "hello world"
      |> graphics.string_split_into_chunks(3, [])
      |> expect.to_equal([
        graphics.Chunk("hel", 3),
        graphics.Chunk("lo ", 3),
        graphics.Chunk("wor", 3),
        graphics.Chunk("ld", 2),
      ])
    }),
  ])
}

fn image_to_chunk_test() {
  describe("image to chunks", [
    it("fails if chunk size not divisible by 4", fn() {
      graphics.image_to_chunks(<<>>, 91)
      |> expect.to_be_error
      |> expect.to_equal(graphics.ChunkNotMultipleOf4)
    }),
    it("fails if chunk size greater than 4096", fn() {
      graphics.image_to_chunks(<<>>, 4097)
      |> expect.to_be_error
      |> expect.to_equal(graphics.ChunkSizeTooBig)
    }),
    it("succeeds in all other cases", fn() {
      let assert Ok(data) = simplifile.read_bits("test_data/road_rage.png")

      let data =
        data
        |> graphics.image_to_chunks(4096)
        |> expect.to_be_ok

      // $ base64 test_data/road_rage.png | wc ==> 50176 bytes
      // 50176/4096 = 12.25, rounded to 13
      expect.to_equal(list.length(data), 13)

      // Since we reounded, we can be sure that the last chunk will be
      // smaller than the given chunk_size
      let assert Ok(graphics.Chunk(_, size)) = list.last(data)
      expect.to_not_equal(size, 4096)
    }),
  ])
}

fn chunks_to_kitty_controls_test() {
  describe("chunks to kitty controls", [
    it("no chunks", fn() {
      [] |> graphics.chunks_to_kitty_controls(4096, []) |> expect.to_equal([])
    }),
    it("single chunk", fn() {
      [graphics.Chunk("payload", 7)]
      |> graphics.chunks_to_kitty_controls(1024, [])
      |> expect.to_equal([graphics.KittyControl([#("m", "0")], "payload")])
    }),
    it("multiple chunks", fn() {
      [graphics.Chunk("payl", 4), graphics.Chunk("oad", 3)]
      |> graphics.chunks_to_kitty_controls(4, [])
      |> expect.to_equal([
        graphics.KittyControl([#("m", "1")], "payl"),
        graphics.KittyControl([#("m", "0")], "oad"),
      ])
    }),
  ])
}

fn kitty_control_to_string_test() {
  describe("kitty control to string", [
    it("no options", fn() {
      graphics.KittyControl([], "payload")
      |> graphics.kitty_control_to_string
      |> expect.to_equal("\u{001b}_G;payload\u{001b}\\")
    }),
    it("one option", fn() {
      graphics.KittyControl([#("a", "T")], "payload")
      |> graphics.kitty_control_to_string
      |> expect.to_equal("\u{001b}_Ga=T;payload\u{001b}\\")
    }),
    it("multiple options", fn() {
      graphics.KittyControl(
        [#("a", "T"), #("f", "100"), #("m", "1")],
        "payload",
      )
      |> graphics.kitty_control_to_string
      |> expect.to_equal("\u{001b}_Ga=T,f=100,m=1;payload\u{001b}\\")
    }),
  ])
}

fn to_kitty_protocol_string_test() {
  describe("to kitty protocol string", [
    // TODO: write a more meaningful test here?
    it("full test", fn() {
      let assert Ok(data) = simplifile.read_bits("test_data/road_rage.png")
      graphics.to_kitty_protocol_string(data, 4096)
      |> expect.to_be_ok

      Nil
    }),
  ])
}
