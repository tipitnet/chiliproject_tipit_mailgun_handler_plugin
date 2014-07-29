class EmailHandlerController < ActionController::Base

  def create
    if EmailHandler.receive(request)
      render :json => { :status => 'ok' }
    else
      render :json => { :status => 'rejected' }, :status => 403
    end
  end

end