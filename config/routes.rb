Rails.application.routes.draw do
  get 'connector/index'

  get 'connector/queue_get_products_job'
  # For details on the DSL available within this file, see https://guides.rubyonrails.org/routing.html
  get 'welcome/index'
end
