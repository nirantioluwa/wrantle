json.extract! contact, :id, :name, :email, :phone, :contact_type, :message, :preferred_date, :preferred_time, :status, :created_at, :updated_at
json.url contact_url(contact, format: :json)
