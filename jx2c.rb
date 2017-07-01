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
    priority
    votes
    assignee
    reporter
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
        priority: priority,
        assignee: assignee,
        reporter: reporter,
        project_id: project_id,
        project_name: project_name,
        comment_count: comments.css("comment").count
      )
    end
  end
end

issues = IssueExtractor.new(filename: ARGV[0]).issues

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
