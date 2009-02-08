gem 'nokogiri', '~>1.2'
require 'nokogiri'

module FeedParser
  module Nokogiri

    class NokogiriSyntaxError < StandardError; end

    class StrictFeedParser
      attr_reader :handler
      def initialize(baseuri, baselang)
        @handler = StrictFeedParserHandler.new(baseuri, baselang, 'utf-8')
      end

      def parse(data)
        saxparser = ::Nokogiri::XML::SAX::Parser.new(@handler)

        saxparser.parse data
      end
    end

    class StrictFeedParserHandler < ::Nokogiri::XML::SAX::Document
      include FeedParserMixin

      attr_accessor :bozo, :entries, :feeddata, :exc

      def initialize(baseuri, baselang, encoding)
        $stderr.puts "trying Nokogiri::StrictFeedParser" if $debug
        startup(baseuri, baselang, encoding)
        @bozo = false
      end

      def start_element(name, attrs)
        name =~ /^(([^;]*);)?(.+)$/ # Snag namespaceuri from name
        namespaceuri = ($2 || '').downcase
        name = $3
        if /backend\.userland\.com\/rss/ =~ namespaceuri
          # match any backend.userland.com namespace
          namespaceuri = 'http://backend.userland.com/rss'
        end
        prefix = @matchnamespaces[namespaceuri]

        if prefix && !prefix.empty?
          name = prefix + ':' + name
        end

        name.downcase!
        unknown_starttag(name, attrs)
      end

      def characters(text)
        handle_data(text)
      end

      def cdata_block(text)
        handle_data(text)
      end

      def end_element(name)
        name =~ /^(([^;]*);)?(.+)$/ # Snag namespaceuri from name
        namespaceuri = ($2 || '').downcase

        prefix = @matchnamespaces[namespaceuri]

        if prefix && !prefix.empty?
         localname = prefix + ':' + name
        end

        name.downcase!
        unknown_endtag(name)
      end

      def error(error_string)
        @bozo = true
        @exc = NokogiriSyntaxError.new(error_string)
        raise @exc
      end
    end
  end
end
