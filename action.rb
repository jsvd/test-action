require "json"
require "rubygems"

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

def pr_edits_version_files?
  `git diff --name-status VERSION *.gemspec version`.empty? == false
end

def pr_updates_changelog?
  `git diff --name-status CHANGELOG.md`.empty? == false
end

def rubygem_published?
  gemspec_path = Dir.glob("*.gemspec").first
  spec = Gem::Specification::load(gemspec_path)
  gem_name = spec.name
  version = spec.version.to_s
  puts spec.platform.to_s
  platform = spec.platform.to_s == "java" ? "-java" : ""
  url = "https://rubygems.org/gems/#{gem_name}/versions/#{version}#{platform}"
  puts url
  result = `curl -s -I #{url}`
  first_line = result.split("\n").first
  _, status, _ = first_line.split(" ")
  puts status
  status == "200"
end

unless pr_edits_version_files?
  $stderr.puts "ERROR: This Pull Request doesn't modify the gemspec or version files (if existent)."
  $stderr.puts "Please bump the version to speed up plugin publishing after this PR is merged"
  exit(1)
end

pr_version = find_pr_version()
puts "Plugin version in this PR is: #{pr_version}"

published_versions = fetch_git_versions()

if published_versions.include?(pr_version)
  $stderr.puts "ERROR: A git tag \"v#{pr_version}\" already exists for version #{pr_version}"
  $stderr.puts "Please bump the version to speed up plugin publishing after this PR is merged"
  exit(1)
end

if rubygem_published?
  $stderr.puts "ERROR: Version \"#{pr_version}\" is already published on Rubygems.org"
  $stderr.puts "Please bump the version to speed up plugin publishing after this PR is merged"
  exit(1)
end

unless pr_updates_changelog?
  $stderr.puts "ERROR: This Pull Request bumps the version but doesn't update the CHANGELOG.md file"
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
