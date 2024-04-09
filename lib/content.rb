require 'nokogiri'
require 'digest'

class Content < Struct.new(:path, :title, :body, :id)
  def self.load_all(dir, source)
    paths = Dir["#{dir}/**/*.html"]

    paths.map {|path|
      html = Nokogiri::HTML.parse(File.read(path))
      title = html.title
      body = html.at(CONTENT_CSS_SELECTOR).text

      new(
        path,
        title,
        body,
        Digest::MD5.hexdigest(source + path),
      )
    }
  end

  def url
    URI.join(TARGET_BASE_URL, path)
  end
end
