class ConnectorController < ApplicationController
  require "xmlrpc/client"
  def index
    @products = Product.all
  end

  def queue_get_products_job
    CollectOddooProductsJob.perform_later
    redirect_back(fallback_location: { action: "index"})
  end

  def make_new_shopify_instance
    @shopify_instance = ShopifyInstance.new(api_key: params[:api_key], password: params[:password], shop_name: params[:shop_name])

    if @shopify_instance.save
      puts "saved shopify stuff"
      #redirect_back(fallback_location: { action: "index"})
    else
      #redirect_back(fallback_location: { action: "index"})
      puts "did not save"
    end
  end

  def make_new_odoo_instance
    @odoo_instance = OdooInstance.new(url: params[:url], db: params[:db], username: params[:username], password: params[:password])

    if @odoo_instance.save
      puts "saved odoo"
      redirect_back(fallback_location: { action: "index"})
    else
      redirect_back(fallback_location: { action: "index"})
    end
  end
end
