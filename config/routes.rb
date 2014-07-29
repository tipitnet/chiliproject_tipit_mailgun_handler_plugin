
ActionController::Routing::Routes.draw do |map|

  map.with_options :controller => 'email_handler' do |email_handler_routes|
    email_handler_routes.with_options :conditions => {:method => :get} do |email_handler_actions|
      email_handler_actions.connect 'email_handler', :action => 'create'
    end
    email_handler_routes.with_options :conditions => {:method => :post} do |email_handler_actions|
      email_handler_actions.connect 'email_handler', :action => 'create'
    end

  end

end