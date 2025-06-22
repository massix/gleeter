import gleam/bit_array
import gleam/result

pub type ImageSize {
  ImageSize(width: Int, height: Int)
}

pub const png_signature = <<137, 80, 78, 71, 13, 10, 26, 10>>

// Given a binary string for a PNG image, retrieve the width and height in pixels
pub fn get_image_size(image data: BitArray) -> Result(ImageSize, Nil) {
  let rt = fn(x, y) { result.try(x, y) }
  // INFO:
  // - we are skipping the signature (8 bytes)
  // - we are also skipping the header of the first chunk (4 bytes + 4 bytes)
  // - we are retrieving only the width and height (4 bytes + 4 bytes)
  use ihdr_chunk <- rt(bit_array.slice(data, 16, 8))
  case is_png(data), ihdr_chunk {
    True, <<width:size(32), height:size(32)>> -> Ok(ImageSize(width, height))
    _, _ -> Error(Nil)
  }
}

// Given binary data, returns true if it is a PNG image
pub fn is_png(data: BitArray) -> Bool {
  case bit_array.slice(data, 0, 8) {
    Ok(x) if x == png_signature -> True
    _ -> False
  }
}
