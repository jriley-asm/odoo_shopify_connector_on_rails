class CollectOddooProductsJob < ApplicationJob
  queue_as :collect_products

  def perform(*args)
    # Do something later
    this_odoo_instance = OdooInstance.last
    url = this_odoo_instance.url
    db = this_odoo_instance.db
    username = this_odoo_instance.username
    password = this_odoo_instance.password
    common = XMLRPC::Client.new2("#{url}/xmlrpc/2/common")
    uid = common.call('authenticate', db, username, password, {})
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
    [ids])

    #put all these variant ids into an Array
    #this should be a 2D arr
    #that way we can batch request all the variants for each product
    product_variant_id_arr = []

    product_records.each do |product|
      this_product_variant_ids = product['product_variant_ids']
      product_variant_id_arr.append(this_product_variant_ids)
    end

    require 'json'
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
