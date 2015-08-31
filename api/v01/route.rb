# Copyright © Mapotempo, 2015
#
# This file is part of Mapotempo.
#
# Mapotempo is free software. You can redistribute it and/or
# modify since you respect the terms of the GNU Affero General
# Public License as published by the Free Software Foundation,
# either version 3 of the License, or (at your option) any later version.
#
# Mapotempo is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY
# or FITNESS FOR A PARTICULAR PURPOSE.  See the Licenses for more details.
#
# You should have received a copy of the GNU Affero General Public License
# along with Mapotempo. If not, see:
# <http://www.gnu.org/licenses/agpl.html>
#
require 'grape'
require 'grape-swagger'
require 'polylines'

require './api/v01/entities/route_result'

module Api
  module V01
    class Route < Grape::API
      version '0.1', using: :path
      format :json
      content_type :json, 'application/json; charset=UTF-8'
      # content_type :geojson, 'application/vnd.geo+json; charset=UTF-8'
      # content_type :gpx, 'application/gpx+xml; charset=UTF-8'
      default_format :json

      rescue_from :all do |error|
        message = {error: error.class.name, detail: error.message}
        if ['development'].include?(ENV['APP_ENV'])
          message[:trace] = error.backtrace
          STDERR.puts error.message
          STDERR.puts error.backtrace
        end
        error!(message, 500)
      end

      resource :route do
        desc 'Route via two points or more', {
          nickname: 'route',
          entity: RouteResult
        }
        params {
          optional :mode, type: String, values: RouterWrapper.config[:services][:route].keys.collect(&:to_s), default: RouterWrapper.config[:services][:route_default], desc: 'Transportation mode.'
          optional :geometry, type: Boolean, default: true, desc: 'Return the route trace geometry.'
          optional :departure, type: Date, desc: 'Departure date time.'
          optional :arrival, type: Date, desc: 'Arrival date time.'
          optional :lang, type: String, default: :en
          requires :loc, type: String, desc: 'List of Latitudes and longitudes separated with comma.'
        }
        get do
          params[:loc] = params[:loc].split(',').collect{ |f| Float(f) }.each_slice(2).to_a
          raise 'At least two couples of lat/lng are needed.' if params[:loc].size < 2
          raise 'Couples of lat/lng are needed.' if params[:loc][-1].size != 2

          results = RouterWrapper::wrapper_route(params)
          results[:router][:version] = 'draft'
          results[:features].each{ |feature|
            if feature[:geometry][:polylines]
              feature[:geometry][:coordinates] = Polylines::Decoder.decode_polyline(feature[:geometry][:polylines], 1e6)
            else
              feature[:geometry][:polylines] = Polylines::Encoder.encode_points(feature[:geometry][:coordinates].collect{ |ll| ll.reverse }, 1e6)
            end
          }
          present results, with: RouteResult
        end
      end
    end
  end
end
