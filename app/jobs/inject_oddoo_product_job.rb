class InjectOddooProductJob < ApplicationJob
  queue_as :inject_products

  API_KEY = "f4d3179bd388e45e631e0f147a2c6027"
  PASSWORD = "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"
  SHOP_NAME = "test-store-4325"

  def perform(*args)
    #get product id
    product_rec_hash = args[0]
    variant_id_arr = args[1]

    info = XMLRPC::Client.new2('https://demo.odoo.com/start').call('start')
    url, db, username, password = \
        info['host'], info['database'], info['user'], info['password']
    common = XMLRPC::Client.new2("#{url}/xmlrpc/2/common")
    uid = common.call('authenticate', db, username, password, {})
    models = XMLRPC::Client.new2("#{url}/xmlrpc/2/object").proxy
    models.execute_kw(db, uid, password,
    'product.product', 'check_access_rights',
    ['read'], {raise_exception: false})
    variants = models.execute_kw(db, uid, password,
    'product.product', 'read',
    [variant_id_arr])

    #puts JSON.pretty_generate(variants[0])

    #create a new product entry, this is how we keep track of the products status outside of the job
    #connect and authenticate with odoo

    #make sure this product is both valid and unique; if we already have this product in our local DB, don't create a new one.

    puts "product variant count:  #{variants.length}"

    if Product.where(odoo_id: product_rec_hash['id']).count == 0
      puts "working on product: #{product_rec_hash['name']}"
      this_product_model = Product.new
      this_product_model.odoo_id = Integer(product_rec_hash['id'])
      this_product_model.name = product_rec_hash['name']
      #as in this is a new product
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

      shopify_options_arr = []

      odoo_product_atrribute_ids = product_rec_hash['attribute_line_ids']

      attributes = models.execute_kw(db, uid, password,
      'product.template.attribute.line', 'read',
      [odoo_product_atrribute_ids])

      attributes.each do |attr|
        option = ShopifyAPI::Option.new(
          "name" => attr['display_name']
        )
        shopify_options_arr.append(option)
      end

      puts shopify_options_arr

      new_product.options = shopify_options_arr
      new_product.save
      #puts variants.class
      variants.each_with_index do |variant, variant_index|
        #puts "current index: #{variant_index}"
        variant_hash = ShopifyAPI::Variant.new(
          #'weight' => variant['weight'],
          'product_id' => new_product.id,
          'price' => Float(variant['price']),#,
          #'weight_unit' => variant['weight_uom_name'],
          #'inventory_policy' => "deny",
          'inventory_management' => "shopify",
          'inventory_quantity' => Integer(variant['qty_available'])
        )
        #puts variant_hash.price

        if variant['code'] != false
          puts 'thinks there is a variant hash code'
          variant_hash.sku = variant['code']
          puts "added sku: #{variant_hash.sku}"
        end

        #puts 'first hash print: '
        #puts JSON.pretty_generate(variant_hash)


        #now we want to add the options (option1, option2 etc for shopify to this shopify variant hash)
        #using the attributes associated with this ODOO product variant
        this_variant_attribute_ids = variant['attribute_line_ids']

        this_variant_attributes = models.execute_kw(db, uid, password,
        'product.attribute', 'read',
        [this_variant_attribute_ids])

        #puts "attribute count: #{this_variant_attributes.length}"

        this_variant_attributes.each_with_index do |attr, index|
          #we want to do two things in this loop, attatch each applicable option to the shopify variant hash
          #and we want to pull the Odoo attribute values for this attribute/variant
          #then we want to include those (or that one, because it should be an individual value in this case since we're dealing with a product variant.)
          product_attribute_values = models.execute_kw(db, uid, password,
          'product.attribute.value', 'read',
          [[attr['id']]])

          if product_attribute_values.length > 1
            puts 'TOO MANY ATTRIBUTE VALUES!!!'
          elsif product_attribute_values.length == 1
            puts 'pass'
            #you can only define up to three options
            new_option_name = product_attribute_values[0]['name']
            puts new_option_name
            case index
            when 0
              variant_hash.option1 = new_option_name
            when 1
              variant_hash.option2 = new_option_name
            when 2
              variant_hash.option2 = new_option_name
            end
            puts 'here'
            puts "Saved variant hash? #{variant_hash.save}"
          else
            puts 'thought there were no attribute values for this attribute'
          end
        end
        #new_product.save
        puts "about to share variant hash id"
        puts "variant hash id: #{variant_hash.id}"
        #new_product.variants << variant_hash
      end



      #need a list of product attributes
      #attribute_line_ids from odoo
      #this seems to be the way Odoo keeps track of product variant options
      #we need to present a list of these options to shopify

      puts 'got this far'

      #puts 'ABOUT TO SHOW ATTRIBUTES:'

      #puts JSON.pretty_generate(attributes)
      #this needs to account for variations

      #...
      #save the new product and return whether or not we actually succeed
      #puts shopify_options_arr

      new_product.save
      puts 'HERE'
      puts new_product.id

      if shopify_options_arr.length > 0
        puts 'thinks it should save shopify product'
        saved_product_shopify = new_product.save
        puts "saved the product in shopify: #{saved_product_shopify}"
      end
      #saved_product_shopify = false

      if saved_product_shopify
        this_product_model.push_status = "Success"
      else
        this_product_model.push_status = "Failed"
      end


      #this_product_model.save
    else
      #this product already exists, we want to go ahead and update this product now
      puts 'we should update this product'
    end
  end
end
