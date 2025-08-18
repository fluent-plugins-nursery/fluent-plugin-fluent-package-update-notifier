lib = File.expand_path("../lib", __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)

Gem::Specification.new do |spec|
  spec.name    = "fluent-plugin-fluent-package-update-notifier"
  spec.version = "0.2.0"
  spec.authors = ["Kentaro Hayashi"]
  spec.email   = ["hayashi@clear-code.com"]

  spec.summary       = %q{Notify latest version of fluent-package}
  spec.description   = %q{Notify latest version of fluent-package on startup}
  spec.homepage      = "https://github.com/fluent-plugins-nursery/fluent-plugin-fluent-package-update-notifier"
  spec.license       = "Apache-2.0"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/fluent-plugins-nursery/fluent-plugin-fluent-package-update-notifier"
  spec.metadata["changelog_uri"] = "https://github.com/fluent-plugins-nursery/fluent-plugin-fluent-package-update-notifier/blob/main/CHANGELOG.md"
  spec.metadata["bug_tracker_uri"] = "https://github.com/fluent-plugins-nursery/fluent-plugin-fluent-package-update-notifier/issues"

  spec.metadata['rubygems_mfa_required'] = 'true'

  spec.files         = Dir.chdir(__dir__) do
    `git ls-files -z`.split("\x0").reject do |f|
      (File.expand_path(f) == __FILE__) ||
        f.start_with?(*%w[test/ spec/ features/ .git .circleci appveyor Gemfile])
    end
  end
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_runtime_dependency "specinfra", "~> 2.94.1"

  spec.add_development_dependency "bundler", "~> 2.4"
  spec.add_development_dependency "rake", "~> 13.2.1"
  spec.add_development_dependency "test-unit", "~> 3.0"
  spec.add_development_dependency "test-unit-rr", "~> 1.0.5"
  spec.add_runtime_dependency "fluentd", [">= 0.14.10", "< 2"]

  spec.add_development_dependency "rubocop-fluentd", "~> 0.2.0"
end
