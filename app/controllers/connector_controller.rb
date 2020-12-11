class ConnectorController < ApplicationController
  require "xmlrpc/client"
  def index
    @products = Product.all
  end

  def queue_get_products_job
    CollectOddooProductsJob.perform_later
    redirect_back(fallback_location: { action: "index"})
  end
end
