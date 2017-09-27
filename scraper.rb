#!/usr/bin/env ruby
# frozen_string_literal: true

require 'scraperwiki'
require 'mechanize'
require 'json'
require 'active_support/core_ext/string/filters'

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
# doc = agent.get('http://www.nationalparks.nsw.gov.au/data/Map/GetPins')
# campsites = JSON.parse(doc.body).select { |d| d['type'] == 'camping' }
#
# campsites.each do |campsite|
#   id = campsite['id']
#   title = campsite['title']
#   puts title
#   latitude = campsite['coords']['lat']
#   longitude = campsite['coords']['lon']
#   # Get some more detailed information about the campsite
#   doc = agent.get(
#     "http://www.nationalparks.nsw.gov.au/data/Map/GetItem?id=#{id}"
#   )
#   data = JSON.parse(doc.body)
#   url = data['Url']
#   park_name = data['WhereText']
#   description = data['ShortDescription']
#   booking_url = data['BookingURL']['Url'] if data['BookingURL']
#
#   # Get the final details from the human readable campsite detail page
#   doc = agent.get(url)
#   # Extract table info
#   data = {}
#   doc.at('table.itemDetails').search('tr').each do |tr|
#     th = tr.at('th').inner_html.squish
#     td = tr.at('td').inner_html.squish
#     data[th] = td
#   end
#
#   record = {
#     'title' => title,
#     'latitude' => latitude,
#     'longitude' => longitude,
#     'id' => id,
#     'url' => url,
#     'park_name' => park_name,
#     'description' => description,
#     'booking_url' => booking_url,
#     'data' => data.to_json
#   }
#   ScraperWiki.save_sqlite(['id'], record)
# end

CAMPING_TYPES = [
  'Camping beside my vehicle',
  'Camping beside my vehicle Short walk from parking',
  'Camper trailer site',
  'High clearance camper trailer site',
  'Caravan site',
  'High clearance caravan site',
  "Don't mind a short walk to tent",
  'Remote/backpack camping',
  'Tent',
  'Tent sites short walk from car park'
].freeze

FACILITIES = [
  'barbecue facilities',
  'drinking water',
  'picnic tables',
  'showers',
  'toilets',
  'amenities block',
  'boat ramp',
  'cafe/kiosk',
  'carpark',
  'electric power',
  'public phone',
  'wireless internet'
].freeze

def parse_facilities(text)
  facilities = if text
                 text.split(',').map(&:strip).map(&:downcase)
               else
                 # TODO: Probably should return unknown values
                 []
               end
  facilities.each do |facility|
    raise "Unexpected facility: #{facility}" unless FACILITIES.include? facility
  end
  {
    'barbecues' => facilities.include?('barbecue facilities'),
    'drinking_water' => facilities.include?('drinking water'),
    'picnic_tables' => facilities.include?('picnic tables'),
    'showers' => facilities.include?('showers'),
    'toilets' => facilities.include?('toilets')
  }
end

def parse_camping_type(text)
  camping_types = text.split(',').map(&:strip)
  camping_types.each do |type|
    raise "Unexpected type: #{type}" unless CAMPING_TYPES.include? type
  end
  car =
    camping_types.include?('Camping beside my vehicle') ||
    camping_types.include?('Camping beside my vehicle Short walk from parking')

  trailers =
    camping_types.include?('Camper trailer site') ||
    camping_types.include?('High clearance camper trailer site')

  caravans =
    camping_types.include?('Caravan site') ||
    camping_types.include?('High clearance caravan site')

  {
    'car' => car,
    'trailers' => trailers,
    'caravans' => caravans
  }
end

# Format the data differently
ScraperWiki.select('* from data').each do |campsite|
  # data = JSON.parse(campsite['data'])
  # campsite['bookings'] = data['Bookings']
  # campsite['camping_type'] = data['Camping type']
  # campsite['entry_fees'] = data['Entry fees']
  # campsite['facilities'] = data['Facilities']
  # campsite['no_of_campsites'] = data['Number of campsites']
  # campsite['opening_times'] = data['Opening times']
  # campsite['please_note'] = data['Please note']
  # campsite['price'] = data['Price']

  campsite = campsite
             .merge(parse_facilities(campsite['facilities']))
             .merge(parse_camping_type(campsite['camping_type']))

  p campsite
  # ScraperWiki.save_sqlite(['id'], campsite)
end
