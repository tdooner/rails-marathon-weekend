class HomeController < ApplicationController
  def index
    hostname = Socket.gethostbyname(Socket.gethostname).first

    render text: "hello from #{hostname} / pid #{Process.pid} / server port #{request.env['SERVER_PORT']}"
  end
end
