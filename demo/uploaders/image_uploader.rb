# This is a subclass of Shrine base that will be further configured for it's requirements.
# This will be included in the model to manage the file.

require "./config/shrine"
require "image_processing/mini_magick"

class ImageUploader < Shrine
  ALLOWED_TYPES = %w[image/jpeg image/png]
  MAX_SIZE      = 10*1024*1024 # 10 MB

  plugin :remove_attachment
  plugin :pretty_location
  plugin :validation_helpers
  plugin :store_dimensions, analyzer: :mini_magick

  # File validations (requires `validation_helpers` plugin)
  Attacher.validate do
    validate_max_size MAX_SIZE
    if validate_mime_type_inclusion(ALLOWED_TYPES)
      validate_max_width 5000
      validate_max_height 5000
    end
  end

  # uploader showcasing processing on-upload
  class Static < ImageUploader
    plugin :processing
    plugin :versions

    # Additional processing (requires `processing` plugin)
    process(:store) do |io, context|
      original = io.download

      thumbnail = ImageProcessing::MiniMagick
        .source(original)
        .resize_to_limit!(600, nil)

      original.close!

      { original: io, thumbnail: thumbnail }  # Hash of versions requires `versions` plugin
    end
  end

  # uploader showcasing on-the-fly processing
  class Dynamic < ImageUploader
    plugin :derivation_endpoint, prefix: "derivations/image"

    derivation :thumbnail do |file, width, height|
      ImageProcessing::MiniMagick
        .source(file)
        .resize_to_limit(width.to_i, height.to_i)
        .convert("webp")
        .call
    end
  end
end
