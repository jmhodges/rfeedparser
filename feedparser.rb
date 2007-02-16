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
require 'net/http'
require 'zlib'
# http://www.yoshidam.net/Ruby.html <-- XMLParser uses Expat
require 'xml/saxdriver' # FIXME this is an external dependency on Expat. On Ubuntu (and Debian), install libxml-parser-ruby1.8
XML_AVAILABLE = true
require 'rubygems'
gem 'builder' # FIXME no rubygems, no builder. is bad. to_xs
require 'builder'

def _xmlescape(text)  # FIXME untranslated, when builder does not exist, must use stupid definition
  # We also need the ability to define new "corrections"
  text.to_xs 
end
# base64 support for Atom feeds that contain embedded binary data
require 'base64'

# FIXME untranslated (?)
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

def unicode(data, from_encoding)
  # Takes a single string and converts it from the encoding in 
  # from_encoding to unicode.
  uconvert(data, from_encoding, 'unicode')
end

def uconvert(data, from_encoding, to_encoding = 'utf-8')
  Iconv.iconv(to_encoding, from_encoding, data)[0]
end

def unichr(i)
  # FIXME Would be better to wrap String.chr
  # How to wrap the ? method (i.e. ?c # => 99 )
  [i].pack('U*')
end

# This adds a nice scrub method to Hpricot, so we don't need a _HTMLSanitizer class
# http://underpantsgnome.com/2007/01/20/hpricot-scrub
# I have modified it to check for attributes that are only allowed if they are in a certain tag
module Hpricot
  class Elements
    def strip
      each { |x| x.strip }
    end

    def strip_attributes(safe=[])
      each { |x| x.strip_attributes(safe) }
    end

    def strip_style(atr, ok_props = [], ok_keywords = [])
      each { |x| x.strip_style(atr, ok_props, ok_keyword) }
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
      # disallow urls
      style = self['href'].sub(/url\s*\(\s*[^\s)]+?\s*\)\s*'/, ' ')
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

          did_not_break = true # This is a terrible, but working way to mimic Python's for/else

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

      self['href'] = clean.join(' ')
    end

    def strip_removes?
      # I'm sure there are others that shuould be ripped instead of stripped
      attributes && attributes['type'] =~ /script|css/
    end
  end

  class Doc
    alias :old_initialize :initialize
    attr_accessor :config

    def initialize(children, config={})
      old_initialize(children)


      setup_filter(config)
    end

    def setup_filter(config={})
      @acceptable_elements = ['a', 'abbr', 'acronym', 'address', 'area', 'b',
      'big', 'blockquote', 'br', 'button', 'caption', 'center', 'cite',
      'code', 'col', 'colgroup', 'dd', 'del', 'dfn', 'dir', 'div', 'dl', 'dt',
      'em', 'fieldset', 'font', 'form', 'h1', 'h2', 'h3', 'h4', 'h5', 'h6',
      'hr', 'i', 'img', 'input', 'ins', 'kbd', 'label', 'legend', 'li', 'map',
      'menu', 'ol', 'optgroup', 'option', 'p', 'pre', 'q', 's', 'samp',
      'select', 'small', 'span', 'strike', 'strong', 'sub', 'sup', 'table',
      'tbody', 'td', 'textarea', 'tfoot', 'th', 'thead', 'tr', 'tt', 'u',
      'ul', 'var']

      @acceptable_attributes = ['abbr', 'accept', 'accept-charset', 'accesskey',
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

      @unacceptable_elements_with_end_tag = ['script', 'applet']

      @acceptable_css_properties = ['azimuth', 'background-color',
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
      @acceptable_css_keywords = ['auto', 'aqua', 'black', 'block', 'blue',
      'bold', 'both', 'bottom', 'brown', 'center', 'collapse', 'dashed',
      'dotted', 'fuchsia', 'gray', 'green', '!important', 'italic', 'left',
      'lime', 'maroon', 'medium', 'none', 'navy', 'normal', 'nowrap', 'olive',
      'pointer', 'purple', 'red', 'right', 'solid', 'silver', 'teal', 'top',
      'transparent', 'underline', 'white', 'yellow']

      @mathml_elements = ['maction', 'math', 'merror', 'mfrac', 'mi',
      'mmultiscripts', 'mn', 'mo', 'mover', 'mpadded', 'mphantom',
      'mprescripts', 'mroot', 'mrow', 'mspace', 'msqrt', 'mstyle', 'msub',
      'msubsup', 'msup', 'mtable', 'mtd', 'mtext', 'mtr', 'munder',
      'munderover', 'none']

      @mathml_attributes = ['actiontype', 'align', 'columnalign', 'columnalign',
      'columnalign', 'columnlines', 'columnspacing', 'columnspan', 'depth',
      'display', 'displaystyle', 'equalcolumns', 'equalrows', 'fence',
      'fontstyle', 'fontweight', 'frame', 'height', 'linethickness', 'lspace',
      'mathbackground', 'mathcolor', 'mathvariant', 'mathvariant', 'maxsize',
      'minsize', 'other', 'rowalign', 'rowalign', 'rowalign', 'rowlines',
      'rowspacing', 'rowspan', 'rspace', 'scriptlevel', 'selection',
      'separator', 'stretchy', 'width', 'width', 'xlink:href', 'xlink:show',
      'xlink:type', 'xmlns', 'xmlns:xlink']

      # svgtiny - foreignObject + linearGradient + radialGradient + stop
      @svg_elements = ['a', 'animate', 'animateColor', 'animateMotion',
      'animateTransform', 'circle', 'defs', 'desc', 'ellipse', 'font-face',
      'font-face-name', 'font-face-src', 'g', 'glyph', 'hkern', 'image',
      'linearGradient', 'line', 'metadata', 'missing-glyph', 'mpath', 'path',
      'polygon', 'polyline', 'radialGradient', 'rect', 'set', 'stop', 'svg',
      'switch', 'text', 'title', 'use']

      # svgtiny + class + opacity + offset + xmlns + xmlns:xlink
      @svg_attributes = ['accent-height', 'accumulate', 'additive', 'alphabetic',
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

      @svg_attr_map = nil
      @svg_elem_map = nil

      @acceptable_svg_properties = [ 'fill', 'fill-opacity', 'fill-rule',
      'stroke', 'stroke-width', 'stroke-linecap', 'stroke-linejoin',
      'stroke-opacity']

      @acceptable_tag_specific_attributes = {}
      @mathml_elements.each{|e| @acceptable_tag_specific_attributes[e] = mathml_attributes }
      @svg_elements.each{|e| @acceptable_tag_specific_attributes[e] = svg_attributes }

      @acceptable_attribute_specific_values = {}
      if @config.nil? or @config['no_defaults']
        @config = { :nuke_tags => [],
          :allow_tags => [],
          :allow_attributes => [],
          :allow_tag_specific_attributes => [],
          :allow_css_style_properties => [],
          :allow_css_style_keywords => []
        }
      elsif @config['use_defaults']
        @config = { :nuke_tags => @unacceptable_elements_with_end_tag ,
          :allow_tags => @acceptable_elements,
          :allow_tag_specific_attributes => @allowed_tag_specific_attributes,
          :allow_css_style_properties => @allowed_css_style_properties,
          :allow_css_style_keywords => @allowed_css_style_keywords
        }
      end
      @config.merge!(config) 
    end

    def scrub(config={})
      if not (@nuke_tags.nil? or @nuke_tags.empty?)
        setup_filter(config)
      end
      @config[:nuke_tags].each { |tag| (self/tag).remove } # yes, that '/' should be there
      @config[:allow_tags].each { |tag|
        # This is the crux of my changes.  It just checks if the tag has 
        # certain attributes allowed through.  Note that this overrides any of the "generic" attributes they could have
        (self/tag).strip_attributes(@config[:allow_tag_specific_attributes][tag] || @config[:allow_attributes])
      }
      self/tag.strip_style(@config[:allow_css_style_properties], @config[:allow_css_style_keywords])
      children.reverse.each do |e|
        unless e.class == Hpricot::Text or config[:allow_tags].include?e.name or e.name == 'style'
          e.strip 
        end
      end
    end
  end
end


module FeedParser
@version = "0.1aleph_naught"
$debug = false
# FIXME OVER HERE! Hi. I'm still translating. Grep for "FIXME untranslated" to 
# figure out, roughly, what needs to be done.  I've tried to put it next to 
# anything having to do with any unimplemented sections. There are plent of 
# other FIXMEs however

# HTTP "User-Agent" header to send to servers when downloading feeds.
# If you are embedding feedparser in a larger application, you should
# change this to your application name and URL.
USER_AGENT = "UniversalFeedParser/%s +http://feedparser.org/" % @version__

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

  # We could include the [] rewrite in new using Hash.new's fancy pants block thing
  # but we'd still have to overwrite []= and such. 
  # I'm going to make it easy to turn lists of pairs into FeedParserDicts's though.
  def new( pairs = nil)
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
    elsif key == 'enclosures' #FIXME why does the orignial code use separate if-statements?
      # self['links'] is an array of links. 
      # these links are each a Hash.
      # we want to return an array of links that have a key 'rel' that has a value 'enclosure'.
      # however, we want to remove the 'rel' key (and, thus, its associated 
      # value, 'enclosure') from each of the links before returning the array
      # we just made. Of course, we want all of the Hashes to really be 
      # FeedParserDicts, but that will be taken care of in #[]= (one hopes).
      # The orignal code does a few backflips to do this. 
      # We do it here in one line and shift the weight of making 
      # FeedParserDicts to #[]= . 
      return self['links'].select{ |link| link['rel'] == 'enclosure' }.each{ |link| link.delete('rel') }
    elsif key == 'categories'
      return self['tags'].collect{|tag| [tag['scheme'],tag['term']]}
    end
    realkey = @@keymap[key] 
    if realkey and realkey.class == Array
      realkey.each{ |key| return self[key] if self.has_key?key }
    end
    # Note that the original key is preferred over the realkey we (might 
    # have) found in @@keymaps
    return super(key) || super(realkey)
  end

  def []=(key,value)
    if value.class == Hash
      value = FeedParserDict.new(value)
      # FIXME This may cause problems with entries.description since description is in @@keymaps.
    end
    if @@keymap.key?key
      key = @@keymap[key]
      if key.class == Array
        key = key[0]
      end
    end
    return super(key,value)
  end

  def fetch(key, default=nil) 
    # fetch is to Ruby's Hash as get is to Python's Dict
    if self.has_key(key)
      return self[key]
    else
      return default
    end
  end

  def get(key, default=nil)
    # in case people don't get the memo. i'm betting this will be removed soon
    self.fetch(key, default)
  end

  def setdefault(key, value) 
    # FIXME i'm not entirely sure of how useful this is, but I've written less than 1/4 of the code, so we'll see.
    if not has_key(key)
      self[key] = value
    end
    return self[key]
  end

  def method_missing(msym, *args)
    methodname = msym.to_s
    if methodname[-1] == '='
      return self[methodname[0..-2]] = args[0]
    elsif methodname[-1] != '!' and methodname[-1] != '?'
      return self[methodname]
    else
      raise NoMethodError, "whoops, we don't know about the attribute or method called `#{methodname}' for #{self}:#{self.class}"
    end
  end 
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

_urifixer = Regexp.new('^([A-Za-z][A-Za-z0-9+-.]*://)(/*)(.*?)')
def _urljoin(base, uri)
  uri = _urifixer.sub('\1\3', uri) 
  begin
    return URI.join(base, uri).to_s #FIXME untranslated, error handling from original needed?
  rescue BadURIError
    if URI.parse(base).relative?
      return URI::parse(uri).to_s
    end
  end
end


module FeedParserMixin
  attr_accessor :feeddata, :entries, :version, :namespacesInUse

  def startup(baseuri=nil, baselang=nil, encoding='utf-8')
    $stderr << "initializing FeedParser\n" if $debug
    unless @matchnamespaces.nil? or @matchnamespaces.empty?
      @namespaces.each do |k,v|
        @matchnamespaces[k.downcase] = v
      end
    end
    @namespaces = {'' => '',
                'http =>//backend.userland.com/rss' => '',
                'http =>//blogs.law.harvard.edu/tech/rss' => '',
                'http =>//purl.org/rss/1.0/' => '',
                'http =>//my.netscape.com/rdf/simple/0.9/' => '',
                'http =>//example.com/newformat#' => '',
                'http =>//example.com/necho' => '',
                'http =>//purl.org/echo/' => '',
                'uri/of/echo/namespace#' => '',
                 'http =>//purl.org/pie/' => '',
                  'http =>//purl.org/atom/ns#' => '',
                  'http =>//www.w3.org/2005/Atom' => '',
                  'http =>//purl.org/rss/1.0/modules/rss091#' => '',
                  'http =>//webns.net/mvcb/' =>                               'admin',
                  'http =>//purl.org/rss/1.0/modules/aggregation/' =>         'ag',
                  'http =>//purl.org/rss/1.0/modules/annotate/' =>            'annotate',
                  'http =>//media.tangent.org/rss/1.0/' =>                    'audio',
                  'http =>//backend.userland.com/blogChannelModule' =>        'blogChannel',
                  'http =>//web.resource.org/cc/' =>                          'cc',
                  'http =>//backend.userland.com/creativeCommonsRssModule' => 'creativeCommons',
                  'http =>//purl.org/rss/1.0/modules/company' =>              'co',
                  'http =>//purl.org/rss/1.0/modules/content/' =>             'content',
                  'http =>//my.theinfo.org/changed/1.0/rss/' =>               'cp',
                  'http =>//purl.org/dc/elements/1.1/' =>                     'dc',
                  'http =>//purl.org/dc/terms/' =>                            'dcterms',
                  'http =>//purl.org/rss/1.0/modules/email/' =>               'email',
                  'http =>//purl.org/rss/1.0/modules/event/' =>               'ev',
                  'http =>//rssnamespace.org/feedburner/ext/1.0' =>           'feedburner',
                  'http =>//freshmeat.net/rss/fm/' =>                         'fm',
                  'http =>//xmlns.com/foaf/0.1/' =>                           'foaf',
                  'http =>//www.w3.org/2003/01/geo/wgs84_pos#' =>             'geo',
                  'http =>//postneo.com/icbm/' =>                             'icbm',
                  'http =>//purl.org/rss/1.0/modules/image/' =>               'image',
                  'http =>//www.itunes.com/DTDs/PodCast-1.0.dtd' =>           'itunes',
                  'http =>//example.com/DTDs/PodCast-1.0.dtd' =>              'itunes',
                  'http =>//purl.org/rss/1.0/modules/link/' =>                'l',
                  'http =>//search.yahoo.com/mrss' =>                         'media',
                  'http =>//madskills.com/public/xml/rss/module/pingback/' => 'pingback',
                  'http =>//prismstandard.org/namespaces/1.2/basic/' =>       'prism',
                  'http =>//www.w3.org/1999/02/22-rdf-syntax-ns#' =>          'rdf',
                  'http =>//www.w3.org/2000/01/rdf-schema#' =>                'rdfs',
                  'http =>//purl.org/rss/1.0/modules/reference/' =>           'ref',
                  'http =>//purl.org/rss/1.0/modules/richequiv/' =>           'reqv',
                  'http =>//purl.org/rss/1.0/modules/search/' =>              'search',
                  'http =>//purl.org/rss/1.0/modules/slash/' =>               'slash',
                  'http =>//schemas.xmlsoap.org/soap/envelope/' =>            'soap',
                  'http =>//purl.org/rss/1.0/modules/servicestatus/' =>       'ss',
                  'http =>//hacks.benhammersley.com/rss/streaming/' =>        'str',
                  'http =>//purl.org/rss/1.0/modules/subscription/' =>        'sub',
                  'http =>//purl.org/rss/1.0/modules/syndication/' =>         'sy',
                  'http =>//purl.org/rss/1.0/modules/taxonomy/' =>            'taxo',
                  'http =>//purl.org/rss/1.0/modules/threading/' =>           'thr',
                  'http =>//purl.org/rss/1.0/modules/textinput/' =>           'ti',
                  'http =>//madskills.com/public/xml/rss/module/trackback/' =>'trackback',
                  'http =>//wellformedweb.org/commentAPI/' =>                 'wfw',
                  'http =>//purl.org/rss/1.0/modules/wiki/' =>                'wiki',
                  'http =>//www.w3.org/1999/xhtml' =>                         'xhtml',
                  'http =>//www.w3.org/XML/1998/namespace' =>                 'xml',
                  'http =>//www.w3.org/1999/xlink' =>                         'xlink',
                  'http =>//schemas.pocketsoap.com/rss/myDescModule/' =>      'szf'
    }
    @matchnamespaces = {}
    @can_be_relative_uri = ['link', 'id', 'wfw_comment', 'wfw_commentrss', 'docs', 'url', 'href', 'comments', 'license', 'icon', 'logo']
    @can_contain_relative_uris = ['content', 'title', 'summary', 'info', 'tagline', 'subtitle', 'copyright', 'rights', 'description']
    @can_contain_dangerous_markup = ['content', 'title', 'summary', 'info', 'tagline', 'subtitle', 'copyright', 'rights', 'description']
    @html_types = ['text/html', 'application/xhtml+xml']
    @feeddata = FeedParserDict.new # feed-level data
    @encoding = encoding # character encoding
    @entries = [] # list of entry-level data
    @version = '' # feed type/version see SUPPORTED_VERSIOSN
    @namespacesinUse = {} # hash of namespaces defined by the feed

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
    @_summaryKey = nil
    @namespacemap = {}
    @elementstack = []
    @basestack = []
    @langstack = []
    @baseuri = baseuri or ''
    @lang = baselang or nil
    if baselang 
      @feeddata['language'] = baselang.gsub('_','-')
    end
    $stderr << "Leaving startup\n" if $debug # My addition
  end

  def unknown_starttag(tag, attrs)
    $stderr << 'start %s with %s\n' % [tag, attrs] if $debug
    # normalize attrs
    attrsD = {}
    attrs.each do |l| 
      l[0].downcase! # Downcase all keys
      if ['rel','type'].include?l[0]
        l[1].downcase!   # Downcase the value if the key is 'rel' or 'type'
      end
      attrsD[l[0]] = l[1]
    end

    # track xml:base and xml:lang
    baseuri = attrsD.fetch('xml:base', attrsD.fetch('base')) || @baseuri 
    lang = attrsD.fetch('xml:lang', attrsD.fetch('lang')) 
    if lang == '' # This next bit of code is right? Wtf?
      # xml:lang could be explicitly set to '', we need to capture that
      lang = nil
    elsif lang.nil?
      # if no xml:lang is specified, use parent lang
      lang = @lang
    end
    if lang #Seriously, this cannot be correct
      if ['feed', 'rss', 'rdf:RDF'].include?tag
        @feeddata['language'] = lang.replace('_','-')
      end
    end
    @lang = lang
    @basestack << @baseuri 
    @langstack << lang

    # track namespaces
    attrs.each do |l|
      prefix, uri = l 
      if /^xmlns:/ =~ prefix # prefix begins with xmlns:
        trackNamespace(prefix[6..-1], uri)
      elsif prefix == 'xmlns':
        trackNamespace(nil, uri)
      end
    end

    # track inline content
    if @incontent != 0 and @contentparams.has_key?('type') and not ( /xml$/ =~ @contentparams.fetch('type', 'xml') )
      # element declared itself as escaped markup, but isn't really
      @contentparams['type'] = 'application/xhtml+xml'
    end
    if @incontent != 0 and @contentparams.fetch('type') == 'application/xhtml+xml'
      # Note: probably shouldn't simply recreate localname here, but
      # our namespace handling isn't actually 100% correct in cases where
      # the feed redefines the default namespace (which is actually
      # the usual case for inline content, thanks Sam), so here we
      # cheat and just reconstruct the element based on localname
      # because that compensates for the bugs in our namespace handling.
      # This will horribly munge inline content with non-empty qnames,
      # but nobody actually does that, so I'm not fixing it.
      if not tag.grep(/:/).empty?
        prefix, tag = tag.split(':',2)
        namespace = @namespacesInUse.fetch(prefix,'')
        if tag == 'math' and namespace == 'http://www.w3.org/1998/Math/MathML':
          attrs << ['xmlns', namespace] 
        end
        if tag == 'svg' and namespace == 'http://www.w3.org/2000/svg':
          attrs << ['xmlns',namespace]
        end
        return handle_data('<%s%s>' % [tag, strattrs(attrs), escape=false]) 
      end
    end

    # match namespaces
    if not tag.grep(/:/).empty?
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
      return send('_start_'+prefix+suffix, attrsD)
    rescue NoMethodError
      return push(prefix + suffix, 1)
    end  
  end # End unknown_starttag

  def unknown_endtag(tag)
    $stderr < 'end %s\n' % tag if $debug
    # match namespaces
    if not tag.grep(/:/).empty?
      prefix, suffix = tag.split(':',2)
    else
      prefix, suffix = '', tag
    end
    prefix = @namespacemap.fetch(prefix,prefix)
    if prefix and not prefix.empty?
      prefix = prefix + '_'
    end

    # call special handler (if defined) or default handler
    begin 
      send('_end_' + prefix + suffix) # Yes, Ruby, I love you. Be mine.
    rescue NoMethodError
      pop(prefix + suffix) 
    end

    # track inline content 
    if @incontent != 0 and @contentparams.has_key?('type') and /xml$/ =~ @contentparams.fetch('type','xml')
      # element declared itself as escaped markup, but it isn't really
      @contentparams['type'] = 'applicatoin/xhtml+xml'
    end
    if @incontent != 0 and @contentparams.fetch('type') == 'application/xhtml+xml'
      tag = tag.split(/:/)[-1]
      handle_data('</%s>' % tag, escape=false)
    end

    # track xml:base and xml:lang going out of scope
    if @basestack and not @basestack.empty?
      @basestack.pop
      if @basestack and @basestack.empty? and @basestack[-1]
        @baseuri = @basestack[-1]
      end
    end
    if @langstack and not @langstack.empty?
      @langstack.pop
      if @langstack and not @langstack.empty? # and (@langstack[-1] is not nil or ''): # Remnants?
        @lang = @langstack[-1]
      end
    end
  end # End unknown_endtag

  def handle_charref(ref)
    # called for each character reference, e.g. for '&#160;', ref will be 160
    if @elementstack.nil? or @elementstack.empty?
      return
    end
    ref.downcase!
    if ['34', '38', '39', '60', '62', 'x22', 'x26', 'x27', 'x3c', 'x3e'].include?ref
      text = '&#%s;' % ref
    else
      if ref[0] == 'x'
        c = ref[1..-1].to_i(16)
      else
        c = ref.to_i
      end
      text = unichr(c) # FIXME untranslated, see the unichr definition.
    end
    @elementstack[-1][2] << text
  end # End handle_charref

  def handle_entityref(ref)
    # called for each entity reference, e.g. for '&copy;', ref will be 'copy'
    if @elementstack.nil? or @elementstack.empty?
      return
    end
    $stderr << 'entering handle_entityref with %s\n' % ref if $debug
    if ['lt', 'gt', 'quot', 'amp', 'apos'].include? ref
      text = "$%s;" % ref
    elsif @entities.has_key? ref
      text = @entities[ref]
      if /^&#/ =~ text and /;$/ =~ text
        return handle_entityref(text)
      end
    else
      ref.decode_entities # FIXME this requires htmlentities/string
    end
    @elementstack[-1][2] << text # FIXME this is probably not going to work as intended
    # In fact, anywhere there is an "append" in the original code, probably 
    # needs to be run over with a fine-toothed comb
  end 

  def handle_data(text, escape=true)
    # called for each block of plain text, i.e. outside of any tag and
    # not containing any character or entity references
    if @elementstack.nil? or @elementstack.empty?
      return
    end 
    if escape and @contentparams.fetch('type') == 'application/xhtml+xml'
      text = text.to_xs # From Builder
    end
    @elementstack[-1][2] << text
  end

  def handle_comment(text)
    # called for each processing instruction, e.g. <!-- insert message here -->
  end

  def handle_pi(text)
    # called for each processing instruction, e.g. <?instruction>
  end

  def handle_decl(text)
  end

  def parse_declaration(i)
    # override internal declaration handler to handle CDATA blocks
    $stderr << 'entering parse_declaration\n' if $debug
    if @rawdata[i..i+9] == '<![CDATA['
      k = k.nil? ? @rawdata.size : @rawdata.index(']]>', i) # using a size call just in case :(  
      handle_data(@rawdata[i+9..k].to_xs) # FIXME test the to_xs call.
      return k+3
    else
      k = @rawdata.index('>', i)
      return k+1
    end
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
    loweruri = uri.downcase
    if [prefix, loweruri] == [nil, 'http://my.netscape.com/rdf/simple/0.9'] and (not @version or @version.empty?)
      @version = 'rss090'
    end
    if loweruri == 'http://purl.org/rss/1.0/' and (not @version or @version.empty?)
      @version = 'rss10'
    end
    if loweruri == 'http://www.w3.org/2005/atom' and (not @version or @version.empty?)
      @version = 'atom10'
    end
    if loweruri.grep(/'backend.userland.com\/rss'/).empty?:
      # match any backend.userland.com namespace
      uri = 'http://backend.userland.com/rss'
      loweruri = uri
    end
    if @matchnamespaces.has_key?loweruri
      @namespacemap[prefix] = @matchnamespaces[loweruri]
      @namespacesInUse[@matchnamespaces[loweruri]] = uri
    else
      @namespacesInUse[prefix || ''] = uri
    end
  end 

  def resolveURI(uri)
    return _urljoin(@baseuri || '', uri) # FIXME untranslated (?)
  end

  def decodeEntities(element, data)
    return data
  end

  def strattrs(attrs)
    # FIXME untranslated, to_xs does not take extra args that we need
    attrs.map{ |pair| '%s="%s"' % [pair[0],pair[1].to_xs]}.join(' ') 
  end

  def push(element, expectingText)
    @elementstack << [element, expectingText, []]
  end

  def pop(element, stripWhitespace=true)
    return if @elementstack.nil? or @elementstack.empty?
    return if @elementstack[-1][0] != element

    element, expectingText, pieces = @elementstack.pop()

    if @version == 'atom10' and @contentparams.fetch('type','text') == 'application/xhtml+xml'
      # remove enclosing child element, but only if it is a <div> and
      # only if all the remaining content is nested underneath it.
      # This means that the divs would be retained in the following:
      #    <div>foo</div><div>bar</div>
      while pieces and not pieces.empty? and pieces.length > 1 and not (pieces.nil? and pieces[-1].strip.empty?)
        pieces.delete_at(-1)
      end
    while pieces and not pieces.empty? and pieces.length > 1 and not (pieces.nil? and pieces[-1].strip.empty?)
      pieces.delete_at(0)
    end
    if pieces and not pieces.empty? and (pieces[0] == '<div>' or /^<div/ =~ pieces[0] and pieces[-1] == '</div>')
      depth = 0
      did_not_break = true
      pieces[0..-2].each do |piece|
        if /^<\// =~ piece
          depth -= 1
          if depth == 0
            did_not_break = false
            break
          end
        elsif /^</ =~ piece and not /\/>/ =~ piece
          depth += 1
        end
      end

      if did_not_break
        pieces = pieces[1..-2]
      end
    end
    end

    output = pieces.join
    if stripWhitespace
      output.strip!
    end

    return output unless expectingText

    # decode base64 content
    if @contentparams['base64'] # as near as I can tell, this is a perfect translation
      # FIXME untranslated, the error checking is not included. is it even needed?
      output = Base64.decode64(output) 
    end

    # resolve relative URIs
    if @can_be_relative_uri.include?element and not (output.nil? and output.empty?)
      output = resolveURI(output)
    end

    # decode entities within embedded markup
    unless @contentparams['base64']
      output = decodeEntities(element, output)
    end

    if lookslikehtml(output)
      @contentparams['type']='text/html'
    end

    # remove temporary cruft from contentparams
    @contentparams.delete('mode')
    @contentparams.delete('base64')

    # FIXME small refactoring could put all of these if is_htmlish stuff under one check
    is_htmlish = @html_types.include?mapContentType(@contentparams.fetch('type', 'text/html'))
    # resolve relative URIs within embedded markup
    if is_htmlish
      if @can_contain_relative_uris.include? element
        output = _resolveRelativeURIs(output, @baseuri, @encoding, @contentparams.fetch('type', 'text/html'))
      end
    end

    # parse microformats
    # (must do this before sanitizing because some microformats
    # rely on elements that we sanitize)
    if is_htmlish and ['content','description','summary'].include?element
      mfresults = _parseMicroformats(output, @baseuri, @encoding)
      if mfresults
        mfresults.fetch('tags', []).each { |tag| _addTag(tag['term'], tag['scheme'], tag['label']) }
        mfresults.fetch('enclosures', []).each { |enclosure| _start_enclosure(enclosure) }
        mfresults.fetch('xfn',[]).each { |xfn| _addXFN(xfn['relationships'], xfn['href'], xfn['name']) }
        if mfresults['vcard']
          _getContext()['vcard'] = vcard # FIXME need to see if _getContext can be better done
        end
      end
    end

    # sanitize embedded markup
    if is_htmlish
      if @can_contain_dangerous_markup
        # FIXME untranslated, output is probably not going to match up with
        # the u'' down below all the time, though it should some of the time. fix this.
        output = _sanitizeHTML(output, @encoding, @contentparams.fetch('type', 'text/html'))
      end
    end

    if @encoding and not @encoding.empty? # and output.class != u('').class # FIXME something like this and statement does need to be there
      output = unicode(output, @encoding) # FIXME no error checks for iconv module
    end

    # address common error where people take data that is already in 
    # utf-8, presume that it is iso-8859-1, and re-encode it.
    #
    if @encoding == 'utf-8' and output.class == ''.class 
      output = unicode(output, 'utf-8') # FIXME this is probably wrong
    end
    #

    # map win-1252 extensions to the proper code points
    if output.class == ''.class # FIXME yeah, this doesn't work
      output = output.collect { |c| _cp1252[c] || c }
    end

    # categories/tags/keywords/whatever are handled in _end_category
    if element == 'category'
      return output
    end

    # store output in appropriate places(s)
    if @inentry and not @insource
      if element == 'content'
        @entries[-1].setdefault(element, [])
        contentparams = @contentparams.dup # FIXME untranslated, there is little likelihood that this works
        contentparams['value'] = output
        @entries[-1][element] << contentparams
      elsif element == 'link'
        @entries[-1][element] = output
        unless output.nil? and output.empty?
          @entries[-1]['links'][-1]['href'] = output
        end
      else
        if element == 'description'
          element = 'summary'
        end
        @entries[-1][element] = output
        if @incontent != 0
          contentparams = @contentparams.dup # FIXME untranslated, again, not going to work
          contentparams['value'] = output
          entries[-1][element + '_detail'] = contentparams
        end
      end
    elsif @infeed or @insource
      context = _getContext
      if element == 'description'
        element = 'subtitle'
      end
      context[element] = output
      if element == 'link'
        context['links'][-1]['href'] = output
      elsif @incontent != 0
        contentparams = @contentparams.dup # FIXME untranslated, deepcopy/dup problem again
        contentparams['value'] = output
        context[element + '_detail'] = contentparams
      end
    end
    return output
  end

  def pushContent(tag, attrsD, defaultContentType, expectingText)
    @incontent += 1
    @lang.replace!('_','-') if @lang
    @contentparams = FeedParserDict.new({'type' => mapContentType(attrsD.fetch('type', defaultContentType)),
                'language' => lang,
                'base' => @baseuri })# One day, I will learn to write braces with proper indentations
    @contentparams['base64'] = _isBase64(attrsD, contentparams)
    push(tag, expectingText)
  end

  def popContent(tag)
    value = pop(tag)
    @incontent -= 1
    @contentparams.clear()
    return value
  end

  # a number of elements in a number of RSS variants are nominally plain
  # text, but this is routinely ignored.  This is an attempt to detect
  # the most common cases.  As false positives often result in silent
  # data loss, this function errs on the conservative side.
  def lookslikehtml(str)
    return if /^atom/ =~ @version
    return if @contentparams.fetch('type','text/html') != 'text/plain'

    # must have a close tag or a entity reference to qualify
    return if not (/<\/(\w+)>/ =~ str) or /&#?\w+;/ =~ str 

    # all tags must be in restricted subset of valid HTML tags
    if str.scan(/<\/?(\w+)/).any?{ |t| not _HTMLSanitizer.acceptable_elements.include? t.downcase }
      return
    end

    return true # FIXME may need to be 1
  end

  def _mapToStandardPrefix(name)
    colonpos = name.index(':')
    if colonpos.nil?
      prefix = name[0..colonpos-1]
      suffix = name[colonpos..-1]
      prefix = @namespacemap.fetch(prefix, prefix)
      name = prefix + ':' + suffix
    end
    return name
  end

  def _getAttribute(attrsD, name) # FIXME this even necessary?
    return attrsD[_mapToStandardPrefix(name)]
  end

  def _isBase64(attrsD, contentparams) # FIXME may need to return 1 or 0
    if attrsD['mode'] == 'base64'      # FIXME why is contentparams passed if it isn't used?
      return true
    elsif /(^text\/)|(\+xml$)|(\/xml$)/ =~ @contentparams
      return false
    end
    return true
  end

  def _itsAnHrefDamnIt(attrsD)
    href, k = attrsD['url'] || attrsD['uri'] || attrsD['href']
    if href
      attrsD.delete('url')
      attrsD.delete('uri')
      attrsD['href'] = href
    end
    return attrsD
  end

  def _save(key, value)
    context = _getContext
    context.setdefault(key, value)
  end

  def _start_rss(attrsD)
    versionmap = { '0.91' => 'rss091u',
                     '0.92' => 'rss092',
                     '0.93' => 'rss093',
                     '0.94' => 'rss094'
    }
    if @version.nil? or @version.empty?
      attr_version = attrsD['version']
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
    _cdf_common(attrsD)
  end
  alias :_start_feedinfo :_start_channel

  def _cdf_common(attrsD)
    if attrsD.has_key('lastmod')
      _start_modified({})
      @elementstack[-1][-1] = attrsD['lastmod']
      _end_modified
    elsif attrsD.had_key('href')
      _start_link({})
      @elementstack[-1][-1] = attrsD['href']
      _end_link
    end
  end

  def _start_feed(attrsD)
    @infeed = true
    versionmap = {  '0.1' => 'atom01', 
                      '0.2' => 'atom02', 
                      '0.3' => 'atom03' 
    }
    if @version.nil? or @version.empty?
      attr_version = attrsD['version']
      version = versionmap[attr_version]
      if version and not version.empty?
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
    context = _getContext
    context.setdefault('image', FeedParserDict.new)
    @inimage = true
    push('image', false)
  end

  def _end_image
    pop('image')
    @inimage = false
  end

  def _start_textinput(attrsD) # These can probably be refactored away with a "_start_simple_tag' in missing_method
    # or with some finite state machine work
    context = _getContext
    context.setdefault('textinput', FeedParserDict.new)
    @intextinput = false
    push('textinput', true)
  end
  alias :_start_textInput :_start_textinput

  def _end_textinput
    pop('textinput')
    @intextinput = false
  end
  alias :_end_textInput :_end_textinput

  def _start_author(attrsD)
    @inauthor = true
    push('author', true)
  end
  alias :_start_managingeditor :_start_author
  alias :_start_dc_author :_start_author
  alias :_start_dc_creator :_start_author
  alias :_start_itunes_author :_start_author

  def _end_author
    pop('author')
    @inauthor = false
    _sync_author_detail
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
    context = _getContext()
    context.setdefault('contributors', [])
    context['contributors'] << FeedParserDict.new
    push('contributor', false)
  end

  def _end_contributor
    pop('contributor')
    @incontributor = false
  end

  def _start_dc_contributor(attrsD)
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
      context = _getContext()
      context['name'] = value
    end
  end
  alias :_end_itunes_name :_end_name

  def _start_width(attrsD)
    push('width', false)
  end

  def _end_width
    value = pop('width')
    begin
      value = value.to_i
    rescue
      value = 0
    end
    if @inimage
      context = _getContext()
      context['width'] = value
    end
  end

  def _start_height(attrsD)
    push('height', false)
  end

  def _end_height
    value = pop('height')
    begin
      value = value.to_i
    rescue
      value = 0
    end
    if @inimage
      context = _getContext()
      context['height'] = value
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

  def _getContext
    if @insource
      context = @sourcedata
    elsif @inimage
      context = @feeddata['image']
    elsif @intextinput
      context = @feeddata['textinput']
    elsif @inentry
      context = @entries[-1]
    else
      context = @feeddata
    end
    return context
  end

  def _save_author(key, value, prefix='author')
    context = _getContext
    context.setdefault(prefix + '_detail', FeedParserDict.new)
    context[prefix + '_detail'][key] = value
    _sync_author_detail
  end

  def _save_contributor(key, value)
    context = _getContext()
    context.setdefault('contributors', [FeedParserDict.new])
    context['contributors'][-1][key] = value
  end

  def _sync_author_detail(key='author')
    context = _getContext()
    detail = context['%s_detail' % key]
    if detail and not detail.empty?
      name = detail['name']
      email = detail['email']
      if name and email and not (name.empty? or email.empty?)
        context[key] = '%s (%s)' % [name, email]
      elsif name and not name.empty?
        context[key] = name
      elsif email and not name.empty?
        context[key] = email
      end
    else
      author, email = context[key], nil
      return unless author and not author.empty?
      emailmatch = author.match(/(([a-zA-Z0-9\_\-\.\+]+)@((\[[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.)|(([a-zA-Z0-9\-]+\.)+))([a-zA-Z]{2,4}|[0-9]{1,3})(\]?))(\?subject=\S+)?(([a-zA-Z0-9\_\-\.\+]+)@((\[[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.)|(([a-zA-Z0-9\-]+\.)+))([a-zA-Z]{2,4}|[0-9]{1,3})(\]?))(\?subject=\S+)?/)
      if emailmatch
        email = emailmatch[0]
        # this is better than the original, i hope.
        author.gsub!(/(#{email})|(\(\))|(<>)|(&lt;&gt;)/)
        author.strip!
        if author and author[0] == ')'
          author = author[1..-1]
        end
        if author and author[-1] == ')'
          author = author[0..-2]
        end
        author.strip!
      end
      if (author and not author.empty?) or email # email will never be empty (#match method)
        context.setdefault('%s_detail' % key, FeedParserDict.new)
      end
      if author and not author.empty?
        context['%s_detail' % key]['name'] = author
      end
      if email
        context['%s_detail' % key]['email'] = email
      end
    end
  end 

  def _start_subtitle(attrsD)
    pushContent('subtitle', attrsD, 'text/plain', true) # replace true with 1?
  end
  alias :_start_tagline :_start_subtitle
  alias :_start_itunes_subtitle :_start_subtitle

  def _end_subtitle
    popContent('subtitle')
  end
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
    @entries.append(FeedParserDict.new)
    push('item', false)
    @inentry = true
    @guidislink = false
    id = _getAttribute(attrsD, 'rdf:about') # FIXME there is a better way to do this
    if id and not id.empty?
      context = _getContext()
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
    value = pop('published')
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
    value = _getAttribute(attrsD, 'rdf:resource')
    if value:
      @elementstack[-1][2] << value
    end
    pop('license')
  end

  def _start_creativecommons_license(attrsD)
    push('license', true)
  end

  def _end_creativecommons_license
    pop('license')
  end

  def _addXFN(relationships, href, name)
    context = _getContext()
    xfn = context.setdefault('xfn', [])
    value = FeedParserDict.new({'relationships' => relationships, 'href' => href, 'name' => name})
    if not xfn.include? value
      xfn << value
    end
  end

  def _addTag(term, scheme, label)
    context = _getContext()
    tags = context.setdefault('tags', [])
    return if (term.nil? or term.empty?) and (scheme.nil? or scheme.empty?) and (label.nil? or label.empty?)
    value = FeedParserDict.new({'term' => term, 'scheme' => scheme, 'label' => label})
    if not tags.include? value
      tags << value
    end
  end

  def _start_category(attrsD)
    $stderr << 'entering _start_category with %s\n' % attrsD.to_s if $debug
    term = attrsD['term']
    scheme = attrsD.fetch('scheme', attrsD.fetch('domain'))
    label = attrsD['label']
    _addTag(term, scheme, label)
    push('category', true)
  end
  alias :_start_dc_subject :_start_category
  alias :_start_keywords :_start_category

  def _end_itunes_keywords
    pop('itunes_keywords').split.each do |term|
      _addTag(term, 'http://www.itunes.com/', nil)
    end
  end

  def _start_itunes_category(attrsD)
    _addTag(attrsD['text'], 'http://www.itunes.com/', nil)
    push('category', true)
  end

  def _end_category
    value = pop('category')
    return if value.nil? or value.empty?
    context = _getContext()
    tags = context['tags']
    term = tag[-1]['term']
    if value and !value.empty? and tags.length > 0 and not (term.nil? or term.empty?)
      tags[-1]['term'] = value
    else
      _addTag(value, nil, nil)
    end
  end
  alias :_end_dc_subject :_end_category
  alias :_end_keywords :_end_category
  alias :_end_itunes_category :_end_category

  def _start_cloud(attrsD)
    _getContext()['cloud'] = FeedParserDict.new(attrsD)
  end

  def _start_link(attrsD)
    attrsD.setdefault('rel', 'alternate')
    if attrsD['rel'] == 'self'
      attrsD.setdefault('type', 'application/atom+xml')
    else
      attrsD.setdefault('type', 'text/html')
    end
    context = _getContext()
    attrsD = _itsAnHrefDamnIt(attrsD) # I'm a big fan of this method. Excellent, Mark.
    if attrsD.has_key('href'):
      attrsD['href'] = resolveURI(attrsD['href'])
      if attrsD.get('rel')=='enclosure' and (context['id'].nil? or context['id'].empty?) 
        context['id'] = attrsD.get('href')
      end
    end
    expectingText = @infeed || @inentry || @insource
    context.setdefault('links', [])
    context['links'] << FeedParserDict.new(attrsD)
    if attrsD.has_key('href'):
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
    context = _getContext()
  end
  alias :_end_producturl :_end_link

  def _start_guid(attrsD)
    @guidislink = (attrsD.fetch('ispermalink', 'true') == 'true')
    push('id', true)
  end

  def _end_guid
    value = pop('id')
    _save('guidislink', (guidislink and not _getContext().has_key?('link')))
    if @guidislink and not @guidislink.empty?
      # guid acts as link, but only if 'ispermalink' is not present or is 'true',
      # and only if the item doesn't already have a link element
      _save('link', value)
    end
  end

  def _start_title(attrsD)
    return unknown_starttag('title', attrsD) if @incontent
    pushContent('title', attrsD, 'text/plain', @infeed || @inentry || @insource)
  end
  alias :_start_dc_title :_start_title
  alias :_start_media_title :_start_title

  def _end_title
    value = popContent('title')
    return if value.nil? or value.empty?
    context = _getContext() # FIXME why is this being called if we do nothing with it? must reread _getContext
  end
  alias :_end_dc_title :_end_title
  alias :_end_media_title :_end_title

  def _start_description(attrsD)
    context = _getContext()
    if context.has_key('summary')
      @_summaryKey = 'content'
      _start_content(attrsD)
    else
      pushContent('description', attrsD, 'text/html', @infeed || @inentry || @insource)
    end
  end
  alias :_start_dc_description :_start_description

  def _start_abstract(attrsD)
    pushContent('description', attrsD, 'text/plain', @infeed || @inentry || @insource)
  end

  def _end_description
    if @_summaryKey == 'content'
      _end_content()
    else
      value = popContent('description')
    end
    @_summaryKey = nil
  end
  alias :_end_abstract :_end_description
  alias :_end_dc_description :_end_description

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
      attrsD = _itsAnHrefDamnIt(attrsD)
      if attrsD.has_key?('href')
        attrsD['href'] = resolveURI(attrsD['href'])
      end
    end
    _getContext()['generator_detail'] = FeedParserDict.new(attrsD)
    push('generator', true)
  end

  def _end_generator
    value = pop('generator')
    context = _getContext()
    if context.has_key('generator_detail')
      context['generator_detail']['name'] = value
    end
  end

  def _start_admin_generatoragent(attrsD)
    push('generator', true)
    value = _getAttribute(attrsD, 'rdf:resource')
    if value and not value.empty?
      @elementstack[-1][2] << value
    end
    pop('generator')
    _getContext()['generator_detail'] = FeedParserDict.new({'href' => value})
  end

  def _start_admin_errorreportsto(attrsD)
    push('errorreportsto', true)
    value = _getAttribute(attrsD, 'rdf:resource')
    if value and not value.empty?
      elementstack[-1][2] << value
    end
    pop('errorreportsto')
  end

  def _start_summary(attrsD)
    context = _getContext()
    if context.has_key?('summary')
      @_summaryKey = 'content'
      _start_content(attrsD)
    else
      @_summaryKey = 'summary'
      pushContent(@_summaryKey, attrsD, 'text/plain', true)
    end
  end
  alias :_start_itunes_summary :_start_summary

  def _end_summary
    if @_summaryKey == 'content'
      _end_content()
    else
      popContent(@_summaryKey || 'summary')
    end
    @_summaryKey = nil
  end
  alias :_end_itunes_summary :_end_summary

  def _start_enclosure(attrsD)
    attrsD = _itsAnHrefDamnIt(attrsD)
    context = _getContext
    attrsD['rel'] = 'enclosure'
    context.setdefault('links', []) << FeedParserDict.new(attrsD) # FIXME check the return of setdefault
    href = attrsD['href']
    if href and not href.empty? and (context['id'] or context['id'].empty?):
      context['id'] = href
    end
  end

  def _start_source(attrsD)
    @insource = true
  end

  def _end_source
    @insource = false
    _getContext()['source'] = @sourcedata.dup # FIXME deepcopy again
    @sourcedata.clear
  end

  def _start_content(attrsD)
    pushContent('content', attrsD, 'text/plain', true)
    src = attrsD['src']
    if src and not src.empty?
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
    copyToDescription = (@html_types << 'text/plain').include? mapContentType(@contentparams['type'])
    value = popContent('content')
    if copyToDescription:
      _save('description', value)
    end
  end
  alias :_end_body :_end_content
  alias :_end_xhtml_body :_end_content
  alias :_end_content_encoded :_end_content
  alias :_end_fullitem :_end_content
  alias :_end_prodlink :_end_content

  def _start_itunes_image(attrsD)
    push('itunes_image', false)
    _getContext()['image'] = FeedParserDict.new({'href' => attrsD['href']})
  end
  alias :_start_itunes_link :_start_itunes_image

  def _end_itunes_block
    value = pop('itunes_block', false)
    _getContext()['itunes_block'] = (value == 'yes') and 1 or 0 # What an interesting hack.
  end

  def _end_itunes_explicit
    value = pop('itunes_explicit', false)
    _getContext()['itunes_explicit'] = (value == 'yes') and 1 or 0
  end
end # End FeedParserMixin

if XML_AVAILABLE
  class StrictFeedParser < XML::SAX::HandlerBase
    
    include FeedParserMixin
    attr_accessor :bozo, :exc
    def initialize(baseuri, baselang, encoding)
      $stderr << "trying StrictFeedParser\n" if $debug
      startup(baseuri, baselang, encoding) # FIXME need to grok mixins, if i name #startup #initialize will this happen for me?
      @bozo = false
      @exc = nil
      $stderr << "Leaving initialize\n" if $debug # My addition
    end
    
    def setDocumentLocator(loc)
      @locator = loc
    end
    def getPos
      [@locator.getSystemId, @locator.getLineNumber]
    end
    def startNamespaceDecl(prefix, uri) # Equivalent to startPrefixMapping in Python's SAX
      $stderr << "startNamespaceDecl: prefix => #{prefix}, uri => #{uri}" if $debug
      trackNamespace(prefix, uri)
    end

    def startElement(name, attrs) # Equivalent to startElementNS in Python's SAX
      $stderr << "name is class: #{name.class} and name is #{name} and attrs is #{attrs}" if $debug # FIXME remove if not needed
      namespace, localname = name.split(';',2)
      lowernamespace = (namespace.to_s || '').downcase
      if /backend\.userland\.com\/rss/ =~ lowernamespace
        # match any backend.userland.com namespace
        namespace = 'http://backend.userland.com/rss'
        lowernamespace = namespace
      end
      # FIXME If you look at feedparser.py, you'll notice that we are
      # supposed to take in a qname here.  That doesn't happen with the
      # expat parser we're using. Tell me how to fix this, would ya?
      givenprefix = nil
      prefix = matchnamespaces[lowernamespace] || givenprefix

      attrsD = {}
      if localname == 'math' and namespace == 'http://www.w3.org/1998/Math/MathML'
        attrsD['xmlns'] = namespace
      end
      if localname == 'svg' and namespace == 'http://www.w3.org/2000/svg'
        attrsD['xmlns'] = namespace
      end

      if prefix and not prefix.empty?
        localname = prefox.downcase + ':' + localname
      elsif namespace and not namespace.empty? #Expat (ah, suck).
        @namespacesInUse.to_a.each do |l| 
          name, value = l
          if name and not name.empty? and value == namespace
            localname = name + ':' + localname
            break
          end
        end
      end
      $stderr << "startElement: qname = %s, namespace = %s, givenprefix = %s, prefix = %s, attrs = %s, localname = %s\n" % [nil, givenprefix, prefix, attrs.to_a, localname]

      attrs.to_a.flatten.each_slice(3) do |namespace, attrlocalname, attrvalue|
        lowernamespace = (namespace || '').downcase
        prefix = matchnamespaces[lowernamespace] || ''
        if not prefix.empty?
          attrlocalname = prefix + ':' + attrlocalname
        end
        attrsD[attrlocalname.downcase] = attrvalue
      end
      unknown_starttag(localname, attrsD.to_a)
    end
    def characters(text)
      handle_data(text)
    end

    def endElement(name)
      namespace, localname = name.split(';',2)
      lowernamespace = (namespace || '').downcase
      givenprefix = ''

      prefix = matchnamespaces[lowernamespace] || givenprefix
      if prefix and not prefix.empty? 
        localname = prefix + ':' + localname
      elsif namespace and not namespace.empty? #Expat 
        # yeah, I'm keeping the if statements as similar as possible
        @namespacesInUse.to_a.each do |l| 
          name, value = l
          if name and not name.empty? and value == namespace
            localname = name + ':' + localname
            break
          end
        end
      end
      localname.downcase! # No default unicode shenanigans, I believe
      unknown_endtag(localname)
    end

    def error(exc)
      @bozo = 1
      @exc = exc
    end

    def fatalError(exc)
      error(exc)
      raise exc
    end
  end
end

def _resolveRelativeURIs(htmlSource, baseURI, encoding, type)
  $stderr << 'entering _resolveRelativeURIs\n' if $debug # FIXME write a decent logger
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

def sanitizeHTML(html)
  # FIXME Does not use Tidy, yet.
  h = Hpricot.scrub(html)
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
  sniffed_xml_encoding = ''
  xml_encoding = ''
  true_encoding = ''
  begin 
    http_headers = feed.meta
    http_content_type = feed.content_type
    http_encoding = feed.charset
  rescue NoMethodError
    http_headers = {}
    http_content_type = nil
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
    elsif xml_data[0..3] = "\x00\x00\x00\x3c"
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
    xml_encoding = xml_encoding.match.group(0).downcase
    xencodings = ['iso-10646-ucs-2', 'ucs-2', 'csunicode', 'iso-10646-ucs-4', 'ucs-4', 'csucs4', 'utf-16', 'utf-32', 'utf16', 'u16']
    if sniffed_xml_encoding and xencodings.include?xml_encoding
      xml_encoding =  sniffed_xml_encoding
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
  newdata = unicode(data, encoding) # Woohoo! Works!
  $stderr << "successfully converted %s data to unicode\n" % encoding
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
def FeedParser.parse(url_file_stream_or_string, etag=nil, modified=nil, agent=nil, referrer=nil, handlers=[])
  # Parse a feed from a URL, file, stream or string
  result = FeedParserDict.new
  result['feed'] = FeedParserDict.new
  result['entries'] = []
  begin 
    modified = modified.rfc2822
  rescue NoMethodError
  end
  if XML_AVAILABLE 
    result['bozo'] = false
  end
  if handlers.class != Array # FIXME is this right?
    handlers = [handlers]
  end
  begin
    if URI::parse(url_file_stream_or_string).class == URI::Generic
      f = open(url_file_stream_or_string) # OpenURI doesn't behave well when passed HTTP options for a file.
    else
      f = open(url_file_stream_or_string, 
                      "If-None-Match" => etag, 
                      "If-Modified-Since" => modified, 
                      "User-Agent" => agent, 
                      "Referer" => referrer
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
    result['url'] = f.base_uri
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
    result['bozo_exception'] = NonXMLContentType(bozo_message) # I get to care about this, cuz Mark says I should.
  end
  result['version'], data = self.stripDoctype(data)

  baseuri = http_headers['content-location'] || result['href'] # FIXME Hope this works.
  baselang = http_headers['content-language']

  # if server sent 304, we're done
  if result['status'] == 304
    result['version'] = ''
    result['debug_message'] = "The feed has not changed sicne you last checked, " +
      "so the server sent no data. This is a feature, not a bug!"
      return result
  end

  # if there was a problem downloading, we're done
  if data.nil? or data.empty?
    return result
  end

  # determine character encoding
  use_script_parser = false
  known_encoding = false
  tried_encodings = []
  # try: HTTP encoding, declared XML encodin, encoding sniffed from BOM
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

  if not XML_AVAILABLE
    use_strict_parser = false
  end
  if use_strict_parser
    # initialize the SAX parser
    feedparser = StrictFeedParser.new(baseuri, baselang, 'utf-8')
    saxparser = XML::SAX::Helpers::ParserFactory.makeParser("XML::Parser::SAXDriver")
    saxparser.setDocumentHandler(feedparser)
    saxparser.setErrorHandler(feedparser)
    source = XML::SAX::InputSource.new(StringIO.new(data)) # NOTE large files are slow
    source.setSystemId('fp')
    source.setEncoding('utf-8')
    puts "source's getEncoding: #{source.getEncoding || source.getEncoding.class}"
    # FIXME are namespaces being checked?
   # begin
      saxparser.parse(source)
   # rescue Exception => e
      if $debug
        $stderr << "xml parsing failed\n"
        $stderr << e # Hrmph.
      end
      result['bozo'] = true
      result['bozo_exception'] = feedparser.exc || e 
      use_strict_parser = false
   # end
  end
  if not use_strict_parser
    feedparser = LooseFeedParser.new(baseuri, baselang, known_encoding && 'utf-8' || '', entities)
    feedparser.feed(data)
  end
  result['feed'] = feedparser.feeddata
  result['entries'] = feedparser.entries
  result['version'] = result['version'] || feedparser.version
  result['namespaces'] = feedparser.namespacesInUse
  return result
end
end # End FeedPraser module
require 'pp'

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
    stream << @results['href'].to_s + '\n\n'
    pp(@results)
    stream << "\n"
  end
end


require 'optparse'
require 'ostruct'
options = OpenStruct.new
options.etag = options.modified = options.agent = options.referrer = nil
options.format = 'pprint'

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
end

opts.parse!(ARGV)
if options.verbose 
  $debug = true
end
if options.format == :text
  serializer = TextSerializer
else
  serializer = PprintSerializer
end
ARGV.each do |url| # opts.parse! removes everything but the urls from the command line
  results = FeedParser.parse(url, etag=options.etag, modified=options.modified, agent=options.agent, referrer=options.referrer)
  serializer.new(results).write($stdout)
end
