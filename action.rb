require "json"
require "rubygems"

event = JSON.parse(File.read(ENV['GITHUB_EVENT_PATH']))

IS_PR = (ENV['GITHUB_EVENT_NAME'] == "pull_request")

puts "Action is PR: #{IS_PR}"

def followup_notice
  if IS_PR
    $stderr.puts "⚠️  Please bump the version to speed up plugin publishing after this PR is merged."
  else
    $stderr.puts "⚠️  Please bump the version to speed up plugin publishing in a new pull request."
  end
end

BASE_REF = IS_PR ? "origin/#{ENV['GITHUB_BASE_REF']}" : event["before"]

unless BASE_REF
  $stderr.puts "❌ Could not determine BASE_REF for this change. Aborting.."
  exit(1)
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

def compute_changelog_suggestion
  commits = `git log #{BASE_REF}.. --format=%B`.split("\n")
  if commits.empty?
    "  - could not find commits between this change the \"#{BASE_REF}\" reference."
  else
    commits.map {|commit| "  - #{commit}" }
  end
end

def file_changed?(path)
  `git diff --name-status #{BASE_REF} -- #{path}`.empty? == false
end

def change_edits_version_files?
  if File.exist?("VERSION")
    return file_changed?("VERSION")
  elsif File.exist?("version")
    return file_changed?("version")
  else
    return file_changed?("*.gemspec")
  end
end

def change_updates_changelog?
  file_changed?("CHANGELOG.md")
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

unless change_edits_version_files?
  $stderr.puts "❌ This change doesn't modify the gemspec or version files (if existent)."
  followup_notice()
  exit(1)
end

change_version = find_gemspec_version()
puts "Plugin version in the gemspec is: #{change_version}"

published_versions = fetch_git_versions()

if published_versions.include?(change_version)
  $stderr.puts "❌ A git tag \"v#{change_version}\" already exists for version #{change_version}"
  followup_notice()
  exit(1)
end

if rubygem_published?
  $stderr.puts "❌ Version \"#{change_version}\" is already published on Rubygems.org"
  followup_notice()
  exit(1)
end

unless change_updates_changelog?
  $stderr.puts "❌ This change bumps the version but doesn't update the CHANGELOG.md file"
  exit(1)
end

unless match = find_version_changelog_entry(change_version)
  $stderr.puts "❌ We were unable to find a CHANGELOG.md entry for version #{change_version}"
  $stderr.puts "Please add a new entry to the top of CHANGELOG.md similar to:\n\n"
  $stderr.puts "## #{change_version}"
  $stderr.puts compute_changelog_suggestion()
  exit(1)
else
  puts "✅ Found changelog entry for version #{change_version}:"
  puts match.to_s
end

if IS_PR
  puts "✅ We're all set up for the version bump. Thank you!"
else
  puts "✅ We're all set up! Starting publishing now"
end
