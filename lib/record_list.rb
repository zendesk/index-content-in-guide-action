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
