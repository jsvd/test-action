require "json"
require "rubygems"

# Each Action has an event passed to it.
=begin
event = JSON.parse(File.read(ENV['GITHUB_EVENT_PATH']))
puts "event inspect:"
puts event.inspect

puts "\n**printing environment"
puts ENV.inspect

puts "\nlisting files"
puts `ls`
=end
BASE_REF = ENV['GITHUB_BASE_REF']
unless BASE_REF
  $stderr.puts "ERROR: GITHUB_BASE_REF environment variable not found. Aborting.."
  exit(1)
end
def find_pr_version
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

def compute_changelog_suggestion
  commits = `git log #{BASE_REF}.. --format=%B`.split("\n")
  if commits.empty?
    "  - could not find commits between this Pull Request and the \"#{BASE_REF}\" branch."
  else
    commits.map {|commit| "  - #{commit}" }
  end
end

pr_version = find_pr_version()
puts "Plugin version in this PR is: #{pr_version}"

published_versions = fetch_git_versions()

if published_versions.include?(pr_version)
  $stderr.puts "ERROR: Version #{pr_version} has already been published to Rubygems.org"
  $stderr.puts "ERROR: Please bump the version to speed up plugin publishing after this PR is merged"
  exit(1)
end

unless match = find_version_changelog_entry(pr_version)
  $stderr.puts "ERROR: We were unable to find a CHANGELOG.md entry for version #{pr_version}"
  $stderr.puts "Please add a new entry to the top of CHANGELOG.md similar to:\n\n"
  $stderr.puts "## #{pr_version}"
  $stderr.puts compute_changelog_suggestion()
  exit(1)
else
  puts "Found changelog entry for version #{pr_version}:"
  puts match.to_s
end

puts "We're all set up for the version bump. Thank you!"
