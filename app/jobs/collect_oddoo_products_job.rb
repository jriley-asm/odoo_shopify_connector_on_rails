class CollectOddooProductsJob < ApplicationJob
  queue_as :collect_products

  def perform(*args)
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

    ### AWS STEP GATE HERE ###
    # make sure we actually got products correctly
    if @ids.kind_of?(Array)
    
      @ids.each do |id|
        InjectOddooProductJob.perform_later(id)
      end
    end
  end
end
