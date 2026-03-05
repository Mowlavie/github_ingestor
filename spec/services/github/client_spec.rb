require "rails_helper"

RSpec.describe Github::Client do
  subject(:client) { described_class.new }

  let(:rate_limit_headers) do
    {
      "Content-Type" => "application/json",
      "ETag" => '"abc123"',
      "X-RateLimit-Limit" => "60",
      "X-RateLimit-Remaining" => "55",
      "X-RateLimit-Reset" => (Time.now.to_i + 3600).to_s
    }
  end

  let(:events_payload) do
    [{ "id" => "123", "type" => "PushEvent" }].to_json
  end

  describe "#fetch_events" do
    before do
      stub_request(:get, "https://api.github.com/events")
        .to_return(status: 200, body: events_payload, headers: rate_limit_headers)
    end

    it "returns a list of events" do
      result = client.fetch_events

      expect(result[:events]).to be_an(Array)
      expect(result[:not_modified]).to be false
    end

    it "returns the etag from the response" do
      result = client.fetch_events

      expect(result[:etag]).to eq('"abc123"')
    end

    it "includes parsed rate limit info" do
      result = client.fetch_events

      expect(result[:rate_limit][:remaining]).to eq(55)
      expect(result[:rate_limit][:limit]).to eq(60)
    end

    it "sends If-None-Match when an etag is provided" do
      client.fetch_events(etag: '"abc123"')

      expect(WebMock).to have_requested(:get, "https://api.github.com/events")
        .with(headers: { "If-None-Match" => '"abc123"' })
    end

    context "when the server returns 304 Not Modified" do
      before do
        stub_request(:get, "https://api.github.com/events")
          .to_return(status: 304, body: "", headers: rate_limit_headers)
      end

      it "returns not_modified: true with an empty event list" do
        result = client.fetch_events(etag: '"abc123"')

        expect(result[:not_modified]).to be true
        expect(result[:events]).to be_empty
      end
    end

    context "when the connection fails" do
      before do
        stub_request(:get, "https://api.github.com/events")
          .to_raise(Faraday::ConnectionFailed.new("connection refused"))
      end

      it "returns an error key and does not raise" do
        result = client.fetch_events

        expect(result[:error]).to be_present
        expect(result[:events]).to be_empty
      end
    end
  end

  describe "#rate_limited?" do
    it "returns true when remaining requests are below the threshold" do
      expect(client.rate_limited?({ remaining: 3 })).to be true
    end

    it "returns false when enough requests remain" do
      expect(client.rate_limited?({ remaining: 30 })).to be false
    end

    it "returns false for an empty rate limit hash" do
      expect(client.rate_limited?({})).to be false
    end
  end

  describe "#seconds_until_reset" do
    it "returns a positive number of seconds" do
      reset_time = Time.now.to_i + 120
      result = client.seconds_until_reset({ reset: reset_time })

      expect(result).to be > 0
    end

    it "returns a default when reset is not present" do
      expect(client.seconds_until_reset({})).to eq(60)
    end
  end
end
