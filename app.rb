require 'sinatra'
require 'omniauth'
require 'yaml'
require 'net/https'
require 'json'
require 'slim'

set YAML.load_file('config.yml')

use OmniAuth::Builder do
  provider :github,
    settings.oauth['id'],
    settings.oauth['secret']
end

helpers do
  def members(verb = :get, name = nil)
    @http ||= begin
      http              = Net::HTTP.new("github.com", 443)
      http.use_ssl      = true
      http.verify_mode  = OpenSSL::SSL::VERIFY_NONE
      http
    end

    klass     = Net::HTTP.const_get verb.to_s.capitalize
    req       = klass.new "/api/v2/json/teams/#{settings.org_id}/members"
    req.body  = "name=#{name}" if name

    req.basic_auth "#{settings.admin['name']}/token", settings.admin['token']
    res    = @http.request req
    result = JSON.parse res.body

    if result.is_a? Hash and result.include? "users"
      result["users"]
    else
      result
    end
  end
end

use Rack::Session::Pool

before %r{^/(?!auth).+} do
  redirect '/' unless session[:user]
  halt 'not a moderator' unless settings.moderators.include? session[:user]
end

get '/' do
  redirect '/list' if session[:user]
  slim :login
end

get '/list' do
  slim :list
end

get '/auth/:name/callback' do
  session[:user] = request.env["omniauth.auth"]["user_info"]["nickname"]
  redirect '/'
end

remove = proc do
  members :delete, params[:name]
  slim :removed
end

add = proc do
  members :post, params[:name]
  redirect '/list'
end

get('/add/:name', &add)
post('/add', &add)

get('/remove/:name', &remove)
post('/remove', &remove)
