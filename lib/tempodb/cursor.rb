require 'enumerator'
require 'httpclient_link_header'

module TempoDB
  class Cursor
    include Enumerable

    TRUNCATED_KEY = "Truncated"

    def initialize(uri, client, inner_cursor_type, wrapper)
      @uri = uri
      @next_uri = uri
      @client = client
      @wrapper = wrapper
      @inner_cursor_type = inner_cursor_type
      @segment = nil
    end

    def each
      # The cursor has been completely consumed
      return if @segment && @segment.empty? && !@next_uri

      loop do
        if @segment == nil || @segment.empty?
          response = @client.cursored_get(@next_uri)
          json = JSON.parse(response.body)
          @segment = @inner_cursor_type.extract(@wrapper.from_json(json)).reverse
          if !response.header[TRUNCATED_KEY].empty?
            @next_uri = URI(@client.construct_uri(response.links.by("rel").fetch("next").first["uri"]).to_s.chomp("/"))
          else
            # We're at the last page
            @next_uri = nil
          end
        end

        # Consume the segment
        @segment.size.times do
          yield @segment.pop
        end

        # Break because there're no more pages to fetch
        return unless @next_uri
      end
    end
  end

  class SeriesCursor
    def self.extract(data_set)
      data_set.data
    end
  end
end
