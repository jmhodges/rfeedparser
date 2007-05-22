require 'rubygems'
Gem::manage_gems
require 'rake/gempackagetask'

spec = Gem::Specification.new do |s|
    s.name       = "rfeedparser"
    s.version    = "0.9.9" # Don't forget the Version in rfeedparser.rb
    s.author     = "Jeff Hodges"
    s.email      = "jeff at somethingsimilar dot com"
    s.homepage   = "http://rfeedparser.rubyforge.org/"
    s.platform   = Gem::Platform::RUBY
    s.summary    = "Parse RSS and Atom feeds in Ruby"
    s.files      = FileList["{lib,tests}/**/*"].exclude("rdoc").to_a
    s.require_path      = "lib"
    # s.autorequire       = "feedparser" # tHe 3vil according to Why.
    s.test_file         = "tests/rfeedparsertest.rb"
    s.has_rdoc          = false
    s.extra_rdoc_files  = ['README','LICENSE', 'RUBY-TESTING']
    s.rubyforge_project = 'rfeedparser'

    # Dependencies
    s.add_dependency('rchardet', '>=1.0')
    s.add_dependency('activesupport', '>= 1.4.1')
    s.add_dependency('hpricot', '>= 0.5')
    s.add_dependency('character-encodings', '>= 0.2')
    s.add_dependency('htmltools', '>= 1.10')
    s.add_dependency('htmlentities', '4.0.0')
    s.add_dependency('mongrel', '>=1.0.1')
    s.add_dependency('xmlparser', '0.6.81')

end

task :default => [:package]

Rake::GemPackageTask.new(spec) do |pkg|
    pkg.need_zip = true
end
