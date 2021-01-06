require 'excon'
require 'json'

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
