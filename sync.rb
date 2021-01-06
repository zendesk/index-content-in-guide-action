require 'dotenv/load'
require 'logger'

require_relative "./lib/federated_search_api"
require_relative "./lib/record_list"
require_relative "./lib/search_record"
require_relative "./lib/content"
require_relative "./lib/colored_logging_formatter"

TARGET_BASE_URL = ENV.fetch("TARGET_BASE_URL")
EXTERNAL_CONTENT_SOURCE_ID = ENV.fetch("EXTERNAL_CONTENT_SOURCE_ID")
EXTERNAL_CONTENT_TYPE_ID = ENV.fetch("EXTERNAL_CONTENT_TYPE_ID")
CONTENT_DIR = ENV.fetch("CONTENT_DIR", ".")
WORKING_DIR = ENV.fetch("WORKING_DIR", ".")

MAX_BODY_LENGTH = 9000

def main
  Dir.chdir WORKING_DIR

  logger = Logger.new(STDOUT)
  logger.formatter = ColoredLoggingFormatter

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

  logger.info "Found #{contents.count} files at #{CONTENT_DIR}"

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
      api.create_external_record(**data)
    else
      logger.info "Updating record for #{content.path}..."
      api.update_external_record(existing_record.id, **data)
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
