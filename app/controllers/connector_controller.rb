class ConnectorController < ApplicationController
  require "xmlrpc/client"
  def index
    @products = Product.all
  end

  def queue_get_products_job
    CollectOddooProductsJob.set(wait: 3.second).perform_later(@this_product_batch)
  end
end
