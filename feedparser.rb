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
require 'enumerator'
require 'uri'
XML_AVAILABLE = true
require 'rexml/parsers/sax2parser'
require 'rexml/sax2listener'
require 'pp'
require 'rubygems'


require 'base64'
require 'iconv'

#FIXME need charset detection

#FIXME untranslated, ruby gem
gem 'htmlentities'
require 'htmlentities/string' #FIXME we need a "manual" attempt if this doesn't exist
gem 'character-encodings', ">=0.2.0"
gem 'hpricot', ">=0.5"
require 'hpricot'
require 'encoding/character/utf-8'
require 'open-uri'
include OpenURI

$debug = false
$compatible = true

def unicode(data, from_encoding)
  # Takes a single string and converts it from the encoding in 
  # from_encoding to unicode.
  uconvert(data, from_encoding, 'unicode')
end

def uconvert(data, from_encoding, to_encoding = 'utf-8')
  Iconv.iconv(to_encoding, from_encoding, data)[0]
end

def unichr(i)
  [i].pack('U*')
end

def _xmlescape(text) # FIXME unused
  Text.new(text).to_s
end

def _ebcdic_to_ascii(s)   
  return Iconv.iconv("EBCDIC-US", "ASCII", s)[0]
end

_cp1252 = {
  unichr(128) => unichr(8364), # euro sign
  unichr(130) => unichr(8218), # single low-9 quotation mark
  unichr(131) => unichr( 402), # latin small letter f with hook
  unichr(132) => unichr(8222), # double low-9 quotation mark
  unichr(133) => unichr(8230), # horizontal ellipsis
  unichr(134) => unichr(8224), # dagger
  unichr(135) => unichr(8225), # double dagger
  unichr(136) => unichr( 710), # modifier letter circumflex accent
  unichr(137) => unichr(8240), # per mille sign
  unichr(138) => unichr( 352), # latin capital letter s with caron
  unichr(139) => unichr(8249), # single left-pointing angle quotation mark
  unichr(140) => unichr( 338), # latin capital ligature oe
  unichr(142) => unichr( 381), # latin capital letter z with caron
  unichr(145) => unichr(8216), # left single quotation mark
  unichr(146) => unichr(8217), # right single quotation mark
  unichr(147) => unichr(8220), # left double quotation mark
  unichr(148) => unichr(8221), # right double quotation mark
  unichr(149) => unichr(8226), # bullet
  unichr(150) => unichr(8211), # en dash
  unichr(151) => unichr(8212), # em dash
  unichr(152) => unichr( 732), # small tilde
  unichr(153) => unichr(8482), # trade mark sign
  unichr(154) => unichr( 353), # latin small letter s with caron
  unichr(155) => unichr(8250), # single right-pointing angle quotation mark
  unichr(156) => unichr( 339), # latin small ligature oe
  unichr(158) => unichr( 382), # latin small letter z with caron
  unichr(159) => unichr( 376) # latin capital letter y with diaeresis
}

def urljoin(base, uri)
  urifixer = Regexp.new('^([A-Za-z][A-Za-z0-9+-.]*://)(/*)(.*?)')
  uri = uri.sub(urifixer, '\1\3') 
  begin
    return URI.join(base, uri).to_s #FIXME untranslated, error handling from original needed?
  rescue URI::BadURIError
    if URI.parse(base).relative?
      return URI::parse(uri).to_s
    end
  end
end

# This adds a nice scrub method to Hpricot, so we don't need a _HTMLSanitizer class
# http://underpantsgnome.com/2007/01/20/hpricot-scrub
# I have modified it to check for attributes that are only allowed if they are in a certain tag
module Hpricot
  class Elements 
    def strip # I completely route around this with the recursive_strip in Doc
      each { |x| x.strip }
    end

    def strip_attributes(safe=[])
      each { |x| x.strip_attributes(safe) }
    end

    def strip_style(ok_props=[], ok_keywords=[])
      each { |x| x.strip_style(ok_props, ok_keywords) }
    end
  end

  class Elem
    def remove
      parent.children.delete(self)
    end

    def strip
      children.each { |x| x.strip unless x.class == Hpricot::Text }

      if strip_removes?
        remove
      else
        parent.replace_child self, Hpricot.make(inner_html) unless parent.nil?
      end
    end

    def strip_attributes(safe=[])
      unless attributes.nil?
        attributes.each do |atr|
          unless safe.include?atr[0] or atr[0] == 'style'
            remove_attribute(atr[0]) 
          end
        end
      end
    end
    
    # Much of this method was translated from Mark Pilgrim's FeedParser, including comments
    def strip_style(ok_props = [], ok_keywords = [])
      unless self['style'].nil?
        # disallow urls 
        style = self['style'].sub(/url\s*\(\s*[^\s)]+?\s*\)\s*'/, ' ')
        valid_css_values = re.compile('^(#[0-9a-f]+|rgb\(\d+%?,\d*%?,?\d*%?\)?|' +
        '\d{0,2}\.?\d{0,2}(cm|em|ex|in|mm|pc|pt|px|%|,|\))?)$')
        # gauntlet
        if not style.match(/^([:,;#%.\sa-zA-Z0-9!]|\w-\w|'[\s\w]+'|"[\s\w]+"|\([\d,\s]+\))*$/)
          return ''
        end
        if not style.match(/^(\s*[-\w]+\s*:\s*[^:;]*(;|$))*$/)
          return ''
        end

        clean = []
        style.scan(/([-\w]+)\s*:\s*([^:;]*)/).each do |l|
          prop, value = l

          next if value.nil? or value.empty?

          if ok_props.include?prop.downcase
            clean << prop + ': ' + value + ';'
          elsif ['background','border','margin','padding'].include? prop.split('-')[0].downcase 

            # This is a terrible, but working way to mimic Python's for/else
            did_not_break = true 

            value.split.each do |keyword|
              if not ok_keywords.include? keyword and not valid_css_values.match(keyword)
                break
              end
            end

            if did_not_break
              clean << prop + ':' + value + ';'
            end
          end

        end
        self['style'] = clean.join(' ')
      end
    end
    
    def strip_removes?
      # I'm sure there are others that shuould be ripped instead of stripped
      attributes && attributes['type'] =~ /script|css/
    end
  end

  class Doc
    alias :old_initialize :initialize
    attr_accessor :config
     @@acceptable_elements = ['a', 'abbr', 'acronym', 'address', 'area', 'b',
      'big', 'blockquote', 'br', 'button', 'caption', 'center', 'cite',
      'code', 'col', 'colgroup', 'dd', 'del', 'dfn', 'dir', 'div', 'dl', 'dt',
      'em', 'fieldset', 'font', 'form', 'h1', 'h2', 'h3', 'h4', 'h5', 'h6',
      'hr', 'i', 'img', 'input', 'ins', 'kbd', 'label', 'legend', 'li', 'map',
      'menu', 'ol', 'optgroup', 'option', 'p', 'pre', 'q', 's', 'samp',
      'select', 'small', 'span', 'strike', 'strong', 'sub', 'sup', 'table',
      'tbody', 'td', 'textarea', 'tfoot', 'th', 'thead', 'tr', 'tt', 'u',
      'ul', 'var']

      @@acceptable_attributes = ['abbr', 'accept', 'accept-charset', 'accesskey',
      'action', 'align', 'alt', 'axis', 'border', 'cellpadding',
      'cellspacing', 'char', 'charoff', 'charset', 'checked', 'cite', 'class',
      'clear', 'cols', 'colspan', 'color', 'compact', 'coords', 'datetime',
      'dir', 'disabled', 'enctype', 'for', 'frame', 'headers', 'height',
      'href', 'hreflang', 'hspace', 'id', 'ismap', 'label', 'lang',
      'longdesc', 'maxlength', 'media', 'method', 'multiple', 'name',
      'nohref', 'noshade', 'nowrap', 'prompt', 'readonly', 'rel', 'rev',
      'rows', 'rowspan', 'rules', 'scope', 'selected', 'shape', 'size',
      'span', 'src', 'start', 'summary', 'tabindex', 'target', 'title', 
      'type', 'usemap', 'valign', 'value', 'vspace', 'width', 'xml:lang']

      @@unacceptable_elements_with_end_tag = ['script', 'applet']

      @@acceptable_css_properties = ['azimuth', 'background-color',
      'border-bottom-color', 'border-collapse', 'border-color',
      'border-left-color', 'border-right-color', 'border-top-color', 'clear',
      'color', 'cursor', 'direction', 'display', 'elevation', 'float', 'font',
      'font-family', 'font-size', 'font-style', 'font-variant', 'font-weight',
      'height', 'letter-spacing', 'line-height', 'overflow', 'pause',
      'pause-after', 'pause-before', 'pitch', 'pitch-range', 'richness',
      'speak', 'speak-header', 'speak-numeral', 'speak-punctuation',
      'speech-rate', 'stress', 'text-align', 'text-decoration', 'text-indent',
      'unicode-bidi', 'vertical-align', 'voice-family', 'volume',
      'white-space', 'width']

      # survey of common keywords found in feeds
      @@acceptable_css_keywords = ['auto', 'aqua', 'black', 'block', 'blue',
      'bold', 'both', 'bottom', 'brown', 'center', 'collapse', 'dashed',
      'dotted', 'fuchsia', 'gray', 'green', '!important', 'italic', 'left',
      'lime', 'maroon', 'medium', 'none', 'navy', 'normal', 'nowrap', 'olive',
      'pointer', 'purple', 'red', 'right', 'solid', 'silver', 'teal', 'top',
      'transparent', 'underline', 'white', 'yellow']

      @@mathml_elements = ['maction', 'math', 'merror', 'mfrac', 'mi',
      'mmultiscripts', 'mn', 'mo', 'mover', 'mpadded', 'mphantom',
      'mprescripts', 'mroot', 'mrow', 'mspace', 'msqrt', 'mstyle', 'msub',
      'msubsup', 'msup', 'mtable', 'mtd', 'mtext', 'mtr', 'munder',
      'munderover', 'none']

      @@mathml_attributes = ['actiontype', 'align', 'columnalign', 'columnalign',
      'columnalign', 'columnlines', 'columnspacing', 'columnspan', 'depth',
      'display', 'displaystyle', 'equalcolumns', 'equalrows', 'fence',
      'fontstyle', 'fontweight', 'frame', 'height', 'linethickness', 'lspace',
      'mathbackground', 'mathcolor', 'mathvariant', 'mathvariant', 'maxsize',
      'minsize', 'other', 'rowalign', 'rowalign', 'rowalign', 'rowlines',
      'rowspacing', 'rowspan', 'rspace', 'scriptlevel', 'selection',
      'separator', 'stretchy', 'width', 'width', 'xlink:href', 'xlink:show',
      'xlink:type', 'xmlns', 'xmlns:xlink']

      # svgtiny - foreignObject + linearGradient + radialGradient + stop
      @@svg_elements = ['a', 'animate', 'animateColor', 'animateMotion',
      'animateTransform', 'circle', 'defs', 'desc', 'ellipse', 'font-face',
      'font-face-name', 'font-face-src', 'g', 'glyph', 'hkern', 'image',
      'linearGradient', 'line', 'metadata', 'missing-glyph', 'mpath', 'path',
      'polygon', 'polyline', 'radialGradient', 'rect', 'set', 'stop', 'svg',
      'switch', 'text', 'title', 'use']

      # svgtiny + class + opacity + offset + xmlns + xmlns:xlink
      @@svg_attributes = ['accent-height', 'accumulate', 'additive', 'alphabetic',
       'arabic-form', 'ascent', 'attributeName', 'attributeType',
       'baseProfile', 'bbox', 'begin', 'by', 'calcMode', 'cap-height',
       'class', 'color', 'color-rendering', 'content', 'cx', 'cy', 'd',
       'descent', 'display', 'dur', 'end', 'fill', 'fill-rule', 'font-family',
       'font-size', 'font-stretch', 'font-style', 'font-variant',
       'font-weight', 'from', 'fx', 'fy', 'g1', 'g2', 'glyph-name', 
       'gradientUnits', 'hanging', 'height', 'horiz-adv-x', 'horiz-origin-x',
       'id', 'ideographic', 'k', 'keyPoints', 'keySplines', 'keyTimes',
       'lang', 'mathematical', 'max', 'min', 'name', 'offset', 'opacity',
       'origin', 'overline-position', 'overline-thickness', 'panose-1',
       'path', 'pathLength', 'points', 'preserveAspectRatio', 'r',
       'repeatCount', 'repeatDur', 'requiredExtensions', 'requiredFeatures',
       'restart', 'rotate', 'rx', 'ry', 'slope', 'stemh', 'stemv', 
       'stop-color', 'stop-opacity', 'strikethrough-position',
       'strikethrough-thickness', 'stroke', 'stroke-dasharray',
       'stroke-dashoffset', 'stroke-linecap', 'stroke-linejoin',
       'stroke-miterlimit', 'stroke-width', 'systemLanguage', 'target',
       'text-anchor', 'to', 'transform', 'type', 'u1', 'u2',
       'underline-position', 'underline-thickness', 'unicode',
       'unicode-range', 'units-per-em', 'values', 'version', 'viewBox',
       'visibility', 'width', 'widths', 'x', 'x-height', 'x1', 'x2',
       'xlink:actuate', 'xlink:arcrole', 'xlink:href', 'xlink:role',
       'xlink:show', 'xlink:title', 'xlink:type', 'xml:base', 'xml:lang',
       'xml:space', 'xmlns', 'xmlns:xlink', 'y', 'y1', 'y2', 'zoomAndPan']

      @@svg_attr_map = nil
      @@svg_elem_map = nil

      @@acceptable_svg_properties = [ 'fill', 'fill-opacity', 'fill-rule',
      'stroke', 'stroke-width', 'stroke-linecap', 'stroke-linejoin',
      'stroke-opacity']

      @@acceptable_tag_specific_attributes = {}
      unless $compatible 
        @@mathml_elements.each{|e| @@acceptable_tag_specific_attributes[e] = @@mathml_attributes }
        @@svg_elements.each{|e| @@acceptable_tag_specific_attributes[e] = @@svg_attributes }
      end

    def initialize(children, config=nil)
      old_initialize(children)
      @config = { :nuke_tags => @@unacceptable_elements_with_end_tag ,
          :allow_tags => @@acceptable_elements,
          :allow_attributes => @@acceptable_attributes,
          :allow_tag_specific_attributes => @@acceptable_tag_specific_attributes
      }
      unless $compatible
        @config.merge!({:allow_css_properties => @@acceptable_css_properties,
            :allow_css_keywords => @@acceptable_css_keywords
        })
      end
      @config.merge!(config) unless config.nil?
    end
    
    def recursive_strip(e)
      unless e.class == Hpricot::Text
        if e.class == Hpricot::Elements or e.class == Array
          e.reverse.each{ |ce| recursive_strip(ce) }
        else
          e.children.reverse.each{ |ce| recursive_strip(ce) }
          unless @config[:allow_tags].include?e.name
            e.strip
          end
        end
      end
    end

    def scrub
      @config[:nuke_tags].each { |tag| (self/tag).remove } # yes, that '/' should be there
      @config[:allow_tags].each do |tag|
        (self/tag).strip_attributes(@config[:allow_tag_specific_attributes][tag] || @config[:allow_attributes])
        unless $compatible
          (self/tag).strip_style(@config[:allow_css_properties], @config[:allow_css_keywords])
        end
      end
      recursive_strip(children)
      return self
    end
  end
end


module FeedParser
  @version = "0.1aleph_naught"
  # FIXME OVER HERE! Hi. I'm still translating. Grep for "FIXME untranslated" to 
  # figure out, roughly, what needs to be done.  I've tried to put it next to 
  # anything having to do with any unimplemented sections. There are plent of 
  # other FIXMEs however

  # HTTP "User-Agent" header to send to servers when downloading feeds.
  # If you are embedding feedparser in a larger application, you should
  # change this to your application name and URL.
  USER_AGENT = "UniversalFeedParser/%s +http://feedparser.org/" % @version

  # HTTP "Accept" header to send to servers when downloading feeds.  If you don't
  # want to send an Accept header, set this to None.
  ACCEPT_HEADER = "application/atom+xml,application/rdf+xml,application/rss+xml,application/x-netcdf,application/xml;q=0.9,text/xml;q=0.2,*/*;q=0.1"


  # List of preferred XML parsers, by SAX driver name.  These will be tried first,
  # but if they're not installed, Python will keep searching through its own list
  # of pre-installed parsers until it finds one that supports everything we need.
  PREFERRED_XML_PARSERS = ["drv_libxml2"] #FIXME untranslated

  # If you want feedparser to automatically run HTML markup through HTML Tidy, set
  # this to true.  Requires mxTidy <http://www.egenix.com/files/python/mxTidy.html>
  # or utidylib <http://utidylib.berlios.de/>.
  TIDY_MARKUP = false #FIXME untranslated

  # List of Python interfaces for HTML Tidy, in order of preference.  Only useful
  # if TIDY_MARKUP = true
  PREFERRED_TIDY_INTERFACES = ["uTidy", "mxTidy"] #FIXME untranslated

  # The original Python import. I'm using it to help translate
  #import sgmllib, re, sys, copy, urlparse, time, rfc822, types, cgi, urllib, urllib2




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

  # FIXME untranslated, the sgmllib, can it be replaced with Hpricot?

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
  class FeedParserDict < Hash 
=begin
     The naming of a certain common attribute (such as, "When was the last
     time this feed was updated?") can have many different names depending
     on the type of feed we are handling. This class allows us to use
     both the attribute name a person, who has knowledge of the kind of
     feed being parsed, expects, as well as allowing a developer to rely
     on one name to contain the proper attribute no matter what kind of
     feed is being parsed. @@keymaps is a Hash that contains information
     on what certain attributes "really is" in each feed type. It does so
     by providing a common name that will map to any feed type in the keys,
     with possible "correct" attributes in the its values. the #[] and #[]=
     methods check with keymaps to see what attribute the developer "really
     means" if they've asked for one which happens to be in @@keymap's keys.
=end
    @@keymap = {'channel' => 'feed',
              'items' => 'entries',
              'guid' => 'id',
              'date' => 'updated',
              'date_parsed' => 'updated_parsed',
              'description' => ['subtitle', 'summary'],
              'url' => ['href'],
              'modified' => 'updated',
              'modified_parsed' => 'updated_parsed',
              'issued' => 'published',
              'issued_parsed' => 'published_parsed',
              'copyright' => 'rights',
              'copyright_detail' => 'rights_detail',
              'tagline' => 'subtitle',
              'tagline_detail' => 'subtitle_detail'}
  
    def entries # Apparently, Hash has an entries method!  That blew a good 3 hours or more of my time
      return self['entries']
    end
    # We could include the [] rewrite in new using Hash.new's fancy pants block thing
    # but we'd still have to overwrite []= and such. 
    # I'm going to make it easy to turn lists of pairs into FeedParserDicts's though.
    def initialize(pairs=nil)
      if pairs.class == Array and pairs[0].class == Array and pairs[0].length == 2
        pairs.each do |l| 
          k,v = l
          self[k] = v
        end
      elsif pairs.class == Hash
        self.merge!(pairs) 
      end
    end

    def [](key)
      if key == 'category'
        return self['tags'][0]['term']
      end
      if key == 'categories' #FIXME why does the orignial code use separate if-statements?
        return self['tags'].collect{|tag| [tag['scheme'],tag['term']]}
      end
      realkey = @@keymap[key] || key 
      if realkey.class == Array
        realkey.each{ |key| return self[key] if has_key?key }
      end
      # Note that the original key is preferred over the realkey we (might 
      # have) found in @@keymaps
      if has_key?(key)
        return super(key)
      end
      return super(realkey)
    end

    def []=(key,value)
      if @@keymap.key?key
        key = @@keymap[key]
        if key.class == Array
          key = key[0]
        end
      end
      super(key,value)
    end

    #def fetch(key, default=nil) 
      # fetch is to Ruby's Hash as get is to Python's Dict
    #  if self.has_key?key
    #    return self[key]
    #  else
    #    return default
    #  end
    #end

    #def get(key, default=nil)
      # in case people don't get the memo. i'm betting this will be removed soon
    #  self.fetch(key, default)
    #end

    def method_missing(msym, *args)
      methodname = msym.to_s
      if methodname[-1] == '='
        return self[methodname[0..-2]] = args[0]
      elsif methodname[-1] != '!' and methodname[-1] != '?' and methodname[0] != "_" # FIXME implement with private
        return self[methodname]
      else
        raise NoMethodError, "whoops, we don't know about the attribute or method called `#{methodname}' for #{self}:#{self.class}"
      end
    end 
  end




  module FeedParserMixin
    attr_accessor :feeddata, :version, :namespacesInUse

    def startup(baseuri=nil, baselang=nil, encoding='utf-8')
      $stderr << "initializing FeedParser\n" if $debug
      
      @namespaces = {'' => '',
                'http://backend.userland.com/rss' => '',
                'http://blogs.law.harvard.edu/tech/rss' => '',
                'http://purl.org/rss/1.0/' => '',
                'http://my.netscape.com/rdf/simple/0.9/' => '',
                'http://example.com/newformat#' => '',
                'http://example.com/necho' => '',
                'http://purl.org/echo/' => '',
                'uri/of/echo/namespace#' => '',
                 'http://purl.org/pie/' => '',
                  'http://purl.org/atom/ns#' => '',
                  'http://www.w3.org/2005/Atom' => '',
                  'http://purl.org/rss/1.0/modules/rss091#' => '',
                  'http://webns.net/mvcb/' =>                               'admin',
                  'http://purl.org/rss/1.0/modules/aggregation/' =>         'ag',
                  'http://purl.org/rss/1.0/modules/annotate/' =>            'annotate',
                  'http://media.tangent.org/rss/1.0/' =>                    'audio',
                  'http://backend.userland.com/blogChannelModule' =>        'blogChannel',
                  'http://web.resource.org/cc/' =>                          'cc',
                  'http://backend.userland.com/creativeCommonsRssModule' => 'creativeCommons',
                  'http://purl.org/rss/1.0/modules/company' =>              'co',
                  'http://purl.org/rss/1.0/modules/content/' =>             'content',
                  'http://my.theinfo.org/changed/1.0/rss/' =>               'cp',
                  'http://purl.org/dc/elements/1.1/' =>                     'dc',
                  'http://purl.org/dc/terms/' =>                            'dcterms',
                  'http://purl.org/rss/1.0/modules/email/' =>               'email',
                  'http://purl.org/rss/1.0/modules/event/' =>               'ev',
                  'http://rssnamespace.org/feedburner/ext/1.0' =>           'feedburner',
                  'http://freshmeat.net/rss/fm/' =>                         'fm',
                  'http://xmlns.com/foaf/0.1/' =>                           'foaf',
                  'http://www.w3.org/2003/01/geo/wgs84_pos#' =>             'geo',
                  'http://postneo.com/icbm/' =>                             'icbm',
                  'http://purl.org/rss/1.0/modules/image/' =>               'image',
                  'http://www.itunes.com/DTDs/PodCast-1.0.dtd' =>           'itunes',
                  'http://example.com/DTDs/PodCast-1.0.dtd' =>              'itunes',
                  'http://purl.org/rss/1.0/modules/link/' =>                'l',
                  'http://search.yahoo.com/mrss' =>                         'media',
                  'http://madskills.com/public/xml/rss/module/pingback/' => 'pingback',
                  'http://prismstandard.org/namespaces/1.2/basic/' =>       'prism',
                  'http://www.w3.org/1999/02/22-rdf-syntax-ns#' =>          'rdf',
                  'http://www.w3.org/2000/01/rdf-schema#' =>                'rdfs',
                  'http://purl.org/rss/1.0/modules/reference/' =>           'ref',
                  'http://purl.org/rss/1.0/modules/richequiv/' =>           'reqv',
                  'http://purl.org/rss/1.0/modules/search/' =>              'search',
                  'http://purl.org/rss/1.0/modules/slash/' =>               'slash',
                  'http://schemas.xmlsoap.org/soap/envelope/' =>            'soap',
                  'http://purl.org/rss/1.0/modules/servicestatus/' =>       'ss',
                  'http://hacks.benhammersley.com/rss/streaming/' =>        'str',
                  'http://purl.org/rss/1.0/modules/subscription/' =>        'sub',
                  'http://purl.org/rss/1.0/modules/syndication/' =>         'sy',
                  'http://purl.org/rss/1.0/modules/taxonomy/' =>            'taxo',
                  'http://purl.org/rss/1.0/modules/threading/' =>           'thr',
                  'http://purl.org/rss/1.0/modules/textinput/' =>           'ti',
                  'http://madskills.com/public/xml/rss/module/trackback/' =>'trackback',
                  'http://wellformedweb.org/commentAPI/' =>                 'wfw',
                  'http://purl.org/rss/1.0/modules/wiki/' =>                'wiki',
                  'http://www.w3.org/1999/xhtml' =>                         'xhtml',
                  'http://www.w3.org/XML/1998/namespace' =>                 'xml',
                  'http://www.w3.org/1999/xlink' =>                         'xlink',
                  'http://schemas.pocketsoap.com/rss/myDescModule/' =>      'szf'
      }
      @matchnamespaces = {}
      @namespaces.each do |l|
        @matchnamespaces[l[0].downcase] = l[1]
      end
      @can_be_relative_uri = ['link', 'id', 'wfw_comment', 'wfw_commentrss', 'docs', 'url', 'href', 'comments', 'license', 'icon', 'logo']
      @can_contain_relative_uris = ['content', 'title', 'summary', 'info', 'tagline', 'subtitle', 'copyright', 'rights', 'description']
      @can_contain_dangerous_markup = ['content', 'title', 'summary', 'info', 'tagline', 'subtitle', 'copyright', 'rights', 'description']
      @html_types = ['text/html', 'application/xhtml+xml']
      @feeddata = FeedParserDict.new # feed-level data
      @encoding = encoding # character encoding
      @entries = [] # list of entry-level data
      @version = '' # feed type/version see SUPPORTED_VERSIOSN
      @namespacesInUse = {} # hash of namespaces defined by the feed

      # the following are used internall to track state;
      # this is really out of control and should be refactored
      @infeed = false
      @inentry = false
      @incontent = 0 # Yes, this needs to be zero until I work out popContent and pushContent
      @intextinput = false
      @inimage = false
      @inauthor = false
      @incontributor = false
      @inpublisher = false
      @insource = false
      @sourcedata = FeedParserDict.new
      @contentparams = FeedParserDict.new
      @summaryKey = nil
      @namespacemap = {}
      @elementstack = []
      @basestack = []
      @langstack = []
      @baseuri = baseuri || ''
      @lang = baselang || nil
      if baselang 
        @feeddata['language'] = baselang.gsub('_','-')
      end
      $stderr << "Leaving startup\n" if $debug # My addition
    end

    def unknown_starttag(tag, attrs)
      $stderr << "start #{tag} with #{attrs}\n" if $debug
      # normalize attrs
      attrsD = {}
      attrs.each_key do |old_k| 
        k = old_k.downcase # Downcase all keys
        attrsD[k] = attrs[old_k]
        if ['rel','type'].include?attrsD[k]
          attrsD[k].downcase!   # Downcase the value if the key is 'rel' or 'type'
        end
      end

      # track xml:base and xml:lang
      baseuri = attrsD['xml:base'] || attrsD['base'] || @baseuri 
      @baseuri = urljoin(@baseuri, baseuri)
      lang = attrsD['xml:lang'] || attrsD['lang']
      if lang == '' # FIXME This next bit of code is right? Wtf?
        # xml:lang could be explicitly set to '', we need to capture that
        lang = nil
      elsif lang.nil?
        # if no xml:lang is specified, use parent lang
        lang = @lang
      end
      if lang and not lang.empty? # Seriously, this cannot be correct
        if ['feed', 'rss', 'rdf:RDF'].include?tag
          @feeddata['language'] = lang.replace('_','-')
        end
      end
      @lang = lang
      @basestack << @baseuri 
      @langstack << lang

      # track namespaces
      attrs.to_a.each do |l|
        prefix, uri = l 
        if /^xmlns:/ =~ prefix # prefix begins with xmlns:
          trackNamespace(prefix[6..-1], uri)
        elsif prefix == 'xmlns':
          trackNamespace(nil, uri)
        end
      end

      # track inline content
      if @incontent != 0 and @contentparams.has_key?('type') and not ( /xml$/ =~ (@contentparams['type'] || 'xml') )
        # element declared itself as escaped markup, but isn't really
        @contentparams['type'] = 'application/xhtml+xml'
      end
      if @incontent != 0 and @contentparams['type'] == 'application/xhtml+xml'
        # Note: probably shouldn't simply recreate localname here, but
        # our namespace handling isn't actually 100% correct in cases where
        # the feed redefines the default namespace (which is actually
        # the usual case for inline content, thanks Sam), so here we
        # cheat and just reconstruct the element based on localname
        # because that compensates for the bugs in our namespace handling.
        # This will horribly munge inline content with non-empty qnames,
        # but nobody actually does that, so I'm not fixing it.
        tag = tag.split(':')[-1]
        attrsA = attrs.to_a.collect{|l| "#{l[0]}=\"#{l[1]}\""} # FIXME this is just ugly
        attrsS = ' '+attrsA.join(' ')
        return handle_data('<%s%s>' % [tag,attrsS], escape=false) 
      end

      # match namespaces
      if /:/ =~ tag
        prefix, suffix = tag.split(':', 2)
      else
        prefix, suffix = '', tag
      end
      prefix = @namespacemap[prefix] || prefix
      if prefix and not prefix.empty?
        prefix = prefix + '_'
      end

      # special hack for better tracking of empty textinput/image elements in illformed feeds
      if (not prefix and not prefix.empty?) and not (['title', 'link', 'description','name'].include?tag)
        @intextinput = false
      end
      if (prefix.nil? or prefix.empty?) and not (['title', 'link', 'description', 'url', 'href', 'width', 'height'].include?tag)
        @inimage = false
      end

      # call special handler (if defined) or default handler
      begin
        return send(('_start_'+prefix+suffix).strip, attrsD)
      rescue NoMethodError
        return push((prefix + suffix).strip, true) # I recognize this strip is probably paranoid
      end  
    end # End unknown_starttag

    def unknown_endtag(tag)
      $stderr << "end #{tag}\n" if $debug
      # match namespaces
      if tag.index(':')
        prefix, suffix = tag.split(':',2)
      else
        prefix, suffix = '', tag
      end
      prefix = @namespacemap[prefix] || prefix
      if prefix and not prefix.empty?
        prefix = prefix + '_'
      end
      
      # call special handler (if defined) or default handler
      begin
        send(('_end_' + prefix + suffix).strip) # NOTE no return here! do not add it!
      rescue NoMethodError
        return pop((prefix + suffix).strip)
      end

      # track inline content
      if @incontent != 0 and @contentparams.has_key?'type' and /xml$/ =~ (@contentparams['type'] || 'xml')
        # element declared itself as escaped markup, but it isn't really
        @contentparams['type'] = 'application/xhtml+xml'
      end
      if @incontent != 0 and @contentparams['type'] == 'application/xhtml+xml'
        tag = tag.split(':')[-1]
        handle_data("</#{tag}>", escape=false)
      end

      # track xml:base and xml:lang going out of scope
      if @basestack and not @basestack.empty?
        @basestack.pop
        if @basestack and @basestack[-1] and not (@basestack.empty? or @basestack[-1].empty?)
          @baseuri = @basestack[-1]
        end
      end
      if @langstack and not @langstack.empty?
        @langstack.pop
        if @langstack and not @langstack.empty? # and @langstack[-1] and not @langstack.empty?
          @lang = @langstack[-1]
        end
      end
    end

    def handle_data(text, escape=true)

      # called for each block of plain text, i.e. outside of any tag and
      # not containing any character or entity references
      return if @elementstack.nil? or @elementstack.empty?
      if escape and @contentparams['type'] == 'application/xhtml+xml'
        text = REXML::Text.new(text).to_s # FIXME test this
      end
      @elementstack[-1][2] << text
    end

    def handle_comment(comment)
      # called for each comment, e.g. <!-- insert message here -->
    end

    def mapContentType(contentType)
      contentType.downcase!
      case contentType
      when 'text'
        contentType = 'text/plain'
      when 'html'
        contentType = 'text/html'
      when 'xhtml'
        contentType = 'application/xhtml+xml'
      end
      return contentType
    end

    def trackNamespace(prefix, uri)
      
      loweruri = uri.downcase.strip
      if [prefix, loweruri] == [nil, 'http://my.netscape.com/rdf/simple/0.9/'] and (@version.nil? or @version.empty?)
        @version = 'rss090'
      elsif loweruri == 'http://purl.org/rss/1.0/' and (@version.nil? or @version.empty?)
        @version = 'rss10'
      elsif loweruri == 'http://www.w3.org/2005/atom' and (@version.nil? or @version.empty?)
        @version = 'atom10'
      elsif /backend\.userland\.com\/rss/ =~ loweruri
        # match any backend.userland.com namespace
        uri = 'http://backend.userland.com/rss'
        loweruri = uri
      end
      if @matchnamespaces.has_key? loweruri
        @namespacemap[prefix] = @matchnamespaces[loweruri]
        @namespacesInUse[@matchnamespaces[loweruri]] = uri
      else
        @namespacesInUse[prefix || ''] = uri
      end
    end

    def resolveURI(uri)
      return urljoin(@baseuri || '', uri)
    end

    def decodeEntities(element, data)
      return data
    end

    def push(element, expectingText)
      @elementstack << [element, expectingText, []]
    end

    def pop(element, stripWhitespace=true)
      return if @elementstack.nil? or @elementstack.empty?
      return if @elementstack[-1][0] != element
      element, expectingText, pieces = @elementstack.pop
      output = pieces.join('')
      if stripWhitespace
        output.strip!
      end
      return output if not expectingText


      # decode base64 content
      if @contentparams['base64']
        out64 = Base64::decode64(output) # a.k.a. [output].unpack('m')[0]
        if not output.empty? and not out64.empty?
          output = out64
        end
      end

      # resolve relative URIs
      if @can_be_relative_uri.include?element and output and not output.empty?
        output = resolveURI(output)
      end

      # decode entities within embedded markup
      if not @contentparams['base64']
        output = decodeEntities(element, output)
      end

      # remove temporary cruft from contentparams
      @contentparams.delete('mode')
      @contentparams.delete('base64')
      
      # resolve relative URIs within embedded markup
      if @html_types.include?mapContentType(@contentparams['type'] || 'text/html')
        if @can_contain_relative_uris.include?element
          output = FeedParser.resolveRelativeURIs(output, @baseuri, @encoding)
        end
      end

      # sanitize embedded markup
      if @html_types.include?mapContentType(@contentparams['type'] || 'text/html')
        if @can_contain_dangerous_markup.include?element
          output = FeedParser.sanitizeHTML(output, @encoding)
        end
      end

      if @encoding and not @encoding.empty? and @encoding != 'utf-8'
        output = uconvert(output, @encoding, 'utf-8') # FIXME we have to turn everything into utf-8, not unicode, because of REXML
      end

      # categories/tags/keywords/whatever are handled in _end_category
      return output if element == 'category'

      # store output in appropriate place(s)
      if @inentry and not @insource
        if element == 'content'
          @entries[-1][element] ||= []
          contentparams = Marshal.load(Marshal.dump(@contentparams)) # deepcopy
          contentparams['value'] = output
          @entries[-1][element] << contentparams
        elsif element == 'link'
          @entries[-1][element] = output
          if output and not output.empty?
            @entries[-1]['links'][-1]['href'] = output
          end
        else
          element = 'summary' if element == 'description'
          @entries[-1][element] = output
          if @incontent != 0
            contentparams = Marshal.load(Marshal.copy(@contentparams))
            contentparams['value'] = output
            @entries[-1][element + '_detail'] = contentparams
          end
        end
      elsif (@infeed or @insource) and not @intextinput and not @inimage
        context = getContext()
        element = 'subtitle' if element == 'description'
        context[element] = output
        if element == 'link'
          context['links'][-1]['href'] = output
        elsif @incontent != 0
          contentparams = Marshal.load(Marshal.dump(@contentparams))
          contentparams['value'] = output
          context[element + '_detail'] = contentparams
        end
      end
      return output
    end

    def pushContent(tag, attrsD, defaultContentType, expectingText)
      @incontent += 1 # Yes, I hate this.
      type = mapContentType(attrsD['type'] || defaultContentType)
      @contentparams = FeedParserDict.new({'type' => type,'language' => @lang,'base' => @baseuri})
      @contentparams['base64'] = isBase64(attrsD, @contentparams)
      push(tag, expectingText)
    end

    def popContent(tag)
      value = pop(tag)
      @incontent -= 1
      @contentparams.clear
      return value
    end

    def mapToStandardPrefix(name)
      colonpos = name.index(':')
      if colonpos
        prefix = name[0..colonpos-1]
        suffix = name[colonpos+1..-1]
        prefix = @namespacemap[prefix] || prefix
        name = prefix + ':' + suffix
      end
      return name
    end

    def getAttribute(attrsD, name)
      return attrsD[mapToStandardPrefix(name)]
    end

    def isBase64(attrsD, contentparams)
      return true if (attrsD['mode'] == 'base64')
      if /(^text\/)|(\+xml$)|(\/xml$)/ =~ contentparams['type']
        return false
      end
      return true
    end

    def itsAnHrefDamnIt(attrsD)
      href= attrsD['url'] || attrsD['uri'] || attrsD['href'] 
      if href
        attrsD.delete('url')
        attrsD.delete('uri')
        attrsD['href'] = href
      end
      return attrsD
    end


    def _save(key, value)
      context = getContext()
      context[key] ||= value
    end

    def _start_rss(attrsD)
      versionmap = {'0.91' => 'rss091u',
                  '0.92' => 'rss092',
                  '0.93' => 'rss093',
                  '0.94' => 'rss094'
      }

      if not @version or @version.empty?
        attr_version = attrsD['version'] || ''
        version = versionmap[attr_version]
        if version and not version.empty?
          @version = version
        elsif /^2\./ =~ attr_version
          @version = 'rss20'
        else
          @version = 'rss'
        end
      end
    end

    def _start_dlhottitles(attrsD)
      @version = 'hotrss'
    end

    def _start_channel(attrsD)
      @infeed = true
      _cdf_comment(attrsD)
    end
    alias :_start_feedinfo :_start_channel

    def _cdf_common(attrsD)
      if attrsD.has_key?'lastmod'
        _start_modified({})
        @elementstack[-1][-1] = attrsD['lastmod']
        _end_modified
      end
      if attrsD.has_key?'href'
        start_link({})
        @elementstack[-1][-1] = attrsD['href']
        _end_link
      end
    end

    def _start_feed(attrsD)
      @infeed = true 
      versionmap = {'0.1' => 'atom01',
                  '0.2' => 'atom02',
                  '0.3' => 'atom03'
      }

      if not @version or @version.empty?
        attr_version = attrsD['version']
        version = versionmap[attr_version]
        if @version and not @version.empty?
          @version = version
        else
          @version = 'atom'
        end
      end
    end

    def _end_channel
      @infeed = false
    end
    alias :_end_feed :_end_channel

    def _start_image(attrsD)
      @inimage = true
      push('image', false)
      context = getContext()
      context['image'] ||= FeedParserDict.new
    end

    def _end_image
      pop('image')
      @inimage = false
    end

    def _start_textinput(attrsD)
      @intextinput = true
      push('textinput', false)
      context = getContext()
      context['textinput'] ||= FeedParserDict.new
    end
    alias :_start_textInput :_start_textinput

    def _end_textinput
      pop('textinput')
      @intextinput = false
    end
    alias :_end_textInput :_end_textinput

    def _start_author(attrsD)
      @inauthor = true
      push('author', false)
    end
    alias :_start_managingeditor :_start_author
    alias :_start_dc_author :_start_author
    alias :_start_dc_creator :_start_author
    alias :_start_itunes_author :_start_author

    def _end_author
      pop('author')
      @inauthor = false
      _sync_author_detail()
    end
    alias :_end_managingeditor :_end_author
    alias :_end_dc_author :_end_author
    alias :_end_dc_creator :_end_author
    alias :_end_itunes_author :_end_author

    def _start_itunes_owner(attrsD)
      @inpublisher = true
      push('publisher', false)
    end

    def _end_itunes_owner
      pop('publisher')
      @inpublisher = false
      _sync_author_detail('publisher')
    end

    def _start_contributor(attrsD)
      @incontributor = true
      context = getContext()
      context['contributors'] ||= []
      context['contributors'] << FeedParserDict.new
      push('contributor', false)
    end

    def _end_contributor
      pop('contributor')
      @incontributor = false
    end

    def _start_dc_contributor(attrsD)
      @incontributor = true
      context = getContext()
      context['contributors'] ||= []
      context['contributors'] << FeedParserDict.new
      push('name', false)
    end

    def _end_dc_contributor
      _end_name
      @incontributor = false
    end

    def _start_name(attrsD)
      push('name', false)
    end
    alias :_start_itunes_name :_start_name

    def _end_name
      value = pop('name')
      if @inpublisher
        _save_author('name', value, 'publisher')
      elsif @inauthor
        _save_author('name', value)
      elsif @incontributor
        _save_contributor('name', value)
      elsif @intextinput
        context = getContext()
        context['textinput']['name'] = value
      end
    end
    alias :_end_itunes_name :_end_name

    def _start_width(attrsD)
      push('width', false)
    end

    def _end_width
      value = pop('width').to_i
      if @inimage 
        context = getContext
        context['image']['width'] = value
      end
    end

    def _start_height(attrsD)
      push('height', false)
    end

    def _end_height
      value = pop('height').to_i
      if @inimage
        context = getContext()
        context['image']['height'] = value
      end
    end

    def _start_url(attrsD)
      push('href', true)
    end
    alias :_start_homepage :_start_url
    alias :_start_uri :_start_url

    def _end_url
      value = pop('href')
      if @inauthor
        _save_author('href', value)
      elsif @incontributor
        _save_contributor('href', value)
      elsif @inimage
        context = getContext()
        context['image']['href'] = value
      elsif @intextinput
        context = getContext()
        context['textinput']['link'] = value
      end
    end
    alias :_end_homepage :_end_url
    alias :_end_uri :_end_url

    def _start_email(attrsD)
      push('email', false)
    end
    alias :_start_itunes_email :_start_email

    def _end_email
      value = pop('email')
      if @inpublisher
        _save_author('email', value, 'publisher')
      elsif @inauthor
        _save_author('email', value)
      elsif @incontributor
        _save_contributor('email', value)
      end
    end
    alias :_end_itunes_email :_end_email

    def getContext
      if @insource
        context = @sourcedata
      elsif @inentry
        context = @entries[-1]
      else
        context = @feeddata
      end
      return context
    end

    def _save_author(key, value, prefix='author')
      context = getContext()
      context[prefix + '_detail'] ||= FeedParserDict.new
      context[prefix + '_detail'][key] = value
      _sync_author_detail()
    end

    def _save_contributor(key, value)
      context = getContext
      context['contributors'] ||= [FeedParserDict.new]
      context['contributors'][-1][key] = value
    end

    def _sync_author_detail(key='author')
      context = getContext()
      detail = context["#{key}_detail"]
      if detail and not detail.empty?
        name = detail['name']
        email = detail['email']
        if name and email and not (name.empty? or name.empty?)
          context[key] = "#{name} (#{email})"
        elsif name and not name.empty?
          context[key] = name
        elsif email and not email.empty?
          context[key] = email
        end
      else
        author = context[key]
        return unless (author and not author.empty?)
        emailmatch = author.scan(/(([a-zA-Z0-9\_\-\.\+]+)@((\[[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.)|(([a-zA-Z0-9\-]+\.)+))([a-zA-Z]{2,4}|[0-9]{1,3})(\]?))/)
        email = emailmatch[0]
        author.gsub!(email, '').gsub!('()', '').strip!
        if author and author[0] == '(' 
          author = author[1..-1]
        end
        if author and author[-1] == ')'
          author = author[0..-2]
        end
        author.strip!
        context["#{key}_detail"] ||= FeedParserDict.new
        context["#{key}_detail"]['name'] = author
        context["#{key}_detail"]['email'] = email
      end
    end

    def _start_subtitle(attrsD)
      pushContent('subtitle', attrsD, 'text/plain', true)
    end
    alias :_start_tagline :_start_subtitle
    alias :_start_itunes_subtitle :_start_subtitle

    def _end_subtitle
      popContent('subtitle')
    end
    alias :_end_tagline :_end_subtitle
    alias :_end_itunes_subtitle :_end_subtitle

    def _start_rights(attrsD)
      pushContent('rights', attrsD, 'text/plain', true)
    end
    alias :_start_dc_rights :_start_rights
    alias :_start_copyright :_start_rights

    def _end_rights
      popContent('rights')
    end
    alias :_end_dc_rights :_end_rights
    alias :_end_copyright :_end_rights

    def _start_item(attrsD)
      @entries << FeedParserDict.new
      push('item', false)
      @inentry = true
      @guidislink = false
      id = getAttribute(attrsD, 'rdf:about')
      if id and not id.empty?
        context = getContext()
        context['id'] = id
      end
      _cdf_common(attrsD)
    end
    alias :_start_entry :_start_item
    alias :_start_product :_start_item

    def _end_item
      pop('item')
      @inentry = false
    end
    alias :_end_entry :_end_item

    def _start_dc_language(attrsD)
      push('language', true)
    end
    alias :_start_language :_start_dc_language

    def _end_dc_language
      @lang = pop('language')
    end
    alias :_end_language :_end_dc_language

    def _start_dc_publisher
      push('publisher', true)
    end
    alias :_start_webmaster :_start_dc_publisher

    def _end_dc_publisher
      pop('publisher')
      _sync_author_detail('publisher')
    end
    alias :_end_webmaster :_end_dc_publisher

    def _start_published(attrsD)
      push('published', true)
    end
    alias :_start_dcterms_issued :_start_published
    alias :_start_issued :_start_published

    def _end_published
      value = self.pop('published')
      _save('published_parsed', _parse_date(value))
    end
    alias :_end_dcterms_issued :_end_published
    alias :_end_issued :_end_published

    def _start_updated(attrsD)
      push('updated', true)
    end
    alias :_start_modified :_start_updated
    alias :_start_dcterms_modified :_start_updated
    alias :_start_pubdate :_start_updated
    alias :_start_dc_date :_start_updated

    def _end_updated
      value = pop('updated')
      parsed_value = _parse_date(value)
      _save('updated_parsed', parsed_value)
    end
    alias :_end_modified :_end_updated
    alias :_end_dcterms_modified :_end_updated
    alias :_end_pubdate :_end_updated
    alias :_end_dc_date :_end_updated

    def _start_created(attrsD)
      push('created', true)
    end
    alias :_start_dcterms_created :_start_created

    def _end_created
      value = pop('created')
      _save('created_parsed', _parse_date(value))
    end
    alias :_end_dcterms_created :_end_created

    def _start_expirationdate(attrsD)
      push('expired', true)
    end
    def _end_expirationdate
      _save('expired_parsed', _parse_date(pop('expired')))
    end

    def _start_cc_license(attrsD)
      push('license', true)
      value = getAttribute(attrsD, 'rdf:resource')
      if value and not value.empty?
        elementstack[-1][2] <<  value
        pop('license')
      end
    end

    def _start_creativecommons_license(attrsD)
      push('license', true)
    end

    def _end_creativecommons_license
      pop('license')
    end

    def addTag(term, scheme, label)
      context = getContext()
      tags = context['tags'] ||= []
      if (term.nil? or term.empty?) and (scheme.nil? or scheme.empty?) and (label.nil? or label.empty?)
        return
      end
      value = FeedParserDict.new({'term' => term, 'scheme' => scheme, 'label' => label})
      if not tags.include?value
        tags << FeedParserDict.new({'term' => term, 'scheme' => scheme, 'label' => label})
      end
    end

    def _start_category(attrsD)
      $stderr << "entering _start_category with #{attrsD}\n" if $debug

      term = attrsD['term']
      scheme = attrsD['scheme'] || attrsD['domain']
      label = attrsD['label']
      addTag(term, scheme, label)
      push('category', true)
    end
    alias :_start_dc_subject :_start_category
    alias :_start_keywords :_start_category

    def _end_itunes_keywords
      pop('itunes_keywords').split.each do |term|
        addTag(term, 'http://www.itunes.com/', nil)
      end
    end

    def _start_itunes_category(attrsD)
      addTag(attrsD['text'], 'http://www.itunes.com/', nil)
      push('category', true)
    end

    def _end_category
      value = pop('category')
      return if value.nil? or value.empty?
      context = _getContext()
      tags = context['tags']
      if value and not value.empty? and not tags.empty? and not tags[-1]['term']:
        tags[-1]['term'] = value
      else
        addTag(value, nil, nil)
      end
    end
    alias :_end_dc_subject :_end_category
    alias :_end_keywords :_end_category
    alias :_end_itunes_category :_end_category

    def _start_cloud(attrsD)
      getContext()['cloud'] = FeedParserDict.new(attrsD)
    end

    def _start_link(attrsD)
      attrsD['rel'] ||= 'alternate'
      attrsD['type'] ||= 'text/html'
      attrsD = itsAnHrefDamnIt(attrsD)
      if attrsD.has_key? 'href'
        attrsD['href'] = resolveURI(attrsD['href'])
      end
      expectingText = @infeed || @inentry || @insource
      context = getContext()
      context['links'] ||= []
      context['links'] << FeedParserDict.new(attrsD)
      if attrsD['rel'] == 'enclosure'
        _start_enclosure(attrsD)
      end
      if attrsD.has_key? 'href'
        expectingText = false
        if (attrsD['rel'] == 'alternate') and @html_types.include?mapContentType(attrsD['type'])
          context['link'] = attrsD['href']
        end
      else
        push('link', expectingText)
      end
    end
    alias :_start_producturl :_start_link

    def _end_link
      value = pop('link')
      context = getContext()
      if @intextinput
        context['textinput']['link'] = value
      end
      if @inimage
        context['image']['link'] = value
      end
    end
    alias :_end_producturl :_end_link

    def _start_guid(attrsD)
      guidislink = ((attrsD['ispermalink'] || 'true') == 'true')
      push('id', true)
    end

    def _end_guid
      value = pop('id')
      _save('guidislink', (guidislink and not getContext().has_key?('link')))
      if guidislink:
        # guid acts as link, but only if 'ispermalink' is not present or is 'true',
        # and only if the item doesn't already have a link element
        _save('link', value)
      end
    end


    def _start_title(attrsD)
      pushContent('title', attrsD, 'text/plain', @infeed || @inentry || @insource)
    end
    alias :_start_dc_title :_start_title
    alias :_start_media_title :_start_title

    def _end_title
      value = popContent('title')
      context = getContext()
      if @intextinput
        context['textinput']['title'] = value
      elsif @inimage
        context['image']['title'] = value
      end
    end
    alias :_end_dc_title :_end_title
    alias :_end_media_title :_end_title

    def _start_description(attrsD)
      context = getContext()
      if context.has_key?('summary')
        @summaryKey = 'content'
        _start_content(attrsD)
      else
        pushContent('description', attrsD, 'text/html', @infeed || @inentry || @insource)
      end
    end

    def _start_abstract(attrsD)
      pushContent('description', attrsD, 'text/plain', @infeed || @inentry || @insource)
    end

    def _end_description
      if @summaryKey == 'content'
        _end_content()
      else
        value = popContent('description')
        context = getContext()
        if @intextinput
          context['textinput']['description'] = value
        elsif @inimage:
          context['image']['description'] = value
        end
      end
      @summaryKey = nil
    end
    alias :_end_abstract :_end_description

    def _start_info(attrsD)
      pushContent('info', attrsD, 'text/plain', true)
    end
    alias :_start_feedburner_browserfriendly :_start_info

    def _end_info
      popContent('info')
    end
    alias :_end_feedburner_browserfriendly :_end_info

    def _start_generator(attrsD)
      if attrsD and not attrsD.empty?
        attrsD = itsAnHrefDamnIt(attrsD)
        if attrsD.has_key?('href')
          attrsD['href'] = resolveURI(attrsD['href'])
        end
      end
      getContext()['generator_detail'] = FeedParserDict.new(attrsD)
      push('generator', true)
    end

    def _end_generator
      value = pop('generator')
      context = getContext()
      if context.has_key?('generator_detail')
        context['generator_detail']['name'] = value
      end
    end

    def _start_admin_generatoragent(attrsD)
      push('generator', true)
      value = getAttribute(attrsD, 'rdf:resource')
      if value and not value.empty?
        elementstack[-1][2] << value
      end
      pop('generator')
      getContext()['generator_detail'] = FeedParserDict.new({'href' => value})
    end

    def _start_admin_errorreportsto(attrsD)
      push('errorreportsto', true)
      value = getAttribute(attrsD, 'rdf:resource')
      if value and not value.empty?
        elementstack[-1][2] << value
      end
      pop('errorreportsto')
    end

    def _start_summary(attrsD)
      context = getContext()
      if context.has_key?'summary'
        @summaryKey = 'content'
        _start_content(attrsD)
      else
        @summaryKey = 'summary'
        pushContent(@summaryKey, attrsD, 'text/plain', true)
      end
    end
    alias :_start_itunes_summary :_start_summary

    def _end_summary
      if @summaryKey == 'content':
        _end_content()
      else
        popContent(@summaryKey || 'summary')
      end
      @summaryKey = nil
    end
    alias :_end_itunes_summary :_end_summary

    def _start_enclosure(attrsD)
      attrsD = itsAnHrefDamnIt(attrsD)
      getContext()['enclosures'] ||= [FeedParserDict.new(attrsD)]
      href = attrsD['href']
      if href and not href.empty?
        context = getContext()
        if not context['id']
          context['id'] = href
        end
      end
    end

    def _start_source(attrsD)
      @insource = true
    end

    def _end_source
      @insource = false
      getContext()['source'] = Marshal.load(Marshal.dump(@sourcedata))
      @sourcedata.clear()
    end

    def _start_content(attrsD)
      pushContent('content', attrsD, 'text/plain', true)
      src = attrsD['src']
      if src and not src.empty?:
        @contentparams['src'] = src
      end
      push('content', true)
    end

    def _start_prodlink(attrsD)
      pushContent('content', attrsD, 'text/html', true)
    end

    def _start_body(attrsD)
      pushContent('content', attrsD, 'application/xhtml+xml', true)
    end
    alias :_start_xhtml_body :_start_body

    def _start_content_encoded(attrsD)
      pushContent('content', attrsD, 'text/html', true)
    end
    alias :_start_fullitem :_start_content_encoded

    def _end_content
      copyToDescription = (['text/plain'] + @html_types).include? mapContentType(@contentparams['type'])
      value = popContent('content')
      if copyToDescription
        _save('description', value)
      end
      alias :_end_body :_end_content
      alias :_end_xhtml_body :_end_content
      alias :_end_content_encoded :_end_content
      alias :_end_fullitem :_end_content
      alias :_end_prodlink :_end_content
    end

    def _start_itunes_image(attrsD)
      push('itunes_image', false)
      _getContext()['image'] = FeedParserDict.new({'href' => attrsD['href']})
    end
    alias :_start_itunes_link :_start_itunes_image

    def _end_itunes_block
      value = pop('itunes_block', false)
      _getContext()['itunes_block'] = (value == 'yes') and true or false
    end

    def _end_itunes_explicit
      value = pop('itunes_explicit', false)
      getContext()['itunes_explicit'] = (value == 'yes') and true or false
    end

  end # End FeedParserMixin

    class StrictFeedListener 
      include REXML::SAX2Listener
      include FeedParserMixin

      attr_accessor :bozo, :entries, :feeddata, :exc
      def initialize(baseuri, baselang, encoding)
        $stderr << "trying StrictFeedParser\n" if $debug
        startup(baseuri, baselang, encoding) # FIXME need to grok mixins, if i name #startup #initialize will this happen for me?
        @bozo = false
        @exc = nil
      end

      def start_document
      end
      def end_document
      end

      def start_prefix_mapping(prefix, uri)
        trackNamespace(prefix, uri)
      end

      def end_prefix_mapping(prefix)
      end

      def start_element(namespace, localname, qname, attributes)
        lowernamespace = (namespace || '').downcase 

        if /backend\.userland\.com\/rss/ =~ lowernamespace
          # match any backend.userland.com namespace
          namespace = 'http://backend.userland.com/rss'
          lowernamespace = namespace
        end
        if qname and qname.index(':')
          givenprefix = qname.split(':')[0] # Not sure if this is appropriate
        else
          givenprefix = nil
        end
        prefix = @matchnamespaces[lowernamespace] || givenprefix
        if givenprefix and (prefix or (prefix.empty? and lowernamespace.empty?)) and not namespacesInUse.has_key?givenprefix
          raise UndeclaredNamespace #FIXME no such error
        end
        if prefix and not prefix.empty?
          localname = prefix + ':' + localname
        end
        localname = localname.to_s.downcase # No utf/unicode
        unknown_starttag(localname, attributes)
      end

      def characters(text)
        handle_data(text)
      end

      def end_element(namespace, localname, qname) # FIXME untranslated, other than this first line
        lowernamespace = (namespace || '').downcase
        if qname and qname.index(':')
          givenprefix = qname.split(':')[0] # NOTE I'm fairly certain that REXML never passes anything like xhtml:div
        else
          givenprefix = ''
        end
        prefix = @matchnamespaces[lowernamespace] || givenprefix
        if prefix and not prefix.empty?
          localname = prefix + ':' + localname
        end
        localname.downcase!
        unknown_endtag(localname)
      end

      def comment(comment)
        handle_comment(comment)
      end

      def error(exc)
        @bozo = true 
        @exc = exc
      end

      def fatalError(exc)
        error(exc)
        raise exc
      end
    end

  def FeedParser.resolveRelativeURIs(htmlSource, baseURI, encoding)
    $stderr << "entering resolveRelativeURIs\n" if $debug # FIXME write a decent logger
    relative_uris = { 'a' => 'href',
                    'applet' => 'codebase',
                    'area' => 'href',
                    'blockquote' => 'cite',
                    'body' => 'background',
                    'del' => 'cite',
                    'form' => 'action',
                    'frame' => 'longdesc',
                    'frame' => 'src',
                    'iframe' => 'longdesc',
                    'iframe' => 'src',
                    'head' => 'profile',
                    'img' => 'longdesc',
                    'img' => 'src',
                    'img' => 'usemap',
                    'input' => 'src',
                    'input' => 'usemap',
                    'ins' => 'cite',
                    'link' => 'href',
                    'object' => 'classid',
                    'object' => 'codebase',
                    'object' => 'data',
                    'object' => 'usemap',
                    'q' => 'cite',
                    'script' => 'src'
    }
    h = Hpricot(htmlSource)
    relative_uris.each do |ename|
      h.search(ename).each do |elem|
        elem_attr = relative_uris[ename]
        elem_uri = elem.attributes[elem_attr]
        break unless elem_uri
        if URI.parse(the_uri).relative?
          elem.attributes[elem_attr] = URI.join(baseURI, elem_uri)
        end
      end
    end
    return h.to_html
  end

  def self.sanitizeHTML(html,encoding)
    # FIXME Does not do encoding, nor Tidy
    h = Hpricot(html)
    h = h.scrub
    return h.to_html
  end

  @date_handlers = []

  # ISO-8601 date parsing routines written by the Ruby developers.
  # We laugh at the silly Python programmers and their convoluted 
  # regexps. 
  include ParseDate
  def _parse_date_iso8601(dateString)
    # Parse a variety of ISO-8601-compatible formats like 20040105
    Time.mktime(ParseDate::parsedate(dateString))
  end

  # 8-bit date handling routes written by ytrewq1
  _korean_year  = u("\ub144") # b3e2 in euc-kr
  _korean_month = u("\uc6d4") # bff9 in euc-kr
  _korean_day   = u("\uc77c") # c0cf in euc-kr
  _korean_am    = u("\uc624\uc804") # bfc0 c0fc in euc-kr
  _korean_pm    = u("\uc624\ud6c4") # bfc0 c8c4 in euc-kr

  _korean_onblog_date_re = Regexp.new("(\d{4})%s\s+(\d{2})%s\s+(\d{2})%s\s+(\d{2}):(\d{2}):(\d{2})" % [_korean_year, _korean_month, _korean_day])
  _korean_nate_date_re = Regexp.new("(\d{4})-(\d{2})-(\d{2})\s+(%s|%s)\s+(\d{0,2}):(\d{0,2}):(\d{0,2})" % [_korean_am, _korean_pm])

  def _parse_date_onblog(dateString)
    # Parse a string according to the OnBlog 8-bit date format
    m = _korean_onblog_date_re.match(dateString)
    return unless m
    w3dtfdate = '%(year)s-%(month)s-%(day)sT%(hour)s:%(minute)s:%(second)s%(zonediff)s' % \
      {'year' => m[1], 'month' => m[2], 'day' => m[3],\
                 'hour' => m[4], 'minute' => m[5], 'second' => m[6],\
                 'zonediff' => '+09 =>00'}

    $stderr << "OnBlog date parsed as: %s\n" % w3dtfdate if $debug
    return _parse_date_w3dtf(w3dtfdate)
  end
  @date_handlers << :_parse_date_onblog

  def _parse_date_name(dateString)
    # Parse a string according to the Nate 8-bit date format
    m = _korean_nate_date_re.match(dateString)
    return unless m
    hour = m[5].to_i
    ampm = m[4]
    if ampm == _korean_pm
      hour += 12
    end
    hour = hour.to_s.rjust(2,'0') 
    w3dtfdate = '%(year)s-%(month)s-%(day)sT%(hour)s:%(minute)s:%(second)s%(zonediff)s' % \
      {'year' => m[1], 'month' => m[2], 'day' => m[3],\
                 'hour' => hour, 'minute' => m[6], 'second' => m[7],\
                 'zonediff' => '+09 =>00'}
    $stderr << "Nate date parsed as: %s\n" % w3dtfdate if $debug
    return _prase_date_w3dtf(w3dtfdate)
  end
  @date_handlers << :_parse_date_nate

  _mssql_date_re = /(\d{4})-(\d{2})-(\d{2})\s+(\d{2}):(\d{2}):(\d{2})(\.\d+)?/
  def _parse_date_mssql(dateString)
    m = _mssql_date_re.match(dateString)
    return unless m
    w3dtfdate =  '%(year)s-%(month)s-%(day)sT%(hour)s:%(minute)s:%(second)s%(zonediff)s' % \
      {'year' => m[1], 'month' => m[2], 'day' => m[3],\
                 'hour' => m[4], 'minute' => m[5], 'second' => m[6],\
                 'zonediff' => '+09 =>00'}
    $stderr << "MS SQL date parsed as: %s\n" % w3dtfdate if $debug
    return _parse_date_w3dtf(w3dtfdate)
  end
  @date_handlers << :_parse_date_mssql

  # Unicode strings for Greek date strings
  _greek_months = { 
    u("\u0399\u03b1\u03bd") => u("Jan"),       # c9e1ed in iso-8859-7
    u("\u03a6\u03b5\u03b2") => u("Feb"),       # d6e5e2 in iso-8859-7
    u("\u039c\u03ac\u03ce") => u("Mar"),       # ccdcfe in iso-8859-7
    u("\u039c\u03b1\u03ce") => u("Mar"),       # cce1fe in iso-8859-7
    u("\u0391\u03c0\u03c1") => u("Apr"),       # c1f0f1 in iso-8859-7
    u("\u039c\u03ac\u03b9") => u("May"),       # ccdce9 in iso-8859-7
    u("\u039c\u03b1\u03ca") => u("May"),       # cce1fa in iso-8859-7
    u("\u039c\u03b1\u03b9") => u("May"),       # cce1e9 in iso-8859-7
    u("\u0399\u03bf\u03cd\u03bd") => u("Jun"), # c9effded in iso-8859-7
    u("\u0399\u03bf\u03bd") => u("Jun"),       # c9efed in iso-8859-7
    u("\u0399\u03bf\u03cd\u03bb") => u("Jul"), # c9effdeb in iso-8859-7
    u("\u0399\u03bf\u03bb") => u("Jul"),       # c9f9eb in iso-8859-7
    u("\u0391\u03cd\u03b3") => u("Aug"),       # c1fde3 in iso-8859-7
    u("\u0391\u03c5\u03b3") => u("Aug"),       # c1f5e3 in iso-8859-7
    u("\u03a3\u03b5\u03c0") => u("Sep"),       # d3e5f0 in iso-8859-7
    u("\u039f\u03ba\u03c4") => u("Oct"),       # cfeaf4 in iso-8859-7
    u("\u039d\u03bf\u03ad") => u("Nov"),       # cdefdd in iso-8859-7
    u("\u039d\u03bf\u03b5") => u("Nov"),       # cdefe5 in iso-8859-7
    u("\u0394\u03b5\u03ba") => u("Dec"),       # c4e5ea in iso-8859-7
  }

  _greek_wdays =   { 
    u("\u039a\u03c5\u03c1") => u("Sun"), # caf5f1 in iso-8859-7
    u("\u0394\u03b5\u03c5") => u("Mon"), # c4e5f5 in iso-8859-7
    u("\u03a4\u03c1\u03b9") => u("Tue"), # d4f1e9 in iso-8859-7
    u("\u03a4\u03b5\u03c4") => u("Wed"), # d4e5f4 in iso-8859-7
    u("\u03a0\u03b5\u03bc") => u("Thu"), # d0e5ec in iso-8859-7
    u("\u03a0\u03b1\u03c1") => u("Fri"), # d0e1f1 in iso-8859-7
    u("\u03a3\u03b1\u03b2") => u("Sat"), # d3e1e2 in iso-8859-7   
  }

  # FIXME I'm not sure that Regexp and Encoding play well together
  _greek_date_format_re = Regexp.new(u("([^,]+),\s+(\d{2})\s+([^\s]+)\s+(\d{4})\s+(\d{2}):(\d{2}):(\d{2})\s+([^\s]+)"))

  def _parse_date_greek(dateString)
    # Parse a string according to a Greek 8-bit date format
    m = _greek_date_format.match(dateString)
    return unless m
    begin
      wday = _greek_wdays[m[1]]
      month = _greek_months[m[3]]
    rescue
      return # I hate silent exceptions. :(
    end
    rfc822date = '%(wday)s, %(day)s %(month)s %(year)s %(hour)s:%(minute)s:%(second)s %(zonediff)s' % \
      {'wday' => wday, 'day' => m[2], 'month' => month, 'year' => m[4],\
                  'hour' => m[5], 'minute' => m[6], 'second' => m[7],\
                  'zonediff' => m[8]}
    $stderr << "Greek date parsed as: %s\n" % rfc822date
    return _parse_date_rfc822(rfc822date) # FIXME these are just wrappers around Time.  Easily removed
  end
  @date_handlers << :_parse_date_greek

  # Unicode strings for Hungarian date strings
  _hungarian_months = { 
    u("janu\u00e1r") =>   u("01"),  # e1 in iso-8859-2
    u("febru\u00e1ri") => u("02"),  # e1 in iso-8859-2
    u("m\u00e1rcius") =>  u("03"),  # e1 in iso-8859-2
    u("\u00e1prilis") =>  u("04"),  # e1 in iso-8859-2
    u("m\u00e1ujus") =>   u("05"),  # e1 in iso-8859-2
    u("j\u00fanius") =>   u("06"),  # fa in iso-8859-2
    u("j\u00falius") =>   u("07"),  # fa in iso-8859-2
    u("augusztus") =>     u("08"),
    u("szeptember") =>    u("09"),
    u("okt\u00f3ber") =>  u("10"),  # f3 in iso-8859-2
    u("november") =>      u("11"),
    u("december") =>      u("12"),
  }
  _hungarian_date_format_re = /(\d{4})-([^-]+)-(\d{0,2})T(\d{0,2}):(\d{2})((\+|-)(\d{0,2}:\d{2}))/

  def _parse_date_hungarian(dateString)
    # Parse a string according to a Hungarian 8-bit date format.
    return unless m
    begin
      month = _hungarian_months[m[2]]
      day = m[3]
      day = day.rjust(2,'0')
      hour = hour.rjust(2,'0')
    rescue
      return
    end

    w3dtfdate = '%(year)s-%(month)s-%(day)sT%(hour)s =>%(minute)s%(zonediff)s' % \
      {'year' => m[1], 'month' => month, 'day' => day,\
                 'hour' => hour, 'minute' => m[5],\
                 'zonediff' => m[6]}
    $stderr << "Hungarian date parsed as: %s\n" % w3dtfdate
    return _parse_date_w3dtf(w3dtfdate)
  end

  # W3DTF-style date parsing
  # FIXME shouldn't it be "W3CDTF"?
  def _parse_date_w3dtf(dateString)
    # Ruby's Time docs claim w3dtf is an alias for iso8601 which is an alias fro xmlschema
    Time.xmlschema(dateString)
  end

  def _parse_date_rfc822(dateString)
    # Parse an RFC822, RFC1123, RFC2822 or asctime-style date 
    Time.rfc822(dateString)
  end

  def _parse_date_perfoce(aDateString)
    # Parse a date in yyyy/mm/dd hh:mm:ss TTT format
    # Note that there is a day of the week at the beginning 
    # Ex. Fri, 2006/09/15 08:19:53 EDT
    Time.parse(aDateString)
  end

  def _parse_date(dateString)
    # Parses a variety of date formats into a Time object in UTC/GMT.
    # FIXME No, this doesn't match up with the tests. Why? Because I haven't 
    # figured out why Mark went the 9-tuple path. Is Python's time module so 
    # screwed up? Or was there another reason?
    for handler in @_date_handlers
      begin 
        datething = send(handler,dateString)
        return datething
      rescue Exception => e
        $stderr << "%s raised %s\n" % [handler.to_s, e]
      end
    end
    return nil
  end

  def self._getCharacterEncoding(feed, xml_data)
    # Get the character encoding of the XML document
    $stderr << "In _getCharacterEncoding\n" if $debug
    sniffed_xml_encoding = nil
    xml_encoding = nil
    true_encoding = nil
    begin 
      http_headers = feed.meta
      http_content_type = feed.content_type
      http_encoding = feed.charset
    rescue NoMethodError
      http_headers = {}
      http_content_type = 
        http_encoding = nil
    end
    # Must sniff for non-ASCII-compatible character encodings before
    # searching for XML declaration.  This heuristic is defined in
    # section F of the XML specification:
    # http://www.w3.org/TR/REC-xml/#sec-guessing-no-ext-info
    begin 
      if xml_data[0..3] == "\x4c\x6f\xa7\x94"
        # EBCDIC
        xml_data = _ebcdic_to_ascii(xml_data)
      elsif xml_data[0..3] == "\x00\x3c\x00\x3f"
        # UTF-16BE
        sniffed_xml_encoding = 'utf-16be'
        xml_data = uconvert(xml_data, 'utf-16be', 'utf-8')
      elsif xml_data.size >= 4 and xml_data[0..1] == "\xfe\xff" and xml_data[2..3] != "\x00\x00"
        # UTF-16BE with BOM
        sniffed_xml_encoding = 'utf-16be'
        xml_data = uconvert(xml_data[2..-1], 'utf-16be', 'utf-8')
      elsif xml_data[0..3] == "\x3c\x00\x3f\x00"
        # UTF-16LE
        sniffed_xml_encoding = 'utf-16le'
        xml_data = uconvert(xml_data, 'utf-16le', 'utf-8')
      elsif xml_data.size >=4 and xml_data[0..1] == "\xff\xfe" and xml_data[2..3] != "\x00\x00"
        # UTF-16LE with BOM
        sniffed_xml_encoding = 'utf-16le'
        xml_data = uconvert(xml_data[2..-1], 'utf-16le', 'utf-8')
      elsif xml_data[0..3] == "\x00\x00\x00\x3c"
        # UTF-32BE
        sniffed_xml_encoding = 'utf-32be'
        xml_data = uconvert(xml_data, 'utf-32be', 'utf-8')
      elsif xml_data[0..3] == "\x3c\x00\x00\x00"
        # UTF-32LE
        sniffed_xml_encoding = 'utf-32le'
        xml_data = uconvert(xml_data, 'utf-32le', 'utf-8')
      elsif xml_data[0..3] == "\x00\x00\xfe\xff"
        # UTF-32BE with BOM
        sniffed_xml_encoding = 'utf-32be'
        xml_data = uconvert(xml_data[4..-1], 'utf-32BE', 'utf-8')
      elsif xml_data[0..3] == "\xef\xfe\x00\x00"
        # UTF-32LE with BOM
        sniffed_xml_encoding = 'utf-32le'
        xml_data = uconvert(xml_data[4..-1], 'utf-32le', 'utf-8')
      elsif xml_data[0..2] == "\xef\xbb\xbf"
        # UTF-8 with BOM
        sniffed_xml_encoding = 'utf-8'
        xml_data = uconvert(xml_data[3..-1], 'utf-8', 'utf-8')
      else
        # ASCII-compatible
      end
      xml_encoding_match = /^<\?.*encoding=[\'"](.*?)[\'"].*\?>/.match(xml_data)
    rescue
      xml_encoding_match = nil
    end
    if xml_encoding_match 
      xml_encoding = xml_encoding_match[1].downcase
      xencodings = ['iso-10646-ucs-2', 'ucs-2', 'csunicode', 'iso-10646-ucs-4', 'ucs-4', 'csucs4', 'utf-16', 'utf-32', 'utf16', 'u16']
      if sniffed_xml_encoding and xencodings.include?xml_encoding
        xml_encoding = sniffed_xml_encoding
      end
    end

    acceptable_content_type = false
    application_content_types = ['application/xml', 'application/xml-dtd', 'application/xml-external-parsed-entity']
    text_content_types = ['text/xml', 'text/xml-external-parsed-entity']

    if application_content_types.include? http_content_type or 
      (/^text\// =~ http_content_type and /\+xml$/ =~ http_content_type)
      acceptable_content_type = true
      true_encoding = http_encoding || xml_encoding || 'utf-8'
    elsif text_content_types.include? http_content_type or
    /^text\// =~ http_content_type and /\+xml$/ =~ http_content_type
    acceptable_content_type = true
    true_encoding = http_encoding || 'us-ascii'
    elsif /text\// =~ http_content_type 
      true_encoding = http_encoding || 'us-ascii'
    elsif http_headers and not http_headers.empty? and 
      not http_headers.has_key?'content-type'
      true_encoding = xml_encoding || 'iso-8859-1'
    else
      true_encoding = xml_encoding || 'utf-8'
    end
    return true_encoding, http_encoding, xml_encoding, sniffed_xml_encoding, acceptable_content_type
  end

  def self.toUTF8(data, encoding)
=begin
    Changes an XML data stream on the fly to specify a new encoding

    data is a raw sequence of bytes (not Unicode) that is presumed to be in %encoding already
    encoding is a string recognized by encodings.aliases
=end
    $stderr << "entering self.toUTF8, trying encoding %s\n" % encoding if $debug
    # NOTE we must use double quotes when dealing with \x encodings!
    if data.size >= 4 and data[0..1] == "\xfe\xff" and data[2..3] != "\x00\x00" 
      if $debug
        $stderr << "stripping BOM\n"
        if encoding != 'utf-16be'
          $stderr << "string utf-16be instead\n"
        end
      end
      encoding = 'utf-16be'
      data = data[2..-1]
    elsif data.size >= 4 and data[0..1] == "\xff\xfe" and data[2..3] != "\x00\x00"
      if $debug
        $stderr << "stripping BOM\n"
        if encoding !- 'utf-16le'
          $stderr << "trying utf-16le instead\n"
        end
      end
    encoding = 'utf-16le'
    data = data[2..-1]
    elsif data[0..2] == "\xef\xbb\xbf"
      if $debug
        $stderr << "stripping BOM\n"
        if encoding != 'utf-8'
          $stderr << "trying utf-8 instead\n"
        end
      end
    encoding = 'utf-8'
    data = data[2..-1]
    elsif data[0..3] == "\x00\x00\xfe\xff"
      if $debug
        $stderr << "stripping BOM\n"
        if encoding != 'utf-32be'
          $stderr << "trying utf-32be instead\n"
        end
      end
    encoding = 'utf-32be'
    data = data[3..-1]
    elsif data[0..3] == "\xff\xfe\x00\x00"
      if $debug
        $stderr << "stripping BOM\n"
        if encoding != 'utf-3lbe'
          $stderr << "trying utf-32le instead\n"
        end
      end
    encoding = 'utf-32le'
    data = data[3..-1]
    end
    newdata = uconvert(data, encoding, 'utf-8') # Woohoo! Works!
    $stderr << "successfully converted #{encoding} data to utf-8\n" if $debug
    declmatch = /^<\?xml[^>]*?>/
    newdecl = "<?xml version=\'1.0\' encoding=\'utf-8\'?>"
    if declmatch =~ newdata
      newdata.sub!(declmatch, newdecl) #FIXME this was late night coding
    else
      newdata = newdecl + "\n" + newdata
    end
    return newdata
  end

  def self.stripDoctype(data)
=begin
Strips DOCTYPE from XML document, returns (rss_version, stripped_data)

    rss_version may be 'rss091n' or None
    stripped_data is the same XML document, minus the DOCTYPE
=end
    entity_pattern = /<!ENTITY([^>]*?)>/m # m is for Regexp::MULTILINE
    entity_results = data.scan(entity_pattern)
    data = data.sub(entity_pattern,data)

    doctype_pattern = /<!DOCTYPE([^>]*?)>/m
    doctype_results = data.scan(doctype_pattern)
    if doctype_results and doctype_results[0]
      doctype = doctype_results[0]
    else
      doctype = ''
    end
    #doctype = doctype_results and doctype_results[0] or '' # I cannot figure out why this doesn't work
    if /netscape/ =~ doctype.downcase
      version = 'rss091n'
    else
      version = nil
    end
    data = data.sub(doctype_pattern, '')
    return version, data
  end

  def parse(*args); FeedParser.parse(*args); end
  def FeedParser.parse(furi, etag=nil, modified=nil, agent=USER_AGENT, referrer=nil, handlers=[], compatible=nil)
    # Parse a feed from a URL, file, stream or string
    $compatible = compatible unless compatible.nil? # Use the default compatibility if compatible is nil
    result = FeedParserDict.new
    result['feed'] = FeedParserDict.new
    result['entries'] = []
    if modified
      modified = Time.parse(modified).rfc2822 # FIXME this ignores all of our time parsing work. Does this work, or do we need to use our parsing stuff?
    end
    if XML_AVAILABLE 
      result['bozo'] = false
    end
    if handlers.class != Array # FIXME is this right?
      handlers = [handlers]
    end
    begin
      if URI::parse(furi).class == URI::Generic
        f = open(furi) # OpenURI doesn't behave well when passed HTTP options for a file.
      else
        f = open(furi, 
                      "If-None-Match" => etag.to_s, 
                      "If-Modified-Since" => modified.to_s, 
                      "User-Agent" => agent.to_s, 
                      "Referer" => referrer.to_s
                )
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
    if f.class == StringIO
      result['etag'] = f.meta['etag']
      result['modified'] = f.last_modified 
      result['url'] = f.base_uri.to_s
      result['status'] = f.status[0]
      result['headers'] = f.meta
    end

    # there are four encodings to keep track of:
    # - http_encoding is the encoding declared in the Content-Type HTTP header
    # - xml_encoding is the encoding declared in the <?xml declaration
    # - sniffed_encoding is the encoding sniffed from the first 4 bytes of the XML data
    # - result['encoding'] is the actual encoding, as per RFC 3023 and a variety of other conflicting specifications
    http_headers = result['headers'] || {} 
    result['encoding'], http_encoding, xml_encoding, sniffed_xml_encoding, acceptable_content_type =
      self._getCharacterEncoding(f,data)

    if not http_headers.empty? and not acceptable_content_type
      if http_headers.has_key?('content-type')
        bozo_message = "%s is not an XML media type" % http_headers['content-type']
      else
        bozo_message = 'no Content-type specified'
      end
      result['bozo'] = true
      result['bozo_exception'] = NonXMLContentType.new(bozo_message) # I get to care about this, cuz Mark says I should.
    end
    result['version'], data = self.stripDoctype(data)

    baseuri = http_headers['content-location'] || result['href'] # FIXME Hope this works.
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
    # if no luck and we ahve auto-detection library, try that
    #if known_encoding and chardet
    # FIXME untranslated
    #end
    #

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
    # if still no luck and we haven't tried iso-8859-2 yet, try that.
    if not known_encoding and not tried_encodings.include?'iso-8859-2'
      begin
        proposed_encoding = 'iso-8859-2'
        tried_encodings << proposed_encoding
        data = self.toUTF8(data, proposed_encoding)
        known_encoding = use_strict_parser = true
      rescue
      end
    end
    # if still no luck, give up
    if not known_encoding
      result['bozo'] = true
      result['bozo_exception'] = CharacterEncodingUnknown.new("documented declared as %s, but parsed as %s" % [result['encoding'], xml_encoding])
      result['encoding'] = proposed_encoding
    end
    use_strict_parser = true
    if use_strict_parser
      # initialize the SAX parser
      feedlistener = StrictFeedListener.new(baseuri, baselang, 'utf-8')
      saxparser = REXML::Parsers::SAX2Parser.new(REXML::Source.new(data))
      saxparser.listen(feedlistener)
      # FIXME are namespaces being checked?
      begin
        saxparser.parse
      rescue Exception => e
        if $debug
          $stderr << "xml parsing failed\n"
          $stderr << e.to_s+"\n" # Hrmph.
        end
        result['bozo'] = true
        result['bozo_exception'] = feedlistener.exc || e 
        use_strict_parser = false
      end
    end
    if not use_strict_parser
      #feedparser = LooseFeedParser.new(baseuri, baselang, known_encoding && 'utf-8' || '')
      #feedparser.feed(data)
      $stderr << "Using LooseFeed" if $debug
    end
    result['feed'] = feedlistener.feeddata
    result['entries'] = feedlistener.entries
    result['version'] = result['version'] || feedlistener.version
    result['namespaces'] = feedlistener.namespacesInUse
    return result
  end
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

class PprintSerializer < Serializer # FIXME ? use pp instead?
  def write(stream = $stdout)
    stream << @results['href'].to_s + "\n\n"
    pp(@results)
    stream << "\n"
  end
end


require 'optparse'
require 'ostruct'
options = OpenStruct.new
options.etag = options.modified = options.agent = options.referrer = nil
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
  results = FeedParser.parse(url, etag=options.etag, modified=options.modified, agent=options.agent, referrer=options.referrer)
  serializer.new(results).write($stdout)
end
end
