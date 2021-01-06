require 'nokogiri'
require 'digest'

class Content < Struct.new(:path, :title, :html, :id)
  def self.load_all(dir)
    paths = Dir["#{dir}/**/*.html"]

    paths.map {|path|
      html = File.read(path)
      title = Nokogiri::HTML.parse(html).title

      new(
        path,
        title,
        html,
        Digest::MD5.hexdigest(path),
      )
    }
  end

  def url
    URI.join(TARGET_BASE_URL, path)
  end
end
