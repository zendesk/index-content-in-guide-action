require 'excon'
require 'json'

# Mints a Zendesk OAuth access token using the client credentials grant.
class OAuthToken
  PATH = "/oauth/tokens"
  SCOPE = "hc:read hc:write"

  EXPIRES_IN = 3600 # seconds

  class Error < StandardError; end

  def initialize(base_url:, client_id:, client_secret:, logger:)
    @base_url = base_url
    @client_id = client_id
    @client_secret = client_secret
    @logger = logger
  end

  # Returns the access token as a string
  def fetch
    @logger.info "Requesting an OAuth access token from #{@base_url}#{PATH}..."

    response = Excon.post(
      "#{@base_url}#{PATH}",
      headers: {
        "Content-Type" => "application/json",
        "Accept" => "application/json",
      },
      body: JSON.dump(
        grant_type: "client_credentials",
        client_id: @client_id,
        client_secret: @client_secret,
        scope: SCOPE,
        expires_in: EXPIRES_IN,
      ),
      expects: [200, 201],
    )

    JSON.parse(response.body).fetch("access_token")
  rescue Excon::Error::HTTPStatus => err
    @logger.error "Could not obtain an OAuth access token (HTTP #{err.response.status})."
    @logger.error err.response.body.to_s.slice(0...1000)

    raise Error, <<~MESSAGE
      Failed to obtain a Zendesk OAuth access token.

      Check that:
        * `client-id` is the OAuth client's Unique Identifier (not its numeric id)
        * `client-secret` matches that client's Secret
        * the client is confidential, not public (public clients cannot use this grant)
        * `zendesk-subdomain` (#{@base_url}) is the account the client belongs to
    MESSAGE
  rescue KeyError
    raise Error, "Zendesk did not return an access_token in its OAuth token response."
  end
end
