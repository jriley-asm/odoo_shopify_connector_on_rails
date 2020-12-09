class InjectOddooProductJob < ApplicationJob
  queue_as :inject_products

  API_KEY = "f4d3179bd388e45e631e0f147a2c6027"
  PASSWORD = "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"
  SHOP_NAME = "test-store-4325"

  def perform(*args)
    product_to_request = args[0]
    # Do something later
    info = XMLRPC::Client.new2('https://demo.odoo.com/start').call('start')
    url, db, username, password = \
        info['host'], info['database'], info['user'], info['password']
    common = XMLRPC::Client.new2("#{url}/xmlrpc/2/common")
    uid = common.call('authenticate', db, username, password, {})
    models = XMLRPC::Client.new2("#{url}/xmlrpc/2/object").proxy
    models.execute_kw(db, uid, password,
    'product.product', 'check_access_rights',
    ['read'], {raise_exception: false})
    @ids = models.execute_kw(db, uid, password,
    'product.product', 'search',
    [[]])

    product_rec = models.execute_kw(db, uid, password,
    'product.product', 'read',
    [[product_to_request]])

    product_rec_hash = product_rec[0]

    if product_rec_hash.kind_of?(Hash)
      #only want to inject the product if we actually got a product from odoo this iteration of the queue
      ### AWS STEP GATE HERE ###

      #use shopify api gem to talk to shopify here

      require 'shopify_api'
      shop_url = "https://#{API_KEY}:#{PASSWORD}@#{SHOP_NAME}.myshopify.com"
      ShopifyAPI::Base.site = shop_url
      ShopifyAPI::Base.api_version = "2020-10"

      new_product = ShopifyAPI::Product.new
      new_product.title = product_rec_hash['name']
      new_product.price = product_rec_hash['price']
      new_product.weight = product_rec_hash['weight']
      new_product.weight_unit = product_rec_hash['weight_uom_name']
      new_product.save
  end
end
