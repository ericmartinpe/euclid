# -*- encoding: utf-8 -*-

Gem::Specification.new do |s|
  s.name = "bond"
  s.version = "0.5.1"

  s.required_rubygems_version = Gem::Requirement.new(">= 1.3.6") if s.respond_to? :required_rubygems_version=
  s.authors = ["Gabriel Horner"]
  s.date = "2014-02-08"
  s.description = "Bond is on a mission to improve autocompletion in ruby, especially for irb/ripl. Aside from doing everything irb's can do and fixing its quirks, Bond can autocomplete argument(s) to methods, uniquely completing per module, per method and per argument. Bond brings ruby autocompletion closer to bash/zsh as it provides a configuration system and a DSL for creating custom completions and completion rules. With this configuration system, users can customize their autocompletions and share it with others. Bond can also load completions that ship with gems.  Bond is able to offer more than irb's completion since it uses the full line of input when completing as opposed to irb's last-word approach."
  s.email = "gabriel.horner@gmail.com"
  s.extensions = ["ext/readline_line_buffer/extconf.rb"]
  s.extra_rdoc_files = ["README.rdoc", "LICENSE.txt"]
  s.files = ["README.rdoc", "LICENSE.txt", "ext/readline_line_buffer/extconf.rb"]
  s.homepage = "http://tagaholic.me/bond/"
  s.licenses = ["MIT"]
  s.rdoc_options = ["--title", "Bond 0.5.1 Documentation"]
  s.require_paths = ["lib"]
  s.rubygems_version = "2.0.14"
  s.summary = "Mission: Easy custom autocompletion for arguments, methods and beyond. Accomplished for irb and any other readline-like console environments."

  if s.respond_to? :specification_version then
    s.specification_version = 4

    if Gem::Version.new(Gem::VERSION) >= Gem::Version.new('1.2.0') then
      s.add_development_dependency(%q<bacon>, [">= 1.1.0"])
      s.add_development_dependency(%q<mocha>, ["~> 0.12.1"])
      s.add_development_dependency(%q<mocha-on-bacon>, ["~> 0.2.1"])
      s.add_development_dependency(%q<bacon-bits>, [">= 0"])
    else
      s.add_dependency(%q<bacon>, [">= 1.1.0"])
      s.add_dependency(%q<mocha>, ["~> 0.12.1"])
      s.add_dependency(%q<mocha-on-bacon>, ["~> 0.2.1"])
      s.add_dependency(%q<bacon-bits>, [">= 0"])
    end
  else
    s.add_dependency(%q<bacon>, [">= 1.1.0"])
    s.add_dependency(%q<mocha>, ["~> 0.12.1"])
    s.add_dependency(%q<mocha-on-bacon>, ["~> 0.2.1"])
    s.add_dependency(%q<bacon-bits>, [">= 0"])
  end
end
