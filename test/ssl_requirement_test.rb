begin
  require 'action_controller'
rescue LoadError
  if ENV['ACTIONCONTROLLER_PATH'].nil?
    abort <<MSG
Please set the ACTIONCONTROLLER_PATH environment variable to the directory
containing the action_controller.rb file.
MSG
  else
    $LOAD_PATH.unshift << ENV['ACTIONCONTROLLER_PATH']
    begin
      require 'action_controller'
    rescue LoadError
      abort "ActionController could not be found."
    end
  end
end

require 'action_controller/test_process'
require 'test/unit'
require "#{File.dirname(__FILE__)}/../lib/ssl_requirement"

ActionController::Base.logger = nil
ActionController::Routing::Routes.reload rescue nil

class SslRequirementController < ActionController::Base
  include SslRequirement
  
  ssl_required :a, :b
  ssl_allowed :c
  
  def a
    render :nothing => true
  end
  
  def b
    render :nothing => true
  end
  
  def c
    render :nothing => true
  end
  
  def d
    render :nothing => true
  end
  
  def set_flash
    flash[:foo] = "bar"
  end
end

class SslHostRequirementController < ActionController::Base
  include SslRequirement
  
  self.ssl_host = "secure.example.com"
  self.non_ssl_host = "www.example.com"
  
  ssl_required :a
  
  def a
    render :nothing => true
  end
  
  def d
    render :nothing => true
  end
  
end

class SslHostDescendant < SslHostRequirementController
end

class SslRequirementTest < Test::Unit::TestCase
  def setup
    @controller = SslRequirementController.new
    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new
  end
  
  def test_redirect_to_https_preserves_flash
    get :set_flash
    get :b
    assert_response :redirect
    assert_equal "bar", flash[:foo]
  end
  
  def test_not_redirecting_to_https_preserves_the_flash
    get :set_flash
    get :d
    assert_response :success
    assert_equal "bar", flash[:foo]
  end
  
  def test_redirect_to_http_preserves_flash
    get :set_flash
    @request.env['HTTPS'] = "on"
    get :d
    assert_response :redirect
    assert_equal "bar", flash[:foo]
  end
  
  def test_not_redirecting_to_http_preserves_the_flash
    get :set_flash
    @request.env['HTTPS'] = "on"
    get :a
    assert_response :success
    assert_equal "bar", flash[:foo]
  end
  
  def test_required_without_ssl
    assert_not_equal "on", @request.env["HTTPS"]
    get :a
    assert_response :redirect
    assert_match %r{^https://}, @response.headers['Location']
    get :b
    assert_response :redirect
    assert_match %r{^https://}, @response.headers['Location']
  end
  
  def test_required_with_ssl
    @request.env['HTTPS'] = "on"
    get :a
    assert_response :success
    get :b
    assert_response :success
  end

  def test_disallowed_without_ssl
    assert_not_equal "on", @request.env["HTTPS"]
    get :d
    assert_response :success
  end

  def test_disallowed_with_ssl
    @request.env['HTTPS'] = "on"
    get :d
    assert_response :redirect
    assert_match %r{^http://}, @response.headers['Location']
  end

  def test_allowed_without_ssl
    assert_not_equal "on", @request.env["HTTPS"]
    get :c
    assert_response :success
  end

  def test_allowed_with_ssl
    @request.env['HTTPS'] = "on"
    get :c
    assert_response :success
  end

  def test_redirects_to_ssl_host
    @controller = SslHostRequirementController.new
    get :a
    assert_response :redirect
    assert_match %r{^https://secure.example.com}, @response.headers['Location']
  end
  
  def test_redirects_to_non_ssl_host
    @controller = SslHostRequirementController.new
    @request.env['HTTPS'] = "on"
    get :d
    assert_response :redirect
    assert_match %r{^http://www.example.com}, @response.headers['Location']
  end
  
  def test_descendant_controller_inerherits_host_setting
    @controller = SslHostDescendant.new
    get :a
    assert_response :redirect
    assert_match %r{^https://secure.example.com}, @response.headers['Location']
  end
  
  def test_ancestor_controller_does_not_inherit_host_setting
    get :a
    assert_response :redirect
    assert_no_match %r{^https://secure.example.com}, @response.headers['Location']
  end
end


