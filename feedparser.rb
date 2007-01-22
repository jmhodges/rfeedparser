#!/usr/bin/env ruby
"""Universal feed parser in Ruby

Handles RSS 0.9x, RSS 1.0, RSS 2.0, CDF, Atom 0.3, and Atom 1.0 feeds

Visit http://feedparser.org/ for the latest version in Python
Visit http://feedparser.org/docs/ for the latest documentation
Email Jeff Hodges at jeff@obquo.com for questions

Required: Ruby 1.8
"""
$KCODE = 'UTF8'
require 'multibyte'
require 'core_ext' 
include CoreExtensions::String::Unicode # This enables multibyte support
__version__ = "0.1aleph_naught"
_debug = false
# FIXME OVER HERE! Hi. I'm still translating. Grep for "FIXME untranslated" to 
# figure out, roughly, what needs to be done.  I've tried to put it next to 
# anything having to do with any unimplemented sections.

# HTTP "User-Agent" header to send to servers when downloading feeds.
# If you are embedding feedparser in a larger application, you should
# change this to your application name and URL.
USER_AGENT = "UniversalFeedParser/%s +http://feedparser.org/" % __version__

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

require 'stringio'
require 'enumerator'
require 'uri'
require 'zlib'
# http://www.yoshidam.net/Ruby.html <-- XMLParser uses Expat
require 'xml/saxdriver' # FIXME this is an external dependency on Expat. On Ubuntu (and Debian), install libxml-parser-ruby1.8
XML::SAX::Helpers::ParserFactory.makeParser("XML::Parser::SAXDriver") 
_XML_AVAILABLE = true
require 'rubygems'
gem 'builder' # FIXME no rubygems, no builder. is bad.
require 'builder'
def _xmlescape(text)  # FIXME untranslated, when builder does not exist, must use stupid definition
  # Also, can just us .to_xs straight
  # http://www.intertwingly.net/blog/2005/09/28/XML-Cleansing
  # to_xs is from builder, of course
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

# ---------- don't touch these ----------
class ThingsNobodyCaresAboutButM < Exception
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

# FIXME We don't have a deep_copy in Ruby, but we have something that kind of, sort of works.
# This is completely untested, just here as a placeholder until I work this out
class Object
  def deep_copy
    Marshal.load(Marshal.dump(self))
  end
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
class FeedParserDict < Hash
  # The naming of a certain common attribute (such as, "When was the last
  # time this feed was updated?") can have many different names depending on
  # the type of feed we are handling. This class allows us to use both the 
  # names a person who has knowledge of the feed type expects, as well as 
  # allowing a developer to rely on one variable to contain the proper 
  # attribute. @@keymaps is a Hash that contains information on what certain 
  # attributes "really is" in each feed type. It does so by providing a 
  # common name that will map to any feed type in the keys, with possible 
  # "correct" attributes in the its values. the #[] and #[]= methods check 
  # with keymaps to see what attribute the developer "really means" if they've
  # asked for one which happens to be in @@keymap's keys.
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
  def initialize(pairs=nil,*args)
    if pairs.class == Array and pairs[0].class == Array and pairs[0].length == 2
      pairs.each do |l| 
        k,v = l
        self[k] = v
      end
    elsif pairs.class == Hash
      self.merge!(pairs) 
    else
      args.insert(0,pairs)
    end
    super.new(args)
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
    return super[key] || super[realkey]
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
    self.fetch(key, default)
  end

  def setdefault(key, value) 
    # FIXME i'm not entirely sure of how useful this is, but I've written less than 1/4 of the code, so we'll see.
    if not self.has_key(key)
      self[key] = value
    end
    return self[key]
  end

  def method_missing(methodname, *args)
    if methodname[-1] == '='
      return self[methodname[0..-2]] = *args[0]
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

#FIXME untranslated all of the _cp1252
_urifixer = RegExp.new('^([A-Za-z][A-Za-z0-9+-.]*://)(/*)(.*?)')
def _urljoin(base, uri)
  uri = _urifixer.sub('\1\3', uri)
  return URI::join(base, uri) #FIXME untranslated, error handling from original needed?
end


module _FeedParserMixin
  attr :namespaces, :can_be_relative_uri, :can_contain_relative_uris, :can_contain_dangerous_markup, :html_types
  namespaces = {'': '',
                  'http://backend.userland.com/rss': '',
                  'http://blogs.law.harvard.edu/tech/rss': '',
                  'http://purl.org/rss/1.0/': '',
                  'http://my.netscape.com/rdf/simple/0.9/': '',
                  'http://example.com/newformat#': '',
                  'http://example.com/necho': '',
                  'http://purl.org/echo/': '',
                  'uri/of/echo/namespace#': '',
                  'http://purl.org/pie/': '',
                  'http://purl.org/atom/ns#': '',
                  'http://www.w3.org/2005/Atom': '',
                  'http://purl.org/rss/1.0/modules/rss091#': '',

                  'http://webns.net/mvcb/':                               'admin',
                  'http://purl.org/rss/1.0/modules/aggregation/':         'ag',
                  'http://purl.org/rss/1.0/modules/annotate/':            'annotate',
                  'http://media.tangent.org/rss/1.0/':                    'audio',
                  'http://backend.userland.com/blogChannelModule':        'blogChannel',
                  'http://web.resource.org/cc/':                          'cc',
                  'http://backend.userland.com/creativeCommonsRssModule': 'creativeCommons',
                  'http://purl.org/rss/1.0/modules/company':              'co',
                  'http://purl.org/rss/1.0/modules/content/':             'content',
                  'http://my.theinfo.org/changed/1.0/rss/':               'cp',
                  'http://purl.org/dc/elements/1.1/':                     'dc',
                  'http://purl.org/dc/terms/':                            'dcterms',
                  'http://purl.org/rss/1.0/modules/email/':               'email',
                  'http://purl.org/rss/1.0/modules/event/':               'ev',
                  'http://rssnamespace.org/feedburner/ext/1.0':           'feedburner',
                  'http://freshmeat.net/rss/fm/':                         'fm',
                  'http://xmlns.com/foaf/0.1/':                           'foaf',
                  'http://www.w3.org/2003/01/geo/wgs84_pos#':             'geo',
                  'http://postneo.com/icbm/':                             'icbm',
                  'http://purl.org/rss/1.0/modules/image/':               'image',
                  'http://www.itunes.com/DTDs/PodCast-1.0.dtd':           'itunes',
                  'http://example.com/DTDs/PodCast-1.0.dtd':              'itunes',
                  'http://purl.org/rss/1.0/modules/link/':                'l',
                  'http://search.yahoo.com/mrss':                         'media',
                  'http://madskills.com/public/xml/rss/module/pingback/': 'pingback',
                  'http://prismstandard.org/namespaces/1.2/basic/':       'prism',
                  'http://www.w3.org/1999/02/22-rdf-syntax-ns#':          'rdf',
                  'http://www.w3.org/2000/01/rdf-schema#':                'rdfs',
                  'http://purl.org/rss/1.0/modules/reference/':           'ref',
                  'http://purl.org/rss/1.0/modules/richequiv/':           'reqv',
                  'http://purl.org/rss/1.0/modules/search/':              'search',
                  'http://purl.org/rss/1.0/modules/slash/':               'slash',
                  'http://schemas.xmlsoap.org/soap/envelope/':            'soap',
                  'http://purl.org/rss/1.0/modules/servicestatus/':       'ss',
                  'http://hacks.benhammersley.com/rss/streaming/':        'str',
                  'http://purl.org/rss/1.0/modules/subscription/':        'sub',
                  'http://purl.org/rss/1.0/modules/syndication/':         'sy',
                  'http://purl.org/rss/1.0/modules/taxonomy/':            'taxo',
                  'http://purl.org/rss/1.0/modules/threading/':           'thr',
                  'http://purl.org/rss/1.0/modules/textinput/':           'ti',
                  'http://madskills.com/public/xml/rss/module/trackback/':'trackback',
                  'http://wellformedweb.org/commentAPI/':                 'wfw',
                  'http://purl.org/rss/1.0/modules/wiki/':                'wiki',
                  'http://www.w3.org/1999/xhtml':                         'xhtml',
                  'http://www.w3.org/XML/1998/namespace':                 'xml',
                  'http://www.w3.org/1999/xlink':                         'xlink',
                  'http://schemas.pocketsoap.com/rss/myDescModule/':      'szf'
  }
  matchnamespaces = {}
  can_be_relative_uri = ['link', 'id', 'wfw_comment', 'wfw_commentrss', 'docs', 'url', 'href', 'comments', 'license', 'icon', 'logo']
  can_contain_relative_uris = ['content', 'title', 'summary', 'info', 'tagline', 'subtitle', 'copyright', 'rights', 'description']
  can_contain_dangerous_markup = ['content', 'title', 'summary', 'info', 'tagline', 'subtitle', 'copyright', 'rights', 'description']
  html_types = ['text/html', 'application/xhtml+xml']

  def initialize(baseuri=nil, baselang=nil, encoding='utf-8')
    $stderr << "initializing FeedParser\n" if _debug
    unless self.matchnamespaces.nil? or self.matchnamespaces.empty?
      self.namespaces.each do |k,v|
        self.matchnamespaces[k.downcase] = v
      end
    end

    self.feeddata = FeedParserDict() # feed-level data
    self.encoding = encoding # character encoding
    self.entries = [] # list of entry-level data
    self.version = '' # feed type/version see SUPPORTED_VERSIOSN
    self.namespacesinUse = {} # hash of namespaces defined by the feed

    # the following are used internall to track state;
    # this is really out of control and should be refactored
    self.infeed = false
    self.inentry = false
    self.incontent = false
    self.intextinput = false
    self.inimage = false
    self.inauthor = false
    self.incontributor = false
    self.inpublisher = false
    self.insource = false
    self.sourcedata = FeedParserDict()
    self.contentparams = FeedParserDict()
    self._summaryKey = None
    self.namespacemap = {}
    self.elementstack = []
    self.basestack = []
    self.langstack = []
    self.baseuri = baseuri or ''
    self.lang = baselang or None
    if baselang 
      self.feeddata['language'] = baselang.gsub('_','-')
    end
  end

  def unknown_starttag(tag, attrs)
    $stderr << 'start %s with %s\n' % [tag, attrs] if _debug
    # normalize attrs
    attrsD = {}
    attrs.each do |l| 
      l[0].downcase! # Downcase all keys
      l[1].downcase! if l[0] in ['rel','type']  # Downcase the values if the key is 'rel' or 'type'
      attrsD[l[0]] = l[1]
    end

    # track xml:base and xml:lang
    baseuri = attrsD.fetch('xml:base', attrsD.fetch('base')) or self.baseuri # Oh, come on. Has to be a better way
    lang = attrsD.fetch('xml:lang', attrsD.fetch('lang')) 
    if lang == '' #This next bit of code is right? Wtf?
      # xml:lang could be explicitly set to '', we need to capture that
      lang = nil
    elsif lang.nil?
      # if no xml:lang is specified, use parent lang
      lang = self.lang
    end
    if lang #Seriously, this cannot be correct
      if tag in ('feed', 'rss', 'rdf:RDF')
        self.feeddata['language'] = lang.replace('_','-')
      end
    end
    self.lang = lang
    self.basestack << (self.baseuri) #FIXME check that these are arrays
    self.langstack << (lang)

    # track namespaces
    attrs.each do |l|
      prefix, uri = l 
      if /^xmlns:/ =~ prefix # prefix begins with xmlns:
        self.trackNamespace(prefix[6..-1], uri)
      elsif prefix == 'xmlns':
        self.trackNamespace(nil, uri)
      end
    end

    # track inline content
    if self.incontent and self.contentparams.has_key?('type'?) and
                                                      not ( /xml$/ =~ self.contentparams.fetch('type', 'xml') )
                                                      # element declared itself as escaped markup, but isn't really
                                                      self.contentparams['type'] = 'application/xhtml+xml'
    end
    if self.incontent and self.contentparams.fetch('type') == 'application/xhtml+xml'
      # Note: probably shouldn't simply recreate localname here, but
      # our namespace handling isn't actually 100% correct in cases where
      # the feed redefines the default namespace (which is actually
      # the usual case for inline content, thanks Sam), so here we
      # cheat and just reconstruct the element based on localname
      # because that compensates for the bugs in our namespace handling.
      # This will horribly munge inline content with non-empty qnames,
      # but nobody actually does that, so I'm not fixing it.
      if not tag.grep(/:/).empty?
        prefix, tag = tag.splict(':',2)
        namespace = self.namespacesInUse.fetch(prefix,'')
        if tag == 'math' and namespace == 'http://www.w3.org/1998/Math/MathML':
          attrs << ['xmlns', namespace] # FIXME Why are we appending an actual list to the inside of attrs?
        end
        if tag == 'svg' and namespace == 'http://www.w3.org/2000/svg':
          attrs << ['xmlns',namespace]
        end
        return self.handle_data('<%s%s>' % (tag, self.strattrs(attrs)), escape=0) #FIXME untranslated.. twice over
      end
    end

    # match namespaces
    if not tag.grep(/:/).empty?
      prefix, suffix = tag.split(':', 2)
    else
      prefix, suffix = '', tag
    end
    prefix = self.namespacemap.fetch(prefix, prefix)
    if prefix and not prefix.empty?
      prefix = prefix + '_'
    end

    # special hack for better tracking of empty textinput/image elements in illformed feeds
    if (not prefix and not prefix.empty?) and not (['title', 'link', 'description','name'].include?tag)
      self.intextinput = false
    end
    if (prefix.nil? or prefix.empty?) and not (['title', 'link', 'description', 'url', 'href', 'width', 'height'].include?tag)
      self.inimage = false
    end

    # call special handler (if defined) or default handler
    begin
      return self.send('_start_'+prefix+suffix, attrsD)
    rescue NoMethodError
      return self.push(prefix + suffix, 1) # FIXME untranslated
    end  
  end # End unknown_starttag

  def unknown_endtag(tag)
    $stderr < 'end %s\n' % tag if _debug
    # match namespaces
    if not tag.grep(/:/).empty?
      prefix, suffix = tag.split(':',2)
    else
      prefix, suffix = '', tag
    end
    prefix = self.namespacemap.fetch(prefix,prefix)
    if prefix and not prefix.empty?
      prefix = prefix + '_'
    end

    # call special handler (if defined) or default handler
    begin 
      self.send('_end_' + prefix + suffix)
    rescue NoMethodError
      self.pop(prefix + suffix) # FIXME untranslated NO REALLY! POP TAKES 0 ARGS!
    end

    # track inline content 
    if self.incontent and self.contentparams.has_key?('type') and /xml$/ =~ self.contentparams.fetch('type','xml')
      # element declared itself as escaped markup, but it isn't really
      self.contentparams['type'] = 'applicatoin/xhtml+xml'
    end
    if self.incontent and self.contentparams.fetch('type') == 'application/xhtml+xml'
      tag = tag.split(/:/)[-1]
      self.handle_data('</%s>' % tag, escape=false) # FIXME untranslated
    end

    # track xml:base and xml:lang going out of scope
    if self.basestack and not self.basestack.empty?
      self.basestack.pop
      if self.basestack and self.basestack.empty? and self.basestack[-1]
        self.baseuri = self.basestack[-1]
      end
    end
    if self.langstack and not self.langstack.empty?
      self.langstack.pop
      if self.langstack and not self.langstack.empty? # and (self.langstack[-1] is not nil or ''): # Remnants?
        self.lang = self.langstack[-1]
      end
    end
  end # End unknown_endtag

  def handle_charref(ref)
    # called for each character reference, e.g. for '&#160;', ref will be 160
    if self.elementstack.nil? or self.elementstack.empty?
      return
    end
    ref.downcase!
    if ref in ('34', '38', '39', '60', '62', 'x22', 'x26', 'x27', 'x3c', 'x3e')
      text = '&#%s;' % ref
    else
      if ref[0] == 'x'
        c = ref[1..-1].to_i(16)
      else
        c = ref.to_i
      end
      text = #unichr(c).encode('utf-8') # FIXME untranslated BIG FIXME
    end
    self.elementstack[-1][2] << text
  end # End handle_charref

  def handle_entityref(ref)
    # called for each entity reference, e.g. for '&copy;', ref will be 'copy'
    if self.elementstack.nil? or self.elementstack.empty?
      return
    end
    $stderr << 'entering handle_entityref with %s\n' % ref if _debug
    if ['lt', 'gt', 'quot', 'amp', 'apos'].include? ref
      text = "$%s;" % ref
    elsif self.entities.has_key? ref
      text = self.entities[ref]
      if /^&#/ =~ text and /;$/ =~ text
        return self.handle_entityref(text)
      end
    else
      ref.decode_entities # FIXME this requires htmlentities/string
    end
    self.elementstack[-1][2] << text # FIXME this is probably not going to work as intended
    # In fact, anywhere there is an "append" in the original code, probably 
    # needs to be run over with a fine-toothed comb
  end 

  def handle_data(text, escape=true)
    # called for each block of plain text, i.e. outside of any tag and
    # not containing any character or entity references
    if self.elementstack.nil? or self.elementstack.empty?
      return
    end 
    if escape and self.contentparams.fetch('type') == 'application/xhtml+xml'
      text = text.to_xs # From Builder
    end
    self.elementstack[-1][2] << text
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
    $stderr << 'entering parse_declaration\n' if _debug
    if self.rawdata[i..i+9] == '<![CDATA['
      k = k.nil? ? self.rawdata.length : self.rawdata.index(']]>', i)
      self.handle_data(self.rawdata[i+9..k].to_xs)
      return k+3
    else
      k = self.rawdata.index('>', i)
      return k+1
    end
  end

  def mapContentType(contentType)
    contentType.lower!
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
    loweruri = uri.lower
    if [prefix, loweruri] == [nil, 'http://my.netscape.com/rdf/simple/0.9'] and (not self.version or self.version.empty?)
      self.version = 'rss090'
    end
    if loweruri == 'http://purl.org/rss/1.0/' and (not self.version or self.version.empty?)
      self.version = 'rss10'
    end
    if loweruri == 'http://www.w3.org/2005/atom' and (not self.version or self.version.empty?)
      self.version = 'atom10'
    end
    if loweruri.grep(/'backend.userland.com\/rss'/).empty?:
      # match any backend.userland.com namespace
      uri = 'http://backend.userland.com/rss'
      loweruri = uri
    end
    if self.matchnamespaces.has_key?loweruri
      self.namespacemap[prefix] = self.matchnamespaces[loweruri]
      self.namespacesInUse[self.matchnamespaces[loweruri]] = uri
    else
      self.namespacesInUse[prefix || ''] = uri
    end
  end 

  def resolveURI(uri)
    return _urljoin(self.baseuri || '', uri) # FIXME untranslated (?)
  end

  def decodeEntities(element, data)
    return data
  end

  def strattrs(attrs)
    # FIXME untranslated, to_xs does not take extra args that we need
    attrs.map{ |pair| '%s="%s"' % [pair[0],pair[1].to_xs]}.join(' ') 
  end

  def push(element, expectingText)
    self.elementstack << [element, expectingText, []])
  end

  def pop(element, stripWhitespace=true)
    return if self.elementstack.nil? or self.elementstack.empty?
    return if self.elementstack[-1][0] != element

    element, expectingText, pieces = self.elementstack.pop()

    if self.version == 'atom10' and self.contentparams.fetch('type','text') == 'application/xhtml+xml'
      # remove enclosing child element, but only if it is a <div> and
      # only if all the remaining content is nested underneath it.
      # This means that the divs would be retained in the following:
      #    <div>foo</div><div>bar</div>

      # FIXME This could definitely be refactored -- Jeff
      while pieces and not pieces.empty? and pieces.length > 1 and not (pieces.nil? and pieces[-1].strip.empty?)
        pieces.delete_at(-1)
      end
    while pieces and not pieces.empty? and pieces.length > 1 and not (pieces.nil? and pieces[-1].strip.empty?)
      pieces.delete_at(0)
    end
    if pieces and not pieces.empty? and (pieces[0] == '<div>' or /^<div/ =~ pieces[0] and pieces[-1] == '</div>')
      depth = 0
      # This next for loop is an attempt to translate Python's for/else idiom
      # See _why's email (and associated thread) at 
      # http://blade.nagaokaut.ac.jp/cgi-bin/scat.rb/ruby/ruby-talk/156771
      for piece in pieces[0..-2]
        if /^<\// =~ piece
          depth -= 1
          break if depth == 0
        elsif /^</ =~ piece and not /\/>/ =~ piece
          depth += 1
        end
      end or
      pieces = pieces[1..-2]
    end
    end

    output = pieces.join
    if stripWhitespace
      output.strip!
    end

    return output unless expectingText

    # decode base64 content
    if contentparams['base64'] # no kidding. this is a perfect translation
      # FIXME untranslated, the error checking is not included. is it even needed?
      output = Base64.decode64(output) 
    end

    # resolve relative URIs
    if self.can_be_relative_uri.include?element and not (output.nil? and output.empty?)
      output = self.resolveURI(output)
    end

    # decode entities within embedded markup
    unless self.contentparams['base64']
      output = self.decodeEntities(element, output)
    end

    if self.lookslikehtml(output)
      self.contentparams['type']='text/html'
    end

    # remove temporary cruft from contentparams
    self.contentparams.delete('mode')
    self.contentparams.delete('base64')

    # FIXME small refactoring could put all of these if is_htmlish stuff under one check
    is_htmlish = self.html_types.include?self.mapContentType(self.contentparams.fetch('type', 'text/html'))
    # resolve relative URIs within embedded markup
    if is_htmlish
      if self.can_contain_relative_uris.include? element
        output = _resolveRelativeURIs(output, self.baseuri, self.encoding, self.contentparams.fetch('type', 'text/html'))
      end
    end

    # parse microformats
    # (must do this before sanitizing because some microformats
    # rely on elements that we sanitize)
    if is_htmlish and ['content','description','summary'].include?element
      mfresults = _parseMicroformats(output, self.baseuri, self.encoding)
      if mfresults
        mfresults.fetch('tags', []).each { |tag| self._addTag(tag['term'], tag['scheme'], tag['label']) }
        mfresults.fetch('enclosures', []).each { |enclosure| self._start_enclosure(enclosure) }
        mfresults.fetch('xfn',[]).each { |xfn| self._addXFN(xfn['relationships'], xfn['href'], xfn['name']) }
        if mfresults['vcard']
          self._getContext()['vcard'] = vcard # FIXME need to see if _getContext can be better done
        end
      end
    end

    # sanitize embedded markup
    if is_htmlish
      if self.can_contain_dangerous_markup
        # FIXME untranslated, output is probably not going to match up with
        # the u'' down below all the time, though it should some of the time. fix this.
        output = _sanitizeHTML(output, self.encoding, self.contentparams.fetch('type', 'text/html'))
      end
    end

    if self.encoding and not self.encoding.empty? and output.class != u('').class
      output = unicode(output, self.encoding) # FIXME no error checks for iconv module
    end

    # address common error where people take data that is already in 
    # utf-8, presume that it is iso-8859-1, and re-encode it.
    #
    # FIXME I have no idea how to implement this in Ruby. Christ. I'm not 
    # even sure how the Python code fixes the problem.
    # 
    #if self.encoding == 'utf-8' and output.class == u''.class
    #  output = unicode(Iconv.new(encoding, 'iso-8859-1').iconv(output),self.encoding)
    #end
    #

    # map win-1252 extensions to the proper code points
    # FIXME untranslated, like i even have included these codepoints. 
    # please.
    # but, this code will work once its in. this is stuff that looks good 
    # in ruby.
    # if output.class == u''.class
    #   output = output.collect { |c| _cp1252[c] || c }

    # categories/tags/keywords/whatever are handled in _end_category
    if element == 'category'
      return output
    end

    # store output in appropriate places(s)
    if self.inentry and not self.insource
      if element == 'content'
        self.entries[-1].setdefault(element, [])
        contentparams = self.contentparams.dup # FIXME untranslated, there is little likelihood that this works
        contentparams['value'] = output
        self.entries[-1][element] << contentparams
      elsif element == 'link'
        self.entries[-1][element] = output
        unless output.nil? and output.empty?
          self.entries[-1]['links'][-1]['href'] = output
        end
      else
        if element == 'description'
          element = 'summary'
        end
        self.entries[-1][element] = output
        if self.incontent
          contentparams = self.contentparams.dup # FIXME untranslated, again, not going to work
          contentparams['value'] = output
          self.entries[-1][element + '_detail'] = contentparams
        end
      end
    elsif self.infeed or self.insource
      context = self._getContext
      if element == 'description'
        element = 'subtitle'
      end
      context[element] = output
      if element == 'link'
        context['links'][-1]['href'] = output
      elsif self.incontent
        contentparams = self.contentparams.dup # FIXME untranslated, deepcopy/dup problem again
        contentparams['value'] = output
        context[element + '_detail'] = contentparams
      end
    end
  end
end #End FeedParserMixin
