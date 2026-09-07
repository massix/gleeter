import gleam/list
import gleeter/graphics
import gleeter/png
import gleeunit/should
import simplifile

pub fn graphics_image_size_square_test() {
  let terminal_size = graphics.TerminalSize(rows: 24, columns: 80)
  let image_size = png.ImageSize(width: 100, height: 100)

  graphics.calculate_new_size(image_size, terminal_size)
  |> should.equal(#(19, 38))
}

pub fn graphics_image_size_wider_test() {
  let terminal_size = graphics.TerminalSize(rows: 100, columns: 240)
  let image_size = png.ImageSize(width: 400, height: 100)

  graphics.calculate_new_size(image_size, terminal_size)
  |> should.equal(#(24, 192))
}

pub fn graphics_image_size_taller_test() {
  let terminal_size = graphics.TerminalSize(rows: 100, columns: 240)
  let image_size = png.ImageSize(width: 100, height: 400)

  graphics.calculate_new_size(image_size, terminal_size)
  |> should.equal(#(80, 40))
}

pub fn graphics_string_split_empty_string_test() {
  "" |> graphics.string_split_into_chunks(16, []) |> should.equal([])
}

pub fn graphics_string_split_size_less_than_chunk_test() {
  "hello world"
  |> graphics.string_split_into_chunks(1024, [])
  |> should.equal([graphics.Chunk("hello world", 11)])
}

pub fn graphics_string_split_multiple_chunks_test() {
  "hello world"
  |> graphics.string_split_into_chunks(3, [])
  |> should.equal([
    graphics.Chunk("hel", 3),
    graphics.Chunk("lo ", 3),
    graphics.Chunk("wor", 3),
    graphics.Chunk("ld", 2),
  ])
}

pub fn graphics_image_to_chunks_fails_on_chunk_not_multiple_of_4_test() {
  graphics.image_to_chunks(<<>>, 91)
  |> should.be_error
  |> should.equal(graphics.ChunkNotMultipleOf4)
}

pub fn graphics_image_to_chunks_fails_on_chunk_size_too_big_test() {
  graphics.image_to_chunks(<<>>, 4097)
  |> should.be_error
  |> should.equal(graphics.ChunkSizeTooBig)
}

pub fn graphics_image_to_chunks_succeeds_in_all_other_cases_test() {
  let assert Ok(data) = simplifile.read_bits("test_data/road_rage.png")

  let data =
    data
    |> graphics.image_to_chunks(4096)
    |> should.be_ok

  list.length(data)
  |> should.equal(13)

  let assert Ok(graphics.Chunk(_, size)) = list.last(data)
  size |> should.not_equal(4096)
}

pub fn graphics_chunks_to_kitty_controls_no_chunks_test() {
  [] |> graphics.chunks_to_kitty_controls([]) |> should.equal([])
}

pub fn graphics_chunks_to_kitty_controls_single_chunk_test() {
  [graphics.Chunk("payload", 7)]
  |> graphics.chunks_to_kitty_controls([])
  |> should.equal([graphics.KittyControl([#("m", "0")], "payload")])
}

pub fn graphics_chunks_to_kitty_controls_multiple_chunks_test() {
  [graphics.Chunk("payl", 4), graphics.Chunk("oad", 3)]
  |> graphics.chunks_to_kitty_controls([])
  |> should.equal([
    graphics.KittyControl([#("m", "1")], "payl"),
    graphics.KittyControl([#("m", "0")], "oad"),
  ])
}

pub fn graphics_kitty_control_to_string_no_options_test() {
  graphics.KittyControl([], "payload")
  |> graphics.kitty_control_to_string
  |> should.equal("\u{001b}_G;payload\u{001b}\\")
}

pub fn graphics_kitty_control_to_string_one_option_test() {
  graphics.KittyControl([#("a", "T")], "payload")
  |> graphics.kitty_control_to_string
  |> should.equal("\u{001b}_Ga=T;payload\u{001b}\\")
}

pub fn graphics_kitty_control_to_string_multiple_options_test() {
  graphics.KittyControl([#("a", "T"), #("f", "100"), #("m", "1")], "payload")
  |> graphics.kitty_control_to_string
  |> should.equal("\u{001b}_Ga=T,f=100,m=1;payload\u{001b}\\")
}

pub fn graphics_to_kitty_protocol_string_test() {
  let assert Ok(data) = simplifile.read_bits("test_data/road_rage.png")
  let _ = graphics.to_kitty_protocol_string(data, 4096) |> should.be_ok
}
