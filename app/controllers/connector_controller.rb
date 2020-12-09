class ConnectorController < ApplicationController
  require "xmlrpc/client"
  def index

  end

  def queue_get_products_job
    CollectOddooProductsJob.set(wait: 3.second).perform_later()
  end
end
