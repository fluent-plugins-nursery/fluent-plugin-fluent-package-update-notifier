require 'open-uri'
require 'json'
require 'tmpdir'
require 'rbconfig'

module Fluent
  module Plugin
    module FluentPackage
      class UpdateChecker
        DEFAULT_PACKAGE_CONFIG_PATH = "/opt/fluent/share/config"

        def initialize(options={})
          @logger = options[:logger]
          @options = options
          @newer_versions = []
          @newer_lts_versions = []
          @major_lts_updates = []
          @major_updates = []
          @tmp_dir = Dir.mktmpdir("fluent_package_update_notifier")
          begin
            require ENV["FLUENT_PACKAGE_CONFIG"] || DEFAULT_PACKAGE_CONFIG_PATH
          rescue LoadError
            @logger.error "Failed to load #{ENV["FLUENT_PACKAGE_CONFIG"] || DEFAULT_PACKAGE_CONFIG_PATH}"
          end
          @host_os = RbConfig::CONFIG['host_os']
        end

        def windows?
          !!(@host_os =~ /mswin|mingw/)
        end

        def linux?
          !!(@host_os =~ /linux/)
        end

        def tags_cached?
          File.exist?(cached_tags_path) and
            (Time.now - 60 * 60 * 24) < File.mtime(cached_tags_path)
        end

        def cached_tags_path
          ENV["FLUENT_PACKAGE_TAGS_PATH"] ? 
            ENV["FLUENT_PACKAGE_TAGS_PATH"] : "#{@tmp_dir}/fluent-package-tags.json"
        end

        def release_tags_url
          "https://api.github.com/repos/fluent/fluent-package-builder/tags"
        end

        def fetch_tags
          begin
            if tags_cached?
              yield JSON.parse(File.open(cached_tags_path).read)
            else
              URI.open(release_tags_url) do |resource|
                File.open(cached_tags_path, "w+") do |f|
                  json = resource.read
                  f.write(json)
                  yield JSON.parse(json)
                end
              end
            end
          rescue => e
            @logger.error "Failed to fetch tags", error: e
          end
        end

        def same_lts_series?(base_version, target_version)
          # compare [major, 0] pair information
          @options[:lts] and [base_version.segments.first, 0] == target_version.segments[..1]
        end

        def major_lts_update?(base_version, target_version)
          @options[:lts] and
            base_version.segments.first < target_version.segments.first and
            [base_version.segments[1], target_version.segments[1]]  == [0, 0]
        end

        def parse_os_release(key)
          File.open("/etc/os-release").readlines.each do |line|
            if line.start_with?(key)
              line.chomp =~ /^#{key}=(.+)$/
              return $1
            end
          end
          nil
        end

        def package_url(prefix, distribution, version)
          major = version.segments.first
          channel = @options[:lts] ? "lts/#{major}" : major
          case distribution
          when "debian", "ubuntu"
            release = parse_os_release("VERSION_CODENAME")
            "#{prefix}/#{channel}/#{distribution}/#{release}/pool/contrib/f/fluent-package/fluent-package_#{version}-1_amd64.deb"
          when "redhat/8"
            "#{prefix}/#{channel}/#{distribution}/x86_64/fluent-package_#{version}-1.el8.x86_64.rpm"
          when "redhat/9"
            "#{prefix}/#{channel}/#{distribution}/x86_64/fluent-package_#{version}-1.el9.x86_64.rpm"
          when "amazon/2023"
            "#{prefix}/#{channel}/#{distribution}/x86_64/fluent-package_#{version}-1.amzn2023.x86_64.rpm"
          when "amazon/2"
            "#{prefix}/#{channel}/#{distribution}/x86_64/fluent-package_#{version}-1.amzn2.x86_64.rpm"
          when "windows"
            "#{prefix}/#{channel}/#{distribution}/fluent-package-#{version}-x64.msi"
          end
        end

        def generate_remote_package_url(url_prefix, target_version)
          if linux?
            os_release_id = parse_os_release("ID")
            case os_release_id
            when "debian"
              url = package_url(url_prefix, "debian", target_version)
              @logger.debug("Check existence of #{url}")
              url
            when "ubuntu"
              package_url(url_prefix, "ubuntu", target_version)
            when "rocky", "almalinux", "amzn"
              cpe = parse_os_release("CPE_NAME")
              case cpe
              when /rocky:8/, /almalinux:8/
                package_url(url_prefix, "redhat/8", target_version)
              when /rocky:9/, /almalinux:9/
                package_url(url_prefix, "redhat/9", target_version)
              when /amazon_linux:2023/, /amazon_linux:2/
                version = parse_os_release("VERSION")
                case version
                when "2023"
                  package_url(url_prefix, "amazon/2023", target_version)
                when "2"
                  package_url(url_prefix, "amazon/2", target_version)
                end
              end
            end
          elsif windows?
            package_url(url_prefix, "windows", target_version)
          end
        end

        def check_remote_packages(target_version)
          @options[:repository_sites].each do |url_prefix|
            yield generate_remote_package_url(url_prefix, target_version)
          end
        end

        def check_package_released?(target_version)
          major = target_version.segments.first
          check_remote_packages(target_version) do |url|
            begin
              URI.open(url)
              return true
            rescue => e
              # package is not available
              @logger.debug("#{url} is inaccessible", error: e)
            end
          end
          # assume package is not available by default
          false
        end

        def check_update_versions
          current_version = Gem::Version.new("#{PACKAGE_VERSION}")
          fetch_tags do |releases|
            releases.each do |release|
              version = release["name"]
              next if version.include?("-") # skip test artifacts
              target_version = Gem::Version.new(version.delete("v"))
              if target_version > current_version
                major = current_version.segments.first
                if same_lts_series?(current_version, target_version)
                  @newer_lts_versions << version if check_package_released?(target_version)
                elsif version.start_with?("v#{major}")
                  @newer_versions << version if check_package_released?(target_version)
                else
                  # major upgrade standard/LTS version
                  if major_lts_update?(current_version, target_version)
                    # LTS
                    @major_lts_updates << version if check_package_released?(target_version)
                  else
                    @major_updates << version if check_package_released?(target_version)
                  end
                end
              end
            end
          end
          FileUtils.rm_rf(@tmp_dir)
        end

        def notify_update_log
          candidates = nil
          if @options[:lts]
            if @options[:notify_major_upgrade]
              candidates = if @major_lts_updates.count > 0
                             @major_lts_updates
                           elsif @newer_lts_versions.count > 0
                             @newer_lts_versions
                           end
            else
              candidates = @newer_lts_versions
            end
          else
            if @options[:notify_major_upgrade]
              candidates = if @major_updates.count > 0
                             @major_updates
                           elsif @newer_versions.count > 0
                             @newer_versions
                           end
            else
              candidates = @newer_versions
            end
          end
          if candidates
            # Assume the version information are already sorted in descendant order by GitHub API
            url = "https://github.com/fluent/fluent-package-builder/releases/tag/#{candidates.first}"
            message = "fluent-package #{candidates.first} is available! See #{url} in details."
          else
            message = "No update for fluent-package #{PACKAGE_VERSION}"
          end
          case @options[:notify_level]
          when :warn
            @logger.warn(message)
          when :info
            @logger.info(message)
          end
        end

        def run
          check_update_versions
          notify_update_log
        end
      end
    end
  end
end
