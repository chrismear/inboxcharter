#!/usr/bin/env ruby

require 'rubygems'
require 'csv'
require 'google_chart'
require 'net/imap'
require 'yaml'
require 'cgi'

def get_status(options={})
  server = options[:server]
  username = options[:username]
  password = options[:password]
  ssl = options[:ssl] || false
  authentication = options[:authentication] || 'PLAIN'
  
  port = ssl ? 993 : 143
  i = Net::IMAP.new(server, port, ssl)
  case authentication
  when 'PLAIN'
    i.login(username, password)
  when 'LOGIN'
    i.authenticate('LOGIN', username, password)
  end
  status = i.status('INBOX', ['MESSAGES', 'UNSEEN'])
  i.examine('INBOX')
  deleted = i.search('DELETED').length
  i.disconnect
  [status['MESSAGES'].to_i, status['UNSEEN'].to_i, deleted]
rescue Net::IMAP::NoResponseError => e
  puts "Error with server #{server}."
  raise e
end

messages = 0
unread = 0
deleted = 0

accounts = YAML.load_file('config.yml')

accounts.each do |account|
  current_messages, current_unread, current_deleted = get_status(account)
  messages += current_messages
  unread += current_unread
  deleted += current_deleted
end

f = File.open('inboxdata.csv', 'a')
CSV::Writer.generate(f) do |csv|
  csv << [Time.now.utc.strftime('%d/%m'), Time.now.utc.strftime('%I%p'), messages-deleted, unread]
end

dates = []
messages = []
unread = []

CSV.open('inboxdata.csv', 'r') do |row|
  dates.push(row[1] + ' ' + row[0])
  messages.push row[2].to_i
  unread.push row[3].to_i
end

[dates, messages, unread].each do |array|
  array = array[-48..-1] if array.length > 48
end

c = GoogleChart::LineChart.new('500x200')
c.data "Messages", messages, '000000'
c.data "Unread", unread, 'ff0000'

skip = (dates.length - 5) / 4
start_date = dates.delete_at(0)
end_date = dates.delete_at(-1)
spaced_dates = []
counter = 0
dates.each do |date|
  counter += 1
  if counter > skip
    spaced_dates.push(date)
    counter = 0
  end
end
spaced_dates.unshift(start_date)
spaced_dates.push(end_date)

c.axis :x, :labels => spaced_dates
c.axis :y, :range => [0, [messages.max, unread.max].max]
puts CGI::escapeHTML(c.to_escaped_url)
