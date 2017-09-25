#!/usr/bin/env ruby
# frozen_string_literal: true

require 'scraperwiki'
require 'mechanize'
require 'json'

def campsite_pages
  page = 1
  agent = Mechanize.new

  loop do
    # Read in the index page
    url = 'http://www.nationalparks.nsw.gov.au/' \
          'search/CampingAndAccommodation/LoadMore?' \
          'LoadMoreCategory=Campgrounds&' \
          'LoadMoreByPrimaryIdentity=0&' \
          "LoadMorePageNumber=#{page}&" \
          'LoadMoreDisplayText=Campgrounds&' \
          'PageSize=10&'
    doc = agent.get(url)

    doc.search('article').each do |article|
      detail_url = article.at('h3 a')['href']
      yield detail_url
    end

    # Check if the "more" link is there
    break if doc.at('a.showMore').nil?
    page += 1
  end
end

agent = Mechanize.new

# campsite_pages do |detail_url|
#   doc = agent.get(detail_url)
#   puts doc.body
#   exit
#
#   p detail_url
#   record = {
#     'detail_url' => detail_url
#   }
#   ScraperWiki.save_sqlite(['detail_url'], record)
# end

# Campsite schema that we're aiming for:
# "park-name": "blah",
# "name": "Acacia Flat",
# "description": "Explore the \"cradle of conservation\", the Blue Gum Forest. Enjoy birdwatching, long walks and plenty of photogenic flora.",
# "position-lat": -33.6149,
# "position-lng": 150.3553,
# "facilities-toilets": "non_flush",
# "facilities-picnicTables": false,
# "facilities-barbecues": "wood",
# "facilities-showers": "none",
# "facilities-drinkingWater": false,
# "access-caravans": false,
# "access-trailers": false,
# "access-car": false

# Get campsite location data
doc = agent.get('http://www.nationalparks.nsw.gov.au/data/Map/GetPins')
campsites = JSON.parse(doc.body).select { |d| d['type'] == 'camping' }

campsites.each do |campsite|
  record = {
    'title' => campsite['title'],
    'latitude' => campsite['coords']['lat'],
    'longitude' => campsite['coords']['lon'],
    'id' => campsite['id']
  }
  ScraperWiki.save_sqlite(['id'], record)
end
