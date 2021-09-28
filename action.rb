require "json"
require "rubygems"

def followup_notice
  $stderr.puts "⚠️  Please bump the version to speed up plugin publishing in a new pull request."
end

def find_gemspec_version
  gemspec_path = Dir.glob("*.gemspec").first
  spec = Gem::Specification::load(gemspec_path)
  spec.version.to_s
end

def fetch_git_versions
  `git tag --list 'v*'`.split("\n").map {|version| version.tr("v", "").strip }
end

def find_version_changelog_entry(version)
  IO.read("CHANGELOG.md").match(/## #{version}\n\s+.+$/)
end

# TODO refactor rubygem_published?
def rubygem_published?
  gemspec_path = Dir.glob("*.gemspec").first
  spec = Gem::Specification::load(gemspec_path)
  gem_name = spec.name
  version = spec.version.to_s
  platform = spec.platform.to_s == "java" ? "-java" : ""
  url = "https://rubygems.org/gems/#{gem_name}/versions/#{version}#{platform}"
  result = `curl -s -I #{url}`
  first_line = result.split("\n").first
  _, status, _ = first_line.split(" ")
  status == "200"
end

event = JSON.parse(File.read(ENV['GITHUB_EVENT_PATH']))

event_name = ENV['GITHUB_EVENT_NAME']
puts ENV.inspect

puts "Action is: #{event_name}"

puts `ls -lha`
gemspec_version = find_gemspec_version()
puts "Plugin version in the gemspec is: #{gemspec_version}"

published_versions = fetch_git_versions()

if published_versions.include?(gemspec_version)
  $stderr.puts "❌ A git tag \"v#{gemspec_version}\" already exists for version #{gemspec_version}"
  followup_notice()
  exit(1)
end

if rubygem_published?
  $stderr.puts "❌ Version \"#{gemspec_version}\" is already published on Rubygems.org"
  followup_notice()
  exit(1)
end

unless match = find_version_changelog_entry(gemspec_version)
  $stderr.puts "❌ We were unable to find a CHANGELOG.md entry for version #{gemspec_version}"
  $stderr.puts "Please add a new entry to the top of CHANGELOG.md similar to:\n\n"
  $stderr.puts "## #{gemspec_version}"
  $stderr.puts "  - Change here [#number](link)"
  exit(1)
else
  puts "✅ Found changelog entry for version #{gemspec_version}:"
  puts match.to_s
end

puts "✅ We're all set up! Starting publishing now"
