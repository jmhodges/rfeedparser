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
require 'xml/saxdriver' # calling expat
require 'pp'
require 'rubygems'
require 'base64'
require 'iconv'
begin 
  gem 'hpricot', ">=0.5"
  gem 'character-encodings', ">=0.2.0"
  gem 'htmltools'
  gem 'htmlentities'
  gem 'activesupport'
  gem 'chardet'
rescue Gem::LoadError,LoadError
end

require 'chardet'
$chardet = true

require 'hpricot'
require 'encoding/character/utf-8'
require 'html/sgml-parser'
require 'htmlentities'
require 'active_support'
require 'open-uri'
include OpenURI

$debug = false
$compatible = true

Encoding_Aliases = { # Adapted from python2.4's encodings/aliases.py
  # ascii codec
    '646'                => 'ascii',
    'ansi_x3.4_1968'     => 'ascii',
    'ansi_x3_4_1968'     => 'ascii', # some email headers use this non-standard name
    'ansi_x3.4_1986'     => 'ascii',
    'cp367'              => 'ascii',
    'csascii'            => 'ascii',
    'ibm367'             => 'ascii',
    'iso646_us'          => 'ascii',
    'iso_646.irv_1991'   => 'ascii',
    'iso_ir_6'           => 'ascii',
    'us'                 => 'ascii',
    'us_ascii'           => 'ascii',

    # big5 codec
    'big5_tw'            => 'big5',
    'csbig5'             => 'big5',

    # big5hkscs codec
    'big5_hkscs'         => 'big5hkscs',
    'hkscs'              => 'big5hkscs',

    # cp037 codec
    '037'                => 'cp037',
    'csibm037'           => 'cp037',
    'ebcdic_cp_ca'       => 'cp037',
    'ebcdic_cp_nl'       => 'cp037',
    'ebcdic_cp_us'       => 'cp037',
    'ebcdic_cp_wt'       => 'cp037',
    'ibm037'             => 'cp037',
    'ibm039'             => 'cp037',

    # cp1026 codec
    '1026'               => 'cp1026',
    'csibm1026'          => 'cp1026',
    'ibm1026'            => 'cp1026',

    # cp1140 codec
    '1140'               => 'cp1140',
    'ibm1140'            => 'cp1140',

    # cp1250 codec
    '1250'               => 'cp1250',
    'windows_1250'       => 'cp1250',

    # cp1251 codec
    '1251'               => 'cp1251',
    'windows_1251'       => 'cp1251',

    # cp1252 codec
    '1252'               => 'cp1252',
    'windows_1252'       => 'cp1252',

    # cp1253 codec
    '1253'               => 'cp1253',
    'windows_1253'       => 'cp1253',

    # cp1254 codec
    '1254'               => 'cp1254',
    'windows_1254'       => 'cp1254',

    # cp1255 codec
    '1255'               => 'cp1255',
    'windows_1255'       => 'cp1255',

    # cp1256 codec
    '1256'               => 'cp1256',
    'windows_1256'       => 'cp1256',

    # cp1257 codec
    '1257'               => 'cp1257',
    'windows_1257'       => 'cp1257',

    # cp1258 codec
    '1258'               => 'cp1258',
    'windows_1258'       => 'cp1258',

    # cp424 codec
    '424'                => 'cp424',
    'csibm424'           => 'cp424',
    'ebcdic_cp_he'       => 'cp424',
    'ibm424'             => 'cp424',

    # cp437 codec
    '437'                => 'cp437',
    'cspc8codepage437'   => 'cp437',
    'ibm437'             => 'cp437',

    # cp500 codec
    '500'                => 'cp500',
    'csibm500'           => 'cp500',
    'ebcdic_cp_be'       => 'cp500',
    'ebcdic_cp_ch'       => 'cp500',
    'ibm500'             => 'cp500',

    # cp775 codec
    '775'              => 'cp775',
    'cspc775baltic'      => 'cp775',
    'ibm775'             => 'cp775',

    # cp850 codec
    '850'                => 'cp850',
    'cspc850multilingual' => 'cp850',
    'ibm850'             => 'cp850',

    # cp852 codec
    '852'                => 'cp852',
    'cspcp852'           => 'cp852',
    'ibm852'             => 'cp852',

    # cp855 codec
    '855'                => 'cp855',
    'csibm855'           => 'cp855',
    'ibm855'             => 'cp855',

    # cp857 codec
    '857'                => 'cp857',
    'csibm857'           => 'cp857',
    'ibm857'             => 'cp857',

    # cp860 codec
    '860'                => 'cp860',
    'csibm860'           => 'cp860',
    'ibm860'             => 'cp860',

    # cp861 codec
    '861'                => 'cp861',
    'cp_is'              => 'cp861',
    'csibm861'           => 'cp861',
    'ibm861'             => 'cp861',

    # cp862 codec
    '862'                => 'cp862',
    'cspc862latinhebrew' => 'cp862',
    'ibm862'             => 'cp862',

    # cp863 codec
    '863'                => 'cp863',
    'csibm863'           => 'cp863',
    'ibm863'             => 'cp863',

    # cp864 codec
    '864'                => 'cp864',
    'csibm864'           => 'cp864',
    'ibm864'             => 'cp864',

    # cp865 codec
    '865'                => 'cp865',
    'csibm865'           => 'cp865',
    'ibm865'             => 'cp865',

    # cp866 codec
    '866'                => 'cp866',
    'csibm866'           => 'cp866',
    'ibm866'             => 'cp866',

    # cp869 codec
    '869'                => 'cp869',
    'cp_gr'              => 'cp869',
    'csibm869'           => 'cp869',
    'ibm869'             => 'cp869',

    # cp932 codec
    '932'                => 'cp932',
    'ms932'              => 'cp932',
    'mskanji'            => 'cp932',
    'ms_kanji'           => 'cp932',

    # cp949 codec
    '949'                => 'cp949',
    'ms949'              => 'cp949',
    'uhc'                => 'cp949',

    # cp950 codec
    '950'                => 'cp950',
    'ms950'              => 'cp950',

    # euc_jp codec
    'euc_jp'             => 'euc-jp',
    'eucjp'              => 'euc-jp',
    'ujis'               => 'euc-jp',
    'u_jis'              => 'euc-jp',

    # euc_kr codec
    'euc_kr'             => 'euc-kr',
    'euckr'              => 'euc-kr',
    'korean'             => 'euc-kr',
    'ksc5601'            => 'euc-kr',
    'ks_c_5601'          => 'euc-kr',
    'ks_c_5601_1987'     => 'euc-kr',
    'ksx1001'            => 'euc-kr',
    'ks_x_1001'          => 'euc-kr',

    # gb18030 codec
    'gb18030_2000'       => 'gb18030',

    # gb2312 codec
    'chinese'            => 'gb2312',
    'csiso58gb231280'    => 'gb2312',
    'euc_cn'             => 'gb2312',
    'euccn'              => 'gb2312',
    'eucgb2312_cn'       => 'gb2312',
    'gb2312_1980'        => 'gb2312',
    'gb2312_80'          => 'gb2312',
    'iso_ir_58'          => 'gb2312',

    # gbk codec
    '936'                => 'gbk',
    'cp936'              => 'gbk',
    'ms936'              => 'gbk',

    # hp-roman8 codec
    'hp_roman8'          => 'hp-roman8',
    'roman8'             => 'hp-roman8',
    'r8'                 => 'hp-roman8',
    'csHPRoman8'         => 'hp-roman8',

    # iso2022_jp codec
    'iso2022_jp'         => 'iso-2022-jp',
    'csiso2022jp'        => 'iso-2022-jp',
    'iso2022jp'          => 'iso-2022-jp',
    'iso_2022_jp'        => 'iso-2022-jp',

    # iso2022_jp_1 codec
    'iso2002_jp_1'       => 'iso-2022-jp-1',
    'iso2022jp_1'        => 'iso-2022-jp-1',
    'iso_2022_jp_1'      => 'iso-2022-jp-1',

    # iso2022_jp_2 codec
    'iso2022_jp_2'       => 'iso-2002-jp-2',
    'iso2022jp_2'        => 'iso-2022-jp-2',
    'iso_2022_jp_2'      => 'iso-2022-jp-2',

    # iso2022_jp_3 codec
    'iso2002_jp_3'       => 'iso-2022-jp-3',
    'iso2022jp_3'        => 'iso-2022-jp-3',
    'iso_2022_jp_3'      => 'iso-2022-jp-3',

    # iso2022_kr codec
    'iso2022_kr'         => 'iso-2022-kr',
    'csiso2022kr'        => 'iso-2022-kr',
    'iso2022kr'          => 'iso-2022-kr',
    'iso_2022_kr'        => 'iso-2022-kr',

    # iso8859_10 codec
    'iso8859_10'         => 'iso-8859-10',
    'csisolatin6'        => 'iso-8859-10',
    'iso_8859_10'        => 'iso-8859-10',
    'iso_8859_10_1992'   => 'iso-8859-10',
    'iso_ir_157'         => 'iso-8859-10',
    'l6'                 => 'iso-8859-10',
    'latin6'             => 'iso-8859-10',

    # iso8859_13 codec
    'iso8859_13'         => 'iso-8859-13',
    'iso_8859_13'        => 'iso-8859-13',

    # iso8859_14 codec
    'iso8859_14'         => 'iso-8859-14',
    'iso_8859_14'        => 'iso-8859-14',
    'iso_8859_14_1998'   => 'iso-8859-14',
    'iso_celtic'         => 'iso-8859-14',
    'iso_ir_199'         => 'iso-8859-14',
    'l8'                 => 'iso-8859-14',
    'latin8'             => 'iso-8859-14',

    # iso8859_15 codec
    'iso8859_15'         => 'iso-8859-15',
    'iso_8859_15'        => 'iso-8859-15',

    # iso8859_1 codec
    'latin_1'            => 'iso-8859-1',
    'cp819'              => 'iso-8859-1',
    'csisolatin1'        => 'iso-8859-1',
    'ibm819'             => 'iso-8859-1',
    'iso8859'            => 'iso-8859-1',
    'iso_8859_1'         => 'iso-8859-1',
    'iso_8859_1_1987'    => 'iso-8859-1',
    'iso_ir_100'         => 'iso-8859-1',
    'l1'                 => 'iso-8859-1',
    'latin'              => 'iso-8859-1',
    'latin1'             => 'iso-8859-1',

    # iso8859_2 codec
    'iso8859_2'          => 'iso-8859-2',
    'csisolatin2'        => 'iso-8859-2',
    'iso_8859_2'         => 'iso-8859-2',
    'iso_8859_2_1987'    => 'iso-8859-2',
    'iso_ir_101'         => 'iso-8859-2',
    'l2'                 => 'iso-8859-2',
    'latin2'             => 'iso-8859-2',

    # iso8859_3 codec
    'iso8859_3'          => 'iso-8859-3',
    'csisolatin3'        => 'iso-8859-3',
    'iso_8859_3'         => 'iso-8859-3',
    'iso_8859_3_1988'    => 'iso-8859-3',
    'iso_ir_109'         => 'iso-8859-3',
    'l3'                 => 'iso-8859-3',
    'latin3'             => 'iso-8859-3',

    # iso8859_4 codec
    'iso8849_4'          => 'iso-8859-4',
    'csisolatin4'        => 'iso-8859-4',
    'iso_8859_4'         => 'iso-8859-4',
    'iso_8859_4_1988'    => 'iso-8859-4',
    'iso_ir_110'         => 'iso-8859-4',
    'l4'                 => 'iso-8859-4',
    'latin4'             => 'iso-8859-4',

    # iso8859_5 codec
    'iso8859_5'          => 'iso-8859-5',
    'csisolatincyrillic' => 'iso-8859-5',
    'cyrillic'           => 'iso-8859-5',
    'iso_8859_5'         => 'iso-8859-5',
    'iso_8859_5_1988'    => 'iso-8859-5',
    'iso_ir_144'         => 'iso-8859-5',

    # iso8859_6 codec
    'iso8859_6'          => 'iso-8859-6',
    'arabic'             => 'iso-8859-6',
    'asmo_708'           => 'iso-8859-6',
    'csisolatinarabic'   => 'iso-8859-6',
    'ecma_114'           => 'iso-8859-6',
    'iso_8859_6'         => 'iso-8859-6',
    'iso_8859_6_1987'    => 'iso-8859-6',
    'iso_ir_127'         => 'iso-8859-6',

    # iso8859_7 codec
    'iso8859_7'          => 'iso-8859-7',
    'csisolatingreek'    => 'iso-8859-7',
    'ecma_118'           => 'iso-8859-7',
    'elot_928'           => 'iso-8859-7',
    'greek'              => 'iso-8859-7',
    'greek8'             => 'iso-8859-7',
    'iso_8859_7'         => 'iso-8859-7',
    'iso_8859_7_1987'    => 'iso-8859-7',
    'iso_ir_126'         => 'iso-8859-7',

    # iso8859_8 codec
    'iso8859_9'          => 'iso8859_8',
    'csisolatinhebrew'   => 'iso-8859-8',
    'hebrew'             => 'iso-8859-8',
    'iso_8859_8'         => 'iso-8859-8',
    'iso_8859_8_1988'    => 'iso-8859-8',
    'iso_ir_138'         => 'iso-8859-8',

    # iso8859_9 codec
    'iso8859_9'          => 'iso-8859-9',
    'csisolatin5'        => 'iso-8859-9',
    'iso_8859_9'         => 'iso-8859-9',
    'iso_8859_9_1989'    => 'iso-8859-9',
    'iso_ir_148'         => 'iso-8859-9',
    'l5'                 => 'iso-8859-9',
    'latin5'             => 'iso-8859-9',

    # iso8859_11 codec
    'iso8859_11'         => 'iso-8859-11',
    'thai'               => 'iso-8859-11',
    'iso_8859_11'        => 'iso-8859-11',
    'iso_8859_11_2001'   => 'iso-8859-11',

    # iso8859_16 codec
    'iso8859_16'         => 'iso-8859-16',
    'iso_8859_16'        => 'iso-8859-16',
    'iso_8859_16_2001'   => 'iso-8859-16',
    'iso_ir_226'         => 'iso-8859-16',
    'l10'                => 'iso-8859-16',
    'latin10'            => 'iso-8859-16',

    # cskoi8r codec 
    'koi8_r'             => 'cskoi8r',

    # mac_cyrillic codec
    'mac_cyrillic'       => 'maccyrillic',

    # shift_jis codec
    'csshiftjis'         => 'shift_jis',
    'shiftjis'           => 'shift_jis',
    'sjis'               => 'shift_jis',
    's_jis'              => 'shift_jis',

    # shift_jisx0213 codec
    'shiftjisx0213'      => 'shift_jisx0213',
    'sjisx0213'          => 'shift_jisx0213',
    's_jisx0213'         => 'shift_jisx0213',

    # utf_16 codec
    'utf_16'             => 'utf-16',
    'u16'                => 'utf-16',
    'utf16'              => 'utf-16',

    # utf_16_be codec
    'utf_16_be'          => 'utf-16be',
    'unicodebigunmarked' => 'utf-16be',
    'utf_16be'           => 'utf-16be',

    # utf_16_le codec
    'utf_16_le'          => 'utf-16le',
    'unicodelittleunmarked' => 'utf-16le',
    'utf_16le'           => 'utf-16le',

    # utf_7 codec
    'utf_7'              => 'utf-7',
    'u7'                 => 'utf-7',
    'utf7'               => 'utf-7',

    # utf_8 codec
    'utf_8'              => 'utf-8',
    'u8'                 => 'utf-8',
    'utf'                => 'utf-8',
    'utf8'               => 'utf-8',
    'utf8_ucs2'          => 'utf-8',
    'utf8_ucs4'          => 'utf-8',
}

def unicode(data, from_encoding)
  # Takes a single string and converts it from the encoding in 
  # from_encoding to unicode.
  uconvert(data, from_encoding, 'unicode')
end

def uconvert(data, from_encoding, to_encoding = 'utf-8')
  from_encoding = Encoding_Aliases[from_encoding] || from_encoding
  to_encoding = Encoding_Aliases[to_encoding] || to_encoding
  Iconv.iconv(to_encoding, from_encoding, data)[0]
end

def unichr(i)
  [i].pack('U*')
end

def index_match(stri,regexp, offset)
  if offset == 241
  end
  i = stri.index(regexp, offset)

  return nil, nil unless i

  full = stri[i..-1].match(regexp)
  return i, full
end

def _ebcdic_to_ascii(s)   
  return Iconv.iconv("iso88591", "ebcdic-cp-be", s)[0]
end

def urljoin(base, uri)
  urifixer = /^([A-Za-z][A-Za-z0-9+-.]*:\/\/)(\/*)(.*?)/u
  uri = uri.sub(urifixer, '\1\3') 
  begin
    return URI.join(base, uri).to_s 
  rescue URI::BadURIError => e
    if URI.parse(base).relative?
      return URI::parse(uri).to_s
    end
  end
end

def py2rtime(pytuple)
  Time.utc(pytuple[0..5])
end

# http://intertwingly.net/stories/2005/09/28/xchar.rb
module XChar
  # http://intertwingly.net/stories/2004/04/14/i18n.html#CleaningWindows
  CP1252 = {
    128 => 8364, # euro sign
    130 => 8218, # single low-9 quotation mark
    131 =>  402, # latin small letter f with hook
    132 => 8222, # double low-9 quotation mark
    133 => 8230, # horizontal ellipsis
    134 => 8224, # dagger
    135 => 8225, # double dagger
    136 =>  710, # modifier letter circumflex accent
    137 => 8240, # per mille sign
    138 =>  352, # latin capital letter s with caron
    139 => 8249, # single left-pointing angle quotation mark
    140 =>  338, # latin capital ligature oe
    142 =>  381, # latin capital letter z with caron
    145 => 8216, # left single quotation mark
    146 => 8217, # right single quotation mark
    147 => 8220, # left double quotation mark
    148 => 8221, # right double quotation mark
    149 => 8226, # bullet
    150 => 8211, # en dash
    151 => 8212, # em dash
    152 =>  732, # small tilde
    153 => 8482, # trade mark sign
    154 =>  353, # latin small letter s with caron
    155 => 8250, # single right-pointing angle quotation mark
    156 =>  339, # latin small ligature oe
    158 =>  382, # latin small letter z with caron
    159 =>  376} # latin capital letter y with diaeresis

    # http://www.w3.org/TR/REC-xml/#dt-chardata
    PREDEFINED = {
      38 => '&amp;', # ampersand
      60 => '&lt;',  # left angle bracket
      62 => '&gt;'}  # right angle bracket

      # http://www.w3.org/TR/REC-xml/#charsets
      VALID = [[0x9, 0xA, 0xD], (0x20..0xD7FF), 
	(0xE000..0xFFFD), (0x10000..0x10FFFF)]
end

class Fixnum
  # xml escaped version of chr
  def xchr
    n = XChar::CP1252[self] || self
    n = 42 unless XChar::VALID.find {|range| range.include? n}
    XChar::PREDEFINED[n] or (n<128 ? n.chr : "&##{n};")
  end
end

class String
  alias :old_index :index
  def to_xs 
    unpack('U*').map {|n| n.xchr}.join # ASCII, UTF-8
  rescue
    unpack('C*').map {|n| n.xchr}.join # ISO-8859-1, WIN-1252
  end
end

class BetterSGMLParserError < Exception; end;
class BetterSGMLParser < HTML::SGMLParser
  # Replaced Tagfind and Charref Regexps with the ones in feedparser.py
  # This makes things work. 
  Interesting = /[&<]/u
  Incomplete = Regexp.compile('&([a-zA-Z][a-zA-Z0-9]*|#[0-9]*)?|' +
				 '<([a-zA-Z][^<>]*|/([a-zA-Z][^<>]*)?|' +
				 '![^<>]*)?', 64) # 64 is the unicode flag

				 Entityref = /&([a-zA-Z][-.a-zA-Z0-9]*)[^-.a-zA-Z0-9]/u
				 Charref = /&#(x?[0-9A-Fa-f]+)[^0-9A-Fa-f]/u

				   Shorttagopen = /'<[a-zA-Z][-.a-zA-Z0-9]*/u
				 Shorttag = /'<([a-zA-Z][-.a-zA-Z0-9]*)\/([^\/]*)\//u
				 Endtagopen = /<\//u # Matching the Python SGMLParser
				 Endbracket = /[<>]/u
				 Declopen = /<!/u
				 Piopenbegin = /^<\?/u
				 Piclose = />/u

				 Commentopen = /<!--/u
				 Commentclose = /--\s*>/u
				 Tagfind = /[a-zA-Z][-_.:a-zA-Z0-9]*/u
				 Attrfind = Regexp.compile('\s*([a-zA-Z_][-:.a-zA-Z_0-9]*)(\s*=\s*'+
			    '(\'[^\']*\'|"[^"]*"|[\]\[\-a-zA-Z0-9./,:;+*%?!&$\(\)_#=~\'"@]*))?',
			    64)
				 Endtagfind = /\s*\/\s*>/u
				 def initialize(verbose=false)
				   super(verbose)
				 end
				 def feed(*args)
				   super(*args)
				 end

				 def goahead(_end)
				   rawdata = @rawdata # woo, utf-8 magic
				   i = 0
				   n = rawdata.length
				   while i < n
				     if @nomoretags
				       # handle_data_range does nothing more than set a "Range" that is never used. wtf?
				       handle_data(rawdata[i...n]) # i...n means "range from i to n not including n" 
				       i = n
				       break
				     end
				     j = rawdata.index(Interesting, i) 
				     j = n unless j
				     handle_data(rawdata[i...j]) if i < j
				     i = j
				     break if (i == n)
				     if rawdata[i..i] == '<' # equivalent to rawdata[i..i] == '<' # Yeah, ugly.
				       if rawdata.index(Starttagopen,i) == i
					 if @literal
					   handle_data(rawdata[i..i])
					   i = i+1
					   next
					 end
					 k = parse_starttag(i)
					 break unless k
					 i = k
					 next
				       end
				       if rawdata.index(Endtagopen,i) == i #Don't use Endtagopen
					 k = parse_endtag(i)
					 break unless k
					 i = k
					 @literal = false
					 next
				       end
				       if @literal
					 if n > (i+1)
					   handle_data("<")
					   i = i+1
					 else
					   #incomplete
					   break
					 end
					 next
				       end
				       if rawdata.index(Commentopen,i) == i 
					 k = parse_comment(i)
					 break unless k
					 i = k
					 next
				       end
				       if rawdata.index(Piopenbegin,i) == i # Like Piopen but must be at beginning of rawdata
					 k = parse_pi(i)
					 break unless k
					 i += k
					 next
				       end
				       if rawdata.index(Declopen,i) == i
					 # This is some sort of declaration; in "HTML as
					 # deployed," this should only be the document type
					 # declaration ("<!DOCTYPE html...>").
					 k = parse_declaration(i)
					 break unless k
					 i = k
					 next
				       end
				     elsif rawdata[i..i] == '&'
				       if @literal # FIXME BUGME SGMLParser totally does not check this. Bug it.
					 handle_data(rawdata[i..i])
					 i += 1
					 next
				       end

				     # the Char must come first as its #=~ method is the only one that is UTF-8 safe 
				     ni,match = index_match(rawdata, Charref, i)
				     if ni and ni == i # See? Ugly
				       handle_charref(match[1]) # $1 is just the first group we captured (with parentheses)
				       i += match[0].length  # $& is the "all" of the match.. it includes the full match we looked for not just the stuff we put parentheses around to capture. 
				       i -= 1 unless rawdata[i-1..i-1] == ";"
				       next
				     end
				     ni,match = index_match(rawdata, Entityref, i)
				     if ni and ni == i
				       handle_entityref(match[1])
				       i += match[0].length
				       i -= 1 unless rawdata[i-1..i-1] == ";"
				       next
				     end
				     else
				       error('neither < nor & ??')
				     end
				     # We get here only if incomplete matches but
				     # nothing else
				     ni,match = index_match(rawdata,Incomplete,i)
				     unless ni and ni == 0
				       handle_data(rawdata[i...i+1]) # str[i...i+1] == str[i..i]
				       i += 1
				       next
				     end
				     j = ni + match[0].length 
				     break if j == n # Really incomplete
				     handle_data(rawdata[i...j])
				     i = j
				   end # end while

				   if _end and i < n
				     handle_data(rawdata[i...n])
				     i = n
				   end

				   @rawdata = rawdata[i..-1] 
				   # @offset += i # FIXME BUGME another unused variable in SGMLParser?
				 end


				 # Internal -- parse processing instr, return length or -1 if not terminated
				 def parse_pi(i)
				   rawdata = @rawdata 
				   if rawdata[i...i+2] != '<?' 
				     error("unexpected call to parse_pi()")
				   end
				   ni,match = index_match(rawdata,Piclose,i+2)
				   return nil unless match
				   j = ni
				   handle_pi(rawdata[i+2...j])
				   j = (j + match[0].length)
				   return j-i
				 end

				 def parse_comment(i)
				   rawdata = @rawdata
				   if rawdata[i...i+4] != "<!--"
				     error("unexpected call to parse_comment()")
				   end
				   ni,match = index_match(rawdata, Commentclose,i)
				   return nil unless match
				   handle_comment(rawdata[i+4..(ni-1)])
				   return ni+match[0].length # Length from i to just past the closing comment tag
				 end


				 def parse_starttag(i)
				   @_starttag_text = nil
				   start_pos = i
				   rawdata = @rawdata
				   ni,match = index_match(rawdata,Shorttagopen,i)
				   if ni == i 
				     # SGML shorthand: <tag/data/ == <tag>data</tag>
				     # XXX Can data contain &... (entity or char refs)?
				     # XXX Can data contain < or > (tag characters)?
				     # XXX Can there be whitespace before the first /?
				     k,match = index_match(rawdata,Shorttag,i)
				     return nil unless match
				     tag, data = match[1], match[2]
				     @_starttag_text = "<#{tag}/"
				     tag.downcase!
				     second_end = rawdata.index(Shorttagopen,k)
				     finish_shorttag(tag, data)
				     @_starttag_text = rawdata[start_pos...second_end+1]
				     return k
				   end

				   j = rawdata.index(Endbracket, i+1)
				   return nil unless j
				   attrsd = []
				   if rawdata[i...i+2] == '<>'
				     # SGML shorthand: <> == <last open tag seen>
				     k = j
				     tag = @lasttag
				   else
				     ni,match = index_match(rawdata,Tagfind,i+1)
				     unless match
				       error('unexpected call to parse_starttag')
				     end
				     k = ni+match[0].length+1
				     tag = match[0].downcase
				     @lasttag = tag
				   end

				   while k < j
				     break if rawdata.index(Endtagfind, k) == k
				     ni,match = index_match(rawdata,Attrfind,k)
				     break unless ni
				     matched_length = match[0].length
				     attrname, rest, attrvalue = match[1],match[2],match[3]
				     if rest.nil? or rest.empty?
				       attrvalue = '' # was: = attrname # Why the change?
				     elsif [?',?'] == [attrvalue[0..0], attrvalue[-1..-1]] or [?",?"] == [attrvalue[0],attrvalue[-1]]
				       attrvalue = attrvalue[1...-1]
				     end
				     attrsd << [attrname.downcase, attrvalue]
				     k += matched_length
				   end
				   if rawdata[j..j] == ">"
				     j += 1
				   end
				   @_starttag_text = rawdata[start_pos...j]
				   finish_starttag(tag, attrsd)
				   return j
				 end

				 def parse_endtag(i)
				   rawdata = @rawdata
				   j, match = index_match(rawdata, /[<>]/,i+1)
				   return nil unless j
				   tag = rawdata[i+2...j].strip.downcase
				   if rawdata[j..j] == ">"
				     j += 1
				   end
				   finish_endtag(tag)
				   return j
				 end

				 def output
				   # Return processed HTML as a single string
				   return @pieces.map{|p| p.to_s}.join
				 end

				 def error(message)
				   raise BetterSGMLParserError.new(message)
				 end
				 def handle_pi(text)
				 end
				 def handle_decl(text)
				 end
end

# Add some helper methods to make AttributeList (all of those damn attrs
# and attrsD used by StrictFeedParser) act more like a Hash.
# NOTE AttributeList is still Read-Only (AFAICT).
# Monkey patching is terrible, and I have an addiction.
module XML
  module SAX
    module AttributeList # in xml/sax.rb
      def [](key)
	getValue(key)
      end

      def each(&blk)
	(0...getLength).each{|pos| yield [getName(pos), getValue(pos)]}
      end

      def each_key(&blk)
	(0...getLength).each{|pos| yield getName(pos) }
      end

      def each_value(&blk)
	(0...getLength).each{|pos| yield getValue(pos) }
      end

      def to_a # Rather use collect? grep for to_a.collect
	l = []
	each{|k,v| l << [k,v]}
	return l
      end

      def to_s
	l = []
	each{|k,v| l << "#{k} => #{v}"}
	"{ "+l.join(", ")+" }"
      end
    end
  end
end
# This adds a nice scrub method to Hpricot, so we don't need a _HTMLSanitizer class
# http://underpantsgnome.com/2007/01/20/hpricot-scrub
# I have modified it to check for attributes that are only allowed if they are in a certain tag
module Hpricot
  Acceptable_Elements = ['a', 'abbr', 'acronym', 'address', 'area', 'b',
      'big', 'blockquote', 'br', 'button', 'caption', 'center', 'cite',
      'code', 'col', 'colgroup', 'dd', 'del', 'dfn', 'dir', 'div', 'dl', 'dt',
      'em', 'fieldset', 'font', 'form', 'h1', 'h2', 'h3', 'h4', 'h5', 'h6',
      'hr', 'i', 'img', 'input', 'ins', 'kbd', 'label', 'legend', 'li', 'map',
      'menu', 'ol', 'optgroup', 'option', 'p', 'pre', 'q', 's', 'samp',
      'select', 'small', 'span', 'strike', 'strong', 'sub', 'sup', 'table',
      'tbody', 'td', 'textarea', 'tfoot', 'th', 'thead', 'tr', 'tt', 'u',
      'ul', 'var'
    ]

    Acceptable_Attributes = ['abbr', 'accept', 'accept-charset', 'accesskey',
      'action', 'align', 'alt', 'axis', 'border', 'cellpadding',
      'cellspacing', 'char', 'charoff', 'charset', 'checked', 'cite', 'class',
      'clear', 'cols', 'colspan', 'color', 'compact', 'coords', 'datetime',
      'dir', 'disabled', 'enctype', 'for', 'frame', 'headers', 'height',
      'href', 'hreflang', 'hspace', 'id', 'ismap', 'label', 'lang',
      'longdesc', 'maxlength', 'media', 'method', 'multiple', 'name',
      'nohref', 'noshade', 'nowrap', 'prompt', 'readonly', 'rel', 'rev',
      'rows', 'rowspan', 'rules', 'scope', 'selected', 'shape', 'size',
      'span', 'src', 'start', 'summary', 'tabindex', 'target', 'title', 
      'type', 'usemap', 'valign', 'value', 'vspace', 'width', 'xml:lang'
    ]

    Unacceptable_Elements_With_End_Tag = ['script', 'applet']

    Acceptable_Css_Properties = ['azimuth', 'background-color',
      'border-bottom-color', 'border-collapse', 'border-color',
      'border-left-color', 'border-right-color', 'border-top-color', 'clear',
      'color', 'cursor', 'direction', 'display', 'elevation', 'float', 'font',
      'font-family', 'font-size', 'font-style', 'font-variant', 'font-weight',
      'height', 'letter-spacing', 'line-height', 'overflow', 'pause',
      'pause-after', 'pause-before', 'pitch', 'pitch-range', 'richness',
      'speak', 'speak-header', 'speak-numeral', 'speak-punctuation',
      'speech-rate', 'stress', 'text-align', 'text-decoration', 'text-indent',
      'unicode-bidi', 'vertical-align', 'voice-family', 'volume',
      'white-space', 'width'
    ]

    # survey of common keywords found in feeds
    Acceptable_Css_Keywords = ['auto', 'aqua', 'black', 'block', 'blue',
    'bold', 'both', 'bottom', 'brown', 'center', 'collapse', 'dashed',
    'dotted', 'fuchsia', 'gray', 'green', '!important', 'italic', 'left',
    'lime', 'maroon', 'medium', 'none', 'navy', 'normal', 'nowrap', 'olive',
    'pointer', 'purple', 'red', 'right', 'solid', 'silver', 'teal', 'top',
    'transparent', 'underline', 'white', 'yellow'
    ]

    Mathml_Elements = ['maction', 'math', 'merror', 'mfrac', 'mi',
    'mmultiscripts', 'mn', 'mo', 'mover', 'mpadded', 'mphantom',
    'mprescripts', 'mroot', 'mrow', 'mspace', 'msqrt', 'mstyle', 'msub',
    'msubsup', 'msup', 'mtable', 'mtd', 'mtext', 'mtr', 'munder',
    'munderover', 'none'
    ]

    Mathml_Attributes = ['actiontype', 'align', 'columnalign', 'columnalign',
    'columnalign', 'columnlines', 'columnspacing', 'columnspan', 'depth',
    'display', 'displaystyle', 'equalcolumns', 'equalrows', 'fence',
    'fontstyle', 'fontweight', 'frame', 'height', 'linethickness', 'lspace',
    'mathbackground', 'mathcolor', 'mathvariant', 'mathvariant', 'maxsize',
    'minsize', 'other', 'rowalign', 'rowalign', 'rowalign', 'rowlines',
    'rowspacing', 'rowspan', 'rspace', 'scriptlevel', 'selection',
    'separator', 'stretchy', 'width', 'width', 'xlink:href', 'xlink:show',
    'xlink:type', 'xmlns', 'xmlns:xlink'
    ]

    # svgtiny - foreignObject + linearGradient + radialGradient + stop
    Svg_Elements = ['a', 'animate', 'animateColor', 'animateMotion',
    'animateTransform', 'circle', 'defs', 'desc', 'ellipse', 'font-face',
    'font-face-name', 'font-face-src', 'g', 'glyph', 'hkern', 'image',
    'linearGradient', 'line', 'metadata', 'missing-glyph', 'mpath', 'path',
    'polygon', 'polyline', 'radialGradient', 'rect', 'set', 'stop', 'svg',
    'switch', 'text', 'title', 'use'
    ]

    # svgtiny + class + opacity + offset + xmlns + xmlns:xlink
    Svg_Attributes = ['accent-height', 'accumulate', 'additive', 'alphabetic',
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
     'xml:space', 'xmlns', 'xmlns:xlink', 'y', 'y1', 'y2', 'zoomAndPan'
    ]

    Svg_Attr_Map = nil
    Svg_Elem_Map = nil

    Acceptable_Svg_Properties = [ 'fill', 'fill-opacity', 'fill-rule',
      'stroke', 'stroke-width', 'stroke-linecap', 'stroke-linejoin',
      'stroke-opacity'
    ]

    unless $compatible 
      @@acceptable_tag_specific_attributes = {}
      @@mathml_elements.each{|e| @@acceptable_tag_specific_attributes[e] = @@mathml_attributes }
      @@svg_elements.each{|e| @@acceptable_tag_specific_attributes[e] = @@svg_attributes }
    end

  class Elements 
    def strip(allowed_tags=[]) # I completely route around this with the recursive_strip in Doc
      each { |x| x.strip(allowed_tags) }
    end

    def strip_attributes(safe=[])
      each { |x| x.strip_attributes(safe) }
    end

    def strip_style(ok_props=[], ok_keywords=[])
      each { |x| x.strip_style(ok_props, ok_keywords) }
    end
  end

  class Text
    def strip(foo)
    end
    def strip_attributes(foo)
    end
  end
  class Comment
    def strip(foo)
    end
    def strip_attributes(foo)
    end
  end
  class BogusETag
    def strip(foo)
    end
    def strip_attributes(foo)
    end
  end

  class Elem
    def decode_entities
      children.each{ |x| x.decode_entities }
    end

    def cull
      if children
	swap(children.to_s)
      end
    end

    def strip
      if strip_removes?
	cull
      end
    end

    def strip_attributes
      unless attributes.nil?
	attributes.each do |atr|
	  unless Acceptable_Attributes.include?atr[0] 
	    remove_attribute(atr[0]) 
	  end
	end
      end
    end

    def strip_removes?
      # I'm sure there are others that shuould be ripped instead of stripped
      attributes && attributes['type'] =~ /script|css/
    end
  end
end

module FeedParser
  Version = "0.1aleph_naught"

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

  Author = "Mark Pilgrim <http://diveintomark.org/>"
  Contributors = [  "Jeff Hodges <http://somethingsimilar.com>",
		    "Jason Diamond <http://injektilo.org/>",
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
      if key == 'categories'
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
    attr_accessor :feeddata, :version, :namespacesInUse, :date_handlers

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
      @date_handlers = [:_parse_date_rfc822,
	:_parse_date_hungarian, :_parse_date_greek,:_parse_date_mssql,
	:_parse_date_nate,:_parse_date_onblog,:_parse_date_w3dtf,:_parse_date_iso8601
      ]
      $stderr << "Leaving startup\n" if $debug # My addition
    end

    def unknown_starttag(tag, attrsd)
      $stderr << "start #{tag} with #{attrsd}\n" if $debug
      # normalize attrs
      attrsD = {}
      attrsd = Hash[*attrsd.flatten] if attrsd.class == Array # Magic! Asterisk!
      # LooseFeedParser needs the above because SGMLParser sends attrs as a 
      # list of lists (like [['type','text/html'],['mode','escaped']])

      attrsd.each do |old_k,value| 
	# There has to be a better, non-ugly way of doing this
	k = old_k.downcase # Downcase all keys
	attrsD[k] = value
	if ['rel','type'].include?value
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
	  @feeddata['language'] = lang.gsub('_','-')
	end
      end
      @lang = lang
      @basestack << @baseuri 
      @langstack << lang

      # track namespaces
      attrsd.each do |prefix, uri|
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
	attrsA = attrsd.to_a.collect{|l| "#{l[0]}=\"#{l[1]}\""}
	attrsS = ' '+attrsA.join(' ')
	return handle_data("<#{tag}#{attrsS}>", escape=false) 
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
	return send('_start_'+prefix+suffix, attrsD)
      rescue NoMethodError
	return push(prefix + suffix, true) 
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
	send('_end_' + prefix + suffix) # NOTE no return here! do not add it!
      rescue NoMethodError => details
	pop(prefix + suffix)
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

    def handle_charref(ref)
      # LooseParserOnly 
      # called for each character reference, e.g. for '&#160;', ref will be '160'
      $stderr << "entering handle_charref with #{ref}\n" if $debug
      return if @elementstack.nil? or @elementstack.empty? 
      ref.downcase!
      chars = ['34', '38', '39', '60', '62', 'x22', 'x26', 'x27', 'x3c', 'x3e']
      if chars.include?ref
	text = "&##{ref};"
      else
	if ref[0..0] == 'x'
	  c = (ref[1..-1]).to_i(16)
	else
	  c = ref.to_i
	end
	text = uconvert(unichr(c),'unicode')
      end
      @elementstack[-1][2] << text
    end

    def handle_entityref(ref)
      # LooseParserOnly
      # called for each entity reference, e.g. for '&copy;', ref will be 'copy'

      return if @elementstack.nil? or @elementstack.empty?
      $stderr << "entering handle_entityref with #{ref}\n" if $debug
      ents = ['lt', 'gt', 'quot', 'amp', 'apos']
      if ents.include?ref
	text = "&#{ref};"
      else
	text = HTMLEntities::decode_entities("&#{ref};")
      end
      @elementstack[-1][2] << text
    end

    def handle_data(text, escape=true)
      # called for each block of plain text, i.e. outside of any tag and
      # not containing any character or entity references
      return if @elementstack.nil? or @elementstack.empty?
      if escape and @contentparams['type'] == 'application/xhtml+xml'
	text = text.to_xs 
      end
      @elementstack[-1][2] << text
    end

    def handle_comment(comment)
      # called for each comment, e.g. <!-- insert message here -->
    end

    def handle_pi(text)
    end

    def handle_decl(text)
    end

    def parse_declaration(i)
      # for LooseFeedParser
      $stderr << "entering parse_declaration\n" if $debug
      if @rawdata[i...i+9] == '<![CDATA['
	k = @rawdata.index(/\]\]>/u,i+9)
	k = @rawdata.length unless k
	handle_data(@rawdata[i+9...k].to_xs,false)
	return k+3
      else
	k = @rawdata.index(/>/,i).to_i
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
      if pieces.class == Array
	output = pieces.join('')
      else
	output = pieces
      end
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
	output = uconvert(output, @encoding, 'utf-8') 
	# FIXME I turn everything into utf-8, not unicode, originally because REXML was being used but now beause I haven't tested it out yet.
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
	    contentparams = Marshal.load(Marshal.dump(@contentparams))
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
      _cdf_common(attrsD)
    end
    alias :_start_feedinfo :_start_channel

    def _cdf_common(attrsD)
      if attrsD.has_key?'lastmod'
	_start_modified({})
	@elementstack[-1][-1] = attrsD['lastmod']
	_end_modified
      end
      if attrsD.has_key?'href'
	_start_link({})
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
      push('author', true)
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
	author = context[key].dup unless context[key].nil?
	return if not author or author.empty?
	emailmatch = author.match(/(([a-zA-Z0-9\_\-\.\+]+)@((\[[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.)|(([a-zA-Z0-9\-]+\.)+))([a-zA-Z]{2,4}|[0-9]{1,3})(\]?))/)
	email = emailmatch[1]
	author.gsub!(email, '')
	author.gsub!("\(\)", '')
	author.strip!
	author.gsub!(/^\(/,'')
		     author.gsub!(/\)$/,'')
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

    def _start_dc_publisher(attrsD)
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
      value = pop('published')
      _save('published_parsed', parse_date(value))
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
      _save('updated_parsed', parse_date(value))
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
      _save('created_parsed', parse_date(value))
    end
    alias :_end_dcterms_created :_end_created

    def _start_expirationdate(attrsD)
      push('expired', true)
    end
    def _end_expirationdate
      _save('expired_parsed', parse_date(pop('expired')))
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
      context['tags'] ||= []
      tags = context['tags']
      if (term.nil? or term.empty?) and (scheme.nil? or scheme.empty?) and (label.nil? or label.empty?)
	return
      end
      value = FeedParserDict.new({'term' => term, 'scheme' => scheme, 'label' => label})
      if not tags.include?value
	context['tags'] << FeedParserDict.new({'term' => term, 'scheme' => scheme, 'label' => label})
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
      context = getContext()
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
      @guidislink = ((attrsD['ispermalink'] || 'true') == 'true')
      push('id', true)
    end

    def _end_guid
      value = pop('id')
      _save('guidislink', (@guidislink and not getContext().has_key?('link')))
      if @guidislink:
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
	@elementstack[-1][2] << value
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
      getContext()['enclosures'] ||= []
      getContext()['enclosures'] << FeedParserDict.new(attrsD)
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
      getContext()['image'] = FeedParserDict.new({'href' => attrsD['href']})
    end
    alias :_start_itunes_link :_start_itunes_image

    def _end_itunes_block
      value = pop('itunes_block', false)
      getContext()['itunes_block'] = (value == 'yes') and true or false
    end

    def _end_itunes_explicit
      value = pop('itunes_explicit', false)
      getContext()['itunes_explicit'] = (value == 'yes') and true or false
    end


    # ISO-8601 date parsing routines written by Fazal Majid.
    # The ISO 8601 standard is very convoluted and irregular - a full ISO 8601
    # parser is beyond the scope of feedparser and the current Time.iso8601 
    # method does not work.  
    # A single regular expression cannot parse ISO 8601 date formats into groups
    # as the standard is highly irregular (for instance is 030104 2003-01-04 or
    # 0301-04-01), so we use templates instead.
    # Please note the order in templates is significant because we need a
    # greedy match.
    def _parse_date_iso8601(dateString)
      # Parse a variety of ISO-8601-compatible formats like 20040105

      # What I'm about to show you may be the ugliest code in all of 
      # rfeedparser.
      # FIXME The century regexp maybe not work ('\d\d$' says "two numbers at 
      # end of line" but we then attach more of a regexp.  
      iso8601_regexps = [ '^(\d{4})-?([01]\d)-([0123]\d)',
		      '^(\d{4})-([01]\d)',
		      '^(\d{4})-?([0123]\d\d)',
		      '^(\d\d)-?([01]\d)-?([0123]\d)',
		      '^(\d\d)-?([0123]\d\d)',
		      '^(\d{4})',
		      '-(\d\d)-?([01]\d)',
		      '-([0123]\d\d)',
		      '-(\d\d)',
		      '--([01]\d)-?([0123]\d)',
		      '--([01]\d)',
		      '---([0123]\d)',
		      '(\d\d$)',
		      ''
      ]
      iso8601_values = { '^(\d{4})-?([01]\d)-([0123]\d)' => ['year', 'month', 'day'],
		  '^(\d{4})-([01]\d)' => ['year','month'], 
		  '^(\d{4})-?([0123]\d\d)' => ['year', 'ordinal'],
		  '^(\d\d)-?([01]\d)-?([0123]\d)' => ['year','month','day'], 
		  '^(\d\d)-?([0123]\d\d)' => ['year','ordinal'],
		  '^(\d{4})' => ['year'],
		  '-(\d\d)-?([01]\d)' => ['year','month'], 
		  '-([0123]\d\d)' => ['ordinal'], 
		  '-(\d\d)' => ['year'],
		  '--([01]\d)-?([0123]\d)' => ['month','day'],
		  '--([01]\d)' => ['month'],
		  '---([0123]\d)' => ['day'],
		  '(\d\d$)' => ['century'], 
		  '' => []
      }
      add_to_all = '(T?(\d\d):(\d\d)(?::(\d\d))?([+-](\d\d)(?::(\d\d))?|Z)?)?'
      add_to_all_fields = ['hour', 'minute', 'second', 'tz', 'tzhour', 'tzmin'] 
      # NOTE We use '(?:' to prevent grouping of optional matches (ones trailed
      # by '?'). The second ':' *are* matched.
      m = nil
      param_keys = []
      iso8601_regexps.each do |s|
	$stderr << "Trying iso8601 regexp: #{s+add_to_all}\n" if $debug
	param_keys = iso8601_values[s] + add_to_all_fields
	m = dateString.match(Regexp.new(s+add_to_all))
	break if m
      end
      return if m.nil? or (m.begin(0).zero? and m.end(0).zero?) 

      param_values = m.to_a
      param_values = param_values[1..-1] 
      params = {}
      param_keys.each_with_index do |key,i|
	params[key] = param_values[i]
      end

      ordinal = params['ordinal'].to_i unless params['ordinal'].nil?
      year = params['year'] || '--'
      if year.nil? or year.empty? or year == '--' # FIXME When could the regexp ever return a year equal to '--'?
	year = Time.now.utc.year
      elsif year.length == 2
	# ISO 8601 assumes current century, i.e. 93 -> 2093, NOT 1993
	year = 100 * (Time.now.utc.year / 100) + year.to_i
      else
	year = year.to_i
      end

      month = params['month'] || '-'
      if month.nil? or month.empty? or month == '-'
	# ordinals are NOT normalized by mktime, we simulate them
	# by setting month=1, day=ordinal
	if ordinal
	  month = DateTime.ordinal(year,ordinal).month
	else
	  month = Time.now.utc.month
	end
      end
      month = month.to_i unless month.nil?
      day = params['day']
      if day.nil? or day.empty?
	# see above
	if ordinal
	  day = DateTime.ordinal(year,ordinal).day
	elsif params['century'] or params['year'] or params['month']
	  day = 1
	else
	  day = Time.now.utc.day
	end
      else
	day = day.to_i
      end
      # special case of the century - is the first year of the 21st century
      # 2000 or 2001 ? The debate goes on...
      if params.has_key? 'century'
	year = (params['century'].to_i - 1) * 100 + 1
      end
      # in ISO 8601 most fields are optional
      hour = params['hour'].to_i 
      minute = params['minute'].to_i 
      second = params['second'].to_i 
      weekday = nil
      # daylight savings is complex, but not needed for feedparser's purposes
      # as time zones, if specified, include mention of whether it is active
      # (e.g. PST vs. PDT, CET). Using -1 is implementation-dependent and
      # and most implementations have DST bugs
      tm = [second, minute, hour, day, month, year, nil, ordinal, false, nil]
      tz = params['tz']
      if tz and not tz.empty? and tz != 'Z'
	# FIXME does this cross over days?
	if tz[0] == '-'
	  tm[3] += params['tzhour'].to_i
	tm[4] += params['tzmin'].to_i
	elsif tz[0] == '+'
	  tm[3] -= params['tzhour'].to_i
	  tm[4] -= params['tzmin'].to_i
	else
	  return nil
	end
      end
      return Time.utc(*tm) # Magic!

    end

    def _parse_date_onblog(dateString)
      # Parse a string according to the OnBlog 8-bit date format
      # 8-bit date handling routes written by ytrewq1
      korean_year  = u("년") # b3e2 in euc-kr
      korean_month = u("월") # bff9 in euc-kr
      korean_day   = u("일") # c0cf in euc-kr


      korean_onblog_date_re = /(\d{4})#{korean_year}\s+(\d{2})#{korean_month}\s+(\d{2})#{korean_day}\s+(\d{2}):(\d{2}):(\d{2})/


	m = korean_onblog_date_re.match(dateString)
      return unless m
      w3dtfdate = "#{m[1]}-#{m[2]}-#{m[3]}T#{m[4]}:#{m[5]}:#{m[6]}+09:00"

      $stderr << "OnBlog date parsed as: %s\n" % w3dtfdate if $debug
      return _parse_date_w3dtf(w3dtfdate)
    end

    def _parse_date_nate(dateString)
      # Parse a string according to the Nate 8-bit date format
      # 8-bit date handling routes written by ytrewq1
      korean_am    = u("오전") # bfc0 c0fc in euc-kr
      korean_pm    = u("오후") # bfc0 c8c4 in euc-kr

      korean_nate_date_re = /(\d{4})-(\d{2})-(\d{2})\s+(#{korean_am}|#{korean_pm})\s+(\d{0,2}):(\d{0,2}):(\d{0,2})/
	m = korean_nate_date_re.match(dateString)
      return unless m
      hour = m[5].to_i
      ampm = m[4]
      if ampm == korean_pm
	hour += 12
      end
      hour = hour.to_s.rjust(2,'0') 
      w3dtfdate = "#{m[1]}-#{m[2]}-#{m[3]}T#{hour}:#{m[6]}:#{m[7]}+09:00"
      $stderr << "Nate date parsed as: %s\n" % w3dtfdate if $debug
      return _parse_date_w3dtf(w3dtfdate)
    end

    def _parse_date_mssql(dateString)
      mssql_date_re = /(\d{4})-(\d{2})-(\d{2})\s+(\d{2}):(\d{2}):(\d{2})(\.\d+)?/

	m = mssql_date_re.match(dateString)
      return unless m
      w3dtfdate =  "#{m[1]}-#{m[2]}-#{m[3]}T#{m[4]}:#{m[5]}:#{m[6]}+09:00"
      $stderr << "MS SQL date parsed as: %s\n" % w3dtfdate if $debug
      return _parse_date_w3dtf(w3dtfdate)
    end

    def _parse_date_greek(dateString)
      # Parse a string according to a Greek 8-bit date format
      # Unicode strings for Greek date strings
      greek_months = { 
	u("Ιαν") => u("Jan"),       # c9e1ed in iso-8859-7
	u("Φεβ") => u("Feb"),       # d6e5e2 in iso-8859-7
	u("Μάώ") => u("Mar"),       # ccdcfe in iso-8859-7
	u("Μαώ") => u("Mar"),       # cce1fe in iso-8859-7
	u("Απρ") => u("Apr"),       # c1f0f1 in iso-8859-7
	u("Μάι") => u("May"),       # ccdce9 in iso-8859-7
	u("Μαϊ") => u("May"),       # cce1fa in iso-8859-7
	u("Μαι") => u("May"),       # cce1e9 in iso-8859-7
	u("Ιούν") => u("Jun"), # c9effded in iso-8859-7
	u("Ιον") => u("Jun"),       # c9efed in iso-8859-7
	u("Ιούλ") => u("Jul"), # c9effdeb in iso-8859-7
	u("Ιολ") => u("Jul"),       # c9f9eb in iso-8859-7
	u("Αύγ") => u("Aug"),       # c1fde3 in iso-8859-7
	u("Αυγ") => u("Aug"),       # c1f5e3 in iso-8859-7
	u("Σεπ") => u("Sep"),       # d3e5f0 in iso-8859-7
	u("Οκτ") => u("Oct"),       # cfeaf4 in iso-8859-7
	u("Νοέ") => u("Nov"),       # cdefdd in iso-8859-7
	u("Νοε") => u("Nov"),       # cdefe5 in iso-8859-7
	u("Δεκ") => u("Dec"),       # c4e5ea in iso-8859-7
      }

      greek_wdays =   { 
	u("Κυρ") => u("Sun"), # caf5f1 in iso-8859-7
	u("Δευ") => u("Mon"), # c4e5f5 in iso-8859-7
	u("Τρι") => u("Tue"), # d4f1e9 in iso-8859-7
	u("Τετ") => u("Wed"), # d4e5f4 in iso-8859-7
	u("Πεμ") => u("Thu"), # d0e5ec in iso-8859-7
	u("Παρ") => u("Fri"), # d0e1f1 in iso-8859-7
	u("Σαβ") => u("Sat"), # d3e1e2 in iso-8859-7   
      }

      greek_date_format = /([^,]+),\s+(\d{2})\s+([^\s]+)\s+(\d{4})\s+(\d{2}):(\d{2}):(\d{2})\s+([^\s]+)/

	m = greek_date_format.match(dateString)
      return unless m
      begin
	wday = greek_wdays[m[1]]
	month = greek_months[m[3]]
      rescue
	return nil
      end
      rfc822date = "#{wday}, #{m[2]} #{month} #{m[4]} #{m[5]}:#{m[6]}:#{m[7]} #{m[8]}" 
      $stderr << "Greek date parsed as: #{rfc822date}\n" if $debug
      return _parse_date_rfc822(rfc822date) 
    end

    def _parse_date_hungarian(dateString)
      # Parse a string according to a Hungarian 8-bit date format.
      hungarian_date_format_re = /(\d{4})-([^-]+)-(\d{0,2})T(\d{0,2}):(\d{2})((\+|-)(\d{0,2}:\d{2}))/
	m = hungarian_date_format_re.match(dateString)
      return unless m

      # Unicode strings for Hungarian date strings
      hungarian_months = { 
	u("január") =>   u("01"),  # e1 in iso-8859-2
	u("februári") => u("02"),  # e1 in iso-8859-2
	u("március") =>  u("03"),  # e1 in iso-8859-2
	u("április") =>  u("04"),  # e1 in iso-8859-2
	u("máujus") =>   u("05"),  # e1 in iso-8859-2
	u("június") =>   u("06"),  # fa in iso-8859-2
	u("július") =>   u("07"),  # fa in iso-8859-2
	u("augusztus") =>     u("08"),
	u("szeptember") =>    u("09"),
	u("október") =>  u("10"),  # f3 in iso-8859-2
	u("november") =>      u("11"),
	u("december") =>      u("12"),
      }
      begin
	month = hungarian_months[m[2]]
	day = m[3].rjust(2,'0')
	hour = m[4].rjust(2,'0')
      rescue
	return
      end

      w3dtfdate = "#{m[1]}-#{month}-#{day}T#{hour}:#{m[5]}:00#{m[6]}"
      $stderr << "Hungarian date parsed as: #{w3dtfdate}\n" if $debug
      return _parse_date_w3dtf(w3dtfdate)
    end

    def rollover(num, modulus)
      return num % modulus, num / modulus
    end

    def set_self(num, modulus)
      r = num / modulus
      if r == 0
	return num
      end
      return r
    end
    # W3DTF-style date parsing
    # FIXME shouldn't it be "W3CDTF"?
    def _parse_date_w3dtf(dateString)
      # Ruby's Time docs claim w3cdtf is an alias for iso8601 which is an alias for xmlschema
      # Whatever it is, it doesn't work.  This has been fixed in Ruby 1.9 and 
      # in Ruby on Rails, but not really. They don't fix the 25 hour or 61 minute or 61 second rollover and fail in other ways.

      m = dateString.match(/^(\d{4})-?(?:(?:([01]\d)-?(?:([0123]\d)(?:T(\d\d):(\d\d):(\d\d)([+-]\d\d:\d\d|Z))?)?)?)?/)

      w3 = m[1..3].map{|s| s=s.to_i; s += 1 if s == 0;s}  # Map the year, month and day to integers and, if they were nil, set them to 1
      w3 += m[4..6].map{|s| s.to_i}			  # Map the hour, minute and second to integers
      w3 << m[-1]					  # Leave the timezone as a String

      # FIXME this next bit needs some serious refactoring
      # Rollover times. 0 minutes and 61 seconds -> 1 minute and 1 second
      w3[5],r = rollover(w3[5], 60)     # rollover seconds
      w3[4] += r
      w3[4],r = rollover(w3[4], 60)      # rollover minutes
      w3[3] += r
      w3[3],r = rollover(w3[3], 24)      # rollover hours

      w3[2] = w3[2] + r
      if w3[1] > 12
	w3[1],r = rollover(w3[1],12)
	w3[1] = 12 if w3[1] == 0
	w3[0] += r
      end

      num_days = Time.days_in_month(w3[1], w3[0])
      while w3[2] > num_days
	w3[2] -= num_days
	w3[1] += 1
	if w3[1] > 12
	  w3[0] += 1
	  w3[1] = set_self(w3[1], 12)
	end
	num_days = Time.days_in_month(w3[1], w3[0])
      end


      unless w3[6].class != String
	if /^-/ =~ w3[6] # Zone offset goes backwards
	  w3[6][0] = '+'
	elsif /^\+/ =~ w3[6]
	  w3[6][0] = '-'
	end
      end
      return Time.utc(w3[0], w3[1], w3[2] , w3[3], w3[4], w3[5])+Time.zone_offset(w3[6] || "UTC")
    end

    def _parse_date_rfc822(dateString)
      # Parse an RFC822, RFC1123, RFC2822 or asctime-style date 
      # These first few lines are to fix up the stupid proprietary format from Disney
      unknown_timezones = { 'AT' => 'EDT', 'ET' => 'EST', 
			'CT' => 'CST', 'MT' => 'MST', 
			'PT' => 'PST' 
      }

      mon = dateString.split[2]
      if mon.length > 3 and Time::RFC2822_MONTH_NAME.include?mon[0..2]
	dateString.sub!(mon,mon[0..2])
      end
      if dateString[-3..-1] != "GMT" and unknown_timezones[dateString[-2..-1]]
	dateString[-2..-1] = unknown_timezones[dateString[-2..-1]]
      end
      # Okay, the Disney date format should be fixed up now.
      rfc = dateString.match(/([A-Za-z]{3}), ([0123]\d) ([A-Za-z]{3}) (\d{4})( (\d\d):(\d\d)(?::(\d\d))? ([A-Za-z]{3}))?/)
      if rfc.to_a.length > 1 and rfc.to_a.include? nil
	dow, day, mon, year, hour, min, sec, tz = rfc[1..-1]
	hour,min,sec = [hour,min,sec].map{|e| e.to_s.rjust(2,'0') }
	tz ||= "GMT"
      end
      asctime_match = dateString.match(/([A-Za-z]{3}) ([A-Za-z]{3})  (\d?\d) (\d\d):(\d\d):(\d\d) ([A-Za-z]{3}) (\d\d\d\d)/).to_a
      if asctime_match.to_a.length > 1
	# Month-abbr dayofmonth hour:minute:second year
	dow, mon, day, hour, min, sec, tz, year = asctime_match[1..-1]
	day.to_s.rjust(2,'0')
      end
      if (rfc.to_a.length > 1 and rfc.to_a.include? nil) or asctime_match.to_a.length > 1
	ds = "#{dow}, #{day} #{mon} #{year} #{hour}:#{min}:#{sec} #{tz}"
      else
	ds = dateString
      end
      t = Time.rfc2822(ds).utc
      return t
    end

    def _parse_date_perforce(aDateString) # FIXME not in 4.1?
      # Parse a date in yyyy/mm/dd hh:mm:ss TTT format
      # Note that there is a day of the week at the beginning 
      # Ex. Fri, 2006/09/15 08:19:53 EDT
      return Time.parse(aDateString).utc
    end

    def extract_tuple(atime)
      # NOTE leave the error handling to parse_date
      t = [atime.year, atime.month, atime.mday, atime.hour,
	atime.min, atime.sec, (atime.wday-1) % 7, atime.yday,
	atime.isdst
      ]
      # yay for modulus! yaaaaaay!  its 530 am and i should be sleeping! yaay!
      t[0..-2].map!{|s| s.to_i}
      t[-1] = t[-1] ? 1 : 0
      return t
    end

    def parse_date(dateString)
      @date_handlers.each do |handler|
	begin 
	  $stderr << "Trying date_handler #{handler}\n" if $debug
	  datething = extract_tuple(send(handler,dateString))
	  return datething
	rescue Exception => e
	  $stderr << "#{handler} raised #{e}\n" if $debug
	end
      end
      return nil
    end

  end # End FeedParserMixin

  class StrictFeedParser < XML::SAX::HandlerBase # expat
    include FeedParserMixin

    attr_accessor :bozo, :entries, :feeddata, :exc
    def initialize(baseuri, baselang, encoding)
      $stderr << "trying StrictFeedParser\n" if $debug
      startup(baseuri, baselang, encoding) 
      @bozo = false
      @exc = nil
      super()
    end

    def getPos
      [@locator.getSystemId, @locator.getLineNumber]
    end

    def getAttrs(attrs)
      ret = []
      for i in 0..attrs.getLength
	ret.push([attrs.getName(i), attrs.getValue(i)])
      end
      ret
    end

    def setDocumentLocator(loc)
      @locator = loc
    end

    def startDoctypeDecl(name, pub_sys, long_name, uri)   
      #Nothing is done here. What could we do that is neat and useful?
    end

    def startNamespaceDecl(prefix, uri)
      trackNamespace(prefix, uri)
    end

    def endNamespaceDecl(prefix)
    end

    def startElement(name, attrs)
      name =~ /^(([^;]*);)?(.+)$/ # Snag namespaceuri from name
	namespaceuri = ($2 || '').downcase
      name = $3
      if /backend\.userland\.com\/rss/ =~ namespaceuri
	# match any backend.userland.com namespace
	namespaceuri = 'http://backend.userland.com/rss'
      end
      prefix = @matchnamespaces[namespaceuri] 
      # No need to raise UndeclaredNamespace, Expat does that for us with
      "unbound prefix (XMLParserError)"
      if prefix and not prefix.empty?
	name = prefix + ':' + name
      end
      name.downcase!
      unknown_starttag(name, attrs)
    end

    def character(text, start, length)       
      #handle_data(CGI.unescapeHTML(text))
      handle_data(text)
    end
    # expat provides "character" not "characters"!
    alias :characters :character # Just in case.

    def startCdata(content)
      handle_data(content)
    end

    def endElement(name) 
      name =~ /^(([^;]*);)?(.+)$/ # Snag namespaceuri from name
	namespaceuri = ($2 || '').downcase
      prefix = @matchnamespaces[namespaceuri]
      if prefix and not prefix.empty?
	localname = prefix + ':' + name
      end
      name.downcase!
      unknown_endtag(name)
    end

    def comment(comment)
      handle_comment(comment)
    end

    def entityDecl(*foo)
    end

    def unparsedEntityDecl(*foo)
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

  class LooseFeedParser < BetterSGMLParser 
    include FeedParserMixin
    # We write the methods that were in BaseHTMLProcessor in the python code
    # in here directly. We do this because if we inherited from 
    # BaseHTMLProcessor but then included from FeedParserMixin, the methods 
    # of Mixin would overwrite the methods we inherited from 
    # BaseHTMLProcessor. This is exactly the opposite of what we want to 
    # happen!

    attr_accessor :encoding, :bozo, :feeddata, :entries, :namespacesInUse

    Elements_No_End_Tag = ['area', 'base', 'basefont', 'br', 'col', 'frame', 'hr',
      'img', 'input', 'isindex', 'link', 'meta', 'param']
    New_Declname_Re = /[a-zA-Z][-_.a-zA-Z0-9:]*\s*/
      alias :sgml_feed :feed # feed needs to mapped to feeddata, not the SGMLParser method feed. I think.
    def feed       
      @feeddata
    end
    def feed=(data)
      @feeddata = data
    end

    def initialize(baseuri, baselang, encoding)
      startup(baseuri, baselang, encoding)
      super() # Keep the parentheses! No touchy.
    end

    def reset
      @pieces = []
      super
    end

    def parse(data)
      data.gsub!(/<!((?!DOCTYPE|--|\[))/i,  '&lt;!\1')
	data.gsub!(/<([^<\s]+?)\s*\/>/) do |tag|
	  clean = tag[1..-3].strip
	  if Elements_No_End_Tag.include?clean
	    tag
	  else
	  '<'+clean+'></'+clean+'>'
	  end
	end

	data.gsub!(/&#39;/, "'")
	  data.gsub!(/&#34;/, "'")
	  if @encoding and not @encoding.empty? # FIXME unicode check type(u'')
	    data = uconvert(data,'utf-8',@encoding)
	  end
	sgml_feed(data) # see the alias above
    end


    def decodeEntities(element, data)
      data.gsub!('&#60;', '&lt;')
      data.gsub!('&#x3c;', '&lt;')
      data.gsub!('&#62;', '&gt;')
      data.gsub!('&#x3e;', '&gt;')
      data.gsub!('&#38;', '&amp;')
      data.gsub!('&#x26;', '&amp;')
      data.gsub!('&#34;', '&quot;')
      data.gsub!('&#x22;', '&quot;')
      data.gsub!('&#39;', '&apos;')
      data.gsub!('&#x27;', '&apos;')
      if @contentparams.has_key? 'type' and not ((@contentparams['type'] || 'xml') =~ /xml$/u)
	data.gsub!('&lt;', '<')
	data.gsub!('&gt;', '>')
	data.gsub!('&amp;', '&')
	data.gsub!('&quot;', '"')
	data.gsub!('&apos;', "'")
      end
      return data
    end
  end

  def FeedParser.resolveRelativeURIs(htmlSource, baseURI, encoding)
    $stderr << "entering resolveRelativeURIs\n" if $debug # FIXME write a decent logger
    relative_uris = [ ['a','href'],
      ['applet','codebase'],
      ['area','href'],
      ['blockquote','cite'],
      ['body','background'],
      ['del','cite'],
      ['form','action'],
      ['frame','longdesc'],
      ['frame','src'],
      ['iframe','longdesc'],
      ['iframe','src'],
      ['head','profile'],
      ['img','longdesc'],
      ['img','src'],
      ['img','usemap'],
      ['input','src'],
      ['input','usemap'],
      ['ins','cite'],
      ['link','href'],
      ['object','classid'],
      ['object','codebase'],
      ['object','data'],
      ['object','usemap'],
      ['q','cite'],
      ['script','src'],
    ]
    h = Hpricot(htmlSource)
    relative_uris.each do |l|
      ename, eattr = l
      h.search(ename).each do |elem|
	euri = elem.attributes[eattr]
	if euri and not euri.empty? and URI.parse(euri).relative?
	  elem.attributes[eattr] = urljoin(baseURI, euri)
	end
      end
    end
    return h.to_html
  end

  class SanitizerDoc < Hpricot::Doc
    
    def scrub
      traverse_all_element do |e| 
	if e.elem? 
	  if Acceptable_Elements.include?e.name
	    e.strip_attributes
	  else
	    if Unacceptable_Elements_With_End_Tag.include?e.name
	      e.inner_html = ''
	    end
	    e.swap(SanitizerDoc.new(e.children).scrub.to_html)
	    # This works because the children swapped in are brought in "after" the current element.
	  end
	elsif e.doctype?
	  e.parent.children.delete(e)
	elsif e.text?
	  ets = e.to_s
	  ets.gsub!(/&#39;/, "'") 
	  ets.gsub!(/&#34;/, '"')
	  ets.gsub!(/\r/,'')
	  e.swap(ets)
	else
	end
      end
      # yes, that '/' should be there. It's a search method. See the Hpricot docs.

      unless $compatible # FIXME not properly recursive, see comment in recursive_strip
	(self/tag).strip_style(@config[:allow_css_properties], @config[:allow_css_keywords])
      end
      return self
    end
  end

  def SanitizerDoc(html)
    FeedParser::SanitizerDoc.new(Hpricot.make(html))
  end
  module_function(:SanitizerDoc)
  def self.sanitizeHTML(html,encoding)
    # FIXME Tidy not yet supported
    html = html.gsub(/<!((?!DOCTYPE|--|\[))/, '&lt;!\1')
      h = SanitizerDoc(html)
      h = h.scrub
      return h.to_html.strip
  end



  def self.getCharacterEncoding(feed, xml_data)
    # Get the character encoding of the XML document
    $stderr << "In getCharacterEncoding\n" if $debug
    sniffed_xml_encoding = nil
    xml_encoding = nil
    true_encoding = nil
    begin 
      http_headers = feed.meta
      http_content_type = feed.meta['content-type'].split(';')[0]
      encoding_scan = feed.meta['content-type'].to_s.scan(/charset\s*=\s*(.*?)(?:"|')*$/)
      http_encoding = encoding_scan.flatten[0].to_s.gsub(/("|')/,'')
      http_encoding = nil if http_encoding.empty?
      # FIXME Open-Uri returns iso8859-1 if there is no charset header,
      # but that doesn't pass the tests. Open-Uri claims its following
      # the right RFC. Are they wrong or do we need to change the tests?
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
      elsif xml_data[0..3] == "\xff\xfe\x00\x00"
	# UTF-32LE with BOM
	sniffed_xml_encoding = 'utf-32le'
	xml_data = uconvert(xml_data[4..-1], 'utf-32le', 'utf-8')
      elsif xml_data[0..2] == "\xef\xbb\xbf"
	# UTF-8 with BOM
	sniffed_xml_encoding = 'utf-8'
	xml_data = xml_data[3..-1]
      else
	# ASCII-compatible
      end
      xml_encoding_match = /^<\?.*encoding=[\'"](.*?)[\'"].*\?>/.match(xml_data)
    rescue
      xml_encoding_match = nil
    end
    if xml_encoding_match 
      xml_encoding = xml_encoding_match[1].downcase
      xencodings = ['iso-10646-ucs-2', 'ucs-2', 'csunicode', 'iso-10646-ucs-4', 'ucs-4', 'csucs4', 'utf-16', 'utf-32', 'utf_16', 'utf_32', 'utf16', 'u16']
      if sniffed_xml_encoding and xencodings.include?xml_encoding
	xml_encoding = sniffed_xml_encoding
      end
    end

    acceptable_content_type = false
    application_content_types = ['application/xml', 'application/xml-dtd', 'application/xml-external-parsed-entity']
    text_content_types = ['text/xml', 'text/xml-external-parsed-entity']

    if application_content_types.include?(http_content_type) or (/^application\// =~ http_content_type and /\+xml$/ =~ http_content_type)
      acceptable_content_type = true
      true_encoding = http_encoding || xml_encoding || 'utf-8'
    elsif text_content_types.include?(http_content_type) or (/^text\// =~ http_content_type and /\+xml$/ =~ http_content_type)
      acceptable_content_type = true
      true_encoding = http_encoding || 'us-ascii'
    elsif /^text\// =~ http_content_type 
      true_encoding = http_encoding || 'us-ascii'
    elsif http_headers and not http_headers.empty? and not http_headers.has_key?'content-type'
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
    if (data.size >= 4 and data[0..1] == "\xfe\xff" and data[2..3] != "\x00\x00")
      if $debug
	$stderr << "stripping BOM\n"
	if encoding != 'utf-16be'
	  $stderr << "string utf-16be instead\n"
	end
      end
      encoding = 'utf-16be'
      data = data[2..-1]
    elsif (data.size >= 4 and data[0..1] == "\xff\xfe" and data[2..3] != "\x00\x00")
      if $debug
	$stderr << "stripping BOM\n"
	$stderr << "trying utf-16le instead\n" if encoding != 'utf-16le'
      end
      encoding = 'utf-16le'
      data = data[2..-1]
    elsif (data[0..2] == "\xef\xbb\xbf")
      if $debug
	$stderr << "stripping BOM\n"
	$stderr << "trying utf-8 instead\n" if encoding != 'utf-8'
      end
      encoding = 'utf-8'
      data = data[3..-1]
    elsif (data[0..3] == "\x00\x00\xfe\xff")
      if $debug
	$stderr << "stripping BOM\n"
	if encoding != 'utf-32be'
	  $stderr << "trying utf-32be instead\n"
	end
      end
      encoding = 'utf-32be'
      data = data[4..-1]
    elsif (data[0..3] == "\xff\xfe\x00\x00")
      if $debug
	$stderr << "stripping BOM\n"
	if encoding != 'utf-32le'
	  $stderr << "trying utf-32le instead\n"
	end
      end
      encoding = 'utf-32le'
      data = data[4..-1]
    end
    begin
      newdata = uconvert(data, encoding, 'utf-8') 
    rescue => details
    end
    $stderr << "successfully converted #{encoding} data to utf-8\n" if $debug
    declmatch = /^<\?xml[^>]*?>/
      newdecl = "<?xml version=\'1.0\' encoding=\'utf-8\'?>"
      if declmatch =~ newdata
	newdata.sub!(declmatch, newdecl) 
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
    entity_pattern = /<!ENTITY(.*?)>/m # m is for Regexp::MULTILINE
    data = data.gsub(entity_pattern,'')

    doctype_pattern = /<!DOCTYPE(.*?)>/m
    doctype_results = data.scan(doctype_pattern)
    if doctype_results and doctype_results[0]
      doctype = doctype_results[0][0]
    else
      doctype = ''
    end

    if /netscape/ =~ doctype.downcase
      version = 'rss091n'
    else
      version = nil
    end
    data = data.sub(doctype_pattern, '')
    return version, data
  end

  def parse(*args); FeedParser.parse(*args); end
  def FeedParser.parse(furi, options={})
    # Parse a feed from a URL, file, stream or string
    $compatible = options[:compatible] || $compatible # Use the default compatibility if compatible is nil
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
      if URI::parse(furi).class == URI::Generic
	f = open(furi) # OpenURI doesn't behave well when passing HTTP options to a file.
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
      feedparser = StrictFeedParser.new(baseuri, baselang, 'utf-8')
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
      feedparser = LooseFeedParser.new(baseuri, baselang, (known_encoding and 'utf-8' or ''))
      feedparser.parse(data)
      $stderr << "Using LooseFeed\n\n" if $debug
    end
    result['feed'] = feedparser.feeddata
    result['entries'] = feedparser.entries
    result['version'] = result['version'] || feedparser.version
    result['namespaces'] = feedparser.namespacesInUse
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
