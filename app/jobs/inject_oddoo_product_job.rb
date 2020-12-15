class InjectOddooProductJob < ApplicationJob
  queue_as :inject_products
  #lazy
  this_shopify_instance = ShopifyInstance.last

  # API_KEY = "f4d3179bd388e45e631e0f147a2c6027"
  # PASSWORD = "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"
  # SHOP_NAME = "test-store-4325"
  API_KEY = this_shopify_instance.api_key
  PASSWORD = this_shopify_instance.password
  SHOP_NAME = this_shopify_instance.shop_name

  def perform(*args)
    #get product id
    product_rec_hash = args[0]
    variant_id_arr = args[1]
    this_odoo_instance = OdooInstance.last
    # url = "https://demo56.odoo.com"
    # db = "demo56"
    # username = "jack@assembleinc.com"
    # #API KEY
    # password = "c1d384f62e88c92daaf52201448ea630069f8412"
    url = this_odoo_instance.url
    db = this_odoo_instance.db
    username = this_odoo_instance.username
    password = this_odoo_instance.password
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
      require 'net/https'
      require 'json'
      shop_url = "https://#{API_KEY}:#{PASSWORD}@#{SHOP_NAME}.myshopify.com" + "/admin/api/2020-10/products.json"

      odoo_product_atrribute_ids = product_rec_hash['attribute_line_ids']

      attributes = models.execute_kw(db, uid, password,
      'product.template.attribute.line', 'read',
      [odoo_product_atrribute_ids])

      shopify_options_arr = []

      attributes.each do |attr|
        option_name = String(attr['display_name'])
        shopify_options_arr.append({"name": option_name})
      end

      shopify_variants_arr = []

      variants.each_with_index do |variant, variant_index|
        this_variant_hash = {
          'price' => Float(variant['price'])
        }

        #get sku if we can
        if variant['code'] != false
          puts 'thinks there is a variant hash code'
          this_variant_hash['sku'] = variant['code']
          puts "added sku: #{this_variant_hash['sku']}"
        end

        this_variant_attribute_ids = variant['attribute_line_ids']

        this_variant_attributes = models.execute_kw(db, uid, password,
        'product.attribute', 'read',
        [this_variant_attribute_ids])
        puts 'got through variant attributes'
        #go through the attributes for this product and give this variant each applicable option
        this_variant_attributes.each_with_index do |attr, index|
          product_attribute_values = models.execute_kw(db, uid, password,
            'product.attribute.value', 'read',
            [[attr['id']]])

          new_option_name = product_attribute_values[0]['name']
          case index
          when 0
            this_variant_hash['option1'] = new_option_name
          when 1
            this_variant_hash['option2'] = new_option_name
          when 2
            this_variant_hash['option3'] = new_option_name
          end
        end
        #need to check and make sure the variant's options are unique
        if check_for_redundant_variant(shopify_variants_arr, this_variant_hash) == false
          shopify_variants_arr.append(this_variant_hash)
        end
        #else do nothing
      end

      product = {
        "product" => {
          "title" => product_rec_hash['name'],
          "variants" => shopify_variants_arr,
          "options" => shopify_options_arr
        }
      }

      uri = URI(shop_url)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      request = Net::HTTP::Post.new(uri)
      request.body = product.to_json
      request['X-Shopify-Access-Token'] = PASSWORD
      request['Content-Type'] = "application/json"

      #request = Net::HTTP::Get.new URI(shop_url)#, body: product)
      response = http.request(request)
      puts response.body
      response_hash = JSON.parse(response.body)

      if response_hash['product'].key?("id")
        this_product_model.push_status = "Success"
      else
        this_product_model.push_status = "Failed"
      end
      this_product_model.save
    else
      #this product already exists, we want to go ahead and update this product now
      puts 'we should update this product'
    end
  end

  private
  #returns true if there is a redundant var
  #returns false if...well just apply binary logic
  #i hate this code but i dont see an alternative
  def check_for_redundant_variant(variants, variant_to_check)
    #if there are no existing variants, redundancy is not possible
    if variants.size == 0
      return false
    end
    variants.each do |curr_variant|
      curr_variant_option_count = 0
      #first we want to figure out how many options are we checking
      if variant_to_check.key?("option1")
        curr_variant_option_count = 1
      end

      if variant_to_check.key?("option1") && variant_to_check.key?("option2")
        curr_variant_option_count = 2
      end

      if variant_to_check.key?("option1") && variant_to_check.key?("option2") && variant_to_check.key?("option3")
        curr_variant_option_count = 3
      end

      #then we compare those options
      case curr_variant_option_count
      when 1
        if curr_variant['option1'] == variant_to_check['option1']
          #we know then that we have found a redundant variant
          return true
        end
      when 2
        if curr_variant['option1'] == variant_to_check['option1'] && curr_variant['option2'] == variant_to_check['option2']
          #we know then that we have found a redundant variant
          return true
        end
      when 3
        if curr_variant['option1'] == variant_to_check['option1'] && curr_variant['option2'] == variant_to_check['option2'] && curr_variant['option3'] == variant_to_check['option3']
          #we know then that we have found a redundant variant
          return true
        end
      else
        return false
      end
    end
  end
end
