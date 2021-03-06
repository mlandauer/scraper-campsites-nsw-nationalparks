#!/usr/bin/env ruby
# frozen_string_literal: true

require 'scraperwiki'
require 'mechanize'
require 'json'
require 'active_support/core_ext/string/filters'

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
    'barbecues' => facilities.include?('barbecue facilities').to_s,
    'drinkingWater' => facilities.include?('drinking water').to_s,
    'picnicTables' => facilities.include?('picnic tables').to_s,
    'showers' => facilities.include?('showers').to_s,
    'toilets' => facilities.include?('toilets').to_s
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
    'car' => car.to_s,
    'trailers' => trailers.to_s,
    'caravans' => caravans.to_s
  }
end

agent = Mechanize.new

# Get campsite location data
doc = agent.get('http://www.nationalparks.nsw.gov.au/data/Map/GetPins')
campsites = JSON.parse(doc.body).select { |d| d['type'] == 'camping' }

campsites.each do |campsite|
  id = campsite['id']
  title = campsite['title']
  puts title
  latitude = campsite['coords']['lat'].to_f
  longitude = campsite['coords']['lon'].to_f
  # Get some more detailed information about the campsite
  doc = agent.get(
    "http://www.nationalparks.nsw.gov.au/data/Map/GetItem?id=#{id}"
  )
  data = JSON.parse(doc.body)
  url = data['Url']
  park_name = data['WhereText']
  description = Nokogiri::HTML(data['ShortDescription']).inner_text
  booking_url = data['BookingURL']['Url'] if data['BookingURL']
  if data['Number of campsites']
    no_of_campsites = data['Number of campsites'].to_i
  end

  # Get the final details from the human readable campsite detail page
  doc = agent.get(url)
  # Extract table info
  data = {}
  doc.at('table.itemDetails').search('tr').each do |tr|
    th = tr.at('th')
    td = tr.at('td')
    if th && td
      th_text = th.inner_html.squish
      td_text = td.inner_html.squish
      data[th_text] = td_text
    end
  end

  record = {
    'name' => title,
    'latitude' => latitude,
    'longitude' => longitude,
    'id' => id,
    'url' => url,
    'parkName' => park_name,
    'description' => description,
    'bookingURL' => booking_url,
    'bookings' => data['Bookings'],
    'noCampsites' => no_of_campsites
  }

  record = record
           .merge(parse_facilities(data['Facilities']))
           .merge(parse_camping_type(data['Camping type']))

  ScraperWiki.save_sqlite(['id'], record)
end
