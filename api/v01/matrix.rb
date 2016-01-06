# Copyright © Mapotempo, 2016
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

require './api/geojson_formatter'
require './api/v01/entities/matrix_result'
require './wrappers/wrapper'
require './router_wrapper'

module Api
  module V01
    class Matrix < Grape::API
      content_type :json, 'application/json; charset=UTF-8'
      content_type :geojson, 'application/vnd.geo+json; charset=UTF-8'
      content_type :xml, 'application/xml'
      formatter :geojson, GeoJsonFormatter
      # content_type :gpx, 'application/gpx+xml; charset=UTF-8'
      # formatter :gpx, GpxFormatter
      default_format :json
      version '0.1', using: :path

      rescue_from :all do |error|
        message = {error: error.class.name, detail: error.message}
        if ['test', 'development'].include?(ENV['APP_ENV'])
          message[:trace] = error.backtrace
          STDERR.puts error.message
          STDERR.puts error.backtrace
        end
        error!(message, 500)
      end

      resource :matrix do
        desc 'Rectangular matrix between tws points set', {
          nickname: 'matrix',
          entity: MatrixResult
        }
        params {
          optional :mode, type: String, values: RouterWrapper.config[:services][:route].keys.collect(&:to_s), default: RouterWrapper.config[:services][:route_default], desc: 'Transportation mode.'
          optional :departure, type: Date, desc: 'Departure date time.'
          optional :arrival, type: Date, desc: 'Arrival date time.'
          optional :speed_multiplicator, type: Float, desc: 'Speed multiplicator (default: 1), not available on all transport mode.'
          optional :lang, type: String, default: :en
          requires :src, type: String, desc: 'List of sources of latitudes and longitudes separated with comma, e.g. lat1,lng1,lat2,lng2...'
          optional :dst, type: String, desc: 'List of destination of latitudes and longitudes, if not present compute square matrix with sources points.'
        }
        get do
          params[:src] = params[:src].split(',').collect{ |f| Float(f) }.each_slice(2).to_a
          params[:src][-1].size == 2 || error!('Source couples of lat/lng are needed.', 400)

          if params.key?(:dst)
            params[:dst] = params[:dst].split(',').collect{ |f| Float(f) }.each_slice(2).to_a
            params[:dst][-1].size == 2 || error!('Destination couples of lat/lng are needed.', 400)
          else
            params[:dst] =  params[:src]
          end

          results = RouterWrapper::wrapper_matrix(params)
          results[:router][:version] = 'draft'
          present results, with: MatrixResult
        end
      end
    end
  end
end
