require 'excon'
require 'json'

require_relative "./oauth_token"

class FederatedSearchAPI
  RECORDS_PATH = "/api/v2/guide/external_content/records"

  def initialize(logger:)
    @logger = logger

    base_url = fetch_env("ZENDESK_BASE_URL", "zendesk-subdomain")
    client_id = fetch_env("ZENDESK_CLIENT_ID", "client-id")
    client_secret = fetch_env("ZENDESK_CLIENT_SECRET", "client-secret")

    @token_source = OAuthToken.new(base_url:, client_id:, client_secret:, logger:)
    @access_token = @token_source.fetch

    headers = {
      "Accept" => "application/json",
      "Content-Type" => "application/json",
    }

    @excon = Excon.new(base_url, persistent: true, headers: headers)
  end

  def create_external_record(**record)
    request(
      method: :post,
      path: RECORDS_PATH,
      body: JSON.dump({ "record" => record }),
      expects: 201,
    )
  end

  def update_external_record(id, **record)
    request(
      method: :put,
      path: "#{RECORDS_PATH}/#{id}",
      body: JSON.dump({ "record" => record }),
      idempotent: true,
      expects: 200,
    )
  end

  def delete_external_record(id)
    request(
      method: :delete,
      path: "#{RECORDS_PATH}/#{id}",
      expects: 204,
      idempotent: true,
    )
  end

  def list_records(cursor: nil)
    query = {}
    query["page[after]"] = cursor if cursor

    response = request(
      method: :get,
      path: RECORDS_PATH,
      query: query,
      expects: 200,
      idempotent: true,
    )

    JSON.parse(response.body)
  end

  private

  def request(**options)
    retried = false

    begin
      @excon.request(
        **options,
        headers: { "Authorization" => "Bearer #{@access_token}" },
      )
    rescue Excon::Error::Client => err
      if !retried && expired_token?(err.response)
        retried = true
        @logger.info "The OAuth access token expired, requesting a new one..."
        @access_token = @token_source.fetch

        retry
      end

      log_error(err.response)

      raise
    end
  end

  def expired_token?(response)
    return false unless response.status == 401

    parse_body(response) { {} }.fetch("error", nil) == "invalid_token"
  end

  def log_error(response)
    body = parse_body(response) { response.body.to_s.slice(0...1000) }

    @logger.error "Zendesk responded with HTTP #{response.status}:"
    @logger.error body
  end

  # Zendesk normally returns JSON errors, but an edge-generated 401, 403 or 429 can be an HTML page.
  # Parsing that would hide the real error behind a JSON::ParserError.
  def parse_body(response)
    JSON.parse(response.body)
  rescue JSON::ParserError, TypeError
    yield
  end

  def fetch_env(name, input)
    value = ENV[name]

    if value.nil? || value.empty?
      raise "#{name} is not set. Set the `#{input}` input on the action."
    end

    value
  end
end
