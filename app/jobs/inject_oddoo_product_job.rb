class InjectOddooProductJob < ApplicationJob
  queue_as :inject_products

  API_KEY = "f4d3179bd388e45e631e0f147a2c6027"
  PASSWORD = "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"
  SHOP_NAME = "test-store-4325"

  def perform(*args)
    #get product id
    product_to_request = args[0]

    #create a new product entry, this is how we keep track of the products status outside of the job
    this_product_model = Product.new
    #connect and authenticate with odoo
    info = XMLRPC::Client.new2('https://demo.odoo.com/start').call('start')
    url, db, username, password = \
        info['host'], info['database'], info['user'], info['password']
    common = XMLRPC::Client.new2("#{url}/xmlrpc/2/common")
    uid = common.call('authenticate', db, username, password, {})
    models = XMLRPC::Client.new2("#{url}/xmlrpc/2/object").proxy
    models.execute_kw(db, uid, password,
    'product.product', 'check_access_rights',
    ['read'], {raise_exception: false})

    #get the product record we're after from odoo
    product_rec = models.execute_kw(db, uid, password,
    'product.product', 'read',
    [[product_to_request]])

    #for some reason this product rec is an array, we want its first element which is a "Hash" class
    product_rec_hash = product_rec[0]

    if product_rec_hash.kind_of?(Hash)
      this_product_model.pull_status = "Success"
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
      #...
      #save the new product and return whether or not we actually succeeded
      saved_product_shopify = new_product.save

      if saved_product_shopify
        this_product_model.push_status = "Success"
      else
        this_product_model.pull_status = "Failed"
      end
    else
      #we did not recieve the right value from odoo
      this_product_model.pull_status = "Failed"
    end
    this_product_model.save
  end
end
