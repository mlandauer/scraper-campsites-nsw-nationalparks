#!/usr/bin/env ruby
# frozen_string_literal: true

require 'scraperwiki'
require 'mechanize'

page = 1
agent = Mechanize.new

loop do
  # Read in the index page
  url = 'http://www.nationalparks.nsw.gov.au/search/CampingAndAccommodation/' \
        'LoadMore?LoadMoreCategory=Campgrounds&LoadMoreByPrimaryIdentity=0&' \
        "LoadMorePageNumber=#{page}&LoadMoreDisplayText=Campgrounds&" \
        'PageSize=10&'
  doc = agent.get(url)

  doc.search('article').each do |article|
    detail_url = article.at('h3 a')['href']
    p detail_url
    record = {
      'detail_url' => detail_url
    }
    ScraperWiki.save_sqlite(['detail_url'], record)
  end

  # Check if the "more" link is there
  break if doc.at('a.showMore').nil?
  page += 1
end
