#!/usr/bin/env ruby
"""Universal feed parser in Ruby

Handles RSS 0.9x, RSS 1.0, RSS 2.0, CDF, Atom 0.3, and Atom 1.0 feeds

Visit http://feedparser.org/ for the latest version in Python
Visit http://feedparser.org/docs/ for the latest documentation
Email Jeff Hodges at jeff@obquo.com for questions

Required: Ruby 1.8
"""
$KCODE = 'UTF8'
require 'stringio'
require 'uri'
require 'cgi' # escaping html
require 'time'
require 'pp'
require 'rubygems'
require 'base64'
require 'iconv'

gem 'character-encodings', ">=0.2.0"
gem 'htmltools', ">=1.10"
gem 'htmlentities', ">=4.0.0"
gem 'activesupport', ">=1.4.1"
gem 'rchardet', ">=1.0"
require 'xml/saxdriver' # calling expat through the xmlparser gem

require 'rchardet'
$chardet = true

require 'encoding/character/utf-8'
require 'html/sgml-parser'
require 'htmlentities'
require 'active_support'
require 'open-uri'
include OpenURI

$debug = false
$compatible = true

$LOAD_PATH << File.expand_path(File.dirname(__FILE__))
require 'rfeedparser/forgiving_uri'
require 'rfeedparser/aliases'
require 'rfeedparser/encoding_helpers'
require 'rfeedparser/better_sgmlparser'
require 'rfeedparser/better_attributelist'
require 'rfeedparser/scrub'
require 'rfeedparser/time_helpers'
require 'rfeedparser/feedparserdict'
require 'rfeedparser/parser_mixin'
require 'rfeedparser/parsers'
require 'rfeedparser/markup_helpers'

include FeedParserUtilities


module FeedParser
  Version = "0.9.92"

  License = """Copyright (c) 2002-2006, Mark Pilgrim, All rights reserved.

Redistribution and use in source and binary forms, with or without modification,
are permitted provided that the following conditions are met:

* Redistributions of source code must retain the above copyright notice,
  this list of conditions and the following disclaimer.
* Redistributions in binary form must reproduce the above copyright notice,
  this list of conditions and the following disclaimer in the documentation
  and/or other materials provided with the distribution.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS 'AS IS'
AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE
LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
POSSIBILITY OF SUCH DAMAGE."""

  Author = "Jeff Hodges <http://somethingsimilar.com>"
  Copyright_Holder = "Mark Pilgrim <http://diveintomark.org/>"
  Contributors = [  "Jason Diamond <http://injektilo.org/>",
		    "John Beimler <http://john.beimler.org/>",
		    "Fazal Majid <http://www.majid.info/mylos/weblog/>",
		    "Aaron Swartz <http://aaronsw.com/>",
		    "Kevin Marks <http://epeus.blogspot.com/>"
  ]
  # HTTP "User-Agent" header to send to servers when downloading feeds.
  # If you are embedding feedparser in a larger application, you should
  # change this to your application name and URL.
  USER_AGENT = "UniversalFeedParser/%s +http://feedparser.org/" % @version

  # HTTP "Accept" header to send to servers when downloading feeds.  If you don't
  # want to send an Accept header, set this to None.
  ACCEPT_HEADER = "application/atom+xml,application/rdf+xml,application/rss+xml,application/x-netcdf,application/xml;q=0.9,text/xml;q=0.2,*/*;q=0.1"


  # If you want feedparser to automatically run HTML markup through HTML Tidy, set
  # this to true.  Requires mxTidy <http://www.egenix.com/files/python/mxTidy.html>
  # or utidylib <http://utidylib.berlios.de/>.
  #TIDY_MARKUP = false #FIXME untranslated

  # List of Python interfaces for HTML Tidy, in order of preference.  Only useful
  # if TIDY_MARKUP = true
  #PREFERRED_TIDY_INTERFACES = ["uTidy", "mxTidy"] #FIXME untranslated


  # ---------- don't touch these ----------
  class ThingsNobodyCaresAboutButMe < Exception
  end
  class CharacterEncodingOverride < ThingsNobodyCaresAboutButMe
  end
  class CharacterEncodingUnknown < ThingsNobodyCaresAboutButMe
  end
  class NonXMLContentType < ThingsNobodyCaresAboutButMe
  end
  class UndeclaredNamespace < Exception
  end


  SUPPORTED_VERSIONS = {'' => 'unknown',
		      'rss090' => 'RSS 0.90',
		      'rss091n' => 'RSS 0.91 (Netscape)',
		      'rss091u' => 'RSS 0.91 (Userland)',
		      'rss092' => 'RSS 0.92',
		      'rss093' => 'RSS 0.93',
		      'rss094' => 'RSS 0.94',
		      'rss20' => 'RSS 2.0',
		      'rss10' => 'RSS 1.0',
		      'rss' => 'RSS (unknown version)',
		      'atom01' => 'Atom 0.1',
		      'atom02' => 'Atom 0.2',
		      'atom03' => 'Atom 0.3',
		      'atom10' => 'Atom 1.0',
		      'atom' => 'Atom (unknown version)',
		      'cdf' => 'CDF',
		      'hotrss' => 'Hot RSS'
  }
  
  def parse(furi, options = {})
    furi.strip!
    # Parse a feed from a URL, file, stream or string
    $compatible = options[:compatible].nil? ? $compatible : options[:compatible]# Use the default compatibility if compatible is nil
    strictklass = options[:strict] || StrictFeedParser
    looseklass = options[:loose] || LooseFeedParser
    result = FeedParserDict.new
    result['feed'] = FeedParserDict.new
    result['entries'] = []
    if options[:modified]
      options[:modified] = Time.parse(options[:modified]).rfc2822 
      # FIXME this ignores all of our time parsing work.  Does it matter?
    end
    result['bozo'] = false
    handlers = options[:handlers]
    if handlers.class != Array # FIXME why does this happen?
      handlers = [handlers]
    end

    begin
      parsed_furi = ForgivingURI.parse(furi)
      if [nil, "file"].include? parsed_furi.scheme
        $stderr << "Opening local file #{furi}\n" if $debug
        f = open(parsed_furi.path) # OpenURI doesn't behave well when passing HTTP options to a file.
      else
        # And when you do pass them, make sure they aren't just nil (this still true?)
        newd = {}
        newd["If-None-Match"] = options[:etag] unless options[:etag].nil?
        newd["If-Modified-Since"] = options[:modified] unless options[:modified].nil?
        newd["User-Agent"] = (options[:agent] || USER_AGENT).to_s 
        newd["Referer"] = options[:referrer] unless options[:referrer].nil?
        newd["Content-Location"] = options[:content_location] unless options[:content_location].nil?
        newd["Content-Language"] = options[:content_language] unless options[:content_language].nil?                    
        newd["Content-type"] = options[:content_type] unless options[:content_type].nil?

        f = open(furi, newd)
      end

      data = f.read
      f.close 
    rescue => e
      $stderr << "Rescued in parse: "+e.to_s+"\n" if $debug # My addition
      result['bozo'] = true
      result['bozo_exception'] = e
      data = ''
      f = nil
    end
    begin
      if f.meta
	result['etag'] = options[:etag] || f.meta['etag']
	result['modified'] = options[:modified] || f.last_modified 
	result['url'] = f.base_uri.to_s
	result['status'] = f.status[0] || 200
	result['headers'] = f.meta
	result['headers']['content-location'] ||= options[:content_location] unless options[:content_location].nil?
	result['headers']['content-language'] ||= options[:content_language] unless options[:content_language].nil?
	result['headers']['content-type'] ||= options[:content_type] unless options[:content_type].nil?
      end
    rescue NoMethodError
      result['headers'] = {}
      result['etag'] = result['headers']['etag'] = options[:etag] unless options[:etag].nil?
      result['modified'] = result['headers']['last-modified'] = options[:modified] unless options[:modified].nil?
      unless options[:content_location].nil?
	result['headers']['content-location'] = options[:content_location]
      end
      unless options[:content_language].nil?
	result['headers']['content-language'] = options[:content_language] 
      end
      unless options[:content_type].nil?
	result['headers']['content-type'] = options[:content_type]     
      end
    end


    # there are four encodings to keep track of:
    # - http_encoding is the encoding declared in the Content-Type HTTP header
    # - xml_encoding is the encoding declared in the <?xml declaration
    # - sniffed_encoding is the encoding sniffed from the first 4 bytes of the XML data
    # - result['encoding'] is the actual encoding, as per RFC 3023 and a variety of other conflicting specifications
    http_headers = result['headers']
    result['encoding'], http_encoding, xml_encoding, sniffed_xml_encoding, acceptable_content_type =
      self.getCharacterEncoding(f,data)

    if not http_headers.empty? and not acceptable_content_type
      if http_headers.has_key?('content-type')
	bozo_message = "#{http_headers['content-type']} is not an XML media type"
      else
	bozo_message = 'no Content-type specified'
      end
      result['bozo'] = true
      result['bozo_exception'] = NonXMLContentType.new(bozo_message) # I get to care about this, cuz Mark says I should.
    end
    result['version'], data = self.stripDoctype(data)
    baseuri = http_headers['content-location'] || result['href']
    baselang = http_headers['content-language']

    # if server sent 304, we're done
    if result['status'] == 304
      result['version'] = ''
      result['debug_message'] = "The feed has not changed since you last checked, " +
      "so the server sent no data. This is a feature, not a bug!"
      return result
    end

    # if there was a problem downloading, we're done
    if data.nil? or data.empty?
      return result
    end

    # determine character encoding
    use_strict_parser = false
    known_encoding = false
    tried_encodings = []
    proposed_encoding = nil
    # try: HTTP encoding, declared XML encoding, encoding sniffed from BOM
    [result['encoding'], xml_encoding, sniffed_xml_encoding].each do |proposed_encoding|
      next if proposed_encoding.nil? or proposed_encoding.empty?
      next if tried_encodings.include? proposed_encoding
      tried_encodings << proposed_encoding
      begin
	data = self.toUTF8(data, proposed_encoding)
	known_encoding = use_strict_parser = true
	break
      rescue
      end
    end
    # if no luck and we have auto-detection library, try that
    if not known_encoding and $chardet
      begin 
	proposed_encoding = CharDet.detect(data)['encoding']
	if proposed_encoding and not tried_encodings.include?proposed_encoding
	  tried_encodings << proposed_encoding
	  data = self.toUTF8(data, proposed_encoding)
	  known_encoding = use_strict_parser = true
	end
      rescue
      end
    end



    # if still no luck and we haven't tried utf-8 yet, try that
    if not known_encoding and not tried_encodings.include?'utf-8'
      begin
	proposed_encoding = 'utf-8'
	tried_encodings << proposed_encoding
	data = self.toUTF8(data, proposed_encoding)
	known_encoding = use_strict_parser = true
      rescue
      end
    end
    # if still no luck and we haven't tried windows-1252 yet, try that
    if not known_encoding and not tried_encodings.include?'windows-1252'
      begin
	proposed_encdoing = 'windows-1252'
	tried_encodings << proposed_encoding
	data = self.toUTF8(data, proposed_encoding)
	known_encoding = use_strict_parser = true
      rescue
      end
    end

    # NOTE this isn't in FeedParser.py 4.1
    # if still no luck and we haven't tried iso-8859-2 yet, try that.
    #if not known_encoding and not tried_encodings.include?'iso-8859-2'
    #  begin
    #    proposed_encoding = 'iso-8859-2'
    #    tried_encodings << proposed_encoding
    #    data = self.toUTF8(data, proposed_encoding)
    #    known_encoding = use_strict_parser = true
    #  rescue
    #  end
    #end


    # if still no luck, give up
    if not known_encoding
      result['bozo'] = true
      result['bozo_exception'] = CharacterEncodingUnknown.new("document encoding unknown, I tried #{result['encoding']}, #{xml_encoding}, utf-8 and windows-1252 but nothing worked")
      result['encoding'] = ''
    elsif proposed_encoding != result['encoding']
      result['bozo'] = true
      result['bozo_exception'] = CharacterEncodingOverride.new("documented declared as #{result['encoding']}, but parsed as #{proposed_encoding}")
      result['encoding'] = proposed_encoding
    end

    if use_strict_parser
      # initialize the SAX parser
      saxparser = XML::SAX::Helpers::ParserFactory.makeParser("XML::Parser::SAXDriver")
      feedparser = strictklass.new(baseuri, baselang, 'utf-8')
      saxparser.setDocumentHandler(feedparser)
      saxparser.setDTDHandler(feedparser)
      saxparser.setEntityResolver(feedparser)
      saxparser.setErrorHandler(feedparser)

      inputdata = XML::SAX::InputSource.new('parsedfeed')
      inputdata.setByteStream(StringIO.new(data))
      begin
	saxparser.parse(inputdata)
      rescue Exception => parseerr # resparse
	if $debug
	  $stderr << "xml parsing failed\n"
	  $stderr << parseerr.to_s+"\n" # Hrmph.
	end
	result['bozo'] = true
	result['bozo_exception'] = feedparser.exc || e 
	use_strict_parser = false
      end
    end
    if not use_strict_parser
      feedparser = looseklass.new(baseuri, baselang, (known_encoding and 'utf-8' or ''))
      feedparser.parse(data)
      $stderr << "Using LooseFeed\n\n" if $debug
    end
    result['feed'] = feedparser.feeddata
    result['entries'] = feedparser.entries
    result['version'] = result['version'] || feedparser.version
    result['namespaces'] = feedparser.namespacesInUse
    return result
  end
  module_function(:parse)
end # End FeedParser module

class Serializer 
  def initialize(results)
    @results = results
  end
end

class TextSerializer < Serializer
  def write(stream=$stdout)
    writer(stream, @results, '')
  end

  def writer(stream, node, prefix)
    return if (node.nil? or node.empty?)
    if node.methods.include?'keys'
      node.keys.sort.each do |key|
      next if ['description','link'].include? key
      next if node.has_key? k+'_detail'
      next if node.has_key? k+'_parsed'
      writer(stream,node[k], prefix+k+'.')
      end
    elsif node.class == Array
      node.each_with_index do |thing, index|
	writer(stream, thing, prefix[0..-2] + '[' + index.to_s + '].')
      end
    else
      begin
	s = u(node.to_s)
	stream << prefix[0..-2]
	stream << '='
	stream << s
	stream << "\n"
      rescue
      end
    end
  end
end

class PprintSerializer < Serializer # FIXME use pp instead
  def write(stream = $stdout)
    stream << @results['href'].to_s + "\n\n"
    pp(@results)
    stream << "\n"
  end
end

if $0 == __FILE__
  require 'optparse'
  require 'ostruct'
  options = OpenStruct.new
  options.etag = options.modified = options.agent = options.referrer = nil
  options.content_language = options.content_location = options.ctype = nil
  options.format = 'pprint'
  options.compatible = $compatible 
  options.verbose = false

  opts = OptionParser.new do |opts|
    opts.banner 
    opts.separator ""
    opts.on("-A", "--user-agent [AGENT]",
	  "User-Agent for HTTP URLs") {|agent|
      options.agent = agent
    }

    opts.on("-e", "--referrer [URL]", 
	  "Referrer for HTTP URLs") {|referrer|
      options.referrer = referrer
    }

    opts.on("-t", "--etag [TAG]",
	  "ETag/If-None-Match for HTTP URLs") {|etag|
      options.etag = etag
    }

    opts.on("-m", "--last-modified [DATE]",
	  "Last-modified/If-Modified-Since for HTTP URLs (any supported date format)") {|modified|
      options.modified = modified
    }

    opts.on("-f", "--format [FORMAT]", [:text, :pprint],
	  "output resutls in FORMAT (text, pprint)") {|format|
      options.format = format
    }

    opts.on("-v", "--[no-]verbose",
	  "write debugging information to stderr") {|v|
      options.verbose = v
    }

    opts.on("-c", "--[no-]compatible",
	  "strip element attributes like feedparser.py 4.1 (default)") {|comp|
      options.compatible = comp
    }
    opts.on("-l", "--content-location [LOCATION]",
	  "default Content-Location HTTP header") {|loc|
      options.content_location = loc
    }
    opts.on("-a", "--content-language [LANG]",
	  "default Content-Language HTTP header") {|lang|
      options.content_language = lang
    }
    opts.on("-t", "--content-type [TYPE]",
	  "default Content-type HTTP header") {|ctype|
      options.ctype = ctype
    }
  end

  opts.parse!(ARGV)
  $debug = true if options.verbose 
  $compatible = options.compatible unless options.compatible.nil?

  if options.format == :text
    serializer = TextSerializer
  else
    serializer = PprintSerializer
  end
  args = *ARGV.dup
  unless args.nil? 
    args.each do |url| # opts.parse! removes everything but the urls from the command line
      results = FeedParser.parse(url, :etag => options.etag, 
				 :modified => options.modified, 
				 :agent => options.agent, 
				 :referrer => options.referrer, 
				 :content_location => options.content_location,
				 :content_language => options.content_language,
				 :content_type => options.ctype
				)
				serializer.new(results).write($stdout)
    end
  end
end
