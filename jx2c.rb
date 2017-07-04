require 'nokogiri'
require 'date'
require 'csv'

OUTPUT_DIR = "./output/".freeze

class Issue
  ATTRIBUTES = %i(
    id
    title 
    link 
    description_length
    project_id
    project_name
    date_submitted
    date_resolved
    type
    status
    resolution_id
    priority
    votes
    assignee
    reporter
    watches
    authors
    comment_count
  )
  attr_accessor *ATTRIBUTES

  # @param title [String] project name
  def initialize(args)
    args.each do |attribute, value|
      send("#{attribute}=", value)
    end
    post_process
  end

  def self.csv_headers
    ATTRIBUTES.map(&:to_s)
  end

  def csv_line
    ATTRIBUTES.map do |attribute|
      send("#{attribute}")
    end
  end

  private

  def post_process
  end

end

class IssueExtractor
  attr_reader :issues
  def initialize(filename:)
    @doc = File.open(filename) { |f| Nokogiri::XML(f) }
    @issues = parse(doc: @doc)
  end

  protected

  def parse(doc:)
    doc.css("item").map do |issue|
      key = issue.css("key").text
      title = issue.css("title").text
      link = issue.css("link").text

      description = issue.css("description").text
      description_length = Nokogiri::HTML(description).text.length

      type = issue.css("type").text
      status = issue.css("status").text
      priority = issue.css("priority").text
      resolution_id = issue.css("resolution").attribute("id").value

      # vout count
      votes = issue.css("votes").text

      # jira user name of assignee
      assignee = issue.css("assignee").text

      # jira user name of reporting usser
      reporter = issue.css("reporter").text

      project_name = issue.css("project").text
      project_id = issue.css("project").attribute("id").value
      created = issue.css("created").text
      resolved = issue.css("resolved").text
      comments = issue.css("comments")
      watches = issue.css("watches").text

      # uniquie comment authors per issue
      comment_authors = comments.css("comment").map { |t| t.attribute("author").value }
      comment_author_count = comment_authors.uniq.count

      Issue.new(
        id: key,
        title: title,
        link: link,
        date_submitted: DateTime.parse(created),
        date_resolved: DateTime.parse(resolved),
        description_length: description_length,
        type: type,
        status: status,
        votes: votes,
        resolution_id: resolution_id,
        priority: priority,
        assignee: assignee,
        reporter: reporter,
        watches: watches,
        authors: comment_author_count,
        project_id: project_id,
        project_name: project_name,
        comment_count: comments.css("comment").count
      )
    end
  end
end

issues = IssueExtractor.new(filename: ARGV[0]).issues


reporters = issues.map(&:reporter).uniq

# Columns per author:
#   1. reporter name
#   2. total issues
#   3. fixed issues
#   4. won't fix issues
reporter_issue_stats = reporters.map do |reporter|
  issues_per_reporter = issues.select do |issue| 
    issue.reporter == reporter
  end
  [
    reporter, 
    issues_per_reporter.count,
    # resolution_id == 1 => FIXED
    issues_per_reporter.select { |issue| issue.resolution_id == "1"}.count,
    # resolution_id == 2 => Won't fix
    issues_per_reporter.select { |issue| issue.resolution_id == "2"}.count
  ]
end

timestamp = DateTime.now.strftime("%H%M%S%d%m%Y")
filename = "issues_#{timestamp}.csv"
filepath = "#{OUTPUT_DIR}#{filename}" 
CSV.open(filepath, "wb") do |csv|
  csv << Issue.csv_headers
  issues.each do |issue|
    csv << issue.csv_line
  end
end
puts "Issues Extracted to `#{filepath}`"

filename = "authors_#{timestamp}.csv"
filepath = "#{OUTPUT_DIR}#{filename}" 
CSV.open(filepath, "wb") do |csv|
  csv << ["Name", "Issues", "Fixed", "Won't Fix"]
  reporter_issue_stats.each do |stats|
    csv << stats
  end
end

puts "Authors Extracted to `#{filepath}`"
