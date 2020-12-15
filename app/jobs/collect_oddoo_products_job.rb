class CollectOddooProductsJob < ApplicationJob
  queue_as :collect_products

  def perform(*args)
    # Do something later
    this_odoo_instance = OdooInstance.last
    puts this_odoo_instance.url
    # url = "https://demo56.odoo.com"
    # db = "demo56"
    # username = "jack@assembleinc.com"
    # #API KEY
    # password = "c1d384f62e88c92daaf52201448ea630069f8412"
    url = this_odoo_instance.url
    db = this_odoo_instance.db
    username = this_odoo_instance.username
    puts username
    password = this_odoo_instance.password
    puts password
    puts "got through initialization"
    common = XMLRPC::Client.new2("#{url}/xmlrpc/2/common")
    uid = common.call('authenticate', db, username, password, {})
    puts uid
    models = XMLRPC::Client.new2("#{url}/xmlrpc/2/object").proxy
    models.execute_kw(db, uid, password,
    'product.template', 'check_access_rights',
    ['read'], {raise_exception: false})
    ids = models.execute_kw(db, uid, password,
    'product.template', 'search',
    [[]])
    # now that we have the ids we need, lets go ahead and batch read these products
    #this returns an array of json objects representing the products

    product_records = models.execute_kw(db, uid, password,
    'product.template', 'read',
    [[9]])
    puts product_records
    #[ids])

    ### FOR TESTING ###
    #product_records = [product_records[0]]

    #put all these variant ids into an Array
    #this should be a 2D arr
    #that way we can batch request all the variants for each product
    product_variant_id_arr = []

    product_records.each do |product|
      this_product_variant_ids = product['product_variant_ids']
      product_variant_id_arr.append(this_product_variant_ids)
    end

    require 'json'

    #puts JSON.pretty_generate(product_records)

    ### AWS STEP GATE HERE ###
    # make sure we actually got products correctly
    if product_records.kind_of?(Array)
      #odoo says one request per second so thats what we're doing
      product_variant_id_arr.each_with_index do |variant_id_arr, index|
        #passing a product TEMPLATE as first arg, not a product PRODUCT
        InjectOddooProductJob.set(wait: 1.second).perform_later(product_records[index], variant_id_arr)
      end
    end
  end
end
