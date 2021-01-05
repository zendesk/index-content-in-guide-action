require 'bundler/setup'
require 'dotenv/load'
require 'pp'
require 'csv'
require 'nokogiri'
require 'json'
require 'logger'
require 'yaml'
require 'digest'
require 'excon'

class FederatedSearchAPI
  BASE_URL = ENV.fetch("ZENDESK_BASE_URL")
  AUTH = ENV.fetch("ZENDESK_AUTH")

  def initialize(logger:)
    headers = {
      "Authorization" => "Basic #{AUTH}",
      "Accept" => "application/json",
    }

    @logger = logger
    @excon = Excon.new(BASE_URL, persistent: true, headers: headers)
  end

  def create_external_record(**record)
    @excon.post(
      path: "/api/v2/guide/external_content/records",
      body: JSON.dump({ "record" => record }),
      expects: 201,
    )
  rescue Excon::Error::Client => err
    @logger.error(JSON.parse(err.response.body))

    raise
  end

  def update_external_record(id, **record)
    @excon.put(
      path: "/api/v2/guide/external_content/records/#{id}",
      body: JSON.dump({ "record" => record }),
      idempotent: true,
      expects: 200,
    )
  rescue Excon::Error::Client => err
    @logger.error(JSON.parse(err.response.body))

    raise
  end

  def delete_external_record(id)
    @excon.delete(
      path: "/api/v2/guide/external_content/records/#{id}",
      expects: 204,
      idempotent: true,
    )
  rescue Excon::Error::Client => err
    @logger.error(JSON.parse(err.response.body))

    raise
  end

  def list_records(cursor: nil)
    query = {}
    query["page[after]"] = cursor if cursor

    response = @excon.get(
      path: "/api/v2/guide/external_content/records",
      query: query,
      expects: 200,
      idempotent: true,
    )

    JSON.parse(response.body)
  rescue Excon::Error::Client => err
    @logger.error(JSON.parse(err.response.body))

    raise
  end
end

class RecordList
  include Enumerable

  def initialize(api:, logger:)
    @api = api
    @logger = logger
  end

  def each(&block)
    cursor = nil

    while true
      @logger.debug "Fetching records starting at cursor #{cursor}"
      response = @api.list_records(cursor: cursor)

      response
        .fetch("records")
        .select {|data| data.fetch("type").fetch("id") == EXTERNAL_CONTENT_TYPE_ID }
        .map {|data| SearchRecord.new(data) }
        .each(&block)

      meta = response.fetch("meta")

      if meta.fetch("has_more")
        cursor = meta.fetch("after_cursor")
        @logger.debug "More records available, cursor = #{cursor}"
      else
        @logger.debug "No more records available"
        break
      end
    end
  end
end

class SearchRecord
  attr_reader :id, :external_id, :title, :body, :url

  def initialize(attrs)
    attrs.each do |key, value|
      instance_variable_set("@" + key, value)
    end
  end
end

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
    "https://techmenu.zende.sk#{path}"
  end
end

EXTERNAL_CONTENT_SOURCE_ID = ENV.fetch("EXTERNAL_CONTENT_SOURCE_ID")
EXTERNAL_CONTENT_TYPE_ID = ENV.fetch("EXTERNAL_CONTENT_TYPE_ID")
CONTENT_DIR = ENV.fetch("CONTENT_DIR")

MAX_BODY_LENGTH = 9000

def main
  logger = Logger.new(STDOUT)

  contents = Content.load_all(CONTENT_DIR)
  api = FederatedSearchAPI.new(logger: logger)

  contents.group_by(&:id).each do |id, cs|
    if cs.count > 1
      logger.error "Multiple contents with same ID #{id}:"
      cs.each do |c|
        logger.error " * #{c.title} at #{c.path}"
      end
      raise
    end
  end

  existing_records = RecordList.new(api: api, logger: logger).to_a

  logger.info "Found #{existing_records.count} files"

  contents.each do |content|
    data = {
      external_id: content.id,
      url: content.url,
      title: content.title,
      body: content.html.slice(0...MAX_BODY_LENGTH),
      type_id: EXTERNAL_CONTENT_TYPE_ID,
      source_id: EXTERNAL_CONTENT_SOURCE_ID,
      locale: "en-us",
      user_segment_id: nil,
    }

    existing_record = existing_records.find {|r| r.external_id == content.id }

    if existing_record.nil?
      logger.info "Creating record for #{content.path}..."
      api.create_external_record(data)
    else
      logger.info "Updating record for #{content.path}..."
      api.update_external_record(existing_record.id, data)
      existing_records.delete(existing_record)
    end
  end

  logger.info "DONE!"

  if existing_records.any?
    logger.warn "#{existing_records.count} records need to be deleted..."

    existing_records.each do |record|
      logger.warn "Deleting record #{record.id}: #{record.title}..."
      api.delete_external_record(record.id)
    end

    logger.info "DONE!"
  end
end

main
