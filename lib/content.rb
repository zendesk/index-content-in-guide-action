require 'nokogiri'
require 'digest'

class Content < Struct.new(:path, :title, :body, :id)
  def self.load_all(dir, source, logger: nil)
    paths = Dir["#{dir}/**/*.html"]

    paths.filter_map {|path|
      html = Nokogiri::HTML.parse(File.read(path))
      content_node = html.at(CONTENT_CSS_SELECTOR)

      if content_node.nil?
        logger&.warn "Skipping #{path}: no element matches CONTENT_CSS_SELECTOR (#{CONTENT_CSS_SELECTOR})"
        next
      end

      new(
        path,
        html.title,
        content_node.text,
        Digest::MD5.hexdigest(source + path),
      )
    }
  end

  def url
    URI.join(TARGET_BASE_URL, path)
  end
end
