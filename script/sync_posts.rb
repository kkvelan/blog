#!/usr/bin/env ruby
# Sync blog folders (each with content.md) into _posts for Jekyll.
# Run from repo root: ruby script/sync_posts.rb

require "yaml"

BLOG_DIRS = %w[_config.yml _layouts _posts _site assets .git .jekyll-cache .sass-cache script]
POSTS_DIR = "_posts"

def skip?(dir)
  return true if dir.start_with?("_") || dir.start_with?(".")
  return true if BLOG_DIRS.include?(dir)
  return true unless File.directory?(dir)
  !File.file?(File.join(dir, "content.md"))
end

def date_from_front_matter(content)
  match = content.match(/\A---\s*\n(.*?)\n---\s*\n/m)
  return nil unless match
  data = YAML.safe_load(match[1])
  return nil unless data && data["date"]
  d = data["date"]
  d = Time.parse(d.to_s) if d.is_a?(String)
  d.strftime("%Y-%m-%d")
end

Dir.mkdir(POSTS_DIR) unless Dir.exist?(POSTS_DIR)

Dir.entries(".").sort.each do |dir|
  next if skip?(dir)

  content_path = File.join(dir, "content.md")
  content = File.read(content_path)
  date_str = date_from_front_matter(content)

  unless date_str
    warn "Skip #{dir}: no valid date in content.md front matter"
    next
  end

  out_name = "#{date_str}-#{dir}.md"
  out_path = File.join(POSTS_DIR, out_name)
  File.write(out_path, content)
  puts "Synced #{content_path} -> #{out_path}"
end

puts "Done. Commit _posts/ and push."
