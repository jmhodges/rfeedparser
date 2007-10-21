#!/usr/bin/env ruby
require File.join(File.dirname(__FILE__), 'aliases')
require File.join(File.dirname(__FILE__), 'encoding_helpers')
require File.join(File.dirname(__FILE__), 'markup_helpers')
require File.join(File.dirname(__FILE__), 'scrub')
require File.join(File.dirname(__FILE__), 'time_helpers')

module FeedParserUtilities
  
  def parse_date(date_string)
    FeedParser::FeedTimeParser.parse_date(date_string)
  end
  module_function :parse_date

  def py2rtime(pytuple)
    return Time.utc(*pytuple[0..5]) unless pytuple.blank? 
  end
end