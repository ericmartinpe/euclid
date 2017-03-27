# -*- encoding: utf-8 -*-
# stub: ripl-multi_line 0.3.1 ruby lib

Gem::Specification.new do |s|
  s.name = "ripl-multi_line".freeze
  s.version = "0.3.1"

  s.required_rubygems_version = Gem::Requirement.new(">= 1.3.6".freeze) if s.respond_to? :required_rubygems_version=
  s.require_paths = ["lib".freeze]
  s.authors = ["Jan Lelis".freeze]
  s.date = "2013-04-23"
  s.description = "This ripl plugin allows you to evaluate multiple lines of Ruby code.".freeze
  s.email = "mail@janlelis.de".freeze
  s.extra_rdoc_files = ["README.rdoc".freeze, "LICENSE.txt".freeze]
  s.files = ["LICENSE.txt".freeze, "README.rdoc".freeze]
  s.homepage = "http://github.com/janlelis/ripl-multi_line".freeze
  s.licenses = ["MIT".freeze]
  s.rubygems_version = "2.6.7".freeze
  s.summary = "A ripl plugin for multi-line eval.".freeze

  s.installed_by_version = "2.6.7" if s.respond_to? :installed_by_version

  if s.respond_to? :specification_version then
    s.specification_version = 3

    if Gem::Version.new(Gem::VERSION) >= Gem::Version.new('1.2.0') then
      s.add_runtime_dependency(%q<ripl>.freeze, [">= 0.3.6"])
      s.add_development_dependency(%q<bacon>.freeze, [">= 1.1.0"])
      s.add_development_dependency(%q<bacon-bits>.freeze, [">= 0"])
      s.add_development_dependency(%q<bacon-rr>.freeze, [">= 0"])
      s.add_development_dependency(%q<rr>.freeze, [">= 0"])
    else
      s.add_dependency(%q<ripl>.freeze, [">= 0.3.6"])
      s.add_dependency(%q<bacon>.freeze, [">= 1.1.0"])
      s.add_dependency(%q<bacon-bits>.freeze, [">= 0"])
      s.add_dependency(%q<bacon-rr>.freeze, [">= 0"])
      s.add_dependency(%q<rr>.freeze, [">= 0"])
    end
  else
    s.add_dependency(%q<ripl>.freeze, [">= 0.3.6"])
    s.add_dependency(%q<bacon>.freeze, [">= 1.1.0"])
    s.add_dependency(%q<bacon-bits>.freeze, [">= 0"])
    s.add_dependency(%q<bacon-rr>.freeze, [">= 0"])
    s.add_dependency(%q<rr>.freeze, [">= 0"])
  end
end
